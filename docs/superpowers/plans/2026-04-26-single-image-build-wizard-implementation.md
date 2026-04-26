# Single-Image Build Wizard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a shell-only single-image wizard that helps beginners generate and optionally run safe `./build.sh` commands.

**Architecture:** Add `scripts/build_wizard.sh` as a thin interactive wrapper around `build.sh`. The wizard reads matrix data with `jq`, shows PostgreSQL extension information from the selected row, composes a command array, prints the shell-quoted command, and optionally executes it from the repository root.

**Tech Stack:** Bash, `jq`, existing `build.sh`, existing `scripts/selftest.sh`, Markdown README.

---

## Scope Check

The approved design covers one subsystem: an interactive single-image command composer. Matrix validation orchestration, rich TUI dependencies, and ad hoc PostgreSQL extension selection are out of scope.

## File Structure

- Create `scripts/build_wizard.sh`: interactive menu flow, matrix row loading, extension display, command composition, final run-or-print choice.
- Modify `scripts/selftest.sh`: offline tests that copy the wizard into a temporary mini-repository, feed menu selections through stdin, and assert generated command output.
- Modify `README.md`: beginner entrypoint documentation for the wizard, including PostgreSQL extension behavior.
- Modify `tasks/todo.md`: execution tracker for this implementation.

---

### Task 1: Add Failing Wizard Selftests

**Files:**
- Modify: `scripts/selftest.sh`
- Modify: `tasks/todo.md`

- [ ] **Step 1: Add the active implementation checklist to `tasks/todo.md`**

Insert this section at the top of `tasks/todo.md`, above the current active design section:

```markdown
# Active Plan: Single-Image Build Wizard Implementation

- [ ] Add failing offline wizard selftests.
- [ ] Implement `scripts/build_wizard.sh`.
- [ ] Add PostgreSQL extension awareness to the wizard preview.
- [ ] Add source image and customization choices.
- [ ] Update the README beginner workflow.
- [ ] Run offline verification.
- [ ] Commit the implementation.

# Active Plan Review: Single-Image Build Wizard Implementation

- Implementation follows the approved design in `docs/superpowers/specs/2026-04-26-single-image-build-wizard-design.md`.
- The wizard remains a thin shell wrapper that prints ordinary `build.sh` commands.
- PostgreSQL extensions remain matrix-driven; the wizard displays them but does not invent a new extension flag.
```

- [ ] **Step 2: Add wizard tests to `scripts/selftest.sh`**

Add this function near the other shell harness tests, before the final README/static checks:

```bash
run_build_wizard_tests() {
  local tmpdir output build_log wizard
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' RETURN
  output="$tmpdir/wizard.out"
  build_log="$tmpdir/build.log"
  wizard="$tmpdir/scripts/build_wizard.sh"

  mkdir -p "$tmpdir/ndb/9.99" "$tmpdir/scripts" "$tmpdir/customizations/profiles"
  cp "$ROOT_DIR/scripts/build_wizard.sh" "$wizard"
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
    "extensions": ["pgvector", "postgis"]
  },
  {
    "ndb_version": "9.99",
    "engine": "PostgreSQL Community Edition",
    "db_type": "pgsql",
    "os_type": "Ubuntu",
    "os_version": "22.04",
    "db_version": "15",
    "provisioning_role": "postgresql",
    "extensions": [],
    "extensions_empty_reason": "Self-test empty extension row."
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
    "engine": "Metadata Only",
    "db_type": "pgsql",
    "os_type": "RHEL",
    "os_version": "9.9",
    "db_version": "14",
    "provisioning_role": "metadata",
    "extensions": ["pg_stat_statements"]
  }
]
JSON

  cat > "$tmpdir/customizations/profiles/enterprise-example.yml" <<'YAML'
name: enterprise-example
phases: {}
YAML

  cat > "$tmpdir/build.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%q ' "$@" > "${NDB_SELFTEST_BUILD_LOG:?}"
printf '\n' >> "${NDB_SELFTEST_BUILD_LOG:?}"
SH
  chmod +x "$tmpdir/build.sh"

  (
    cd "$tmpdir"
    printf '1\n1\n1\n1\n1\n1\n1\n' | "$wizard" >"$output" 2>&1
  ) || fail "wizard default PostgreSQL dry-run failed"
  grep -Fq "Extensions: pgvector, postgis" "$output" || fail "wizard did not show PostgreSQL extension list"
  grep -Fq "./build.sh --ci --dry-run --ndb-version 9.99 --db-type pgsql --os 'Rocky Linux' --os-version 9.9 --db-version 16" "$output" || fail "wizard dry-run command mismatch"
  ! grep -Fq "Metadata Only" "$output" || fail "wizard exposed metadata-only rows"

  (
    cd "$tmpdir"
    printf '1\n1\n2\n1\n1\n1\n1\n' | "$wizard" >"$output" 2>&1
  ) || fail "wizard empty-extension PostgreSQL dry-run failed"
  grep -Fq "No PostgreSQL extensions requested." "$output" || fail "wizard did not show empty extension status"
  grep -Fq "Self-test empty extension row." "$output" || fail "wizard did not show empty extension reason"

  (
    cd "$tmpdir"
    printf '1\n1\n1\n4\n1\n1\n1\n1\n1\n1\n' | "$wizard" >"$output" 2>&1
  ) || fail "wizard validated build preview failed"
  grep -Fq "./build.sh --ci --validate --validate-artifact --manifest --ndb-version 9.99 --db-type pgsql --os 'Rocky Linux' --os-version 9.9 --db-version 16" "$output" || fail "wizard build command missing validation defaults"

  (
    cd "$tmpdir"
    printf '1\n1\n3\n1\n1\n1\n1\n' | "$wizard" >"$output" 2>&1
  ) || fail "wizard MongoDB dry-run failed"
  grep -Fq "MongoDB deployments: single-instance, replica-set, sharded-cluster" "$output" || fail "wizard did not show MongoDB deployment list"
  grep -Fq -- "--db-type mongodb" "$output" || fail "wizard MongoDB command mismatch"

  (
    cd "$tmpdir"
    printf '1\n1\n1\n1\n3\n11111111-2222-3333-4444-555555555555\n3\n1\n1\n' | "$wizard" >"$output" 2>&1
  ) || fail "wizard source UUID and customization preview failed"
  grep -Fq -- "--source-image-uuid 11111111-2222-3333-4444-555555555555" "$output" || fail "wizard source UUID command mismatch"
  grep -Fq -- "--customization-profile enterprise-example" "$output" || fail "wizard customization command mismatch"

  (
    cd "$tmpdir"
    printf '1\n1\n1\n1\n1\n1\n2\n' | NDB_SELFTEST_BUILD_LOG="$build_log" "$wizard" >"$output" 2>&1
  ) || fail "wizard run-now path failed"
  grep -Fq -- "--dry-run" "$build_log" || fail "wizard did not execute generated build command"

  pass "build wizard"
}

run_build_wizard_tests
```

- [ ] **Step 3: Run the tests to verify they fail before implementation**

Run:

```bash
bash scripts/selftest.sh
```

Expected: FAIL because `scripts/build_wizard.sh` does not exist yet.

- [ ] **Step 4: Commit the red test if working in strict TDD mode**

Run:

```bash
git add scripts/selftest.sh tasks/todo.md
git commit -m "Add build wizard selftests"
```

Expected: commit succeeds only if the red test state is intentional for the execution style. If batching changes in one commit, skip this commit and keep the failing test as the next implementation guide.

---

### Task 2: Implement `scripts/build_wizard.sh` Foundation

**Files:**
- Create: `scripts/build_wizard.sh`

- [ ] **Step 1: Create the script with shell safety and basic helpers**

Create `scripts/build_wizard.sh` with this foundation:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

require_command() {
  local command_name=$1
  command -v "$command_name" >/dev/null 2>&1 || fail "$command_name is required to run the build wizard."
}

shell_quote() {
  local value=${1-}
  if [[ "$value" =~ ^[A-Za-z0-9_./:=@+-]+$ ]]; then
    printf '%s' "$value"
  else
    printf "'%s'" "${value//\'/\'\\\'\'}"
  fi
}

print_command() {
  local -n command_ref=$1
  local rendered="" arg
  for arg in "${command_ref[@]}"; do
    if [[ -n "$rendered" ]]; then
      rendered+=" "
    fi
    rendered+="$(shell_quote "$arg")"
  done
  printf '%s\n' "$rendered"
}

prompt_menu() {
  local title=$1
  shift
  local options=("$@")
  local choice

  if (( ${#options[@]} == 0 )); then
    fail "No options available for ${title}."
  fi

  printf '\n%s\n' "$title" >&2
  local index
  for index in "${!options[@]}"; do
    printf '  %d. %s\n' "$((index + 1))" "${options[$index]}" >&2
  done

  while true; do
    printf 'Choose [1-%d]: ' "${#options[@]}" >&2
    IFS= read -r choice || fail "No selection provided for ${title}."
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#options[@]} )); then
      printf '%s\n' "$((choice - 1))"
      return 0
    fi
    printf 'Invalid selection. Please try again.\n' >&2
  done
}

prompt_value() {
  local prompt=$1
  local value
  while true; do
    printf '%s: ' "$prompt" >&2
    IFS= read -r value || fail "No value provided for ${prompt}."
    if [[ -n "$value" ]]; then
      printf '%s\n' "$value"
      return 0
    fi
    printf 'Value cannot be empty.\n' >&2
  done
}

join_json_array() {
  jq -r 'if type == "array" and length > 0 then join(", ") else "" end'
}
```

- [ ] **Step 2: Run shell syntax check**

Run:

```bash
bash -n scripts/build_wizard.sh
```

Expected: command exits 0.

---

### Task 3: Add Matrix Loading, Row Selection, and Extension Preview

**Files:**
- Modify: `scripts/build_wizard.sh`

- [ ] **Step 1: Add NDB version loading and row filters**

Add these functions below the helpers:

```bash
load_ndb_versions() {
  find "$ROOT_DIR/ndb" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort
}

load_buildable_rows() {
  local matrix_file=$1
  local filter_name=$2
  case "$filter_name" in
    all)
      jq -c '.[] | select((.provisioning_role // "") as $role | ($role == "postgresql" or $role == "mongodb"))' "$matrix_file"
      ;;
    pgsql_extensions)
      jq -c '.[] | select((.provisioning_role // "") == "postgresql" and ((.extensions // []) | length) > 0)' "$matrix_file"
      ;;
    pgsql_no_extensions)
      jq -c '.[] | select((.provisioning_role // "") == "postgresql" and ((.extensions // []) | length) == 0)' "$matrix_file"
      ;;
    mongodb)
      jq -c '.[] | select((.provisioning_role // "") == "mongodb")' "$matrix_file"
      ;;
  esac
}
```

- [ ] **Step 2: Add row label and details functions**

Add:

```bash
row_label() {
  jq -r '
    if .provisioning_role == "postgresql" then
      "PostgreSQL \(.db_version) on \(.os_type) \(.os_version)"
      + (if ((.extensions // []) | length) > 0 then
          " (extensions: \((.extensions // []) | join(", ")))"
        else
          " (no extensions)"
        end)
    elif .provisioning_role == "mongodb" then
      "MongoDB \(.db_version) on \(.os_type) \(.os_version)"
    else
      "\(.engine) \(.db_version) on \(.os_type) \(.os_version)"
    end
  '
}

print_row_details() {
  local row_json=$1
  local role db_type os_type os_version db_version extensions reason deployments
  role=$(jq -r '.provisioning_role' <<<"$row_json")
  db_type=$(jq -r '.db_type' <<<"$row_json")
  os_type=$(jq -r '.os_type' <<<"$row_json")
  os_version=$(jq -r '.os_version' <<<"$row_json")
  db_version=$(jq -r '.db_version' <<<"$row_json")

  printf '\nSelected image:\n'
  printf '  Database: %s %s\n' "$db_type" "$db_version"
  printf '  OS: %s %s\n' "$os_type" "$os_version"

  if [[ "$role" == "postgresql" ]]; then
    extensions=$(jq -c '.extensions // []' <<<"$row_json" | join_json_array)
    if [[ -n "$extensions" ]]; then
      printf '  Extensions: %s\n' "$extensions"
    else
      printf '  Extensions: No PostgreSQL extensions requested.\n'
      reason=$(jq -r '.extensions_empty_reason // ""' <<<"$row_json")
      if [[ -n "$reason" ]]; then
        printf '  Extension reason: %s\n' "$reason"
      else
        printf '  Extension warning: missing extensions_empty_reason; run scripts/matrix_validate.sh ndb/*/matrix.json before building.\n'
      fi
    fi
  elif [[ "$role" == "mongodb" ]]; then
    deployments=$(jq -c '.deployment // []' <<<"$row_json" | join_json_array)
    printf '  MongoDB deployments: %s\n' "$deployments"
  fi
}
```

- [ ] **Step 3: Add RHEL source warning helper**

Add:

```bash
source_image_key() {
  local os_type=$1
  local os_version=$2
  printf '%s-%s' "$os_type" "$os_version" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-//; s/-$//'
}

print_source_image_warning() {
  local row_json=$1
  local os_type os_version key env_var description
  os_type=$(jq -r '.os_type' <<<"$row_json")
  os_version=$(jq -r '.os_version' <<<"$row_json")
  key=$(source_image_key "$os_type" "$os_version")

  if [[ ! -f "$ROOT_DIR/images.json" ]]; then
    return 0
  fi

  env_var=$(jq -r --arg key "$key" '.[$key].env_var // ""' "$ROOT_DIR/images.json")
  if [[ -n "$env_var" && -z "${!env_var:-}" ]]; then
    description=$(jq -r --arg key "$key" '.[$key].description // ""' "$ROOT_DIR/images.json")
    printf '\nWarning: source image variable %s is not set.\n' "$env_var"
    if [[ -n "$description" ]]; then
      printf '  %s\n' "$description"
    fi
  fi
}
```

- [ ] **Step 4: Run focused syntax and selftest**

Run:

```bash
bash -n scripts/build_wizard.sh
bash scripts/selftest.sh
```

Expected: syntax passes. Selftest may still fail until command composition is added.

---

### Task 4: Add Command Composition, Source Image Choices, and Customization Choices

**Files:**
- Modify: `scripts/build_wizard.sh`

- [ ] **Step 1: Add profile selection helpers**

Add:

```bash
load_profile_names() {
  local profile
  for profile in "$ROOT_DIR"/customizations/profiles/*.yml; do
    [[ -e "$profile" ]] || continue
    basename "$profile" .yml
  done | sort
}

choose_customization_args() {
  local choice profile_choice profile_path
  local profiles=()
  mapfile -t profiles < <(load_profile_names)

  choice=$(prompt_menu "Customization" \
    "No command-line customization profile" \
    "Force no customizations (--no-customizations)" \
    "Use a repository profile" \
    "Use a manual profile path")

  case "$choice" in
    0)
      return 0
      ;;
    1)
      printf '%s\n' "--no-customizations"
      ;;
    2)
      if (( ${#profiles[@]} == 0 )); then
        fail "No profiles found under customizations/profiles."
      fi
      profile_choice=$(prompt_menu "Customization profiles" "${profiles[@]}")
      printf '%s\n%s\n' "--customization-profile" "${profiles[$profile_choice]}"
      ;;
    3)
      profile_path=$(prompt_value "Customization profile path")
      printf '%s\n%s\n' "--customization-profile" "$profile_path"
      ;;
  esac
}
```

- [ ] **Step 2: Add action, validation, and source image helpers**

Add:

```bash
choose_action_arg() {
  local choice
  choice=$(prompt_menu "Action" \
    "Dry run (safe preview)" \
    "Preflight only" \
    "Stage source image" \
    "Build image")
  case "$choice" in
    0) printf '%s\n' "--dry-run" ;;
    1) printf '%s\n' "--preflight" ;;
    2) printf '%s\n' "--stage-source" ;;
    3) printf '%s\n' "build" ;;
  esac
}

choose_yes_no() {
  local title=$1
  local choice
  choice=$(prompt_menu "$title" "Yes" "No")
  [[ "$choice" == "0" ]]
}

choose_source_args() {
  local action_arg=$1
  local choice value
  if [[ "$action_arg" == "--stage-source" ]]; then
    return 0
  fi

  choice=$(prompt_menu "Source image strategy" \
    "Use matrix default" \
    "Use existing Prism image name" \
    "Use existing Prism image UUID")
  case "$choice" in
    0)
      return 0
      ;;
    1)
      value=$(prompt_value "Existing Prism image name")
      printf '%s\n%s\n' "--source-image-name" "$value"
      ;;
    2)
      value=$(prompt_value "Existing Prism image UUID")
      printf '%s\n%s\n' "--source-image-uuid" "$value"
      ;;
  esac
}
```

- [ ] **Step 3: Add the main flow**

Add this `main` function and call it at the bottom of the script:

```bash
main() {
  require_command jq

  local versions=() version_choice ndb_version matrix_file
  local filter_choice filter_name rows=() row_labels=() row_choice row_json
  local action_arg source_args=() customization_args=() command_args=()
  local db_type os_type os_version db_version final_choice

  cd "$ROOT_DIR"

  mapfile -t versions < <(load_ndb_versions)
  version_choice=$(prompt_menu "NDB version" "${versions[@]}")
  ndb_version="${versions[$version_choice]}"
  matrix_file="$ROOT_DIR/ndb/$ndb_version/matrix.json"
  [[ -f "$matrix_file" ]] || fail "Matrix file not found: $matrix_file"

  filter_choice=$(prompt_menu "Rows to show" \
    "All buildable rows" \
    "PostgreSQL rows with extensions" \
    "PostgreSQL rows without extensions" \
    "MongoDB rows")
  case "$filter_choice" in
    0) filter_name="all" ;;
    1) filter_name="pgsql_extensions" ;;
    2) filter_name="pgsql_no_extensions" ;;
    3) filter_name="mongodb" ;;
  esac

  mapfile -t rows < <(load_buildable_rows "$matrix_file" "$filter_name")
  if (( ${#rows[@]} == 0 )); then
    fail "No buildable rows match the selected filter."
  fi

  local row
  for row in "${rows[@]}"; do
    row_labels+=("$(row_label <<<"$row")")
  done

  row_choice=$(prompt_menu "Buildable image rows" "${row_labels[@]}")
  row_json="${rows[$row_choice]}"
  print_row_details "$row_json"

  action_arg=$(choose_action_arg)

  command_args=("./build.sh" "--ci")
  if [[ "$action_arg" != "build" ]]; then
    command_args+=("$action_arg")
  else
    if choose_yes_no "Run in-guest validation?"; then
      command_args+=("--validate")
    fi
    if choose_yes_no "Run saved-artifact validation?"; then
      command_args+=("--validate-artifact")
    fi
    if choose_yes_no "Write manifest?"; then
      command_args+=("--manifest")
    fi
  fi

  db_type=$(jq -r '.db_type' <<<"$row_json")
  os_type=$(jq -r '.os_type' <<<"$row_json")
  os_version=$(jq -r '.os_version' <<<"$row_json")
  db_version=$(jq -r '.db_version' <<<"$row_json")

  command_args+=(
    "--ndb-version" "$ndb_version"
    "--db-type" "$db_type"
    "--os" "$os_type"
    "--os-version" "$os_version"
    "--db-version" "$db_version"
  )

  mapfile -t source_args < <(choose_source_args "$action_arg")
  command_args+=("${source_args[@]}")

  mapfile -t customization_args < <(choose_customization_args)
  command_args+=("${customization_args[@]}")

  print_source_image_warning "$row_json"

  printf '\nCommand preview:\n'
  print_row_details "$row_json"
  printf '  Action: %s\n' "$([[ "$action_arg" == "build" ]] && printf 'build' || printf '%s' "$action_arg")"
  printf '\n'
  print_command command_args

  final_choice=$(prompt_menu "Next step" "Print command only" "Run command now")
  if [[ "$final_choice" == "1" ]]; then
    printf '\nRunning command...\n'
    "${command_args[@]}"
  fi
}

main "$@"
```

- [ ] **Step 4: Run the wizard tests**

Run:

```bash
bash scripts/selftest.sh
```

Expected: wizard tests pass. If other existing selftests fail, inspect the failure and fix only regressions caused by this task.

---

### Task 5: Update README Beginner Workflow

**Files:**
- Modify: `README.md`
- Modify: `scripts/selftest.sh`

- [ ] **Step 1: Add README wizard guidance**

Add a short section near the existing quick-start commands:

````markdown
### Guided Single-Image Build

If you are new to the project, start with the wizard:

```sh
scripts/build_wizard.sh
```

The wizard does not replace `build.sh`. It asks beginner-friendly questions, shows the selected matrix row, prints the exact `./build.sh --ci ...` command, and lets you either print the command or run it.

For PostgreSQL rows, the wizard shows the matrix-defined extension list before you build. Extension installation is still controlled by `ndb/<version>/matrix.json`; to change extensions, edit or add a matrix row, then run:

```sh
scripts/matrix_validate.sh ndb/*/matrix.json
```
````

- [ ] **Step 2: Add README selftest coverage**

Add this function near the existing README checks in `scripts/selftest.sh`:

```bash
run_readme_wizard_tests() {
  grep -q "scripts/build_wizard.sh" "$ROOT_DIR/README.md" || fail "README missing build wizard command"
  grep -q "PostgreSQL rows, the wizard shows" "$ROOT_DIR/README.md" || fail "README missing wizard PostgreSQL extension guidance"
  grep -q "Extension installation is still controlled by" "$ROOT_DIR/README.md" || fail "README missing matrix-driven extension guidance"
  pass "README build wizard guidance"
}

run_readme_wizard_tests
```

- [ ] **Step 3: Run documentation tests**

Run:

```bash
bash scripts/selftest.sh
```

Expected: selftests pass.

---

### Task 6: Final Verification and Commit

**Files:**
- Modify: `tasks/todo.md`

- [ ] **Step 1: Run full offline verification**

Run:

```bash
bash -n build.sh test.sh scripts/*.sh
bash scripts/selftest.sh
scripts/matrix_validate.sh ndb/*/matrix.json
packer fmt -check packer
git diff --check
```

Expected:

- Shell syntax checks exit 0.
- Selftests exit 0.
- Matrix validation succeeds for all matrix files.
- Packer formatting check exits 0.
- Diff whitespace check exits 0.

- [ ] **Step 2: Run one real-repo wizard print-only smoke**

Use menu choices that select the first available NDB version, all buildable rows, the first row, dry run, matrix source, no command-line customization, and print-only:

```bash
printf '1\n1\n1\n1\n1\n1\n1\n' | scripts/build_wizard.sh
```

Expected: output prints a valid `./build.sh --ci --dry-run ...` command and does not start Packer.

- [ ] **Step 3: Mark implementation complete in `tasks/todo.md`**

Update the active implementation checklist so completed items are checked, and add final verification results to the active plan review.

- [ ] **Step 4: Commit**

Run:

```bash
git add scripts/build_wizard.sh scripts/selftest.sh README.md tasks/todo.md
git commit -m "Add single-image build wizard"
```

Expected: commit succeeds with only the wizard implementation, tests, README, and task tracker changes staged.
