# PostgreSQL Extension Selection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make PostgreSQL extension installation explicit, individually selectable, and advisory-release-note-aware.

**Architecture:** Add one shell helper as the authoritative installable extension catalog, migrate matrix metadata from default install lists to `qualified_extensions`, and make `build.sh` pass only user-selected extensions to Ansible and artifact validation. The wizard remains a thin interactive wrapper that generates ordinary `build.sh --ci` commands with optional `--extensions`.

**Tech Stack:** Bash, jq, JSON matrix files, Ansible defaults/playbooks, existing Packer workflow.

---

## File Structure

- Create `scripts/postgres_extensions.sh`: shared shell/JQ helper for installable extension catalog, alias normalization, selection parsing, unknown-extension checks, qualification warnings, and `all-qualified` resolution.
- Modify `build.sh`: add `--extensions`, default to no selected extensions, validate selected extensions before Packer, warn for not-release-note-qualified selections, pass selected extensions to Ansible/artifact validation, and expose selected/qualified data in dry-run/manifests.
- Modify `scripts/build_wizard.sh`: replace matrix extension display with individual PostgreSQL extension selection and warning preview.
- Modify `scripts/matrix_validate.sh`: validate `qualified_extensions`, `qualified_extensions_empty_reason`, and reject ambiguous legacy `extensions`.
- Modify `scripts/artifact_validate.sh`: update help text from matrix extensions to selected extensions; behavior can continue consuming JSON.
- Modify `test.sh`: make `--extensions-only` mean "rows with qualified installable extensions" and pass `--extensions all-qualified` for coverage rows.
- Modify `scripts/selftest.sh`: add failing tests first for catalog parsing, matrix validation, CLI behavior, wizard generation, test harness filtering, and documentation guards.
- Modify `ndb/2.9/matrix.json` and `ndb/2.10/matrix.json`: migrate `extensions` to `qualified_extensions` based on release-note table data, not package coverage assumptions.
- Modify `README.md`: explain DBA-selected extensions, qualified advisory warnings, wizard usage, and direct CLI usage.
- Modify `AGENTS.md` and `tasks/lessons.md`: record that qualified extension metadata is not a default install list and that wizard updates are mandatory for extension choice changes.
- Modify `docs/superpowers/plans/2026-04-27-postgresql-extension-selection-implementation.md` and `tasks/todo.md` while tracking execution.

## Naming Rules

Use project extension names everywhere after normalization:

- `pg_vector` -> `pgvector`
- `pg_logical` -> `pglogical`
- `TimescaleDB` -> `timescaledb`
- `pgAudit` -> `pgaudit`
- `PostGIS` -> `postgis`
- `pg lo` -> `lo`

The first implementation exposes only currently installable Ansible-backed extensions:

```text
pg_cron
pglogical
pg_partman
pg_stat_statements
pgvector
pgaudit
postgis
set_user
timescaledb
```

Release-note-qualified but not-yet-installable extensions may appear in `qualified_extensions`, but they must not be selectable until Ansible package/config/create/validate support exists.

---

### Task 1: Add Shared PostgreSQL Extension Catalog

**Files:**
- Create: `scripts/postgres_extensions.sh`
- Modify: `scripts/selftest.sh`

- [x] **Step 1: Add failing selftests for extension helper behavior**

Add a new `run_postgres_extension_helper_tests` function near the other helper/selftest functions in `scripts/selftest.sh`, before wizard tests.

```bash
run_postgres_extension_helper_tests() {
  local tmpdir selected unknown nonqualified resolved skipped
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' RETURN

  # shellcheck source=/dev/null
  source "$ROOT_DIR/scripts/postgres_extensions.sh"

  selected=$(postgres_extensions_selection_to_json "pg_vector, PostGIS,pg_cron")
  jq -e '. == ["pgvector","postgis","pg_cron"]' <<<"$selected" >/dev/null || fail "extension selection normalization"

  selected=$(postgres_extensions_selection_to_json "none")
  jq -e '. == []' <<<"$selected" >/dev/null || fail "extension selection none"

  unknown=$(postgres_extensions_unknown_json '["pgvector","not_real"]')
  jq -e '. == ["not_real"]' <<<"$unknown" >/dev/null || fail "unknown extension detection"

  nonqualified=$(postgres_extensions_not_qualified_json '["pgvector","postgis"]' '["pgvector"]')
  jq -e '. == ["postgis"]' <<<"$nonqualified" >/dev/null || fail "non-qualified extension detection"

  resolved=$(postgres_extensions_resolve_selection_json "all-qualified" '["pgvector","citext","pg_cron"]')
  skipped=$(postgres_extensions_all_qualified_skipped_json '["pgvector","citext","pg_cron"]')
  jq -e '. == ["pgvector","pg_cron"]' <<<"$resolved" >/dev/null || fail "all-qualified installable subset"
  jq -e '. == ["citext"]' <<<"$skipped" >/dev/null || fail "all-qualified skipped non-installable extensions"

  pass "PostgreSQL extension helper"
}

run_postgres_extension_helper_tests
```

- [x] **Step 2: Run the focused selftest and verify it fails**

Run:

```bash
bash scripts/selftest.sh
```

Expected: FAIL because `scripts/postgres_extensions.sh` does not exist.

- [x] **Step 3: Create the shared helper**

Create `scripts/postgres_extensions.sh`:

```bash
#!/usr/bin/env bash

POSTGRES_INSTALLABLE_EXTENSIONS=(
  pg_cron
  pglogical
  pg_partman
  pg_stat_statements
  pgvector
  pgaudit
  postgis
  set_user
  timescaledb
)

postgres_installable_extensions_json() {
  printf '%s\n' "${POSTGRES_INSTALLABLE_EXTENSIONS[@]}" | jq -R . | jq -s .
}

postgres_extension_normalize_name() {
  local value=$1
  value=$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]' | sed -E 's/^ +//; s/ +$//; s/[[:space:]]+/_/g')
  case "$value" in
    pg_vector) printf 'pgvector\n' ;;
    pg_logical) printf 'pglogical\n' ;;
    timescaledb) printf 'timescaledb\n' ;;
    pgaudit) printf 'pgaudit\n' ;;
    postgis) printf 'postgis\n' ;;
    pg_lo) printf 'lo\n' ;;
    *) printf '%s\n' "$value" ;;
  esac
}

postgres_extensions_selection_to_json() {
  local selection=${1:-}
  local value normalized
  local values=()
  local normalized_values=()
  if [[ -z "$selection" || "$selection" == "none" ]]; then
    printf '[]\n'
    return 0
  fi
  if [[ "$selection" == "all-qualified" ]]; then
    echo "Error: all-qualified requires postgres_extensions_resolve_selection_json." >&2
    return 1
  fi
  IFS=',' read -r -a values <<<"$selection"
  for value in "${values[@]}"; do
    normalized=$(postgres_extension_normalize_name "$value")
    [[ -n "$normalized" ]] && normalized_values+=("$normalized")
  done
  printf '%s\n' "${normalized_values[@]}" | jq -R . | jq -s 'unique'
}

postgres_extensions_unknown_json() {
  local selected_json=$1
  local installable_json
  installable_json=$(postgres_installable_extensions_json)
  jq -nc \
    --argjson selected "$selected_json" \
    --argjson installable "$installable_json" \
    '$selected | map(select(. as $name | $installable | index($name) | not))'
}

postgres_extensions_not_qualified_json() {
  local selected_json=$1
  local qualified_json=${2:-[]}
  jq -nc \
    --argjson selected "$selected_json" \
    --argjson qualified "$qualified_json" \
    '$selected | map(select(. as $name | $qualified | index($name) | not))'
}

postgres_extensions_resolve_selection_json() {
  local selection=${1:-none}
  local qualified_json=${2:-[]}
  local installable_json
  if [[ "$selection" != "all-qualified" ]]; then
    postgres_extensions_selection_to_json "$selection"
    return
  fi
  installable_json=$(postgres_installable_extensions_json)
  jq -nc \
    --argjson qualified "$qualified_json" \
    --argjson installable "$installable_json" \
    '$qualified | map(select(. as $name | $installable | index($name))) | unique'
}

postgres_extensions_all_qualified_skipped_json() {
  local qualified_json=${1:-[]}
  local installable_json
  installable_json=$(postgres_installable_extensions_json)
  jq -nc \
    --argjson qualified "$qualified_json" \
    --argjson installable "$installable_json" \
    '$qualified | map(select(. as $name | $installable | index($name) | not)) | unique'
}

postgres_extensions_json_to_csv() {
  jq -r 'if type == "array" and length > 0 then join(",") else "" end'
}
```

- [x] **Step 4: Run the focused selftest and verify it passes**

Run:

```bash
bash scripts/selftest.sh
```

Expected: PASS for `PostgreSQL extension helper`; later tests may still reflect old behavior until subsequent tasks update them.

- [x] **Step 5: Commit Task 1**

```bash
git add scripts/postgres_extensions.sh scripts/selftest.sh
git commit -m "Add PostgreSQL extension catalog helper"
```

---

### Task 2: Validate New Matrix Extension Metadata

**Files:**
- Modify: `scripts/matrix_validate.sh`
- Modify: `scripts/selftest.sh`

This task intentionally continues into Task 3 before committing, because the validator will reject the current real matrices until they are migrated.

- [x] **Step 1: Update failing matrix selftests**

Replace the current legacy extension assertions in `scripts/selftest.sh` with new `qualified_extensions` cases.

Use these exact invalid cases:

```bash
assert_invalid_matrix "qualified_extensions type" '[{"ndb_version":"2.99","engine":"PostgreSQL Community Edition","db_type":"pgsql","os_type":"Rocky Linux","os_version":"9.9","db_version":"18","provisioning_role":"postgresql","qualified_extensions":"pgvector"}]' "qualified_extensions.*list"
assert_invalid_matrix "qualified_extensions element" '[{"ndb_version":"2.99","engine":"PostgreSQL Community Edition","db_type":"pgsql","os_type":"Rocky Linux","os_version":"9.9","db_version":"18","provisioning_role":"postgresql","qualified_extensions":["pgvector",""]}]' "qualified_extensions.*non-empty strings"
assert_invalid_matrix "empty PostgreSQL qualified extensions require reason" '[{"ndb_version":"2.99","engine":"PostgreSQL Community Edition","db_type":"pgsql","os_type":"Rocky Linux","os_version":"9.9","db_version":"18","provisioning_role":"postgresql","qualified_extensions":[]}]' "qualified_extensions_empty_reason"
assert_invalid_matrix "legacy extensions rejected" '[{"ndb_version":"2.99","engine":"PostgreSQL Community Edition","db_type":"pgsql","os_type":"Rocky Linux","os_version":"9.9","db_version":"18","provisioning_role":"postgresql","extensions":["pgvector"],"qualified_extensions":["pgvector"]}]' "legacy.*extensions"
```

- [x] **Step 2: Run the focused selftest and verify it fails**

Run:

```bash
bash scripts/selftest.sh
```

Expected: FAIL because `scripts/matrix_validate.sh` still validates legacy `extensions`.

- [x] **Step 3: Update matrix validator jq rules**

In `scripts/matrix_validate.sh`, replace the `extensions` validation block with:

```jq
(
  select(($entry | has("extensions")))
  | "\(ctx($idx; $entry)): legacy 'extensions' is ambiguous; use 'qualified_extensions' for release-note metadata and --extensions for build-time selection"
),
(
  select(($entry | has("extensions_empty_reason")))
  | "\(ctx($idx; $entry)): legacy 'extensions_empty_reason' is ambiguous; use 'qualified_extensions_empty_reason'"
),
(
  select(($entry | has("qualified_extensions")) and ($entry.qualified_extensions != null) and (($entry.qualified_extensions | type) != "array"))
  | "\(ctx($idx; $entry)): 'qualified_extensions' must be a list or omitted"
),
(
  select(($entry.qualified_extensions | type) == "array" and any($entry.qualified_extensions[]; (nonempty_string | not)))
  | "\(ctx($idx; $entry)): 'qualified_extensions' must only contain non-empty strings"
),
(
  select(
    ($entry.db_type // null) == "pgsql"
    and ($entry.provisioning_role // null) == "postgresql"
    and (
      (($entry | has("qualified_extensions")) | not)
      or ($entry.qualified_extensions == null)
      or (($entry.qualified_extensions | type) == "array" and ($entry.qualified_extensions | length) == 0)
    )
    and (($entry.qualified_extensions_empty_reason // "") | nonempty_string | not)
  )
  | "\(ctx($idx; $entry)): buildable PostgreSQL rows with no qualified extensions must include non-empty 'qualified_extensions_empty_reason'"
),
(
  select(($entry | has("qualified_extensions_empty_reason")) and (($entry.qualified_extensions_empty_reason | nonempty_string) | not))
  | "\(ctx($idx; $entry)): 'qualified_extensions_empty_reason' must be a non-empty string when present"
),
(
  select(($entry.qualified_extensions | type) == "array" and ($entry.qualified_extensions | length) > 0 and ($entry | has("qualified_extensions_empty_reason")))
  | "\(ctx($idx; $entry)): omit 'qualified_extensions_empty_reason' when 'qualified_extensions' contains values"
)
```

- [x] **Step 4: Run the focused selftest and verify it passes**

Run:

```bash
bash scripts/selftest.sh
```

Expected: the matrix tests pass after later test fixtures are migrated from `extensions` to `qualified_extensions`.

- [x] **Step 5: Hold the validator changes for Task 3**

Do not commit after this task. Continue directly to Task 3 so the repository does not contain a validator that rejects its own checked-in matrix files.

---

### Task 3: Migrate Matrix Rows To Qualified Metadata

**Files:**
- Modify: `ndb/2.9/matrix.json`
- Modify: `ndb/2.10/matrix.json`
- Modify: `scripts/selftest.sh`

- [x] **Step 1: Add release-note migration expectations to selftests**

Add a selftest function that proves no legacy keys remain and buildable PostgreSQL rows have qualified metadata:

```bash
run_qualified_extension_matrix_tests() {
  local missing_qualified legacy_keys
  legacy_keys=$(jq -r '
    [.[]
      | select((.provisioning_role // "") == "postgresql")
      | select(has("extensions") or has("extensions_empty_reason"))
    ] | length
  ' "$ROOT_DIR/ndb/2.9/matrix.json" "$ROOT_DIR/ndb/2.10/matrix.json")
  [[ "$legacy_keys" == "0" ]] || fail "PostgreSQL matrix rows still use legacy extension keys"

  missing_qualified=$(jq -r '
    [.[]
      | select((.db_type // "") == "pgsql" and (.provisioning_role // "") == "postgresql")
      | select((has("qualified_extensions") | not) and ((.qualified_extensions_empty_reason // "") == ""))
    ] | length
  ' "$ROOT_DIR/ndb/2.9/matrix.json" "$ROOT_DIR/ndb/2.10/matrix.json")
  [[ "$missing_qualified" == "0" ]] || fail "buildable PostgreSQL rows missing qualified extension metadata"

  pass "qualified extension matrix metadata"
}

run_qualified_extension_matrix_tests
```

- [x] **Step 2: Run the selftest and verify it fails**

Run:

```bash
bash scripts/selftest.sh
```

Expected: FAIL because the real matrices still use `extensions`.

- [x] **Step 3: Migrate real matrix files**

Use `jq` to transform existing keys, then manually tighten the values against release-note tables:

```bash
tmp=$(mktemp)
jq 'map(
  if (.db_type == "pgsql" and (.provisioning_role // "") == "postgresql") then
    .qualified_extensions = (.extensions // [])
    | del(.extensions)
    | if has("extensions_empty_reason") then
        .qualified_extensions_empty_reason = .extensions_empty_reason
        | del(.extensions_empty_reason)
      else
        .
      end
  else
    del(.extensions, .extensions_empty_reason)
  end
)' ndb/2.9/matrix.json > "$tmp" && mv "$tmp" ndb/2.9/matrix.json

tmp=$(mktemp)
jq 'map(
  if (.db_type == "pgsql" and (.provisioning_role // "") == "postgresql") then
    .qualified_extensions = (.extensions // [])
    | del(.extensions)
    | if has("extensions_empty_reason") then
        .qualified_extensions_empty_reason = .extensions_empty_reason
        | del(.extensions_empty_reason)
      else
        .
      end
  else
    del(.extensions, .extensions_empty_reason)
  end
)' ndb/2.10/matrix.json > "$tmp" && mv "$tmp" ndb/2.10/matrix.json
```

Then correct the buildable PostgreSQL rows so `qualified_extensions` represents the exact release-note qualification table, not our installable package coverage.

For NDB 2.9 release notes:

- RHEL 9.4 + PostgreSQL 16 qualifies `pgvector`, `timescaledb`, `pgaudit`, `pg_cron`, `set_user`, `postgis`, `pg_partman`, `pglogical`, `pg_stat_statements`.
- RHEL 8.4 + PostgreSQL 14 qualifies `timescaledb`, `pgaudit`, `pg_cron`, `set_user`, `postgis`.
- RHEL 8.6 + PostgreSQL 14 qualifies `timescaledb`, `pgaudit`, `pg_cron`, `set_user`, `postgis`.
- RHEL 8.10 + EPAS 15.6 qualifies `pgvector`.

For NDB 2.10 release notes:

- RHEL 9.4 + PostgreSQL 16.9 qualifies `pgvector`, `timescaledb`, `pgaudit`, `pg_cron`, `set_user`, `postgis`, `pg_partman`, `pglogical`, `pg_stat_statements`, `citext`, `dblink`, `pg_stat_monitor`, `pg_trgm`, `pgcrypto`, `pgstattuple`, `plpgsql`, `postgres_fdw`, `tablefunc`, `lo`.
- RHEL 8.4 + PostgreSQL 14 qualifies `timescaledb`, `pgaudit`, `pg_cron`, `set_user`, `postgis`.
- RHEL 8.6 + PostgreSQL 14 qualifies `timescaledb`, `pgaudit`, `pg_cron`, `set_user`, `postgis`.
- RHEL 8.10 + EPAS 15.6 qualifies `pgvector`.

If a buildable row does not exactly match one of those release-note rows, set:

```json
"qualified_extensions": [],
"qualified_extensions_empty_reason": "Nutanix release notes do not list qualified PostgreSQL extensions for this exact OS and PostgreSQL version."
```

- [x] **Step 4: Format and validate matrices**

Run:

```bash
jq . ndb/2.9/matrix.json > /tmp/ndb-2.9-matrix.json && mv /tmp/ndb-2.9-matrix.json ndb/2.9/matrix.json
jq . ndb/2.10/matrix.json > /tmp/ndb-2.10-matrix.json && mv /tmp/ndb-2.10-matrix.json ndb/2.10/matrix.json
bash scripts/matrix_validate.sh ndb/2.9/matrix.json ndb/2.10/matrix.json
```

Expected: both matrix files validate successfully.

- [x] **Step 5: Run selftests**

Run:

```bash
bash scripts/selftest.sh
```

Expected: matrix metadata tests pass after selftest fixtures are migrated.

- [x] **Step 6: Commit Tasks 2 and 3 together**

```bash
git add scripts/matrix_validate.sh scripts/selftest.sh ndb/2.9/matrix.json ndb/2.10/matrix.json
git commit -m "Migrate PostgreSQL matrix extensions to qualified metadata"
```

---

### Task 4: Add `build.sh --extensions`

**Files:**
- Modify: `build.sh`
- Modify: `scripts/selftest.sh`

- [ ] **Step 1: Add failing CLI/dry-run selftests**

Add tests that call `build.sh --dry-run` with synthetic or real matrix rows and assert generated vars:

```bash
run_build_extension_selection_tests() {
  local output

  output=$(./build.sh --ci --dry-run --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18)
  grep -q '"postgres_extensions": \[\]' <<<"$output" || fail "default build should select no PostgreSQL extensions"
  grep -q '"selected_extensions": \[\]' <<<"$output" || fail "dry-run should show selected extensions"

  output=$(./build.sh --ci --dry-run --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18 --extensions pgvector,postgis 2>&1)
  grep -q '"postgres_extensions": \[' <<<"$output" || fail "selected extensions missing from generated vars"
  grep -q '"pgvector"' <<<"$output" || fail "pgvector missing from generated vars"
  grep -q '"postgis"' <<<"$output" || fail "postgis missing from generated vars"
  grep -q "not release-note-qualified for this matrix row" <<<"$output" || fail "non-qualified extension warning missing"

  if ./build.sh --ci --dry-run --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18 --extensions not_real >/dev/null 2>&1; then
    fail "unknown PostgreSQL extension unexpectedly passed"
  fi

  if ./build.sh --ci --dry-run --ndb-version 2.10 --db-type mongodb --os "Rocky Linux" --os-version 9.7 --db-version 8.0 --extensions pgvector >/dev/null 2>&1; then
    fail "MongoDB build accepted PostgreSQL extensions"
  fi

  pass "build.sh PostgreSQL extension selection"
}

run_build_extension_selection_tests
```

- [ ] **Step 2: Run selftests and verify they fail**

Run:

```bash
bash scripts/selftest.sh
```

Expected: FAIL because `build.sh` has no `--extensions` option and still reads matrix `extensions`.

- [ ] **Step 3: Source the helper and add CLI state**

Near the top of `build.sh`, after helper path setup:

```bash
# shellcheck source=scripts/postgres_extensions.sh
source "${SCRIPT_DIR}/scripts/postgres_extensions.sh"
```

Add usage text:

```text
  --extensions LIST        PostgreSQL extensions to install: none, all-qualified, or comma-separated names
```

Add state before argument parsing:

```bash
POSTGRES_EXTENSIONS_SELECTION="none"
POSTGRES_SELECTED_EXTENSIONS_JSON="[]"
POSTGRES_QUALIFIED_EXTENSIONS_JSON="[]"
POSTGRES_EXTENSION_WARNINGS_JSON="[]"
```

Add parser case:

```bash
    --extensions)
      POSTGRES_EXTENSIONS_SELECTION="$2"
      shift
      ;;
```

- [ ] **Step 4: Resolve selected extensions after matrix row selection**

Replace the current matrix extension assignment:

```bash
POSTGRES_EXTENSIONS_JSON=$(echo "$CONFIG" | jq -c '.extensions // []')
```

with this block after `PROVISIONING_ROLE` has been assigned:

```bash
PROVISIONING_ROLE=$(echo "$CONFIG" | jq -r '.provisioning_role // "postgresql"')
POSTGRES_QUALIFIED_EXTENSIONS_JSON=$(echo "$CONFIG" | jq -c '.qualified_extensions // []')

if [[ "$PROVISIONING_ROLE" != "postgresql" && "$POSTGRES_EXTENSIONS_SELECTION" != "none" ]]; then
  echo "Error: --extensions is only valid for PostgreSQL builds." >&2
  exit 1
fi

POSTGRES_SELECTED_EXTENSIONS_JSON=$(postgres_extensions_resolve_selection_json "$POSTGRES_EXTENSIONS_SELECTION" "$POSTGRES_QUALIFIED_EXTENSIONS_JSON")
POSTGRES_UNKNOWN_EXTENSIONS_JSON=$(postgres_extensions_unknown_json "$POSTGRES_SELECTED_EXTENSIONS_JSON")
if [[ "$(jq 'length' <<<"$POSTGRES_UNKNOWN_EXTENSIONS_JSON")" -gt 0 ]]; then
  echo "Error: Unknown or not installable PostgreSQL extensions: $(jq -r 'join(", ")' <<<"$POSTGRES_UNKNOWN_EXTENSIONS_JSON")" >&2
  exit 1
fi

POSTGRES_EXTENSION_WARNINGS_JSON=$(postgres_extensions_not_qualified_json "$POSTGRES_SELECTED_EXTENSIONS_JSON" "$POSTGRES_QUALIFIED_EXTENSIONS_JSON")
if [[ "$(jq 'length' <<<"$POSTGRES_EXTENSION_WARNINGS_JSON")" -gt 0 ]]; then
  while IFS= read -r extension_name; do
    echo "Warning: Extension ${extension_name} is installable by this tool, but is not release-note-qualified for this matrix row." >&2
  done < <(jq -r '.[]' <<<"$POSTGRES_EXTENSION_WARNINGS_JSON")
fi

if [[ "$POSTGRES_EXTENSIONS_SELECTION" == "all-qualified" ]]; then
  POSTGRES_ALL_QUALIFIED_SKIPPED_JSON=$(postgres_extensions_all_qualified_skipped_json "$POSTGRES_QUALIFIED_EXTENSIONS_JSON")
  if [[ "$(jq 'length' <<<"$POSTGRES_ALL_QUALIFIED_SKIPPED_JSON")" -gt 0 ]]; then
    echo "Warning: Some release-note-qualified extensions are not installable by this tool yet and were skipped: $(jq -r 'join(", ")' <<<"$POSTGRES_ALL_QUALIFIED_SKIPPED_JSON")" >&2
  fi
fi
```

Remove the old later `PROVISIONING_ROLE=$(...)` duplicate assignment. Update the `generate_ansible_vars_json` call to pass `POSTGRES_SELECTED_EXTENSIONS_JSON`.

- [ ] **Step 5: Add dry-run and manifest visibility**

In the dry-run output after `Provisioning role`, add:

```bash
  Qualified PostgreSQL extensions: $(jq -r 'if length > 0 then join(", ") else "none" end' <<<"$POSTGRES_QUALIFIED_EXTENSIONS_JSON")
  Selected PostgreSQL extensions: $(jq -r 'if length > 0 then join(", ") else "none" end' <<<"$POSTGRES_SELECTED_EXTENSIONS_JSON")
```

After manifest init, add:

```bash
"$MANIFEST_HELPER" set-json --file "$MANIFEST_FILE" --key ".extensions.qualified" --json-value "$POSTGRES_QUALIFIED_EXTENSIONS_JSON"
"$MANIFEST_HELPER" set-json --file "$MANIFEST_FILE" --key ".extensions.selected" --json-value "$POSTGRES_SELECTED_EXTENSIONS_JSON"
"$MANIFEST_HELPER" set-json --file "$MANIFEST_FILE" --key ".extensions.not_release_note_qualified" --json-value "$POSTGRES_EXTENSION_WARNINGS_JSON"
```

- [ ] **Step 6: Pass selected extensions to artifact validation**

Replace the artifact validation argument:

```bash
--extensions "$POSTGRES_EXTENSIONS_JSON"
```

with:

```bash
--extensions "$POSTGRES_SELECTED_EXTENSIONS_JSON"
```

- [ ] **Step 7: Run selftests**

Run:

```bash
bash scripts/selftest.sh
```

Expected: build extension selection tests pass.

- [ ] **Step 8: Commit Task 4**

```bash
git add build.sh scripts/selftest.sh
git commit -m "Add explicit PostgreSQL extension selection"
```

---

### Task 5: Update Artifact Validation And Test Harness Coverage

**Files:**
- Modify: `scripts/artifact_validate.sh`
- Modify: `test.sh`
- Modify: `scripts/selftest.sh`

- [ ] **Step 1: Update failing selftests for harness behavior**

Replace the old `run_test_harness_extensions_only_tests` fixture fields with `qualified_extensions`.

Update the fake `build.sh` parser in that test to capture `--extensions`:

```bash
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
```

Expected assertion:

```bash
[[ "$(cat "$build_log")" == "1|all-qualified" ]] || fail "test harness extensions-only did not select qualified extension row with all-qualified"
```

- [ ] **Step 2: Run selftests and verify failure**

Run:

```bash
bash scripts/selftest.sh
```

Expected: FAIL because `test.sh --extensions-only` still filters on `.extensions`.

- [ ] **Step 3: Update `test.sh` filtering and build args**

Replace:

```bash
extensions_count=$(echo "$build" | jq -r '(.extensions // []) | length')
if [[ "$EXTENSIONS_ONLY" == "true" && "$extensions_count" -eq 0 ]]; then
  continue
fi
```

with:

```bash
qualified_installable_extensions_count=$(echo "$build" | jq -r '
  (.qualified_extensions // [])
  | map(select(. as $name | ["pg_cron","pglogical","pg_partman","pg_stat_statements","pgvector","pgaudit","postgis","set_user","timescaledb"] | index($name)))
  | length
')
if [[ "$EXTENSIONS_ONLY" == "true" && "$qualified_installable_extensions_count" -eq 0 ]]; then
  continue
fi
```

Inside `BUILD_ARGS`, add:

```bash
if [[ "$EXTENSIONS_ONLY" == "true" && "$provisioning_role" == "postgresql" ]]; then
  BUILD_ARGS+=(--extensions all-qualified)
fi
```

Update usage text:

```text
  --extensions-only     Only run PostgreSQL rows with installable qualified extensions and select --extensions all-qualified
```

- [ ] **Step 4: Update artifact validation help**

In `scripts/artifact_validate.sh`, replace:

```text
  --extensions JSON      Matrix extension list JSON (default: [])
```

with:

```text
  --extensions JSON      Selected PostgreSQL extensions JSON (default: [])
```

- [x] **Step 5: Run selftests**

Run:

```bash
bash scripts/selftest.sh
```

Expected: harness tests and artifact validation tests pass.

- [ ] **Step 6: Commit Task 5**

```bash
git add test.sh scripts/artifact_validate.sh scripts/selftest.sh
git commit -m "Update extension coverage harness semantics"
```

---

### Task 6: Add Individual Extension Selection To Wizard

**Files:**
- Modify: `scripts/build_wizard.sh`
- Modify: `scripts/selftest.sh`

- [ ] **Step 1: Add failing wizard selftests**

Update the wizard fixture matrix rows from `extensions` to `qualified_extensions`.

Add a test that selects individual extensions and asserts command generation:

```bash
(
  cd "$tmpdir"
  printf '1\n1\n1\n1\n1 3\n1\n1\n1\n' | "$wizard" >"$output" 2>&1
) || fail "wizard individual PostgreSQL extension selection failed"
grep -Fq "Qualified extensions: pgvector, postgis" "$output" || fail "wizard did not show qualified extensions"
grep -Fq "Selected extensions: pgvector, pg_cron" "$output" || fail "wizard did not show selected extensions"
grep -Fq -- "--extensions pgvector,pg_cron" "$output" || fail "wizard command missing selected extensions"
grep -Fq "not release-note-qualified for this matrix row" "$output" || fail "wizard did not warn for advanced extension selection"
```

This input sequence assumes the extension prompt appears after action selection and before source-image/customization prompts. The test must exercise:

- PostgreSQL row selection.
- Extension prompt defaulting to none.
- Multi-select of one qualified and one advanced installable extension.
- Warning preview before command execution.

- [ ] **Step 2: Run selftests and verify failure**

Run:

```bash
bash scripts/selftest.sh
```

Expected: FAIL because the wizard still displays matrix extension lists and has no selection prompt.

- [ ] **Step 3: Source the helper and update row filters**

Near the top of `scripts/build_wizard.sh`:

```bash
# shellcheck source=scripts/postgres_extensions.sh
source "$ROOT_DIR/scripts/postgres_extensions.sh"
```

Update `load_buildable_rows` filters:

```bash
pgsql_extensions)
  jq -c '.[] | select((.provisioning_role // "") == "postgresql" and ((.qualified_extensions // []) | length) > 0)' "$matrix_file"
  ;;
pgsql_no_extensions)
  jq -c '.[] | select((.provisioning_role // "") == "postgresql" and ((.qualified_extensions // []) | length) == 0)' "$matrix_file"
  ;;
```

Change menu labels:

```text
PostgreSQL rows with qualified extensions
PostgreSQL rows without qualified extensions
```

- [ ] **Step 4: Add multi-select prompt helper**

Add this function before `append_source_args`:

```bash
prompt_multi_select() {
  local title=$1
  shift
  local options=("$@")
  local value token index
  printf '\n%s\n' "$title" >&2
  printf '  0. None\n' >&2
  for index in "${!options[@]}"; do
    printf '  %d. %s\n' "$((index + 1))" "${options[$index]}" >&2
  done
  while true; do
    printf 'Choose numbers separated by spaces [0-%d]: ' "${#options[@]}" >&2
    IFS= read -r value || fail "No selection provided for ${title}."
    [[ -z "$value" || "$value" == "0" ]] && return 0
    local selected=()
    local valid=true
    for token in $value; do
      if [[ "$token" =~ ^[0-9]+$ ]] && (( token >= 1 && token <= ${#options[@]} )); then
        selected+=("${options[$((token - 1))]%% *}")
      else
        valid=false
      fi
    done
    if [[ "$valid" == "true" ]]; then
      printf '%s\n' "${selected[@]}" | awk '!seen[$0]++'
      return 0
    fi
    printf 'Invalid selection. Please try again.\n' >&2
  done
}
```

- [ ] **Step 5: Add extension selection flow**

Add a function:

```bash
append_postgres_extension_args() {
  local row_json=$1
  local qualified_json installable_json qualified_installable_json advanced_json selected_json selected_csv warnings_json
  local options=() extension

  qualified_json=$(jq -c '.qualified_extensions // []' <<<"$row_json")
  installable_json=$(postgres_installable_extensions_json)
  qualified_installable_json=$(jq -nc --argjson qualified "$qualified_json" --argjson installable "$installable_json" '$qualified | map(select(. as $name | $installable | index($name)))')
  advanced_json=$(jq -nc --argjson qualified "$qualified_json" --argjson installable "$installable_json" '$installable | map(select(. as $name | $qualified | index($name) | not))')

  printf '\nPostgreSQL extensions are optional. Default: none.\n'
  printf 'Qualified extensions: %s\n' "$(jq -r 'if length > 0 then join(", ") else "none" end' <<<"$qualified_json")"

  while IFS= read -r extension; do
    options+=("${extension} (qualified)")
  done < <(jq -r '.[]' <<<"$qualified_installable_json")
  while IFS= read -r extension; do
    options+=("${extension} (advanced: not release-note-qualified for this row)")
  done < <(jq -r '.[]' <<<"$advanced_json")

  if (( ${#options[@]} == 0 )); then
    printf 'No installable PostgreSQL extensions are available for selection.\n'
    return 0
  fi

  selected_json=$(prompt_multi_select "PostgreSQL extensions to install" "${options[@]}" | jq -R . | jq -s 'map(select(length > 0))')
  selected_csv=$(postgres_extensions_json_to_csv <<<"$selected_json")
  if [[ -n "$selected_csv" ]]; then
    COMMAND_ARGS+=("--extensions" "$selected_csv")
    warnings_json=$(postgres_extensions_not_qualified_json "$selected_json" "$qualified_json")
    if [[ "$(jq 'length' <<<"$warnings_json")" -gt 0 ]]; then
      while IFS= read -r extension; do
        printf 'Warning: Extension %s is installable by this tool, but is not release-note-qualified for this matrix row.\n' "$extension"
      done < <(jq -r '.[]' <<<"$warnings_json")
    fi
    printf 'Selected extensions: %s\n' "$(jq -r 'join(", ")' <<<"$selected_json")"
  else
    printf 'Selected extensions: none\n'
  fi
}
```

Call it after matrix selector args are appended and before source/customization prompts:

```bash
if [[ "$(jq -r '.provisioning_role' <<<"$row_json")" == "postgresql" ]]; then
  append_postgres_extension_args "$row_json"
fi
```

- [ ] **Step 6: Update row details and labels**

Replace extension display text with qualified/selected language:

```bash
extensions=$(jq -c '.qualified_extensions // []' <<<"$row_json" | join_json_array)
if [[ -n "$extensions" ]]; then
  printf '  Qualified extensions: %s\n' "$extensions"
else
  printf '  Qualified extensions: none listed for this row.\n'
  reason=$(jq -r '.qualified_extensions_empty_reason // ""' <<<"$row_json")
  [[ -n "$reason" ]] && printf '  Qualified extension reason: %s\n' "$reason"
fi
```

- [ ] **Step 7: Run selftests**

Run:

```bash
bash scripts/selftest.sh
```

Expected: wizard tests pass with individual extension selection and warnings.

- [ ] **Step 8: Commit Task 6**

```bash
git add scripts/build_wizard.sh scripts/selftest.sh
git commit -m "Add wizard PostgreSQL extension selection"
```

---

### Task 7: Update Documentation And Agent Memory

**Files:**
- Modify: `README.md`
- Modify: `AGENTS.md`
- Modify: `tasks/lessons.md`
- Modify: `scripts/selftest.sh`

- [ ] **Step 1: Add failing documentation guards**

Update `run_documentation_tests` or the equivalent README/AGENTS selftest block in `scripts/selftest.sh`:

```bash
grep -q "PostgreSQL extensions are optional" "$ROOT_DIR/README.md" || fail "README missing optional PostgreSQL extension guidance"
grep -q -- "--extensions pgvector,postgis" "$ROOT_DIR/README.md" || fail "README missing direct PostgreSQL extension CLI example"
grep -q "not release-note-qualified for this matrix row" "$ROOT_DIR/README.md" || fail "README missing advisory qualification warning wording"
grep -q "qualified_extensions" "$ROOT_DIR/AGENTS.md" || fail "AGENTS missing qualified extension metadata guidance"
grep -q "Do not treat qualified_extensions as default installs" "$ROOT_DIR/tasks/lessons.md" || fail "lessons missing qualified extension correction"
```

- [ ] **Step 2: Run selftests and verify failure**

Run:

```bash
bash scripts/selftest.sh
```

Expected: FAIL until docs are updated.

- [ ] **Step 3: Update README beginner guidance**

Add or replace the PostgreSQL extension section with beginner wording:

```markdown
### PostgreSQL Extensions

PostgreSQL extensions are optional. The tool installs no extensions unless you select them.

For most DBA workflows, select only the extensions required by the application. Nutanix release notes list which extensions are qualified for specific OS and PostgreSQL combinations; this project stores that release-note metadata as `qualified_extensions` in each PostgreSQL matrix row.

The wizard is the easiest way to choose extensions for one image:

```sh
scripts/build_wizard.sh
```

Direct CLI users can pass a comma-separated list:

```sh
./build.sh --ci --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18 --extensions pgvector,postgis
```

If you choose an installable extension that is not listed as qualified for the selected row, the build continues and prints this warning:

```text
Extension <name> is installable by this tool, but is not release-note-qualified for this matrix row.
```

Use `--extensions none` or omit `--extensions` to install no extensions. Use `--extensions all-qualified` only for coverage-style builds where you want every release-note-qualified extension that this project can install today.
```

- [ ] **Step 4: Update matrix authoring guidance in README**

Replace references to `extensions` and `extensions_empty_reason` with:

```markdown
- `qualified_extensions` records the PostgreSQL extensions listed in Nutanix release notes for that exact row.
- `qualified_extensions_empty_reason` explains why no qualified extensions are listed for a buildable PostgreSQL row.
- Do not use `qualified_extensions` as a default install list. Extension installation is a per-build choice via the wizard or `build.sh --extensions`.
```

- [ ] **Step 5: Update agent memory**

Add to `AGENTS.md`:

```markdown
- PostgreSQL extension matrix data is advisory release-note metadata. Use `qualified_extensions` for what Nutanix release notes qualify, and use build-time `--extensions` / wizard selections for what gets installed.
- Do not treat `qualified_extensions` as default installs. Default selected extensions should be empty.
- When changing extension choices, warnings, validation defaults, or generated flags, update `scripts/build_wizard.sh` in the same change.
```

Add to `tasks/lessons.md`:

```markdown
- Do not treat qualified_extensions as default installs. They are release-note qualification metadata only; DBAs should explicitly select individual PostgreSQL extensions per build.
```

- [x] **Step 6: Run selftests**

Run:

```bash
bash scripts/selftest.sh
```

Expected: documentation guards pass.

- [ ] **Step 7: Commit Task 7**

```bash
git add README.md AGENTS.md tasks/lessons.md scripts/selftest.sh
git commit -m "Document advisory PostgreSQL extension selection"
```

---

### Task 8: Final Offline Verification

**Files:**
- Modify only if verification finds a real defect in files from prior tasks.

- [ ] **Step 1: Run shell syntax checks**

Run:

```bash
bash -n build.sh test.sh scripts/*.sh
```

Expected: no output and exit 0.

- [x] **Step 2: Run selftests**

Run:

```bash
bash scripts/selftest.sh
```

Expected: all tests pass.

- [ ] **Step 3: Run matrix validation**

Run:

```bash
bash scripts/matrix_validate.sh ndb/2.9/matrix.json ndb/2.10/matrix.json
```

Expected: both matrix files validate successfully.

- [ ] **Step 4: Run representative dry-runs**

Run:

```bash
./build.sh --ci --dry-run --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18
./build.sh --ci --dry-run --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18 --extensions pgvector,postgis
./build.sh --ci --dry-run --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18 --extensions none
./build.sh --ci --dry-run --ndb-version 2.10 --db-type mongodb --os "Rocky Linux" --os-version 9.7 --db-version 8.0
```

Expected:

- Default PostgreSQL dry-run shows selected extensions as none.
- Selected extension dry-run shows `postgres_extensions` with only `pgvector` and `postgis`.
- Non-qualified selected extensions print advisory warnings.
- MongoDB dry-run still works.

- [ ] **Step 5: Run Packer and Ansible static checks**

Run:

```bash
packer fmt -check packer
packer validate \
  -var "pc_username=dummy" \
  -var "pc_password=dummy" \
  -var "pc_ip=127.0.0.1" \
  -var "cluster_name=dummy" \
  -var "subnet_name=dummy" \
  -var "source_image_uri=https://example.invalid/source.qcow2" \
  -var "ndb_version=2.10" \
  -var "os_type=Rocky Linux" \
  -var "os_version=9.7" \
  -var "db_type=pgsql" \
  -var "db_version=18" \
  -var "ansible_site_playbook=ansible/2.10/playbooks/site.yml" \
  -var "ansible_config_path=ANSIBLE_CONFIG=ansible/2.10/ansible.cfg" \
  -var "ansible_roles_path_env=" \
  -var "ansible_extra_vars_file=/tmp/nonexistent.json" \
  -var "image_name=ndb-test" \
  -var "vm_name=ndb-test" \
  -var "ssh_public_key=dummy" \
  packer
ANSIBLE_CONFIG=ansible/2.9/ansible.cfg ansible-playbook --syntax-check ansible/2.9/playbooks/site.yml
ANSIBLE_CONFIG=ansible/2.10/ansible.cfg ansible-playbook --syntax-check ansible/2.10/playbooks/site.yml
```

Expected: all static checks pass.

- [ ] **Step 6: Run diff hygiene**

Run:

```bash
git diff --check
git status --short
```

Expected: no whitespace errors; only intended files modified.

- [ ] **Step 7: Update task review notes**

Add an `Active Plan Review` section to `tasks/todo.md` summarizing:

- `qualified_extensions` migrated to release-note metadata.
- Default selected extensions are empty.
- `build.sh --extensions` controls installation.
- Wizard supports individual selections and warnings.
- Offline verification result.

- [ ] **Step 8: Commit final verification notes**

```bash
git add tasks/todo.md
git commit -m "Record PostgreSQL extension selection verification"
```

---

## Execution Notes

- Use `apply_patch` for manual edits.
- Keep commits task-sized.
- Do not run live Prism builds until offline verification passes.
- If live validation is requested later, prefer a small representative PostgreSQL row with `--extensions pgvector,postgis` before attempting coverage-style `--extensions all-qualified`.
- If implementation reveals that release-note table rows are not represented as buildable matrix rows, leave `qualified_extensions` empty for unmatched buildable rows and document the reason rather than guessing.

## Self-Review

- Spec coverage: the plan covers advisory qualification, default empty selection, individual DBA selection, wizard updates, matrix migration, validation semantics, manifest visibility, README updates, and agent memory updates.
- Placeholder scan: no unresolved placeholders are intentionally left in the implementation steps.
- Scope check: the plan avoids adding new PostgreSQL extension package support beyond the existing Ansible-backed catalog.
- Type consistency: matrix metadata uses `qualified_extensions` and `qualified_extensions_empty_reason`; build-time selection uses `--extensions` and `selected_extensions`/`postgres_extensions`.
