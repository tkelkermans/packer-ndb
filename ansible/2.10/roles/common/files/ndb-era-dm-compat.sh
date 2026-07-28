#!/usr/bin/env bash
set -euo pipefail

log_file=/opt/era_base/era_dm_compat.log
rules_file=/etc/udev/rules.d/99-ndb-era-dm-serial.rules

mkdir -p /opt/era_base /etc/udev/rules.d

log() {
  printf '%s %s\n' "$(date -Is)" "$*" >> "$log_file"
}

command -v udevadm >/dev/null 2>&1 || exit 0
command -v dmsetup >/dev/null 2>&1 || exit 0

ensure_dm_alias() {
  local dm_dev=$1
  local kernel=$2
  local alias="/dev/${kernel}.."

  if [[ -e "$alias" ]]; then
    if [[ -L "$alias" && "$(readlink "$alias")" == "$dm_dev" ]]; then
      return 0
    fi
    rm -f "$alias"
  fi

  ln -s "$dm_dev" "$alias"
  log "Created NDB device-mapper symlink alias $alias -> $dm_dev."
}

tmp_rules=$(mktemp)
trap 'rm -f "$tmp_rules"' EXIT
dm_devices=()

for dm_dev in /dev/dm-[0-9]*; do
  [[ -b "$dm_dev" ]] || continue
  kernel=$(basename "$dm_dev")
  [[ "$kernel" =~ ^dm-[0-9]+$ ]] || continue
  dm_vg=$(udevadm info --query=property --name="$dm_dev" | sed -n 's/^DM_VG_NAME=//p' | head -1)
  [[ "$dm_vg" == ntnx_era_agent_vg_* ]] || continue

  ensure_dm_alias "$dm_dev" "$kernel"
  dm_devices+=("$dm_dev")

  parent=$(dmsetup deps -o devname "$dm_dev" 2>/dev/null | sed -n 's/.*(\([^)]*\)).*/\1/p' | awk '{print $1}' || true)
  [[ -n "$parent" && -b "/dev/$parent" ]] || continue
  serial=$(udevadm info --query=property --name="/dev/$parent" | sed -n 's/^ID_SERIAL=//p' | head -1)
  short_serial=$(udevadm info --query=property --name="/dev/$parent" | sed -n 's/^ID_SERIAL_SHORT=//p' | head -1)
  [[ -n "$serial" ]] || continue

  printf 'KERNEL=="%s", ENV{DM_VG_NAME}=="%s", ENV{ID_SERIAL}="%s", ENV{ID_SERIAL_SHORT}="%s"\n' \
    "$kernel" "$dm_vg" "$serial" "${short_serial:-$serial}" >> "$tmp_rules"
done

if [[ -s "$tmp_rules" ]] && ! cmp -s "$tmp_rules" "$rules_file"; then
  install -m 0644 "$tmp_rules" "$rules_file"
  udevadm control --reload-rules
  for dm_dev in "${dm_devices[@]}"; do
    udevadm trigger --action=change --name-match="$dm_dev" || true
  done
  udevadm settle || true
  log "Refreshed NDB Era device-mapper udev serial metadata."
fi
