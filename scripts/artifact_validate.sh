#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=scripts/prism.sh
source "$ROOT_DIR/scripts/prism.sh"

IMAGE_NAME=""
NDB_VERSION=""
DB_VERSION=""
DB_TYPE="pgsql"
EXTENSIONS_JSON="[]"
PROVISIONING_ROLE=""
MONGODB_EDITION="community"
MONGODB_DEPLOYMENTS_JSON="[]"
RESULT_FILE=""
KEEP_ON_FAILURE=false
VM_NAME=""
VM_UUID=""
IMAGE_UUID=""
CLEANUP_STATUS="not-started"
FINAL_STATUS="failed"
TMPDIR=""

usage() {
  cat <<'EOF'
Usage: scripts/artifact_validate.sh --image-name NAME --ndb-version VERSION --db-version VERSION [options]

Options:
  --image-name NAME      Saved Prism image name to validate
  --ndb-version VERSION  NDB/Ansible version to use, for example 2.10
  --db-version VERSION   PostgreSQL major version expected in the image
  --db-type TYPE         Database type expected in the image (default: pgsql)
  --extensions JSON      Matrix extension list JSON (default: [])
  --provisioning-role ROLE
                         Provisioning role from the selected matrix row
  --mongodb-edition EDITION
                         MongoDB edition: community or enterprise
  --mongodb-deployments JSON
                         MongoDB deployment list JSON (default: [])
  --result-file FILE     Write validation result JSON to FILE
  --keep-on-failure      Keep the disposable VM if validation fails
  -h, --help             Show this help and exit
EOF
}

require_option_value() {
  local option=$1
  local remaining_args=$2
  if (( remaining_args < 2 )); then
    printf 'Error: %s requires a value.\n' "$option" >&2
    usage >&2
    exit 1
  fi
}

require_command() {
  local missing=()
  local cmd
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing+=("$cmd")
    fi
  done
  if (( ${#missing[@]} > 0 )); then
    printf 'Error: required commands not found: %s\n' "${missing[*]}" >&2
    exit 1
  fi
}

require_file() {
  local file=$1
  if [[ ! -f "$file" ]]; then
    printf 'Error: required file not found: %s\n' "$file" >&2
    exit 1
  fi
}

json_string_array() {
  local json=$1
  jq -ce 'if type == "array" and all(.[]; type == "string" and length > 0) then . else error("expected JSON array of non-empty strings") end' <<<"$json"
}

json_mongodb_deployments() {
  local json=$1
  jq -ce 'if type == "array" and all(.[]; type == "string" and (. == "single-instance" or . == "replica-set" or . == "sharded-cluster")) then . else error("expected MongoDB deployment array") end' <<<"$json"
}

base64_no_wrap() {
  base64 | tr -d '\n'
}

extract_task_uuid() {
  jq -r '.status.execution_context.task_uuid // .task_uuid // ""'
}

wait_task_from_response() {
  local response=$1
  local task_uuid
  task_uuid=$(extract_task_uuid <<<"$response")
  if [[ -n "$task_uuid" ]]; then
    prism_wait_task "$task_uuid" >/dev/null
  fi
}

wait_required_task_from_response() {
  local response=$1
  local action=$2
  local task_uuid
  task_uuid=$(extract_task_uuid <<<"$response")
  if [[ -z "$task_uuid" ]]; then
    printf 'Error: Prism %s response did not include a task UUID.\n' "$action" >&2
    return 1
  fi
  prism_wait_task "$task_uuid" >/dev/null
}

write_result() {
  local status=$1
  if [[ -z "$RESULT_FILE" ]]; then
    return
  fi

  mkdir -p "$(dirname "$RESULT_FILE")"
  jq -n \
    --arg image_name "$IMAGE_NAME" \
    --arg image_uuid "$IMAGE_UUID" \
    --arg vm_name "$VM_NAME" \
    --arg vm_uuid "$VM_UUID" \
    --arg status "$status" \
    --arg cleanup_status "$CLEANUP_STATUS" \
    '{
      image_name: $image_name,
      image_uuid: $image_uuid,
      vm_name: $vm_name,
      vm_uuid: $vm_uuid,
      artifact_vm_name: $vm_name,
      artifact_vm_uuid: $vm_uuid,
      status: $status,
      cleanup_status: $cleanup_status,
      cleanup: {
        artifact_validation_vm: $cleanup_status
      }
    }' > "$RESULT_FILE"
}

cleanup_vm() {
  local delete_response

  if [[ -z "$VM_UUID" ]]; then
    CLEANUP_STATUS="not-created"
    return 0
  fi

  if [[ "$FINAL_STATUS" != "passed" && "$KEEP_ON_FAILURE" == "true" ]]; then
    CLEANUP_STATUS="kept-on-failure"
    return 0
  fi

  CLEANUP_STATUS="deleting"
  if delete_response=$(prism_delete_vm "$VM_UUID"); then
    wait_task_from_response "$delete_response" || {
      CLEANUP_STATUS="delete-task-failed"
      return 1
    }
    CLEANUP_STATUS="deleted"
  else
    CLEANUP_STATUS="delete-request-failed"
    return 1
  fi
}

on_exit() {
  local status=$?
  local cleanup_status=0
  if [[ "$status" -eq 0 ]]; then
    FINAL_STATUS="passed"
  fi

  cleanup_vm || cleanup_status=$?
  if [[ "$status" -eq 0 && "$cleanup_status" -ne 0 ]]; then
    FINAL_STATUS="failed"
    status="$cleanup_status"
  fi
  write_result "$FINAL_STATUS" || true
  if [[ -n "$TMPDIR" ]]; then
    rm -rf "$TMPDIR"
  fi
  exit "$status"
}
trap on_exit EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image-name)
      require_option_value "$1" "$#"
      IMAGE_NAME=$2
      shift
      ;;
    --ndb-version)
      require_option_value "$1" "$#"
      NDB_VERSION=$2
      shift
      ;;
    --db-version)
      require_option_value "$1" "$#"
      DB_VERSION=$2
      shift
      ;;
    --db-type)
      require_option_value "$1" "$#"
      DB_TYPE=$2
      shift
      ;;
    --extensions)
      require_option_value "$1" "$#"
      EXTENSIONS_JSON=$2
      shift
      ;;
    --provisioning-role)
      require_option_value "$1" "$#"
      PROVISIONING_ROLE=$2
      shift
      ;;
    --mongodb-edition)
      require_option_value "$1" "$#"
      MONGODB_EDITION=$2
      shift
      ;;
    --mongodb-deployments)
      require_option_value "$1" "$#"
      MONGODB_DEPLOYMENTS_JSON=$2
      shift
      ;;
    --result-file)
      require_option_value "$1" "$#"
      RESULT_FILE=$2
      shift
      ;;
    --keep-on-failure)
      KEEP_ON_FAILURE=true
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

if [[ -z "$IMAGE_NAME" || -z "$NDB_VERSION" || -z "$DB_VERSION" ]]; then
  printf 'Error: --image-name, --ndb-version, and --db-version are required.\n' >&2
  usage >&2
  exit 1
fi

EXTENSIONS_JSON=$(json_string_array "$EXTENSIONS_JSON")
MONGODB_DEPLOYMENTS_JSON=$(json_mongodb_deployments "$MONGODB_DEPLOYMENTS_JSON")
PROVISIONING_ROLE=${PROVISIONING_ROLE:-$([[ "$DB_TYPE" == "mongodb" ]] && echo "mongodb" || echo "postgresql")}
case "$PROVISIONING_ROLE" in
  postgresql|mongodb)
    ;;
  *)
    printf 'Error: unsupported provisioning role for artifact validation: %s\n' "$PROVISIONING_ROLE" >&2
    exit 1
    ;;
esac

VALIDATION_ROLE="validate_postgres"
LOAD_POSTGRES_DEFAULTS=true
if [[ "$DB_TYPE" == "mongodb" || "$PROVISIONING_ROLE" == "mongodb" ]]; then
  VALIDATION_ROLE="validate_mongodb"
  LOAD_POSTGRES_DEFAULTS=false
fi

prism_require_env
require_command jq curl ssh ansible-playbook base64

PRIVATE_KEY_PATH="$ROOT_DIR/packer/id_rsa"
PUBLIC_KEY_PATH="$ROOT_DIR/packer/id_rsa.pub"
USER_DATA_TEMPLATE="$ROOT_DIR/packer/http/user-data"
ANSIBLE_DIR="$ROOT_DIR/ansible/$NDB_VERSION"
ANSIBLE_CFG_PATH="$ANSIBLE_DIR/ansible.cfg"
POSTGRES_DEFAULTS="$ANSIBLE_DIR/roles/postgres/defaults/main.yml"

require_file "$PRIVATE_KEY_PATH"
require_file "$PUBLIC_KEY_PATH"
require_file "$USER_DATA_TEMPLATE"
require_file "$ANSIBLE_CFG_PATH"
if [[ "$LOAD_POSTGRES_DEFAULTS" == "true" ]]; then
  require_file "$POSTGRES_DEFAULTS"
fi

if [[ -z "${PKR_VAR_cluster_name:-}" || -z "${PKR_VAR_subnet_name:-}" ]]; then
  printf 'Error: PKR_VAR_cluster_name and PKR_VAR_subnet_name are required for artifact validation.\n' >&2
  exit 1
fi

IMAGE_UUID=$(prism_image_uuid_by_name "$IMAGE_NAME")
if [[ -z "$IMAGE_UUID" ]]; then
  printf 'Error: could not find saved Prism image named %s.\n' "$IMAGE_NAME" >&2
  exit 1
fi

CLUSTER_UUID=$(prism_cluster_uuid_by_name "$PKR_VAR_cluster_name")
if [[ -z "$CLUSTER_UUID" ]]; then
  printf 'Error: could not find Prism cluster named %s.\n' "$PKR_VAR_cluster_name" >&2
  exit 1
fi

SUBNET_UUID=$(prism_subnet_uuid_by_name "$PKR_VAR_subnet_name")
if [[ -z "$SUBNET_UUID" ]]; then
  printf 'Error: could not find Prism subnet named %s.\n' "$PKR_VAR_subnet_name" >&2
  exit 1
fi

TIMESTAMP=$(date +%Y%m%d%H%M%S)
VM_NAME="validate-${IMAGE_NAME:0:45}-${TIMESTAMP}"
TMPDIR=$(mktemp -d)

SSH_PUBLIC_KEY=$(tr -d '\n' < "$PUBLIC_KEY_PATH")
USER_DATA_B64=$(sed "s|\${ssh_public_key}|${SSH_PUBLIC_KEY}|g" "$USER_DATA_TEMPLATE" | base64_no_wrap)

CREATE_PAYLOAD=$(jq -n \
  --arg vm_name "$VM_NAME" \
  --arg cluster_uuid "$CLUSTER_UUID" \
  --arg subnet_uuid "$SUBNET_UUID" \
  --arg image_uuid "$IMAGE_UUID" \
  --arg user_data "$USER_DATA_B64" \
  '{
    spec: {
      name: $vm_name,
      cluster_reference: {
        kind: "cluster",
        uuid: $cluster_uuid
      },
      resources: {
        num_sockets: 2,
        num_vcpus_per_socket: 1,
        memory_size_mib: 4096,
        power_state: "OFF",
        disk_list: [
          {
            data_source_reference: {
              kind: "image",
              uuid: $image_uuid
            },
            device_properties: {
              device_type: "DISK",
              disk_address: {
                adapter_type: "SCSI",
                device_index: 0
              }
            }
          }
        ],
        nic_list: [
          {
            subnet_reference: {
              kind: "subnet",
              uuid: $subnet_uuid
            },
            is_connected: true
          }
        ],
        guest_customization: {
          cloud_init: {
            user_data: $user_data
          }
        }
      }
    },
    metadata: {
      kind: "vm"
    }
  }')

printf 'Creating disposable validation VM %s from image %s...\n' "$VM_NAME" "$IMAGE_NAME"
CREATE_RESPONSE=$(prism_curl POST /api/nutanix/v3/vms "$CREATE_PAYLOAD")
VM_UUID=$(jq -r '.metadata.uuid // ""' <<<"$CREATE_RESPONSE")
if [[ -z "$VM_UUID" ]]; then
  printf 'Error: Prism create response did not include VM UUID.\n' >&2
  exit 1
fi
wait_required_task_from_response "$CREATE_RESPONSE" "create VM"

printf 'Powering on validation VM %s...\n' "$VM_UUID"
POWER_RESPONSE=$(prism_power_on_vm "$VM_UUID")
wait_required_task_from_response "$POWER_RESPONSE" "power on VM"

printf 'Waiting for validation VM IP...\n'
VM_IP=""
for _ in {1..90}; do
  VM_IP=$(prism_vm_ip "$VM_UUID")
  if [[ -n "$VM_IP" ]]; then
    break
  fi
  sleep 10
done
if [[ -z "$VM_IP" ]]; then
  printf 'Error: timed out waiting for validation VM IP.\n' >&2
  exit 1
fi

printf 'Waiting for SSH on %s...\n' "$VM_IP"
SSH_COMMON_ARGS=(
  -i "$PRIVATE_KEY_PATH"
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  -o IdentitiesOnly=yes
  -o IdentityAgent=none
  -o BatchMode=yes
  -o ConnectTimeout=10
)
for _ in {1..90}; do
  if ssh "${SSH_COMMON_ARGS[@]}" "packer@${VM_IP}" true >/dev/null 2>&1; then
    break
  fi
  sleep 10
done
ssh "${SSH_COMMON_ARGS[@]}" "packer@${VM_IP}" true >/dev/null

cat > "$TMPDIR/inventory" <<EOF
[validation]
${VM_IP} ansible_user=packer ansible_ssh_private_key_file=${PRIVATE_KEY_PATH} ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o IdentityAgent=none'
EOF

cat > "$TMPDIR/validate.yml" <<EOF
---
- name: Validate saved NDB image artifact
  hosts: validation
  roles:
    - ${VALIDATION_ROLE}
EOF

jq -n \
  --arg db_version "$DB_VERSION" \
  --arg db_type "$DB_TYPE" \
  --arg provisioning_role "$PROVISIONING_ROLE" \
  --arg mongodb_edition "$MONGODB_EDITION" \
  --argjson postgres_extensions "$EXTENSIONS_JSON" \
  --argjson mongodb_deployments "$MONGODB_DEPLOYMENTS_JSON" \
  '{
    db_version: $db_version,
    db_type: $db_type,
    provisioning_role: $provisioning_role,
    configure_ndb_sudoers: true,
    postgres_extensions: $postgres_extensions,
    postgres_extensions_databases: ["postgres"],
    mongodb_edition: $mongodb_edition,
    mongodb_deployments: $mongodb_deployments
  }' > "$TMPDIR/vars.json"

printf 'Running artifact validation playbook against %s...\n' "$VM_IP"
ANSIBLE_PLAYBOOK_CMD=(
  ansible-playbook
  -e "ansible_ssh_private_key_file=${PRIVATE_KEY_PATH}"
  -i "$TMPDIR/inventory"
  "$TMPDIR/validate.yml"
)
if [[ "$LOAD_POSTGRES_DEFAULTS" == "true" ]]; then
  ANSIBLE_PLAYBOOK_CMD+=(-e "@${POSTGRES_DEFAULTS}")
fi
ANSIBLE_PLAYBOOK_CMD+=(
  -e "@${TMPDIR}/vars.json"
)
ANSIBLE_CONFIG="$ANSIBLE_CFG_PATH" ANSIBLE_ROLES_PATH="$ANSIBLE_DIR/roles" "${ANSIBLE_PLAYBOOK_CMD[@]}"

FINAL_STATUS="passed"
