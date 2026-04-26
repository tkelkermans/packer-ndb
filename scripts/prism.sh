#!/usr/bin/env bash

prism_endpoint_from_host() {
  local host=$1

  if [[ "$host" == http://* || "$host" == https://* ]]; then
    printf '%s\n' "${host%/}"
  elif [[ "$host" == *:* ]]; then
    printf 'https://%s\n' "${host%/}"
  else
    printf 'https://%s:9440\n' "${host%/}"
  fi
}

prism_require_env() {
  local missing=()
  local var_name

  for var_name in PKR_VAR_pc_username PKR_VAR_pc_password PKR_VAR_pc_ip; do
    if [[ -z "${!var_name:-}" ]]; then
      missing+=("$var_name")
    fi
  done

  if (( ${#missing[@]} > 0 )); then
    printf 'Error: missing Prism environment variables: %s\n' "${missing[*]}" >&2
    return 1
  fi
}

prism_endpoint() {
  prism_require_env || return 1
  prism_endpoint_from_host "$PKR_VAR_pc_ip"
}

prism_curl() {
  local method=$1
  local path=$2
  local payload=${3:-}
  local endpoint
  local response_file
  local http_status
  local curl_rc

  endpoint=$(prism_endpoint) || return 1
  response_file=$(mktemp -t ndb-prism-response.XXXXXX)

  if [[ -n "$payload" ]]; then
    http_status=$(curl -sS -k -u "${PKR_VAR_pc_username}:${PKR_VAR_pc_password}" \
      -H "Content-Type: application/json" \
      -X "$method" \
      -d "$payload" \
      -o "$response_file" \
      -w "%{http_code}" \
      "${endpoint}${path}") || curl_rc=$?
  else
    http_status=$(curl -sS -k -u "${PKR_VAR_pc_username}:${PKR_VAR_pc_password}" \
      -H "Content-Type: application/json" \
      -X "$method" \
      -o "$response_file" \
      -w "%{http_code}" \
      "${endpoint}${path}") || curl_rc=$?
  fi

  if [[ "${curl_rc:-0}" -ne 0 ]]; then
    rm -f "$response_file"
    return "$curl_rc"
  fi

  if [[ ! "$http_status" =~ ^2[0-9][0-9]$ ]]; then
    printf 'Error: Prism API %s %s returned HTTP %s\n' "$method" "$path" "$http_status" >&2
    sed 's/^/  /' "$response_file" >&2
    rm -f "$response_file"
    return 1
  fi

  cat "$response_file"
  rm -f "$response_file"
}

prism_list_resource() {
  local resource=$1
  local kind=$2
  local length=${3:-500}
  local payload

  payload=$(jq -nc --arg kind "$kind" --argjson length "$length" '{kind: $kind, length: $length}') || return 1
  prism_curl POST "/api/nutanix/v3/${resource}/list" "$payload"
}

prism_find_uuid_by_name() {
  local resource=$1
  local kind=$2
  local name=$3

  prism_list_resource "$resource" "$kind" 2000 \
    | jq -r --arg name "$name" '.entities[]? | select((.spec.name // .status.name // "") == $name) | .metadata.uuid' \
    | head -n 1
}

prism_image_uuid_by_name() {
  prism_find_uuid_by_name images image "$1"
}

prism_image_json() {
  local image_uuid=$1

  prism_curl GET "/api/nutanix/v3/images/${image_uuid}"
}

prism_image_uuid_exists() {
  local image_uuid=$1

  prism_image_json "$image_uuid" >/dev/null 2>&1
}

prism_vm_uuid_by_name() {
  prism_find_uuid_by_name vms vm "$1"
}

prism_cluster_uuid_by_name() {
  prism_find_uuid_by_name clusters cluster "$1"
}

prism_subnet_uuid_by_name() {
  prism_find_uuid_by_name subnets subnet "$1"
}

prism_task_json() {
  local task_uuid=$1

  prism_curl GET "/api/nutanix/v3/tasks/${task_uuid}"
}

prism_task_status() {
  local task_uuid=$1

  prism_task_json "$task_uuid" | jq -r '.status'
}

prism_wait_task() {
  local task_uuid=$1
  local timeout_seconds=${2:-1800}
  local interval_seconds=${3:-10}
  local elapsed=0
  local task
  local status
  local percent

  while (( elapsed <= timeout_seconds )); do
    task=$(prism_task_json "$task_uuid") || return 1
    status=$(jq -r '.status' <<<"$task")
    percent=$(jq -r '.percentage_complete // 0' <<<"$task")
    printf 'Prism task %s: %s %s%%\n' "$task_uuid" "$status" "$percent" >&2

    case "$status" in
      SUCCEEDED)
        printf '%s\n' "$task"
        return 0
        ;;
      FAILED)
        printf '%s\n' "$task" >&2
        return 1
        ;;
    esac

    sleep "$interval_seconds"
    elapsed=$((elapsed + interval_seconds))
  done

  printf 'Error: timed out waiting for Prism task %s after %s seconds.\n' "$task_uuid" "$timeout_seconds" >&2
  return 124
}

prism_vm_json() {
  local vm_uuid=$1

  prism_curl GET "/api/nutanix/v3/vms/${vm_uuid}"
}

prism_vm_ip() {
  local vm_uuid=$1

  prism_vm_json "$vm_uuid" | jq -r '.status.resources.nic_list[0].ip_endpoint_list[0].ip // ""'
}

prism_vm_power_state() {
  local vm_uuid=$1

  prism_vm_json "$vm_uuid" | jq -r '.status.resources.power_state // ""'
}

prism_power_on_vm() {
  local vm_uuid=$1
  local vm_json
  local payload

  vm_json=$(prism_vm_json "$vm_uuid") || return 1
  payload=$(jq '.spec.resources.power_state = "ON" | {api_version: .api_version, metadata: .metadata, spec: .spec}' <<<"$vm_json") || return 1
  prism_curl PUT "/api/nutanix/v3/vms/${vm_uuid}" "$payload"
}

prism_delete_vm() {
  local vm_uuid=$1

  prism_curl DELETE "/api/nutanix/v3/vms/${vm_uuid}"
}
