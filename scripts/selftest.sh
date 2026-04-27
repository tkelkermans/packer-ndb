#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

pass() {
  printf 'PASS: %s\n' "$*"
}

run_matrix_validator_tests() {
  local tmpdir valid invalid invalid_output
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' RETURN
  valid="$tmpdir/2.99/matrix.json"
  invalid="$tmpdir/2.99-invalid/matrix.json"
  invalid_output="$tmpdir/invalid.out"
  mkdir -p "$(dirname "$valid")" "$(dirname "$invalid")"

  cat > "$valid" <<'JSON'
[
  {
    "ndb_version": "2.99",
    "engine": "PostgreSQL Community Edition",
    "db_type": "pgsql",
    "os_type": "Rocky Linux",
    "os_version": "9.9",
    "db_version": "18",
    "provisioning_role": "postgresql",
    "qualified_extensions": ["pg_stat_statements"],
    "ha_components": {
      "patroni": ["4.0.5"],
      "etcd": ["3.5.12"]
    }
  }
]
JSON

  cat > "$invalid" <<'JSON'
[
  {
    "ndb_version": "wrong",
    "engine": "",
    "db_type": "mysql",
    "os_type": null,
    "os_version": "9.9",
    "db_version": "18/17",
    "provisioning_role": "postgresql",
    "qualified_extensions": ["pg_stat_statements", ""],
    "ha_components": {
      "patroni": "4.0.5"
    }
  }
]
JSON

  "$ROOT_DIR/scripts/matrix_validate.sh" "$valid" >/dev/null
  if "$ROOT_DIR/scripts/matrix_validate.sh" "$invalid" >"$invalid_output" 2>&1; then
    fail "invalid matrix unexpectedly passed validation"
  fi
  grep -q "ndb_version" "$invalid_output" || fail "invalid matrix output missed version error"
  grep -q "os_type" "$invalid_output" || fail "invalid matrix output missed null required-field error"
  grep -q "db_version contains '/'" "$invalid_output" || fail "invalid matrix output missed db_version error"
  grep -q "provisioning_role.*requires db_type" "$invalid_output" || fail "invalid matrix output missed provisioning/db_type error"
  grep -q "qualified_extensions.*non-empty strings" "$invalid_output" || fail "invalid matrix output missed qualified extension element error"
  grep -q "ha_components.*list of non-empty strings" "$invalid_output" || fail "invalid matrix output missed ha_components list error"

  assert_invalid_matrix "non-array root" '"not an array"' "Matrix must be a JSON array"
  assert_invalid_matrix "non-object entry" '[null]' "entry must be an object"
  assert_invalid_matrix "qualified_extensions type" '[{"ndb_version":"2.99","engine":"PostgreSQL Community Edition","db_type":"pgsql","os_type":"Rocky Linux","os_version":"9.9","db_version":"18","provisioning_role":"postgresql","qualified_extensions":"pgvector"}]' "qualified_extensions.*list"
  assert_invalid_matrix "qualified_extensions element" '[{"ndb_version":"2.99","engine":"PostgreSQL Community Edition","db_type":"pgsql","os_type":"Rocky Linux","os_version":"9.9","db_version":"18","provisioning_role":"postgresql","qualified_extensions":["pgvector",""]}]' "qualified_extensions.*non-empty strings"
  assert_invalid_matrix "empty PostgreSQL qualified extensions require reason" '[{"ndb_version":"2.99","engine":"PostgreSQL Community Edition","db_type":"pgsql","os_type":"Rocky Linux","os_version":"9.9","db_version":"18","provisioning_role":"postgresql","qualified_extensions":[]}]' "qualified_extensions_empty_reason"
  assert_invalid_matrix "legacy extensions rejected" '[{"ndb_version":"2.99","engine":"PostgreSQL Community Edition","db_type":"pgsql","os_type":"Rocky Linux","os_version":"9.9","db_version":"18","provisioning_role":"postgresql","extensions":["pgvector"],"qualified_extensions":["pgvector"]}]' "legacy.*extensions"
  assert_invalid_matrix "ha_components type" '[{"ndb_version":"2.99","engine":"PostgreSQL Community Edition","db_type":"pgsql","os_type":"Rocky Linux","os_version":"9.9","db_version":"18","provisioning_role":"postgresql","ha_components":[]}]' "ha_components.*object"
  assert_invalid_matrix "duplicate combination" '[{"ndb_version":"2.99","engine":"PostgreSQL Community Edition","db_type":"pgsql","os_type":"Rocky Linux","os_version":"9.9","db_version":"18","provisioning_role":"postgresql"},{"ndb_version":"2.99","engine":"PostgreSQL Community Edition","db_type":"pgsql","os_type":"Rocky Linux","os_version":"9.9","db_version":"18","provisioning_role":"postgresql"}]' "duplicate combination"
  assert_invalid_matrix "mongodb role requires mongodb db type" '[{"ndb_version":"2.99","engine":"MongoDB","db_type":"pgsql","os_type":"Rocky Linux","os_version":"9.9","db_version":"8.0","provisioning_role":"mongodb","mongodb_edition":"community","deployment":["single-instance"]}]' "provisioning_role.*mongodb.*requires db_type"
  assert_invalid_matrix "mongodb edition required" '[{"ndb_version":"2.99","engine":"MongoDB","db_type":"mongodb","os_type":"Rocky Linux","os_version":"9.9","db_version":"8.0","provisioning_role":"mongodb","deployment":["single-instance"]}]' "mongodb_edition"
  assert_invalid_matrix "mongodb deployment required" '[{"ndb_version":"2.99","engine":"MongoDB","db_type":"mongodb","os_type":"Rocky Linux","os_version":"9.9","db_version":"8.0","provisioning_role":"mongodb","mongodb_edition":"community"}]' "deployment"
  assert_invalid_matrix "mongodb fake sharded os version" '[{"ndb_version":"2.99","engine":"MongoDB","db_type":"mongodb","os_type":"Rocky Linux","os_version":"9.9 (sharded)","db_version":"8.0","provisioning_role":"mongodb","mongodb_edition":"community","deployment":["sharded-cluster"]}]' "os_version.*must not encode MongoDB topology"
  assert_invalid_matrix_without_pattern "mongodb non-string os version clean error" '[{"ndb_version":"2.99","engine":"MongoDB","db_type":"mongodb","os_type":"Rocky Linux","os_version":9.9,"db_version":"8.0","provisioning_role":"mongodb","mongodb_edition":"community","deployment":["single-instance"]}]' "os_version" "jq:|test\\(|number.*string|string.*number"
  assert_invalid_matrix "mongodb metadata deployment required" '[{"ndb_version":"2.99","engine":"MongoDB","db_type":"mongodb","os_type":"Rocky Linux","os_version":"9.9","db_version":"8.0","provisioning_role":"metadata"}]' "MongoDB rows require deployment as a non-empty list"
  assert_invalid_matrix "mongodb metadata invalid deployment value" '[{"ndb_version":"2.99","engine":"MongoDB","db_type":"mongodb","os_type":"Rocky Linux","os_version":"9.9","db_version":"8.0","provisioning_role":"metadata","deployment":["global-cluster"]}]' "MongoDB deployment values"
  assert_invalid_matrix "mongodb duplicate deployment value" '[{"ndb_version":"2.99","engine":"MongoDB","db_type":"mongodb","os_type":"Rocky Linux","os_version":"9.9","db_version":"8.0","provisioning_role":"metadata","deployment":["single-instance","single-instance"]}]' "MongoDB deployment values must not contain duplicates"
  assert_invalid_matrix_without_pattern "mongodb non-array deployment clean error" '[{"ndb_version":"2.99","engine":"MongoDB","db_type":"mongodb","os_type":"Rocky Linux","os_version":"9.9","db_version":"8.0","provisioning_role":"metadata","deployment":"single-instance"}]' "MongoDB rows require deployment as a non-empty list" "jq:|Cannot iterate|array.*string"

  mkdir -p "$tmpdir/2.99-mongodb"
  cat > "$tmpdir/2.99-mongodb/matrix.json" <<'JSON'
[
  {
    "ndb_version": "2.99-mongodb",
    "engine": "MongoDB",
    "db_type": "mongodb",
    "os_type": "Rocky Linux",
    "os_version": "9.9",
    "db_version": "8.0",
    "provisioning_role": "mongodb",
    "mongodb_edition": "community",
    "deployment": ["single-instance", "replica-set", "sharded-cluster"]
  },
  {
    "ndb_version": "2.99-mongodb",
    "engine": "MongoDB",
    "db_type": "mongodb",
    "os_type": "Rocky Linux",
    "os_version": "9.9",
    "db_version": "8.0",
    "provisioning_role": "metadata",
    "deployment": ["sharded-cluster"],
    "notes": "metadata-only sharded row"
  }
]
JSON
  "$ROOT_DIR/scripts/matrix_validate.sh" "$tmpdir/2.99-mongodb/matrix.json" >/dev/null

  pass "matrix validator"
}

assert_invalid_matrix() {
  local name=$1
  local json=$2
  local expected_pattern=$3
  local matrix_file output_file
  matrix_file="$tmpdir/2.99/${name// /-}.json"
  output_file="$tmpdir/${name// /-}.out"
  mkdir -p "$(dirname "$matrix_file")"
  printf '%s\n' "$json" > "$matrix_file"

  if "$ROOT_DIR/scripts/matrix_validate.sh" "$matrix_file" >"$output_file" 2>&1; then
    fail "${name} matrix unexpectedly passed validation"
  fi

  grep -Eq "$expected_pattern" "$output_file" || fail "${name} output missed expected pattern: ${expected_pattern}"
}

assert_invalid_matrix_without_pattern() {
  local name=$1
  local json=$2
  local expected_pattern=$3
  local rejected_pattern=$4
  local matrix_file output_file
  matrix_file="$tmpdir/2.99/${name// /-}.json"
  output_file="$tmpdir/${name// /-}.out"
  mkdir -p "$(dirname "$matrix_file")"
  printf '%s\n' "$json" > "$matrix_file"

  if "$ROOT_DIR/scripts/matrix_validate.sh" "$matrix_file" >"$output_file" 2>&1; then
    fail "${name} matrix unexpectedly passed validation"
  fi

  grep -Eq "$expected_pattern" "$output_file" || fail "${name} output missed expected pattern: ${expected_pattern}"
  ! grep -Eq "$rejected_pattern" "$output_file" || fail "${name} output included rejected pattern: ${rejected_pattern}"
}

run_matrix_validator_tests

run_mongodb_matrix_coverage_tests() {
  local buildable_29 buildable_210 fake_versions sharded_readiness
  buildable_29=$(jq '[.[] | select(.db_type == "mongodb" and .provisioning_role == "mongodb")] | length' "$ROOT_DIR/ndb/2.9/matrix.json")
  buildable_210=$(jq '[.[] | select(.db_type == "mongodb" and .provisioning_role == "mongodb")] | length' "$ROOT_DIR/ndb/2.10/matrix.json")
  fake_versions=$(jq -s '[.[][] | select(.db_type == "mongodb" and (.os_version | test("\\(")))] | length' "$ROOT_DIR"/ndb/*/matrix.json)
  sharded_readiness=$(jq -s '[.[][] | select((.ndb_version == "2.9" or .ndb_version == "2.10") and .db_type == "mongodb" and .provisioning_role == "mongodb" and (.deployment | index("sharded-cluster")))] | length' "$ROOT_DIR/ndb/2.9/matrix.json" "$ROOT_DIR/ndb/2.10/matrix.json")

  [[ "$buildable_29" == "9" ]] || fail "expected 9 buildable NDB 2.9 MongoDB rows, got $buildable_29"
  [[ "$buildable_210" == "9" ]] || fail "expected 9 buildable NDB 2.10 MongoDB rows, got $buildable_210"
  [[ "$fake_versions" == "0" ]] || fail "MongoDB topology is still encoded in os_version"

  [[ "$sharded_readiness" == "8" ]] || fail "expected 8 buildable MongoDB sharded-readiness rows for NDB 2.9 and 2.10, got $sharded_readiness"
  jq -e '[.[] | select(.ndb_version == "2.10" and .db_type == "mongodb" and .provisioning_role == "mongodb" and (.deployment | index("sharded-cluster")) and .mongodb_edition != "enterprise")] | length == 0' "$ROOT_DIR/ndb/2.10/matrix.json" >/dev/null || fail "NDB 2.10 sharded MongoDB rows must be enterprise"

  pass "MongoDB matrix coverage"
}

run_mongodb_matrix_coverage_tests

run_qualified_extension_matrix_tests() {
  local legacy_keys missing_qualified
  legacy_keys=$(jq -s -r '
    [.[]
      | .[]
      | select((.provisioning_role // "") == "postgresql")
      | select(has("extensions") or has("extensions_empty_reason"))
    ] | length
  ' "$ROOT_DIR/ndb/2.9/matrix.json" "$ROOT_DIR/ndb/2.10/matrix.json")
  [[ "$legacy_keys" == "0" ]] || fail "PostgreSQL matrix rows still use legacy extension keys"

  missing_qualified=$(jq -s -r '
    [.[]
      | .[]
      | select((.db_type // "") == "pgsql" and (.provisioning_role // "") == "postgresql")
      | select((has("qualified_extensions") | not) and ((.qualified_extensions_empty_reason // "") == ""))
    ] | length
  ' "$ROOT_DIR/ndb/2.9/matrix.json" "$ROOT_DIR/ndb/2.10/matrix.json")
  [[ "$missing_qualified" == "0" ]] || fail "buildable PostgreSQL rows missing qualified extension metadata"

  pass "qualified extension matrix metadata"
}

run_qualified_extension_matrix_tests

run_customization_profile_static_tests() {
  [[ -f "$ROOT_DIR/customizations/profiles/enterprise-example.yml" ]] || fail "missing enterprise example profile"
  [[ -f "$ROOT_DIR/customizations/profiles/enterprise-example.vars.yml" ]] || fail "missing enterprise example vars"
  [[ -f "$ROOT_DIR/customizations/local/README.md" ]] || fail "missing local customization README"
  grep -q "customizations/local/" "$ROOT_DIR/.gitignore" || fail ".gitignore does not ignore local customizations"
  grep -q "custom_internal_ca" "$ROOT_DIR/customizations/profiles/enterprise-example.yml" || fail "profile missing internal CA role"
  grep -q "custom_monitoring_agent" "$ROOT_DIR/customizations/profiles/enterprise-example.yml" || fail "profile missing monitoring role"
  grep -q "custom_os_hardening" "$ROOT_DIR/customizations/profiles/enterprise-example.yml" || fail "profile missing hardening role"
  grep -q "validate_custom_enterprise" "$ROOT_DIR/customizations/profiles/enterprise-example.yml" || fail "profile missing custom validation role"
  grep -q "OpenTelemetry Collector" "$ROOT_DIR/customizations/examples/monitoring-agent/README.md" || fail "monitoring example does not document OpenTelemetry Collector"
  grep -q "Customize The Image" "$ROOT_DIR/README.md" || fail "README missing customization section"
  grep -q -- "--customization-profile" "$ROOT_DIR/README.md" || fail "README missing customization profile command"
  pass "customization profile static skeleton"
}

run_customization_profile_static_tests

run_customization_profile_cli_tests() {
  grep -q -- "--customization-profile" "$ROOT_DIR/build.sh" || fail "build.sh missing customization profile flag"
  grep -q "NDB_CUSTOMIZATION_PROFILE" "$ROOT_DIR/build.sh" || fail "build.sh missing customization profile env default"
  grep -q "CUSTOMIZATION_PROFILE_FILE" "$ROOT_DIR/build.sh" || fail "build.sh missing customization profile resolver"
  grep -q "customization_profile_file" "$ROOT_DIR/build.sh" || fail "build.sh does not pass customization profile to Ansible"
  grep -q "Customization profile:" "$ROOT_DIR/build.sh" || fail "dry-run summary missing customization profile"
  pass "customization profile CLI guards"
}

run_customization_profile_cli_tests

run_customization_profile_ansible_tests() {
  for version in 2.9 2.10; do
    [[ -f "$ROOT_DIR/ansible/$version/playbooks/customization_preflight.yml" ]] || fail "missing customization preflight playbook $version"
    [[ -f "$ROOT_DIR/ansible/$version/roles/customization_profile/tasks/main.yml" ]] || fail "missing customization_profile role $version"
    grep -q "include_vars" "$ROOT_DIR/ansible/$version/roles/customization_profile/tasks/main.yml" || fail "customization_profile $version does not load profile YAML"
    grep -q "customization_allowed_phases" "$ROOT_DIR/ansible/$version/roles/customization_profile/tasks/main.yml" || fail "customization_profile $version does not validate allowed phases"
    grep -q "include_role" "$ROOT_DIR/ansible/$version/roles/customization_profile/tasks/main.yml" || fail "customization_profile $version does not run phase roles"
  done
  grep -q "customization_preflight.yml" "$ROOT_DIR/build.sh" || fail "build.sh does not run customization preflight"
  pass "customization profile Ansible preflight guards"
}

run_customization_profile_ansible_tests

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
  pass "customization build dispatch guards"
}

run_customization_build_dispatch_tests

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

run_customization_dry_run_missing_ansible_tests

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

run_customization_extra_role_path_dry_run_tests

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

run_customization_build_time_vars_dry_run_tests

run_build_extension_selection_tests() {
  local output

  output=$(cd "$ROOT_DIR" && ./build.sh --ci --dry-run --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18 2>&1)
  grep -q '"postgres_extensions": \[\]' <<<"$output" || fail "default build should select no PostgreSQL extensions"
  grep -q '"selected_extensions": \[\]' <<<"$output" || fail "dry-run should show selected extensions"
  grep -Eq 'Image name: ndb-2\.10-pgsql-18-Rocky Linux-9\.7-[0-9]{14}' <<<"$output" || fail "default image name changed unexpectedly"
  ! grep -q 'ext-' <<<"$output" || fail "default image name should not include extension suffix"

  output=$(cd "$ROOT_DIR" && ./build.sh --ci --dry-run --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18 --extensions pgvector,postgis 2>&1)
  grep -q '"postgres_extensions": \[' <<<"$output" || fail "selected extensions missing from generated vars"
  grep -q '"pgvector"' <<<"$output" || fail "pgvector missing from generated vars"
  grep -q '"postgis"' <<<"$output" || fail "postgis missing from generated vars"
  grep -q "not release-note-qualified for this matrix row" <<<"$output" || fail "non-qualified extension warning missing"
  grep -Eq 'Image name: ndb-2\.10-pgsql-18-Rocky Linux-9\.7-ext-pgvector-postgis-[0-9]{14}' <<<"$output" || fail "selected extensions missing from image name"

  if (cd "$ROOT_DIR" && ./build.sh --ci --dry-run --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18 --extensions not_real >/dev/null 2>&1); then
    fail "unknown PostgreSQL extension unexpectedly passed"
  fi

  if (cd "$ROOT_DIR" && ./build.sh --ci --dry-run --ndb-version 2.10 --db-type mongodb --os "Rocky Linux" --os-version 9.7 --db-version 8.0 --extensions pgvector >/dev/null 2>&1); then
    fail "MongoDB build accepted PostgreSQL extensions"
  fi

  pass "build.sh PostgreSQL extension selection"
}

run_build_extension_selection_tests

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
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o)
      output_file=$2
      shift
      ;;
    -w)
      shift
      ;;
  esac
  shift
done
body='{"entities":[{"spec":{"name":"test-cluster"},"metadata":{"uuid":"cluster-uuid"}},{"spec":{"name":"test-subnet"},"metadata":{"uuid":"subnet-uuid"}},{"spec":{"name":"test-image"},"metadata":{"uuid":"image-uuid"}}]}'
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

run_customization_preflight_order_tests

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

run_customization_profile_role_type_tests

run_prism_helper_tests() {
  # shellcheck source=/dev/null
  source "$ROOT_DIR/scripts/prism.sh"
  local tmpdir
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' RETURN

  [[ "$(prism_endpoint_from_host "pc.example.com")" == "https://pc.example.com:9440" ]] || fail "endpoint from host"
  [[ "$(prism_endpoint_from_host "pc.example.com:9440")" == "https://pc.example.com:9440" ]] || fail "endpoint from host with port"
  [[ "$(prism_endpoint_from_host "https://pc.example.com:9440")" == "https://pc.example.com:9440" ]] || fail "endpoint from URL"

  mkdir -p "$tmpdir/bin"
  cat > "$tmpdir/bin/curl" <<'SH'
#!/usr/bin/env bash
status=${PRISM_TEST_HTTP_STATUS:-200}
body=${PRISM_TEST_BODY:-'{"ok":true}'}
output_file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -o)
      output_file=$2
      shift
      ;;
    -w)
      shift
      ;;
  esac
  shift
done

if [[ -n "$output_file" ]]; then
  printf '%s' "$body" > "$output_file"
else
  printf '%s' "$body"
fi
printf '%s' "$status"
SH
  chmod +x "$tmpdir/bin/curl"

  (
    PATH="$tmpdir/bin:$PATH"
    export PKR_VAR_pc_username=user
    export PKR_VAR_pc_password=password
    export PKR_VAR_pc_ip=pc.example.com
    [[ "$(prism_curl GET /api/test)" == '{"ok":true}' ]] || fail "prism_curl success body"
  )

  (
    PATH="$tmpdir/bin:$PATH"
    export PKR_VAR_pc_username=user
    export PKR_VAR_pc_password=password
    export PKR_VAR_pc_ip=pc.example.com
    export PRISM_TEST_HTTP_STATUS=401
    export PRISM_TEST_BODY='{"message":"unauthorized"}'
    if prism_curl GET /api/test >"$tmpdir/http-failure.out" 2>&1; then
      fail "prism_curl HTTP failure unexpectedly passed"
    fi
    grep -q "HTTP 401" "$tmpdir/http-failure.out" || fail "prism_curl failure missed HTTP status"
    grep -q "unauthorized" "$tmpdir/http-failure.out" || fail "prism_curl failure missed response body"
  )

  pass "prism helper pure functions"
}

run_prism_helper_tests

run_source_image_tests() {
  # shellcheck source=/dev/null
  source "$ROOT_DIR/scripts/source_images.sh"
  local tmpdir images_file
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' RETURN
  images_file="$tmpdir/images.json"

  [[ "$(source_image_key_for_os "Rocky Linux" "9.7")" == "rocky-linux-9.7" ]] || fail "Rocky image key"
  [[ "$(source_image_key_for_os "Red Hat Enterprise Linux (RHEL)" "9.7")" == "rhel-9.7" ]] || fail "RHEL image key"
  [[ "$(source_image_key_for_os "Ubuntu Linux" "24.04")" == "ubuntu-linux-24.04" ]] || fail "Ubuntu image key"
  [[ "$(source_image_key_for_os "Oracle Linux" "9.4")" == "oracle-linux-9.4" ]] || fail "fallback image key"

  cat > "$images_file" <<'JSON'
{
  "rocky-linux-9.7": "https://example.com/rocky.qcow2",
  "rhel-9.7": {
    "env_var": "NDB_TEST_RHEL_IMAGE_URI",
    "description": "test rhel image"
  }
}
JSON

  [[ "$(source_image_resolve_from_images_json "$images_file" "rocky-linux-9.7")" == "https://example.com/rocky.qcow2" ]] || fail "string image resolution"

  export NDB_TEST_RHEL_IMAGE_URI="file:///tmp/rhel.qcow2"
  [[ "$(source_image_resolve_from_images_json "$images_file" "rhel-9.7")" == "file:///tmp/rhel.qcow2" ]] || fail "env image resolution"
  unset NDB_TEST_RHEL_IMAGE_URI

  if source_image_resolve_from_images_json "$images_file" "rhel-9.7" >"$tmpdir/missing-env.out" 2>&1; then
    fail "missing image env unexpectedly passed"
  fi
  grep -q "NDB_TEST_RHEL_IMAGE_URI" "$tmpdir/missing-env.out" || fail "missing env output missed env var"

  source_image_value_is_real "https://example.com/rocky.qcow2" || fail "real URI not detected"
  ! source_image_value_is_real "<not used>" || fail "placeholder detected as real"
  ! source_image_value_is_real "<temporary local file created at runtime>" || fail "temporary placeholder detected as real"
  ! source_image_value_is_real "<unresolved until FOO is set>" || fail "unresolved placeholder detected as real"

  pass "source image helpers"
}

run_source_image_tests

run_source_image_uuid_guard_tests() {
  grep -q -- "--source-image-uuid" "$ROOT_DIR/build.sh" || fail "build.sh does not expose source image UUID override"
  grep -q "PACKER_SOURCE_IMAGE_UUID" "$ROOT_DIR/build.sh" || fail "build.sh does not track source image UUID for Packer"
  grep -q 'source_image_uuid=${PACKER_SOURCE_IMAGE_UUID}' "$ROOT_DIR/build.sh" || fail "build.sh dry-run does not show source image UUID"
  grep -q 'source_image_uuid=' "$ROOT_DIR/build.sh" || fail "build.sh does not pass source image UUID to Packer"
  grep -q 'variable "source_image_uuid"' "$ROOT_DIR/packer/variables.pkr.hcl" || fail "Packer variables do not define source_image_uuid"
  grep -q 'source_image_uuid = var.source_image_uuid' "$ROOT_DIR/packer/database.pkr.hcl" || fail "Packer builder does not use source_image_uuid"
  grep -q "prism_image_uuid_exists" "$ROOT_DIR/scripts/prism.sh" || fail "Prism helper does not validate source image UUIDs"
  grep -q -- "--source-image-uuid" "$ROOT_DIR/README.md" || fail "README does not document source image UUID override"
  pass "source image UUID override guard"
}

run_source_image_uuid_guard_tests

run_manifest_tests() {
  local tmpdir manifest
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' RETURN
  manifest="$tmpdir/manifest.json"

  "$ROOT_DIR/scripts/manifest.sh" init \
    --file "$manifest" \
    --image-name "ndb-test" \
    --ndb-version "2.10" \
    --db-type "pgsql" \
    --db-version "18" \
    --os-type "Rocky Linux" \
    --os-version "9.7" \
    --provisioning-role "postgresql" \
    --matrix-row-json '{"ndb_version":"2.10","provisioning_role":"postgresql"}'

  jq -e '.image_name == "ndb-test" and .status == "running" and .selection.provisioning_role == "postgresql" and .matrix_row.ndb_version == "2.10"' "$manifest" >/dev/null || fail "manifest init JSON"
  jq -e '.validation.in_guest == "not-requested" and .validation.artifact == "not-requested" and (.cleanup | type) == "object"' "$manifest" >/dev/null || fail "manifest default status JSON"

  "$ROOT_DIR/scripts/manifest.sh" set \
    --file "$manifest" \
    --key ".source_image.name" \
    --value "rocky"

  "$ROOT_DIR/scripts/manifest.sh" set \
    --file "$manifest" \
    --key ".source_image.mode" \
    --value "existing-prism-image"

  "$ROOT_DIR/scripts/manifest.sh" set \
    --file "$manifest" \
    --key ".source_image.uuid" \
    --value "source-image-uuid-1"

  "$ROOT_DIR/scripts/manifest.sh" set \
    --file "$manifest" \
    --key ".artifact.image_name" \
    --value "ndb-test"

  "$ROOT_DIR/scripts/manifest.sh" set \
    --file "$manifest" \
    --key ".validation.in_guest" \
    --value "passed"

  "$ROOT_DIR/scripts/manifest.sh" set-json \
    --file "$manifest" \
    --key ".packer.duration_seconds" \
    --json-value "12"

  jq -e '.source_image.name == "rocky" and .source_image.mode == "existing-prism-image" and .source_image.uuid == "source-image-uuid-1" and .artifact.image_name == "ndb-test" and .validation.in_guest == "passed" and .packer.duration_seconds == 12' "$manifest" >/dev/null || fail "manifest set JSON"

  "$ROOT_DIR/scripts/manifest.sh" set-json \
    --file "$manifest" \
    --key ".customization" \
    --json-value '{"enabled":true,"profile":"enterprise-example","profile_file":"customizations/profiles/enterprise-example.yml","phases":{"pre_common":["custom_internal_ca"],"post_common":[],"post_database":["custom_monitoring_agent","custom_os_hardening"],"validate":["validate_custom_enterprise"]},"validation":"not-requested"}'

  jq -e '.customization.enabled == true and .customization.profile == "enterprise-example" and (.customization.phases.validate | index("validate_custom_enterprise"))' "$manifest" >/dev/null || fail "manifest customization JSON"

  printf '' > "$tmpdir/empty-artifact-result.json"
  "$ROOT_DIR/scripts/manifest.sh" record-artifact-validation \
    --file "$manifest" \
    --result-file "$tmpdir/empty-artifact-result.json" \
    --exit-status 7

  jq -e '.validation.artifact == "failed" and .cleanup.artifact_validation_vm == "result-unavailable"' "$manifest" >/dev/null || fail "manifest empty artifact result fallback"

  if "$ROOT_DIR/scripts/manifest.sh" record-artifact-validation \
    --file "$manifest" \
    --result-file "$tmpdir/empty-artifact-result.json" \
    --exit-status 0 >/dev/null 2>&1; then
    fail "manifest empty artifact success unexpectedly passed"
  fi

  "$ROOT_DIR/scripts/manifest.sh" finalize \
    --file "$manifest" \
    --status success \
    --artifact-image-uuid "image-uuid-1"

  jq -e '.status == "success" and .artifact.image_name == "ndb-test" and .artifact.image_uuid == "image-uuid-1"' "$manifest" >/dev/null || fail "manifest finalize JSON"
  grep -Fq ".customization" "$ROOT_DIR/build.sh" || fail "build.sh does not record customization manifest fields"
  pass "manifest helper"
}

run_manifest_tests

run_artifact_validate_tests() {
  local tmpdir failure_result success_result cleanup_result test_private_key test_public_key
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' RETURN
  failure_result="$tmpdir/failure-result.json"
  success_result="$tmpdir/success-result.json"
  cleanup_result="$tmpdir/cleanup-result.json"
  test_private_key="$tmpdir/id_rsa"
  test_public_key="$tmpdir/id_rsa.pub"

  printf '%s\n' "selftest-private-key" > "$test_private_key"
  printf '%s\n' "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCselftest packer@selftest" > "$test_public_key"
  chmod 600 "$test_private_key"
  export NDB_ARTIFACT_PRIVATE_KEY_PATH="$test_private_key"
  export NDB_ARTIFACT_PUBLIC_KEY_PATH="$test_public_key"

  if "$ROOT_DIR/scripts/artifact_validate.sh" --help >/dev/null; then
    pass "artifact validation help"
  else
    fail "artifact validation help"
  fi

  grep -q -- "--customization-profile-file" "$ROOT_DIR/scripts/artifact_validate.sh" || fail "artifact validation missing customization profile file flag"
  grep -q "validate_custom_enterprise" "$ROOT_DIR/customizations/examples/enterprise-validation/roles/validate_custom_enterprise/tasks/main.yml" || fail "missing enterprise validation role marker"

  mkdir -p "$tmpdir/bin"
  cat > "$tmpdir/bin/curl" <<'SH'
#!/usr/bin/env bash
output_file=""
url=""
method=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -X)
      method=$2
      shift
      ;;
    -o)
      output_file=$2
      shift
      ;;
    -w)
      shift
      ;;
    http*://*)
      url=$1
      ;;
  esac
  shift
done

case "$url" in
  */api/nutanix/v3/images/list)
    body='{"entities":[{"spec":{"name":"test-image"},"metadata":{"uuid":"image-uuid"}}]}'
    ;;
  */api/nutanix/v3/clusters/list)
    body='{"entities":[{"spec":{"name":"mock-cluster"},"metadata":{"uuid":"cluster-uuid"}}]}'
    ;;
  */api/nutanix/v3/subnets/list)
    body='{"entities":[{"spec":{"name":"mock-subnet"},"metadata":{"uuid":"subnet-uuid"}}]}'
    ;;
  */api/nutanix/v3/vms)
    body='{"metadata":{"uuid":"vm-uuid"},"status":{"execution_context":{"task_uuid":"create-task"}}}'
    ;;
  */api/nutanix/v3/tasks/create-task|*/api/nutanix/v3/tasks/power-task)
    body='{"status":"SUCCEEDED","percentage_complete":100}'
    ;;
  */api/nutanix/v3/tasks/delete-task)
    body="{\"status\":\"${NDB_SELFTEST_DELETE_TASK_STATUS:-SUCCEEDED}\",\"percentage_complete\":100}"
    ;;
  */api/nutanix/v3/vms/vm-uuid)
    if [[ "$method" == "DELETE" ]]; then
      touch "${NDB_SELFTEST_DELETE_MARKER:?}"
      body='{"status":{"execution_context":{"task_uuid":"delete-task"}}}'
    elif [[ "$method" == "PUT" ]]; then
      body='{"status":{"execution_context":{"task_uuid":"power-task"}}}'
    else
      body='{"api_version":"3.1","metadata":{"uuid":"vm-uuid","kind":"vm"},"spec":{"name":"vm","resources":{"power_state":"OFF"}},"status":{"resources":{"nic_list":[{"ip_endpoint_list":[{"ip":"192.0.2.10"}]}]}}}'
    fi
    ;;
  *)
    body='{"status":"SUCCEEDED","percentage_complete":100}'
    ;;
esac

if [[ -n "$output_file" ]]; then
  printf '%s' "$body" > "$output_file"
else
  printf '%s' "$body"
fi
printf '200'
SH

  cat > "$tmpdir/bin/ssh" <<'SH'
#!/usr/bin/env bash
exit 0
SH

  cat > "$tmpdir/bin/ansible-playbook" <<'SH'
#!/usr/bin/env bash
if [[ -n "${NDB_SELFTEST_ROLES_PATH_CAPTURE:-}" ]]; then
  printf '%s' "${ANSIBLE_ROLES_PATH:-}" > "$NDB_SELFTEST_ROLES_PATH_CAPTURE"
fi

for arg in "$@"; do
  case "$arg" in
    @*.yml|@*.yaml)
      ;;
    *.yml)
      if [[ -n "${NDB_SELFTEST_PLAYBOOK_CAPTURE:-}" ]]; then
        cp "$arg" "$NDB_SELFTEST_PLAYBOOK_CAPTURE"
      fi
      ;;
    @*.json)
      if [[ -n "${NDB_SELFTEST_VARS_CAPTURE:-}" ]]; then
        cp "${arg#@}" "$NDB_SELFTEST_VARS_CAPTURE"
      fi
      ;;
  esac
done
exit "${NDB_SELFTEST_ANSIBLE_RC:-42}"
SH

  chmod +x "$tmpdir/bin/curl" "$tmpdir/bin/ssh" "$tmpdir/bin/ansible-playbook"

  (
    export PATH="$tmpdir/bin:$PATH"
    export PKR_VAR_pc_username=user
    export PKR_VAR_pc_password=password
    export PKR_VAR_pc_ip=pc.example.com
    export PKR_VAR_cluster_name=mock-cluster
    export PKR_VAR_subnet_name=mock-subnet
    export NDB_SELFTEST_DELETE_MARKER="$tmpdir/delete-called"
    if "$ROOT_DIR/scripts/artifact_validate.sh" \
      --image-name test-image \
      --ndb-version 2.10 \
      --db-version 18 \
      --result-file "$failure_result" \
      --keep-on-failure >/dev/null 2>&1; then
      fail "artifact validation failure unexpectedly exited successfully"
    fi
  )

  jq -e '.status == "failed" and .cleanup_status == "kept-on-failure" and .vm_uuid == "vm-uuid"' "$failure_result" >/dev/null || fail "artifact validation failure result JSON"
  [[ ! -e "$tmpdir/delete-called" ]] || fail "artifact validation deleted VM despite --keep-on-failure"

  (
    export PATH="$tmpdir/bin:$PATH"
    export PKR_VAR_pc_username=user
    export PKR_VAR_pc_password=password
    export PKR_VAR_pc_ip=pc.example.com
    export PKR_VAR_cluster_name=mock-cluster
    export PKR_VAR_subnet_name=mock-subnet
    export NDB_SELFTEST_DELETE_MARKER="$tmpdir/delete-called"
    export NDB_SELFTEST_ANSIBLE_RC=0
    export NDB_SELFTEST_PLAYBOOK_CAPTURE="$tmpdir/postgres-validate.yml"
    if "$ROOT_DIR/scripts/artifact_validate.sh" \
      --image-name test-image \
      --ndb-version 2.10 \
      --db-version 18 \
      --provisioning-role postgresql \
      --mongodb-edition community \
      --mongodb-deployments '[]' \
      --result-file "$success_result" >/dev/null 2>&1; then
      :
    else
      fail "artifact validation success path unexpectedly failed"
    fi
  )

  grep -q "validate_postgres" "$tmpdir/postgres-validate.yml" || fail "PostgreSQL artifact validation did not dispatch validate_postgres"
  jq -e '.status == "passed" and .cleanup_status == "deleted" and .artifact_vm_name != "" and .artifact_vm_uuid == "vm-uuid" and .cleanup.artifact_validation_vm == "deleted"' "$success_result" >/dev/null || fail "artifact validation success result JSON"
  [[ -e "$tmpdir/delete-called" ]] || fail "artifact validation success did not request VM delete"
  rm -f "$tmpdir/delete-called"

  (
    export PATH="$tmpdir/bin:$PATH"
    export PKR_VAR_pc_username=user
    export PKR_VAR_pc_password=password
    export PKR_VAR_pc_ip=pc.example.com
    export PKR_VAR_cluster_name=mock-cluster
    export PKR_VAR_subnet_name=mock-subnet
    export NDB_SELFTEST_DELETE_MARKER="$tmpdir/delete-called"
    export NDB_SELFTEST_ANSIBLE_RC=0
    export NDB_SELFTEST_PLAYBOOK_CAPTURE="$tmpdir/custom-validate.yml"
    export NDB_SELFTEST_ROLES_PATH_CAPTURE="$tmpdir/custom-roles-path"
    export NDB_SELFTEST_VARS_CAPTURE="$tmpdir/custom-vars.json"
    "$ROOT_DIR/scripts/artifact_validate.sh" \
      --image-name test-image \
      --ndb-version 2.10 \
      --db-version 18 \
      --customization-enabled \
      --customization-profile-name enterprise-example \
      --customization-profile-file "$ROOT_DIR/customizations/profiles/enterprise-example.yml" \
      --customization-roles-path "$ROOT_DIR/ansible/2.10/roles:$ROOT_DIR/customizations/examples/enterprise-validation/roles" \
      --result-file "$tmpdir/custom-result.json" >/dev/null
  ) || fail "custom artifact validation success path failed"

  grep -q "customization_profile" "$tmpdir/custom-validate.yml" || fail "custom artifact validation did not dispatch customization_profile"
  grep -q "customization_phase: validate" "$tmpdir/custom-validate.yml" || fail "custom artifact validation missing validate phase"
  grep -q "$ROOT_DIR/customizations/examples/enterprise-validation/roles" "$tmpdir/custom-roles-path" || fail "custom artifact validation did not use custom roles path"
  jq -e '.customization_enabled == true and .customization_profile_name == "enterprise-example" and (.customization_profile_file | endswith("customizations/profiles/enterprise-example.yml"))' "$tmpdir/custom-vars.json" >/dev/null || fail "custom artifact validation vars JSON"
  jq -e '.status == "passed"' "$tmpdir/custom-result.json" >/dev/null || fail "custom artifact validation result JSON"
  [[ -e "$tmpdir/delete-called" ]] || fail "custom artifact validation success did not request VM delete"
  rm -f "$tmpdir/delete-called"

  (
    export PATH="$tmpdir/bin:$PATH"
    export PKR_VAR_pc_username=user
    export PKR_VAR_pc_password=password
    export PKR_VAR_pc_ip=pc.example.com
    export PKR_VAR_cluster_name=mock-cluster
    export PKR_VAR_subnet_name=mock-subnet
    export NDB_SELFTEST_DELETE_MARKER="$tmpdir/delete-called"
    export NDB_SELFTEST_ANSIBLE_RC=0
    export NDB_SELFTEST_PLAYBOOK_CAPTURE="$tmpdir/mongodb-validate.yml"
    "$ROOT_DIR/scripts/artifact_validate.sh" \
      --image-name test-image \
      --ndb-version 2.10 \
      --db-version 8.0 \
      --db-type mongodb \
      --provisioning-role mongodb \
      --mongodb-edition community \
      --mongodb-deployments '["single-instance","replica-set","sharded-cluster"]' \
      --result-file "$tmpdir/mongodb-result.json" >/dev/null
  ) || fail "MongoDB artifact validation success path failed"

  grep -q "validate_mongodb" "$tmpdir/mongodb-validate.yml" || fail "MongoDB artifact validation did not dispatch validate_mongodb"
  jq -e '.status == "passed"' "$tmpdir/mongodb-result.json" >/dev/null || fail "MongoDB artifact validation result JSON"
  [[ -e "$tmpdir/delete-called" ]] || fail "MongoDB artifact validation success did not request VM delete"
  rm -f "$tmpdir/delete-called"

  (
    export PATH="$tmpdir/bin:$PATH"
    export PKR_VAR_pc_username=user
    export PKR_VAR_pc_password=password
    export PKR_VAR_pc_ip=pc.example.com
    export PKR_VAR_cluster_name=mock-cluster
    export PKR_VAR_subnet_name=mock-subnet
    export NDB_SELFTEST_DELETE_MARKER="$tmpdir/delete-called"
    export NDB_SELFTEST_ANSIBLE_RC=0
    export NDB_SELFTEST_DELETE_TASK_STATUS=FAILED
    if "$ROOT_DIR/scripts/artifact_validate.sh" \
      --image-name test-image \
      --ndb-version 2.10 \
      --db-version 18 \
      --result-file "$cleanup_result" >/dev/null 2>&1; then
      fail "artifact validation cleanup failure unexpectedly exited successfully"
    fi
  )

  jq -e '.status == "failed" and .cleanup_status == "delete-task-failed" and .vm_uuid == "vm-uuid"' "$cleanup_result" >/dev/null || fail "artifact validation cleanup failure result JSON"
  [[ -e "$tmpdir/delete-called" ]] || fail "artifact validation cleanup failure did not request VM delete"

  pass "artifact validation failure handling"
}

run_artifact_validate_tests

run_release_scaffold_tests() {
  local output test_version
  test_version="99.$(date +%s)"
  output=$("$ROOT_DIR/scripts/release_scaffold.sh" "$test_version" --from 2.10 --dry-run)
  grep -q "ansible/${test_version}" <<<"$output" || fail "release scaffold dry-run"
  [[ ! -e "$ROOT_DIR/ndb/$test_version" ]] || fail "release scaffold dry-run created ndb/$test_version"
  [[ ! -e "$ROOT_DIR/ansible/$test_version" ]] || fail "release scaffold dry-run created ansible/$test_version"
  pass "release scaffold dry-run"
}

run_release_scaffold_tests

run_postgres_extension_helper_tests() {
  local selected unknown nonqualified resolved skipped suffix

  # shellcheck source=/dev/null
  source "$ROOT_DIR/scripts/postgres_extensions.sh"

  selected=$(postgres_extensions_selection_to_json "pg_vector, PostGIS,pg_cron")
  jq -e '. == ["pg_cron","pgvector","postgis"]' <<<"$selected" >/dev/null || fail "extension selection normalization"

  selected=$(postgres_extensions_selection_to_json "none")
  jq -e '. == []' <<<"$selected" >/dev/null || fail "extension selection none"

  unknown=$(postgres_extensions_unknown_json '["pgvector","not_real"]')
  jq -e '. == ["not_real"]' <<<"$unknown" >/dev/null || fail "unknown extension detection"

  nonqualified=$(postgres_extensions_not_qualified_json '["pgvector","postgis"]' '["pgvector"]')
  jq -e '. == ["postgis"]' <<<"$nonqualified" >/dev/null || fail "non-qualified extension detection"

  resolved=$(postgres_extensions_resolve_selection_json "all-qualified" '["pgvector","citext","pg_cron"]')
  skipped=$(postgres_extensions_all_qualified_skipped_json '["pgvector","citext","pg_cron"]')
  jq -e '. == ["pg_cron","pgvector"]' <<<"$resolved" >/dev/null || fail "all-qualified installable subset"
  jq -e '. == ["citext"]' <<<"$skipped" >/dev/null || fail "all-qualified skipped non-installable extensions"

  suffix=$(postgres_extensions_image_name_suffix_json '["pg_stat_statements"]')
  [[ "$suffix" == "ext-pg-stat-statements" ]] || fail "single extension image suffix"

  suffix=$(postgres_extensions_image_name_suffix_json '["pg_cron","pglogical","pg_partman","pg_stat_statements"]')
  [[ "$suffix" =~ ^ext-pg-cron-pglogical-pg-partman-plus-1-[0-9]+$ ]] || fail "long extension image suffix"

  pass "PostgreSQL extension helper"
}

run_postgres_extension_helper_tests

run_build_wizard_tests() {
  local tmpdir output build_log wizard stubbin packer_log ssh_keygen_log
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' RETURN
  output="$tmpdir/wizard.out"
  build_log="$tmpdir/build.log"
  wizard="$tmpdir/scripts/build_wizard.sh"
  stubbin="$tmpdir/bin"
  packer_log="$tmpdir/packer.log"
  ssh_keygen_log="$tmpdir/ssh-keygen.log"

  mkdir -p "$tmpdir/ndb/9.99" "$tmpdir/scripts" "$tmpdir/customizations/profiles" "$tmpdir/packer" "$stubbin"
  cp "$ROOT_DIR/scripts/build_wizard.sh" "$wizard"
  cp "$ROOT_DIR/scripts/postgres_extensions.sh" "$tmpdir/scripts/postgres_extensions.sh"
  chmod +x "$wizard"

  cat > "$tmpdir/ndb/9.99/matrix.json" <<'JSON'
[
  {
    "ndb_version": "9.99",
    "engine": "PostgreSQL Community Edition",
    "db_type": "pgsql",
    "os_type": "Rocky Linux",
    "os_version": "9.9",
    "db_version": "16",
    "provisioning_role": "postgresql",
    "qualified_extensions": ["pgvector", "postgis"]
  },
  {
    "ndb_version": "9.99",
    "engine": "PostgreSQL Community Edition",
    "db_type": "pgsql",
    "os_type": "Ubuntu",
    "os_version": "22.04",
    "db_version": "15",
    "provisioning_role": "postgresql",
    "qualified_extensions": [],
    "qualified_extensions_empty_reason": "Self-test empty extension row."
  },
  {
    "ndb_version": "9.99",
    "engine": "MongoDB",
    "db_type": "mongodb",
    "os_type": "Rocky Linux",
    "os_version": "9.9",
    "db_version": "8.0",
    "provisioning_role": "mongodb",
    "mongodb_edition": "community",
    "deployment": ["single-instance", "replica-set", "sharded-cluster"]
  },
  {
    "ndb_version": "9.99",
    "engine": "PostgreSQL Community Edition",
    "db_type": "pgsql",
    "os_type": "Red Hat Enterprise Linux (RHEL)",
    "os_version": "9.7",
    "db_version": "14",
    "provisioning_role": "postgresql",
    "qualified_extensions": [],
    "qualified_extensions_empty_reason": "Self-test licensed source image row."
  },
  {
    "ndb_version": "9.99",
    "engine": "Metadata Only",
    "db_type": "pgsql",
    "os_type": "RHEL",
    "os_version": "9.9",
    "db_version": "14",
    "provisioning_role": "metadata",
    "qualified_extensions": ["pg_stat_statements"]
  }
]
JSON

  cat > "$tmpdir/images.json" <<'JSON'
{
  "rhel-9.7": {
    "env_var": "NDB_RHEL_9_7_IMAGE_URI",
    "description": "Set NDB_RHEL_9_7_IMAGE_URI before starting the build."
  }
}
JSON

  cat > "$tmpdir/customizations/profiles/enterprise-example.yml" <<'YAML'
name: enterprise-example
phases: {}
YAML

  cat > "$tmpdir/.env.example" <<'ENV'
export PKR_VAR_pc_username="your-prism-username"
export PKR_VAR_pc_password="your-prism-password"
export PKR_VAR_pc_ip="your-prism-central-ip-or-hostname"
export PKR_VAR_cluster_name="your-cluster-name"
export PKR_VAR_subnet_name="your-subnet-name"
ENV

  cat > "$stubbin/packer" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${NDB_SELFTEST_PACKER_LOG:?}"
SH

  cat > "$stubbin/ssh-keygen" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
key_path=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -f)
      key_path=$2
      shift
      ;;
  esac
  shift
done
[[ -n "$key_path" ]] || exit 2
mkdir -p "$(dirname "$key_path")"
printf 'PRIVATE KEY\n' > "$key_path"
printf 'PUBLIC KEY\n' > "${key_path}.pub"
printf '%s\n' "$key_path" >> "${NDB_SELFTEST_SSH_KEYGEN_LOG:?}"
SH

  cat > "$stubbin/dirname" <<'SH'
#!/bin/sh
case "$1" in
  */*) printf '%s\n' "${1%/*}" ;;
  *) printf '.\n' ;;
esac
SH

  chmod +x "$stubbin/packer" "$stubbin/ssh-keygen" "$stubbin/dirname"

  cat > "$tmpdir/build.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%q ' "$@" > "${NDB_SELFTEST_BUILD_LOG:?}"
printf '\n' >> "${NDB_SELFTEST_BUILD_LOG:?}"
SH
  chmod +x "$tmpdir/build.sh"

  (
    cd "$tmpdir"
    env PATH="$stubbin" /bin/bash "$wizard" >"$output" 2>&1
  ) && fail "wizard unexpectedly passed without jq"
  grep -Fq "Missing jq." "$output" || fail "wizard missing jq message is not beginner-friendly"

  (
    cd "$tmpdir"
    printf '3\n1\n1\n1\n1\n1\n0\n1\n1\n1\n' \
      | PATH="$stubbin:$PATH" NDB_SELFTEST_PACKER_LOG="$packer_log" NDB_SELFTEST_SSH_KEYGEN_LOG="$ssh_keygen_log" "$wizard" >"$output" 2>&1
  ) || fail "wizard .env copy readiness action failed"
  [[ -f "$tmpdir/.env" ]] || fail "wizard did not copy .env.example to .env"
  grep -Fq "Created .env from .env.example." "$output" || fail "wizard did not report .env creation"

  rm -f "$tmpdir/packer/id_rsa" "$tmpdir/packer/id_rsa.pub" "$ssh_keygen_log"
  (
    cd "$tmpdir"
    printf '2\n1\n1\n1\n1\n1\n0\n1\n1\n1\n' \
      | PATH="$stubbin:$PATH" NDB_SELFTEST_PACKER_LOG="$packer_log" NDB_SELFTEST_SSH_KEYGEN_LOG="$ssh_keygen_log" "$wizard" >"$output" 2>&1
  ) || fail "wizard SSH key readiness action failed"
  [[ -f "$tmpdir/packer/id_rsa" ]] || fail "wizard did not create packer/id_rsa"
  [[ -f "$tmpdir/packer/id_rsa.pub" ]] || fail "wizard did not create packer/id_rsa.pub"
  grep -Fq "$tmpdir/packer/id_rsa" "$ssh_keygen_log" || fail "wizard did not invoke ssh-keygen with packer/id_rsa"

  : > "$packer_log"
  cp "$tmpdir/.env.example" "$tmpdir/.env"
  printf 'PRIVATE KEY\n' > "$tmpdir/packer/id_rsa"
  printf 'PUBLIC KEY\n' > "$tmpdir/packer/id_rsa.pub"
  (
    cd "$tmpdir"
    printf '2\n1\n1\n1\n1\n1\n0\n1\n1\n1\n' \
      | PATH="$stubbin:$PATH" NDB_SELFTEST_PACKER_LOG="$packer_log" NDB_SELFTEST_SSH_KEYGEN_LOG="$ssh_keygen_log" "$wizard" >"$output" 2>&1
  ) || fail "wizard packer init readiness action failed"
  grep -Fq "init packer/" "$packer_log" || fail "wizard did not invoke packer init packer/"

  grep -Eq "PKR_VAR_pc_password: (present|missing)" "$output" || fail "wizard did not show secret variable status"
  ! grep -Fq "your-prism-password" "$output" || fail "wizard printed secret-like .env template value"

  (
    cd "$tmpdir"
    printf '1\n1\n1\n1\n1\n0\n1\n1\n1\n' | "$wizard" >"$output" 2>&1
  ) || fail "wizard default PostgreSQL dry-run failed"
  grep -Fq "Qualified extensions: pgvector, postgis" "$output" || fail "wizard did not show PostgreSQL qualified extension list"
  grep -Fq "Selected extensions: none" "$output" || fail "wizard default did not select no extensions"
  grep -Fq "./build.sh --ci --dry-run --ndb-version 9.99 --db-type pgsql --os 'Rocky Linux' --os-version 9.9 --db-version 16" "$output" || fail "wizard dry-run command mismatch"
  ! grep -Fq "Metadata Only" "$output" || fail "wizard exposed metadata-only rows"

  (
    cd "$tmpdir"
    printf '1\n1\n1\n1\n1\n1 3\n1\n1\n1\n' | "$wizard" >"$output" 2>&1
  ) || fail "wizard individual PostgreSQL extension selection failed"
  grep -Fq "Selected extensions: pgvector, pg_cron" "$output" || fail "wizard did not show selected extensions"
  grep -Fq "Image name suffix: ext-pg-cron-pgvector" "$output" || fail "wizard did not preview extension image name suffix"
  grep -Fq -- "--extensions" "$output" || fail "wizard command missing selected extension flag"
  grep -Fq "pgvector,pg_cron" "$output" || fail "wizard command missing selected extension list"
  grep -Fq "not release-note-qualified for this matrix row" "$output" || fail "wizard did not warn for advanced extension selection"

  (
    cd "$tmpdir"
    printf '1\n1\n1\n2\n1\n0\n1\n1\n1\n' | "$wizard" >"$output" 2>&1
  ) || fail "wizard empty-extension PostgreSQL dry-run failed"
  grep -Fq "Qualified extensions: none listed for this row." "$output" || fail "wizard did not show empty qualified extension status"
  grep -Fq "Self-test empty extension row." "$output" || fail "wizard did not show empty extension reason"

  (
    cd "$tmpdir"
    printf '1\n1\n1\n1\n4\n1\n0\n1\n1\n1\n' | "$wizard" >"$output" 2>&1
  ) || fail "wizard validated build preview failed"
  grep -Fq "./build.sh --ci --validate --validate-artifact --manifest --ndb-version 9.99 --db-type pgsql --os 'Rocky Linux' --os-version 9.9 --db-version 16" "$output" || fail "wizard build command missing validation defaults"
  grep -Fq "Selected image recipe:" "$output" || fail "wizard did not print selected recipe"
  grep -Fq "Validation: in-guest + saved artifact" "$output" || fail "wizard did not show recommended validation summary"

  (
    cd "$tmpdir"
    printf '1\n1\n1\n3\n1\n1\n1\n1\n' | "$wizard" >"$output" 2>&1
  ) || fail "wizard MongoDB dry-run failed"
  grep -Fq "MongoDB validation shape: single instance, replica set smoke test, sharded cluster smoke test" "$output" || fail "wizard did not show human MongoDB deployment list"
  grep -Fq "MongoDB edition: community" "$output" || fail "wizard did not show MongoDB edition"
  grep -Fq -- "--db-type mongodb" "$output" || fail "wizard MongoDB command mismatch"

  (
    cd "$tmpdir"
    printf '1\n1\n1\n4\n1\n0\n1\n1\n1\n' | NDB_RHEL_9_7_IMAGE_URI="" "$wizard" >"$output" 2>&1
  ) || fail "wizard RHEL source warning preview failed"
  grep -Fq "Warning: source image variable NDB_RHEL_9_7_IMAGE_URI is not set." "$output" || fail "wizard did not warn about missing RHEL source image variable"

  (
    cd "$tmpdir"
    printf '1\n1\n1\n1\n1\n0\n3\n11111111-2222-3333-4444-555555555555\n3\n1\n1\n' | "$wizard" >"$output" 2>&1
  ) || fail "wizard source UUID and customization preview failed"
  grep -Fq -- "--source-image-uuid 11111111-2222-3333-4444-555555555555" "$output" || fail "wizard source UUID command mismatch"
  grep -Fq -- "--customization-profile enterprise-example" "$output" || fail "wizard customization command mismatch"

  (
    cd "$tmpdir"
    printf '1\n1\n1\n1\n1\n0\n1\n1\n2\n' | NDB_SELFTEST_BUILD_LOG="$build_log" "$wizard" >"$output" 2>&1
  ) || fail "wizard run-now path failed"
  grep -Fq -- "--dry-run" "$build_log" || fail "wizard did not execute generated build command"

  (
    cd "$tmpdir"
    rm -f packer/id_rsa packer/id_rsa.pub
    printf '1\n1\n1\n1\n4\n1\n0\n1\n1\n2\n' | "$wizard" >"$output" 2>&1
  ) && fail "wizard live run-now unexpectedly passed without prerequisites"
  grep -Fq "Cannot run this live action yet." "$output" || fail "wizard did not stop live run-now with friendly message"
  ! grep -Fq "Running command..." "$output" || fail "wizard attempted to run live build despite missing prerequisites"

  pass "build wizard"
}

run_build_wizard_tests

run_test_harness_tests() {
  local tmpdir marker
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' RETURN
  marker="$tmpdir/second-build-finished"

  mkdir -p "$tmpdir/ndb/9.99" "$tmpdir/scripts"
  cp "$ROOT_DIR/test.sh" "$tmpdir/test.sh"
  cp "$ROOT_DIR/scripts/postgres_extensions.sh" "$tmpdir/scripts/postgres_extensions.sh"

  cat > "$tmpdir/ndb/9.99/matrix.json" <<'JSON'
[
  {
    "ndb_version": "9.99",
    "engine": "PostgreSQL Community Edition",
    "db_type": "pgsql",
    "os_type": "Rocky Linux",
    "os_version": "9.99",
    "db_version": "1",
    "provisioning_role": "postgresql"
  },
  {
    "ndb_version": "9.99",
    "engine": "PostgreSQL Community Edition",
    "db_type": "pgsql",
    "os_type": "Rocky Linux",
    "os_version": "9.99",
    "db_version": "2",
    "provisioning_role": "postgresql"
  }
]
JSON

  cat > "$tmpdir/build.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
db_version=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --db-version)
      db_version=$2
      shift
      ;;
  esac
  shift
done
if [[ "$db_version" == "1" ]]; then
  exit 17
fi
sleep 1
touch "${NDB_SELFTEST_SECOND_BUILD_MARKER:?}"
SH
  chmod +x "$tmpdir/test.sh" "$tmpdir/build.sh"

  if (
    cd "$tmpdir"
    SKIP_MATRIX_VALIDATION=true NDB_SELFTEST_SECOND_BUILD_MARKER="$marker" ./test.sh --include-ndb 9.99 --max-parallel 2 >/dev/null 2>&1
  ); then
    fail "test harness failure unexpectedly passed"
  fi

  [[ -e "$marker" ]] || fail "test harness did not drain active parallel build"
  pass "test harness drains active builds"
}

run_test_harness_tests

run_test_harness_extensions_only_tests() {
  local tmpdir build_log harness_stderr
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' RETURN
  build_log="$tmpdir/builds.log"
  harness_stderr="$tmpdir/test-harness.err"

  mkdir -p "$tmpdir/ndb/9.99" "$tmpdir/scripts"
  cp "$ROOT_DIR/test.sh" "$tmpdir/test.sh"
  cp "$ROOT_DIR/scripts/postgres_extensions.sh" "$tmpdir/scripts/postgres_extensions.sh"

  cat > "$tmpdir/ndb/9.99/matrix.json" <<'JSON'
[
  {
    "ndb_version": "9.99",
    "engine": "PostgreSQL Community Edition",
    "db_type": "pgsql",
    "os_type": "Rocky Linux",
    "os_version": "9.99",
    "db_version": "1",
    "provisioning_role": "postgresql",
    "qualified_extensions": ["pg_stat_statements"]
  },
  {
    "ndb_version": "9.99",
    "engine": "PostgreSQL Community Edition",
    "db_type": "pgsql",
    "os_type": "Rocky Linux",
    "os_version": "9.99",
    "db_version": "2",
    "provisioning_role": "postgresql",
    "qualified_extensions": [],
    "qualified_extensions_empty_reason": "self-test row without extension coverage"
  }
]
JSON

  cat > "$tmpdir/build.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
db_version=""
extension_selection=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --db-version)
      db_version=$2
      shift
      ;;
    --extensions)
      extension_selection=$2
      shift
      ;;
  esac
  shift
done
printf '%s|%s\n' "$db_version" "$extension_selection" >> "${NDB_SELFTEST_BUILD_LOG:?}"
SH
  chmod +x "$tmpdir/test.sh" "$tmpdir/build.sh"

  (
    cd "$tmpdir"
    SKIP_MATRIX_VALIDATION=true NDB_SELFTEST_BUILD_LOG="$build_log" ./test.sh --include-ndb 9.99 --extensions-only >/dev/null 2>"$harness_stderr"
  ) || fail "test harness extensions-only run failed"

  [[ "$(cat "$build_log")" == "1|all-qualified" ]] || fail "test harness extensions-only did not limit builds to extension rows with all-qualified"
  [[ ! -s "$harness_stderr" ]] || fail "test harness extensions-only wrote unexpected stderr: $(cat "$harness_stderr")"
  pass "test harness extensions-only filter"
}

run_test_harness_extensions_only_tests

run_test_harness_build_stdin_isolation_tests() {
  local tmpdir build_log
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' RETURN
  build_log="$tmpdir/builds.log"

  mkdir -p "$tmpdir/ndb/9.99" "$tmpdir/scripts"
  cp "$ROOT_DIR/test.sh" "$tmpdir/test.sh"
  cp "$ROOT_DIR/scripts/postgres_extensions.sh" "$tmpdir/scripts/postgres_extensions.sh"

  cat > "$tmpdir/ndb/9.99/matrix.json" <<'JSON'
[
  {
    "ndb_version": "9.99",
    "engine": "PostgreSQL Community Edition",
    "db_type": "pgsql",
    "os_type": "Rocky Linux",
    "os_version": "9.99",
    "db_version": "1",
    "provisioning_role": "postgresql",
    "qualified_extensions": ["pg_stat_statements"]
  },
  {
    "ndb_version": "9.99",
    "engine": "PostgreSQL Community Edition",
    "db_type": "pgsql",
    "os_type": "Rocky Linux",
    "os_version": "9.99",
    "db_version": "2",
    "provisioning_role": "postgresql",
    "qualified_extensions": ["pg_stat_statements"]
  }
]
JSON

  cat > "$tmpdir/build.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
db_version=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --db-version)
      db_version=$2
      shift
      ;;
  esac
  shift
done
cat >/dev/null
printf '%s\n' "$db_version" >> "${NDB_SELFTEST_BUILD_LOG:?}"
SH
  chmod +x "$tmpdir/test.sh" "$tmpdir/build.sh"

  (
    cd "$tmpdir"
    SKIP_MATRIX_VALIDATION=true NDB_SELFTEST_BUILD_LOG="$build_log" ./test.sh --include-ndb 9.99 --extensions-only --max-parallel 1 >/dev/null 2>&1
  ) || fail "test harness stdin isolation run failed"

  [[ "$(tr '\n' ',' < "$build_log")" == "1,2," ]] || fail "test harness let a build consume remaining matrix rows"
  pass "test harness isolates build stdin"
}

run_test_harness_build_stdin_isolation_tests

run_test_harness_continue_on_error_tests() {
  local tmpdir build_log
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' RETURN
  build_log="$tmpdir/builds.log"

  mkdir -p "$tmpdir/ndb/9.99" "$tmpdir/scripts"
  cp "$ROOT_DIR/test.sh" "$tmpdir/test.sh"
  cp "$ROOT_DIR/scripts/postgres_extensions.sh" "$tmpdir/scripts/postgres_extensions.sh"

  cat > "$tmpdir/ndb/9.99/matrix.json" <<'JSON'
[
  {
    "ndb_version": "9.99",
    "engine": "PostgreSQL Community Edition",
    "db_type": "pgsql",
    "os_type": "Rocky Linux",
    "os_version": "9.99",
    "db_version": "1",
    "provisioning_role": "postgresql",
    "qualified_extensions": ["pg_stat_statements"]
  },
  {
    "ndb_version": "9.99",
    "engine": "PostgreSQL Community Edition",
    "db_type": "pgsql",
    "os_type": "Rocky Linux",
    "os_version": "9.99",
    "db_version": "2",
    "provisioning_role": "postgresql",
    "qualified_extensions": ["pg_stat_statements"]
  }
]
JSON

  cat > "$tmpdir/build.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
db_version=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --db-version)
      db_version=$2
      shift
      ;;
  esac
  shift
done
printf '%s\n' "$db_version" >> "${NDB_SELFTEST_BUILD_LOG:?}"
if [[ "$db_version" == "1" ]]; then
  exit 17
fi
SH
  chmod +x "$tmpdir/test.sh" "$tmpdir/build.sh"

  if (
    cd "$tmpdir"
    SKIP_MATRIX_VALIDATION=true NDB_SELFTEST_BUILD_LOG="$build_log" ./test.sh --include-ndb 9.99 --extensions-only --continue-on-error >/dev/null 2>&1
  ); then
    fail "test harness continue-on-error unexpectedly passed despite one failed build"
  fi

  [[ "$(tr '\n' ',' < "$build_log")" == "1,2," ]] || fail "test harness continue-on-error did not run all requested rows"
  pass "test harness continue-on-error coverage"
}

run_test_harness_continue_on_error_tests

run_mongodb_dispatch_guard_tests() {
  grep -q 'postgresql|mongodb' "$ROOT_DIR/build.sh" || fail "build.sh does not allow MongoDB provisioning role"
  grep -q 'mongodb_edition' "$ROOT_DIR/build.sh" || fail "build.sh does not pass MongoDB edition to Ansible"
  grep -q 'mongodb_deployments' "$ROOT_DIR/build.sh" || fail "build.sh does not pass MongoDB deployments to Ansible"
  grep -q 'PROVISIONING_ROLE=$(echo "$CONFIG"' "$ROOT_DIR/build.sh" || fail "build.sh does not extract provisioning role from the matrix"
  grep -q -- '--provisioning-role "$PROVISIONING_ROLE"' "$ROOT_DIR/build.sh" || fail "build.sh does not pass provisioning role to artifact validation"
  grep -Fq 'if [[ "$provisioning_role" == "metadata" ]]' "$ROOT_DIR/test.sh" || fail "test.sh still filters to one hard-coded provisioning role"
  pass "MongoDB build and test dispatch guards"
}

run_mongodb_dispatch_guard_tests

run_extension_strictness_tests() {
  local version
  for version in 2.9 2.10; do
    grep -q "Assert all requested PostgreSQL extensions are installable" "$ROOT_DIR/ansible/$version/roles/postgres/tasks/main.yml" || fail "postgres role $version does not fail skipped requested extensions"
    grep -q "Assert all requested PostgreSQL extensions are validated" "$ROOT_DIR/ansible/$version/roles/validate_postgres/tasks/main.yml" || fail "validate_postgres role $version does not fail skipped requested extensions"
    grep -q "until: validate_service_active_result.stdout == \"active\"" "$ROOT_DIR/ansible/$version/roles/validate_postgres/tasks/main.yml" || fail "validate_postgres role $version does not wait for services to become active"
    grep -q 'pgaudit: "pgaudit_%s"' "$ROOT_DIR/ansible/$version/roles/postgres/defaults/main.yml" || fail "postgres role $version uses the wrong RedHat pgaudit package template"
    grep -q '"14": "pgaudit16_14"' "$ROOT_DIR/ansible/$version/roles/postgres/defaults/main.yml" || fail "postgres role $version is missing the RedHat PG14 pgaudit override"
    grep -q '"15": "pgaudit17_15"' "$ROOT_DIR/ansible/$version/roles/postgres/defaults/main.yml" || fail "postgres role $version is missing the RedHat PG15 pgaudit override"
    grep -q 'timescaledb: "timescaledb_%s"' "$ROOT_DIR/ansible/$version/roles/postgres/defaults/main.yml" || fail "postgres role $version uses the wrong RedHat TimescaleDB package template"
    grep -q 'timescaledb: "timescaledb-2-postgresql-%s"' "$ROOT_DIR/ansible/$version/roles/postgres/defaults/main.yml" || fail "postgres role $version uses the wrong Debian TimescaleDB package template"
    grep -q 'pg_stat_statements: "postgresql-contrib-%s"' "$ROOT_DIR/ansible/$version/roles/postgres/defaults/main.yml" || fail "postgres role $version uses the wrong Debian contrib package template"
    grep -q "postgresql-contrib-' + postgres_major_version" "$ROOT_DIR/ansible/$version/roles/postgres/tasks/main.yml" || fail "postgres role $version computes the wrong Debian contrib package name"
    grep -q "Add TimescaleDB repository (Debian/Ubuntu)" "$ROOT_DIR/ansible/$version/roles/postgres/tasks/main.yml" || fail "postgres role $version does not add the TimescaleDB Ubuntu repository"
    grep -q "timescale_timescaledb-archive-keyring.gpg" "$ROOT_DIR/ansible/$version/roles/postgres/tasks/main.yml" || fail "postgres role $version does not install the dearmored TimescaleDB keyring"
    grep -q "lock_timeout: 600" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version does not wait for apt locks"
    grep -q "apt_postgres_extension_packages_result" "$ROOT_DIR/ansible/$version/roles/postgres/tasks/main.yml" || fail "postgres role $version does not retry Debian extension package installs"
  done
  pass "strict extension package mapping, apt locking, and skip guards"
}

run_extension_strictness_tests

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

run_playbook_database_dispatch_tests

run_mongodb_role_static_tests() {
  local version
  for version in 2.9 2.10; do
    grep -q "mongodb_edition" "$ROOT_DIR/ansible/$version/roles/mongodb/defaults/main.yml" || fail "mongodb role $version missing edition default"
    grep -q "repo.mongodb.org" "$ROOT_DIR/ansible/$version/roles/mongodb/tasks/main.yml" || fail "mongodb role $version missing community repository"
    grep -q "repo.mongodb.com" "$ROOT_DIR/ansible/$version/roles/mongodb/tasks/main.yml" || fail "mongodb role $version missing enterprise repository"
    grep -q "lock_timeout: 600" "$ROOT_DIR/ansible/$version/roles/mongodb/tasks/main.yml" || fail "mongodb role $version does not wait for apt locks"
    grep -q "mongodb-enterprise" "$ROOT_DIR/ansible/$version/roles/mongodb/tasks/main.yml" || fail "mongodb role $version does not support enterprise packages"
    grep -q "mongod" "$ROOT_DIR/ansible/$version/roles/mongodb/tasks/main.yml" || fail "mongodb role $version does not manage mongod service"
    grep -q "mongodb_selinux_policy_repo" "$ROOT_DIR/ansible/$version/roles/mongodb/tasks/main.yml" || fail "mongodb role $version does not install MongoDB SELinux policy"
    grep -q "mongodb-selinux.git" "$ROOT_DIR/ansible/$version/roles/mongodb/defaults/main.yml" || fail "mongodb role $version missing MongoDB SELinux policy repository default"
    grep -q "selinux-policy-devel" "$ROOT_DIR/ansible/$version/roles/mongodb/tasks/main.yml" || fail "mongodb role $version missing SELinux policy build dependency"
    grep -q "mongodb_selinux_policy_version" "$ROOT_DIR/ansible/$version/roles/mongodb/defaults/main.yml" || fail "mongodb role $version does not pin SELinux policy version"
    grep -Eq 'mongodb_selinux_policy_version: "[0-9a-f]{40}"' "$ROOT_DIR/ansible/$version/roles/mongodb/defaults/main.yml" || fail "mongodb role $version SELinux policy version is not a commit SHA"
    grep -q "update: false" "$ROOT_DIR/ansible/$version/roles/mongodb/tasks/main.yml" || fail "mongodb role $version updates SELinux policy from a mutable branch"
    ! grep -q "^mongodb_user: mongod" "$ROOT_DIR/ansible/$version/roles/mongodb/defaults/main.yml" || fail "mongodb role $version has RedHat-only user default"
    ! grep -q "^mongodb_group: mongod" "$ROOT_DIR/ansible/$version/roles/mongodb/defaults/main.yml" || fail "mongodb role $version has RedHat-only group default"
  done
  pass "MongoDB provisioning role static checks"
}

run_mongodb_role_static_tests

run_validate_mongodb_role_static_tests() {
  local version
  for version in 2.9 2.10; do
    grep -q "validate_mongodb_service_active_retries" "$ROOT_DIR/ansible/$version/roles/validate_mongodb/defaults/main.yml" || fail "validate_mongodb role $version missing retry default"
    grep -q "mongod --version" "$ROOT_DIR/ansible/$version/roles/validate_mongodb/tasks/main.yml" || fail "validate_mongodb role $version does not check mongod version"
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
  done
  pass "MongoDB validation role static checks"
}

run_validate_mongodb_role_static_tests

run_image_prepare_tests() {
  local version
  for version in 2.9 2.10; do
    grep -q -- "- image_prepare" "$ROOT_DIR/ansible/$version/playbooks/site.yml" || fail "playbook $version does not run final image preparation"
    grep -q "/usr/bin/cloud-init clean --logs --machine-id" "$ROOT_DIR/ansible/$version/roles/image_prepare/tasks/main.yml" || fail "image_prepare role $version does not reset cloud-init state"
    grep -q "/etc/netplan/50-cloud-init.yaml" "$ROOT_DIR/ansible/$version/roles/image_prepare/tasks/main.yml" || fail "image_prepare role $version does not remove generated Ubuntu netplan"
  done
  pass "final image preparation guard"
}

run_image_prepare_tests

run_build_cleanup_guard_tests() {
  grep -q "cleanup_failed_builder_vm" "$ROOT_DIR/build.sh" || fail "build script does not define failed builder VM cleanup"
  grep -q "prism_delete_vm" "$ROOT_DIR/build.sh" || fail "build script does not delete failed builder VMs"
  pass "failed builder VM cleanup guard"
}

run_build_cleanup_guard_tests

run_readme_mongodb_tests() {
  grep -q "MongoDB" "$ROOT_DIR/README.md" || fail "README does not mention MongoDB"
  grep -q -- "--include-db-type mongodb" "$ROOT_DIR/README.md" || fail "README missing MongoDB test command"
  grep -q "sharded topology" "$ROOT_DIR/README.md" || fail "README missing local sharded topology explanation"
  grep -q "mongodb_edition" "$ROOT_DIR/README.md" || fail "README missing MongoDB edition matrix guidance"
  pass "README MongoDB guidance"
}

run_readme_mongodb_tests

run_readme_wizard_tests() {
  grep -q "scripts/build_wizard.sh" "$ROOT_DIR/README.md" || fail "README missing build wizard command"
  grep -q "safest first path" "$ROOT_DIR/README.md" || fail "README missing first build assistant positioning"
  grep -q "create \`packer/id_rsa\`" "$ROOT_DIR/README.md" || fail "README missing wizard SSH key setup guidance"
  grep -q "run \`packer init packer/\`" "$ROOT_DIR/README.md" || fail "README missing wizard Packer init guidance"
  grep -q "op run --env-file .env -- scripts/build_wizard.sh" "$ROOT_DIR/README.md" || fail "README missing 1Password wizard guidance"
  grep -q "PostgreSQL extensions are optional" "$ROOT_DIR/README.md" || fail "README missing optional PostgreSQL extension guidance"
  grep -q -- "--extensions pgvector,postgis" "$ROOT_DIR/README.md" || fail "README missing direct PostgreSQL extension CLI example"
  grep -q "ext-pgvector-postgis" "$ROOT_DIR/README.md" || fail "README missing extension image naming example"
  grep -q "not release-note-qualified for this matrix row" "$ROOT_DIR/README.md" || fail "README missing advisory qualification warning wording"
  ! grep -q "Maintainer rule:" "$ROOT_DIR/README.md" || fail "README should not contain agent maintainer rules"
  pass "README build wizard guidance"
}

run_readme_wizard_tests

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

run_ansible_fact_normalization_guard_tests

run_agent_guidance_tests() {
  grep -q "update the shell wizard/TUI in the same work item" "$ROOT_DIR/AGENTS.md" || fail "AGENTS missing wizard maintenance rule"
  grep -q "Keep the README beginner-facing" "$ROOT_DIR/AGENTS.md" || fail "AGENTS missing README boundary guidance"
  grep -q "Packer, Terraform, Ansible, and shell" "$ROOT_DIR/AGENTS.md" || fail "AGENTS missing toolchain guidance"
  grep -q "op run --env-file .env" "$ROOT_DIR/AGENTS.md" || fail "AGENTS missing 1Password env guidance"
  grep -q -- "--source-image-uuid" "$ROOT_DIR/AGENTS.md" || fail "AGENTS missing source image UUID guidance"
  grep -q "qualified_extensions" "$ROOT_DIR/AGENTS.md" || fail "AGENTS missing qualified extension metadata guidance"
  grep -q "RHEL live validation has been blocked" "$ROOT_DIR/AGENTS.md" || fail "AGENTS missing RHEL validation blocker"
  grep -q "update the shell wizard/TUI in the same work item" "$ROOT_DIR/tasks/lessons.md" || fail "lessons missing wizard maintenance rule"
  grep -q "Do not treat qualified_extensions as default installs" "$ROOT_DIR/tasks/lessons.md" || fail "lessons missing qualified extension correction"
  pass "agent guidance"
}

run_agent_guidance_tests

run_readme_customization_tests() {
  grep -q "Customize The Image" "$ROOT_DIR/README.md" || fail "README missing Customize The Image"
  grep -q "Install an internal CA certificate" "$ROOT_DIR/README.md" || fail "README missing internal CA recipe"
  grep -q "OpenTelemetry Collector" "$ROOT_DIR/README.md" || fail "README missing OpenTelemetry explanation"
  grep -q "customizations/local" "$ROOT_DIR/README.md" || fail "README missing private overlay explanation"
  grep -q "validate_custom_enterprise" "$ROOT_DIR/README.md" || fail "README missing custom validation role guidance"
  pass "README customization guidance"
}

run_readme_customization_tests
