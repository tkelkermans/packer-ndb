#!/usr/bin/env bash
# Sourced by scripts/selftest.sh; defines run_*_tests suite functions.
# shellcheck shell=bash

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
run_source_image_catalog_tests() {
  local debian_12_image
  debian_12_image=$(jq -r '."debian-12"' "$ROOT_DIR/images.json")

  [[ "$debian_12_image" == *"debian-12-generic-amd64.qcow2" ]] || fail "Debian 12 source image should use the generic image for maximum device compatibility"
  [[ "$debian_12_image" != *"genericcloud"* ]] || fail "Debian 12 source image should not use genericcloud on AHV"

  pass "source image catalog"
}
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
  grep -q "vm_lifecycle_wait_guest_boot_ready" "$ROOT_DIR/scripts/source_image_ssh_probe.sh" || fail "source image SSH probe does not wait for D-Bus readiness"
  grep -q "/run/dbus/system_bus_socket" "$ROOT_DIR/scripts/vm_lifecycle.sh" || fail "vm lifecycle library lost the D-Bus readiness probe"
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
run_rhel_readiness_helper_tests() {
  local tmpdir output status
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' RETURN
  output="$tmpdir/rhel-readiness.out"

  "$ROOT_DIR/scripts/rhel_readiness.sh" --help >/dev/null || fail "RHEL readiness helper help"

  status=0
  (
    unset NDB_RHEL_9_6_IMAGE_URI NDB_RHEL_9_7_IMAGE_URI NDB_RHEL_9_8_IMAGE_URI NDB_RHEL_10_IMAGE_URI \
      RHEL_96_UUID RHEL_97_UUID RHEL_98_UUID RHEL_10_UUID
    "$ROOT_DIR/scripts/rhel_readiness.sh" >"$output" 2>&1
  ) || status=$?
  [[ "$status" -eq 1 ]] || fail "RHEL readiness helper should fail when RHEL inputs are missing"
  grep -q "RHEL source URI readiness (9.6/9.7 core): incomplete" "$output" || fail "RHEL readiness helper did not report missing URI readiness"
  grep -q "NDB_RHEL_9_6_IMAGE_URI=missing" "$output" || fail "RHEL readiness helper did not report missing RHEL 9.6 URI"
  grep -q "NDB_RHEL_9_8_IMAGE_URI=missing" "$output" || fail "RHEL readiness helper did not report missing RHEL 9.8 URI"
  grep -q "RHEL staged image UUID readiness (9.6/9.7 core): incomplete" "$output" || fail "RHEL readiness helper did not report missing staged UUID readiness"
  grep -q "RHEL_97_UUID=missing" "$output" || fail "RHEL readiness helper did not report missing RHEL 9.7 UUID"
  grep -q "RHEL_10_UUID=missing" "$output" || fail "RHEL readiness helper did not report missing RHEL 10 UUID"
  grep -q "ndb/2.11/matrix.json" "$output" || fail "RHEL readiness helper missing 2.11 coverage audit command"

  (
    export NDB_RHEL_9_6_IMAGE_URI=/private/rhel-9.6.qcow2
    export NDB_RHEL_9_7_IMAGE_URI=/private/rhel-9.7.qcow2
    unset NDB_RHEL_9_8_IMAGE_URI NDB_RHEL_10_IMAGE_URI RHEL_96_UUID RHEL_97_UUID RHEL_98_UUID RHEL_10_UUID
    "$ROOT_DIR/scripts/rhel_readiness.sh" >"$output" 2>&1
  ) || fail "RHEL readiness helper should pass when licensed URI inputs are set"
  grep -q "RHEL source URI readiness (9.6/9.7 core): complete" "$output" || fail "RHEL readiness helper did not report complete URI readiness"
  ! grep -q "/private/rhel" "$output" || fail "RHEL readiness helper printed source image URI values"
  grep -q -- './test.sh --allow-rhel --include-os "Red Hat Enterprise Linux (RHEL)" --preflight --max-parallel 1' "$output" || fail "RHEL readiness helper did not print URI preflight command"

  (
    unset NDB_RHEL_9_6_IMAGE_URI NDB_RHEL_9_7_IMAGE_URI NDB_RHEL_9_8_IMAGE_URI NDB_RHEL_10_IMAGE_URI
    export RHEL_96_UUID=00000000-0000-0000-0000-000000000000
    export RHEL_97_UUID=11111111-1111-1111-1111-111111111111
    unset RHEL_98_UUID RHEL_10_UUID
    "$ROOT_DIR/scripts/rhel_readiness.sh" >"$output" 2>&1
  ) || fail "RHEL readiness helper should pass when staged UUID inputs are set"
  grep -q "RHEL staged image UUID readiness (9.6/9.7 core): complete" "$output" || fail "RHEL readiness helper did not report complete UUID readiness"
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
    unset NDB_RHEL_9_6_IMAGE_URI NDB_RHEL_9_7_IMAGE_URI NDB_RHEL_9_8_IMAGE_URI NDB_RHEL_10_IMAGE_URI \
      RHEL_96_UUID RHEL_97_UUID RHEL_98_UUID RHEL_10_UUID
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
