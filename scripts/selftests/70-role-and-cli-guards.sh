#!/usr/bin/env bash
# Sourced by scripts/selftest.sh; defines run_*_tests suite functions.
# shellcheck shell=bash

run_mongodb_dispatch_guard_tests() {
  grep -q 'postgresql|mongodb' "$ROOT_DIR/build.sh" || fail "build.sh does not allow MongoDB provisioning role"
  grep -q 'mongodb_edition' "$ROOT_DIR/build.sh" || fail "build.sh does not pass MongoDB edition to Ansible"
  grep -q 'mongodb_deployments' "$ROOT_DIR/build.sh" || fail "build.sh does not pass MongoDB deployments to Ansible"
  grep -q 'PROVISIONING_ROLE=$(echo "$CONFIG"' "$ROOT_DIR/build.sh" || fail "build.sh does not extract provisioning role from the matrix"
  grep -q -- '--provisioning-role "$PROVISIONING_ROLE"' "$ROOT_DIR/build.sh" || fail "build.sh does not pass provisioning role to artifact validation"
  grep -Fq 'if [[ "$provisioning_role" == "metadata" ]]' "$ROOT_DIR/test.sh" || fail "test.sh still filters to one hard-coded provisioning role"
  pass "MongoDB build and test dispatch guards"
}
run_extension_strictness_tests() {
  local version
  for version in 2.9 2.10; do
    grep -q "Assert all requested PostgreSQL extensions are installable" "$ROOT_DIR/ansible/$version/roles/postgres/tasks/main.yml" || fail "postgres role $version does not fail skipped requested extensions"
    grep -q "Assert all requested PostgreSQL extensions are validated" "$ROOT_DIR/ansible/$version/roles/validate_postgres/tasks/main.yml" || fail "validate_postgres role $version does not fail skipped requested extensions"
    grep -q "until: validate_service_active_result.stdout == \"active\"" "$ROOT_DIR/ansible/$version/roles/validate_postgres/tasks/main.yml" || fail "validate_postgres role $version does not wait for services to become active"
    grep -q "Stop and disable packaged PostgreSQL service before image capture" "$ROOT_DIR/ansible/$version/roles/postgres/tasks/main.yml" || fail "postgres role $version does not stop packaged PostgreSQL before capture"
    ! grep -q "notify: Start PostgreSQL service" "$ROOT_DIR/ansible/$version/roles/postgres/tasks/main.yml" || fail "postgres role $version still auto-starts PostgreSQL through handlers"
    grep -q "Assert packaged PostgreSQL service is inactive" "$ROOT_DIR/ansible/$version/roles/validate_postgres/tasks/main.yml" || fail "validate_postgres role $version does not require packaged PostgreSQL to be inactive"
    grep -q "Assert PostgreSQL listener port is free" "$ROOT_DIR/ansible/$version/roles/validate_postgres/tasks/main.yml" || fail "validate_postgres role $version does not prove port 5432 is free for NDB"
    grep -q "Check expected PostgreSQL extension control files exist" "$ROOT_DIR/ansible/$version/roles/validate_postgres/tasks/main.yml" || fail "validate_postgres role $version does not validate extension control files without a running default database"
    grep -q "validate_postgres_postgres_bin_map" "$ROOT_DIR/ansible/$version/roles/validate_postgres/defaults/main.yml" || fail "validate_postgres role $version does not define server binary paths"
    grep -q 'pgaudit: "pgaudit_%s"' "$ROOT_DIR/ansible/$version/roles/postgres/defaults/main.yml" || fail "postgres role $version uses the wrong RedHat pgaudit package template"
    grep -q '"14": "pgaudit16_14"' "$ROOT_DIR/ansible/$version/roles/postgres/defaults/main.yml" || fail "postgres role $version is missing the RedHat PG14 pgaudit override"
    grep -q '"15": "pgaudit17_15"' "$ROOT_DIR/ansible/$version/roles/postgres/defaults/main.yml" || fail "postgres role $version is missing the RedHat PG15 pgaudit override"
    grep -q 'timescaledb: "timescaledb_%s"' "$ROOT_DIR/ansible/$version/roles/postgres/defaults/main.yml" || fail "postgres role $version uses the wrong RedHat TimescaleDB package template"
    grep -q 'timescaledb: "timescaledb-2-postgresql-%s"' "$ROOT_DIR/ansible/$version/roles/postgres/defaults/main.yml" || fail "postgres role $version uses the wrong Debian TimescaleDB package template"
    grep -q 'pg_stat_statements: "postgresql-contrib-%s"' "$ROOT_DIR/ansible/$version/roles/postgres/defaults/main.yml" || fail "postgres role $version uses the wrong Debian contrib package template"
    grep -q "postgresql-contrib-' + postgres_major_version" "$ROOT_DIR/ansible/$version/roles/postgres/tasks/main.yml" || fail "postgres role $version computes the wrong Debian contrib package name"
    grep -q "apt-archive.postgresql.org" "$ROOT_DIR/ansible/$version/roles/postgres/tasks/main.yml" || fail "postgres role $version does not support the PGDG archive for pinned packages"
    grep -q "postgres_debian_client_package_name" "$ROOT_DIR/ansible/$version/roles/postgres/tasks/main.yml" || fail "postgres role $version does not pin the Debian PostgreSQL client package"
    grep -q "postgres_resolved_client_package_version" "$ROOT_DIR/ansible/$version/roles/postgres/tasks/main.yml" || fail "postgres role $version does not resolve pinned Debian PostgreSQL client packages"
    grep -q "postgres_package_version_prefix" "$ROOT_DIR/ansible/$version/roles/validate_postgres/tasks/main.yml" || fail "validate_postgres role $version does not enforce pinned PostgreSQL package prefixes"
    grep -q "Assert PostgreSQL pg_config version matches release-note package pin" "$ROOT_DIR/ansible/$version/roles/validate_postgres/tasks/main.yml" || fail "validate_postgres role $version does not enforce pinned pg_config versions"
    ! grep -q "postgres_contrib_version_overrides" "$ROOT_DIR/ansible/$version/roles/postgres/defaults/main.yml" || fail "postgres role $version pins RedHat contrib packages to drift-prone patch versions"
    ! grep -q "contrib_suffix" "$ROOT_DIR/ansible/$version/roles/postgres/tasks/main.yml" || fail "postgres role $version appends drift-prone RedHat contrib version suffixes"
    grep -q "postgres_ha_components" "$ROOT_DIR/ansible/$version/roles/postgres/defaults/main.yml" || fail "postgres role $version does not define HA component defaults"
    grep -q "patroni\\[etcd\\]" "$ROOT_DIR/ansible/$version/roles/postgres/tasks/main.yml" || fail "postgres role $version does not install Patroni with etcd support"
    grep -q "psycopg2-binary" "$ROOT_DIR/ansible/$version/roles/postgres/tasks/main.yml" || fail "postgres role $version does not install the Patroni PostgreSQL driver"
    grep -q "etcd-v{{ postgres_etcd_version }}" "$ROOT_DIR/ansible/$version/roles/postgres/tasks/main.yml" || fail "postgres role $version does not install matrix-qualified etcd binaries"
    grep -q "name: haproxy" "$ROOT_DIR/ansible/$version/roles/postgres/tasks/main.yml" || fail "postgres role $version does not install HAProxy when qualified"
    grep -q "name: keepalived" "$ROOT_DIR/ansible/$version/roles/postgres/tasks/main.yml" || fail "postgres role $version does not install Keepalived when qualified"
    grep -q "Check Patroni version" "$ROOT_DIR/ansible/$version/roles/validate_postgres/tasks/main.yml" || fail "validate_postgres role $version does not validate Patroni"
    grep -q "Check etcd version" "$ROOT_DIR/ansible/$version/roles/validate_postgres/tasks/main.yml" || fail "validate_postgres role $version does not validate etcd"
    grep -q "Check HAProxy is installed" "$ROOT_DIR/ansible/$version/roles/validate_postgres/tasks/main.yml" || fail "validate_postgres role $version does not validate HAProxy"
    grep -q "/usr/sbin/haproxy" "$ROOT_DIR/ansible/$version/roles/validate_postgres/tasks/main.yml" || fail "validate_postgres role $version does not validate HAProxy by absolute system path"
    grep -q "/usr/sbin/keepalived" "$ROOT_DIR/ansible/$version/roles/validate_postgres/tasks/main.yml" || fail "validate_postgres role $version does not validate Keepalived by absolute system path"
    grep -q "Check Keepalived is installed" "$ROOT_DIR/ansible/$version/roles/validate_postgres/tasks/main.yml" || fail "validate_postgres role $version does not validate Keepalived"
    grep -q "Add TimescaleDB repository (Debian/Ubuntu)" "$ROOT_DIR/ansible/$version/roles/postgres/tasks/main.yml" || fail "postgres role $version does not add the TimescaleDB Ubuntu repository"
    grep -q "timescale_timescaledb-archive-keyring.gpg" "$ROOT_DIR/ansible/$version/roles/postgres/tasks/main.yml" || fail "postgres role $version does not install the dearmored TimescaleDB keyring"
    grep -q "lock_timeout: 600" "$ROOT_DIR/ansible/$version/roles/common/tasks/packages.yml" || fail "common role $version does not wait for apt locks"
    grep -q "apt_postgres_extension_packages_result" "$ROOT_DIR/ansible/$version/roles/postgres/tasks/main.yml" || fail "postgres role $version does not retry Debian extension package installs"
  done
  grep -q "POSTGRES_HA_COMPONENTS_JSON" "$ROOT_DIR/build.sh" || fail "build.sh does not extract PostgreSQL HA components from the matrix"
  grep -q "postgres_ha_components" "$ROOT_DIR/build.sh" || fail "build.sh does not pass PostgreSQL HA components to Ansible"
  grep -q "POSTGRES_PACKAGE_VERSION_PREFIX" "$ROOT_DIR/build.sh" || fail "build.sh does not extract PostgreSQL package pins from the matrix"
  grep -q "postgres_package_version_prefix" "$ROOT_DIR/scripts/artifact_validate.sh" || fail "artifact validation does not receive PostgreSQL package pins"
  pass "strict extension package mapping, apt locking, HA validation, and NDB-safe PostgreSQL service state"
}
run_playbook_database_dispatch_tests() {
  local version
  for version in 2.9 2.10; do
    grep -q "role: postgres" "$ROOT_DIR/ansible/$version/playbooks/site.yml" || fail "playbook $version missing postgres role dispatch"
    grep -q "role: mongodb" "$ROOT_DIR/ansible/$version/playbooks/site.yml" || fail "playbook $version missing mongodb role dispatch"
    grep -q "role: validate_mongodb" "$ROOT_DIR/ansible/$version/playbooks/site.yml" || fail "playbook $version missing validate_mongodb dispatch"
    grep -q "provisioning_role | default" "$ROOT_DIR/ansible/$version/playbooks/site.yml" || fail "playbook $version does not dispatch by provisioning_role"
  done
  pass "playbook database role dispatch"
}
run_mongodb_role_static_tests() {
  local version
  for version in 2.9 2.10; do
    grep -q "mongodb_edition" "$ROOT_DIR/ansible/$version/roles/mongodb/defaults/main.yml" || fail "mongodb role $version missing edition default"
    grep -q "repo.mongodb.org" "$ROOT_DIR/ansible/$version/roles/mongodb/tasks/main.yml" || fail "mongodb role $version missing community repository"
    grep -q "repo.mongodb.com" "$ROOT_DIR/ansible/$version/roles/mongodb/tasks/main.yml" || fail "mongodb role $version missing enterprise repository"
    grep -q "lock_timeout: 600" "$ROOT_DIR/ansible/$version/roles/mongodb/tasks/main.yml" || fail "mongodb role $version does not wait for apt locks"
    grep -q "mongodb-enterprise" "$ROOT_DIR/ansible/$version/roles/mongodb/tasks/main.yml" || fail "mongodb role $version does not support enterprise packages"
    grep -q "mongodb-database-tools" "$ROOT_DIR/ansible/$version/roles/mongodb/defaults/main.yml" || fail "mongodb role $version does not install MongoDB Database Tools"
    grep -q "mongodump" "$ROOT_DIR/ansible/$version/roles/mongodb/defaults/main.yml" || fail "mongodb role $version does not expose mongodump in NDB-safe software home"
    grep -q "mongorestore" "$ROOT_DIR/ansible/$version/roles/mongodb/defaults/main.yml" || fail "mongodb role $version does not expose mongorestore in NDB-safe software home"
    grep -q "mongod" "$ROOT_DIR/ansible/$version/roles/mongodb/tasks/main.yml" || fail "mongodb role $version does not manage mongod service"
    grep -q "mongodb_selinux_policy_repo" "$ROOT_DIR/ansible/$version/roles/mongodb/tasks/main.yml" || fail "mongodb role $version does not install MongoDB SELinux policy"
    grep -q "mongodb-selinux.git" "$ROOT_DIR/ansible/$version/roles/mongodb/defaults/main.yml" || fail "mongodb role $version missing MongoDB SELinux policy repository default"
    grep -q "selinux-policy-devel" "$ROOT_DIR/ansible/$version/roles/mongodb/tasks/main.yml" || fail "mongodb role $version missing SELinux policy build dependency"
    grep -q "mongodb_selinux_policy_version" "$ROOT_DIR/ansible/$version/roles/mongodb/defaults/main.yml" || fail "mongodb role $version does not pin SELinux policy version"
    grep -Eq 'mongodb_selinux_policy_version: "[0-9a-f]{40}"' "$ROOT_DIR/ansible/$version/roles/mongodb/defaults/main.yml" || fail "mongodb role $version SELinux policy version is not a commit SHA"
    grep -q "update: false" "$ROOT_DIR/ansible/$version/roles/mongodb/tasks/main.yml" || fail "mongodb role $version updates SELinux policy from a mutable branch"
    grep -q "mongodb_redhat_selinux_state: permissive" "$ROOT_DIR/ansible/$version/roles/mongodb/defaults/main.yml" || fail "mongodb role $version does not default RedHat-family MongoDB SELinux to permissive"
    grep -q "Persist SELinux permissive mode for MongoDB NDB provisioning" "$ROOT_DIR/ansible/$version/roles/mongodb/tasks/main.yml" || fail "mongodb role $version does not persist SELinux permissive mode for NDB provisioning"
    grep -q "setenforce" "$ROOT_DIR/ansible/$version/roles/mongodb/tasks/main.yml" || fail "mongodb role $version does not apply SELinux permissive mode immediately"
    ! grep -q "ansible_selinux" "$ROOT_DIR/ansible/$version/roles/mongodb/tasks/main.yml" || fail "mongodb role $version uses deprecated top-level SELinux facts"
    grep -q "mongodb_ndb_software_home" "$ROOT_DIR/ansible/$version/roles/mongodb/defaults/main.yml" || fail "mongodb role $version missing NDB-safe software home default"
    grep -q "Link MongoDB binaries into NDB-safe software home" "$ROOT_DIR/ansible/$version/roles/mongodb/tasks/main.yml" || fail "mongodb role $version does not link binaries into NDB-safe software home"
    grep -q "Stop and disable packaged mongod service before image capture" "$ROOT_DIR/ansible/$version/roles/mongodb/tasks/main.yml" || fail "mongodb role $version does not stop mongod before image capture"
    grep -q "apt/{{ ansible_facts" "$ROOT_DIR/ansible/$version/roles/mongodb/tasks/main.yml" || fail "mongodb role $version apt repository path is not distribution-aware"
    ! grep -q "apt/ubuntu " "$ROOT_DIR/ansible/$version/roles/mongodb/tasks/main.yml" || fail "mongodb role $version hardcodes the Ubuntu apt repository path for the whole Debian family"
    ! grep -q "^mongodb_user: mongod" "$ROOT_DIR/ansible/$version/roles/mongodb/defaults/main.yml" || fail "mongodb role $version has RedHat-only user default"
    ! grep -q "^mongodb_group: mongod" "$ROOT_DIR/ansible/$version/roles/mongodb/defaults/main.yml" || fail "mongodb role $version has RedHat-only group default"
  done
  pass "MongoDB provisioning role static checks"
}
run_validate_mongodb_role_static_tests() {
  local version
  for version in 2.9 2.10; do
    grep -q "validate_mongodb_service_active_retries" "$ROOT_DIR/ansible/$version/roles/validate_mongodb/defaults/main.yml" || fail "validate_mongodb role $version missing retry default"
    grep -q "mongod --version" "$ROOT_DIR/ansible/$version/roles/validate_mongodb/tasks/main.yml" || fail "validate_mongodb role $version does not check mongod version"
    grep -q "Check NDB-safe MongoDB software home binary" "$ROOT_DIR/ansible/$version/roles/validate_mongodb/tasks/main.yml" || fail "validate_mongodb role $version does not validate NDB-safe MongoDB software home"
    grep -q "validate_mongodb_ndb_required_binaries" "$ROOT_DIR/ansible/$version/roles/validate_mongodb/tasks/main.yml" || fail "validate_mongodb role $version does not validate required NDB MongoDB tools"
    grep -q "mongodump" "$ROOT_DIR/ansible/$version/roles/validate_mongodb/defaults/main.yml" || fail "validate_mongodb role $version does not require mongodump"
    grep -q "mongorestore" "$ROOT_DIR/ansible/$version/roles/validate_mongodb/defaults/main.yml" || fail "validate_mongodb role $version does not require mongorestore"
    grep -q "Assert SELinux is not enforcing for MongoDB NDB provisioning" "$ROOT_DIR/ansible/$version/roles/validate_mongodb/tasks/main.yml" || fail "validate_mongodb role $version does not reject SELinux enforcing for MongoDB NDB provisioning"
    grep -q "db.version()" "$ROOT_DIR/ansible/$version/roles/validate_mongodb/tasks/main.yml" || fail "validate_mongodb role $version does not check server version"
    grep -q "buildInfo" "$ROOT_DIR/ansible/$version/roles/validate_mongodb/tasks/main.yml" || fail "validate_mongodb role $version does not check MongoDB edition"
    grep -q 'modules.includes("enterprise")' "$ROOT_DIR/ansible/$version/roles/validate_mongodb/tasks/main.yml" || fail "validate_mongodb role $version does not derive enterprise edition"
    grep -q "validate_mongodb_sharded.sh" "$ROOT_DIR/ansible/$version/roles/validate_mongodb/tasks/main.yml" || fail "validate_mongodb role $version does not run sharded validation"
    grep -q "validate_mongodb_replica_set.sh" "$ROOT_DIR/ansible/$version/roles/validate_mongodb/tasks/main.yml" || fail "validate_mongodb role $version does not run replica-set validation"
    grep -q "trap cleanup EXIT" "$ROOT_DIR/ansible/$version/roles/validate_mongodb/files/validate_mongodb_sharded.sh" || fail "sharded validation $version lacks cleanup trap"
    grep -q "sh.addShard" "$ROOT_DIR/ansible/$version/roles/validate_mongodb/files/validate_mongodb_sharded.sh" || fail "sharded validation $version does not add a shard"
    grep -q "choose_ports" "$ROOT_DIR/ansible/$version/roles/validate_mongodb/files/validate_mongodb_sharded.sh" || fail "sharded validation $version uses fixed ports"
    grep -q "cmdline" "$ROOT_DIR/ansible/$version/roles/validate_mongodb/files/validate_mongodb_sharded.sh" || fail "sharded validation $version does not verify PID ownership before cleanup"
    grep -q "trap cleanup EXIT" "$ROOT_DIR/ansible/$version/roles/validate_mongodb/files/validate_mongodb_replica_set.sh" || fail "replica-set validation $version lacks cleanup trap"
    grep -q "rs.status().ok" "$ROOT_DIR/ansible/$version/roles/validate_mongodb/files/validate_mongodb_replica_set.sh" || fail "replica-set validation $version does not check rs.status"
    grep -q "choose_ports" "$ROOT_DIR/ansible/$version/roles/validate_mongodb/files/validate_mongodb_replica_set.sh" || fail "replica-set validation $version uses fixed ports"
    grep -q "cmdline" "$ROOT_DIR/ansible/$version/roles/validate_mongodb/files/validate_mongodb_replica_set.sh" || fail "replica-set validation $version does not verify PID ownership before cleanup"
    grep -q "Stop and disable packaged mongod after validation" "$ROOT_DIR/ansible/$version/roles/validate_mongodb/tasks/main.yml" || fail "validate_mongodb role $version does not stop mongod after validation"
    grep -q "Assert MongoDB listener port is free" "$ROOT_DIR/ansible/$version/roles/validate_mongodb/tasks/main.yml" || fail "validate_mongodb role $version does not prove MongoDB listener port is free before capture"
  done
  pass "MongoDB validation role static checks"
}
run_ndb_common_runtime_guard_tests() {
  local version newline_less_password newline_less_pam_password

  newline_less_password=$(printf 'secret' | bash -c 'password=""; IFS= read -r password || true; printf "%s" "$password"')
  [[ "$newline_less_password" == "secret" ]] || fail "passwd wrapper read pattern does not preserve newline-less stdin"

  newline_less_pam_password=$(printf 'secret' | bash -c 'pam_password=""; IFS= read -r pam_password || true; printf "%s" "$pam_password"')
  [[ "$newline_less_pam_password" == "secret" ]] || fail "PAM auth-token read pattern does not preserve newline-less stdin"

  for version in 2.9 2.10; do
    grep -q "numa=off" "$ROOT_DIR/ansible/$version/roles/common/vars/main.yml" || fail "common role $version missing NDB numa kernel arg default"
    grep -q "transparent_hugepage=never" "$ROOT_DIR/ansible/$version/roles/common/vars/main.yml" || fail "common role $version missing NDB transparent hugepage kernel arg default"
    grep -q "Persist NDB kernel arguments in GRUB defaults" "$ROOT_DIR/ansible/$version/roles/common/tasks/grub.yml" || fail "common role $version does not persist NDB kernel args"
    grep -q "util-linux" "$ROOT_DIR/ansible/$version/roles/common/vars/main.yml" || fail "common role $version does not install util-linux for the reset helper lock"
    grep -q "parted" "$ROOT_DIR/ansible/$version/roles/common/vars/main.yml" || fail "common role $version does not install parted for NDB storage mapping"
    grep -q "nftables" "$ROOT_DIR/ansible/$version/roles/common/vars/main.yml" || fail "common role $version does not install nftables for the Debian SSH reset port gate"
    grep -q "grubby" "$ROOT_DIR/ansible/$version/roles/common/tasks/grub.yml" || fail "common role $version does not apply kernel args to Red Hat boot entries"
    grep -q "update-grub" "$ROOT_DIR/ansible/$version/roles/common/tasks/grub.yml" || fail "common role $version does not refresh Debian GRUB config"
    grep -q "99-ndb-root-device.cfg" "$ROOT_DIR/ansible/$version/roles/common/tasks/grub.yml" || fail "common role $version does not write late Debian GRUB root-device override"
    grep -q "GRUB_DISABLE_LINUX_PARTUUID" "$ROOT_DIR/ansible/$version/roles/common/tasks/grub.yml" || fail "common role $version does not disable Debian PARTUUID root mapping"
    grep -q "GRUB_FORCE_PARTUUID=" "$ROOT_DIR/ansible/$version/roles/common/tasks/grub.yml" || fail "common role $version does not clear Ubuntu cloud-image forced PARTUUID root"
    grep -q "Set Debian-family SSH password auth in main sshd_config" "$ROOT_DIR/ansible/$version/roles/common/tasks/debian_ndb_clone.yml" || fail "common role $version does not set main Debian sshd_config password auth for NDB"
    grep -q "01-ndb-password-auth.conf" "$ROOT_DIR/ansible/$version/roles/common/tasks/debian_ndb_clone.yml" || fail "common role $version does not configure Debian SSH password auth for NDB"
    grep -q "PasswordAuthentication yes" "$ROOT_DIR/ansible/$version/roles/common/tasks/debian_ndb_clone.yml" || fail "common role $version does not allow NDB password SSH on Debian clones"
    grep -q "Assert Debian-family SSH password auth is effective" "$ROOT_DIR/ansible/$version/roles/common/tasks/debian_ndb_clone.yml" || fail "common role $version does not assert effective Debian SSH password auth for NDB"
    grep -q "passwordauthentication yes" "$ROOT_DIR/ansible/$version/roles/common/tasks/debian_ndb_clone.yml" || fail "common role $version does not validate effective Debian SSH password auth with sshd -T"
    grep -q "Remove stale NDB reset hook from Debian-family rc.local" "$ROOT_DIR/ansible/$version/roles/common/tasks/debian_ndb_clone.yml" || fail "common role $version does not sanitize stale Debian rc.local reset hooks"
    grep -q "Remove stale NDB reset script from Debian-family source image" "$ROOT_DIR/ansible/$version/roles/common/tasks/debian_ndb_clone.yml" || fail "common role $version does not remove stale Debian reset scripts before capture"
    grep -q "ndb-reset-password-compat.service" "$ROOT_DIR/ansible/$version/roles/common/tasks/debian_ndb_clone.yml" || fail "common role $version does not install the Debian NDB password reset compatibility service"
    grep -q "ndb-ssh-reset-gate.service" "$ROOT_DIR/ansible/$version/roles/common/tasks/debian_ndb_clone.yml" || fail "common role $version does not install the Debian SSH reset port gate service"
    grep -q "ndb_ssh_reset_gate" "$ROOT_DIR/ansible/$version/roles/common/files/ndb-ssh-reset-gate.sh" || fail "common role $version does not use a dedicated nftables table for the Debian SSH reset port gate"
    grep -q "tcp dport 22 drop" "$ROOT_DIR/ansible/$version/roles/common/files/ndb-ssh-reset-gate.sh" || fail "common role $version SSH reset port gate does not block inbound SSH"
    grep -q "validate-block-rule" "$ROOT_DIR/ansible/$version/roles/common/files/ndb-ssh-reset-gate.sh" || fail "common role $version SSH reset port gate does not expose nft dry-run validation"
    ! grep -q "watch-reset-intent" "$ROOT_DIR/ansible/$version/roles/common/files/ndb-ssh-reset-gate.sh" || fail "common role $version SSH reset port gate must not run a long watcher before early boot targets"
    grep -q "Type=oneshot" "$ROOT_DIR/ansible/$version/roles/common/tasks/storage.yml" || fail "common role $version SSH reset port gate service is not a fast oneshot"
    grep -q "ExecStart=/usr/local/sbin/ndb-ssh-reset-gate block-if-reset-intent" "$ROOT_DIR/ansible/$version/roles/common/tasks/debian_ndb_clone.yml" || fail "common role $version SSH reset port gate service does not synchronously apply the first gate check"
    grep -q "WantedBy=sysinit.target" "$ROOT_DIR/ansible/$version/roles/common/tasks/debian_ndb_clone.yml" || fail "common role $version SSH reset port gate service is not anchored early enough in sysinit.target"
    grep -q "Before=sysinit.target basic.target" "$ROOT_DIR/ansible/$version/roles/common/tasks/debian_ndb_clone.yml" || fail "common role $version SSH reset port gate service is not ordered before early boot targets"
    ! grep -Eq "Before=.*firewalld\\.service" "$ROOT_DIR/ansible/$version/roles/common/tasks/debian_ndb_clone.yml" || fail "common role $version SSH reset port gate must not order itself before firewalld and create Ubuntu boot cycles"
    ! grep -q "Type=simple" "$ROOT_DIR/ansible/$version/roles/common/tasks/debian_ndb_clone.yml" || fail "common role $version SSH reset port gate must not use a boot-blocking Type=simple watcher"
    ! grep -q "tcp dport 22 drop comment" "$ROOT_DIR/ansible/$version/roles/common/files/ndb-ssh-reset-gate.sh" || fail "common role $version SSH reset port gate uses a fragile unescaped nft rule comment"
    grep -q "block-if-reset-intent" "$ROOT_DIR/ansible/$version/roles/common/tasks/debian_ndb_clone.yml" || fail "common role $version SSH reset port gate is not limited to NDB reset intent"
    grep -q "ndb-ssh-reset-gate unblock" "$ROOT_DIR/ansible/$version/roles/common/files/ndb-run-reset-password.sh" || fail "common role $version reset helper does not unblock the SSH reset port gate after reset"
    ! grep -q "ConditionPathExists=/bin/reset_password.sh" "$ROOT_DIR/ansible/$version/roles/common/tasks/debian_ndb_clone.yml" || fail "common role $version reset service still uses a systemd path condition instead of helper-level no-op logic"
    grep -q "DefaultDependencies=no" "$ROOT_DIR/ansible/$version/roles/common/tasks/debian_ndb_clone.yml" || fail "common role $version reset service does not use early boot ordering"
    grep -Eq "Before=.*ssh.service.*sshd.service" "$ROOT_DIR/ansible/$version/roles/common/tasks/debian_ndb_clone.yml" || fail "common role $version password reset service does not run before SSH"
    grep -q "ssh.service.d/10-ndb-reset-password.conf" "$ROOT_DIR/ansible/$version/roles/common/tasks/debian_ndb_clone.yml" || fail "common role $version does not attach the NDB password reset to SSH startup"
    grep -q "sshd.service.d/10-ndb-reset-password.conf" "$ROOT_DIR/ansible/$version/roles/common/tasks/debian_ndb_clone.yml" || fail "common role $version does not attach the NDB password reset to the SSH alias startup"
    grep -q "Check Debian-family SSH socket activation unit" "$ROOT_DIR/ansible/$version/roles/common/tasks/debian_ndb_clone.yml" || fail "common role $version does not check for SSH socket support before masking it"
    grep -q "ssh.socket" "$ROOT_DIR/ansible/$version/roles/common/tasks/debian_ndb_clone.yml" || fail "common role $version does not disable Debian SSH socket activation"
    grep -q "masked: false" "$ROOT_DIR/ansible/$version/roles/common/tasks/debian_ndb_clone.yml" || fail "common role $version must leave Debian SSH socket unmasked so ssh.service can start on socket-backed images"
    ! grep -q "masked: true" "$ROOT_DIR/ansible/$version/roles/common/tasks/debian_ndb_clone.yml" || fail "common role $version masks Debian SSH socket and can prevent ssh.service from starting"
    grep -q "Ensure Debian-family SSH service remains enabled after socket activation disablement" "$ROOT_DIR/ansible/$version/roles/common/tasks/debian_ndb_clone.yml" || fail "common role $version does not re-enable SSH service after disabling socket activation"
    grep -q "Wants=ndb-reset-password-compat.service" "$ROOT_DIR/ansible/$version/roles/common/tasks/debian_ndb_clone.yml" || fail "common role $version SSH drop-in does not explicitly start the Debian reset service before SSH"
    grep -q "After=ndb-reset-password-compat.service" "$ROOT_DIR/ansible/$version/roles/common/tasks/debian_ndb_clone.yml" || fail "common role $version SSH drop-in does not order SSH after the Debian reset service"
    ! grep -q "After=ndb-reset-password-compat.service rc-local.service" "$ROOT_DIR/ansible/$version/roles/common/tasks/debian_ndb_clone.yml" || fail "common role $version SSH drop-in can deadlock cloud-init SSH startup by waiting directly on rc-local.service"
    grep -q "ExecStartPre=/usr/local/sbin/ndb-run-reset-password" "$ROOT_DIR/ansible/$version/roles/common/tasks/debian_ndb_clone.yml" || fail "common role $version SSH drop-in does not run the reset helper before SSH"
    grep -q -- "--wait-for-script 150" "$ROOT_DIR/ansible/$version/roles/common/tasks/debian_ndb_clone.yml" || fail "common role $version SSH drop-in does not wait for late NDB reset-script injection"
    grep -q "Run NDB injected password reset before Debian-family SSH password authentication" "$ROOT_DIR/ansible/$version/roles/common/tasks/debian_ndb_clone.yml" || fail "common role $version does not gate Debian SSH password authentication through the reset helper"
    grep -q 'auth required pam_exec.so quiet seteuid expose_authtok /usr/local/sbin/ndb-run-reset-password --pam-auth-token {{ ndb_drive_user }}' "$ROOT_DIR/ansible/$version/roles/common/tasks/debian_ndb_clone.yml" || fail "common role $version does not add the Debian SSH PAM auth-token reset gate with effective-root privileges for the configured NDB drive user"
    grep -q "Normalize NDB drive user before Debian-family SSH account checks" "$ROOT_DIR/ansible/$version/roles/common/tasks/debian_ndb_clone.yml" || fail "common role $version does not normalize the NDB drive user before Debian SSH account checks"
    grep -q 'account required pam_exec.so quiet seteuid /usr/local/sbin/ndb-run-reset-password --pam-account {{ ndb_drive_user }}' "$ROOT_DIR/ansible/$version/roles/common/tasks/debian_ndb_clone.yml" || fail "common role $version does not add the Debian SSH PAM account normalization gate with effective-root privileges"
    grep -q "Bypass Debian-family boot nologin for NDB drive user" "$ROOT_DIR/ansible/$version/roles/common/tasks/debian_ndb_clone.yml" || fail "common role $version does not skip boot nologin for the NDB drive user"
    grep -Fq 'account [success=1 default=ignore] pam_succeed_if.so quiet user = {{ ndb_drive_user }}' "$ROOT_DIR/ansible/$version/roles/common/tasks/debian_ndb_clone.yml" || fail "common role $version does not install a user-scoped pam_nologin bypass for the NDB drive user"
    grep -q "pam_nologin" "$ROOT_DIR/ansible/$version/roles/common/tasks/debian_ndb_clone.yml" || fail "common role $version NDB nologin bypass is not anchored to pam_nologin"
    grep -q "wait_seconds=0" "$ROOT_DIR/ansible/$version/roles/common/files/ndb-run-reset-password.sh" || fail "common role $version reset helper does not support bounded wait mode"
    grep -q "pam_token_user=" "$ROOT_DIR/ansible/$version/roles/common/files/ndb-run-reset-password.sh" || fail "common role $version reset helper does not support PAM auth-token mode"
    grep -q "pam_account_user=" "$ROOT_DIR/ansible/$version/roles/common/files/ndb-run-reset-password.sh" || fail "common role $version reset helper does not support PAM account mode"
    grep -q "pam_password=" "$ROOT_DIR/ansible/$version/roles/common/files/ndb-run-reset-password.sh" || fail "common role $version reset helper does not capture the PAM auth token before fallback"
    grep -q "IFS= read -r pam_password || true" "$ROOT_DIR/ansible/$version/roles/common/files/ndb-run-reset-password.sh" || fail "common role $version reset helper does not preserve newline-less PAM auth tokens"
    grep -q "IFS= read -r password || true" "$ROOT_DIR/ansible/$version/roles/common/files/ndb-passwd-stdin.sh" || fail "common role $version passwd wrapper does not preserve newline-less stdin passwords"
    ! grep -q 'IFS= read -r pam_password || pam_password=""' "$ROOT_DIR/ansible/$version/roles/common/files/ndb-run-reset-password.sh" || fail "common role $version reset helper clears newline-less PAM auth tokens"
    ! grep -q 'IFS= read -r password || password=""' "$ROOT_DIR/ansible/$version/roles/common/files/ndb-passwd-stdin.sh" || fail "common role $version passwd wrapper clears newline-less stdin passwords"
    grep -q "set_password_from_pam_token" "$ROOT_DIR/ansible/$version/roles/common/files/ndb-run-reset-password.sh" || fail "common role $version reset helper does not fall back to the PAM auth token when OpenSSH provides one"
    grep -q "normalize_password_login_account" "$ROOT_DIR/ansible/$version/roles/common/files/ndb-passwd-stdin.sh" || fail "common role $version reset helper does not normalize the drive-user account after password reset"
    grep -q "usermod --unlock" "$ROOT_DIR/ansible/$version/roles/common/files/ndb-passwd-stdin.sh" || fail "common role $version reset helper does not unlock the drive-user account after password reset"
    grep -q "chage -E -1 -I -1 -m 0 -M 99999" "$ROOT_DIR/ansible/$version/roles/common/files/ndb-passwd-stdin.sh" || fail "common role $version reset helper does not unexpire the drive-user account after password reset"
    grep -q 'normalize_password_login_account "$user"' "$ROOT_DIR/ansible/$version/roles/common/files/ndb-passwd-stdin.sh" || fail "common role $version passwd wrapper does not normalize account state after chpasswd"
    grep -q 'normalize_password_login_account "$target_user"' "$ROOT_DIR/ansible/$version/roles/common/files/ndb-run-reset-password.sh" || fail "common role $version PAM token fallback does not normalize account state after chpasswd"
    grep -q 'normalize_password_login_account "$pam_account_user"' "$ROOT_DIR/ansible/$version/roles/common/files/ndb-run-reset-password.sh" || fail "common role $version PAM account hook does not normalize account state"
    ! grep -q 'if \[\[ -f "\$done_marker" || ! -f "\$script" \]\]' "$ROOT_DIR/ansible/$version/roles/common/files/ndb-run-reset-password.sh" || fail "common role $version PAM account hook unblocks SSH before reset completion when the reset script is absent"
    grep -q "NDB PAM account normalization completed" "$ROOT_DIR/ansible/$version/roles/common/files/ndb-run-reset-password.sh" || fail "common role $version reset helper does not log PAM account normalization"
    grep -q "NDB injected password reset completed during PAM account check" "$ROOT_DIR/ansible/$version/roles/common/files/ndb-run-reset-password.sh" || fail "common role $version reset helper does not run reset work from the PAM account phase"
    grep -q "script_completed=false" "$ROOT_DIR/ansible/$version/roles/common/files/ndb-run-reset-password.sh" || fail "common role $version reset helper does not track completed NDB reset scripts in PAM mode"
    grep -q "Applying PAM auth-token password reset for" "$ROOT_DIR/ansible/$version/roles/common/files/ndb-run-reset-password.sh" || fail "common role $version reset helper does not apply the PAM auth-token password when one is available"
    grep -q "PAM auth token unavailable; trusting completed NDB injected password reset" "$ROOT_DIR/ansible/$version/roles/common/files/ndb-run-reset-password.sh" || fail "common role $version reset helper does not tolerate OpenSSH PAM auth without an exposed token after a successful reset script"
    grep -q "interactive or Red Hat-style passwd forms" "$ROOT_DIR/ansible/$version/roles/common/files/ndb-run-reset-password.sh" || fail "common role $version reset helper does not rewrite interactive passwd forms for Debian"
    grep -q 'exec /usr/bin/passwd "$@"' "$ROOT_DIR/ansible/$version/roles/common/files/ndb-passwd-stdin.sh" || fail "common role $version passwd compatibility helper does not delegate unsupported passwd invocations"
    ! grep -q '\${#' "$ROOT_DIR/ansible/$version/roles/common/tasks/debian_ndb_clone.yml" || fail "common role $version inline shell contains unescaped Bash length syntax that Jinja parses as a comment"
    grep -q "PAM_USER" "$ROOT_DIR/ansible/$version/roles/common/files/ndb-run-reset-password.sh" || fail "common role $version reset helper does not gate PAM token fallback by PAM user"
    grep -q "rc_local_references_reset=false" "$ROOT_DIR/ansible/$version/roles/common/files/ndb-run-reset-password.sh" || fail "common role $version reset helper does not track rc.local reset intent"
    grep -q 'rc_local_references_reset" != "true"' "$ROOT_DIR/ansible/$version/roles/common/files/ndb-run-reset-password.sh" || fail "common role $version reset helper waits on normal boots without rc.local reset intent"
    grep -q "NDB PAM auth waiting for late injected reset script" "$ROOT_DIR/ansible/$version/roles/common/files/ndb-run-reset-password.sh" || fail "common role $version PAM auth helper does not wait for late NDB reset-script injection before password checks"
    grep -q '\[\[ -e /etc/rc.local \]\]' "$ROOT_DIR/ansible/$version/roles/common/files/ndb-run-reset-password.sh" || fail "common role $version PAM auth helper does not use NDB-created rc.local as the late reset-injection signal"
    grep -q "NDB PAM auth-token password reset triggered by NDB-created rc.local" "$ROOT_DIR/ansible/$version/roles/common/files/ndb-run-reset-password.sh" || fail "common role $version PAM auth helper does not set the password from the NDB auth token when rc.local exists before reset script injection"
    ! grep -q "NDB reset helper waiting for late injected reset script before SSH opens" "$ROOT_DIR/ansible/$version/roles/common/files/ndb-run-reset-password.sh" || fail "common role $version reset helper blocks normal SSH startup while waiting for late reset injection"
    grep -q "flock -w 300" "$ROOT_DIR/ansible/$version/roles/common/files/ndb-run-reset-password.sh" || fail "common role $version reset helper does not serialize concurrent reset attempts"
    grep -q "done_marker=/run/ndb-reset-password.done" "$ROOT_DIR/ansible/$version/roles/common/files/ndb-ssh-reset-gate.sh" || fail "common role $version reset helper does not mark successful reset completion"
    grep -q "reset_already_completed=false" "$ROOT_DIR/ansible/$version/roles/common/files/ndb-run-reset-password.sh" || fail "common role $version reset helper does not track pre-existing reset completion separately from PAM auth"
    ! grep -q 'if \[\[ -f "\$done_marker" \]\] && \[\[ -n "\$pam_token_user" \]\]' "$ROOT_DIR/ansible/$version/roles/common/files/ndb-run-reset-password.sh" || fail "common role $version reset helper exits before PAM auth-token fallback when reset is already marked complete"
    grep -q "NDB injected password reset was already marked complete before PAM auth" "$ROOT_DIR/ansible/$version/roles/common/files/ndb-run-reset-password.sh" || fail "common role $version reset helper does not allow PAM token fallback after an earlier reset marker"
    grep -q "NDB injected password reset failed with exit status" "$ROOT_DIR/ansible/$version/roles/common/files/ndb-run-reset-password.sh" || fail "common role $version reset helper does not fail closed on reset errors"
    ! grep -q '/bin/bash "\$script".*|| true' "$ROOT_DIR/ansible/$version/roles/common/files/ndb-run-reset-password.sh" || fail "common role $version reset helper still masks reset-script failures"
    grep -q "networking.service.d/10-ndb-reset-password.conf" "$ROOT_DIR/ansible/$version/roles/common/tasks/debian_ndb_clone.yml" || fail "common role $version does not attach the NDB password reset to Debian networking startup"
    grep -q "Before=networking.service" "$ROOT_DIR/ansible/$version/roles/common/tasks/debian_ndb_clone.yml" || fail "common role $version reset service is not ordered before Debian networking"
    grep -q "/usr/local/sbin/ndb-run-reset-password" "$ROOT_DIR/ansible/$version/roles/common/tasks/debian_ndb_clone.yml" || fail "common role $version SSH drop-in does not use the Debian-safe NDB reset helper"
    grep -q "/usr/local/sbin/ndb-passwd-stdin" "$ROOT_DIR/ansible/$version/roles/common/tasks/debian_ndb_clone.yml" || fail "common role $version does not install a passwd --stdin compatibility helper"
    grep -q "chpasswd" "$ROOT_DIR/ansible/$version/roles/common/files/ndb-passwd-stdin.sh" || fail "common role $version NDB reset compatibility helper does not use chpasswd"
    grep -q "/bin/reset_password.sh" "$ROOT_DIR/ansible/$version/roles/common/tasks/debian_ndb_clone.yml" || fail "common role $version SSH drop-in does not handle NDB's injected reset script"
    grep -q "/opt/era_base/era_startup.log" "$ROOT_DIR/ansible/$version/roles/common/files/ndb-ssh-reset-gate.sh" || fail "common role $version SSH drop-in does not preserve reset logs"
    grep -q "ndb-era-dm-compat" "$ROOT_DIR/ansible/$version/roles/common/tasks/storage.yml" || fail "common role $version does not install the NDB Era device-mapper helper"
    grep -q "ntnx_era_agent_vg_*" "$ROOT_DIR/ansible/$version/roles/common/files/ndb-era-dm-compat.sh" || fail "common role $version NDB Era device-mapper helper is not scoped to NDB Era LVM volumes"
    grep -q "dmsetup deps -o devname" "$ROOT_DIR/ansible/$version/roles/common/files/ndb-era-dm-compat.sh" || fail "common role $version NDB Era device-mapper helper does not derive parent disks"
    grep -Fq '[[ "$kernel" =~ ^dm-[0-9]+$ ]]' "$ROOT_DIR/ansible/$version/roles/common/files/ndb-era-dm-compat.sh" || fail "common role $version NDB Era device-mapper helper can recursively process generated DM aliases"
    grep -q '/dev/${kernel}..' "$ROOT_DIR/ansible/$version/roles/common/files/ndb-era-dm-compat.sh" || fail "common role $version NDB Era device-mapper helper does not create malformed DM aliases"
    grep -Fq 'ln -s "$dm_dev" "$alias"' "$ROOT_DIR/ansible/$version/roles/common/files/ndb-era-dm-compat.sh" || fail "common role $version NDB Era device-mapper helper must create symlink aliases"
    ! grep -q "mknod -m" "$ROOT_DIR/ansible/$version/roles/common/files/ndb-era-dm-compat.sh" || fail "common role $version NDB Era device-mapper helper must not create block-device aliases"
    grep -q "99-ndb-era-dm-serial.rules" "$ROOT_DIR/ansible/$version/roles/common/files/ndb-era-dm-compat.sh" || fail "common role $version NDB Era device-mapper helper does not write udev serial metadata"
    grep -q "ndb-era-dm-compat.timer" "$ROOT_DIR/ansible/$version/roles/common/tasks/storage.yml" || fail "common role $version does not install the NDB Era device-mapper timer"
    grep -q "OnUnitActiveSec=10s" "$ROOT_DIR/ansible/$version/roles/common/tasks/storage.yml" || fail "common role $version NDB Era device-mapper timer does not rerun during target disk attach"
    grep -q "Expose Debian-family chrony config at NDB expected path" "$ROOT_DIR/ansible/$version/roles/common/tasks/services.yml" || fail "common role $version does not expose /etc/chrony.conf for Debian-family NDB compatibility"
    grep -q "Ensure Debian-family D-Bus service is pulled in during first boot" "$ROOT_DIR/ansible/$version/roles/common/tasks/services.yml" || fail "common role $version does not guarantee Debian-family D-Bus first-boot startup"
    grep -q "basic.target.wants/dbus.service" "$ROOT_DIR/ansible/$version/roles/common/tasks/services.yml" || fail "common role $version does not anchor dbus.service to basic.target"
    grep -q "sockets.target.wants/dbus.socket" "$ROOT_DIR/ansible/$version/roles/common/tasks/services.yml" || fail "common role $version does not anchor dbus.socket to sockets.target"
    grep -q "Check firewalld SSH service rule" "$ROOT_DIR/ansible/$version/roles/common/tasks/services.yml" || fail "common role $version does not check whether firewalld allows SSH"
    grep -q "Allow SSH through firewalld" "$ROOT_DIR/ansible/$version/roles/common/tasks/services.yml" || fail "common role $version does not allow SSH through firewalld"
    grep -q "Reload firewalld after allowing SSH" "$ROOT_DIR/ansible/$version/roles/common/tasks/services.yml" || fail "common role $version does not reload firewalld after allowing SSH"
    grep -q "name: validate_common" "$ROOT_DIR/ansible/$version/roles/validate_postgres/tasks/main.yml" || fail "validate_postgres role $version does not include the shared validate_common checks"
    grep -q "name: validate_common" "$ROOT_DIR/ansible/$version/roles/validate_mongodb/tasks/main.yml" || fail "validate_mongodb role $version does not include the shared validate_common checks"
    grep -q "Assert GRUB defaults include NDB kernel arguments" "$ROOT_DIR/ansible/$version/roles/validate_common/tasks/main.yml" || fail "validate_postgres role $version does not validate NDB kernel args"
    grep -q "Assert GRUB defaults include NDB kernel arguments" "$ROOT_DIR/ansible/$version/roles/validate_common/tasks/main.yml" || fail "validate_mongodb role $version does not validate NDB kernel args"
    grep -q "Assert firewalld allows SSH" "$ROOT_DIR/ansible/$version/roles/validate_common/tasks/main.yml" || fail "validate_postgres role $version does not validate firewalld SSH access"
    grep -q "Assert firewalld allows SSH" "$ROOT_DIR/ansible/$version/roles/validate_common/tasks/main.yml" || fail "validate_mongodb role $version does not validate firewalld SSH access"
    grep -q "Assert Debian-family NDB chrony config path exists" "$ROOT_DIR/ansible/$version/roles/validate_common/tasks/main.yml" || fail "validate_postgres role $version does not validate Debian-family /etc/chrony.conf compatibility"
    grep -q "Assert Debian-family NDB chrony config path exists" "$ROOT_DIR/ansible/$version/roles/validate_common/tasks/main.yml" || fail "validate_mongodb role $version does not validate Debian-family /etc/chrony.conf compatibility"
    grep -q "Validate Debian-family D-Bus first-boot readiness" "$ROOT_DIR/ansible/$version/roles/validate_common/tasks/main.yml" || fail "validate_postgres role $version does not validate Debian-family D-Bus first-boot readiness"
    grep -q "Validate Debian-family D-Bus first-boot readiness" "$ROOT_DIR/ansible/$version/roles/validate_common/tasks/main.yml" || fail "validate_mongodb role $version does not validate Debian-family D-Bus first-boot readiness"
    grep -q "/run/dbus/system_bus_socket" "$ROOT_DIR/ansible/$version/roles/validate_common/tasks/main.yml" || fail "validate_postgres role $version does not validate the D-Bus system socket"
    grep -q "/run/dbus/system_bus_socket" "$ROOT_DIR/ansible/$version/roles/validate_common/tasks/main.yml" || fail "validate_mongodb role $version does not validate the D-Bus system socket"
    grep -q "Validate Debian-family captured image has no stale NDB reset script" "$ROOT_DIR/ansible/$version/roles/validate_common/tasks/main.yml" || fail "validate_postgres role $version does not validate stale Debian reset script removal"
    grep -q "Validate Debian-family captured image has no stale NDB reset script" "$ROOT_DIR/ansible/$version/roles/validate_common/tasks/main.yml" || fail "validate_mongodb role $version does not validate stale Debian reset script removal"
    grep -q "Validate Debian-family rc.local has no stale NDB reset hook" "$ROOT_DIR/ansible/$version/roles/validate_common/tasks/main.yml" || fail "validate_postgres role $version does not validate stale Debian rc.local reset hook removal"
    grep -q "Validate Debian-family rc.local has no stale NDB reset hook" "$ROOT_DIR/ansible/$version/roles/validate_common/tasks/main.yml" || fail "validate_mongodb role $version does not validate stale Debian rc.local reset hook removal"
    grep -q "Validate Debian-family NDB reset helper wait mode" "$ROOT_DIR/ansible/$version/roles/validate_common/tasks/main.yml" || fail "validate_postgres role $version does not validate Debian-family reset helper wait mode"
    grep -q "Validate Debian-family NDB reset helper wait mode" "$ROOT_DIR/ansible/$version/roles/validate_common/tasks/main.yml" || fail "validate_mongodb role $version does not validate Debian-family reset helper wait mode"
    grep -q "Validate Debian-family SSH reset port gate helper" "$ROOT_DIR/ansible/$version/roles/validate_common/tasks/main.yml" || fail "validate_postgres role $version does not validate Debian-family SSH reset port gate helper"
    grep -q "Validate Debian-family SSH reset port gate helper" "$ROOT_DIR/ansible/$version/roles/validate_common/tasks/main.yml" || fail "validate_mongodb role $version does not validate Debian-family SSH reset port gate helper"
    grep -q "validate-block-rule" "$ROOT_DIR/ansible/$version/roles/validate_common/tasks/main.yml" || fail "validate_postgres role $version does not dry-run validate the Debian SSH reset port gate nft rule"
    grep -q "validate-block-rule" "$ROOT_DIR/ansible/$version/roles/validate_common/tasks/main.yml" || fail "validate_mongodb role $version does not dry-run validate the Debian SSH reset port gate nft rule"
    grep -q "Validate Debian-family SSH reset port gate service" "$ROOT_DIR/ansible/$version/roles/validate_common/tasks/main.yml" || fail "validate_postgres role $version does not validate Debian-family SSH reset port gate service"
    grep -q "Validate Debian-family SSH reset port gate service" "$ROOT_DIR/ansible/$version/roles/validate_common/tasks/main.yml" || fail "validate_mongodb role $version does not validate Debian-family SSH reset port gate service"
    grep -q "Type=oneshot" "$ROOT_DIR/ansible/$version/roles/validate_common/tasks/main.yml" || fail "validate_postgres role $version does not validate the fast reset gate service type"
    grep -q "Type=oneshot" "$ROOT_DIR/ansible/$version/roles/validate_common/tasks/main.yml" || fail "validate_mongodb role $version does not validate the fast reset gate service type"
    grep -q "ExecStart=/usr/local/sbin/ndb-ssh-reset-gate block-if-reset-intent" "$ROOT_DIR/ansible/$version/roles/validate_common/tasks/main.yml" || fail "validate_postgres role $version does not validate the fast reset gate command"
    grep -q "ExecStart=/usr/local/sbin/ndb-ssh-reset-gate block-if-reset-intent" "$ROOT_DIR/ansible/$version/roles/validate_common/tasks/main.yml" || fail "validate_mongodb role $version does not validate the fast reset gate command"
    grep -q "watch-reset-intent" "$ROOT_DIR/ansible/$version/roles/validate_common/tasks/main.yml" || fail "validate_postgres role $version does not reject the old boot-blocking reset gate watcher"
    grep -q "watch-reset-intent" "$ROOT_DIR/ansible/$version/roles/validate_common/tasks/main.yml" || fail "validate_mongodb role $version does not reject the old boot-blocking reset gate watcher"
    grep -q "Before=.*firewalld.service" "$ROOT_DIR/ansible/$version/roles/validate_common/tasks/main.yml" || fail "validate_postgres role $version does not reject firewalld ordering in the SSH reset gate service"
    grep -q "Before=.*firewalld.service" "$ROOT_DIR/ansible/$version/roles/validate_common/tasks/main.yml" || fail "validate_mongodb role $version does not reject firewalld ordering in the SSH reset gate service"
    grep -q "sysinit.target.wants/ndb-ssh-reset-gate.service" "$ROOT_DIR/ansible/$version/roles/validate_common/tasks/main.yml" || fail "validate_postgres role $version does not validate early sysinit anchoring for the SSH reset port gate"
    grep -q "sysinit.target.wants/ndb-ssh-reset-gate.service" "$ROOT_DIR/ansible/$version/roles/validate_common/tasks/main.yml" || fail "validate_mongodb role $version does not validate early sysinit anchoring for the SSH reset port gate"
    ! grep -q "Validate Debian-family SSH waits for rc-local reset path" "$ROOT_DIR/ansible/$version/roles/validate_postgres/tasks/main.yml" || fail "validate_postgres role $version still validates the removed rc-local SSH ordering"
    ! grep -q "Validate Debian-family SSH waits for rc-local reset path" "$ROOT_DIR/ansible/$version/roles/validate_mongodb/tasks/main.yml" || fail "validate_mongodb role $version still validates the removed rc-local SSH ordering"
    grep -q "Validate Debian-family SSH PAM reset gate" "$ROOT_DIR/ansible/$version/roles/validate_common/tasks/main.yml" || fail "validate_postgres role $version does not validate Debian-family SSH PAM reset gate"
    grep -q "Validate Debian-family SSH PAM reset gate" "$ROOT_DIR/ansible/$version/roles/validate_common/tasks/main.yml" || fail "validate_mongodb role $version does not validate Debian-family SSH PAM reset gate"
    grep -q "Validate Debian-family SSH PAM nologin bypass for NDB drive user" "$ROOT_DIR/ansible/$version/roles/validate_common/tasks/main.yml" || fail "validate_postgres role $version does not validate Debian-family SSH PAM nologin bypass"
    grep -q "Validate Debian-family SSH PAM nologin bypass for NDB drive user" "$ROOT_DIR/ansible/$version/roles/validate_common/tasks/main.yml" || fail "validate_mongodb role $version does not validate Debian-family SSH PAM nologin bypass"
    grep -q "Validate Debian-family SSH PAM account normalization gate" "$ROOT_DIR/ansible/$version/roles/validate_common/tasks/main.yml" || fail "validate_postgres role $version does not validate Debian-family SSH PAM account normalization gate"
    grep -q "Validate Debian-family SSH PAM account normalization gate" "$ROOT_DIR/ansible/$version/roles/validate_common/tasks/main.yml" || fail "validate_mongodb role $version does not validate Debian-family SSH PAM account normalization gate"
    grep -q "Validate Debian-family reset helper normalizes PAM account state" "$ROOT_DIR/ansible/$version/roles/validate_common/tasks/main.yml" || fail "validate_postgres role $version does not validate Debian-family PAM account normalization"
    grep -q "Validate Debian-family reset helper normalizes PAM account state" "$ROOT_DIR/ansible/$version/roles/validate_common/tasks/main.yml" || fail "validate_mongodb role $version does not validate Debian-family PAM account normalization"
    grep -q "Assert Debian-family SSH socket activation cannot bypass reset gate" "$ROOT_DIR/ansible/$version/roles/validate_common/tasks/main.yml" || fail "validate_postgres role $version does not validate SSH socket reset-gate protection"
    grep -q "Assert Debian-family SSH socket activation cannot bypass reset gate" "$ROOT_DIR/ansible/$version/roles/validate_common/tasks/main.yml" || fail "validate_mongodb role $version does not validate SSH socket reset-gate protection"
    ! grep -q 'stdout in \["masked", "disabled"\]' "$ROOT_DIR/ansible/$version/roles/validate_postgres/tasks/main.yml" || fail "validate_postgres role $version still accepts masked SSH socket state"
    ! grep -q 'stdout in \["masked", "disabled"\]' "$ROOT_DIR/ansible/$version/roles/validate_mongodb/tasks/main.yml" || fail "validate_mongodb role $version still accepts masked SSH socket state"
    grep -q "Assert Debian-family SSH service is enabled after socket activation disablement" "$ROOT_DIR/ansible/$version/roles/validate_common/tasks/main.yml" || fail "validate_postgres role $version does not validate SSH service enablement after socket activation disablement"
    grep -q "Assert Debian-family SSH service is enabled after socket activation disablement" "$ROOT_DIR/ansible/$version/roles/validate_common/tasks/main.yml" || fail "validate_mongodb role $version does not validate SSH service enablement after socket activation disablement"
    grep -q "root=/dev/" "$ROOT_DIR/ansible/$version/roles/validate_common/tasks/main.yml" || fail "validate_postgres role $version does not validate Debian root disk mapping"
    grep -q "root=/dev/" "$ROOT_DIR/ansible/$version/roles/validate_common/tasks/main.yml" || fail "validate_mongodb role $version does not validate Debian root disk mapping"
    grep -q "Validate Debian-family NDB Era device-mapper helper" "$ROOT_DIR/ansible/$version/roles/validate_common/tasks/main.yml" || fail "validate_postgres role $version does not validate the NDB Era device-mapper helper"
    grep -q "Validate Debian-family NDB Era device-mapper helper" "$ROOT_DIR/ansible/$version/roles/validate_common/tasks/main.yml" || fail "validate_mongodb role $version does not validate the NDB Era device-mapper helper"
    grep -q "Validate Debian-family NDB Era device-mapper timer" "$ROOT_DIR/ansible/$version/roles/validate_common/tasks/main.yml" || fail "validate_postgres role $version does not validate the NDB Era device-mapper timer"
    grep -q "Validate Debian-family NDB Era device-mapper timer" "$ROOT_DIR/ansible/$version/roles/validate_common/tasks/main.yml" || fail "validate_mongodb role $version does not validate the NDB Era device-mapper timer"
    grep -q "command -v parted" "$ROOT_DIR/ansible/$version/roles/validate_common/tasks/main.yml" || fail "validate_postgres role $version does not validate parted for NDB storage mapping"
    grep -q "command -v parted" "$ROOT_DIR/ansible/$version/roles/validate_common/tasks/main.yml" || fail "validate_mongodb role $version does not validate parted for NDB storage mapping"
    grep -q "validate_mongodb_db_os_user" "$ROOT_DIR/ansible/$version/roles/validate_mongodb/tasks/main.yml" || fail "validate_mongodb role $version does not validate MongoDB DB OS user"
  done
  grep -q "getent passwd mongod" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "E2E runner does not detect Red Hat MongoDB DB OS user"
  grep -q "getent passwd mongodb" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "E2E runner does not detect Debian MongoDB DB OS user"
  grep -q '\$state\[0\]\.db_os_user' "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "E2E runner does not pass detected DB OS user to NDB registration"
  grep -q "NDB_E2E_POSTGRES_SOFTWARE_HOME_BASE" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "E2E runner does not expose PostgreSQL software home base"
  grep -q "NDB_E2E_POSTGRES_SOFTWARE_DISK_SIZE_GB" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "E2E runner does not expose PostgreSQL software disk sizing"
  grep -q "Preparing dedicated PostgreSQL software disk" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "E2E runner does not prepare a dedicated PostgreSQL software disk"
  grep -q "/opt/ndb/postgresql" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "E2E runner does not use an NDB-safe PostgreSQL software home"
  grep -q 'mountpoint -q "$NDB_PG_SOFTWARE_HOME"' "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "E2E runner does not require PostgreSQL software home to be an exact mountpoint"
  grep -q 'SSH_MAX_POLLS=${NDB_E2E_SSH_MAX_POLLS:-30}' "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "E2E runner default SSH readiness wait is too long for unreachable Prism IP retries"
  grep -q 'vm_lifecycle_set_ssh_args "\$PRIVATE_KEY_PATH" 5' "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "E2E runner SSH probes use too long a connection timeout for unreachable Prism IP retries"
  grep -q "prepare_debian_ndb_dm_serial_metadata" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "E2E runner does not prepare Debian/Ubuntu NDB device-mapper serial metadata"
  grep -q "99-ndb-era-dm-serial.rules" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "E2E runner does not install the temporary NDB Era-drive udev rule"
  grep -q "dmsetup deps -o devname" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "E2E runner does not derive NDB Era-drive DM parent disks"
  grep -Fq '[[ "$kernel" =~ ^dm-[0-9]+$ ]]' "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "E2E runner can recursively process generated DM aliases"
  grep -q '/dev/${kernel}..' "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "E2E runner does not create NDB-compatible malformed DM device aliases"
  grep -Fq 'ln -s "$dm_dev" "$alias"' "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "E2E runner must create NDB-compatible DM symlink aliases"
  ! grep -q "mknod -m" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "E2E runner must not create block-device DM aliases"
  grep -q "did not return an operationId" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "E2E runner does not fail clearly on NDB registration API errors"
  grep -q "transparent_hugepage=never" "$ROOT_DIR/README.md" || fail "README missing NDB kernel argument guidance"
  grep -q "root=PARTUUID" "$ROOT_DIR/README.md" || fail "README missing Debian root disk mapping guidance"
  grep -q "/run/dbus/system_bus_socket" "$ROOT_DIR/README.md" || fail "README missing Debian/Ubuntu D-Bus first-boot guidance"
  grep -q "NDB_E2E_POSTGRES_SOFTWARE_DISK_SIZE_GB" "$ROOT_DIR/README.md" || fail "README missing PostgreSQL E2E software disk guidance"
  grep -q "ndb-era-dm-compat" "$ROOT_DIR/README.md" || fail "README missing Debian/Ubuntu NDB Era device-mapper helper guidance"
  grep -q "NDB-side storage/protection issue" "$ROOT_DIR/README.md" || fail "README missing Debian/Ubuntu NDB storage/protection escalation guidance"
  grep -q -- "-u mongodb" "$ROOT_DIR/README.md" || fail "README missing Ubuntu/Debian MongoDB precheck user guidance"
  pass "NDB common runtime guards"
}
run_image_prepare_tests() {
  local version
  for version in 2.9 2.10; do
    grep -q -- "- image_prepare" "$ROOT_DIR/ansible/$version/playbooks/site.yml" || fail "playbook $version does not run final image preparation"
    grep -q "/usr/bin/cloud-init clean --logs --machine-id" "$ROOT_DIR/ansible/$version/roles/image_prepare/tasks/main.yml" || fail "image_prepare role $version does not reset cloud-init state"
    grep -q "/etc/netplan/50-cloud-init.yaml" "$ROOT_DIR/ansible/$version/roles/image_prepare/tasks/main.yml" || fail "image_prepare role $version does not remove generated Ubuntu netplan"
    grep -q "ansible.builtin.assert" "$ROOT_DIR/ansible/$version/roles/image_prepare/tasks/main.yml" || fail "image_prepare role $version does not assert cloud-init availability"
    grep -q "rm -f /etc/ssh/ssh_host_" "$ROOT_DIR/ansible/$version/roles/image_prepare/tasks/main.yml" || fail "image_prepare role $version does not remove baked SSH host keys"
    grep -q "userdel --force --remove packer" "$ROOT_DIR/ansible/$version/roles/image_prepare/tasks/main.yml" || fail "image_prepare role $version does not remove the packer build user"
    grep -q "getent passwd packer" "$ROOT_DIR/ansible/$version/roles/image_prepare/tasks/main.yml" || fail "image_prepare role $version does not verify packer build user removal"
    grep -q "ndb-ssh-hostkeys-ensure.service" "$ROOT_DIR/ansible/$version/roles/common/tasks/services.yml" || fail "common role $version does not install the SSH host key regeneration guard"
    grep -q "Enforce database runtime is disabled before image capture" "$ROOT_DIR/ansible/$version/roles/image_prepare/tasks/main.yml" || fail "image_prepare role $version does not unconditionally enforce the disabled-database invariant"
    grep -q "image_prepare_guard_port" "$ROOT_DIR/ansible/$version/roles/image_prepare/tasks/main.yml" || fail "image_prepare role $version does not check database port binding"
    grep -q "/etc/default/grub.bak" "$ROOT_DIR/ansible/$version/roles/image_prepare/tasks/main.yml" || fail "image_prepare role $version does not remove grub backup debris"
    grep -q "Remove etcd download artifacts" "$ROOT_DIR/ansible/$version/roles/postgres/tasks/main.yml" || fail "postgres role $version leaves etcd download artifacts in /tmp"
  done
  pass "final image preparation guard"
}
run_build_cleanup_guard_tests() {
  grep -q "cleanup_failed_builder_vm" "$ROOT_DIR/build.sh" || fail "build script does not define failed builder VM cleanup"
  grep -q "prism_delete_vm" "$ROOT_DIR/build.sh" || fail "build script does not delete failed builder VMs"
  grep -q ".cleanup.packer_builder_vm" "$ROOT_DIR/build.sh" || fail "build script does not record failed builder cleanup in manifests"
  grep -q ".cleanup.packer_builder_vm_uuid" "$ROOT_DIR/build.sh" || fail "build script does not record failed builder VM UUIDs in manifests"
  grep -q -- "--retain-failed-builder" "$ROOT_DIR/build.sh" || fail "build script does not expose non-interactive failed builder retention"
  grep -q "RETAIN_FAILED_BUILDER" "$ROOT_DIR/build.sh" || fail "build script does not track failed builder retention separately from debug mode"
  grep -q "kept-on-failure" "$ROOT_DIR/build.sh" || fail "build script does not record retained failed builder manifests"
  grep -q "delete-task-failed" "$ROOT_DIR/build.sh" || fail "build script does not distinguish failed delete tasks from timeouts"
  pass "failed builder VM cleanup guard"
}
run_cli_argument_guard_tests() {
  local output

  if output=$(cd "$ROOT_DIR" && "$BASH" test.sh --max-parallel 2>&1); then
    fail "test.sh accepted --max-parallel without a value"
  fi
  grep -q "requires a value" <<<"$output" || fail "test.sh missing-value error not reported: $output"

  if output=$(cd "$ROOT_DIR" && "$BASH" build.sh --ndb-version 2>&1); then
    fail "build.sh accepted --ndb-version without a value"
  fi
  grep -q "requires a value" <<<"$output" || fail "build.sh missing-value error not reported: $output"

  if output=$(cd "$ROOT_DIR" && "$BASH" scripts/ndb_e2e_validate.sh --limit abc 2>&1); then
    fail "ndb_e2e_validate.sh accepted a non-numeric --limit"
  fi
  grep -q "non-negative integer" <<<"$output" || fail "ndb_e2e_validate.sh non-numeric --limit error not reported: $output"

  if output=$(cd "$ROOT_DIR" && "$BASH" scripts/ndb_e2e_validate.sh --row-id 2>&1); then
    fail "ndb_e2e_validate.sh accepted --row-id without a value"
  fi
  grep -q "requires a value" <<<"$output" || fail "ndb_e2e_validate.sh missing-value error not reported: $output"

  pass "CLI argument guards"
}
run_postgres_suffix_helper_tests() {
  local ha pin joined
  # shellcheck source=scripts/postgres_extensions.sh
  source "$ROOT_DIR/scripts/postgres_extensions.sh"

  ha=$(postgres_ha_image_name_suffix '{"patroni":["4.0.7"]}')
  [[ "$ha" == "ha" ]] || fail "ha suffix helper returned '$ha'"
  ha=$(postgres_ha_image_name_suffix '{}')
  [[ -z "$ha" ]] || fail "empty ha suffix helper returned '$ha'"
  pin=$(postgres_package_image_name_suffix "16.12")
  [[ "$pin" == "pg16-12" ]] || fail "package suffix helper returned '$pin'"
  pin=$(postgres_package_image_name_suffix "")
  [[ -z "$pin" ]] || fail "empty package suffix helper returned '$pin'"
  joined=$(postgres_join_image_name_suffixes "ha" "" "pg16-12" "ext-pgvector")
  [[ "$joined" == "ha-pg16-12-ext-pgvector" ]] || fail "suffix join helper returned '$joined'"
  joined=$(postgres_join_image_name_suffixes "" "" "")
  [[ -z "$joined" ]] || fail "empty suffix join helper returned '$joined'"
  grep -q "postgres_join_image_name_suffixes" "$ROOT_DIR/build.sh" || fail "build.sh does not use the shared suffix helpers"
  grep -q "postgres_join_image_name_suffixes" "$ROOT_DIR/scripts/build_wizard.sh" || fail "build wizard does not use the shared suffix helpers"
  grep -q "source_image_key_for_os" "$ROOT_DIR/scripts/build_wizard.sh" || fail "build wizard does not use the shared source-image key mapping"
  pass "postgres image suffix helpers"
}
run_readme_mongodb_tests() {
  grep -q "MongoDB" "$ROOT_DIR/README.md" || fail "README does not mention MongoDB"
  grep -q -- "--include-db-type mongodb" "$ROOT_DIR/README.md" || fail "README missing MongoDB test command"
  grep -q -- "--include-db-type pgsql --preflight" "$ROOT_DIR/README.md" || fail "README missing matrix preflight command"
  grep -q "RHEL live validation runbook" "$ROOT_DIR/README.md" || fail "README missing RHEL live validation runbook"
  grep -q 'NDB_RHEL_9_6_IMAGE_URI=missing' "$ROOT_DIR/README.md" || fail "README missing non-secret RHEL env readiness example"
  grep -q -- '--allow-rhel --include-os "Red Hat Enterprise Linux (RHEL)" --customization-profile customizations/local/rhel-repositories.yml --preflight' "$ROOT_DIR/README.md" || fail "README missing RHEL preflight runbook customization command"
  grep -q 'rhel-9.6=${RHEL_96_UUID},rhel-9.7=${RHEL_97_UUID}' "$ROOT_DIR/README.md" || fail "README missing staged RHEL UUID map example"
  grep -q -- '--allow-rhel --include-os "Red Hat Enterprise Linux (RHEL)" --customization-profile customizations/local/rhel-repositories.yml --validate --validate-artifact --manifest --continue-on-error --source-image-uuid-map' "$ROOT_DIR/README.md" || fail "README missing RHEL live validation runbook customization command"
  grep -q "debian-12=\${DEBIAN_12_UUID}" "$ROOT_DIR/README.md" || fail "README matrix preflight command does not include Debian 12 UUID mapping"
  grep -q "preflight cannot prove cloud-init SSH compatibility" "$ROOT_DIR/README.md" || fail "README missing source-image SSH compatibility preflight warning"
  grep -q "Builder VM gets an IP but SSH never becomes available" "$ROOT_DIR/README.md" || fail "README missing builder SSH troubleshooting guidance"
  grep -q "scripts/source_image_ssh_probe.sh" "$ROOT_DIR/README.md" || fail "README missing source image SSH probe command"
  grep -q "probe passes but Packer still times out" "$ROOT_DIR/README.md" || fail "README missing source probe versus Packer SSH guidance"
  grep -q "scripts/live_coverage_audit.sh" "$ROOT_DIR/README.md" || fail "README missing live coverage audit command"
  grep -q "live_coverage_audit.sh --suggest-runs --source-image-uuid-map" "$ROOT_DIR/README.md" || fail "README missing coverage audit UUID suggestion command"
  grep -q "live_coverage_audit.sh --suggest-runs --customization-profile" "$ROOT_DIR/README.md" || fail "README missing coverage audit customization suggestion command"
  grep -q "sharded topology" "$ROOT_DIR/README.md" || fail "README missing local sharded topology explanation"
  grep -q "mongodb_edition" "$ROOT_DIR/README.md" || fail "README missing MongoDB edition matrix guidance"
  grep -q "/opt/ndb/mongodb" "$ROOT_DIR/README.md" || fail "README missing NDB-safe MongoDB software home guidance"
  grep -q "MongoDB Database Tools" "$ROOT_DIR/README.md" || fail "README missing MongoDB Database Tools guidance"
  grep -q "SELinux permissive" "$ROOT_DIR/README.md" || fail "README missing MongoDB SELinux permissive guidance"
  pass "README MongoDB guidance"
}
run_readme_wizard_tests() {
  grep -q "scripts/build_wizard.sh" "$ROOT_DIR/README.md" || fail "README missing build wizard command"
  grep -q "safest first path" "$ROOT_DIR/README.md" || fail "README missing first build assistant positioning"
  grep -q "create \`packer/id_rsa\`" "$ROOT_DIR/README.md" || fail "README missing wizard SSH key setup guidance"
  grep -q "run \`packer init packer/\`" "$ROOT_DIR/README.md" || fail "README missing wizard Packer init guidance"
  grep -q "secret manager provides your environment" "$ROOT_DIR/README.md" || fail "README missing secret-managed environment guidance"
  grep -q "PostgreSQL extensions are optional" "$ROOT_DIR/README.md" || fail "README missing optional PostgreSQL extension guidance"
  grep -q -- "--extensions pgvector,postgis" "$ROOT_DIR/README.md" || fail "README missing direct PostgreSQL extension CLI example"
  grep -q "ext-pgvector-postgis" "$ROOT_DIR/README.md" || fail "README missing extension image naming example"
  grep -q "not release-note-qualified for this matrix row" "$ROOT_DIR/README.md" || fail "README missing advisory qualification warning wording"
  grep -q "validation.artifact_vm_ip" "$ROOT_DIR/README.md" || fail "README missing artifact validation VM IP manifest guidance"
  ! grep -q "Maintainer rule:" "$ROOT_DIR/README.md" || fail "README should not contain agent maintainer rules"
  pass "README build wizard guidance"
}
run_ansible_fact_normalization_guard_tests() {
  local deprecated_pattern deprecated_refs
  deprecated_pattern='ansible_(os_family|distribution|distribution_version|distribution_major_version|distribution_release)'
  deprecated_refs=$(
    find "$ROOT_DIR/ansible" "$ROOT_DIR/customizations/examples" -name '*.yml' -print0 \
      | xargs -0 rg -n "$deprecated_pattern" || true
  )

  if [[ -n "$deprecated_refs" ]]; then
    printf '%s\n' "$deprecated_refs" >&2
    fail "committed Ansible YAML still uses deprecated top-level ansible_* facts"
  fi

  pass "Ansible fact normalization guard"
}
run_debian_libaio_package_guard_tests() {
  local version vars_file

  for version in 2.9 2.10; do
    vars_file="$ROOT_DIR/ansible/$version/roles/common/vars/main.yml"

    grep -q "debian_libaio_package" "$vars_file" "$ROOT_DIR/ansible/$version/roles/common/tasks/packages.yml" || fail "NDB $version common role does not derive Debian libaio package by OS release"
    grep -q "libaio1t64" "$vars_file" "$ROOT_DIR/ansible/$version/roles/common/tasks/packages.yml" || fail "NDB $version common role does not handle Ubuntu 24.04 libaio1t64"
    grep -q "version('24.04', '>=')" "$vars_file" "$ROOT_DIR/ansible/$version/roles/common/tasks/packages.yml" || fail "NDB $version common role does not gate libaio1t64 on Ubuntu 24.04 or newer"
    ! grep -qE '^[[:space:]]*-[[:space:]]+libaio1$' "$vars_file" || fail "NDB $version common role still installs libaio1 unconditionally"
  done

  pass "Debian libaio package guard"
}
run_debian_common_package_guard_tests() {
  local version vars_file

  for version in 2.9 2.10; do
    vars_file="$ROOT_DIR/ansible/$version/roles/common/vars/main.yml"
    grep -qE '^[[:space:]]*-[[:space:]]+cron$' "$vars_file" || fail "NDB $version common role does not install cron before managing cron.service on Debian"
  done

  pass "Debian common package guard"
}
