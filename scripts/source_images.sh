#!/usr/bin/env bash

SOURCE_IMAGES_SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/prism.sh
source "${SOURCE_IMAGES_SCRIPT_DIR}/prism.sh"

source_image_normalize_key_part() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g'
}

source_image_key_for_os() {
  local os_type=$1
  local os_version=$2

  case "$os_type" in
    "Red Hat Enterprise Linux (RHEL)"|"RHEL")
      printf 'rhel-%s\n' "$os_version"
      ;;
    "Rocky Linux")
      printf 'rocky-linux-%s\n' "$os_version"
      ;;
    "Ubuntu Linux")
      printf 'ubuntu-linux-%s\n' "$os_version"
      ;;
    *)
      printf '%s-%s\n' "$(source_image_normalize_key_part "$os_type")" "$os_version"
      ;;
  esac
}

source_image_resolve_from_images_json() {
  local images_file=$1
  local image_key=$2
  local entry_type

  entry_type=$(jq -r --arg key "$image_key" 'if has($key) then (.[$key] | type) else "missing" end' "$images_file")

  case "$entry_type" in
    string)
      jq -r --arg key "$image_key" '.[$key]' "$images_file"
      ;;
    object)
      local env_var description
      env_var=$(jq -r --arg key "$image_key" '.[$key].env_var // ""' "$images_file")
      description=$(jq -r --arg key "$image_key" '.[$key].description // ""' "$images_file")

      if [[ -z "$env_var" ]]; then
        printf 'Error: images.json entry %s must define env_var when using object syntax.\n' "$image_key" >&2
        return 1
      fi

      if [[ -z "${!env_var:-}" ]]; then
        printf 'Error: source image for %s requires environment variable %s.\n' "$image_key" "$env_var" >&2
        if [[ -n "$description" ]]; then
          printf '%s\n' "$description" >&2
        fi
        return 1
      fi

      printf '%s\n' "${!env_var}"
      ;;
    missing)
      printf 'Error: no source image entry for %s in %s.\n' "$image_key" "$images_file" >&2
      return 1
      ;;
    *)
      printf 'Error: unsupported image entry type %s for %s.\n' "$entry_type" "$image_key" >&2
      return 1
      ;;
  esac
}

source_image_name_from_uri() {
  local source_uri=$1
  basename "${source_uri%%\?*}"
}

source_image_value_is_real() {
  local value=${1:-}
  [[ -n "$value" && "$value" != "<not used>" && "$value" != "<temporary local file created at runtime>" && "$value" != "<unresolved"* ]]
}

source_image_preflight() {
  local source_image_name="" source_image_uuid="" source_image_uri="" source_image_path="" cluster_name="" subnet_name=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --source-image-name)
        source_image_name=$2
        shift
        ;;
      --source-image-uuid)
        source_image_uuid=$2
        shift
        ;;
      --source-image-uri)
        source_image_uri=$2
        shift
        ;;
      --source-image-path)
        source_image_path=$2
        shift
        ;;
      --cluster-name)
        cluster_name=$2
        shift
        ;;
      --subnet-name)
        subnet_name=$2
        shift
        ;;
      *)
        printf 'Error: unknown source image preflight argument: %s\n' "$1" >&2
        return 1
        ;;
    esac
    shift
  done

  prism_require_env || return 1

  if [[ -n "$cluster_name" && -z "$(prism_cluster_uuid_by_name "$cluster_name")" ]]; then
    printf 'Error: Prism cluster not found: %s\n' "$cluster_name" >&2
    return 1
  fi

  if [[ -n "$subnet_name" && -z "$(prism_subnet_uuid_by_name "$subnet_name")" ]]; then
    printf 'Error: Prism subnet not found: %s\n' "$subnet_name" >&2
    return 1
  fi

  if source_image_value_is_real "$source_image_name" && [[ -z "$(prism_image_uuid_by_name "$source_image_name")" ]]; then
    printf 'Error: source image does not exist in Prism: %s\n' "$source_image_name" >&2
    return 1
  fi

  if source_image_value_is_real "$source_image_uuid" && ! prism_image_uuid_exists "$source_image_uuid"; then
    printf 'Error: source image UUID does not exist in Prism: %s\n' "$source_image_uuid" >&2
    return 1
  fi

  if source_image_value_is_real "$source_image_path" && [[ ! -f "$source_image_path" ]]; then
    printf 'Error: source image path does not exist: %s\n' "$source_image_path" >&2
    return 1
  fi

  if source_image_value_is_real "$source_image_uri"; then
    printf 'Source image URI is ready for staging or Packer import: %s\n' "$source_image_uri"
  fi
}

source_image_stage_remote_uri() {
  local source_uri=$1
  local cluster_uuid=$2
  local image_name=${3:-}
  local timeout_seconds=${4:-3600}
  local existing_uuid payload response task_uuid

  if [[ -z "$image_name" ]]; then
    image_name=$(source_image_name_from_uri "$source_uri")
  fi

  existing_uuid=$(prism_image_uuid_by_name "$image_name")
  if [[ -n "$existing_uuid" ]]; then
    printf 'Reusing existing Prism image: %s\n' "$image_name" >&2
    printf '%s\n' "$image_name"
    return 0
  fi

  payload=$(jq -nc \
    --arg image_name "$image_name" \
    --arg source_uri "$source_uri" \
    --arg cluster_uuid "$cluster_uuid" \
    '{
      spec: {
        name: $image_name,
        description: "staged by NDB build tooling",
        resources: {
          image_type: "DISK_IMAGE",
          source_uri: $source_uri,
          initial_placement_ref_list: [
            {kind: "cluster", uuid: $cluster_uuid}
          ]
        }
      },
      metadata: {kind: "image"}
    }')

  response=$(prism_curl POST "/api/nutanix/v3/images" "$payload")
  task_uuid=$(jq -r '(.status.execution_context.task_uuid // .status.execution_context.task_uuid_list // empty) | if type == "array" then .[0] else . end // ""' <<<"$response")
  if [[ -z "$task_uuid" || "$task_uuid" == "null" ]]; then
    printf 'Error: Prism image create response did not include a task UUID.\n%s\n' "$response" >&2
    return 1
  fi

  if ! prism_wait_task "$task_uuid" "$timeout_seconds" 15 >/dev/null; then
    printf 'Source image staging is still running or failed. Task UUID: %s\n' "$task_uuid" >&2
    printf 'Retry after the import finishes with: --source-image-name "%s"\n' "$image_name" >&2
    return 1
  fi

  printf '%s\n' "$image_name"
}
