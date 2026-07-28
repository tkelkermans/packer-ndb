#!/usr/bin/env bash
# Sourced by scripts/selftest.sh; defines run_*_tests suite functions.
# shellcheck shell=bash

run_customization_profile_static_tests() {
  [[ -f "$ROOT_DIR/customizations/profiles/enterprise-example.yml" ]] || fail "missing enterprise example profile"
  [[ -f "$ROOT_DIR/customizations/profiles/enterprise-example.vars.yml" ]] || fail "missing enterprise example vars"
  [[ -f "$ROOT_DIR/customizations/profiles/rhel-repositories-example.yml" ]] || fail "missing RHEL repositories example profile"
  [[ -f "$ROOT_DIR/customizations/profiles/rhel-repositories-example.vars.yml" ]] || fail "missing RHEL repositories example vars"
  [[ -f "$ROOT_DIR/customizations/examples/rhel-repositories/README.md" ]] || fail "missing RHEL repositories example README"
  [[ -f "$ROOT_DIR/customizations/local/README.md" ]] || fail "missing local customization README"
  grep -q "customizations/local/" "$ROOT_DIR/.gitignore" || fail ".gitignore does not ignore local customizations"
  grep -q "custom_internal_ca" "$ROOT_DIR/customizations/profiles/enterprise-example.yml" || fail "profile missing internal CA role"
  grep -q "custom_monitoring_agent" "$ROOT_DIR/customizations/profiles/enterprise-example.yml" || fail "profile missing monitoring role"
  grep -q "custom_os_hardening" "$ROOT_DIR/customizations/profiles/enterprise-example.yml" || fail "profile missing hardening role"
  grep -q "validate_custom_enterprise" "$ROOT_DIR/customizations/profiles/enterprise-example.yml" || fail "profile missing custom validation role"
  grep -q "custom_rhel_repositories" "$ROOT_DIR/customizations/profiles/rhel-repositories-example.yml" || fail "RHEL repositories profile missing pre-common role"
  grep -q "validate_rhel_repositories" "$ROOT_DIR/customizations/profiles/rhel-repositories-example.yml" || fail "RHEL repositories profile missing validation role"
  grep -q "customizations/examples/rhel-repositories/roles" "$ROOT_DIR/customizations/profiles/rhel-repositories-example.yml" || fail "RHEL repositories profile missing explicit role path"
  grep -q "OpenTelemetry Collector" "$ROOT_DIR/customizations/examples/monitoring-agent/README.md" || fail "monitoring example does not document OpenTelemetry Collector"
  grep -q "rhel-repositories-example" "$ROOT_DIR/README.md" || fail "README missing RHEL repositories profile command"
  grep -q -- "--customization-profile customizations/local/rhel-repositories.yml" "$ROOT_DIR/VALIDATION.md" || fail "VALIDATION missing RHEL matrix customization profile command"
  grep -q "Customize The Image" "$ROOT_DIR/README.md" || fail "README missing customization section"
  grep -q -- "--customization-profile" "$ROOT_DIR/README.md" || fail "README missing customization profile command"
  pass "customization profile static skeleton"
}
run_rhel_activation_key_guard_tests() {
  local version playbook_file role_file image_prepare_file subscription_line common_line tmpdir output

  grep -q "NDB_RHEL_ORGID" "$ROOT_DIR/build.sh" || fail "build.sh does not pass NDB_RHEL_ORGID to Ansible"
  grep -q "NDB_RHEL_ACTIVATIONKEY" "$ROOT_DIR/build.sh" || fail "build.sh does not pass NDB_RHEL_ACTIVATIONKEY to Ansible"
  grep -q "RHEL subscription activation:" "$ROOT_DIR/build.sh" || fail "build.sh dry-run missing non-secret RHEL activation readiness"

  for version in $(selftest_ndb_versions); do
    playbook_file="$ROOT_DIR/ansible/$version/playbooks/site.yml"
    role_file="$ROOT_DIR/ansible/$version/roles/rhel_subscription/tasks/main.yml"
    image_prepare_file="$ROOT_DIR/ansible/$version/roles/image_prepare/tasks/main.yml"

    [[ -f "$role_file" ]] || fail "missing RHEL subscription role for NDB $version"
    grep -q "rhel_subscription" "$playbook_file" || fail "site playbook $version does not run RHEL subscription role"
    subscription_line=$(grep -n "rhel_subscription" "$playbook_file" | head -n1 | cut -d: -f1)
    common_line=$(grep -n -- "- common" "$playbook_file" | head -n1 | cut -d: -f1)
    [[ -n "$subscription_line" && -n "$common_line" && "$subscription_line" -lt "$common_line" ]] || fail "site playbook $version must register RHEL before common package installation"

    grep -q "subscription-manager" "$role_file" || fail "RHEL subscription role $version does not use subscription-manager"
    grep -q "register" "$role_file" || fail "RHEL subscription role $version does not register systems"
    grep -q "rhel_subscription_org_id" "$role_file" || fail "RHEL subscription role $version missing org id variable"
    grep -q "rhel_subscription_activation_key" "$role_file" || fail "RHEL subscription role $version missing activation key variable"
    grep -q "codeready-builder-for-rhel" "$role_file" || fail "RHEL subscription role $version does not enable CodeReady Builder for build-time packages"
    grep -q "no_log: true" "$role_file" || fail "RHEL subscription role $version does not hide activation key task output"
    ! grep -q "subscription-manager attach" "$role_file" || fail "RHEL subscription role $version should not manually attach subscriptions"

    grep -q "subscription-manager unregister" "$image_prepare_file" || fail "image_prepare $version does not unregister RHSM before image capture"
    grep -q "subscription-manager clean" "$image_prepare_file" || fail "image_prepare $version does not clean RHSM before image capture"
  done

  grep -q "NDB_RHEL_ORGID" "$ROOT_DIR/scripts/source_image_ssh_probe.sh" || fail "source image probe does not use RHEL org id"
  grep -q "NDB_RHEL_ACTIVATIONKEY" "$ROOT_DIR/scripts/source_image_ssh_probe.sh" || fail "source image probe does not use RHEL activation key"
  grep -q "subscription-manager register" "$ROOT_DIR/scripts/source_image_ssh_probe.sh" || fail "source image probe does not register with activation key"
  grep -q "codeready-builder-for-rhel" "$ROOT_DIR/scripts/source_image_ssh_probe.sh" || fail "source image RHEL repository probe does not enable CodeReady Builder"
  grep -q "gdbm-devel" "$ROOT_DIR/scripts/source_image_ssh_probe.sh" || fail "source image RHEL repository probe does not test CodeReady Builder packages"
  grep -q "subscription-manager unregister" "$ROOT_DIR/scripts/source_image_ssh_probe.sh" || fail "source image probe does not unregister after repository check"
  grep -q "subscription-manager clean" "$ROOT_DIR/scripts/source_image_ssh_probe.sh" || fail "source image probe does not clean RHSM after repository check"

  grep -q "NDB_RHEL_ORGID" "$ROOT_DIR/scripts/rhel_readiness.sh" || fail "RHEL readiness helper missing org id status"
  grep -q "NDB_RHEL_ACTIVATIONKEY" "$ROOT_DIR/scripts/rhel_readiness.sh" || fail "RHEL readiness helper missing activation key status"
  grep -q "NDB_RHEL_ORGID" "$ROOT_DIR/README.md" || fail "README missing RHEL org id guidance"
  grep -q "NDB_RHEL_ACTIVATIONKEY" "$ROOT_DIR/README.md" || fail "README missing RHEL activation key guidance"
  grep -q "CodeReady Builder" "$ROOT_DIR/README.md" || fail "README missing RHEL CodeReady Builder guidance"
  grep -q "NDB_RHEL_ACTIVATIONKEY" "$ROOT_DIR/VALIDATION.md" || fail "VALIDATION missing RHEL activation key guidance"
  grep -q "activation key" "$ROOT_DIR/customizations/examples/rhel-repositories/README.md" || fail "RHEL repository example missing activation key guidance"

  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' RETURN
  output="$tmpdir/rhel-dry-run.out"
  (
    export NDB_RHEL_ORGID=selftest-org
    export NDB_RHEL_ACTIVATIONKEY=selftest-secret
    "$ROOT_DIR/build.sh" \
      --dry-run \
      --ci \
      --source-image-uuid selftest-rhel-image \
      --ndb-version 2.10 \
      --db-type pgsql \
      --os "Red Hat Enterprise Linux (RHEL)" \
      --os-version 9.7 \
      --db-version 18 >"$output"
  ) || fail "RHEL activation dry-run failed"
  grep -q "Activation key pair: present" "$output" || fail "RHEL activation dry-run does not report present activation key pair"
  grep -q '"rhel_subscription_enabled": true' "$output" || fail "RHEL activation dry-run does not enable subscription registration"
  grep -q '"rhel_subscription_activation_key": "<redacted>"' "$output" || fail "RHEL activation dry-run does not redact activation key"
  ! grep -q "selftest-secret" "$output" || fail "RHEL activation dry-run printed activation key value"
  ! grep -q "selftest-org" "$output" || fail "RHEL activation dry-run printed org id value"

  pass "RHEL activation key guard"
}
run_customization_profile_cli_tests() {
  grep -q -- "--customization-profile" "$ROOT_DIR/build.sh" || fail "build.sh missing customization profile flag"
  grep -q "NDB_CUSTOMIZATION_PROFILE" "$ROOT_DIR/build.sh" || fail "build.sh missing customization profile env default"
  grep -q "CUSTOMIZATION_PROFILE_FILE" "$ROOT_DIR/build.sh" || fail "build.sh missing customization profile resolver"
  grep -q "customization_profile_file" "$ROOT_DIR/build.sh" || fail "build.sh does not pass customization profile to Ansible"
  grep -q "Customization profile:" "$ROOT_DIR/build.sh" || fail "dry-run summary missing customization profile"
  pass "customization profile CLI guards"
}
run_customization_profile_ansible_tests() {
  for version in $(selftest_ndb_versions); do
    [[ -f "$ROOT_DIR/ansible/$version/playbooks/customization_preflight.yml" ]] || fail "missing customization preflight playbook $version"
    [[ -f "$ROOT_DIR/ansible/$version/roles/customization_profile/tasks/main.yml" ]] || fail "missing customization_profile role $version"
    grep -q "include_vars" "$ROOT_DIR/ansible/$version/roles/customization_profile/tasks/main.yml" || fail "customization_profile $version does not load profile YAML"
    grep -q "customization_allowed_phases" "$ROOT_DIR/ansible/$version/roles/customization_profile/tasks/main.yml" || fail "customization_profile $version does not validate allowed phases"
    grep -q "include_role" "$ROOT_DIR/ansible/$version/roles/customization_profile/tasks/main.yml" || fail "customization_profile $version does not run phase roles"
  done
  grep -q "customization_preflight.yml" "$ROOT_DIR/build.sh" || fail "build.sh does not run customization preflight"
  pass "customization profile Ansible preflight guards"
}
run_customization_build_dispatch_tests() {
  grep -q "ansible_roles_path_env" "$ROOT_DIR/packer/variables.pkr.hcl" || fail "Packer variables missing ansible_roles_path_env"
  grep -q "ANSIBLE_ROLES_PATH" "$ROOT_DIR/packer/database.pkr.hcl" || fail "Packer does not pass ANSIBLE_ROLES_PATH"
  grep -q "customization_phase: pre_common" "$ROOT_DIR/ansible/2.10/playbooks/site.yml" || fail "site playbook missing pre_common customization phase"
  grep -q "customization_phase: post_database" "$ROOT_DIR/ansible/2.10/playbooks/site.yml" || fail "site playbook missing post_database customization phase"
  grep -q "custom_internal_ca" "$ROOT_DIR/customizations/examples/internal-ca/roles/custom_internal_ca/tasks/main.yml" || fail "missing internal CA role marker"
  grep -q "ndb-example-otelcol" "$ROOT_DIR/customizations/examples/monitoring-agent/roles/custom_monitoring_agent/tasks/main.yml" || fail "missing monitoring role marker"
  grep -q "vm.swappiness" "$ROOT_DIR/customizations/examples/os-hardening/roles/custom_os_hardening/tasks/main.yml" || fail "missing hardening role marker"
  grep -q "become: yes" "$ROOT_DIR/customizations/examples/internal-ca/roles/custom_internal_ca/tasks/main.yml" || fail "internal CA example does not use privilege escalation"
  grep -q "become: yes" "$ROOT_DIR/customizations/examples/monitoring-agent/roles/custom_monitoring_agent/tasks/main.yml" || fail "monitoring example does not use privilege escalation"
  grep -q "become: yes" "$ROOT_DIR/customizations/examples/os-hardening/roles/custom_os_hardening/tasks/main.yml" || fail "hardening example does not use privilege escalation"
  grep -q "become: yes" "$ROOT_DIR/customizations/examples/enterprise-validation/roles/validate_custom_enterprise/tasks/main.yml" || fail "enterprise validation example does not use privilege escalation"
  grep -q "ansible.builtin.yum_repository" "$ROOT_DIR/customizations/examples/rhel-repositories/roles/custom_rhel_repositories/tasks/main.yml" || fail "RHEL repository role does not configure yum repositories"
  grep -q "subscription-manager" "$ROOT_DIR/customizations/examples/rhel-repositories/roles/custom_rhel_repositories/tasks/main.yml" || fail "RHEL repository role does not support subscription-manager repo enablement"
  grep -q "no_log" "$ROOT_DIR/customizations/examples/rhel-repositories/roles/custom_rhel_repositories/tasks/main.yml" || fail "RHEL repository role does not hide repository values"
  grep -q "makecache" "$ROOT_DIR/customizations/examples/rhel-repositories/roles/custom_rhel_repositories/tasks/main.yml" || fail "RHEL repository role does not refresh dnf metadata"
  grep -q "ansible.builtin.package_facts" "$ROOT_DIR/customizations/examples/rhel-repositories/roles/validate_rhel_repositories/tasks/main.yml" || fail "RHEL repository validation role does not inspect installed packages"
  grep -q "rhel_repositories_required_packages" "$ROOT_DIR/customizations/examples/rhel-repositories/roles/validate_rhel_repositories/tasks/main.yml" || fail "RHEL repository validation role does not check required package list"
  pass "customization build dispatch guards"
}
run_customization_dry_run_missing_ansible_tests() {
  local tmpdir output cmd cmd_path
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' RETURN
  output="$tmpdir/dry-run.out"
  mkdir -p "$tmpdir/bin"

  for cmd in jq cksum dirname mktemp date tr sed rm cat; do
    cmd_path=$(command -v "$cmd") || fail "selftest missing required command: $cmd"
    ln -s "$cmd_path" "$tmpdir/bin/$cmd"
  done

  if (
    cd "$ROOT_DIR"
    PATH="$tmpdir/bin" SKIP_MATRIX_VALIDATION=true "$BASH" "$ROOT_DIR/build.sh" \
      --ci \
      --dry-run \
      --ndb-version 2.10 \
      --db-type pgsql \
      --os "Rocky Linux" \
      --os-version "9.6" \
      --db-version 17 \
      --source-image-name test-image \
      --customization-profile enterprise-example >"$output" 2>&1
  ); then
    :
  else
    fail "customized dry-run failed without ansible-playbook: $(cat "$output")"
  fi

  grep -q "=== NDB Build Dry Run ===" "$output" || fail "customized dry-run missing summary"
  grep -q "ansible-playbook=missing" "$output" || fail "customized dry-run did not report missing ansible-playbook"
  grep -q "command: ansible-playbook" "$output" || fail "customized dry-run did not list ansible-playbook as a missing prerequisite"
  ! grep -q "command not found" "$output" || fail "customized dry-run crashed with command not found"
  pass "customization dry-run reports missing ansible-playbook"
}
run_customization_extra_role_path_dry_run_tests() {
  local tmpdir output profile local_extra_root extra_roles relative_extra_roles cmd cmd_path
  tmpdir=$(mktemp -d)
  local_extra_root="customizations/local/selftest-extra-role-path-$$"
  trap 'rm -rf "$tmpdir" "$ROOT_DIR/$local_extra_root"' RETURN
  output="$tmpdir/dry-run.out"
  profile="$ROOT_DIR/$local_extra_root/profile.yml"
  relative_extra_roles="$local_extra_root/roles"
  extra_roles="$ROOT_DIR/$relative_extra_roles"
  mkdir -p "$tmpdir/bin" "$extra_roles/custom_test_role/tasks"

  for cmd in jq cksum dirname mktemp date tr sed rm cat grep chmod bash; do
    cmd_path=$(command -v "$cmd") || fail "selftest missing required command: $cmd"
    ln -s "$cmd_path" "$tmpdir/bin/$cmd"
  done

  cat > "$profile" <<YAML
name: extra-role-path-test
description: profile with a temporary role path
extra_role_paths:
  - $relative_extra_roles
phases:
  pre_common:
    roles:
      - custom_test_role
YAML

  cat > "$tmpdir/bin/ansible-playbook" <<'SH'
#!/usr/bin/env bash
extra_paths_file=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -e)
      case "$2" in
        customization_extra_role_paths_file=*)
          extra_paths_file=${2#customization_extra_role_paths_file=}
          ;;
      esac
      shift
      ;;
  esac
  shift
done
if [[ -n "$extra_paths_file" ]]; then
  printf '["%s"]' "$NDB_SELFTEST_EXTRA_ROLES" > "$extra_paths_file"
fi
exit 0
SH
  chmod +x "$tmpdir/bin/ansible-playbook"

  if (
    cd "$ROOT_DIR"
    PATH="$tmpdir/bin" \
      SKIP_MATRIX_VALIDATION=true \
      NDB_SELFTEST_EXTRA_ROLES="$relative_extra_roles" \
      "$BASH" "$ROOT_DIR/build.sh" \
      --ci \
      --dry-run \
      --ndb-version 2.10 \
      --db-type pgsql \
      --os "Rocky Linux" \
      --os-version "9.6" \
      --db-version 17 \
      --source-image-name test-image \
      --customization-profile "$profile" >"$output" 2>&1
  ); then
    :
  else
    fail "customized dry-run with extra role path failed: $(cat "$output")"
  fi

  grep -q "ansible_roles_path_env=ANSIBLE_ROLES_PATH=.*$extra_roles" "$output" || fail "customized dry-run omitted profile extra_role_paths from roles path preview"
  pass "customization dry-run includes profile extra_role_paths"
}
run_customization_build_time_vars_dry_run_tests() {
  local tmpdir output vars_file probe_playbook probe_output roles_path
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' RETURN
  output="$tmpdir/dry-run.out"
  vars_file="$tmpdir/generated-vars.json"
  probe_playbook="$tmpdir/build-time-probe.yml"
  probe_output="$tmpdir/build-time-probe.out"

  command -v ansible-playbook >/dev/null 2>&1 || fail "ansible-playbook is required for customization build-time vars selftest"

  if (
    cd "$ROOT_DIR"
    SKIP_MATRIX_VALIDATION=true "$BASH" "$ROOT_DIR/build.sh" \
      --ci \
      --dry-run \
      --ndb-version 2.10 \
      --db-type pgsql \
      --os "Rocky Linux" \
      --os-version "9.6" \
      --db-version 17 \
      --source-image-name test-image \
      --customization-profile enterprise-example >"$output" 2>&1
  ); then
    :
  else
    fail "customized dry-run with enterprise example failed: $(cat "$output")"
  fi

  grep -q "\"customization_repo_root\": \"${ROOT_DIR}\"" "$output" || fail "customized dry-run vars omitted customization_repo_root"

  awk '/^Generated Ansible vars:/{flag=1;next}/^Selected matrix entry:/{flag=0}flag' "$output" > "$vars_file"

  cat > "$probe_playbook" <<'YAML'
- name: Probe build-time customization profile phase from generated vars
  hosts: localhost
  connection: local
  gather_facts: false
  vars:
    customization_phase: post_common
  roles:
    - role: customization_profile
YAML

  roles_path="$ROOT_DIR/ansible/2.10/roles:$ROOT_DIR/customizations/examples/internal-ca/roles:$ROOT_DIR/customizations/examples/monitoring-agent/roles:$ROOT_DIR/customizations/examples/os-hardening/roles:$ROOT_DIR/customizations/examples/enterprise-validation/roles:$ROOT_DIR/customizations/local"
  if ANSIBLE_ROLES_PATH="$roles_path" ANSIBLE_CONFIG="$ROOT_DIR/ansible/2.10/ansible.cfg" \
    ansible-playbook -i localhost, -c local -e "@$vars_file" "$probe_playbook" >"$probe_output" 2>&1; then
    :
  else
    fail "build-time customization profile probe failed: $(cat "$probe_output")"
  fi

  pass "customization dry-run vars support build-time profile loading"
}
run_build_extension_selection_tests() {
  local output

  output=$(cd "$ROOT_DIR" && ./build.sh --ci --dry-run --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18 2>&1)
  grep -q '"postgres_extensions": \[\]' <<<"$output" || fail "default build should select no PostgreSQL extensions"
  grep -q '"selected_extensions": \[\]' <<<"$output" || fail "dry-run should show selected extensions"
  grep -q '"postgres_ha_components": {' <<<"$output" || fail "dry-run should pass PostgreSQL HA components"
  grep -q '"patroni":' <<<"$output" || fail "dry-run should include Patroni HA component"
  grep -q '"etcd":' <<<"$output" || fail "dry-run should include etcd HA component"
  grep -Eq 'Image name: ndb-2\.10-pgsql-18-Rocky Linux-9\.7-ha-[0-9]{14}' <<<"$output" || fail "default HA image name changed unexpectedly"
  ! grep -q 'ext-' <<<"$output" || fail "default image name should not include extension suffix"

  output=$(cd "$ROOT_DIR" && ./build.sh --ci --dry-run --ndb-version 2.10 --db-type pgsql --os Debian --os-version 12 --db-version 16 --source-image-name test-image 2>&1)
  grep -q '"postgres_qualified_version_range": "16.9 - 16.12"' <<<"$output" || fail "Debian dry-run missing PostgreSQL qualified version range"
  grep -q '"postgres_package_version_prefix": "16.12"' <<<"$output" || fail "Debian dry-run missing PostgreSQL package pin"
  grep -q '"postgres_package_use_archive": true' <<<"$output" || fail "Debian dry-run missing PostgreSQL archive pin flag"
  grep -q "PostgreSQL package pin: 16.12" <<<"$output" || fail "Debian dry-run did not summarize PostgreSQL package pin"
  grep -Eq 'Image name: ndb-2\.10-pgsql-16-Debian-12-ha-pg16-12-[0-9]{14}' <<<"$output" || fail "Debian package pin missing from image name"

  output=$(cd "$ROOT_DIR" && ./build.sh --ci --dry-run --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18 --extensions pgvector,postgis 2>&1)
  grep -q '"postgres_extensions": \[' <<<"$output" || fail "selected extensions missing from generated vars"
  grep -q '"pgvector"' <<<"$output" || fail "pgvector missing from generated vars"
  grep -q '"postgis"' <<<"$output" || fail "postgis missing from generated vars"
  grep -q "not release-note-qualified for this matrix row" <<<"$output" || fail "non-qualified extension warning missing"
  grep -Eq 'Image name: ndb-2\.10-pgsql-18-Rocky Linux-9\.7-ha-ext-pgvector-postgis-[0-9]{14}' <<<"$output" || fail "selected extensions missing from HA image name"

  if (cd "$ROOT_DIR" && ./build.sh --ci --dry-run --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18 --extensions not_real >/dev/null 2>&1); then
    fail "unknown PostgreSQL extension unexpectedly passed"
  fi

  if (cd "$ROOT_DIR" && ./build.sh --ci --dry-run --ndb-version 2.10 --db-type mongodb --os "Rocky Linux" --os-version 9.7 --db-version 8.0 --extensions pgvector >/dev/null 2>&1); then
    fail "MongoDB build accepted PostgreSQL extensions"
  fi

  pass "build.sh PostgreSQL extension selection"
}
run_customization_preflight_order_tests() {
  local tmpdir output valid_profile invalid_profile ansible_log curl_log cmd cmd_path
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' RETURN
  output="$tmpdir/preflight.out"
  valid_profile="$tmpdir/valid-profile.yml"
  invalid_profile="$tmpdir/invalid-profile.yml"
  ansible_log="$tmpdir/ansible.log"
  curl_log="$tmpdir/curl.log"
  mkdir -p "$tmpdir/bin"

  for cmd in jq cksum dirname mktemp date tr sed rm grep basename bash cat head; do
    cmd_path=$(command -v "$cmd") || fail "selftest missing required command: $cmd"
    ln -s "$cmd_path" "$tmpdir/bin/$cmd"
  done

  cat > "$valid_profile" <<'YAML'
name: valid-test
description: valid profile
phases:
  pre_common:
    roles: []
YAML

  cat > "$invalid_profile" <<'YAML'
name: invalid-test
description: invalid profile
phases:
  unsupported_phase:
    roles: []
YAML

  cat > "$tmpdir/bin/ansible-playbook" <<'SH'
#!/usr/bin/env bash
printf 'ansible-playbook %s\n' "$*" >> "$NDB_SELFTEST_ANSIBLE_LOG"
profile_file=""
extra_paths_file=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -e)
      case "$2" in
        customization_profile_file=*)
          profile_file=${2#customization_profile_file=}
          ;;
        customization_extra_role_paths_file=*)
          extra_paths_file=${2#customization_extra_role_paths_file=}
          ;;
      esac
      shift
      ;;
  esac
  shift
done
if [[ -n "$extra_paths_file" ]]; then
  printf '[]' > "$extra_paths_file"
  exit 0
fi
if grep -q "unsupported_phase" "$profile_file"; then
  printf 'Customization profile contains unsupported phase names\n' >&2
  exit 23
fi
exit 0
SH
  chmod +x "$tmpdir/bin/ansible-playbook"

  cat > "$tmpdir/bin/curl" <<'SH'
#!/usr/bin/env bash
printf 'curl %s\n' "$*" >> "$NDB_SELFTEST_CURL_LOG"
output_file=""
url=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o)
      output_file=$2
      shift
      ;;
    http*://*)
      url=$1
      ;;
    -w)
      shift
      ;;
  esac
  shift
done
case "$url" in
  */api/nutanix/v3/images/image-uuid)
    body='{"metadata":{"uuid":"image-uuid"},"status":{"state":"COMPLETE","resources":{"cluster_reference_list":[{"kind":"cluster","uuid":"cluster-uuid"}]}}}'
    ;;
  *)
    body='{"entities":[{"spec":{"name":"test-cluster"},"metadata":{"uuid":"cluster-uuid"}},{"spec":{"name":"test-subnet"},"metadata":{"uuid":"subnet-uuid"}},{"spec":{"name":"test-image"},"metadata":{"uuid":"image-uuid"}}]}'
    ;;
esac
if [[ -n "$output_file" ]]; then
  printf '%s' "$body" > "$output_file"
else
  printf '%s' "$body"
fi
printf '200'
exit 0
SH
  chmod +x "$tmpdir/bin/curl"

  if (
    cd "$ROOT_DIR"
    PATH="$tmpdir/bin" \
      SKIP_MATRIX_VALIDATION=true \
      NDB_SELFTEST_ANSIBLE_LOG="$ansible_log" \
      NDB_SELFTEST_CURL_LOG="$curl_log" \
      PKR_VAR_pc_username=user \
      PKR_VAR_pc_password=password \
      PKR_VAR_pc_ip=pc.example.com \
      PKR_VAR_cluster_name=test-cluster \
      PKR_VAR_subnet_name=test-subnet \
      "$BASH" "$ROOT_DIR/build.sh" \
        --ci \
        --preflight \
        --ndb-version 2.10 \
        --db-type pgsql \
        --os "Rocky Linux" \
        --os-version "9.6" \
        --db-version 17 \
        --source-image-name test-image \
        --customization-profile "$invalid_profile" >"$output" 2>&1
  ); then
    fail "customized preflight with invalid profile unexpectedly passed"
  fi

  grep -q "Customization profile contains unsupported phase names" "$output" || fail "invalid customized preflight missed profile contract error"
  [[ -s "$ansible_log" ]] || fail "invalid customized preflight did not invoke ansible-playbook"
  [[ ! -e "$curl_log" ]] || fail "invalid customized preflight reached Prism/source-image checks before profile validation"

  rm -f "$ansible_log" "$curl_log" "$output"

  if (
    cd "$ROOT_DIR"
    PATH="$tmpdir/bin" \
      SKIP_MATRIX_VALIDATION=true \
      NDB_SELFTEST_ANSIBLE_LOG="$ansible_log" \
      NDB_SELFTEST_CURL_LOG="$curl_log" \
      PKR_VAR_pc_username=user \
      PKR_VAR_pc_password=password \
      PKR_VAR_pc_ip=pc.example.com \
      PKR_VAR_cluster_name=test-cluster \
      PKR_VAR_subnet_name=test-subnet \
      "$BASH" "$ROOT_DIR/build.sh" \
        --ci \
        --preflight \
        --ndb-version 2.10 \
        --db-type pgsql \
        --os "Rocky Linux" \
        --os-version "9.6" \
        --db-version 17 \
        --source-image-name test-image \
        --customization-profile "$valid_profile" >"$output" 2>&1
  ); then
    :
  else
    fail "customized preflight with valid profile failed: $(cat "$output")"
  fi

  [[ -s "$ansible_log" ]] || fail "valid customized preflight did not invoke ansible-playbook"
  [[ -s "$curl_log" ]] || fail "valid customized preflight did not continue to Prism/source-image checks"
  pass "customization preflight validates profile before source-image checks"
}
run_customization_profile_role_type_tests() {
  local tmpdir output scalar_profile mapping_profile profile profile_name
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' RETURN
  output="$tmpdir/preflight.out"
  scalar_profile="$tmpdir/scalar-roles-profile.yml"
  mapping_profile="$tmpdir/mapping-roles-profile.yml"

  command -v ansible-playbook >/dev/null 2>&1 || fail "ansible-playbook is required for customization profile role type selftest"

  cat > "$scalar_profile" <<'YAML'
name: scalar-roles-test
description: invalid profile with scalar roles
phases:
  pre_common:
    roles: custom_internal_ca
YAML

  cat > "$mapping_profile" <<'YAML'
name: mapping-roles-test
description: invalid profile with mapping roles
phases:
  pre_common:
    roles:
      name: custom_internal_ca
YAML

  for profile in "$scalar_profile" "$mapping_profile"; do
    profile_name=$(basename "$profile")
    if (
      cd "$ROOT_DIR"
      SKIP_MATRIX_VALIDATION=true "$BASH" "$ROOT_DIR/build.sh" \
        --ci \
        --dry-run \
        --ndb-version 2.10 \
        --db-type pgsql \
        --os "Rocky Linux" \
        --os-version "9.6" \
        --db-version 17 \
        --source-image-name test-image \
        --customization-profile "$profile" >"$output" 2>&1
    ); then
      fail "${profile_name} unexpectedly passed customization preflight"
    fi

    grep -q "Customization profile phase roles must be lists" "$output" || fail "${profile_name} missed roles type error"
    ! grep -q "Starting Packer build" "$output" || fail "${profile_name} reached build after invalid customization preflight"
    rm -f "$output"
  done

  pass "customization profile rejects scalar and mapping roles"
}
