#!/usr/bin/env bash
# Sourced by scripts/selftest.sh; defines run_*_tests suite functions.
# shellcheck shell=bash

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
  cp "$ROOT_DIR/scripts/source_images.sh" "$tmpdir/scripts/source_images.sh"
  cp "$ROOT_DIR/scripts/prism.sh" "$tmpdir/scripts/prism.sh"
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
