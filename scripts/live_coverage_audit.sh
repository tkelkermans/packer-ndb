#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
MANIFEST_DIR="$ROOT_DIR/manifests"
MATRIX_FILES=()
SUGGEST_RUNS=false
SOURCE_IMAGE_UUID_MAP_RAW=""
SOURCE_IMAGE_UUID_KEYS=()
SOURCE_IMAGE_UUID_VALUES=()

usage() {
  cat <<'EOF'
Usage: scripts/live_coverage_audit.sh [--suggest-runs] [--source-image-uuid-map MAP] [--manifest-dir DIR] [matrix.json ...]

Audits buildable matrix rows against successful live build manifests.

A row is counted as covered only when a manifest records:
  status == success
  validation.in_guest == passed
  validation.artifact == passed
  cleanup.artifact_validation_vm == deleted

If no matrix files are provided, ndb/*/matrix.json is used.

Options:
  --suggest-runs                 Print one validated build.sh command for each missing row.
  --source-image-uuid-map MAP    Add --source-image-uuid to suggested commands for matching image keys.
EOF
}

source_image_key() {
  local os_type=$1 os_version=$2
  local os_slug

  case "$os_type" in
    "Red Hat Enterprise Linux (RHEL)"|"RHEL")
      printf 'rhel-%s' "$os_version"
      ;;
    "Rocky Linux")
      printf 'rocky-linux-%s' "$os_version"
      ;;
    "Ubuntu Linux")
      printf 'ubuntu-linux-%s' "$os_version"
      ;;
    *)
      os_slug=$(printf '%s' "$os_type" \
        | tr '[:upper:]' '[:lower:]' \
        | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g')
      printf '%s-%s' "$os_slug" "$os_version"
      ;;
  esac
}

parse_source_image_uuid_map() {
  local map=$1 entry key uuid

  [[ -n "$map" ]] || return 0
  IFS=',' read -r -a entries <<< "$map"
  for entry in "${entries[@]}"; do
    if [[ "$entry" != *=* ]]; then
      echo "Error: --source-image-uuid-map entries must use key=uuid." >&2
      exit 1
    fi
    key=${entry%%=*}
    uuid=${entry#*=}
    if [[ -z "$key" || -z "$uuid" ]]; then
      echo "Error: --source-image-uuid-map entries require non-empty key and UUID values." >&2
      exit 1
    fi
    if source_image_uuid_for_key "$key" >/dev/null; then
      echo "Error: duplicate --source-image-uuid-map key: $key" >&2
      exit 1
    fi
    SOURCE_IMAGE_UUID_KEYS+=("$key")
    SOURCE_IMAGE_UUID_VALUES+=("$uuid")
  done
}

source_image_uuid_for_key() {
  local requested_key=$1 index

  for index in "${!SOURCE_IMAGE_UUID_KEYS[@]}"; do
    if [[ "${SOURCE_IMAGE_UUID_KEYS[$index]}" == "$requested_key" ]]; then
      printf '%s\n' "${SOURCE_IMAGE_UUID_VALUES[$index]}"
      return 0
    fi
  done

  return 1
}

print_build_command() {
  local ndb_version=$1 db_type=$2 os_type=$3 os_version=$4 db_version=$5
  local key uuid

  key=$(source_image_key "$os_type" "$os_version")
  uuid=$(source_image_uuid_for_key "$key" || true)

  printf './build.sh --ci --validate --validate-artifact --manifest'
  printf ' --ndb-version %q' "$ndb_version"
  printf ' --db-type %q' "$db_type"
  printf ' --os %q' "$os_type"
  printf ' --os-version %q' "$os_version"
  printf ' --db-version %q' "$db_version"
  if [[ -n "$uuid" ]]; then
    printf ' --source-image-uuid %q' "$uuid"
  fi
  printf '\n'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --suggest-runs)
      SUGGEST_RUNS=true
      ;;
    --source-image-uuid-map)
      SOURCE_IMAGE_UUID_MAP_RAW=$2
      shift
      ;;
    --manifest-dir)
      MANIFEST_DIR=$2
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      MATRIX_FILES+=("$1")
      ;;
  esac
  shift
done

parse_source_image_uuid_map "$SOURCE_IMAGE_UUID_MAP_RAW"

if [[ ${#MATRIX_FILES[@]} -eq 0 ]]; then
  for matrix_file in "$ROOT_DIR"/ndb/*/matrix.json; do
    [[ -f "$matrix_file" ]] || continue
    MATRIX_FILES+=("$matrix_file")
  done
fi

if [[ ${#MATRIX_FILES[@]} -eq 0 ]]; then
  echo "Error: no matrix files found." >&2
  exit 1
fi

for matrix_file in "${MATRIX_FILES[@]}"; do
  if [[ ! -f "$matrix_file" ]]; then
    echo "Error: matrix file not found: $matrix_file" >&2
    exit 1
  fi
done

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

EXPECTED_ROWS="$TMPDIR/expected.tsv"
SUCCESS_ROWS="$TMPDIR/success.tsv"
COVERED_ROWS="$TMPDIR/covered.tsv"
MISSING_ROWS="$TMPDIR/missing.tsv"

jq -s -r '
  .[][]
  | select((.provisioning_role // "") == "postgresql" or (.provisioning_role // "") == "mongodb")
  | [.ndb_version, .db_type, .os_type, .os_version, .db_version]
  | @tsv
' "${MATRIX_FILES[@]}" | sort -u > "$EXPECTED_ROWS"

MANIFEST_FILES=()
if [[ -d "$MANIFEST_DIR" ]]; then
  while IFS= read -r -d '' manifest_file; do
    MANIFEST_FILES+=("$manifest_file")
  done < <(find "$MANIFEST_DIR" -maxdepth 1 -type f -name '*.json' -print0)
fi

if [[ ${#MANIFEST_FILES[@]} -gt 0 ]]; then
  jq -s -r '
    .[]
    | select(.status == "success")
    | select(.validation.in_guest == "passed")
    | select(.validation.artifact == "passed")
    | select(.cleanup.artifact_validation_vm == "deleted")
    | [.selection.ndb_version, .selection.db_type, .selection.os_type, .selection.os_version, .selection.db_version]
    | @tsv
  ' "${MANIFEST_FILES[@]}" | sort -u > "$SUCCESS_ROWS"
else
  : > "$SUCCESS_ROWS"
fi

comm -12 "$EXPECTED_ROWS" "$SUCCESS_ROWS" > "$COVERED_ROWS"
comm -23 "$EXPECTED_ROWS" "$SUCCESS_ROWS" > "$MISSING_ROWS"

buildable_count=$(wc -l < "$EXPECTED_ROWS" | tr -d ' ')
covered_count=$(wc -l < "$COVERED_ROWS" | tr -d ' ')
missing_count=$(wc -l < "$MISSING_ROWS" | tr -d ' ')

printf 'Buildable rows: %s\n' "$buildable_count"
printf 'Successful live rows: %s\n' "$covered_count"
printf 'Missing live rows: %s\n' "$missing_count"

if [[ "$missing_count" != "0" ]]; then
  printf '\nMissing rows:\n'
  printf 'ndb_version\tdb_type\tos_type\tos_version\tdb_version\n'
  cat "$MISSING_ROWS"

  if [[ "$SUGGEST_RUNS" == "true" ]]; then
    printf '\nSuggested commands for missing rows:\n'
    while IFS=$'\t' read -r ndb_version db_type os_type os_version db_version; do
      print_build_command "$ndb_version" "$db_type" "$os_type" "$os_version" "$db_version"
    done < "$MISSING_ROWS"
  fi

  exit 1
fi
