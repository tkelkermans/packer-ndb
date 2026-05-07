#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=scripts/prism.sh
source "$ROOT_DIR/scripts/prism.sh"

SCAN_PRISM=false
SHOW_PRISM_MATCHES=false

usage() {
  cat <<'EOF'
Usage: scripts/rhel_readiness.sh [--scan-prism] [--show-prism-matches]

Checks whether the licensed RHEL source-image inputs needed for live matrix
validation are ready. The helper prints set/missing status only; it does not
print source-image URI values or staged UUID values.

Options:
  --scan-prism           Query Prism for image names that look like RHEL images
  --show-prism-matches   With --scan-prism, print matching image UUIDs and names
  -h, --help             Show this help and exit
EOF
}

require_command() {
  local missing=()
  local command_name

  for command_name in "$@"; do
    command -v "$command_name" >/dev/null 2>&1 || missing+=("$command_name")
  done

  if (( ${#missing[@]} > 0 )); then
    printf 'Error: required commands not found: %s\n' "${missing[*]}" >&2
    exit 1
  fi
}

env_status() {
  local name=$1

  if [[ -n "${!name:-}" ]]; then
    printf '%s=set\n' "$name"
    return 0
  fi

  printf '%s=missing\n' "$name"
  return 1
}

all_set() {
  local name

  for name in "$@"; do
    [[ -n "${!name:-}" ]] || return 1
  done

  return 0
}

print_commands() {
  local uri_ready=$1
  local uuid_ready=$2

  printf '\nNext commands:\n'

  if [[ "$uuid_ready" == "true" ]]; then
    printf './test.sh --allow-rhel --include-os "Red Hat Enterprise Linux (RHEL)" --preflight --source-image-uuid-map "rhel-9.6=${RHEL_96_UUID},rhel-9.7=${RHEL_97_UUID}" --max-parallel 1\n'
  elif [[ "$uri_ready" == "true" ]]; then
    printf './test.sh --allow-rhel --include-os "Red Hat Enterprise Linux (RHEL)" --preflight --max-parallel 1\n'
  else
    printf 'Set NDB_RHEL_9_6_IMAGE_URI and NDB_RHEL_9_7_IMAGE_URI, or set RHEL_96_UUID and RHEL_97_UUID for staged Prism images.\n'
  fi

  printf './test.sh --allow-rhel --include-os "Red Hat Enterprise Linux (RHEL)" --validate --validate-artifact --manifest --continue-on-error --max-parallel 1\n'
  printf 'scripts/live_coverage_audit.sh ndb/2.9/matrix.json ndb/2.10/matrix.json\n'
}

scan_prism_images() {
  local response
  local matches_file
  local count
  local active_count

  require_command jq curl
  prism_require_env >/dev/null

  matches_file=$(mktemp -t ndb-rhel-images.XXXXXX)

  response=$(prism_list_resource images image 2000)
  jq -r '
    [
      .entities[]?
      | {
          name: (.spec.name // .status.name // ""),
          uuid: (.metadata.uuid // ""),
          state: (.status.state // ""),
          cluster_count: ((.status.resources.cluster_reference_list // .status.cluster_reference_list // []) | length)
        }
      | select(.name | test("rhel|red hat|redhat|enterprise linux"; "i"))
      | select(.uuid != "" and .name != "")
    ]
  ' <<<"$response" > "$matches_file"

  count=$(jq 'length' "$matches_file")
  active_count=$(jq '[.[] | select(.cluster_count > 0)] | length' "$matches_file")
  printf '\nStaged RHEL-like Prism images: %s\n' "$count"
  printf 'Active RHEL-like Prism images: %s\n' "$active_count"

  if [[ "$count" == "0" ]]; then
    printf 'No staged Prism images matched RHEL naming.\n'
    return 0
  fi

  if [[ "$SHOW_PRISM_MATCHES" == "true" ]]; then
    jq -r '.[] | "- \(.uuid)\t\(.name)\tstate=\(.state)\tclusters=\(.cluster_count)\tavailability=\(if .cluster_count > 0 then "active" else "inactive" end)"' "$matches_file"
  else
    printf 'Use --show-prism-matches to print matching image UUIDs and names.\n'
  fi

  rm -f "$matches_file"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scan-prism)
      SCAN_PRISM=true
      ;;
    --show-prism-matches)
      SHOW_PRISM_MATCHES=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown parameter: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

uri_ready=false
uuid_ready=false

printf 'RHEL source URI readiness: '
if all_set NDB_RHEL_9_6_IMAGE_URI NDB_RHEL_9_7_IMAGE_URI; then
  uri_ready=true
  printf 'complete\n'
else
  printf 'incomplete\n'
fi
env_status NDB_RHEL_9_6_IMAGE_URI || true
env_status NDB_RHEL_9_7_IMAGE_URI || true

printf '\nRHEL staged image UUID readiness: '
if all_set RHEL_96_UUID RHEL_97_UUID; then
  uuid_ready=true
  printf 'complete\n'
else
  printf 'incomplete\n'
fi
env_status RHEL_96_UUID || true
env_status RHEL_97_UUID || true

if [[ "$SCAN_PRISM" == "true" ]]; then
  scan_prism_images
fi

print_commands "$uri_ready" "$uuid_ready"

if [[ "$uri_ready" == "true" || "$uuid_ready" == "true" ]]; then
  exit 0
fi

exit 1
