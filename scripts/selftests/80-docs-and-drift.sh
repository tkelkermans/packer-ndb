#!/usr/bin/env bash
# Sourced by scripts/selftest.sh; defines run_*_tests suite functions.
# shellcheck shell=bash

run_ndb_linux_precheck_guard_tests() {
  local version vars_file sudoers_file pkg
  local common_precheck_packages=(
    logrotate
    lsscsi
  )
  local common_ndb_driver_packages=(
    parted
  )
  local redhat_precheck_packages=(
    cronie
    python3-libselinux
  )
  local debian_precheck_packages=(
    cron
    ifupdown
    nftables
    python3-selinux
    systemd
    xfsprogs
  )

  for version in 2.9 2.10; do
    vars_file="$ROOT_DIR/ansible/$version/roles/common/vars/main.yml"
    sudoers_file="$ROOT_DIR/ansible/$version/roles/common/templates/ndb_sudoers.j2"

    for pkg in "${common_precheck_packages[@]}"; do
      grep -qE "^[[:space:]]*-[[:space:]]+$pkg$" "$vars_file" || fail "NDB $version common role does not install Nutanix precheck package $pkg"
    done

    for pkg in "${common_ndb_driver_packages[@]}"; do
      grep -qE "^[[:space:]]*-[[:space:]]+$pkg$" "$vars_file" || fail "NDB $version common role does not install NDB driver package $pkg"
    done

    for pkg in "${redhat_precheck_packages[@]}"; do
      grep -qE "^[[:space:]]*-[[:space:]]+$pkg$" "$vars_file" || fail "NDB $version Red Hat common role does not install Nutanix precheck package $pkg"
    done

    for pkg in "${debian_precheck_packages[@]}"; do
      grep -qE "^[[:space:]]*-[[:space:]]+$pkg$" "$vars_file" || fail "NDB $version Debian common role does not install Nutanix precheck package $pkg"
    done

    grep -q 'name: "{{ ndb_drive_user }}"' "$ROOT_DIR/ansible/$version/roles/common/tasks/services.yml" || fail "NDB $version common role does not create the NDB drive user"
    grep -q "use_devicesfile = 0" "$ROOT_DIR/ansible/$version/roles/common/tasks/storage.yml" || fail "NDB $version common role does not disable LVM devices file usage"
    grep -q "ndb-era-dm-compat" "$ROOT_DIR/ansible/$version/roles/common/tasks/storage.yml" || fail "NDB $version common role does not install the NDB Era device-mapper helper"
    grep -q "ndb-era-dm-compat.timer" "$ROOT_DIR/ansible/$version/roles/common/tasks/storage.yml" || fail "NDB $version common role does not install the NDB Era device-mapper timer"
    grep -q "OnUnitActiveSec=10s" "$ROOT_DIR/ansible/$version/roles/common/tasks/storage.yml" || fail "NDB $version NDB Era device-mapper timer does not rerun during target disk attach"
    grep -Fq '[[ "$kernel" =~ ^dm-[0-9]+$ ]]' "$ROOT_DIR/ansible/$version/roles/common/files/ndb-era-dm-compat.sh" || fail "NDB $version NDB Era device-mapper helper can recursively process generated DM aliases"
    grep -q '/dev/${kernel}..' "$ROOT_DIR/ansible/$version/roles/common/files/ndb-era-dm-compat.sh" || fail "NDB $version NDB Era device-mapper helper does not create malformed DM aliases"
    grep -Fq 'ln -s "$dm_dev" "$alias"' "$ROOT_DIR/ansible/$version/roles/common/files/ndb-era-dm-compat.sh" || fail "NDB $version NDB Era device-mapper helper must create symlink aliases"
    ! grep -q "mknod -m" "$ROOT_DIR/ansible/$version/roles/common/files/ndb-era-dm-compat.sh" || fail "NDB $version NDB Era device-mapper helper must not create block-device aliases"
    grep -q "99-ndb-era-dm-serial.rules" "$ROOT_DIR/ansible/$version/roles/common/files/ndb-era-dm-compat.sh" || fail "NDB $version NDB Era device-mapper helper does not write udev serial metadata"
    grep -q "Expose Debian-family chrony config at NDB expected path" "$ROOT_DIR/ansible/$version/roles/common/tasks/services.yml" || fail "NDB $version common role does not expose Debian-family /etc/chrony.conf for NDB"
    grep -q "Ensure Debian-family D-Bus service is pulled in during first boot" "$ROOT_DIR/ansible/$version/roles/common/tasks/services.yml" || fail "NDB $version common role does not guarantee Debian-family D-Bus first-boot startup"
    grep -q "basic.target.wants/dbus.service" "$ROOT_DIR/ansible/$version/roles/common/tasks/services.yml" || fail "NDB $version common role does not anchor dbus.service to basic.target"
    grep -q "sockets.target.wants/dbus.socket" "$ROOT_DIR/ansible/$version/roles/common/tasks/services.yml" || fail "NDB $version common role does not anchor dbus.socket to sockets.target"
    grep -q '{{ ndb_drive_user }} ALL=(ALL) NOPASSWD:ALL' "$sudoers_file" || fail "NDB $version sudoers policy does not allow Nutanix precheck sudo -n true"
    # Shared checks moved to validate_common; both engine roles include it
    # (asserted by the validate_common wiring guards).
    grep -q "Validate Debian-family D-Bus first-boot readiness" "$ROOT_DIR/ansible/$version/roles/validate_common/tasks/main.yml" || fail "NDB $version shared validation does not check Debian-family D-Bus first-boot readiness"
    grep -q "command -v parted" "$ROOT_DIR/ansible/$version/roles/validate_common/tasks/main.yml" || fail "NDB $version shared validation does not check parted for NDB storage mapping"
  done

  grep -q "Nutanix Linux Precheck" "$ROOT_DIR/README.md" || fail "README missing Nutanix Linux precheck guidance"
  grep -q "/etc/chrony.conf" "$ROOT_DIR/README.md" || fail "README missing Debian-family chrony path guidance"
  grep -q "/run/dbus/system_bus_socket" "$ROOT_DIR/README.md" || fail "README missing Debian-family D-Bus first-boot guidance"
  grep -q "ndb-era-dm-compat" "$ROOT_DIR/README.md" || fail "README missing Debian-family NDB Era device-mapper helper guidance"
  grep -q "ndb_linux_prechecks.sh -t postgres_database -n era" "$ROOT_DIR/README.md" || fail "README missing PostgreSQL Linux precheck command"
  grep -q "ndb_linux_prechecks.sh -t mongodb_database -n era" "$ROOT_DIR/README.md" || fail "README missing MongoDB Linux precheck command"

  pass "NDB Linux precheck guard"
}
run_readme_customization_tests() {
  grep -q "Customize The Image" "$ROOT_DIR/README.md" || fail "README missing Customize The Image"
  grep -q "Install an internal CA certificate" "$ROOT_DIR/README.md" || fail "README missing internal CA recipe"
  grep -q "OpenTelemetry Collector" "$ROOT_DIR/README.md" || fail "README missing OpenTelemetry explanation"
  grep -q "customizations/local" "$ROOT_DIR/README.md" || fail "README missing private overlay explanation"
  grep -q "validate_custom_enterprise" "$ROOT_DIR/README.md" || fail "README missing custom validation role guidance"
  pass "README customization guidance"
}
run_ansible_tree_drift_tests() {
  # The ansible/<ver> trees are deliberately parallel (release_scaffold.sh copies
  # a prior version). Only files listed here may differ between versions, and the
  # difference must be an intentional vendor-qualification delta. Any other
  # divergence is unintended drift: a change applied to one version's role but
  # not the others. Sync the change across versions, or add the file here with a
  # comment explaining why it legitimately differs.
  local allowlist=(
    "roles/common/tasks/services.yml" # version-specific NDB guest workarounds (Ubuntu 24.04 AppArmor)
    "roles/postgres/vars/main.yml"    # per-version qualified PostgreSQL versions
  )

  local versions=()
  while IFS= read -r version_dir; do
    versions+=("$(basename "$version_dir")")
  done < <(find "$ROOT_DIR/ansible" -mindepth 1 -maxdepth 1 -type d | sort)

  if (( ${#versions[@]} < 2 )); then
    pass "ansible tree drift check (only one NDB version present)"
    return
  fi

  local ref="${versions[0]}"
  local ref_dir="$ROOT_DIR/ansible/$ref"
  local ver ver_dir rel allowed entry
  for ver in "${versions[@]:1}"; do
    ver_dir="$ROOT_DIR/ansible/$ver"

    if ! diff <(cd "$ref_dir" && find . -type f | sort) \
              <(cd "$ver_dir" && find . -type f | sort) >/dev/null; then
      diff <(cd "$ref_dir" && find . -type f | sort) \
           <(cd "$ver_dir" && find . -type f | sort) >&2 || true
      fail "ansible/$ver file set differs from ansible/$ref (keep version trees in lockstep)"
    fi

    while IFS= read -r rel; do
      rel="${rel#./}"
      allowed=false
      for entry in "${allowlist[@]}"; do
        if [[ "$rel" == "$entry" ]]; then
          allowed=true
          break
        fi
      done
      if cmp -s "$ref_dir/$rel" "$ver_dir/$rel"; then
        if [[ "$allowed" == "true" ]]; then
          fail "stale ansible drift allowlist: $rel is identical between $ref and $ver; remove it from the allowlist"
        fi
      else
        if [[ "$allowed" != "true" ]]; then
          fail "unintended ansible drift: ansible/$ver/$rel differs from ansible/$ref/$rel (sync the change or allowlist it with justification)"
        fi
      fi
    done < <(cd "$ref_dir" && find . -type f | sort)
  done

  pass "ansible tree drift between NDB versions is intentional"
}
run_matrix_ha_components_source_of_truth_tests() {
  # ha_components is the single source of truth for HA install versions. The old
  # top-level patroni_version/etcd_version fields duplicated ha_components[0],
  # were passed to Packer as variables it never referenced, and must not return.
  local matrix
  for matrix in "$ROOT_DIR"/ndb/*/matrix.json; do
    if jq -e 'any(.[]; has("patroni_version") or has("etcd_version"))' "$matrix" >/dev/null; then
      fail "$matrix reintroduced dead patroni_version/etcd_version fields; use ha_components instead"
    fi
  done
  ! grep -q "patroni_version=" "$ROOT_DIR/build.sh" \
    || fail "build.sh passes the dead patroni_version Packer variable"
  ! grep -q 'variable "patroni_version"' "$ROOT_DIR/packer/variables.pkr.hcl" \
    || fail "packer still declares the unused patroni_version variable"
  pass "matrix HA versions sourced only from ha_components"
}
