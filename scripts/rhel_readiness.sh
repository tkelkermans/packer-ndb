#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=scripts/prism.sh
source "$ROOT_DIR/scripts/prism.sh"

SCAN_PRISM=false
SHOW_PRISM_MATCHES=false

# Core RHEL 9.6/9.7 inputs cover NDB 2.9 and 2.10. NDB 2.11 adds 9.8 and 10.
RHEL_URI_VARS=(
  NDB_RHEL_9_6_IMAGE_URI
  NDB_RHEL_9_7_IMAGE_URI
  NDB_RHEL_9_8_IMAGE_URI
  NDB_RHEL_10_IMAGE_URI
)
RHEL_UUID_VARS=(
  RHEL_96_UUID
  RHEL_97_UUID
  RHEL_98_UUID
  RHEL_10_UUID
)
RHEL_CORE_URI_VARS=(
  NDB_RHEL_9_6_IMAGE_URI
  NDB_RHEL_9_7_IMAGE_URI
)
RHEL_CORE_UUID_VARS=(
  RHEL_96_UUID
  RHEL_97_UUID
)

usage() {
  cat <<'EOF'
Usage: scripts/rhel_readiness.sh [--scan-prism] [--show-prism-matches]

Checks whether the licensed RHEL source-image inputs needed for live matrix
validation are ready. The helper prints set/missing status only; it does not
print source-image URI values, staged UUID values, org IDs, or activation keys.

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

any_set() {
  local name

  for name in "$@"; do
    [[ -n "${!name:-}" ]] && return 0
  done

  return 1
}

print_commands() {
  local uri_ready=$1
  local uuid_ready=$2

  printf '\nNext commands:\n'

  if [[ "$uuid_ready" == "true" ]]; then
    printf './test.sh --allow-rhel --include-os "Red Hat Enterprise Linux (RHEL)" --preflight --source-image-uuid-map "rhel-9.6=${RHEL_96_UUID},rhel-9.7=${RHEL_97_UUID},rhel-9.8=${RHEL_98_UUID},rhel-10=${RHEL_10_UUID}" --max-parallel 1\n'
  elif [[ "$uri_ready" == "true" ]]; then
    printf './test.sh --allow-rhel --include-os "Red Hat Enterprise Linux (RHEL)" --preflight --max-parallel 1\n'
  else
    printf 'Set NDB_RHEL_9_6_IMAGE_URI and NDB_RHEL_9_7_IMAGE_URI (plus NDB_RHEL_9_8_IMAGE_URI / NDB_RHEL_10_IMAGE_URI for NDB 2.11), or set matching RHEL_*_UUID staged Prism image variables.\n'
  fi

  printf 'Set NDB_RHEL_ORGID and NDB_RHEL_ACTIVATIONKEY before running --rhel-repository-check or live RHEL builds that need Red Hat CDN repositories.\n'
  printf 'scripts/source_image_ssh_probe.sh --source-image-uuid "${RHEL_97_UUID}" --rhel-repository-check --ssh-timeout 900\n'
  printf './test.sh --allow-rhel --include-os "Red Hat Enterprise Linux (RHEL)" --validate --validate-artifact --manifest --continue-on-error --max-parallel 1\n'
  printf 'scripts/live_coverage_audit.sh ndb/2.9/matrix.json ndb/2.10/matrix.json ndb/2.11/matrix.json\n'
}

scan_prism_images() {
  local response
  local candidates_file
  local matches_file
  local records_file
  local count
  local active_count
  local candidate
  local detail_json
  local name
  local state
  local uuid
  local cluster_count

  require_command jq curl
  prism_require_env >/dev/null

  candidates_file=$(mktemp -t ndb-rhel-image-candidates.XXXXXX)
  matches_file=$(mktemp -t ndb-rhel-images.XXXXXX)
  records_file=$(mktemp -t ndb-rhel-image-records.XXXXXX)
  : > "$records_file"

  response=$(prism_list_all_entities images image)
  jq -c '
    .entities[]?
    | {
        name: (.spec.name // .status.name // ""),
        uuid: (.metadata.uuid // ""),
        state: (.status.state // "")
      }
    | select(.name | test("rhel|red hat|redhat|enterprise linux"; "i"))
    | select(.uuid != "" and .name != "")
  ' <<<"$response" > "$candidates_file"

  while IFS= read -r candidate; do
    [[ -n "$candidate" ]] || continue

    name=$(jq -r '.name' <<<"$candidate")
    uuid=$(jq -r '.uuid' <<<"$candidate")
    state=$(jq -r '.state' <<<"$candidate")
    cluster_count=0

    if detail_json=$(prism_image_json "$uuid" 2>/dev/null); then
      name=$(jq -r --arg fallback "$name" '.spec.name // .status.name // $fallback' <<<"$detail_json")
      state=$(jq -r --arg fallback "$state" '.status.state // $fallback' <<<"$detail_json")
      cluster_count=$(jq -r '
        [
          (.status.resources.cluster_reference_list // [])[]?,
          (.status.resources.current_cluster_reference_list // [])[]?,
          (.status.resources.initial_placement_ref_list // [])[]?,
          (.spec.resources.initial_placement_ref_list // [])[]?,
          (.status.cluster_reference_list // [])[]?
        ]
        | length
      ' <<<"$detail_json")
    fi

    jq -nc \
      --arg name "$name" \
      --arg uuid "$uuid" \
      --arg state "$state" \
      --argjson cluster_count "$cluster_count" \
      '{name: $name, uuid: $uuid, state: $state, cluster_count: $cluster_count}' >> "$records_file"
  done < "$candidates_file"

  jq -s '.' "$records_file" > "$matches_file"

  count=$(jq 'length' "$matches_file")
  active_count=$(jq '[.[] | select(.cluster_count > 0)] | length' "$matches_file")
  printf '\nStaged RHEL-like Prism images: %s\n' "$count"
  printf 'Active RHEL-like Prism images: %s\n' "$active_count"

  if [[ "$count" == "0" ]]; then
    printf 'No staged Prism images matched RHEL naming.\n'
    rm -f "$candidates_file" "$matches_file" "$records_file"
    return 0
  fi

  if [[ "$SHOW_PRISM_MATCHES" == "true" ]]; then
    jq -r '.[] | "- \(.uuid)\t\(.name)\tstate=\(.state)\tclusters=\(.cluster_count)\tavailability=\(if .cluster_count > 0 then "active" else "inactive" end)"' "$matches_file"
  else
    printf 'Use --show-prism-matches to print matching image UUIDs and names.\n'
  fi

  rm -f "$candidates_file" "$matches_file" "$records_file"
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
uri_211_ready=false
uuid_211_ready=false

printf 'RHEL source URI readiness (9.6/9.7 core): '
if all_set "${RHEL_CORE_URI_VARS[@]}"; then
  uri_ready=true
  printf 'complete\n'
else
  printf 'incomplete\n'
fi
for name in "${RHEL_URI_VARS[@]}"; do
  env_status "$name" || true
done

printf '\nRHEL source URI readiness (2.11: 9.8/10): '
if all_set NDB_RHEL_9_8_IMAGE_URI NDB_RHEL_10_IMAGE_URI; then
  uri_211_ready=true
  printf 'complete\n'
else
  printf 'incomplete\n'
fi

printf '\nRHEL staged image UUID readiness (9.6/9.7 core): '
if all_set "${RHEL_CORE_UUID_VARS[@]}"; then
  uuid_ready=true
  printf 'complete\n'
else
  printf 'incomplete\n'
fi
for name in "${RHEL_UUID_VARS[@]}"; do
  env_status "$name" || true
done

printf '\nRHEL staged image UUID readiness (2.11: 9.8/10): '
if all_set RHEL_98_UUID RHEL_10_UUID; then
  uuid_211_ready=true
  printf 'complete\n'
else
  printf 'incomplete\n'
fi

printf '\nRHEL activation key readiness: '
if all_set NDB_RHEL_ORGID NDB_RHEL_ACTIVATIONKEY; then
  printf 'complete\n'
else
  printf 'incomplete\n'
fi
env_status NDB_RHEL_ORGID || true
env_status NDB_RHEL_ACTIVATIONKEY || true

if [[ "$uri_211_ready" != "true" && "$uuid_211_ready" != "true" ]]; then
  if any_set NDB_RHEL_9_8_IMAGE_URI NDB_RHEL_10_IMAGE_URI RHEL_98_UUID RHEL_10_UUID; then
    printf '\nNote: NDB 2.11 RHEL 9.8/10 inputs are partially set; finish both versions before auditing full 2.11 RHEL coverage.\n'
  else
    printf '\nNote: NDB 2.11 RHEL 9.8/10 inputs are optional until you build those matrix rows.\n'
  fi
fi

if [[ "$SCAN_PRISM" == "true" ]]; then
  scan_prism_images
fi

print_commands "$uri_ready" "$uuid_ready"

if [[ "$uri_ready" == "true" || "$uuid_ready" == "true" ]]; then
  exit 0
fi

exit 1
