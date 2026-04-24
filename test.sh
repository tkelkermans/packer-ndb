#!/bin/bash

set -euo pipefail

INCLUDE_OS=()
EXCLUDE_OS=()
INCLUDE_NDB=()
MAX_PARALLEL=1
ALLOW_RHEL=false
INCLUDE_DB_TYPES=("pgsql")
FILTER_DB_TYPES=true
VALIDATE_BUILDS=false
VALIDATE_ARTIFACTS=false
WRITE_MANIFEST=false

function usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  --include-os LIST     Comma-separated list of OS types to include (default: all)
  --exclude-os LIST     Comma-separated list of OS types to exclude
  --include-ndb LIST    Comma-separated list of NDB versions to include (default: all)
  --include-db-type LIST  Comma-separated list of db_type values (default: pgsql)
  --all-db-types        Disable db_type filtering
  --max-parallel N      Number of concurrent builds to run (default: 1)
  --allow-rhel          Include RHEL builds (skipped by default)
  --validate            Run in-guest validation after provisioning for each build
  --validate-artifact   Boot and validate each saved artifact after Packer succeeds
  --manifest            Write build manifests for each live build
  -h, --help            Show this help and exit
EOF
}

function split_csv() {
  local input=$1
  IFS=',' read -r -a result <<< "$input"
  printf '%s\0' "${result[@]}"
}

function contains() {
  local needle=$1
  shift
  for item in "$@"; do
    if [[ "$item" == "$needle" ]]; then
      return 0
    fi
  done
  return 1
}

function db_type_allowed() {
  local db_type=$1
  if [[ "$FILTER_DB_TYPES" == true ]]; then
    contains "$db_type" "${INCLUDE_DB_TYPES[@]}"
    return
  fi
  return 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --include-os)
      while IFS= read -r -d '' value; do
        INCLUDE_OS+=("$value")
      done < <(split_csv "$2")
      shift
      ;;
    --exclude-os)
      while IFS= read -r -d '' value; do
        EXCLUDE_OS+=("$value")
      done < <(split_csv "$2")
      shift
      ;;
    --include-ndb)
      while IFS= read -r -d '' value; do
        INCLUDE_NDB+=("$value")
      done < <(split_csv "$2")
      shift
      ;;
    --include-db-type)
      INCLUDE_DB_TYPES=()
      while IFS= read -r -d '' value; do
        INCLUDE_DB_TYPES+=("$value")
      done < <(split_csv "$2")
      FILTER_DB_TYPES=true
      shift
      ;;
    --all-db-types)
      FILTER_DB_TYPES=false
      INCLUDE_DB_TYPES=()
      ;;
    --max-parallel)
      MAX_PARALLEL="$2"
      shift
      ;;
    --allow-rhel)
      ALLOW_RHEL=true
      ;;
    --validate)
      VALIDATE_BUILDS=true
      ;;
    --validate-artifact)
      VALIDATE_ARTIFACTS=true
      ;;
    --manifest)
      WRITE_MANIFEST=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
  shift
done

if ! [[ "$MAX_PARALLEL" =~ ^[0-9]+$ ]] || (( MAX_PARALLEL < 1 )); then
  echo "Error: --max-parallel must be a positive integer." >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required to run the tests." >&2
  exit 1
fi

MATRIX_FILES=(ndb/*/matrix.json)
if (( ${#MATRIX_FILES[@]} == 0 )); then
  echo "Error: No matrix files found under ndb/." >&2
  exit 1
fi

if [[ "${SKIP_MATRIX_VALIDATION:-false}" != "true" ]]; then
  scripts/matrix_validate.sh "${MATRIX_FILES[@]}"
fi

declare -a ACTIVE_PIDS=()
TEST_FAILURES=0

function terminate_active_builds() {
  local pid
  for pid in "${ACTIVE_PIDS[@]}"; do
    if kill -0 "$pid" >/dev/null 2>&1; then
      kill "$pid" >/dev/null 2>&1 || true
    fi
  done
  for pid in "${ACTIVE_PIDS[@]}"; do
    wait "$pid" >/dev/null 2>&1 || true
  done
  ACTIVE_PIDS=()
}

function cleanup_on_exit() {
  local status=$?
  if [[ "$status" -ne 0 && ${#ACTIVE_PIDS[@]} -gt 0 ]]; then
    terminate_active_builds
  fi
}
trap cleanup_on_exit EXIT
trap 'terminate_active_builds; exit 130' INT TERM

function wait_for_one() {
  local pid=$1
  local status=0
  if wait "$pid"; then
    status=0
  else
    status=$?
    TEST_FAILURES=$((TEST_FAILURES + 1))
    echo "Error: build process ${pid} failed with exit status ${status}." >&2
  fi
  return 0
}

function wait_for_all() {
  for pid in "${ACTIVE_PIDS[@]}"; do
    wait_for_one "$pid"
  done
  ACTIVE_PIDS=()
}

function throttle() {
  if (( ${#ACTIVE_PIDS[@]} >= MAX_PARALLEL )); then
    wait_for_one "${ACTIVE_PIDS[0]}"
    ACTIVE_PIDS=("${ACTIVE_PIDS[@]:1}")
  fi
}

function os_allowed() {
  local os=$1
  if (( ${#INCLUDE_OS[@]} > 0 )) && ! contains "$os" "${INCLUDE_OS[@]}"; then
    return 1
  fi
  if (( ${#EXCLUDE_OS[@]} > 0 )) && contains "$os" "${EXCLUDE_OS[@]}"; then
    return 1
  fi
  if [[ "$ALLOW_RHEL" != "true" ]]; then
    case "$os" in
      RHEL|"Red Hat Enterprise Linux (RHEL)")
        return 1
        ;;
    esac
  fi
  return 0
}

function ndb_allowed() {
  local version=$1
  if (( ${#INCLUDE_NDB[@]} > 0 )) && ! contains "$version" "${INCLUDE_NDB[@]}"; then
    return 1
  fi
  return 0
}

for matrix_file in "${MATRIX_FILES[@]}"; do
  ndb_version=$(basename "$(dirname "$matrix_file")")
  if [[ -n "$ndb_version" ]] && ! ndb_allowed "$ndb_version"; then
    echo "--- Skipping NDB version ${ndb_version} (not selected) ---"
    continue
  fi

  echo "--- Testing NDB version ${ndb_version} ---"

  while IFS= read -r build; do
    if (( TEST_FAILURES > 0 )); then
      break
    fi
    db_type=$(echo "$build" | jq -r '.db_type // ""')
    if ! db_type_allowed "$db_type"; then
      continue
    fi
    provisioning_role=$(echo "$build" | jq -r '.provisioning_role // "postgresql"')
    if [[ "$provisioning_role" != "postgresql" ]]; then
      continue
    fi
    os_type=$(echo "$build" | jq -r '.os_type')
    if ! os_allowed "$os_type"; then
      echo "--> Skipping ${os_type} build per filters."
      continue
    fi

    os_version=$(echo "$build" | jq -r '.os_version')
    db_version=$(echo "$build" | jq -r '.db_version')

    echo "--> Testing build: ${db_type} on ${os_type} ${os_version} (DB ${db_version})"

    (
      set -euo pipefail
      BUILD_ARGS=(./build.sh --ci --ndb-version "$ndb_version" --db-type "$db_type" --os "$os_type" --os-version "$os_version" --db-version "$db_version")
      if [[ "$VALIDATE_BUILDS" == "true" ]]; then
        BUILD_ARGS+=(--validate)
      fi
      if [[ "$VALIDATE_ARTIFACTS" == "true" ]]; then
        BUILD_ARGS+=(--validate-artifact)
      fi
      if [[ "$WRITE_MANIFEST" == "true" ]]; then
        BUILD_ARGS+=(--manifest)
      fi
      "${BUILD_ARGS[@]}"
    ) &

    ACTIVE_PIDS+=($!)
    throttle
  done < <(jq -c '.[]' "$matrix_file")

  if (( TEST_FAILURES > 0 )); then
    break
  fi
done

wait_for_all

if (( TEST_FAILURES > 0 )); then
  echo "--- ${TEST_FAILURES} requested test build(s) failed ---" >&2
  exit 1
fi

echo "--- All requested tests completed successfully ---"
