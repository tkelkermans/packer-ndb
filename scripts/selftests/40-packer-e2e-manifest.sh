#!/usr/bin/env bash
# Sourced by scripts/selftest.sh; defines run_*_tests suite functions.
# shellcheck shell=bash

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
run_packer_cloud_init_tests() {
  grep -q "name: packer" "$ROOT_DIR/packer/http/user-data" || fail "Packer cloud-init user data does not create packer user"
  grep -q "NOPASSWD:ALL" "$ROOT_DIR/packer/http/user-data" || fail "Packer cloud-init user data does not grant passwordless sudo"
  grep -q "openssh-server" "$ROOT_DIR/packer/http/user-data" || fail "Packer cloud-init user data does not install openssh-server"
  ! grep -q "groups:.*admin" "$ROOT_DIR/packer/http/user-data" || fail "Packer cloud-init user data uses non-portable admin group"

  pass "Packer cloud-init user data guard"
}
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
  jq -e '.source_image.head == null' "$manifest" >/dev/null || fail "manifest init missing source_image.head"

  "$ROOT_DIR/scripts/manifest.sh" set-json \
    --file "$manifest" \
    --key ".source_image.head" \
    --json-value '{"etag":"\"abc123\"","content_length":662110208,"last_modified":"Sun, 23 Nov 2025 00:00:00 GMT"}'
  jq -e '.source_image.head.content_length == 662110208 and .source_image.head.etag == "\"abc123\""' "$manifest" >/dev/null || fail "manifest source_image.head set-json"
  grep -q "record_source_image_provenance" "$ROOT_DIR/build.sh" || fail "build script does not record source image provenance"

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
  grep -q "vm_lifecycle_wait_guest_boot_ready" "$ROOT_DIR/scripts/artifact_validate.sh" || fail "artifact validation does not wait for D-Bus readiness"
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
run_ndb_e2e_validate_static_tests() {
  local tmpdir targets_file output status
  bash -n "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E validation runner has shell syntax errors"
  bash "$ROOT_DIR/scripts/ndb_e2e_validate.sh" --help >/dev/null || fail "NDB E2E validation runner help failed"

  grep -q 'TMPDIR:-/tmp' "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E runner must default temp paths via TMPDIR/tmp"
  ! grep -Eq '=(/private/tmp|\$\{[^}]*private/tmp)' "$ROOT_DIR/scripts/ndb_e2e_validate.sh" \
    || fail "NDB E2E runner must not hardcode macOS /private/tmp path defaults"
  grep -q "NDB_E2E_EVIDENCE_FILE" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E runner missing configurable evidence file"
  grep -q "join(\"|\")" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E runner must preserve empty target fields with a non-whitespace delimiter"
  grep -q "IFS='|'" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E runner must read target rows with the non-whitespace delimiter"
  grep -q "mongodb_edition" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E runner must carry MongoDB edition metadata"
  grep -q "deployment" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E runner must carry MongoDB deployment metadata"
  grep -q "psql_path" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E runner must preserve OS-specific PostgreSQL client paths"
  grep -Fq "current_database() || '|'" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E runner must record PostgreSQL database name and version in one smoke-check result"
  grep -q "software_profile_name" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E runner evidence must include software profile names"
  grep -q "failure_class" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E runner evidence must include failure class metadata"
  grep -q "known_ndb_debian_pg_storage_protection_blocker" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E runner must classify the known Debian PostgreSQL NDB storage/protection blocker"
  grep -q "Detected invalid Volume Group" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E blocker classifier must require Prism invalid-volume-group evidence"
  grep -q "known_ndb_debian_pg_storage_protection_blocker" "$ROOT_DIR/README.md" || fail "README missing known Debian PostgreSQL blocker classification guidance"
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
  grep -q "validate_live_e2e_config" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E runner must validate live E2E env before provisioning"
  grep -q "NDB_E2E_CLUSTER_ID" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E runner must require a configured NDB cluster"
  grep -q "NDB_E2E_COMPUTE_PROFILE_ID" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E runner must require a configured compute profile"
  grep -q "NDB_E2E_SLA_ID" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E runner must require a configured SLA"
  ! grep -Eq 'NDB_E2E_(CLUSTER_ID|POSTGRES_NETWORK_PROFILE_ID|POSTGRES_DB_PARAM_PROFILE_ID|MONGODB_DB_PARAM_PROFILE_ID|COMPUTE_PROFILE_ID|SLA_ID):-[0-9a-f]{8}-' "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E runner must not publish lab-specific profile UUID defaults"
  grep -q "wait_guest_boot_ready" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E runner does not wait for first-boot system readiness"
  grep -q "vm_lifecycle_wait_guest_boot_ready" "$ROOT_DIR/scripts/ndb_e2e_validate.sh" || fail "NDB E2E runner does not wait for D-Bus readiness"
  grep -q "cloud-init status" "$ROOT_DIR/scripts/vm_lifecycle.sh" || fail "vm lifecycle library does not wait for cloud-init readiness"
  grep -q "Full NDB Provisioning E2E" "$ROOT_DIR/README.md" || fail "README missing full NDB provisioning E2E guidance"
  grep -q "NDB_SERVER_ADDRESS" "$ROOT_DIR/README.md" || fail "README missing NDB server env guidance"
  grep -q "NDB_E2E_CLUSTER_ID" "$ROOT_DIR/README.md" || fail "README missing required NDB cluster ID guidance"
  grep -q "NDB_E2E_POSTGRES_DB_PARAM_PROFILE_ID" "$ROOT_DIR/README.md" || fail "README missing PostgreSQL DB parameter profile guidance"
  grep -q "NDB_E2E_MONGODB_DB_PARAM_PROFILE_ID" "$ROOT_DIR/README.md" || fail "README missing MongoDB DB parameter profile guidance"
  grep -q "NDB_E2E_CLUSTER_ID" "$ROOT_DIR/.env.example" || fail ".env.example missing NDB E2E cluster placeholder"
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

  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' RETURN
  targets_file="$tmpdir/ndb_e2e_latest_targets.psv"
  output="$tmpdir/e2e-dry-run.out"
  status=0
  (
    unset TMPDIR
    NDB_E2E_TARGETS_FILE="$targets_file" \
      NDB_E2E_STATE_DIR="$tmpdir/state" \
      NDB_E2E_EVIDENCE_FILE="$tmpdir/results.jsonl" \
      "$ROOT_DIR/scripts/ndb_e2e_validate.sh" --dry-run --limit 1
  ) >"$output" 2>&1 || status=$?
  [[ -d "$tmpdir" ]] || fail "E2E dry-run temp directory disappeared"
  # Fresh clones have no manifests, so dry-run fails the coverage count — that is
  # expected. The important check is that it never tries to create /private/tmp.
  ! grep -q '/private/tmp' "$output" || fail "E2E dry-run referenced /private/tmp: $(cat "$output")"
  [[ -e "$targets_file" || -d "$(dirname "$targets_file")" ]] \
    || fail "E2E dry-run did not use NDB_E2E_TARGETS_FILE under mktemp"
  if [[ "$status" -eq 0 ]]; then
    grep -q "Attempted rows:" "$output" || fail "E2E dry-run succeeded without reporting attempted rows"
  else
    grep -Eq 'expected .* latest-success targets|Attempted rows:' "$output" \
      || fail "E2E dry-run failed for an unexpected reason: $(cat "$output")"
  fi

  pass "NDB E2E validation runner static guards"
}
run_release_scaffold_tests() {
  local output test_version
  test_version="99.$(date +%s)"
  output=$("$ROOT_DIR/scripts/release_scaffold.sh" "$test_version" --from 2.10 --dry-run)
  grep -q "ansible/${test_version}" <<<"$output" || fail "release scaffold dry-run"
  [[ ! -e "$ROOT_DIR/ndb/$test_version" ]] || fail "release scaffold dry-run created ndb/$test_version"
  [[ ! -e "$ROOT_DIR/ansible/$test_version" ]] || fail "release scaffold dry-run created ansible/$test_version"
  pass "release scaffold dry-run"
}
run_live_campaign_tests() {
  bash -n "$ROOT_DIR/scripts/live_campaign.sh" || fail "live campaign script has shell syntax errors"
  "$ROOT_DIR/scripts/live_campaign.sh" --help >/dev/null || fail "live campaign help failed"
  output=$("$ROOT_DIR/scripts/live_campaign.sh" --list-phases)
  grep -q "ubuntu_pg18_e2e" <<<"$output" || fail "live campaign missing phase 1"
  grep -q "debian_mongo" <<<"$output" || fail "live campaign missing phase 5"
  output=$("$ROOT_DIR/scripts/live_campaign.sh" --dry-run --phase 1 2>&1)
  grep -q "210-pg18-ubuntu2404" <<<"$output" || fail "live campaign phase 1 missing Ubuntu PG18 E2E row id"
  grep -q "preflight-images" <<<"$output" || fail "live campaign phase 1 missing image preflight"
  grep -q 'Ubuntu Linux' <<<"$output" || fail "live campaign phase 1 missing Ubuntu build"
  output=$("$ROOT_DIR/scripts/live_campaign.sh" --dry-run --phase 3 2>&1)
  grep -q 'mongodb' <<<"$output" || fail "live campaign phase 3 missing mongodb builds"
  grep -q '7.0' <<<"$output" || fail "live campaign phase 3 missing MongoDB 7.0"
  grep -q '8.0' <<<"$output" || fail "live campaign phase 3 missing MongoDB 8.0"
  output=$("$ROOT_DIR/scripts/live_campaign.sh" --dry-run --phase 4 2>&1)
  grep -q "Skipping RHEL" <<<"$output" || fail "live campaign phase 4 should skip RHEL by default"
  grep -q "scripts/live_campaign.sh" "$ROOT_DIR/VALIDATION.md" || fail "VALIDATION.md missing live campaign script"
  output=$("$ROOT_DIR/scripts/live_campaign.sh" --check-lab --skip-e2e 2>&1) || true
  grep -q "Lab readiness:" <<<"$output" || fail "live campaign --check-lab missing readiness summary"
  pass "live campaign planner"
}
