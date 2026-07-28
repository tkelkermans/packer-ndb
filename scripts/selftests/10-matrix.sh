#!/usr/bin/env bash
# Sourced by scripts/selftest.sh; defines run_*_tests suite functions.
# shellcheck shell=bash

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
    "os_type": "Debian",
    "os_version": "12",
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
  assert_invalid_matrix "PostgreSQL package pin requires range" '[{"ndb_version":"2.99","engine":"PostgreSQL Community Edition","db_type":"pgsql","os_type":"Debian","os_version":"12","db_version":"18","provisioning_role":"postgresql","postgres_package_version_prefix":"18.0","qualified_extensions":["pg_stat_statements"]}]' "postgres_qualified_version_range"
  assert_invalid_matrix "PostgreSQL package pin major mismatch" '[{"ndb_version":"2.99","engine":"PostgreSQL Community Edition","db_type":"pgsql","os_type":"Debian","os_version":"12","db_version":"18","provisioning_role":"postgresql","postgres_qualified_version_range":"18.0","postgres_package_version_prefix":"17.8","qualified_extensions":["pg_stat_statements"]}]' "postgres_package_version_prefix.*db_version"
  assert_invalid_matrix "PostgreSQL archive flag type" '[{"ndb_version":"2.99","engine":"PostgreSQL Community Edition","db_type":"pgsql","os_type":"Debian","os_version":"12","db_version":"18","provisioning_role":"postgresql","postgres_qualified_version_range":"18.0","postgres_package_version_prefix":"18.0","postgres_package_use_archive":"yes","qualified_extensions":["pg_stat_statements"]}]' "postgres_package_use_archive"
  assert_invalid_matrix "PostgreSQL package pin restricted to Debian and Ubuntu" '[{"ndb_version":"2.99","engine":"PostgreSQL Community Edition","db_type":"pgsql","os_type":"Rocky Linux","os_version":"9.9","db_version":"18","provisioning_role":"postgresql","postgres_qualified_version_range":"18.0","postgres_package_version_prefix":"18.0","qualified_extensions":["pg_stat_statements"],"ha_components":{"patroni":["4.0.7"]}}]' "Debian and Ubuntu"
  assert_invalid_matrix "unknown matrix key" '[{"ndb_version":"2.99","engine":"PostgreSQL Community Edition","db_type":"pgsql","os_type":"Debian","os_version":"12","db_version":"18","provisioning_role":"postgresql","qualified_extensions":["pg_stat_statements"],"ha_components":{"patroni":["4.0.7"]},"unexpected_key":"x"}]' "unknown key"
  assert_invalid_matrix "provisioning_role outside enum" '[{"ndb_version":"2.99","engine":"PostgreSQL Community Edition","db_type":"pgsql","os_type":"Debian","os_version":"12","db_version":"18","provisioning_role":"postgres","qualified_extensions":["pg_stat_statements"],"ha_components":{"patroni":["4.0.7"]}}]' "provisioning_role must be one of"
  assert_invalid_matrix "buildable PostgreSQL rows require ha_components" '[{"ndb_version":"2.99","engine":"PostgreSQL Community Edition","db_type":"pgsql","os_type":"Debian","os_version":"12","db_version":"18","provisioning_role":"postgresql","qualified_extensions":["pg_stat_statements"]}]' "non-empty .ha_components."
  assert_invalid_matrix "buildable PostgreSQL rows reject empty ha_components" '[{"ndb_version":"2.99","engine":"PostgreSQL Community Edition","db_type":"pgsql","os_type":"Debian","os_version":"12","db_version":"18","provisioning_role":"postgresql","qualified_extensions":["pg_stat_statements"],"ha_components":{}}]' "non-empty .ha_components."
  assert_invalid_matrix "buildable rows require images.json coverage" '[{"ndb_version":"2.99","engine":"PostgreSQL Community Edition","db_type":"pgsql","os_type":"Rocky Linux","os_version":"9.9","db_version":"18","provisioning_role":"postgresql","qualified_extensions":["pg_stat_statements"],"ha_components":{"patroni":["4.0.7"]}}]' "no images.json entry"
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
    "os_version": "9.7",
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
run_postgres_debian_package_resolver_tests() {
  local version role_file
  for version in 2.9 2.10; do
    role_file="$ROOT_DIR/ansible/$version/roles/postgres/tasks/main.yml"
    ! grep -q 'apt-cache madison "$POSTGRES_PACKAGE_NAME" |' "$role_file" || fail "postgres role $version uses an early-exit apt-cache pipeline that can fail with rc 141 under pipefail"
  done
  pass "PostgreSQL Debian package resolver avoids pipefail SIGPIPE"
}
