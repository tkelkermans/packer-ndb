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

  "$ROOT_DIR/scripts/manifest.sh" set-json \
    --file "$manifest" \
    --key ".packer.duration_seconds" \
    --json-value "12"

  jq -e '.source_image.name == "rocky" and .packer.duration_seconds == 12' "$manifest" >/dev/null || fail "manifest set JSON"

  "$ROOT_DIR/scripts/manifest.sh" finalize \
    --file "$manifest" \
    --status success \
    --artifact-image-uuid "image-uuid-1"

  jq -e '.status == "success" and .artifact.image_uuid == "image-uuid-1"' "$manifest" >/dev/null || fail "manifest finalize JSON"
  pass "manifest helper"
}

run_manifest_tests

run_artifact_validate_tests() {
  if "$ROOT_DIR/scripts/artifact_validate.sh" --help >/dev/null; then
    pass "artifact validation help"
  else
    fail "artifact validation help"
  fi
}

run_artifact_validate_tests
