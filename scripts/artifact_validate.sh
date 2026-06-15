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
POSTGRES_HA_COMPONENTS_JSON="{}"
POSTGRES_QUALIFIED_VERSION_RANGE=""
POSTGRES_PACKAGE_VERSION_PREFIX=""
POSTGRES_PACKAGE_USE_ARCHIVE=false
PROVISIONING_ROLE=""
MONGODB_EDITION="community"
MONGODB_DEPLOYMENTS_JSON="[]"
CUSTOMIZATION_ENABLED=false
CUSTOMIZATION_PROFILE_NAME=""
CUSTOMIZATION_PROFILE_FILE=""
CUSTOMIZATION_ROLES_PATH_ENV=""
RESULT_FILE=""
KEEP_ON_FAILURE=false
VM_NAME=""
VM_UUID=""
VM_IP=""
IMAGE_UUID=""
CLEANUP_STATUS="not-started"
FINAL_STATUS="failed"
ARTIFACT_VALIDATE_WORKDIR=""

usage() {
  cat <<'EOF'
Usage: scripts/artifact_validate.sh --image-name NAME --ndb-version VERSION --db-version VERSION [options]

Options:
  --image-name NAME      Saved Prism image name to validate
  --ndb-version VERSION  NDB/Ansible version to use, for example 2.10
  --db-version VERSION   PostgreSQL major version expected in the image
  --db-type TYPE         Database type expected in the image (default: pgsql)
  --extensions JSON      Selected PostgreSQL extensions JSON (default: [])
  --postgres-ha-components JSON
                         PostgreSQL HA components JSON from the matrix row (default: {})
  --postgres-qualified-version-range RANGE
                         Human-readable PostgreSQL version range from the release notes
  --postgres-package-version-prefix VERSION
                         Required installed PostgreSQL patch prefix, for example 16.12
  --postgres-package-use-archive BOOL
                         Whether the build used the PGDG archive repository for the pin
  --provisioning-role ROLE
                         Provisioning role from the selected matrix row
  --mongodb-edition EDITION
                         MongoDB edition: community or enterprise
  --mongodb-deployments JSON
                         MongoDB deployment list JSON (default: [])
  --customization-enabled
                         Run selected customization validation roles
  --customization-profile-name NAME
                         Customization profile name for validation context
  --customization-profile-file FILE
                         Customization profile file to load
  --customization-roles-path PATH
                         ANSIBLE_ROLES_PATH value for custom roles
  --result-file FILE     Write validation result JSON to FILE
  --keep-on-failure      Keep the disposable VM if validation fails
  -h, --help             Show this help and exit

Environment:
  NDB_ARTIFACT_PRIVATE_KEY_PATH  Override packer/id_rsa for validation SSH
  NDB_ARTIFACT_PUBLIC_KEY_PATH   Override packer/id_rsa.pub for cloud-init
  NDB_ARTIFACT_USER_DATA_TEMPLATE
                                  Override saved-artifact validation cloud-init
                                  (default: packer/http/e2e-user-data)
  NDB_ARTIFACT_SSH_MAX_POLLS     SSH readiness attempts before failing (default: 90)
  NDB_ARTIFACT_SSH_POLL_SECONDS  Seconds between SSH readiness attempts (default: 10)
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

json_postgres_ha_components() {
  local json=$1
  jq -ce 'if type == "object" and all(.[]; type == "array" and all(.[]; type == "string" and length > 0)) then . else error("expected PostgreSQL HA components object") end' <<<"$json"
}

base64_no_wrap() {
  base64 | tr -d '\n'
}

guest_boot_ready_probe() {
  cat <<'EOF'
test -S /run/dbus/system_bus_socket || exit 1
state=$(systemctl is-system-running 2>/dev/null || true)
case "$state" in
  running|degraded) ;;
  *) exit 1 ;;
esac
if command -v cloud-init >/dev/null 2>&1; then
  cloud_state=$(cloud-init status 2>/dev/null || true)
  case "$cloud_state" in
    *"status: running"*) exit 1 ;;
  esac
fi
EOF
}

wait_guest_boot_ready() {
  local user=$1 ip=$2

  printf 'Waiting for systemd/D-Bus readiness on %s...\n' "$ip"
  for _ in $(seq 1 90); do
    if ssh "${SSH_COMMON_ARGS[@]}" "${user}@${ip}" "$(guest_boot_ready_probe)" >/dev/null 2>&1; then
      return 0
    fi
    sleep 10
  done

  ssh "${SSH_COMMON_ARGS[@]}" "${user}@${ip}" "systemctl is-system-running || true; ls -l /run/dbus/system_bus_socket || true; cloud-init status || true" >&2 || true
  ssh "${SSH_COMMON_ARGS[@]}" "${user}@${ip}" "$(guest_boot_ready_probe)" >/dev/null
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
    --arg vm_ip "$VM_IP" \
    --arg status "$status" \
    --arg cleanup_status "$CLEANUP_STATUS" \
    '{
      image_name: $image_name,
      image_uuid: $image_uuid,
      vm_name: $vm_name,
      vm_uuid: $vm_uuid,
      vm_ip: $vm_ip,
      artifact_vm_name: $vm_name,
      artifact_vm_uuid: $vm_uuid,
      artifact_vm_ip: $vm_ip,
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
    prism_wait_task_from_response "$delete_response" || {
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
  if [[ -n "$ARTIFACT_VALIDATE_WORKDIR" ]]; then
    rm -rf "$ARTIFACT_VALIDATE_WORKDIR"
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
    --postgres-ha-components)
      require_option_value "$1" "$#"
      POSTGRES_HA_COMPONENTS_JSON=$2
      shift
      ;;
    --postgres-qualified-version-range)
      require_option_value "$1" "$#"
      POSTGRES_QUALIFIED_VERSION_RANGE=$2
      shift
      ;;
    --postgres-package-version-prefix)
      require_option_value "$1" "$#"
      POSTGRES_PACKAGE_VERSION_PREFIX=$2
      shift
      ;;
    --postgres-package-use-archive)
      require_option_value "$1" "$#"
      POSTGRES_PACKAGE_USE_ARCHIVE=$2
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
    --customization-enabled)
      CUSTOMIZATION_ENABLED=true
      ;;
    --customization-profile-name)
      require_option_value "$1" "$#"
      CUSTOMIZATION_PROFILE_NAME=$2
      shift
      ;;
    --customization-profile-file)
      require_option_value "$1" "$#"
      CUSTOMIZATION_PROFILE_FILE=$2
      shift
      ;;
    --customization-roles-path)
      require_option_value "$1" "$#"
      CUSTOMIZATION_ROLES_PATH_ENV=$2
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

if [[ "$CUSTOMIZATION_ENABLED" == "true" && -z "$CUSTOMIZATION_PROFILE_FILE" ]]; then
  printf 'Error: --customization-profile-file is required when --customization-enabled is used.\n' >&2
  exit 1
fi
CUSTOMIZATION_ROLES_PATH_ENV=${CUSTOMIZATION_ROLES_PATH_ENV#ANSIBLE_ROLES_PATH=}

EXTENSIONS_JSON=$(json_string_array "$EXTENSIONS_JSON")
POSTGRES_HA_COMPONENTS_JSON=$(json_postgres_ha_components "$POSTGRES_HA_COMPONENTS_JSON")
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

PRIVATE_KEY_PATH="${NDB_ARTIFACT_PRIVATE_KEY_PATH:-$ROOT_DIR/packer/id_rsa}"
PUBLIC_KEY_PATH="${NDB_ARTIFACT_PUBLIC_KEY_PATH:-$ROOT_DIR/packer/id_rsa.pub}"
SSH_MAX_POLLS="${NDB_ARTIFACT_SSH_MAX_POLLS:-90}"
SSH_POLL_SECONDS="${NDB_ARTIFACT_SSH_POLL_SECONDS:-10}"
USER_DATA_TEMPLATE="${NDB_ARTIFACT_USER_DATA_TEMPLATE:-$ROOT_DIR/packer/http/e2e-user-data}"
ANSIBLE_DIR="$ROOT_DIR/ansible/$NDB_VERSION"
ANSIBLE_CFG_PATH="$ANSIBLE_DIR/ansible.cfg"
POSTGRES_DEFAULTS="$ANSIBLE_DIR/roles/postgres/defaults/main.yml"

require_file "$PRIVATE_KEY_PATH"
require_file "$PUBLIC_KEY_PATH"
require_file "$USER_DATA_TEMPLATE"
require_file "$ANSIBLE_CFG_PATH"
if ! [[ "$SSH_MAX_POLLS" =~ ^[0-9]+$ ]] || (( SSH_MAX_POLLS < 1 )); then
  printf 'Error: NDB_ARTIFACT_SSH_MAX_POLLS must be a positive integer.\n' >&2
  exit 1
fi
if ! [[ "$SSH_POLL_SECONDS" =~ ^[0-9]+$ ]] || (( SSH_POLL_SECONDS < 1 )); then
  printf 'Error: NDB_ARTIFACT_SSH_POLL_SECONDS must be a positive integer.\n' >&2
  exit 1
fi
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
ARTIFACT_VALIDATE_WORKDIR=$(mktemp -d)

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
        boot_config: {
          boot_type: "UEFI",
          boot_device_order_list: ["DISK", "CDROM", "NETWORK"]
        },
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
        serial_port_list: [
          {
            index: 0,
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
prism_wait_required_task_from_response "$CREATE_RESPONSE" "create VM"

printf 'Powering on validation VM %s...\n' "$VM_UUID"
POWER_RESPONSE=$(prism_power_on_vm "$VM_UUID")
prism_wait_required_task_from_response "$POWER_RESPONSE" "power on VM"

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
SSH_READY=false
for ((attempt = 1; attempt <= SSH_MAX_POLLS; attempt++)); do
  if ssh "${SSH_COMMON_ARGS[@]}" "packer@${VM_IP}" true >/dev/null 2>&1; then
    SSH_READY=true
    break
  fi
  if (( attempt % 6 == 0 || attempt == SSH_MAX_POLLS )); then
    printf 'Still waiting for SSH on %s (attempt %s/%s)...\n' "$VM_IP" "$attempt" "$SSH_MAX_POLLS"
  fi
  sleep "$SSH_POLL_SECONDS"
done
if [[ "$SSH_READY" != "true" ]]; then
  printf 'Error: timed out waiting for SSH on validation VM %s after %s attempts.\n' "$VM_IP" "$SSH_MAX_POLLS" >&2
  exit 1
fi
wait_guest_boot_ready packer "$VM_IP"

cat > "$ARTIFACT_VALIDATE_WORKDIR/inventory" <<EOF
[validation]
${VM_IP} ansible_user=packer ansible_ssh_private_key_file=${PRIVATE_KEY_PATH} ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o IdentityAgent=none'
EOF

cat > "$ARTIFACT_VALIDATE_WORKDIR/validate.yml" <<EOF
---
- name: Validate saved NDB image artifact
  hosts: validation
  roles:
    - ${VALIDATION_ROLE}
    - role: customization_profile
      vars:
        customization_phase: validate
      when: customization_enabled | default(false) | bool
EOF

jq -n \
  --arg db_version "$DB_VERSION" \
  --arg db_type "$DB_TYPE" \
  --arg provisioning_role "$PROVISIONING_ROLE" \
  --arg mongodb_edition "$MONGODB_EDITION" \
  --arg postgres_qualified_version_range "$POSTGRES_QUALIFIED_VERSION_RANGE" \
  --arg postgres_package_version_prefix "$POSTGRES_PACKAGE_VERSION_PREFIX" \
  --arg customization_profile_name "$CUSTOMIZATION_PROFILE_NAME" \
  --arg customization_profile_file "$CUSTOMIZATION_PROFILE_FILE" \
  --arg customization_repo_root "$ROOT_DIR" \
  --argjson postgres_extensions "$EXTENSIONS_JSON" \
  --argjson postgres_ha_components "$POSTGRES_HA_COMPONENTS_JSON" \
  --argjson postgres_package_use_archive "$POSTGRES_PACKAGE_USE_ARCHIVE" \
  --argjson mongodb_deployments "$MONGODB_DEPLOYMENTS_JSON" \
  --argjson customization_enabled "$CUSTOMIZATION_ENABLED" \
  '{
    db_version: $db_version,
    db_type: $db_type,
    provisioning_role: $provisioning_role,
    configure_ndb_sudoers: true,
    postgres_extensions: $postgres_extensions,
    postgres_extensions_databases: ["postgres"],
    postgres_ha_components: $postgres_ha_components,
    postgres_qualified_version_range: $postgres_qualified_version_range,
    postgres_package_version_prefix: $postgres_package_version_prefix,
    postgres_package_use_archive: $postgres_package_use_archive,
    mongodb_edition: $mongodb_edition,
    mongodb_deployments: $mongodb_deployments,
    customization_enabled: $customization_enabled,
    customization_profile_name: $customization_profile_name,
    customization_profile_file: $customization_profile_file,
    customization_repo_root: $customization_repo_root
  }' > "$ARTIFACT_VALIDATE_WORKDIR/vars.json"

printf 'Running artifact validation playbook against %s...\n' "$VM_IP"
ANSIBLE_PLAYBOOK_CMD=(
  ansible-playbook
  -e "ansible_ssh_private_key_file=${PRIVATE_KEY_PATH}"
  -i "$ARTIFACT_VALIDATE_WORKDIR/inventory"
  "$ARTIFACT_VALIDATE_WORKDIR/validate.yml"
)
if [[ "$LOAD_POSTGRES_DEFAULTS" == "true" ]]; then
  ANSIBLE_PLAYBOOK_CMD+=(-e "@${POSTGRES_DEFAULTS}")
fi
ANSIBLE_PLAYBOOK_CMD+=(
  -e "@${ARTIFACT_VALIDATE_WORKDIR}/vars.json"
)
if [[ -n "$CUSTOMIZATION_ROLES_PATH_ENV" ]]; then
  ANSIBLE_CONFIG="$ANSIBLE_CFG_PATH" ANSIBLE_ROLES_PATH="$CUSTOMIZATION_ROLES_PATH_ENV" "${ANSIBLE_PLAYBOOK_CMD[@]}"
else
  ANSIBLE_CONFIG="$ANSIBLE_CFG_PATH" ANSIBLE_ROLES_PATH="$ANSIBLE_DIR/roles" "${ANSIBLE_PLAYBOOK_CMD[@]}"
fi

FINAL_STATUS="passed"
