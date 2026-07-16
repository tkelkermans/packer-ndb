#!/usr/bin/env bash
# Shared disposable-VM lifecycle helpers for artifact validation, source-image
# probing, and NDB E2E validation. Source scripts/prism.sh first, then this
# file, then call vm_lifecycle_set_ssh_args before any SSH helper.

vm_lifecycle_base64_no_wrap() {
  base64 | tr -d '\n'
}

# Renders a cloud-init user-data template (packer/http/*), substituting
# ${ssh_public_key}, and emits it base64-encoded for Prism guest_customization.
vm_lifecycle_render_user_data_b64() {
  local template=$1
  local public_key_path=$2
  local ssh_public_key

  ssh_public_key=$(tr -d '\n' < "$public_key_path")
  sed "s|\${ssh_public_key}|${ssh_public_key}|g" "$template" | vm_lifecycle_base64_no_wrap
}

# Populates the global VM_LIFECYCLE_SSH_ARGS array used by vm_lifecycle_ssh.
vm_lifecycle_set_ssh_args() {
  local private_key_path=$1
  local connect_timeout=${2:-10}

  VM_LIFECYCLE_SSH_ARGS=(
    -i "$private_key_path"
    -o StrictHostKeyChecking=no
    -o UserKnownHostsFile=/dev/null
    -o IdentitiesOnly=yes
    -o IdentityAgent=none
    -o BatchMode=yes
    -o ConnectTimeout="$connect_timeout"
  )
}

vm_lifecycle_ssh() {
  local user=$1 ip=$2
  shift 2
  ssh "${VM_LIFECYCLE_SSH_ARGS[@]}" "${user}@${ip}" "$@"
}

# Polls SSH reachability; on exhaustion re-runs the probe without silencing
# stderr so the caller sees the underlying SSH error (existing behavior in
# all three consumers).
vm_lifecycle_wait_ssh() {
  local user=$1 ip=$2 max_polls=$3 poll_seconds=${4:-10} progress_label=${5:-}
  local attempt

  for attempt in $(seq 1 "$max_polls"); do
    if vm_lifecycle_ssh "$user" "$ip" true >/dev/null 2>&1; then
      return 0
    fi
    if [[ -n "$progress_label" ]] && (( attempt % 6 == 0 || attempt == max_polls )); then
      printf 'Still waiting for SSH on %s (attempt %s/%s)...\n' "$ip" "$attempt" "$max_polls"
    fi
    sleep "$poll_seconds"
  done
  vm_lifecycle_ssh "$user" "$ip" true >/dev/null
}

vm_lifecycle_guest_boot_ready_probe() {
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

# Waits for systemd/D-Bus/cloud-init readiness; on exhaustion dumps boot
# state to stderr, then re-runs the probe so the failure carries evidence.
vm_lifecycle_wait_guest_boot_ready() {
  local user=$1 ip=$2 max_polls=${3:-90} poll_seconds=${4:-10}

  printf 'Waiting for systemd/D-Bus readiness on %s...\n' "$ip"
  for _ in $(seq 1 "$max_polls"); do
    if vm_lifecycle_ssh "$user" "$ip" "$(vm_lifecycle_guest_boot_ready_probe)" >/dev/null 2>&1; then
      return 0
    fi
    sleep "$poll_seconds"
  done

  vm_lifecycle_ssh "$user" "$ip" "systemctl is-system-running || true; ls -l /run/dbus/system_bus_socket || true; cloud-init status || true" >&2 || true
  vm_lifecycle_ssh "$user" "$ip" "$(vm_lifecycle_guest_boot_ready_probe)" >/dev/null
}

# Prints the VM IP once Prism reports one; empty output + rc 1 on timeout.
vm_lifecycle_wait_vm_ip() {
  local vm_uuid=$1 max_polls=$2 poll_seconds=${3:-10}
  local ip=""

  for _ in $(seq 1 "$max_polls"); do
    ip=$(prism_vm_ip "$vm_uuid")
    if [[ -n "$ip" ]]; then
      printf '%s\n' "$ip"
      return 0
    fi
    sleep "$poll_seconds"
  done
  return 1
}
