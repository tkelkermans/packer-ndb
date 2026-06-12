#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=scripts/prism.sh
source "$ROOT_DIR/scripts/prism.sh"

SOURCE_IMAGE_NAME=""
SOURCE_IMAGE_UUID=""
RESULT_FILE=""
KEEP_ON_FAILURE=false
IP_TIMEOUT_SECONDS=900
SSH_TIMEOUT_SECONDS=900
BOOT_TYPE="uefi"
BOOT_TYPE_API=""
VM_NAME=""
VM_UUID=""
VM_IP=""
CLEANUP_STATUS="not-started"
FINAL_STATUS="failed"
RHEL_REPOSITORY_CHECK=false
RHEL_REPOSITORY_CHECK_STATUS="not-requested"
RHEL_REPOSITORY_PACKAGES=(bison firewalld flex gcc gdbm-devel lsof lvm2 net-tools perl python3-pip sshpass unzip wget zip)

usage() {
  cat <<'EOF'
Usage: scripts/source_image_ssh_probe.sh (--source-image-name NAME | --source-image-uuid UUID) [options]

Boots a disposable VM from an existing Prism source image, injects the same
packer cloud-init user data used by builds, waits for SSH as the packer user,
then deletes the VM. Use this to prove source-image cloud-init/SSH compatibility
before running a long Packer build.

Options:
  --source-image-name NAME   Existing Prism source image name
  --source-image-uuid UUID   Existing Prism source image UUID
  --boot-type TYPE           VM boot type: uefi, legacy, or default (default: uefi)
  --ip-timeout SECONDS      Seconds to wait for a VM IP (default: 900)
  --ssh-timeout SECONDS     Seconds to wait for SSH (default: 900)
  --rhel-repository-check   After SSH succeeds, install representative RHEL packages with dnf
  --rhel-repository-packages CSV
                            Comma-separated package list for --rhel-repository-check
  --result-file FILE        Write probe result JSON to FILE
  --keep-on-failure         Keep the disposable VM if SSH probing fails
  -h, --help                Show this help and exit

Environment:
  NDB_SOURCE_PROBE_PRIVATE_KEY_PATH  Override packer/id_rsa for SSH
  NDB_SOURCE_PROBE_PUBLIC_KEY_PATH   Override packer/id_rsa.pub for cloud-init
  NDB_RHEL_ORGID                     Optional Red Hat org ID for repository checks
  NDB_RHEL_ACTIVATIONKEY             Optional Red Hat activation key for repository checks
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

parse_package_csv() {
  local spec=$1
  local old_ifs=$IFS
  local package
  local parsed=()

  IFS=,
  read -r -a parsed <<< "$spec"
  IFS=$old_ifs

  if (( ${#parsed[@]} == 0 )); then
    printf 'Error: --rhel-repository-packages requires at least one package.\n' >&2
    exit 1
  fi

  for package in "${parsed[@]}"; do
    if [[ -z "$package" || ! "$package" =~ ^[A-Za-z0-9_.:+-]+$ ]]; then
      printf 'Error: invalid package name in --rhel-repository-packages: %s\n' "$package" >&2
      exit 1
    fi
  done

  RHEL_REPOSITORY_PACKAGES=("${parsed[@]}")
}

base64_no_wrap() {
  base64 | tr -d '\n'
}

extract_task_uuid() {
  jq -r '.status.execution_context.task_uuid // .task_uuid // ""'
}

wait_task_from_response() {
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
    --arg source_image_name "$SOURCE_IMAGE_NAME" \
    --arg source_image_uuid "$SOURCE_IMAGE_UUID" \
    --arg vm_name "$VM_NAME" \
    --arg vm_uuid "$VM_UUID" \
    --arg vm_ip "$VM_IP" \
    --arg status "$status" \
    --arg cleanup_status "$CLEANUP_STATUS" \
    --arg rhel_repository_check "$RHEL_REPOSITORY_CHECK_STATUS" \
    '{
      source_image_name: $source_image_name,
      source_image_uuid: $source_image_uuid,
      vm_name: $vm_name,
      vm_uuid: $vm_uuid,
      vm_ip: $vm_ip,
      status: $status,
      cleanup_status: $cleanup_status,
      checks: {
        rhel_repositories: $rhel_repository_check
      },
      cleanup: {
        source_image_probe_vm: $cleanup_status
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
    wait_task_from_response "$delete_response" "delete VM" || {
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
  exit "$status"
}
trap on_exit EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source-image-name)
      require_option_value "$1" "$#"
      SOURCE_IMAGE_NAME=$2
      shift
      ;;
    --source-image-uuid)
      require_option_value "$1" "$#"
      SOURCE_IMAGE_UUID=$2
      shift
      ;;
    --ip-timeout)
      require_option_value "$1" "$#"
      IP_TIMEOUT_SECONDS=$2
      shift
      ;;
    --boot-type)
      require_option_value "$1" "$#"
      BOOT_TYPE=$2
      shift
      ;;
    --ssh-timeout)
      require_option_value "$1" "$#"
      SSH_TIMEOUT_SECONDS=$2
      shift
      ;;
    --rhel-repository-check)
      RHEL_REPOSITORY_CHECK=true
      ;;
    --rhel-repository-packages)
      require_option_value "$1" "$#"
      parse_package_csv "$2"
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

if [[ -z "$SOURCE_IMAGE_NAME" && -z "$SOURCE_IMAGE_UUID" ]]; then
  printf 'Error: either --source-image-name or --source-image-uuid is required.\n' >&2
  usage >&2
  exit 1
fi

if [[ -n "$SOURCE_IMAGE_NAME" && -n "$SOURCE_IMAGE_UUID" ]]; then
  printf 'Error: use only one of --source-image-name or --source-image-uuid.\n' >&2
  usage >&2
  exit 1
fi

if ! [[ "$IP_TIMEOUT_SECONDS" =~ ^[0-9]+$ && "$SSH_TIMEOUT_SECONDS" =~ ^[0-9]+$ ]]; then
  printf 'Error: --ip-timeout and --ssh-timeout must be non-negative integers.\n' >&2
  exit 1
fi

case "$BOOT_TYPE" in
  uefi)
    BOOT_TYPE_API="UEFI"
    ;;
  legacy)
    BOOT_TYPE_API="LEGACY"
    ;;
  default)
    BOOT_TYPE_API="default"
    ;;
  *)
    printf 'Error: --boot-type must be uefi, legacy, or default.\n' >&2
    exit 1
    ;;
esac

prism_require_env
require_command jq curl ssh base64

PRIVATE_KEY_PATH="${NDB_SOURCE_PROBE_PRIVATE_KEY_PATH:-$ROOT_DIR/packer/id_rsa}"
PUBLIC_KEY_PATH="${NDB_SOURCE_PROBE_PUBLIC_KEY_PATH:-$ROOT_DIR/packer/id_rsa.pub}"
USER_DATA_TEMPLATE="$ROOT_DIR/packer/http/user-data"

require_file "$PRIVATE_KEY_PATH"
require_file "$PUBLIC_KEY_PATH"
require_file "$USER_DATA_TEMPLATE"

if [[ -z "${PKR_VAR_cluster_name:-}" || -z "${PKR_VAR_subnet_name:-}" ]]; then
  printf 'Error: PKR_VAR_cluster_name and PKR_VAR_subnet_name are required for source image probing.\n' >&2
  exit 1
fi

if [[ -n "$SOURCE_IMAGE_NAME" ]]; then
  SOURCE_IMAGE_UUID=$(prism_image_uuid_by_name "$SOURCE_IMAGE_NAME")
  if [[ -z "$SOURCE_IMAGE_UUID" ]]; then
    printf 'Error: could not find Prism source image named %s.\n' "$SOURCE_IMAGE_NAME" >&2
    exit 1
  fi
else
  IMAGE_JSON=$(prism_image_json "$SOURCE_IMAGE_UUID")
  SOURCE_IMAGE_NAME=$(jq -r '.spec.name // .status.name // ""' <<<"$IMAGE_JSON")
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
VM_NAME="source-probe-${SOURCE_IMAGE_NAME:-image}-${TIMESTAMP}"
VM_NAME=${VM_NAME:0:64}

SSH_PUBLIC_KEY=$(tr -d '\n' < "$PUBLIC_KEY_PATH")
USER_DATA_B64=$(sed "s|\${ssh_public_key}|${SSH_PUBLIC_KEY}|g" "$USER_DATA_TEMPLATE" | base64_no_wrap)

CREATE_PAYLOAD=$(jq -n \
  --arg vm_name "$VM_NAME" \
  --arg cluster_uuid "$CLUSTER_UUID" \
  --arg subnet_uuid "$SUBNET_UUID" \
  --arg image_uuid "$SOURCE_IMAGE_UUID" \
  --arg user_data "$USER_DATA_B64" \
  --arg boot_type "$BOOT_TYPE_API" \
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
  }
  | if $boot_type == "default" then .
    else .spec.resources.boot_config = {boot_type: $boot_type}
    end')

printf 'Creating disposable source image probe VM %s from image %s...\n' "$VM_NAME" "${SOURCE_IMAGE_NAME:-$SOURCE_IMAGE_UUID}"
CREATE_RESPONSE=$(prism_curl POST /api/nutanix/v3/vms "$CREATE_PAYLOAD")
VM_UUID=$(jq -r '.metadata.uuid // ""' <<<"$CREATE_RESPONSE")
if [[ -z "$VM_UUID" ]]; then
  printf 'Error: Prism create response did not include VM UUID.\n' >&2
  exit 1
fi
wait_task_from_response "$CREATE_RESPONSE" "create VM"

printf 'Powering on source image probe VM %s...\n' "$VM_UUID"
POWER_RESPONSE=$(prism_power_on_vm "$VM_UUID")
wait_task_from_response "$POWER_RESPONSE" "power on VM"

printf 'Waiting for source image probe VM IP...\n'
VM_IP=""
elapsed=0
while (( elapsed <= IP_TIMEOUT_SECONDS )); do
  VM_IP=$(prism_vm_ip "$VM_UUID")
  if [[ -n "$VM_IP" ]]; then
    break
  fi
  sleep 10
  elapsed=$((elapsed + 10))
done
if [[ -z "$VM_IP" ]]; then
  printf 'Error: timed out waiting for source image probe VM IP.\n' >&2
  exit 1
fi

printf 'Waiting for SSH on %s as packer...\n' "$VM_IP"
SSH_COMMON_ARGS=(
  -i "$PRIVATE_KEY_PATH"
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  -o IdentitiesOnly=yes
  -o IdentityAgent=none
  -o BatchMode=yes
  -o ConnectTimeout=10
)

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
  printf 'Waiting for systemd/D-Bus readiness on %s...\n' "$VM_IP"
  for _ in $(seq 1 90); do
    if ssh "${SSH_COMMON_ARGS[@]}" "packer@${VM_IP}" "$(guest_boot_ready_probe)" >/dev/null 2>&1; then
      return 0
    fi
    sleep 10
  done

  ssh "${SSH_COMMON_ARGS[@]}" "packer@${VM_IP}" "systemctl is-system-running || true; ls -l /run/dbus/system_bus_socket || true; cloud-init status || true" >&2 || true
  ssh "${SSH_COMMON_ARGS[@]}" "packer@${VM_IP}" "$(guest_boot_ready_probe)" >/dev/null
}

run_rhel_repository_check() {
  local packages
  local org_id_quoted
  local activation_key_quoted

  packages="${RHEL_REPOSITORY_PACKAGES[*]}"
  printf 'Checking RHEL package repositories on %s with dnf...\n' "$VM_IP"

  if [[ -n "${NDB_RHEL_ORGID:-}" && -z "${NDB_RHEL_ACTIVATIONKEY:-}" ]] || [[ -z "${NDB_RHEL_ORGID:-}" && -n "${NDB_RHEL_ACTIVATIONKEY:-}" ]]; then
    RHEL_REPOSITORY_CHECK_STATUS="failed"
    printf 'Error: set both NDB_RHEL_ORGID and NDB_RHEL_ACTIVATIONKEY, or neither.\n' >&2
    return 1
  fi

  printf -v org_id_quoted "%q" "${NDB_RHEL_ORGID:-}"
  printf -v activation_key_quoted "%q" "${NDB_RHEL_ACTIVATIONKEY:-}"

  # shellcheck disable=SC2087  # client-side expansion is intentional: only the %q-quoted
  # values above are substituted; remote-side variables are escaped with \$ in the heredoc.
  if ssh "${SSH_COMMON_ARGS[@]}" "packer@${VM_IP}" "sudo -n bash -s" <<EOF
set -euo pipefail

rhel_org_id=${org_id_quoted}
rhel_activation_key=${activation_key_quoted}
rhel_major_version=""
if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  rhel_major_version="\${VERSION_ID%%.*}"
fi
if [[ -z "\$rhel_major_version" ]]; then
  rhel_major_version=\$(rpm -E '%{rhel}' 2>/dev/null || true)
fi
if [[ -z "\$rhel_major_version" || "\$rhel_major_version" == *%* ]]; then
  echo "Unable to determine RHEL major version for CodeReady Builder repository" >&2
  exit 1
fi
rhel_arch=\$(uname -m)
codeready_repo_id="codeready-builder-for-rhel-\${rhel_major_version}-\${rhel_arch}-rpms"

cleanup_rhel_subscription() {
  if [[ "\${RHEL_REPOSITORY_REGISTERED:-false}" == "true" ]]; then
    subscription-manager unregister >/dev/null 2>&1 || true
    subscription-manager clean >/dev/null 2>&1 || true
  fi
}
trap cleanup_rhel_subscription EXIT

if [[ -n "\$rhel_org_id" && -n "\$rhel_activation_key" ]]; then
  subscription-manager register --org="\$rhel_org_id" --activationkey="\$rhel_activation_key" >/dev/null
  RHEL_REPOSITORY_REGISTERED=true
  subscription-manager refresh >/dev/null
fi

if subscription-manager identity >/dev/null 2>&1; then
  subscription-manager repos --enable="\$codeready_repo_id" >/dev/null
fi

command -v dnf >/dev/null
dnf -y makecache
dnf -y install ${packages}
EOF
  then
    RHEL_REPOSITORY_CHECK_STATUS="passed"
    printf 'RHEL package repository check passed on %s.\n' "$VM_IP"
    return 0
  fi

  RHEL_REPOSITORY_CHECK_STATUS="failed"
  printf 'Error: RHEL package repository check failed on %s.\n' "$VM_IP" >&2
  return 1
}

elapsed=0
while (( elapsed <= SSH_TIMEOUT_SECONDS )); do
  if ssh "${SSH_COMMON_ARGS[@]}" "packer@${VM_IP}" true >/dev/null 2>&1; then
    wait_guest_boot_ready
    if [[ "$RHEL_REPOSITORY_CHECK" == "true" ]]; then
      run_rhel_repository_check
    fi
    FINAL_STATUS="passed"
    printf 'Source image accepted cloud-init SSH for packer@%s.\n' "$VM_IP"
    exit 0
  fi
  sleep 10
  elapsed=$((elapsed + 10))
done

printf 'Error: timed out waiting for cloud-init SSH as packer@%s.\n' "$VM_IP" >&2
exit 1
