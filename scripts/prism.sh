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
  # shellcheck disable=SC2154  # PKR_VAR_* are provided via the environment (.env / op run)
  prism_endpoint_from_host "$PKR_VAR_pc_ip"
}

prism_curl_config_escape() {
  local value=${1//\\/\\\\}
  printf '%s' "${value//\"/\\\"}"
}

prism_curl() {
  local method=$1
  local path=$2
  local payload=${3:-}
  local endpoint
  local response_file
  local http_status
  local curl_rc
  local curl_config
  local -a curl_args

  endpoint=$(prism_endpoint) || return 1
  response_file=$(mktemp -t ndb-prism-response.XXXXXX)

  # Credentials travel to curl on stdin via --config so they never appear in
  # ps output while long task polls run.
  # shellcheck disable=SC2154  # PKR_VAR_* are provided via the environment (.env / op run)
  curl_config=$(printf 'user = "%s:%s"' \
    "$(prism_curl_config_escape "$PKR_VAR_pc_username")" \
    "$(prism_curl_config_escape "$PKR_VAR_pc_password")")

  curl_args=(
    -sS
    --config -
    --connect-timeout "${PRISM_API_CONNECT_TIMEOUT:-15}"
    --max-time "${PRISM_API_MAX_TIME:-300}"
    -H "Content-Type: application/json"
    -X "$method"
    -o "$response_file"
    -w "%{http_code}"
  )
  # TLS verification is on by default; set PKR_VAR_nutanix_insecure=true for
  # labs with self-signed Prism certificates (matches the Packer variable).
  case "${PKR_VAR_nutanix_insecure:-false}" in
    [Tt][Rr][Uu][Ee]|1|[Yy][Ee][Ss])
      curl_args+=(-k)
      ;;
  esac
  if [[ -n "$payload" ]]; then
    curl_args+=(-d "$payload")
  fi

  http_status=$(curl "${curl_args[@]}" "${endpoint}${path}" <<<"$curl_config") || curl_rc=$?

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
  local offset=${4:-0}
  local payload

  payload=$(jq -nc --arg kind "$kind" --argjson length "$length" --argjson offset "$offset" '{kind: $kind, length: $length, offset: $offset}') || return 1
  prism_curl POST "/api/nutanix/v3/${resource}/list" "$payload"
}

# Prism v3 list endpoints cap page sizes server-side, so a single large-length
# request can silently miss entities. Emits one JSON document per page; safe
# for consumers that stream .entities[]?.
prism_list_all_entities() {
  local resource=$1
  local kind=$2
  local page_length=${3:-500}
  local offset=0
  local page
  local count

  while :; do
    page=$(prism_list_resource "$resource" "$kind" "$page_length" "$offset") || return 1
    printf '%s\n' "$page"
    count=$(jq -r '.entities | length' <<<"$page") || return 1
    if (( count < page_length )); then
      break
    fi
    offset=$((offset + page_length))
  done
}

prism_find_uuid_by_name() {
  local resource=$1
  local kind=$2
  local name=$3
  local page_length=500
  local offset=0
  local page
  local count
  local uuid

  # Paged loop instead of one capped list call; no cross-page pipeline so an
  # early match cannot SIGPIPE the producer under pipefail.
  while :; do
    page=$(prism_list_resource "$resource" "$kind" "$page_length" "$offset") || return 1
    uuid=$(jq -r --arg name "$name" 'first(.entities[]? | select((.spec.name // .status.name // "") == $name) | .metadata.uuid) // empty' <<<"$page") || return 1
    if [[ -n "$uuid" ]]; then
      printf '%s\n' "$uuid"
      return 0
    fi
    count=$(jq -r '.entities | length' <<<"$page") || return 1
    if (( count < page_length )); then
      return 0
    fi
    offset=$((offset + page_length))
  done
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

prism_extract_task_uuid() {
  jq -r '(.status.execution_context.task_uuid
          // .status.execution_context.task_uuid_list
          // .task_uuid
          // "")
         | if type == "array" then (.[0] // "") else . end'
}

prism_wait_task_from_response() {
  local response=$1
  local task_uuid
  task_uuid=$(prism_extract_task_uuid <<<"$response")
  if [[ -n "$task_uuid" ]]; then
    prism_wait_task "$task_uuid" >/dev/null
  fi
}

prism_wait_required_task_from_response() {
  local response=$1
  local action=$2
  local task_uuid
  task_uuid=$(prism_extract_task_uuid <<<"$response")
  if [[ -z "$task_uuid" ]]; then
    printf 'Error: Prism %s response did not include a task UUID.\n' "$action" >&2
    return 1
  fi
  prism_wait_task "$task_uuid" >/dev/null
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
