#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=scripts/prism.sh
source "$ROOT_DIR/scripts/prism.sh"
# shellcheck source=scripts/source_images.sh
source "$ROOT_DIR/scripts/source_images.sh"

IMAGE_UUID=""
CLUSTER_NAME=""
APPLY=false
WAIT_TIMEOUT_SECONDS=1800

usage() {
  cat <<'EOF'
Usage: scripts/prism_image_activate.sh --image-uuid UUID --cluster-name NAME [--apply]

Adds the selected Prism cluster to an existing image's initial placement list.
By default this is a dry-run that prints the planned action and makes no Prism
changes. Pass --apply to submit the Prism image update and wait for completion.

Options:
  --image-uuid UUID       Existing Prism image UUID
  --cluster-name NAME     Prism cluster name that should host the image
  --wait-timeout SECONDS  Seconds to wait for the update task (default: 1800)
  --apply                 Submit the update to Prism
  -h, --help              Show this help and exit
EOF
}

require_option_value() {
  local option=$1
  local remaining=$2

  if (( remaining < 2 )); then
    printf 'Error: %s requires a value.\n' "$option" >&2
    usage >&2
    exit 1
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image-uuid)
      require_option_value "$1" "$#"
      IMAGE_UUID=$2
      shift
      ;;
    --cluster-name)
      require_option_value "$1" "$#"
      CLUSTER_NAME=$2
      shift
      ;;
    --wait-timeout)
      require_option_value "$1" "$#"
      WAIT_TIMEOUT_SECONDS=$2
      shift
      ;;
    --apply)
      APPLY=true
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

if [[ -z "$IMAGE_UUID" || -z "$CLUSTER_NAME" ]]; then
  printf 'Error: --image-uuid and --cluster-name are required.\n' >&2
  usage >&2
  exit 1
fi

prism_require_env >/dev/null

CLUSTER_UUID=$(prism_cluster_uuid_by_name "$CLUSTER_NAME")
if [[ -z "$CLUSTER_UUID" ]]; then
  printf 'Error: Prism cluster not found: %s\n' "$CLUSTER_NAME" >&2
  exit 1
fi

IMAGE_JSON=$(prism_image_json "$IMAGE_UUID")
IMAGE_NAME=$(jq -r '.spec.name // .status.name // ""' <<<"$IMAGE_JSON")
if [[ -z "$IMAGE_NAME" ]]; then
  IMAGE_NAME="$IMAGE_UUID"
fi

if source_image_json_active_on_cluster "$IMAGE_JSON" "$CLUSTER_UUID"; then
  printf 'Image is already active on the selected Prism cluster: %s\n' "$IMAGE_NAME"
  exit 0
fi

UPDATE_PAYLOAD=$(jq -c --arg cluster_uuid "$CLUSTER_UUID" '
  {
    metadata: .metadata,
    spec: (
      .spec
      | .resources.initial_placement_ref_list = (
          (
            (.resources.initial_placement_ref_list // [])
            + [{kind: "cluster", uuid: $cluster_uuid}]
          )
          | unique_by(.uuid)
        )
    )
  }
' <<<"$IMAGE_JSON")

printf 'Image: %s\n' "$IMAGE_NAME"
printf 'Image UUID: %s\n' "$IMAGE_UUID"
printf 'Target cluster: %s\n' "$CLUSTER_NAME"

if [[ "$APPLY" != "true" ]]; then
  printf 'Dry run: no Prism changes made. Re-run with --apply to update image placement.\n'
  exit 0
fi

RESPONSE=$(prism_curl PUT "/api/nutanix/v3/images/${IMAGE_UUID}" "$UPDATE_PAYLOAD")
TASK_UUID=$(jq -r '.status.execution_context.task_uuid // .task_uuid // ""' <<<"$RESPONSE")
if [[ -z "$TASK_UUID" ]]; then
  printf 'Error: Prism image update response did not include a task UUID.\n%s\n' "$RESPONSE" >&2
  exit 1
fi

prism_wait_task "$TASK_UUID" "$WAIT_TIMEOUT_SECONDS" 10 >/dev/null
printf 'Activation task completed: %s\n' "$TASK_UUID"
