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
    "extensions": ["pg_stat_statements"],
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
    "extensions": ["pg_stat_statements", ""],
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
  grep -q "extensions.*non-empty strings" "$invalid_output" || fail "invalid matrix output missed extension element error"
  grep -q "ha_components.*list of non-empty strings" "$invalid_output" || fail "invalid matrix output missed ha_components list error"

  assert_invalid_matrix "non-array root" '"not an array"' "Matrix must be a JSON array"
  assert_invalid_matrix "non-object entry" '[null]' "entry must be an object"
  assert_invalid_matrix "extensions type" '[{"ndb_version":"2.99","engine":"PostgreSQL Community Edition","db_type":"pgsql","os_type":"Rocky Linux","os_version":"9.9","db_version":"18","provisioning_role":"postgresql","extensions":"pg_stat_statements"}]' "extensions.*list"
  assert_invalid_matrix "empty PostgreSQL extensions require reason" '[{"ndb_version":"2.99","engine":"PostgreSQL Community Edition","db_type":"pgsql","os_type":"Rocky Linux","os_version":"9.9","db_version":"18","provisioning_role":"postgresql","extensions":[]}]' "extensions_empty_reason"
  assert_invalid_matrix "ha_components type" '[{"ndb_version":"2.99","engine":"PostgreSQL Community Edition","db_type":"pgsql","os_type":"Rocky Linux","os_version":"9.9","db_version":"18","provisioning_role":"postgresql","ha_components":[]}]' "ha_components.*object"
  assert_invalid_matrix "duplicate combination" '[{"ndb_version":"2.99","engine":"PostgreSQL Community Edition","db_type":"pgsql","os_type":"Rocky Linux","os_version":"9.9","db_version":"18","provisioning_role":"postgresql"},{"ndb_version":"2.99","engine":"PostgreSQL Community Edition","db_type":"pgsql","os_type":"Rocky Linux","os_version":"9.9","db_version":"18","provisioning_role":"postgresql"}]' "duplicate combination"

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

run_matrix_validator_tests

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
  pass "manifest helper"
}

run_manifest_tests

run_artifact_validate_tests() {
  local tmpdir failure_result success_result cleanup_result
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' RETURN
  failure_result="$tmpdir/failure-result.json"
  success_result="$tmpdir/success-result.json"
  cleanup_result="$tmpdir/cleanup-result.json"

  if "$ROOT_DIR/scripts/artifact_validate.sh" --help >/dev/null; then
    pass "artifact validation help"
  else
    fail "artifact validation help"
  fi

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
    if "$ROOT_DIR/scripts/artifact_validate.sh" \
      --image-name test-image \
      --ndb-version 2.10 \
      --db-version 18 \
      --result-file "$success_result" >/dev/null 2>&1; then
      :
    else
      fail "artifact validation success path unexpectedly failed"
    fi
  )

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

run_test_harness_tests() {
  local tmpdir marker
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' RETURN
  marker="$tmpdir/second-build-finished"

  mkdir -p "$tmpdir/ndb/9.99" "$tmpdir/scripts"
  cp "$ROOT_DIR/test.sh" "$tmpdir/test.sh"

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
