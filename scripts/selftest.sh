#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

SELFTEST_ANSIBLE_LOCAL_TEMP=""
if [[ -z "${ANSIBLE_LOCAL_TEMP:-}" ]]; then
  SELFTEST_ANSIBLE_LOCAL_TEMP=$(mktemp -d "${TMPDIR:-/tmp}/ndb-ansible-local.XXXXXX")
  export ANSIBLE_LOCAL_TEMP="$SELFTEST_ANSIBLE_LOCAL_TEMP"
fi
if [[ -z "${ANSIBLE_REMOTE_TEMP:-}" ]]; then
  export ANSIBLE_REMOTE_TEMP="${ANSIBLE_LOCAL_TEMP}/remote"
fi

cleanup_selftest_tmp() {
  if [[ -n "$SELFTEST_ANSIBLE_LOCAL_TEMP" ]]; then
    rm -rf "$SELFTEST_ANSIBLE_LOCAL_TEMP"
  fi
}
trap cleanup_selftest_tmp EXIT

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
    "postgres_qualified_version_range": "18.0",
    "postgres_package_version_prefix": "18.0",
    "postgres_package_use_archive": true,
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
  assert_invalid_matrix "PostgreSQL package pin requires range" '[{"ndb_version":"2.99","engine":"PostgreSQL Community Edition","db_type":"pgsql","os_type":"Rocky Linux","os_version":"9.9","db_version":"18","provisioning_role":"postgresql","postgres_package_version_prefix":"18.0","qualified_extensions":["pg_stat_statements"]}]' "postgres_qualified_version_range"
  assert_invalid_matrix "PostgreSQL package pin major mismatch" '[{"ndb_version":"2.99","engine":"PostgreSQL Community Edition","db_type":"pgsql","os_type":"Rocky Linux","os_version":"9.9","db_version":"18","provisioning_role":"postgresql","postgres_qualified_version_range":"18.0","postgres_package_version_prefix":"17.8","qualified_extensions":["pg_stat_statements"]}]' "postgres_package_version_prefix.*db_version"
  assert_invalid_matrix "PostgreSQL archive flag type" '[{"ndb_version":"2.99","engine":"PostgreSQL Community Edition","db_type":"pgsql","os_type":"Rocky Linux","os_version":"9.9","db_version":"18","provisioning_role":"postgresql","postgres_qualified_version_range":"18.0","postgres_package_version_prefix":"18.0","postgres_package_use_archive":"yes","qualified_extensions":["pg_stat_statements"]}]' "postgres_package_use_archive"
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

run_postgres_debian_package_resolver_tests() {
  local version role_file
  for version in 2.9 2.10; do
    role_file="$ROOT_DIR/ansible/$version/roles/postgres/tasks/main.yml"
    ! grep -q 'apt-cache madison "$POSTGRES_PACKAGE_NAME" |' "$role_file" || fail "postgres role $version uses an early-exit apt-cache pipeline that can fail with rc 141 under pipefail"
  done
  pass "PostgreSQL Debian package resolver avoids pipefail SIGPIPE"
}

run_postgres_debian_package_resolver_tests

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

run_customization_profile_static_tests

run_rhel_activation_key_guard_tests() {
  local version playbook_file role_file image_prepare_file subscription_line common_line tmpdir output

  grep -q "NDB_RHEL_ORGID" "$ROOT_DIR/build.sh" || fail "build.sh does not pass NDB_RHEL_ORGID to Ansible"
  grep -q "NDB_RHEL_ACTIVATIONKEY" "$ROOT_DIR/build.sh" || fail "build.sh does not pass NDB_RHEL_ACTIVATIONKEY to Ansible"
  grep -q "RHEL subscription activation:" "$ROOT_DIR/build.sh" || fail "build.sh dry-run missing non-secret RHEL activation readiness"

  for version in 2.9 2.10; do
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

run_rhel_activation_key_guard_tests

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
  grep -q "ansible.builtin.yum_repository" "$ROOT_DIR/customizations/examples/rhel-repositories/roles/custom_rhel_repositories/tasks/main.yml" || fail "RHEL repository role does not configure yum repositories"
  grep -q "subscription-manager" "$ROOT_DIR/customizations/examples/rhel-repositories/roles/custom_rhel_repositories/tasks/main.yml" || fail "RHEL repository role does not support subscription-manager repo enablement"
  grep -q "no_log" "$ROOT_DIR/customizations/examples/rhel-repositories/roles/custom_rhel_repositories/tasks/main.yml" || fail "RHEL repository role does not hide repository values"
  grep -q "makecache" "$ROOT_DIR/customizations/examples/rhel-repositories/roles/custom_rhel_repositories/tasks/main.yml" || fail "RHEL repository role does not refresh dnf metadata"
  grep -q "ansible.builtin.package_facts" "$ROOT_DIR/customizations/examples/rhel-repositories/roles/validate_rhel_repositories/tasks/main.yml" || fail "RHEL repository validation role does not inspect installed packages"
  grep -q "rhel_repositories_required_packages" "$ROOT_DIR/customizations/examples/rhel-repositories/roles/validate_rhel_repositories/tasks/main.yml" || fail "RHEL repository validation role does not check required package list"
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

run_source_image_preflight_active_image_tests() {
  # shellcheck source=/dev/null
  source "$ROOT_DIR/scripts/source_images.sh"
  local tmpdir output
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' RETURN
  output="$tmpdir/preflight.out"

  mkdir -p "$tmpdir/bin"
  cat > "$tmpdir/bin/curl" <<'SH'
#!/usr/bin/env bash
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
  esac
  shift
done

case "$url" in
  */api/nutanix/v3/clusters/list)
    body='{"entities":[{"spec":{"name":"test-cluster"},"metadata":{"uuid":"cluster-uuid"}}]}'
    ;;
  */api/nutanix/v3/subnets/list)
    body='{"entities":[{"spec":{"name":"test-subnet"},"metadata":{"uuid":"subnet-uuid"}}]}'
    ;;
  */api/nutanix/v3/images/active-image-uuid)
    body='{"metadata":{"uuid":"active-image-uuid"},"status":{"state":"COMPLETE","resources":{"cluster_reference_list":[],"current_cluster_reference_list":[{"kind":"cluster","uuid":"cluster-uuid"}]}}}'
    ;;
  */api/nutanix/v3/images/inactive-image-uuid)
    body='{"metadata":{"uuid":"inactive-image-uuid"},"status":{"state":"COMPLETE","resources":{"cluster_reference_list":[]}}}'
    ;;
  *)
    body='{"metadata":{"uuid":"unknown"},"status":{"resources":{}}}'
    ;;
esac

if [[ -n "$output_file" ]]; then
  printf '%s' "$body" > "$output_file"
else
  printf '%s' "$body"
fi
printf '200'
SH
  chmod +x "$tmpdir/bin/curl"

  (
    export PATH="$tmpdir/bin:$PATH"
    export PKR_VAR_pc_username=user
    export PKR_VAR_pc_password=password
    export PKR_VAR_pc_ip=pc.example.com
    source_image_preflight \
      --source-image-uuid active-image-uuid \
      --cluster-name test-cluster \
      --subnet-name test-subnet >"$output" 2>&1
  ) || fail "source image preflight rejected active image UUID: $(cat "$output")"

  if (
    export PATH="$tmpdir/bin:$PATH"
    export PKR_VAR_pc_username=user
    export PKR_VAR_pc_password=password
    export PKR_VAR_pc_ip=pc.example.com
    source_image_preflight \
      --source-image-uuid inactive-image-uuid \
      --cluster-name test-cluster \
      --subnet-name test-subnet >"$output" 2>&1
  ); then
    fail "source image preflight unexpectedly accepted inactive image UUID"
  fi
  grep -q "inactive or unavailable on the selected Prism cluster" "$output" || fail "source image preflight inactive image error was not actionable"

  pass "source image preflight active image guard"
}

run_source_image_preflight_active_image_tests

run_source_image_stage_existing_image_tests() {
  # shellcheck source=/dev/null
  source "$ROOT_DIR/scripts/source_images.sh"
  local tmpdir output
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' RETURN
  output="$tmpdir/stage.out"

  mkdir -p "$tmpdir/bin"
  cat > "$tmpdir/bin/curl" <<'SH'
#!/usr/bin/env bash
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
  esac
  shift
done

case "$url" in
  */api/nutanix/v3/images/list)
    body='{"entities":[{"spec":{"name":"active.qcow2"},"metadata":{"uuid":"active-image-uuid"}},{"spec":{"name":"inactive.qcow2"},"metadata":{"uuid":"inactive-image-uuid"}}]}'
    ;;
  */api/nutanix/v3/images/active-image-uuid)
    body='{"metadata":{"uuid":"active-image-uuid"},"status":{"state":"COMPLETE","resources":{"cluster_reference_list":[{"kind":"cluster","uuid":"cluster-uuid"}]}}}'
    ;;
  */api/nutanix/v3/images/inactive-image-uuid)
    body='{"metadata":{"uuid":"inactive-image-uuid"},"status":{"state":"COMPLETE","resources":{"cluster_reference_list":[]}}}'
    ;;
  *)
    body='{"metadata":{"uuid":"new-image-uuid"},"status":{"execution_context":{"task_uuid":"task-uuid"}}}'
    ;;
esac

if [[ -n "$output_file" ]]; then
  printf '%s' "$body" > "$output_file"
else
  printf '%s' "$body"
fi
printf '200'
SH
  chmod +x "$tmpdir/bin/curl"

  (
    export PATH="$tmpdir/bin:$PATH"
    export PKR_VAR_pc_username=user
    export PKR_VAR_pc_password=password
    export PKR_VAR_pc_ip=pc.example.com
    [[ "$(source_image_stage_remote_uri "https://example.com/active.qcow2" "cluster-uuid" "active.qcow2")" == "active.qcow2" ]]
  ) >"$output" 2>&1 || fail "source image staging did not reuse active existing image: $(cat "$output")"
  grep -q "Reusing existing Prism image" "$output" || fail "source image staging did not report active image reuse"

  if (
    export PATH="$tmpdir/bin:$PATH"
    export PKR_VAR_pc_username=user
    export PKR_VAR_pc_password=password
    export PKR_VAR_pc_ip=pc.example.com
    source_image_stage_remote_uri "https://example.com/inactive.qcow2" "cluster-uuid" "inactive.qcow2" >"$output" 2>&1
  ); then
    fail "source image staging unexpectedly reused inactive existing image"
  fi
  grep -q "existing Prism image is inactive" "$output" || fail "source image staging inactive image error was not actionable"

  pass "source image staging existing image guard"
}

run_source_image_stage_existing_image_tests

run_prism_image_activation_helper_tests() {
  local tmpdir output put_payload
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' RETURN
  output="$tmpdir/activate.out"
  put_payload="$tmpdir/put-payload.json"

  "$ROOT_DIR/scripts/prism_image_activate.sh" --help >/dev/null || fail "Prism image activation helper help"

  mkdir -p "$tmpdir/bin"
  cat > "$tmpdir/bin/curl" <<'SH'
#!/usr/bin/env bash
output_file=""
url=""
method=""
payload=""

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
    -d)
      payload=$2
      shift
      ;;
    http*://*)
      url=$1
      ;;
  esac
  shift
done

case "$url" in
  */api/nutanix/v3/clusters/list)
    body='{"entities":[{"spec":{"name":"target-cluster"},"metadata":{"uuid":"cluster-uuid"}}]}'
    ;;
  */api/nutanix/v3/images/inactive-image-uuid)
    if [[ "$method" == "PUT" ]]; then
      printf '%s' "$payload" > "${NDB_SELFTEST_PUT_PAYLOAD:?}"
      body='{"status":{"execution_context":{"task_uuid":"activate-task"}}}'
    else
      body='{"metadata":{"kind":"image","uuid":"inactive-image-uuid","spec_version":2},"spec":{"name":"inactive.qcow2","resources":{"image_type":"DISK_IMAGE","architecture":"X86_64","initial_placement_ref_list":[{"kind":"cluster","uuid":"other-cluster"}]}},"status":{"state":"COMPLETE","resources":{"cluster_reference_list":[]}}}'
    fi
    ;;
  */api/nutanix/v3/tasks/activate-task)
    body='{"status":"SUCCEEDED","percentage_complete":100}'
    ;;
  *)
    body='{}'
    ;;
esac

if [[ -n "$output_file" ]]; then
  printf '%s' "$body" > "$output_file"
else
  printf '%s' "$body"
fi
printf '200'
SH
  chmod +x "$tmpdir/bin/curl"

  (
    export PATH="$tmpdir/bin:$PATH"
    export PKR_VAR_pc_username=user
    export PKR_VAR_pc_password=password
    export PKR_VAR_pc_ip=pc.example.com
    export NDB_SELFTEST_PUT_PAYLOAD="$put_payload"
    "$ROOT_DIR/scripts/prism_image_activate.sh" \
      --image-uuid inactive-image-uuid \
      --cluster-name target-cluster >"$output" 2>&1
  ) || fail "Prism image activation dry-run failed: $(cat "$output")"
  grep -q "Dry run: no Prism changes made" "$output" || fail "Prism image activation helper did not default to dry-run"
  grep -q "inactive.qcow2" "$output" || fail "Prism image activation helper did not identify image"
  [[ ! -e "$put_payload" ]] || fail "Prism image activation helper mutated Prism during dry-run"

  (
    export PATH="$tmpdir/bin:$PATH"
    export PKR_VAR_pc_username=user
    export PKR_VAR_pc_password=password
    export PKR_VAR_pc_ip=pc.example.com
    export NDB_SELFTEST_PUT_PAYLOAD="$put_payload"
    "$ROOT_DIR/scripts/prism_image_activate.sh" \
      --image-uuid inactive-image-uuid \
      --cluster-name target-cluster \
      --apply >"$output" 2>&1
  ) || fail "Prism image activation apply failed: $(cat "$output")"
  grep -q "Activation task completed" "$output" || fail "Prism image activation helper did not wait for task completion"
  jq -e '([.spec.resources.initial_placement_ref_list[].uuid] | sort) == ["cluster-uuid", "other-cluster"]' "$put_payload" >/dev/null || fail "Prism image activation payload did not preserve and add initial placement"
  jq -e '.metadata.uuid == "inactive-image-uuid" and .metadata.spec_version == 2' "$put_payload" >/dev/null || fail "Prism image activation payload did not preserve metadata"

  pass "Prism image activation helper"
}

run_prism_image_activation_helper_tests

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

run_source_image_catalog_tests() {
  local debian_12_image
  debian_12_image=$(jq -r '."debian-12"' "$ROOT_DIR/images.json")

  [[ "$debian_12_image" == *"debian-12-generic-amd64.qcow2" ]] || fail "Debian 12 source image should use the generic image for maximum device compatibility"
  [[ "$debian_12_image" != *"genericcloud"* ]] || fail "Debian 12 source image should not use genericcloud on AHV"

  pass "source image catalog"
}

run_source_image_catalog_tests

run_source_image_ssh_probe_tests() {
  local tmpdir result test_private_key test_public_key
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' RETURN
  result="$tmpdir/result.json"
  test_private_key="$tmpdir/id_rsa"
  test_public_key="$tmpdir/id_rsa.pub"

  printf '%s\n' "selftest-private-key" > "$test_private_key"
  printf '%s\n' "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCselftest packer@selftest" > "$test_public_key"
  chmod 600 "$test_private_key"

  "$ROOT_DIR/scripts/source_image_ssh_probe.sh" --help >/dev/null || fail "source image SSH probe help"
  grep -q -- "--rhel-repository-check" "$ROOT_DIR/scripts/source_image_ssh_probe.sh" || fail "source image SSH probe missing RHEL repository check option"
  grep -q "wait_guest_boot_ready" "$ROOT_DIR/scripts/source_image_ssh_probe.sh" || fail "source image SSH probe does not wait for first-boot system readiness"
  grep -q "/run/dbus/system_bus_socket" "$ROOT_DIR/scripts/source_image_ssh_probe.sh" || fail "source image SSH probe does not wait for D-Bus readiness"
  grep -q -- "--rhel-repository-check" "$ROOT_DIR/README.md" || fail "README does not document source image RHEL repository probe"

  mkdir -p "$tmpdir/bin"
  cat > "$tmpdir/bin/curl" <<'SH'
#!/usr/bin/env bash
  output_file=""
  url=""
  method=""
  payload=""

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
    -d)
      payload=$2
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
  */api/nutanix/v3/images/source-image-uuid)
    body='{"metadata":{"uuid":"source-image-uuid"},"spec":{"name":"source-image"}}'
    ;;
  */api/nutanix/v3/clusters/list)
    body='{"entities":[{"spec":{"name":"mock-cluster"},"metadata":{"uuid":"cluster-uuid"}}]}'
    ;;
  */api/nutanix/v3/subnets/list)
    body='{"entities":[{"spec":{"name":"mock-subnet"},"metadata":{"uuid":"subnet-uuid"}}]}'
    ;;
  */api/nutanix/v3/vms)
    if [[ -n "${NDB_SELFTEST_PAYLOAD_CAPTURE:-}" ]]; then
      printf '%s' "$payload" > "$NDB_SELFTEST_PAYLOAD_CAPTURE"
    fi
    body='{"metadata":{"uuid":"vm-uuid"},"status":{"execution_context":{"task_uuid":"create-task"}}}'
    ;;
  */api/nutanix/v3/tasks/create-task|*/api/nutanix/v3/tasks/power-task|*/api/nutanix/v3/tasks/delete-task)
    body='{"status":"SUCCEEDED","percentage_complete":100}'
    ;;
  */api/nutanix/v3/vms/vm-uuid)
    if [[ "$method" == "DELETE" ]]; then
      touch "${NDB_SELFTEST_DELETE_MARKER:?}"
      body='{"status":{"execution_context":{"task_uuid":"delete-task"}}}'
    elif [[ "$method" == "PUT" ]]; then
      body='{"status":{"execution_context":{"task_uuid":"power-task"}}}'
    else
      body='{"api_version":"3.1","metadata":{"uuid":"vm-uuid","kind":"vm"},"spec":{"name":"vm","resources":{"power_state":"OFF"}},"status":{"resources":{"nic_list":[{"ip_endpoint_list":[{"ip":"192.0.2.20"}]}]}}}'
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
stdin_payload=$(cat || true)
combined_payload="$*
$stdin_payload"
if [[ "$combined_payload" == *"dnf"* ]]; then
  printf '%s\n' "$combined_payload" > "${NDB_SELFTEST_REPO_CHECK_MARKER:?}"
fi
exit 0
SH
  chmod +x "$tmpdir/bin/curl" "$tmpdir/bin/ssh"

  (
    export PATH="$tmpdir/bin:$PATH"
    export PKR_VAR_pc_username=user
    export PKR_VAR_pc_password=password
    export PKR_VAR_pc_ip=pc.example.com
    export PKR_VAR_cluster_name=mock-cluster
    export PKR_VAR_subnet_name=mock-subnet
    export NDB_SOURCE_PROBE_PRIVATE_KEY_PATH="$test_private_key"
    export NDB_SOURCE_PROBE_PUBLIC_KEY_PATH="$test_public_key"
    export NDB_SELFTEST_DELETE_MARKER="$tmpdir/delete-called"
    export NDB_SELFTEST_PAYLOAD_CAPTURE="$tmpdir/create-payload.json"
    "$ROOT_DIR/scripts/source_image_ssh_probe.sh" \
      --source-image-uuid source-image-uuid \
      --result-file "$result" >/dev/null 2>&1
  ) || fail "source image SSH probe success path failed"

  jq -e '.status == "passed" and .source_image_uuid == "source-image-uuid" and .vm_uuid == "vm-uuid" and .vm_ip == "192.0.2.20" and .cleanup.source_image_probe_vm == "deleted"' "$result" >/dev/null || fail "source image SSH probe result JSON"
  jq -e '.spec.resources.boot_config.boot_type == "UEFI"' "$tmpdir/create-payload.json" >/dev/null || fail "source image SSH probe does not default to Packer UEFI boot type"
  [[ -e "$tmpdir/delete-called" ]] || fail "source image SSH probe did not delete VM"

  rm -f "$result" "$tmpdir/delete-called" "$tmpdir/repo-check-command.txt"
  (
    export PATH="$tmpdir/bin:$PATH"
    export PKR_VAR_pc_username=user
    export PKR_VAR_pc_password=password
    export PKR_VAR_pc_ip=pc.example.com
    export PKR_VAR_cluster_name=mock-cluster
    export PKR_VAR_subnet_name=mock-subnet
    export NDB_SOURCE_PROBE_PRIVATE_KEY_PATH="$test_private_key"
    export NDB_SOURCE_PROBE_PUBLIC_KEY_PATH="$test_public_key"
    export NDB_SELFTEST_DELETE_MARKER="$tmpdir/delete-called"
    export NDB_SELFTEST_PAYLOAD_CAPTURE="$tmpdir/create-payload.json"
    export NDB_SELFTEST_REPO_CHECK_MARKER="$tmpdir/repo-check-command.txt"
    export NDB_RHEL_ORGID=selftest-org
    export NDB_RHEL_ACTIVATIONKEY=selftest-activation-key
    "$ROOT_DIR/scripts/source_image_ssh_probe.sh" \
      --source-image-uuid source-image-uuid \
      --rhel-repository-check \
      --rhel-repository-packages bison,gcc \
      --result-file "$result" >/dev/null 2>&1
  ) || fail "source image RHEL repository probe success path failed"
  grep -q 'subscription-manager register --org="$rhel_org_id" --activationkey="$rhel_activation_key"' "$tmpdir/repo-check-command.txt" || fail "source image RHEL repository probe did not register with activation key"
  grep -q "dnf -y install bison gcc" "$tmpdir/repo-check-command.txt" || fail "source image RHEL repository probe did not install requested packages"
  grep -q "subscription-manager unregister" "$tmpdir/repo-check-command.txt" || fail "source image RHEL repository probe did not unregister after package check"
  grep -q "subscription-manager clean" "$tmpdir/repo-check-command.txt" || fail "source image RHEL repository probe did not clean after package check"
  jq -e '.status == "passed" and .checks.rhel_repositories == "passed"' "$result" >/dev/null || fail "source image RHEL repository probe result JSON"

  pass "source image SSH probe"
}

run_source_image_ssh_probe_tests

run_rhel_readiness_helper_tests() {
  local tmpdir output status
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' RETURN
  output="$tmpdir/rhel-readiness.out"

  "$ROOT_DIR/scripts/rhel_readiness.sh" --help >/dev/null || fail "RHEL readiness helper help"

  status=0
  (
    unset NDB_RHEL_9_6_IMAGE_URI NDB_RHEL_9_7_IMAGE_URI RHEL_96_UUID RHEL_97_UUID
    "$ROOT_DIR/scripts/rhel_readiness.sh" >"$output" 2>&1
  ) || status=$?
  [[ "$status" -eq 1 ]] || fail "RHEL readiness helper should fail when RHEL inputs are missing"
  grep -q "RHEL source URI readiness: incomplete" "$output" || fail "RHEL readiness helper did not report missing URI readiness"
  grep -q "NDB_RHEL_9_6_IMAGE_URI=missing" "$output" || fail "RHEL readiness helper did not report missing RHEL 9.6 URI"
  grep -q "RHEL staged image UUID readiness: incomplete" "$output" || fail "RHEL readiness helper did not report missing staged UUID readiness"
  grep -q "RHEL_97_UUID=missing" "$output" || fail "RHEL readiness helper did not report missing RHEL 9.7 UUID"

  (
    export NDB_RHEL_9_6_IMAGE_URI=/private/rhel-9.6.qcow2
    export NDB_RHEL_9_7_IMAGE_URI=/private/rhel-9.7.qcow2
    unset RHEL_96_UUID RHEL_97_UUID
    "$ROOT_DIR/scripts/rhel_readiness.sh" >"$output" 2>&1
  ) || fail "RHEL readiness helper should pass when licensed URI inputs are set"
  grep -q "RHEL source URI readiness: complete" "$output" || fail "RHEL readiness helper did not report complete URI readiness"
  ! grep -q "/private/rhel" "$output" || fail "RHEL readiness helper printed source image URI values"
  grep -q -- './test.sh --allow-rhel --include-os "Red Hat Enterprise Linux (RHEL)" --preflight --max-parallel 1' "$output" || fail "RHEL readiness helper did not print URI preflight command"

  (
    unset NDB_RHEL_9_6_IMAGE_URI NDB_RHEL_9_7_IMAGE_URI
    export RHEL_96_UUID=00000000-0000-0000-0000-000000000000
    export RHEL_97_UUID=11111111-1111-1111-1111-111111111111
    "$ROOT_DIR/scripts/rhel_readiness.sh" >"$output" 2>&1
  ) || fail "RHEL readiness helper should pass when staged UUID inputs are set"
  grep -q "RHEL staged image UUID readiness: complete" "$output" || fail "RHEL readiness helper did not report complete UUID readiness"
  grep -q 'rhel-9.6=${RHEL_96_UUID},rhel-9.7=${RHEL_97_UUID}' "$output" || fail "RHEL readiness helper did not print staged UUID map command"
  ! grep -q "00000000-0000-0000-0000-000000000000" "$output" || fail "RHEL readiness helper printed staged UUID values"

  mkdir -p "$tmpdir/bin"
  cat > "$tmpdir/bin/curl" <<'SH'
#!/usr/bin/env bash
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
  esac
  shift
done

case "$url" in
  */api/nutanix/v3/images/list)
    body='{"entities":[{"spec":{"name":"rhel-9.7-source"},"metadata":{"uuid":"uuid-97"}},{"spec":{"name":"rhel-9.6-source"},"metadata":{"uuid":"uuid-96"}},{"spec":{"name":"ubuntu-24.04-source"},"metadata":{"uuid":"uuid-ubuntu"}}]}'
    ;;
  */api/nutanix/v3/images/uuid-97)
    body='{"metadata":{"uuid":"uuid-97"},"spec":{"name":"rhel-9.7-source"},"status":{"state":"COMPLETE","resources":{"current_cluster_reference_list":[{"kind":"cluster","uuid":"cluster-uuid"}]}}}'
    ;;
  */api/nutanix/v3/images/uuid-96)
    body='{"metadata":{"uuid":"uuid-96"},"spec":{"name":"rhel-9.6-source"},"status":{"state":"COMPLETE","resources":{"current_cluster_reference_list":[]}}}'
    ;;
  *)
    body='{}'
    ;;
esac
if [[ -n "$output_file" ]]; then
  printf '%s' "$body" > "$output_file"
else
  printf '%s' "$body"
fi
printf '200'
SH
  chmod +x "$tmpdir/bin/curl"

  status=0
  (
    export PATH="$tmpdir/bin:$PATH"
    export PKR_VAR_pc_username=user
    export PKR_VAR_pc_password=password
    export PKR_VAR_pc_ip=pc.example.com
    unset NDB_RHEL_9_6_IMAGE_URI NDB_RHEL_9_7_IMAGE_URI RHEL_96_UUID RHEL_97_UUID
    "$ROOT_DIR/scripts/rhel_readiness.sh" --scan-prism --show-prism-matches >"$output" 2>&1
  ) || status=$?
  [[ "$status" -eq 1 ]] || fail "RHEL readiness helper should still fail when scan finds candidates but no chosen inputs are set"
  grep -q "Staged RHEL-like Prism images: 2" "$output" || fail "RHEL readiness helper did not count Prism RHEL matches"
  grep -q "Active RHEL-like Prism images: 1" "$output" || fail "RHEL readiness helper did not count active Prism RHEL matches"
  grep -q "uuid-97" "$output" || fail "RHEL readiness helper did not print Prism match UUID when requested"
  grep -q "rhel-9.7-source" "$output" || fail "RHEL readiness helper did not print Prism match name when requested"
  grep -q "rhel-9.6-source" "$output" || fail "RHEL readiness helper did not print inactive Prism match name when requested"
  grep -q "active" "$output" || fail "RHEL readiness helper did not flag active Prism match availability"
  grep -q "inactive" "$output" || fail "RHEL readiness helper did not flag Prism match availability"

  pass "RHEL readiness helper"
}

run_rhel_readiness_helper_tests

run_packer_builder_timeout_tests() {
  grep -q 'version[[:space:]]*=[[:space:]]*"~> 1.0.0"' "$ROOT_DIR/packer/database.pkr.hcl" || fail "Packer Nutanix plugin should use the live-proven 1.0.x line"
  grep -q 'variable "ssh_timeout"' "$ROOT_DIR/packer/variables.pkr.hcl" || fail "Packer variables do not define ssh_timeout"
  grep -q 'ssh_timeout[[:space:]]*=[[:space:]]*var.ssh_timeout' "$ROOT_DIR/packer/database.pkr.hcl" || fail "Packer builder does not set ssh_timeout"
  grep -q 'default[[:space:]]*=[[:space:]]*"10m"' "$ROOT_DIR/packer/variables.pkr.hcl" || fail "Packer ssh_timeout should default to 10m"
  grep -q 'variable "boot_type"' "$ROOT_DIR/packer/variables.pkr.hcl" || fail "Packer variables do not define boot_type"
  grep -q 'boot_type[[:space:]]*=[[:space:]]*var.boot_type' "$ROOT_DIR/packer/database.pkr.hcl" || fail "Packer builder does not set boot_type from a variable"
  grep -q 'default[[:space:]]*=[[:space:]]*"uefi"' "$ROOT_DIR/packer/variables.pkr.hcl" || fail "Packer boot_type should default to current uefi behavior"
  grep -q 'variable "boot_priority"' "$ROOT_DIR/packer/variables.pkr.hcl" || fail "Packer variables do not define boot_priority"
  grep -q 'boot_priority[[:space:]]*=[[:space:]]*var.boot_priority' "$ROOT_DIR/packer/database.pkr.hcl" || fail "Packer builder does not set boot_priority from a variable"
  grep -q 'default[[:space:]]*=[[:space:]]*"disk"' "$ROOT_DIR/packer/variables.pkr.hcl" || fail "Packer boot_priority should default to disk for cloud images"
  grep -q 'variable "serialport"' "$ROOT_DIR/packer/variables.pkr.hcl" || fail "Packer variables do not define serialport"
  grep -q 'serialport[[:space:]]*=[[:space:]]*var.serialport' "$ROOT_DIR/packer/database.pkr.hcl" || fail "Packer builder does not set serialport from a variable"
  grep -q 'default[[:space:]]*=[[:space:]]*true' "$ROOT_DIR/packer/variables.pkr.hcl" || fail "Packer serialport should default to true for Linux cloud images"

  pass "Packer builder SSH timeout guard"
}

run_packer_builder_timeout_tests

run_packer_cloud_init_tests() {
  grep -q "name: packer" "$ROOT_DIR/packer/http/user-data" || fail "Packer cloud-init user data does not create packer user"
  grep -q "NOPASSWD:ALL" "$ROOT_DIR/packer/http/user-data" || fail "Packer cloud-init user data does not grant passwordless sudo"
  grep -q "openssh-server" "$ROOT_DIR/packer/http/user-data" || fail "Packer cloud-init user data does not install openssh-server"
  ! grep -q "groups:.*admin" "$ROOT_DIR/packer/http/user-data" || fail "Packer cloud-init user data uses non-portable admin group"

  pass "Packer cloud-init user data guard"
}

run_packer_cloud_init_tests

run_ndb_e2e_cloud_init_tests() {
  grep -q "packer/http/e2e-user-data" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E runner must default to the offline-safe source VM cloud-init template"
  grep -q "NDB_E2E_USER_DATA_TEMPLATE" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E runner must keep a user-data template override"
  grep -q "name: packer" "$ROOT_DIR/packer/http/e2e-user-data" || fail "NDB E2E cloud-init user data does not create packer user"
  grep -q "NOPASSWD:ALL" "$ROOT_DIR/packer/http/e2e-user-data" || fail "NDB E2E cloud-init user data does not grant passwordless sudo"
  grep -q "systemctl start ssh" "$ROOT_DIR/packer/http/e2e-user-data" || fail "NDB E2E cloud-init user data does not start SSH"
  ! grep -q "package_update" "$ROOT_DIR/packer/http/e2e-user-data" || fail "NDB E2E cloud-init user data must not run package updates"
  ! grep -q "apt-get update" "$ROOT_DIR/packer/http/e2e-user-data" || fail "NDB E2E cloud-init user data must not depend on apt repositories"
  ! grep -q "yum install" "$ROOT_DIR/packer/http/e2e-user-data" || fail "NDB E2E cloud-init user data must not depend on yum repositories"
  ! grep -q "dnf install" "$ROOT_DIR/packer/http/e2e-user-data" || fail "NDB E2E cloud-init user data must not depend on dnf repositories"

  pass "NDB E2E offline-safe cloud-init guard"
}

run_ndb_e2e_cloud_init_tests

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
  jq -e '.validation.in_guest == "not-requested" and .validation.artifact == "not-requested" and .validation.artifact_vm_ip == null and (.cleanup | type) == "object"' "$manifest" >/dev/null || fail "manifest default status JSON"

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

  printf '%s\n' '{"status":"passed","artifact_vm_name":"validate-test","artifact_vm_uuid":"vm-uuid-1","artifact_vm_ip":"192.0.2.10","cleanup":{"artifact_validation_vm":"deleted"}}' > "$tmpdir/artifact-result.json"
  "$ROOT_DIR/scripts/manifest.sh" record-artifact-validation \
    --file "$manifest" \
    --result-file "$tmpdir/artifact-result.json" \
    --exit-status 0

  jq -e '.validation.artifact == "passed" and .validation.artifact_vm_name == "validate-test" and .validation.artifact_vm_uuid == "vm-uuid-1" and .validation.artifact_vm_ip == "192.0.2.10" and .cleanup.artifact_validation_vm == "deleted"' "$manifest" >/dev/null || fail "manifest artifact validation result JSON"

  printf '%s\n' '{"status":"passed","artifact_vm_name":"validate-interrupted","artifact_vm_uuid":"vm-uuid-interrupted","artifact_vm_ip":"192.0.2.11","cleanup":{"artifact_validation_vm":"deleted"}}' > "$tmpdir/artifact-interrupted-result.json"
  "$ROOT_DIR/scripts/manifest.sh" record-artifact-validation \
    --file "$manifest" \
    --result-file "$tmpdir/artifact-interrupted-result.json" \
    --exit-status 143

  jq -e '.validation.artifact == "failed" and .validation.artifact_vm_name == "validate-interrupted" and .validation.artifact_vm_uuid == "vm-uuid-interrupted" and .validation.artifact_vm_ip == "192.0.2.11" and .cleanup.artifact_validation_vm == "deleted"' "$manifest" >/dev/null || fail "manifest interrupted artifact validation must not pass"

  printf '' > "$tmpdir/empty-artifact-result.json"
  "$ROOT_DIR/scripts/manifest.sh" record-artifact-validation \
    --file "$manifest" \
    --result-file "$tmpdir/empty-artifact-result.json" \
    --exit-status 7

  jq -e '.validation.artifact == "failed" and .validation.artifact_vm_ip == "" and .cleanup.artifact_validation_vm == "result-unavailable"' "$manifest" >/dev/null || fail "manifest empty artifact result fallback"

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

run_live_coverage_audit_tests() {
  local tmpdir manifest_dir output matrix_file
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' RETURN
  manifest_dir="$tmpdir/manifests"
  matrix_file="$tmpdir/matrix.json"
  output="$tmpdir/coverage.out"
  mkdir -p "$manifest_dir"

  cat > "$matrix_file" <<'JSON'
[
  {
    "ndb_version": "9.99",
    "engine": "PostgreSQL Community Edition",
    "db_type": "pgsql",
    "os_type": "Rocky Linux",
    "os_version": "9.9",
    "db_version": "16",
    "provisioning_role": "postgresql"
  },
  {
    "ndb_version": "9.99",
    "engine": "PostgreSQL Community Edition",
    "db_type": "pgsql",
    "os_type": "Debian",
    "os_version": "12",
    "db_version": "18",
    "provisioning_role": "postgresql"
  },
  {
    "ndb_version": "9.99",
    "engine": "MongoDB",
    "db_type": "mongodb",
    "os_type": "Ubuntu Linux",
    "os_version": "22.04",
    "db_version": "8.0",
    "provisioning_role": "mongodb"
  },
  {
    "ndb_version": "9.99",
    "engine": "Metadata Only",
    "db_type": "oracle",
    "os_type": "Rocky Linux",
    "os_version": "9.9",
    "db_version": "23ai",
    "provisioning_role": "metadata"
  }
]
JSON

  cat > "$manifest_dir/rocky.json" <<'JSON'
{
  "status": "success",
  "selection": {
    "ndb_version": "9.99",
    "db_type": "pgsql",
    "os_type": "Rocky Linux",
    "os_version": "9.9",
    "db_version": "16"
  },
  "validation": {
    "in_guest": "passed",
    "artifact": "passed"
  },
  "cleanup": {
    "artifact_validation_vm": "deleted"
  }
}
JSON

  cat > "$manifest_dir/mongodb.json" <<'JSON'
{
  "status": "success",
  "selection": {
    "ndb_version": "9.99",
    "db_type": "mongodb",
    "os_type": "Ubuntu Linux",
    "os_version": "22.04",
    "db_version": "8.0"
  },
  "validation": {
    "in_guest": "passed",
    "artifact": "passed"
  },
  "cleanup": {
    "artifact_validation_vm": "deleted"
  }
}
JSON

  if "$ROOT_DIR/scripts/live_coverage_audit.sh" --manifest-dir "$manifest_dir" "$matrix_file" >"$output" 2>&1; then
    fail "live coverage audit unexpectedly passed with missing Debian row"
  fi

  grep -q "Buildable rows: 3" "$output" || fail "coverage audit did not count buildable rows"
  grep -q "Successful live rows: 2" "$output" || fail "coverage audit did not count successful rows"
  grep -q "Missing live rows: 1" "$output" || fail "coverage audit did not count missing rows"
  grep -q $'9.99\tpgsql\tDebian\t12\t18' "$output" || fail "coverage audit did not list missing Debian row"
  ! grep -q "oracle" "$output" || fail "coverage audit included metadata-only row"

  if "$ROOT_DIR/scripts/live_coverage_audit.sh" --suggest-runs --manifest-dir "$manifest_dir" "$matrix_file" >"$output" 2>&1; then
    fail "live coverage audit suggestions unexpectedly passed with missing Debian row"
  fi
  grep -q "Suggested commands for missing rows:" "$output" || fail "coverage audit suggestions missing heading"
  grep -q -- "./build.sh --ci --validate --validate-artifact --manifest --ndb-version 9.99 --db-type pgsql --os Debian --os-version 12 --db-version 18" "$output" || fail "coverage audit suggestions missing Debian build command"

  if "$ROOT_DIR/scripts/live_coverage_audit.sh" --suggest-runs --source-image-uuid-map "debian-12=debian-uuid" --manifest-dir "$manifest_dir" "$matrix_file" >"$output" 2>&1; then
    fail "live coverage audit UUID suggestions unexpectedly passed with missing Debian row"
  fi
  grep -q -- "./build.sh --ci --validate --validate-artifact --manifest --ndb-version 9.99 --db-type pgsql --os Debian --os-version 12 --db-version 18 --source-image-uuid debian-uuid" "$output" || fail "coverage audit suggestions missing source image UUID"

  if "$ROOT_DIR/scripts/live_coverage_audit.sh" --suggest-runs --customization-profile customizations/local/rhel-repositories.yml --source-image-uuid-map "debian-12=debian-uuid" --manifest-dir "$manifest_dir" "$matrix_file" >"$output" 2>&1; then
    fail "live coverage audit customization suggestions unexpectedly passed with missing Debian row"
  fi
  grep -q -- "./build.sh --ci --validate --validate-artifact --manifest --ndb-version 9.99 --db-type pgsql --os Debian --os-version 12 --db-version 18 --customization-profile customizations/local/rhel-repositories.yml --source-image-uuid debian-uuid" "$output" || fail "coverage audit suggestions missing customization profile"

  cat > "$manifest_dir/debian.json" <<'JSON'
{
  "status": "success",
  "selection": {
    "ndb_version": "9.99",
    "db_type": "pgsql",
    "os_type": "Debian",
    "os_version": "12",
    "db_version": "18"
  },
  "validation": {
    "in_guest": "passed",
    "artifact": "passed"
  },
  "cleanup": {
    "artifact_validation_vm": "deleted"
  }
}
JSON

  "$ROOT_DIR/scripts/live_coverage_audit.sh" --manifest-dir "$manifest_dir" "$matrix_file" >"$output" 2>&1 || fail "coverage audit failed after all rows were covered: $(cat "$output")"
  grep -q "Missing live rows: 0" "$output" || fail "coverage audit did not report full coverage"

  pass "live coverage audit"
}

run_live_coverage_audit_tests

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

  if "$ROOT_DIR/scripts/artifact_validate.sh" --help > "$tmpdir/artifact-help.txt"; then
    grep -q "NDB_ARTIFACT_SSH_MAX_POLLS" "$tmpdir/artifact-help.txt" || fail "artifact validation help missing SSH max polls"
    grep -q "NDB_ARTIFACT_SSH_POLL_SECONDS" "$tmpdir/artifact-help.txt" || fail "artifact validation help missing SSH poll seconds"
    pass "artifact validation help"
  else
    fail "artifact validation help"
  fi

  grep -q -- "--customization-profile-file" "$ROOT_DIR/scripts/artifact_validate.sh" || fail "artifact validation missing customization profile file flag"
  grep -q -- "--postgres-ha-components" "$ROOT_DIR/scripts/artifact_validate.sh" || fail "artifact validation missing PostgreSQL HA components flag"
  grep -q "wait_guest_boot_ready" "$ROOT_DIR/scripts/artifact_validate.sh" || fail "artifact validation does not wait for first-boot system readiness"
  grep -q "/run/dbus/system_bus_socket" "$ROOT_DIR/scripts/artifact_validate.sh" || fail "artifact validation does not wait for D-Bus readiness"
  grep -q "NDB_ARTIFACT_USER_DATA_TEMPLATE" "$ROOT_DIR/scripts/artifact_validate.sh" || fail "artifact validation missing user-data template override"
  grep -q "packer/http/e2e-user-data" "$ROOT_DIR/scripts/artifact_validate.sh" || fail "artifact validation must default to offline-safe saved-image cloud-init"
  grep -q "validate_custom_enterprise" "$ROOT_DIR/customizations/examples/enterprise-validation/roles/validate_custom_enterprise/tasks/main.yml" || fail "missing enterprise validation role marker"

  mkdir -p "$tmpdir/bin"
  cat > "$tmpdir/bin/curl" <<'SH'
#!/usr/bin/env bash
output_file=""
url=""
method=""
payload=""

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
    -d)
      payload=$2
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
    if [[ -n "${NDB_SELFTEST_PAYLOAD_CAPTURE:-}" ]]; then
      printf '%s' "$payload" > "$NDB_SELFTEST_PAYLOAD_CAPTURE"
    fi
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
    export NDB_SELFTEST_VARS_CAPTURE="$tmpdir/postgres-vars.json"
    export NDB_SELFTEST_PAYLOAD_CAPTURE="$tmpdir/artifact-create-payload.json"
    if "$ROOT_DIR/scripts/artifact_validate.sh" \
      --image-name test-image \
      --ndb-version 2.10 \
      --db-version 18 \
      --provisioning-role postgresql \
      --postgres-ha-components '{"patroni":["4.0.5"],"etcd":["3.5.12"]}' \
      --postgres-qualified-version-range "18.0" \
      --postgres-package-version-prefix "18.0" \
      --postgres-package-use-archive true \
      --mongodb-edition community \
      --mongodb-deployments '[]' \
      --result-file "$success_result" >/dev/null 2>&1; then
      :
    else
      fail "artifact validation success path unexpectedly failed"
    fi
  )

  grep -q "validate_postgres" "$tmpdir/postgres-validate.yml" || fail "PostgreSQL artifact validation did not dispatch validate_postgres"
  jq -e '.postgres_ha_components.patroni == ["4.0.5"] and .postgres_ha_components.etcd == ["3.5.12"]' "$tmpdir/postgres-vars.json" >/dev/null || fail "PostgreSQL artifact validation omitted HA component vars"
  jq -e '.postgres_qualified_version_range == "18.0" and .postgres_package_version_prefix == "18.0" and .postgres_package_use_archive == true' "$tmpdir/postgres-vars.json" >/dev/null || fail "PostgreSQL artifact validation omitted package pin vars"
  jq -e '.spec.resources.boot_config.boot_type == "UEFI" and .spec.resources.boot_config.boot_device_order_list == ["DISK","CDROM","NETWORK"] and .spec.resources.serial_port_list == [{"index":0,"is_connected":true}]' "$tmpdir/artifact-create-payload.json" >/dev/null || fail "artifact validation VM payload does not set UEFI disk-first serial console shape"
  jq -e '.status == "passed" and .cleanup_status == "deleted" and .artifact_vm_name != "" and .artifact_vm_uuid == "vm-uuid" and .artifact_vm_ip == "192.0.2.10" and .vm_ip == "192.0.2.10" and .cleanup.artifact_validation_vm == "deleted"' "$success_result" >/dev/null || fail "artifact validation success result JSON"
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

run_ndb_e2e_validate_static_tests() {
  bash -n "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E validation runner has shell syntax errors"
  bash "$ROOT_DIR/scripts/ndb_e2e_validate.sh" --help >/dev/null || fail "NDB E2E validation runner help failed"

  grep -q "NDB_E2E_EVIDENCE_FILE" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E runner missing configurable evidence file"
  grep -q "join(\"|\")" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E runner must preserve empty target fields with a non-whitespace delimiter"
  grep -q "IFS='|'" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E runner must read target rows with the non-whitespace delimiter"
  grep -q "mongodb_edition" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E runner must carry MongoDB edition metadata"
  grep -q "deployment" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E runner must carry MongoDB deployment metadata"
  grep -q "psql_path" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E runner must preserve OS-specific PostgreSQL client paths"
  grep -Fq "current_database() || '|'" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E runner must record PostgreSQL database name and version in one smoke-check result"
  grep -q "software_profile_name" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E runner evidence must include software profile names"
  grep -q "row_already_passed" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E runner must skip already-passed rows for resumable full runs"
  grep -q "validate_row_filter_exists" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E runner must fail clearly when a row-id filter matches no generated target"
  grep -q -- "--row-id did not match any generated E2E target" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E runner missing clear unmatched row-id error"
  grep -q -- "--rerun-passed" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E runner missing rerun-passed override"
  grep -q "register-dbserver-operation.json" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E runner must wait for async DB server registration"
  grep -q "NDB_E2E_MONGODB_SOFTWARE_HOME" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E runner must support MongoDB software-home override"
  grep -q "/opt/ndb/mongodb" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E runner must use an NDB-safe MongoDB software home outside /usr"
  grep -q "mongodump" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E runner must verify mongodump under MongoDB software home"
  grep -q "resolve_image_uuid" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E runner must resolve stale manifest image UUIDs by name"
  grep -q "network_profile_id_for" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E runner must choose network profiles per database engine"
  grep -q "NDB_E2E_MONGODB_NETWORK_PROFILE_ID" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E runner must support MongoDB network profile override"
  grep -q "NDB_E2E_OPERATION_STALL_POLLS" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E runner must support stalled-operation detection"
  grep -q "NDB_E2E_NDB_API_TIMEOUT" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E runner must support configurable NDB API timeouts"
  grep -q "NDB_E2E_SOURCE_VM_MAX_ATTEMPTS" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E runner must support source VM readiness retries"
  grep -q "NDB_E2E_SSH_MAX_POLLS" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E runner must support configurable SSH polling"
  grep -q "NDB_E2E_GUEST_READY_MAX_POLLS" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E runner must support configurable guest readiness polling"
  grep -q "packer/http/e2e-user-data" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E runner must use offline-safe source VM cloud-init by default"
  grep -q "NDB_E2E_TARGET_OBSERVER" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E runner must support target observer diagnostics"
  grep -q "NDB_E2E_TARGET_OBSERVER_INTERVAL_SECONDS" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E runner must support configurable target observer interval"
  grep -q "NDB_E2E_TARGET_OBSERVER_MAX_SECONDS" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E runner must support configurable target observer max duration"
  grep -q "target_observer_start" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E runner missing target observer start hook"
  grep -q "target_observer_stop" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E runner missing target observer stop hook"
  grep -q "target_observer_prism_ips" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E target observer must discover target IPs from Prism when NDB omits them"
  grep -q "prism-vms" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E target observer must save Prism VM snapshots"
  grep -q "target-observer" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E runner must write observer evidence under target-observer"
  grep -q "ansible_(ssh|sudo)_pass" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E target observer must redact Ansible password arguments"
  grep -q "DB_PASSWORD|DB_PASS|db_password|db_pass" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E target observer must redact database password command arguments"
  grep -q "candidate_logs" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E target observer must capture nested driver log candidates"
  grep -q "grep -v '/opt/era_base/logs/monitoring/'" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E target observer must skip noisy monitoring logs"
  grep -q "delete_disposable_vm" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E runner must clean up failed source VM retry attempts"
  grep -q -- "--argjson delete_vm_on_failure" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E runner must send delete_vm_on_failure as a JSON boolean"
  grep -q "operationId" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E runner must reject provision responses without operation IDs"
  grep -q "preflight_target_images" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E runner must preflight selected Prism image availability"
  grep -q -- "--preflight-images" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E runner missing image preflight flag"
  grep -q "wait_guest_boot_ready" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E runner does not wait for first-boot system readiness"
  grep -q "/run/dbus/system_bus_socket" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E runner does not wait for D-Bus readiness"
  grep -q "cloud-init status" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E runner does not wait for cloud-init readiness"
  grep -q "Full NDB Provisioning E2E" "$ROOT_DIR/README.md" || fail "README missing full NDB provisioning E2E guidance"
  grep -q "scripts/ndb_e2e_validate.sh --db-type pgsql --limit 1" "$ROOT_DIR/README.md" || fail "README missing PostgreSQL E2E smoke command"
  grep -q "scripts/ndb_e2e_validate.sh --db-type mongodb --limit 1" "$ROOT_DIR/README.md" || fail "README missing MongoDB E2E smoke command"
  grep -q "database together with its Time Machine/protection workflow" "$ROOT_DIR/README.md" || fail "README must explain that NDB provisioning includes Time Machine/protection workflow"
  grep -q "NDB_E2E_SOURCE_VM_MAX_ATTEMPTS" "$ROOT_DIR/README.md" || fail "README missing source VM retry override"
  grep -q "NDB_E2E_SSH_MAX_POLLS" "$ROOT_DIR/README.md" || fail "README missing SSH polling override"
  grep -q "NDB_E2E_DELETE_VM_ON_FAILURE" "$ROOT_DIR/README.md" || fail "README missing failed target VM preservation override"
  grep -q "NDB_E2E_NDB_API_TIMEOUT" "$ROOT_DIR/README.md" || fail "README missing NDB API timeout override"
  grep -q "NDB_E2E_TARGET_OBSERVER" "$ROOT_DIR/README.md" || fail "README missing target observer override"
  grep -q "NDB_E2E_TARGET_OBSERVER_INTERVAL_SECONDS" "$ROOT_DIR/README.md" || fail "README missing target observer interval override"
  grep -q "NDB_E2E_TARGET_OBSERVER_MAX_SECONDS" "$ROOT_DIR/README.md" || fail "README missing target observer max-duration override"
  grep -q "target-observer" "$ROOT_DIR/README.md" || fail "README missing target observer output directory guidance"
  grep -q "offline-safe E2E cloud-init" "$ROOT_DIR/README.md" || fail "README missing offline-safe E2E cloud-init guidance"

  pass "NDB E2E validation runner static guards"
}

run_ndb_e2e_validate_static_tests

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
    "postgres_qualified_version_range": "16.9 - 16.12",
    "postgres_package_version_prefix": "16.12",
    "postgres_package_use_archive": true,
    "provisioning_role": "postgresql",
    "qualified_extensions": ["pgvector", "postgis"],
    "ha_components": {
      "patroni": ["4.0.5"],
      "etcd": ["3.5.12"]
    }
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
  grep -Fq "HA profile components: patroni 4.0.5, etcd 3.5.12" "$output" || fail "wizard did not show PostgreSQL HA components"
  grep -Fq "Qualified PostgreSQL version range: 16.9 - 16.12" "$output" || fail "wizard did not show PostgreSQL qualified version range"
  grep -Fq "PostgreSQL package pin: 16.12 via PGDG archive" "$output" || fail "wizard did not show PostgreSQL package pin"
  grep -Fq "Qualified extensions: pgvector, postgis" "$output" || fail "wizard did not show PostgreSQL qualified extension list"
  grep -Fq "Selected extensions: none" "$output" || fail "wizard default did not select no extensions"
  grep -Fq "Image name suffix: ha-pg16-12" "$output" || fail "wizard default did not preview HA and package-pin image suffix"
  grep -Fq "./build.sh --ci --dry-run --ndb-version 9.99 --db-type pgsql --os 'Rocky Linux' --os-version 9.9 --db-version 16" "$output" || fail "wizard dry-run command mismatch"
  ! grep -Fq "Metadata Only" "$output" || fail "wizard exposed metadata-only rows"

  (
    cd "$tmpdir"
    printf '1\n1\n1\n1\n1\n1 3\n1\n1\n1\n' | "$wizard" >"$output" 2>&1
  ) || fail "wizard individual PostgreSQL extension selection failed"
  grep -Fq "Selected extensions: pgvector, pg_cron" "$output" || fail "wizard did not show selected extensions"
  grep -Fq "Image name suffix: ha-pg16-12-ext-pg-cron-pgvector" "$output" || fail "wizard did not preview HA package-pin extension image name suffix"
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
  grep -Fq "PostgreSQL package pin: 16.12 via PGDG archive" "$output" || fail "wizard build preview did not show PostgreSQL package pin"

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
  cp "$ROOT_DIR/scripts/source_images.sh" "$tmpdir/scripts/source_images.sh"
  cp "$ROOT_DIR/scripts/prism.sh" "$tmpdir/scripts/prism.sh"

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
  cp "$ROOT_DIR/scripts/source_images.sh" "$tmpdir/scripts/source_images.sh"
  cp "$ROOT_DIR/scripts/prism.sh" "$tmpdir/scripts/prism.sh"

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
  cp "$ROOT_DIR/scripts/source_images.sh" "$tmpdir/scripts/source_images.sh"
  cp "$ROOT_DIR/scripts/prism.sh" "$tmpdir/scripts/prism.sh"

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
  cp "$ROOT_DIR/scripts/source_images.sh" "$tmpdir/scripts/source_images.sh"
  cp "$ROOT_DIR/scripts/prism.sh" "$tmpdir/scripts/prism.sh"

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

run_test_harness_source_image_uuid_map_tests() {
  local tmpdir build_log
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' RETURN
  build_log="$tmpdir/builds.log"

  mkdir -p "$tmpdir/ndb/9.99" "$tmpdir/scripts"
  cp "$ROOT_DIR/test.sh" "$tmpdir/test.sh"
  cp "$ROOT_DIR/scripts/postgres_extensions.sh" "$tmpdir/scripts/postgres_extensions.sh"
  cp "$ROOT_DIR/scripts/source_images.sh" "$tmpdir/scripts/source_images.sh"
  cp "$ROOT_DIR/scripts/prism.sh" "$tmpdir/scripts/prism.sh"

  cat > "$tmpdir/ndb/9.99/matrix.json" <<'JSON'
[
  {
    "ndb_version": "9.99",
    "engine": "MongoDB",
    "db_type": "mongodb",
    "os_type": "Rocky Linux",
    "os_version": "9.7",
    "db_version": "1",
    "provisioning_role": "mongodb",
    "mongodb_edition": "community",
    "deployment": ["single-instance"]
  },
  {
    "ndb_version": "9.99",
    "engine": "MongoDB",
    "db_type": "mongodb",
    "os_type": "Ubuntu Linux",
    "os_version": "22.04",
    "db_version": "2",
    "provisioning_role": "mongodb",
    "mongodb_edition": "community",
    "deployment": ["single-instance"]
  }
]
JSON

  cat > "$tmpdir/build.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
db_version=""
source_image_uuid=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --db-version)
      db_version=$2
      shift
      ;;
    --source-image-uuid)
      source_image_uuid=$2
      shift
      ;;
  esac
  shift
done
printf '%s|%s\n' "$db_version" "$source_image_uuid" >> "${NDB_SELFTEST_BUILD_LOG:?}"
SH
  chmod +x "$tmpdir/test.sh" "$tmpdir/build.sh"

  (
    cd "$tmpdir"
    SKIP_MATRIX_VALIDATION=true NDB_SELFTEST_BUILD_LOG="$build_log" ./test.sh --include-ndb 9.99 --include-db-type mongodb --source-image-uuid-map rocky-linux-9.7=rocky-uuid,ubuntu-linux-22.04=ubuntu-uuid --max-parallel 1 >/dev/null 2>&1
  ) || fail "test harness source image UUID map run failed"

  [[ "$(cat "$build_log")" == $'1|rocky-uuid\n2|ubuntu-uuid' ]] || fail "test harness did not pass per-source image UUIDs"
  pass "test harness source image UUID map"
}

run_test_harness_source_image_uuid_map_tests

run_test_harness_preflight_tests() {
  local tmpdir build_log
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' RETURN
  build_log="$tmpdir/builds.log"

  mkdir -p "$tmpdir/ndb/9.99" "$tmpdir/scripts"
  cp "$ROOT_DIR/test.sh" "$tmpdir/test.sh"
  cp "$ROOT_DIR/scripts/postgres_extensions.sh" "$tmpdir/scripts/postgres_extensions.sh"
  cp "$ROOT_DIR/scripts/source_images.sh" "$tmpdir/scripts/source_images.sh"
  cp "$ROOT_DIR/scripts/prism.sh" "$tmpdir/scripts/prism.sh"

  cat > "$tmpdir/ndb/9.99/matrix.json" <<'JSON'
[
  {
    "ndb_version": "9.99",
    "engine": "PostgreSQL Community Edition",
    "db_type": "pgsql",
    "os_type": "Rocky Linux",
    "os_version": "9.7",
    "db_version": "1",
    "provisioning_role": "postgresql"
  },
  {
    "ndb_version": "9.99",
    "engine": "PostgreSQL Community Edition",
    "db_type": "pgsql",
    "os_type": "Ubuntu Linux",
    "os_version": "22.04",
    "db_version": "2",
    "provisioning_role": "postgresql"
  }
]
JSON

  cat > "$tmpdir/build.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
db_version=""
preflight=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --db-version)
      db_version=$2
      shift
      ;;
    --preflight)
      preflight=true
      ;;
  esac
  shift
done
printf '%s|%s\n' "$db_version" "$preflight" >> "${NDB_SELFTEST_BUILD_LOG:?}"
SH
  chmod +x "$tmpdir/test.sh" "$tmpdir/build.sh"

  (
    cd "$tmpdir"
    SKIP_MATRIX_VALIDATION=true NDB_SELFTEST_BUILD_LOG="$build_log" ./test.sh --include-ndb 9.99 --preflight --max-parallel 1 >/dev/null 2>&1
  ) || fail "test harness preflight run failed"

  [[ "$(cat "$build_log")" == $'1|true\n2|true' ]] || fail "test harness did not pass --preflight to selected rows"
  pass "test harness preflight mode"
}

run_test_harness_preflight_tests

run_test_harness_customization_profile_tests() {
  local tmpdir build_log
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' RETURN
  build_log="$tmpdir/builds.log"

  mkdir -p "$tmpdir/ndb/9.99" "$tmpdir/scripts"
  cp "$ROOT_DIR/test.sh" "$tmpdir/test.sh"
  cp "$ROOT_DIR/scripts/postgres_extensions.sh" "$tmpdir/scripts/postgres_extensions.sh"
  cp "$ROOT_DIR/scripts/source_images.sh" "$tmpdir/scripts/source_images.sh"
  cp "$ROOT_DIR/scripts/prism.sh" "$tmpdir/scripts/prism.sh"

  cat > "$tmpdir/ndb/9.99/matrix.json" <<'JSON'
[
  {
    "ndb_version": "9.99",
    "engine": "PostgreSQL Community Edition",
    "db_type": "pgsql",
    "os_type": "Red Hat Enterprise Linux (RHEL)",
    "os_version": "9.7",
    "db_version": "1",
    "provisioning_role": "postgresql"
  },
  {
    "ndb_version": "9.99",
    "engine": "PostgreSQL Community Edition",
    "db_type": "pgsql",
    "os_type": "Red Hat Enterprise Linux (RHEL)",
    "os_version": "9.7",
    "db_version": "2",
    "provisioning_role": "postgresql"
  }
]
JSON

  cat > "$tmpdir/build.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
db_version=""
customization_profile=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --db-version)
      db_version=$2
      shift
      ;;
    --customization-profile)
      customization_profile=$2
      shift
      ;;
  esac
  shift
done
printf '%s|%s\n' "$db_version" "$customization_profile" >> "${NDB_SELFTEST_BUILD_LOG:?}"
SH
  chmod +x "$tmpdir/test.sh" "$tmpdir/build.sh"

  (
    cd "$tmpdir"
    SKIP_MATRIX_VALIDATION=true NDB_SELFTEST_BUILD_LOG="$build_log" ./test.sh --include-ndb 9.99 --allow-rhel --customization-profile customizations/local/rhel-repositories.yml --max-parallel 1 >/dev/null 2>&1
  ) || fail "test harness customization profile run failed"

  [[ "$(cat "$build_log")" == $'1|customizations/local/rhel-repositories.yml\n2|customizations/local/rhel-repositories.yml' ]] || fail "test harness did not pass customization profile to selected rows"
  pass "test harness customization profile"
}

run_test_harness_customization_profile_tests

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
    grep -q "lock_timeout: 600" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version does not wait for apt locks"
    grep -q "apt_postgres_extension_packages_result" "$ROOT_DIR/ansible/$version/roles/postgres/tasks/main.yml" || fail "postgres role $version does not retry Debian extension package installs"
  done
  grep -q "POSTGRES_HA_COMPONENTS_JSON" "$ROOT_DIR/build.sh" || fail "build.sh does not extract PostgreSQL HA components from the matrix"
  grep -q "postgres_ha_components" "$ROOT_DIR/build.sh" || fail "build.sh does not pass PostgreSQL HA components to Ansible"
  grep -q "POSTGRES_PACKAGE_VERSION_PREFIX" "$ROOT_DIR/build.sh" || fail "build.sh does not extract PostgreSQL package pins from the matrix"
  grep -q "postgres_package_version_prefix" "$ROOT_DIR/scripts/artifact_validate.sh" || fail "artifact validation does not receive PostgreSQL package pins"
  pass "strict extension package mapping, apt locking, HA validation, and NDB-safe PostgreSQL service state"
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

run_validate_mongodb_role_static_tests

run_ndb_linux_precheck_guard_tests() {
  local version newline_less_password newline_less_pam_password

  newline_less_password=$(printf 'secret' | bash -c 'password=""; IFS= read -r password || true; printf "%s" "$password"')
  [[ "$newline_less_password" == "secret" ]] || fail "passwd wrapper read pattern does not preserve newline-less stdin"

  newline_less_pam_password=$(printf 'secret' | bash -c 'pam_password=""; IFS= read -r pam_password || true; printf "%s" "$pam_password"')
  [[ "$newline_less_pam_password" == "secret" ]] || fail "PAM auth-token read pattern does not preserve newline-less stdin"

  for version in 2.9 2.10; do
    grep -q "numa=off" "$ROOT_DIR/ansible/$version/roles/common/vars/main.yml" || fail "common role $version missing NDB numa kernel arg default"
    grep -q "transparent_hugepage=never" "$ROOT_DIR/ansible/$version/roles/common/vars/main.yml" || fail "common role $version missing NDB transparent hugepage kernel arg default"
    grep -q "Persist NDB kernel arguments in GRUB defaults" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version does not persist NDB kernel args"
    grep -q "util-linux" "$ROOT_DIR/ansible/$version/roles/common/vars/main.yml" || fail "common role $version does not install util-linux for the reset helper lock"
    grep -q "parted" "$ROOT_DIR/ansible/$version/roles/common/vars/main.yml" || fail "common role $version does not install parted for NDB storage mapping"
    grep -q "nftables" "$ROOT_DIR/ansible/$version/roles/common/vars/main.yml" || fail "common role $version does not install nftables for the Debian SSH reset port gate"
    grep -q "grubby" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version does not apply kernel args to Red Hat boot entries"
    grep -q "update-grub" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version does not refresh Debian GRUB config"
    grep -q "99-ndb-root-device.cfg" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version does not write late Debian GRUB root-device override"
    grep -q "GRUB_DISABLE_LINUX_PARTUUID" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version does not disable Debian PARTUUID root mapping"
    grep -q "GRUB_FORCE_PARTUUID=" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version does not clear Ubuntu cloud-image forced PARTUUID root"
    grep -q "Set Debian-family SSH password auth in main sshd_config" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version does not set main Debian sshd_config password auth for NDB"
    grep -q "01-ndb-password-auth.conf" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version does not configure Debian SSH password auth for NDB"
    grep -q "PasswordAuthentication yes" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version does not allow NDB password SSH on Debian clones"
    grep -q "Assert Debian-family SSH password auth is effective" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version does not assert effective Debian SSH password auth for NDB"
    grep -q "passwordauthentication yes" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version does not validate effective Debian SSH password auth with sshd -T"
    grep -q "Remove stale NDB reset hook from Debian-family rc.local" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version does not sanitize stale Debian rc.local reset hooks"
    grep -q "Remove stale NDB reset script from Debian-family source image" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version does not remove stale Debian reset scripts before capture"
    grep -q "ndb-reset-password-compat.service" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version does not install the Debian NDB password reset compatibility service"
    grep -q "ndb-ssh-reset-gate.service" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version does not install the Debian SSH reset port gate service"
    grep -q "ndb_ssh_reset_gate" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version does not use a dedicated nftables table for the Debian SSH reset port gate"
    grep -q "tcp dport 22 drop" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version SSH reset port gate does not block inbound SSH"
    grep -q "validate-block-rule" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version SSH reset port gate does not expose nft dry-run validation"
    ! grep -q "watch-reset-intent" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version SSH reset port gate must not run a long watcher before early boot targets"
    grep -q "Type=oneshot" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version SSH reset port gate service is not a fast oneshot"
    grep -q "ExecStart=/usr/local/sbin/ndb-ssh-reset-gate block-if-reset-intent" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version SSH reset port gate service does not synchronously apply the first gate check"
    grep -q "WantedBy=sysinit.target" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version SSH reset port gate service is not anchored early enough in sysinit.target"
    grep -q "Before=sysinit.target basic.target" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version SSH reset port gate service is not ordered before early boot targets"
    ! grep -Eq "Before=.*firewalld\\.service" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version SSH reset port gate must not order itself before firewalld and create Ubuntu boot cycles"
    ! grep -q "Type=simple" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version SSH reset port gate must not use a boot-blocking Type=simple watcher"
    ! grep -q "tcp dport 22 drop comment" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version SSH reset port gate uses a fragile unescaped nft rule comment"
    grep -q "block-if-reset-intent" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version SSH reset port gate is not limited to NDB reset intent"
    grep -q "ndb-ssh-reset-gate unblock" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version reset helper does not unblock the SSH reset port gate after reset"
    ! grep -q "ConditionPathExists=/bin/reset_password.sh" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version reset service still uses a systemd path condition instead of helper-level no-op logic"
    grep -q "DefaultDependencies=no" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version reset service does not use early boot ordering"
    grep -Eq "Before=.*ssh.service.*sshd.service" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version password reset service does not run before SSH"
    grep -q "ssh.service.d/10-ndb-reset-password.conf" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version does not attach the NDB password reset to SSH startup"
    grep -q "sshd.service.d/10-ndb-reset-password.conf" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version does not attach the NDB password reset to the SSH alias startup"
    grep -q "Check Debian-family SSH socket activation unit" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version does not check for SSH socket support before masking it"
    grep -q "ssh.socket" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version does not disable Debian SSH socket activation"
    grep -q "masked: false" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version must leave Debian SSH socket unmasked so ssh.service can start on socket-backed images"
    ! grep -q "masked: true" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version masks Debian SSH socket and can prevent ssh.service from starting"
    grep -q "Ensure Debian-family SSH service remains enabled after socket activation disablement" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version does not re-enable SSH service after disabling socket activation"
    grep -q "Wants=ndb-reset-password-compat.service" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version SSH drop-in does not explicitly start the Debian reset service before SSH"
    grep -q "After=ndb-reset-password-compat.service" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version SSH drop-in does not order SSH after the Debian reset service"
    ! grep -q "After=ndb-reset-password-compat.service rc-local.service" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version SSH drop-in can deadlock cloud-init SSH startup by waiting directly on rc-local.service"
    grep -q "ExecStartPre=/usr/local/sbin/ndb-run-reset-password" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version SSH drop-in does not run the reset helper before SSH"
    grep -q -- "--wait-for-script 150" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version SSH drop-in does not wait for late NDB reset-script injection"
    grep -q "Run NDB injected password reset before Debian-family SSH password authentication" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version does not gate Debian SSH password authentication through the reset helper"
    grep -q 'auth required pam_exec.so quiet seteuid expose_authtok /usr/local/sbin/ndb-run-reset-password --pam-auth-token {{ ndb_drive_user }}' "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version does not add the Debian SSH PAM auth-token reset gate with effective-root privileges for the configured NDB drive user"
    grep -q "Normalize NDB drive user before Debian-family SSH account checks" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version does not normalize the NDB drive user before Debian SSH account checks"
    grep -q 'account required pam_exec.so quiet seteuid /usr/local/sbin/ndb-run-reset-password --pam-account {{ ndb_drive_user }}' "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version does not add the Debian SSH PAM account normalization gate with effective-root privileges"
    grep -q "Bypass Debian-family boot nologin for NDB drive user" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version does not skip boot nologin for the NDB drive user"
    grep -Fq 'account [success=1 default=ignore] pam_succeed_if.so quiet user = {{ ndb_drive_user }}' "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version does not install a user-scoped pam_nologin bypass for the NDB drive user"
    grep -q "pam_nologin" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version NDB nologin bypass is not anchored to pam_nologin"
    grep -q "wait_seconds=0" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version reset helper does not support bounded wait mode"
    grep -q "pam_token_user=" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version reset helper does not support PAM auth-token mode"
    grep -q "pam_account_user=" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version reset helper does not support PAM account mode"
    grep -q "pam_password=" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version reset helper does not capture the PAM auth token before fallback"
    grep -q "IFS= read -r pam_password || true" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version reset helper does not preserve newline-less PAM auth tokens"
    grep -q "IFS= read -r password || true" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version passwd wrapper does not preserve newline-less stdin passwords"
    ! grep -q 'IFS= read -r pam_password || pam_password=""' "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version reset helper clears newline-less PAM auth tokens"
    ! grep -q 'IFS= read -r password || password=""' "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version passwd wrapper clears newline-less stdin passwords"
    grep -q "set_password_from_pam_token" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version reset helper does not fall back to the PAM auth token when OpenSSH provides one"
    grep -q "normalize_password_login_account" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version reset helper does not normalize the drive-user account after password reset"
    grep -q "usermod --unlock" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version reset helper does not unlock the drive-user account after password reset"
    grep -q "chage -E -1 -I -1 -m 0 -M 99999" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version reset helper does not unexpire the drive-user account after password reset"
    grep -q 'normalize_password_login_account "$user"' "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version passwd wrapper does not normalize account state after chpasswd"
    grep -q 'normalize_password_login_account "$target_user"' "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version PAM token fallback does not normalize account state after chpasswd"
    grep -q 'normalize_password_login_account "$pam_account_user"' "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version PAM account hook does not normalize account state"
    ! grep -q 'if \[\[ -f "\$done_marker" || ! -f "\$script" \]\]' "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version PAM account hook unblocks SSH before reset completion when the reset script is absent"
    grep -q "NDB PAM account normalization completed" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version reset helper does not log PAM account normalization"
    grep -q "NDB injected password reset completed during PAM account check" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version reset helper does not run reset work from the PAM account phase"
    grep -q "script_completed=false" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version reset helper does not track completed NDB reset scripts in PAM mode"
    grep -q "Applying PAM auth-token password reset for" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version reset helper does not apply the PAM auth-token password when one is available"
    grep -q "PAM auth token unavailable; trusting completed NDB injected password reset" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version reset helper does not tolerate OpenSSH PAM auth without an exposed token after a successful reset script"
    grep -q "interactive or Red Hat-style passwd forms" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version reset helper does not rewrite interactive passwd forms for Debian"
    grep -q 'exec /usr/bin/passwd "$@"' "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version passwd compatibility helper does not delegate unsupported passwd invocations"
    ! grep -q '\${#' "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version inline shell contains unescaped Bash length syntax that Jinja parses as a comment"
    grep -q "PAM_USER" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version reset helper does not gate PAM token fallback by PAM user"
    grep -q "rc_local_references_reset=false" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version reset helper does not track rc.local reset intent"
    grep -q 'rc_local_references_reset" != "true"' "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version reset helper waits on normal boots without rc.local reset intent"
    grep -q "NDB PAM auth waiting for late injected reset script" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version PAM auth helper does not wait for late NDB reset-script injection before password checks"
    grep -q '\[\[ -e /etc/rc.local \]\]' "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version PAM auth helper does not use NDB-created rc.local as the late reset-injection signal"
    grep -q "NDB PAM auth-token password reset triggered by NDB-created rc.local" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version PAM auth helper does not set the password from the NDB auth token when rc.local exists before reset script injection"
    ! grep -q "NDB reset helper waiting for late injected reset script before SSH opens" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version reset helper blocks normal SSH startup while waiting for late reset injection"
    grep -q "flock -w 300" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version reset helper does not serialize concurrent reset attempts"
    grep -q "done_marker=/run/ndb-reset-password.done" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version reset helper does not mark successful reset completion"
    grep -q "reset_already_completed=false" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version reset helper does not track pre-existing reset completion separately from PAM auth"
    ! grep -q 'if \[\[ -f "\$done_marker" \]\] && \[\[ -n "\$pam_token_user" \]\]' "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version reset helper exits before PAM auth-token fallback when reset is already marked complete"
    grep -q "NDB injected password reset was already marked complete before PAM auth" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version reset helper does not allow PAM token fallback after an earlier reset marker"
    grep -q "NDB injected password reset failed with exit status" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version reset helper does not fail closed on reset errors"
    ! grep -q '/bin/bash "\$script".*|| true' "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version reset helper still masks reset-script failures"
    grep -q "networking.service.d/10-ndb-reset-password.conf" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version does not attach the NDB password reset to Debian networking startup"
    grep -q "Before=networking.service" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version reset service is not ordered before Debian networking"
    grep -q "/usr/local/sbin/ndb-run-reset-password" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version SSH drop-in does not use the Debian-safe NDB reset helper"
    grep -q "/usr/local/sbin/ndb-passwd-stdin" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version does not install a passwd --stdin compatibility helper"
    grep -q "chpasswd" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version NDB reset compatibility helper does not use chpasswd"
    grep -q "/bin/reset_password.sh" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version SSH drop-in does not handle NDB's injected reset script"
    grep -q "/opt/era_base/era_startup.log" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version SSH drop-in does not preserve reset logs"
    grep -q "ndb-era-dm-compat" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version does not install the NDB Era device-mapper helper"
    grep -q "ntnx_era_agent_vg_*" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version NDB Era device-mapper helper is not scoped to NDB Era LVM volumes"
    grep -q "dmsetup deps -o devname" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version NDB Era device-mapper helper does not derive parent disks"
    grep -Fq '[[ "$kernel" =~ ^dm-[0-9]+$ ]]' "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version NDB Era device-mapper helper can recursively process generated DM aliases"
    grep -q '/dev/${kernel}..' "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version NDB Era device-mapper helper does not create malformed DM aliases"
    grep -Fq 'ln -s "$dm_dev" "$alias"' "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version NDB Era device-mapper helper must create symlink aliases"
    ! grep -q "mknod -m" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version NDB Era device-mapper helper must not create block-device aliases"
    grep -q "99-ndb-era-dm-serial.rules" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version NDB Era device-mapper helper does not write udev serial metadata"
    grep -q "ndb-era-dm-compat.timer" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version does not install the NDB Era device-mapper timer"
    grep -q "OnUnitActiveSec=10s" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version NDB Era device-mapper timer does not rerun during target disk attach"
    grep -q "Expose Debian-family chrony config at NDB expected path" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version does not expose /etc/chrony.conf for Debian-family NDB compatibility"
    grep -q "Ensure Debian-family D-Bus service is pulled in during first boot" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version does not guarantee Debian-family D-Bus first-boot startup"
    grep -q "basic.target.wants/dbus.service" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version does not anchor dbus.service to basic.target"
    grep -q "sockets.target.wants/dbus.socket" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version does not anchor dbus.socket to sockets.target"
    grep -q "Check firewalld SSH service rule" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version does not check whether firewalld allows SSH"
    grep -q "Allow SSH through firewalld" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version does not allow SSH through firewalld"
    grep -q "Reload firewalld after allowing SSH" "$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml" || fail "common role $version does not reload firewalld after allowing SSH"
    grep -q "Assert GRUB defaults include NDB kernel arguments" "$ROOT_DIR/ansible/$version/roles/validate_postgres/tasks/main.yml" || fail "validate_postgres role $version does not validate NDB kernel args"
    grep -q "Assert GRUB defaults include NDB kernel arguments" "$ROOT_DIR/ansible/$version/roles/validate_mongodb/tasks/main.yml" || fail "validate_mongodb role $version does not validate NDB kernel args"
    grep -q "Assert firewalld allows SSH" "$ROOT_DIR/ansible/$version/roles/validate_postgres/tasks/main.yml" || fail "validate_postgres role $version does not validate firewalld SSH access"
    grep -q "Assert firewalld allows SSH" "$ROOT_DIR/ansible/$version/roles/validate_mongodb/tasks/main.yml" || fail "validate_mongodb role $version does not validate firewalld SSH access"
    grep -q "Assert Debian-family NDB chrony config path exists" "$ROOT_DIR/ansible/$version/roles/validate_postgres/tasks/main.yml" || fail "validate_postgres role $version does not validate Debian-family /etc/chrony.conf compatibility"
    grep -q "Assert Debian-family NDB chrony config path exists" "$ROOT_DIR/ansible/$version/roles/validate_mongodb/tasks/main.yml" || fail "validate_mongodb role $version does not validate Debian-family /etc/chrony.conf compatibility"
    grep -q "Validate Debian-family D-Bus first-boot readiness" "$ROOT_DIR/ansible/$version/roles/validate_postgres/tasks/main.yml" || fail "validate_postgres role $version does not validate Debian-family D-Bus first-boot readiness"
    grep -q "Validate Debian-family D-Bus first-boot readiness" "$ROOT_DIR/ansible/$version/roles/validate_mongodb/tasks/main.yml" || fail "validate_mongodb role $version does not validate Debian-family D-Bus first-boot readiness"
    grep -q "/run/dbus/system_bus_socket" "$ROOT_DIR/ansible/$version/roles/validate_postgres/tasks/main.yml" || fail "validate_postgres role $version does not validate the D-Bus system socket"
    grep -q "/run/dbus/system_bus_socket" "$ROOT_DIR/ansible/$version/roles/validate_mongodb/tasks/main.yml" || fail "validate_mongodb role $version does not validate the D-Bus system socket"
    grep -q "Validate Debian-family captured image has no stale NDB reset script" "$ROOT_DIR/ansible/$version/roles/validate_postgres/tasks/main.yml" || fail "validate_postgres role $version does not validate stale Debian reset script removal"
    grep -q "Validate Debian-family captured image has no stale NDB reset script" "$ROOT_DIR/ansible/$version/roles/validate_mongodb/tasks/main.yml" || fail "validate_mongodb role $version does not validate stale Debian reset script removal"
    grep -q "Validate Debian-family rc.local has no stale NDB reset hook" "$ROOT_DIR/ansible/$version/roles/validate_postgres/tasks/main.yml" || fail "validate_postgres role $version does not validate stale Debian rc.local reset hook removal"
    grep -q "Validate Debian-family rc.local has no stale NDB reset hook" "$ROOT_DIR/ansible/$version/roles/validate_mongodb/tasks/main.yml" || fail "validate_mongodb role $version does not validate stale Debian rc.local reset hook removal"
    grep -q "Validate Debian-family NDB reset helper wait mode" "$ROOT_DIR/ansible/$version/roles/validate_postgres/tasks/main.yml" || fail "validate_postgres role $version does not validate Debian-family reset helper wait mode"
    grep -q "Validate Debian-family NDB reset helper wait mode" "$ROOT_DIR/ansible/$version/roles/validate_mongodb/tasks/main.yml" || fail "validate_mongodb role $version does not validate Debian-family reset helper wait mode"
    grep -q "Validate Debian-family SSH reset port gate helper" "$ROOT_DIR/ansible/$version/roles/validate_postgres/tasks/main.yml" || fail "validate_postgres role $version does not validate Debian-family SSH reset port gate helper"
    grep -q "Validate Debian-family SSH reset port gate helper" "$ROOT_DIR/ansible/$version/roles/validate_mongodb/tasks/main.yml" || fail "validate_mongodb role $version does not validate Debian-family SSH reset port gate helper"
    grep -q "validate-block-rule" "$ROOT_DIR/ansible/$version/roles/validate_postgres/tasks/main.yml" || fail "validate_postgres role $version does not dry-run validate the Debian SSH reset port gate nft rule"
    grep -q "validate-block-rule" "$ROOT_DIR/ansible/$version/roles/validate_mongodb/tasks/main.yml" || fail "validate_mongodb role $version does not dry-run validate the Debian SSH reset port gate nft rule"
    grep -q "Validate Debian-family SSH reset port gate service" "$ROOT_DIR/ansible/$version/roles/validate_postgres/tasks/main.yml" || fail "validate_postgres role $version does not validate Debian-family SSH reset port gate service"
    grep -q "Validate Debian-family SSH reset port gate service" "$ROOT_DIR/ansible/$version/roles/validate_mongodb/tasks/main.yml" || fail "validate_mongodb role $version does not validate Debian-family SSH reset port gate service"
    grep -q "Type=oneshot" "$ROOT_DIR/ansible/$version/roles/validate_postgres/tasks/main.yml" || fail "validate_postgres role $version does not validate the fast reset gate service type"
    grep -q "Type=oneshot" "$ROOT_DIR/ansible/$version/roles/validate_mongodb/tasks/main.yml" || fail "validate_mongodb role $version does not validate the fast reset gate service type"
    grep -q "ExecStart=/usr/local/sbin/ndb-ssh-reset-gate block-if-reset-intent" "$ROOT_DIR/ansible/$version/roles/validate_postgres/tasks/main.yml" || fail "validate_postgres role $version does not validate the fast reset gate command"
    grep -q "ExecStart=/usr/local/sbin/ndb-ssh-reset-gate block-if-reset-intent" "$ROOT_DIR/ansible/$version/roles/validate_mongodb/tasks/main.yml" || fail "validate_mongodb role $version does not validate the fast reset gate command"
    grep -q "watch-reset-intent" "$ROOT_DIR/ansible/$version/roles/validate_postgres/tasks/main.yml" || fail "validate_postgres role $version does not reject the old boot-blocking reset gate watcher"
    grep -q "watch-reset-intent" "$ROOT_DIR/ansible/$version/roles/validate_mongodb/tasks/main.yml" || fail "validate_mongodb role $version does not reject the old boot-blocking reset gate watcher"
    grep -q "Before=.*firewalld.service" "$ROOT_DIR/ansible/$version/roles/validate_postgres/tasks/main.yml" || fail "validate_postgres role $version does not reject firewalld ordering in the SSH reset gate service"
    grep -q "Before=.*firewalld.service" "$ROOT_DIR/ansible/$version/roles/validate_mongodb/tasks/main.yml" || fail "validate_mongodb role $version does not reject firewalld ordering in the SSH reset gate service"
    grep -q "sysinit.target.wants/ndb-ssh-reset-gate.service" "$ROOT_DIR/ansible/$version/roles/validate_postgres/tasks/main.yml" || fail "validate_postgres role $version does not validate early sysinit anchoring for the SSH reset port gate"
    grep -q "sysinit.target.wants/ndb-ssh-reset-gate.service" "$ROOT_DIR/ansible/$version/roles/validate_mongodb/tasks/main.yml" || fail "validate_mongodb role $version does not validate early sysinit anchoring for the SSH reset port gate"
    ! grep -q "Validate Debian-family SSH waits for rc-local reset path" "$ROOT_DIR/ansible/$version/roles/validate_postgres/tasks/main.yml" || fail "validate_postgres role $version still validates the removed rc-local SSH ordering"
    ! grep -q "Validate Debian-family SSH waits for rc-local reset path" "$ROOT_DIR/ansible/$version/roles/validate_mongodb/tasks/main.yml" || fail "validate_mongodb role $version still validates the removed rc-local SSH ordering"
    grep -q "Validate Debian-family SSH PAM reset gate" "$ROOT_DIR/ansible/$version/roles/validate_postgres/tasks/main.yml" || fail "validate_postgres role $version does not validate Debian-family SSH PAM reset gate"
    grep -q "Validate Debian-family SSH PAM reset gate" "$ROOT_DIR/ansible/$version/roles/validate_mongodb/tasks/main.yml" || fail "validate_mongodb role $version does not validate Debian-family SSH PAM reset gate"
    grep -q "Validate Debian-family SSH PAM nologin bypass for NDB drive user" "$ROOT_DIR/ansible/$version/roles/validate_postgres/tasks/main.yml" || fail "validate_postgres role $version does not validate Debian-family SSH PAM nologin bypass"
    grep -q "Validate Debian-family SSH PAM nologin bypass for NDB drive user" "$ROOT_DIR/ansible/$version/roles/validate_mongodb/tasks/main.yml" || fail "validate_mongodb role $version does not validate Debian-family SSH PAM nologin bypass"
    grep -q "Validate Debian-family SSH PAM account normalization gate" "$ROOT_DIR/ansible/$version/roles/validate_postgres/tasks/main.yml" || fail "validate_postgres role $version does not validate Debian-family SSH PAM account normalization gate"
    grep -q "Validate Debian-family SSH PAM account normalization gate" "$ROOT_DIR/ansible/$version/roles/validate_mongodb/tasks/main.yml" || fail "validate_mongodb role $version does not validate Debian-family SSH PAM account normalization gate"
    grep -q "Validate Debian-family reset helper normalizes PAM account state" "$ROOT_DIR/ansible/$version/roles/validate_postgres/tasks/main.yml" || fail "validate_postgres role $version does not validate Debian-family PAM account normalization"
    grep -q "Validate Debian-family reset helper normalizes PAM account state" "$ROOT_DIR/ansible/$version/roles/validate_mongodb/tasks/main.yml" || fail "validate_mongodb role $version does not validate Debian-family PAM account normalization"
    grep -q "Assert Debian-family SSH socket activation cannot bypass reset gate" "$ROOT_DIR/ansible/$version/roles/validate_postgres/tasks/main.yml" || fail "validate_postgres role $version does not validate SSH socket reset-gate protection"
    grep -q "Assert Debian-family SSH socket activation cannot bypass reset gate" "$ROOT_DIR/ansible/$version/roles/validate_mongodb/tasks/main.yml" || fail "validate_mongodb role $version does not validate SSH socket reset-gate protection"
    ! grep -q 'stdout in \["masked", "disabled"\]' "$ROOT_DIR/ansible/$version/roles/validate_postgres/tasks/main.yml" || fail "validate_postgres role $version still accepts masked SSH socket state"
    ! grep -q 'stdout in \["masked", "disabled"\]' "$ROOT_DIR/ansible/$version/roles/validate_mongodb/tasks/main.yml" || fail "validate_mongodb role $version still accepts masked SSH socket state"
    grep -q "Assert Debian-family SSH service is enabled after socket activation disablement" "$ROOT_DIR/ansible/$version/roles/validate_postgres/tasks/main.yml" || fail "validate_postgres role $version does not validate SSH service enablement after socket activation disablement"
    grep -q "Assert Debian-family SSH service is enabled after socket activation disablement" "$ROOT_DIR/ansible/$version/roles/validate_mongodb/tasks/main.yml" || fail "validate_mongodb role $version does not validate SSH service enablement after socket activation disablement"
    grep -q "root=/dev/" "$ROOT_DIR/ansible/$version/roles/validate_postgres/tasks/main.yml" || fail "validate_postgres role $version does not validate Debian root disk mapping"
    grep -q "root=/dev/" "$ROOT_DIR/ansible/$version/roles/validate_mongodb/tasks/main.yml" || fail "validate_mongodb role $version does not validate Debian root disk mapping"
    grep -q "Validate Debian-family NDB Era device-mapper helper" "$ROOT_DIR/ansible/$version/roles/validate_postgres/tasks/main.yml" || fail "validate_postgres role $version does not validate the NDB Era device-mapper helper"
    grep -q "Validate Debian-family NDB Era device-mapper helper" "$ROOT_DIR/ansible/$version/roles/validate_mongodb/tasks/main.yml" || fail "validate_mongodb role $version does not validate the NDB Era device-mapper helper"
    grep -q "Validate Debian-family NDB Era device-mapper timer" "$ROOT_DIR/ansible/$version/roles/validate_postgres/tasks/main.yml" || fail "validate_postgres role $version does not validate the NDB Era device-mapper timer"
    grep -q "Validate Debian-family NDB Era device-mapper timer" "$ROOT_DIR/ansible/$version/roles/validate_mongodb/tasks/main.yml" || fail "validate_mongodb role $version does not validate the NDB Era device-mapper timer"
    grep -q "command -v parted" "$ROOT_DIR/ansible/$version/roles/validate_postgres/tasks/main.yml" || fail "validate_postgres role $version does not validate parted for NDB storage mapping"
    grep -q "command -v parted" "$ROOT_DIR/ansible/$version/roles/validate_mongodb/tasks/main.yml" || fail "validate_mongodb role $version does not validate parted for NDB storage mapping"
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
  grep -q 'ConnectTimeout=5' "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "E2E runner SSH probes use too long a connection timeout for unreachable Prism IP retries"
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
  pass "NDB Linux precheck guards"
}

run_ndb_linux_precheck_guard_tests

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
  grep -q ".cleanup.packer_builder_vm" "$ROOT_DIR/build.sh" || fail "build script does not record failed builder cleanup in manifests"
  grep -q ".cleanup.packer_builder_vm_uuid" "$ROOT_DIR/build.sh" || fail "build script does not record failed builder VM UUIDs in manifests"
  grep -q -- "--retain-failed-builder" "$ROOT_DIR/build.sh" || fail "build script does not expose non-interactive failed builder retention"
  grep -q "RETAIN_FAILED_BUILDER" "$ROOT_DIR/build.sh" || fail "build script does not track failed builder retention separately from debug mode"
  grep -q "kept-on-failure" "$ROOT_DIR/build.sh" || fail "build script does not record retained failed builder manifests"
  pass "failed builder VM cleanup guard"
}

run_build_cleanup_guard_tests

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

run_readme_mongodb_tests

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

run_debian_libaio_package_guard_tests() {
  local version vars_file tasks_file

  for version in 2.9 2.10; do
    vars_file="$ROOT_DIR/ansible/$version/roles/common/vars/main.yml"
    tasks_file="$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml"

    grep -q "debian_libaio_package" "$vars_file" "$tasks_file" || fail "NDB $version common role does not derive Debian libaio package by OS release"
    grep -q "libaio1t64" "$vars_file" "$tasks_file" || fail "NDB $version common role does not handle Ubuntu 24.04 libaio1t64"
    grep -q "version('24.04', '>=')" "$vars_file" "$tasks_file" || fail "NDB $version common role does not gate libaio1t64 on Ubuntu 24.04 or newer"
    ! grep -qE '^[[:space:]]*-[[:space:]]+libaio1$' "$vars_file" || fail "NDB $version common role still installs libaio1 unconditionally"
  done

  pass "Debian libaio package guard"
}

run_debian_libaio_package_guard_tests

run_debian_common_package_guard_tests() {
  local version vars_file

  for version in 2.9 2.10; do
    vars_file="$ROOT_DIR/ansible/$version/roles/common/vars/main.yml"
    grep -qE '^[[:space:]]*-[[:space:]]+cron$' "$vars_file" || fail "NDB $version common role does not install cron before managing cron.service on Debian"
  done

  pass "Debian common package guard"
}

run_debian_common_package_guard_tests

run_ndb_linux_precheck_guard_tests() {
  local version vars_file tasks_file sudoers_file validate_postgres_file validate_mongodb_file pkg
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
    tasks_file="$ROOT_DIR/ansible/$version/roles/common/tasks/main.yml"
    sudoers_file="$ROOT_DIR/ansible/$version/roles/common/templates/ndb_sudoers.j2"
    validate_postgres_file="$ROOT_DIR/ansible/$version/roles/validate_postgres/tasks/main.yml"
    validate_mongodb_file="$ROOT_DIR/ansible/$version/roles/validate_mongodb/tasks/main.yml"

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

    grep -q 'name: "{{ ndb_drive_user }}"' "$tasks_file" || fail "NDB $version common role does not create the NDB drive user"
    grep -q "use_devicesfile = 0" "$tasks_file" || fail "NDB $version common role does not disable LVM devices file usage"
    grep -q "ndb-era-dm-compat" "$tasks_file" || fail "NDB $version common role does not install the NDB Era device-mapper helper"
    grep -q "ndb-era-dm-compat.timer" "$tasks_file" || fail "NDB $version common role does not install the NDB Era device-mapper timer"
    grep -q "OnUnitActiveSec=10s" "$tasks_file" || fail "NDB $version NDB Era device-mapper timer does not rerun during target disk attach"
    grep -Fq '[[ "$kernel" =~ ^dm-[0-9]+$ ]]' "$tasks_file" || fail "NDB $version NDB Era device-mapper helper can recursively process generated DM aliases"
    grep -q '/dev/${kernel}..' "$tasks_file" || fail "NDB $version NDB Era device-mapper helper does not create malformed DM aliases"
    grep -Fq 'ln -s "$dm_dev" "$alias"' "$tasks_file" || fail "NDB $version NDB Era device-mapper helper must create symlink aliases"
    ! grep -q "mknod -m" "$tasks_file" || fail "NDB $version NDB Era device-mapper helper must not create block-device aliases"
    grep -q "99-ndb-era-dm-serial.rules" "$tasks_file" || fail "NDB $version NDB Era device-mapper helper does not write udev serial metadata"
    grep -q "Expose Debian-family chrony config at NDB expected path" "$tasks_file" || fail "NDB $version common role does not expose Debian-family /etc/chrony.conf for NDB"
    grep -q "Ensure Debian-family D-Bus service is pulled in during first boot" "$tasks_file" || fail "NDB $version common role does not guarantee Debian-family D-Bus first-boot startup"
    grep -q "basic.target.wants/dbus.service" "$tasks_file" || fail "NDB $version common role does not anchor dbus.service to basic.target"
    grep -q "sockets.target.wants/dbus.socket" "$tasks_file" || fail "NDB $version common role does not anchor dbus.socket to sockets.target"
    grep -q '{{ ndb_drive_user }} ALL=(ALL) NOPASSWD:ALL' "$sudoers_file" || fail "NDB $version sudoers policy does not allow Nutanix precheck sudo -n true"
    grep -q "Validate Debian-family D-Bus first-boot readiness" "$validate_postgres_file" || fail "NDB $version PostgreSQL validation does not check Debian-family D-Bus first-boot readiness"
    grep -q "Validate Debian-family D-Bus first-boot readiness" "$validate_mongodb_file" || fail "NDB $version MongoDB validation does not check Debian-family D-Bus first-boot readiness"
    grep -q "command -v parted" "$validate_postgres_file" || fail "NDB $version PostgreSQL validation does not check parted for NDB storage mapping"
    grep -q "command -v parted" "$validate_mongodb_file" || fail "NDB $version MongoDB validation does not check parted for NDB storage mapping"
  done

  grep -q "Nutanix Linux Precheck" "$ROOT_DIR/README.md" || fail "README missing Nutanix Linux precheck guidance"
  grep -q "/etc/chrony.conf" "$ROOT_DIR/README.md" || fail "README missing Debian-family chrony path guidance"
  grep -q "/run/dbus/system_bus_socket" "$ROOT_DIR/README.md" || fail "README missing Debian-family D-Bus first-boot guidance"
  grep -q "ndb-era-dm-compat" "$ROOT_DIR/README.md" || fail "README missing Debian-family NDB Era device-mapper helper guidance"
  grep -q "ndb_linux_prechecks.sh -t postgres_database -n era" "$ROOT_DIR/README.md" || fail "README missing PostgreSQL Linux precheck command"
  grep -q "ndb_linux_prechecks.sh -t mongodb_database -n era" "$ROOT_DIR/README.md" || fail "README missing MongoDB Linux precheck command"

  pass "NDB Linux precheck guard"
}

run_ndb_linux_precheck_guard_tests

run_readme_customization_tests() {
  grep -q "Customize The Image" "$ROOT_DIR/README.md" || fail "README missing Customize The Image"
  grep -q "Install an internal CA certificate" "$ROOT_DIR/README.md" || fail "README missing internal CA recipe"
  grep -q "OpenTelemetry Collector" "$ROOT_DIR/README.md" || fail "README missing OpenTelemetry explanation"
  grep -q "customizations/local" "$ROOT_DIR/README.md" || fail "README missing private overlay explanation"
  grep -q "validate_custom_enterprise" "$ROOT_DIR/README.md" || fail "README missing custom validation role guidance"
  pass "README customization guidance"
}

run_readme_customization_tests
