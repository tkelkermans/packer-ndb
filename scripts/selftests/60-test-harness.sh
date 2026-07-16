#!/usr/bin/env bash
# Sourced by scripts/selftest.sh; defines run_*_tests suite functions.
# shellcheck shell=bash

run_test_harness_tests() {
  local tmpdir marker
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' RETURN
  marker="$tmpdir/second-build-finished"

  mkdir -p "$tmpdir/ndb/9.99" "$tmpdir/scripts"
  cp "$ROOT_DIR/test.sh" "$tmpdir/test.sh"
  cp "$ROOT_DIR/scripts/postgres_extensions.sh" "$tmpdir/scripts/postgres_extensions.sh"
  cp "$ROOT_DIR/scripts/source_images.sh" "$tmpdir/scripts/source_images.sh"
  cp "$ROOT_DIR/scripts/args.sh" "$tmpdir/scripts/args.sh"
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
  cp "$ROOT_DIR/scripts/args.sh" "$tmpdir/scripts/args.sh"
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
run_test_harness_build_stdin_isolation_tests() {
  local tmpdir build_log
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' RETURN
  build_log="$tmpdir/builds.log"

  mkdir -p "$tmpdir/ndb/9.99" "$tmpdir/scripts"
  cp "$ROOT_DIR/test.sh" "$tmpdir/test.sh"
  cp "$ROOT_DIR/scripts/postgres_extensions.sh" "$tmpdir/scripts/postgres_extensions.sh"
  cp "$ROOT_DIR/scripts/source_images.sh" "$tmpdir/scripts/source_images.sh"
  cp "$ROOT_DIR/scripts/args.sh" "$tmpdir/scripts/args.sh"
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
run_test_harness_continue_on_error_tests() {
  local tmpdir build_log
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' RETURN
  build_log="$tmpdir/builds.log"

  mkdir -p "$tmpdir/ndb/9.99" "$tmpdir/scripts"
  cp "$ROOT_DIR/test.sh" "$tmpdir/test.sh"
  cp "$ROOT_DIR/scripts/postgres_extensions.sh" "$tmpdir/scripts/postgres_extensions.sh"
  cp "$ROOT_DIR/scripts/source_images.sh" "$tmpdir/scripts/source_images.sh"
  cp "$ROOT_DIR/scripts/args.sh" "$tmpdir/scripts/args.sh"
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
run_test_harness_source_image_uuid_map_tests() {
  local tmpdir build_log
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' RETURN
  build_log="$tmpdir/builds.log"

  mkdir -p "$tmpdir/ndb/9.99" "$tmpdir/scripts"
  cp "$ROOT_DIR/test.sh" "$tmpdir/test.sh"
  cp "$ROOT_DIR/scripts/postgres_extensions.sh" "$tmpdir/scripts/postgres_extensions.sh"
  cp "$ROOT_DIR/scripts/source_images.sh" "$tmpdir/scripts/source_images.sh"
  cp "$ROOT_DIR/scripts/args.sh" "$tmpdir/scripts/args.sh"
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
run_test_harness_preflight_tests() {
  local tmpdir build_log
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' RETURN
  build_log="$tmpdir/builds.log"

  mkdir -p "$tmpdir/ndb/9.99" "$tmpdir/scripts"
  cp "$ROOT_DIR/test.sh" "$tmpdir/test.sh"
  cp "$ROOT_DIR/scripts/postgres_extensions.sh" "$tmpdir/scripts/postgres_extensions.sh"
  cp "$ROOT_DIR/scripts/source_images.sh" "$tmpdir/scripts/source_images.sh"
  cp "$ROOT_DIR/scripts/args.sh" "$tmpdir/scripts/args.sh"
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
run_test_harness_customization_profile_tests() {
  local tmpdir build_log
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' RETURN
  build_log="$tmpdir/builds.log"

  mkdir -p "$tmpdir/ndb/9.99" "$tmpdir/scripts"
  cp "$ROOT_DIR/test.sh" "$tmpdir/test.sh"
  cp "$ROOT_DIR/scripts/postgres_extensions.sh" "$tmpdir/scripts/postgres_extensions.sh"
  cp "$ROOT_DIR/scripts/source_images.sh" "$tmpdir/scripts/source_images.sh"
  cp "$ROOT_DIR/scripts/args.sh" "$tmpdir/scripts/args.sh"
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
