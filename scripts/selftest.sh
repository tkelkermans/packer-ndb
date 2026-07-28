#!/usr/bin/env bash
set -euo pipefail

# The suite is strictly non-interactive. Detach stdin so sandboxed fakes
# that read it (e.g. ssh payload capture) get EOF instead of blocking when
# the suite runs with a long-lived stdin (background runners, some CI).
exec </dev/null

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=scripts/args.sh
source "$ROOT_DIR/scripts/args.sh"

SELFTEST_ANSIBLE_LOCAL_TEMP=""
if [[ -z "${ANSIBLE_LOCAL_TEMP:-}" ]]; then
  SELFTEST_ANSIBLE_LOCAL_TEMP=$(mktemp -d "${TMPDIR:-/tmp}/ndb-ansible-local.XXXXXX")
  export ANSIBLE_LOCAL_TEMP="$SELFTEST_ANSIBLE_LOCAL_TEMP"
fi
if [[ -z "${ANSIBLE_REMOTE_TEMP:-}" ]]; then
  export ANSIBLE_REMOTE_TEMP="${ANSIBLE_LOCAL_TEMP}/remote"
fi

cleanup_selftest_tmp() {
  if [[ -n "$SELFTEST_ANSIBLE_LOCAL_TEMP" ]]; then
    rm -rf "$SELFTEST_ANSIBLE_LOCAL_TEMP"
  fi
}
trap cleanup_selftest_tmp EXIT

SELFTEST_PASS_COUNT=0

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

pass() {
  printf 'PASS: %s\n' "$*"
  SELFTEST_PASS_COUNT=$((SELFTEST_PASS_COUNT + 1))
}

# Every NDB version tree present in the repo. Suites iterate this instead of a
# hardcoded list so a newly scaffolded release is covered automatically.
selftest_ndb_versions() {
  local dir
  for dir in "$ROOT_DIR"/ansible/*/; do
    [[ -d "$dir" ]] || continue
    basename "$dir"
  done
}

usage() {
  cat <<'EOF'
Usage: scripts/selftest.sh [--filter REGEX]

Runs every run_*_tests suite defined in scripts/selftests/*.sh, in file
(numeric prefix) order and definition order within each file. Fail-fast:
the first failing assertion aborts the run.

Options:
  --filter REGEX  Run only suite functions whose name matches REGEX
  -h, --help      Show this help and exit
EOF
}

SELFTEST_FILTER=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --filter)
      require_option_value "$1" "$#"
      SELFTEST_FILTER=$2
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Error: unknown selftest argument: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

# Discover suites in deterministic order and refuse duplicate names: a
# duplicated run_*_tests silently shadows its namesake when sourced (this
# bit once - see commit 1aba8a8). Parallel arrays instead of declare -A so
# the runner still works on macOS /bin/bash 3.2.
declare -a SELFTEST_SUITES=()
declare -a SELFTEST_SUITE_FILES=()

selftest_suite_file_for() {
  local wanted=$1 i
  (( ${#SELFTEST_SUITES[@]} > 0 )) || return 1
  for i in "${!SELFTEST_SUITES[@]}"; do
    if [[ "${SELFTEST_SUITES[$i]}" == "$wanted" ]]; then
      printf '%s\n' "${SELFTEST_SUITE_FILES[$i]}"
      return 0
    fi
  done
  return 1
}

SELFTEST_SUITE_GLOB=("$ROOT_DIR"/scripts/selftests/*.sh)
if (( ${#SELFTEST_SUITE_GLOB[@]} == 0 )) || [[ ! -e "${SELFTEST_SUITE_GLOB[0]}" ]]; then
  fail "no suite files found under scripts/selftests/"
fi

for suite_file in "${SELFTEST_SUITE_GLOB[@]}"; do
  suite_names=$(grep -E '^run_[a-z0-9_]+_tests\(\) \{$' "$suite_file" | sed 's/() {$//') || true
  if [[ -z "$suite_names" ]]; then
    fail "suite file defines no run_*_tests functions: $suite_file"
  fi
  while IFS= read -r suite_name; do
    if previous_file=$(selftest_suite_file_for "$suite_name"); then
      fail "duplicate suite function $suite_name in $suite_file (already defined in $previous_file)"
    fi
    SELFTEST_SUITES+=("$suite_name")
    SELFTEST_SUITE_FILES+=("$suite_file")
  done <<<"$suite_names"
  # shellcheck source=/dev/null
  source "$suite_file"
done

SELFTEST_RUN_COUNT=0
for suite_name in "${SELFTEST_SUITES[@]}"; do
  if [[ -n "$SELFTEST_FILTER" ]] && ! [[ "$suite_name" =~ $SELFTEST_FILTER ]]; then
    continue
  fi
  "$suite_name"
  SELFTEST_RUN_COUNT=$((SELFTEST_RUN_COUNT + 1))
done

if (( SELFTEST_RUN_COUNT == 0 )); then
  fail "no test suites matched --filter $SELFTEST_FILTER"
fi

printf 'Selftest summary: %s suite function(s) run, %s check(s) passed.\n' "$SELFTEST_RUN_COUNT" "$SELFTEST_PASS_COUNT"
