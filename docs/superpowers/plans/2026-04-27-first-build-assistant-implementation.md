# First Build Assistant Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `scripts/build_wizard.sh` the safest beginner path for one NDB image by adding readiness checks, safe setup actions, live-run guards, clearer DBA choices, and README guidance.

**Architecture:** Keep the wizard as a shell-only command composer that emits ordinary `./build.sh --ci ...` commands. Add small wizard-local helper functions for readiness reporting and local setup actions, then gate only run-now live actions while keeping dry-run and print-only previews safe without Prism credentials. Extend existing shell selftests with temporary mini repositories and stub commands so the new behavior is proven without touching real credentials or running Packer.

**Tech Stack:** Bash, `jq`, existing `scripts/postgres_extensions.sh`, existing `scripts/selftest.sh`, Markdown README.

---

## File Map

- Modify `scripts/build_wizard.sh`: add first-build readiness assistant helpers, safe local setup actions, production safety preset, live run-now prerequisite guard, and clearer selected recipe previews.
- Modify `scripts/selftest.sh`: extend `run_build_wizard_tests` with readiness tests and update existing wizard input sequences for the new readiness menu and safety preset.
- Modify `README.md`: make the wizard-first beginner path explicit and describe the assistant checks and safe setup actions.
- Modify `tasks/todo.md`: track this execution and record verification results.
- Do not modify `build.sh`, Packer templates, Ansible roles, matrix files, or validation roles for this feature.

---

## Task 1: Add Failing Wizard Assistant Selftests

**Files:**
- Modify: `scripts/selftest.sh`
- Modify: `tasks/todo.md`

- [ ] **Step 1: Add execution tracker**

Add this block near the top of `tasks/todo.md`, below `# Task Plan`:

```markdown
# Active Plan: First Build Assistant

- [ ] Add failing selftests for wizard readiness and safe setup paths.
- [ ] Implement wizard readiness summary and safe local setup actions.
- [ ] Add run-now prerequisite guards for live actions.
- [ ] Improve selected image recipe and production safety prompts.
- [ ] Update README beginner guidance.
- [ ] Run offline verification and wizard smoke checks.
- [ ] Record final review.
```

- [ ] **Step 2: Extend wizard selftest fixture with `.env.example` and stub bin directory**

In `scripts/selftest.sh`, inside `run_build_wizard_tests`, change the local variable line from:

```bash
local tmpdir output build_log wizard
```

to:

```bash
local tmpdir output build_log wizard stubbin packer_log ssh_keygen_log
```

After:

```bash
build_log="$tmpdir/build.log"
wizard="$tmpdir/scripts/build_wizard.sh"
```

add:

```bash
stubbin="$tmpdir/bin"
packer_log="$tmpdir/packer.log"
ssh_keygen_log="$tmpdir/ssh-keygen.log"
```

Change:

```bash
mkdir -p "$tmpdir/ndb/9.99" "$tmpdir/scripts" "$tmpdir/customizations/profiles"
```

to:

```bash
mkdir -p "$tmpdir/ndb/9.99" "$tmpdir/scripts" "$tmpdir/customizations/profiles" "$tmpdir/packer" "$stubbin"
```

After the existing `enterprise-example.yml` fixture, add:

```bash
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
```

- [ ] **Step 3: Add red readiness tests before existing wizard cases**

Before the existing default PostgreSQL dry-run case, add these test cases:

```bash
  (
    cd "$tmpdir"
    env PATH="$stubbin" /bin/bash "$wizard" >"$output" 2>&1
  ) && fail "wizard unexpectedly passed without jq"
  grep -Fq "Missing jq." "$output" || fail "wizard missing jq message is not beginner-friendly"

  (
    cd "$tmpdir"
    printf '3\n1\n1\n1\n1\n0\n1\n1\n1\n' \
      | PATH="$stubbin:$PATH" NDB_SELFTEST_PACKER_LOG="$packer_log" NDB_SELFTEST_SSH_KEYGEN_LOG="$ssh_keygen_log" "$wizard" >"$output" 2>&1
  ) || fail "wizard .env copy readiness action failed"
  [[ -f "$tmpdir/.env" ]] || fail "wizard did not copy .env.example to .env"
  grep -Fq "Created .env from .env.example." "$output" || fail "wizard did not report .env creation"

  rm -f "$tmpdir/packer/id_rsa" "$tmpdir/packer/id_rsa.pub" "$ssh_keygen_log"
  (
    cd "$tmpdir"
    printf '2\n1\n1\n1\n1\n0\n1\n1\n1\n' \
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
    printf '2\n1\n1\n1\n1\n0\n1\n1\n1\n' \
      | PATH="$stubbin:$PATH" NDB_SELFTEST_PACKER_LOG="$packer_log" NDB_SELFTEST_SSH_KEYGEN_LOG="$ssh_keygen_log" "$wizard" >"$output" 2>&1
  ) || fail "wizard packer init readiness action failed"
  grep -Fq "init packer/" "$packer_log" || fail "wizard did not invoke packer init packer/"

  grep -Eq "PKR_VAR_pc_password=(present|missing)" "$output" || fail "wizard did not show secret variable status"
  ! grep -Fq "your-prism-password" "$output" || fail "wizard printed secret-like .env template value"
```

Expected before implementation: at least the first new readiness case fails because the wizard still prints `Error: jq is required to run the build wizard.` instead of `Missing jq.`

- [ ] **Step 4: Update existing wizard input sequences for the readiness menu**

After implementation, the first prompt will be `Readiness actions`, with option `1` meaning "Continue to image selection". In the existing wizard cases in `run_build_wizard_tests`, prefix each input stream with `1\n`.

For example, change:

```bash
printf '1\n1\n1\n1\n0\n1\n1\n1\n' | "$wizard" >"$output" 2>&1
```

to:

```bash
printf '1\n1\n1\n1\n1\n0\n1\n1\n1\n' | "$wizard" >"$output" 2>&1
```

Update every existing wizard case in that function the same way, then run the selftest to confirm the new red failures are only readiness-related:

```bash
bash scripts/selftest.sh
```

Expected: failure from missing first-build assistant behavior, not from broken matrix setup.

- [ ] **Step 5: Mark tracker item**

Mark `Add failing selftests for wizard readiness and safe setup paths` complete in `tasks/todo.md`.

---

## Task 2: Implement Readiness Summary And Safe Setup Actions

**Files:**
- Modify: `scripts/build_wizard.sh`
- Modify: `tasks/todo.md`

- [ ] **Step 1: Add readiness constants near the top of the wizard**

After the `source "$ROOT_DIR/scripts/postgres_extensions.sh"` line in `scripts/build_wizard.sh`, add:

```bash
REQUIRED_LIVE_COMMANDS=(packer ansible-playbook curl ssh base64)
LIVE_ENV_KEYS=(
  PKR_VAR_pc_username
  PKR_VAR_pc_password
  PKR_VAR_pc_ip
  PKR_VAR_cluster_name
  PKR_VAR_subnet_name
)
```

Keep `jq` and `cksum` as hard requirements because the wizard itself cannot load matrix rows or compute extension suffixes without them.

- [ ] **Step 2: Replace `require_command` with beginner-readable output for hard requirements**

Replace:

```bash
require_command() {
  local command_name=$1
  command -v "$command_name" >/dev/null 2>&1 || fail "$command_name is required to run the build wizard."
}
```

with:

```bash
require_command() {
  local command_name=$1
  if ! command -v "$command_name" >/dev/null 2>&1; then
    printf 'Missing %s.\n' "$command_name" >&2
    printf 'Install %s, then rerun scripts/build_wizard.sh.\n' "$command_name" >&2
    exit 1
  fi
}
```

- [ ] **Step 3: Add readiness helper functions after `prompt_value`**

Add:

```bash
command_status() {
  local command_name=$1
  if command -v "$command_name" >/dev/null 2>&1; then
    printf 'present'
  else
    printf 'missing'
  fi
}

env_status() {
  local key=$1
  if [[ -n "${!key:-}" ]]; then
    printf 'present'
  else
    printf 'missing'
  fi
}

env_vars_missing() {
  local key
  for key in "${LIVE_ENV_KEYS[@]}"; do
    [[ -n "${!key:-}" ]] || return 0
  done
  return 1
}

live_commands_missing() {
  local command_name
  for command_name in "${REQUIRED_LIVE_COMMANDS[@]}"; do
    command -v "$command_name" >/dev/null 2>&1 || return 0
  done
  return 1
}

ssh_keypair_missing() {
  [[ -f "$ROOT_DIR/packer/id_rsa" && -f "$ROOT_DIR/packer/id_rsa.pub" ]] && return 1
  return 0
}

print_readiness_summary() {
  local command_name key

  printf '\nFirst build readiness check\n'
  printf 'Local tools:\n'
  printf '  jq: present\n'
  printf '  cksum: present\n'
  for command_name in "${REQUIRED_LIVE_COMMANDS[@]}"; do
    printf '  %s: %s\n' "$command_name" "$(command_status "$command_name")"
  done
  printf '  op: %s (optional, only needed for 1Password-managed .env files)\n' "$(command_status op)"

  printf '\nSSH key:\n'
  if [[ -f "$ROOT_DIR/packer/id_rsa.pub" ]]; then
    printf '  packer/id_rsa.pub: present\n'
  else
    printf '  packer/id_rsa.pub: missing - required for live builds and artifact validation\n'
  fi
  if [[ -f "$ROOT_DIR/packer/id_rsa" ]]; then
    printf '  packer/id_rsa: present\n'
  else
    printf '  packer/id_rsa: missing - required for live builds and artifact validation\n'
  fi

  printf '\nEnvironment:\n'
  if [[ -f "$ROOT_DIR/.env" ]]; then
    printf '  .env: present\n'
  else
    printf '  .env: missing\n'
  fi
  for key in "${LIVE_ENV_KEYS[@]}"; do
    printf '  %s: %s\n' "$key" "$(env_status "$key")"
  done
  printf '  Tip: if 1Password manages .env, run: op run --env-file .env -- scripts/build_wizard.sh\n'
}

copy_env_example() {
  [[ -f "$ROOT_DIR/.env.example" ]] || fail ".env.example is missing; cannot create .env."
  if [[ -f "$ROOT_DIR/.env" ]]; then
    printf '.env already exists; leaving it unchanged.\n'
    return 0
  fi
  cp "$ROOT_DIR/.env.example" "$ROOT_DIR/.env"
  printf 'Created .env from .env.example. Edit it or run the wizard through op before live builds.\n'
}

create_ssh_keypair() {
  if [[ -f "$ROOT_DIR/packer/id_rsa" || -f "$ROOT_DIR/packer/id_rsa.pub" ]]; then
    fail "One packer SSH key file already exists. Refusing to overwrite partial keypair."
  fi
  mkdir -p "$ROOT_DIR/packer"
  ssh-keygen -t rsa -b 4096 -C "packer@nutanix" -f "$ROOT_DIR/packer/id_rsa" -N ""
  printf 'Created packer/id_rsa and packer/id_rsa.pub.\n'
}

run_packer_init() {
  packer init packer/
  printf 'Packer plugins initialized for packer/.\n'
}
```

- [ ] **Step 4: Add readiness action loop**

After the functions from Step 3, add:

```bash
run_first_build_assistant() {
  local options=() actions=() choice

  while true; do
    print_readiness_summary
    options=("Continue to image selection")
    actions=("continue")

    if ssh_keypair_missing && command -v ssh-keygen >/dev/null 2>&1; then
      options+=("Create missing packer SSH keypair")
      actions+=("create_ssh_keypair")
    fi
    if [[ ! -f "$ROOT_DIR/.env" && -f "$ROOT_DIR/.env.example" ]]; then
      options+=("Create .env from .env.example")
      actions+=("copy_env")
    fi
    if command -v packer >/dev/null 2>&1; then
      options+=("Run packer init packer/")
      actions+=("packer_init")
    fi

    choice=$(prompt_menu "Readiness actions" "${options[@]}")
    case "${actions[$choice]}" in
      continue)
        return 0
        ;;
      create_ssh_keypair)
        create_ssh_keypair
        ;;
      copy_env)
        copy_env_example
        ;;
      packer_init)
        run_packer_init
        ;;
    esac
  done
}
```

- [ ] **Step 5: Invoke readiness before matrix prompts**

In `main`, after:

```bash
require_command jq
require_command cksum
cd "$ROOT_DIR"
```

add:

```bash
run_first_build_assistant
```

- [ ] **Step 6: Run targeted selftest**

Run:

```bash
bash scripts/selftest.sh
```

Expected: readiness summary and safe setup tests pass. Later tests may still fail until prompt sequences and run-now guards are updated in the following tasks.

- [ ] **Step 7: Mark tracker item**

Mark `Implement wizard readiness summary and safe local setup actions` complete in `tasks/todo.md`.

---

## Task 3: Add Run-Now Guards For Live Actions

**Files:**
- Modify: `scripts/build_wizard.sh`
- Modify: `scripts/selftest.sh`
- Modify: `tasks/todo.md`

- [ ] **Step 1: Add action guard helpers after `run_first_build_assistant`**

Add:

```bash
action_uses_live_prism() {
  local action_arg=$1
  [[ "$action_arg" == "--preflight" || "$action_arg" == "--stage-source" || "$action_arg" == "build" ]]
}

action_requires_ssh_keypair() {
  local action_arg=$1
  [[ "$action_arg" == "build" ]]
}

assert_run_now_prerequisites() {
  local action_arg=$1
  local missing=false

  if [[ "$action_arg" == "--dry-run" ]]; then
    return 0
  fi

  if action_uses_live_prism "$action_arg" && live_commands_missing; then
    printf 'Cannot run this live action yet. Missing one or more live-build commands:\n' >&2
    local command_name
    for command_name in "${REQUIRED_LIVE_COMMANDS[@]}"; do
      if ! command -v "$command_name" >/dev/null 2>&1; then
        printf '  - %s\n' "$command_name" >&2
      fi
    done
    missing=true
  fi

  if action_uses_live_prism "$action_arg" && env_vars_missing; then
    printf 'Cannot run this live action yet. Missing one or more Prism variables:\n' >&2
    local key
    for key in "${LIVE_ENV_KEYS[@]}"; do
      if [[ -z "${!key:-}" ]]; then
        printf '  - %s\n' "$key" >&2
      fi
    done
    printf 'Edit .env and source it, or run: op run --env-file .env -- scripts/build_wizard.sh\n' >&2
    missing=true
  fi

  if action_requires_ssh_keypair "$action_arg" && ssh_keypair_missing; then
    printf 'Cannot run a live build yet. Missing packer SSH keypair.\n' >&2
    printf 'Create it from the readiness menu or run:\n' >&2
    printf '  ssh-keygen -t rsa -b 4096 -C "packer@nutanix" -f packer/id_rsa -N ""\n' >&2
    missing=true
  fi

  [[ "$missing" == "false" ]] || exit 1
}
```

- [ ] **Step 2: Gate only final run-now execution**

Near the end of `main`, change:

```bash
  final_choice=$(prompt_menu "Next step" "Print command only" "Run command now")
  if [[ "$final_choice" == "1" ]]; then
    printf '\nRunning command...\n'
    "${COMMAND_ARGS[@]}"
  fi
```

to:

```bash
  final_choice=$(prompt_menu "Next step" "Print command only" "Run command now")
  if [[ "$final_choice" == "1" ]]; then
    assert_run_now_prerequisites "$action_arg"
    printf '\nRunning command...\n'
    "${COMMAND_ARGS[@]}"
  fi
```

Print-only must remain unblocked.

- [ ] **Step 3: Add run-now guard selftest**

Inside `run_build_wizard_tests`, after the existing run-now dry-run path, add:

```bash
  (
    cd "$tmpdir"
    rm -f packer/id_rsa packer/id_rsa.pub
    printf '1\n1\n1\n1\n4\n1\n1\n1\n0\n1\n1\n2\n' | "$wizard" >"$output" 2>&1
  ) && fail "wizard live run-now unexpectedly passed without prerequisites"
  grep -Fq "Cannot run this live action yet." "$output" || fail "wizard did not stop live run-now with friendly message"
  ! grep -Fq "Running command..." "$output" || fail "wizard attempted to run live build despite missing prerequisites"
```

Expected after implementation: the case exits non-zero and prints missing prerequisite guidance before invoking `build.sh`.

- [ ] **Step 4: Run targeted wizard tests**

Run:

```bash
bash scripts/selftest.sh
```

Expected: wizard tests pass or only fail on the production safety prompt updates from Task 4.

- [ ] **Step 5: Mark tracker item**

Mark `Add run-now prerequisite guards for live actions` complete in `tasks/todo.md`.

---

## Task 4: Improve Selected Recipe And Production Safety Prompts

**Files:**
- Modify: `scripts/build_wizard.sh`
- Modify: `scripts/selftest.sh`
- Modify: `tasks/todo.md`

- [ ] **Step 1: Add human-friendly MongoDB deployment formatter**

After `join_json_array`, add:

```bash
mongodb_deployments_human() {
  jq -r '
    if type != "array" or length == 0 then
      "none"
    else
      map(
        if . == "single-instance" then "single instance"
        elif . == "replica-set" then "replica set smoke test"
        elif . == "sharded-cluster" then "sharded cluster smoke test"
        else .
        end
      ) | join(", ")
    end
  '
}
```

- [ ] **Step 2: Update `print_row_details` for MongoDB edition and human deployments**

In `print_row_details`, change the local variable list from:

```bash
local role db_type os_type os_version db_version extensions reason deployments
```

to:

```bash
local role db_type os_type os_version db_version extensions reason deployments edition
```

In the MongoDB branch, replace:

```bash
    deployments=$(jq -c '.deployment // []' <<<"$row_json" | join_json_array)
    printf '  MongoDB deployments: %s\n' "$deployments"
```

with:

```bash
    edition=$(jq -r '.mongodb_edition // "community"' <<<"$row_json")
    deployments=$(jq -c '.deployment // []' <<<"$row_json" | mongodb_deployments_human)
    printf '  MongoDB edition: %s\n' "$edition"
    printf '  MongoDB validation shape: %s\n' "$deployments"
```

- [ ] **Step 3: Add selected recipe preview helper**

After `print_row_details`, add:

```bash
print_selected_recipe() {
  local row_json=$1
  local action_arg=$2
  local source_summary=$3
  local extensions_summary=${4:-none}
  local image_suffix_summary=${5:-none}
  local role db_type os_type os_version db_version ndb_version validation_summary manifest_summary edition deployments

  role=$(jq -r '.provisioning_role' <<<"$row_json")
  db_type=$(jq -r '.db_type' <<<"$row_json")
  os_type=$(jq -r '.os_type' <<<"$row_json")
  os_version=$(jq -r '.os_version' <<<"$row_json")
  db_version=$(jq -r '.db_version' <<<"$row_json")
  ndb_version=$(jq -r '.ndb_version' <<<"$row_json")

  if [[ " ${COMMAND_ARGS[*]} " == *" --validate "* && " ${COMMAND_ARGS[*]} " == *" --validate-artifact "* ]]; then
    validation_summary="in-guest + saved artifact"
  elif [[ " ${COMMAND_ARGS[*]} " == *" --validate "* ]]; then
    validation_summary="in-guest only"
  elif [[ " ${COMMAND_ARGS[*]} " == *" --validate-artifact "* ]]; then
    validation_summary="saved artifact only"
  else
    validation_summary="not requested"
  fi

  if [[ " ${COMMAND_ARGS[*]} " == *" --manifest "* ]]; then
    manifest_summary="yes"
  else
    manifest_summary="no"
  fi

  printf '\nSelected image recipe:\n'
  printf '  Database: %s %s\n' "$db_type" "$db_version"
  printf '  OS: %s %s\n' "$os_type" "$os_version"
  printf '  NDB: %s\n' "$ndb_version"
  printf '  Source image: %s\n' "$source_summary"
  printf '  Action: %s\n' "$action_arg"
  printf '  Validation: %s\n' "$validation_summary"
  printf '  Manifest: %s\n' "$manifest_summary"

  if [[ "$role" == "postgresql" ]]; then
    printf '  PostgreSQL extensions: %s\n' "$extensions_summary"
    printf '  Image variant suffix: %s\n' "$image_suffix_summary"
  elif [[ "$role" == "mongodb" ]]; then
    edition=$(jq -r '.mongodb_edition // "community"' <<<"$row_json")
    deployments=$(jq -c '.deployment // []' <<<"$row_json" | mongodb_deployments_human)
    printf '  MongoDB edition: %s\n' "$edition"
    printf '  MongoDB validation shape: %s\n' "$deployments"
  fi
}
```

- [ ] **Step 4: Track source and extension preview summaries**

At the start of `main`, extend the local variable line from:

```bash
local action_choice action_arg db_type os_type os_version db_version final_choice
```

to:

```bash
local action_choice action_arg db_type os_type os_version db_version final_choice source_summary extensions_summary image_suffix_summary
```

Initialize the summaries after `COMMAND_ARGS=("./build.sh" "--ci")`:

```bash
source_summary="matrix default"
extensions_summary="none"
image_suffix_summary="none"
```

Update `append_source_args` so it sets a global `SOURCE_SUMMARY`:

```bash
SOURCE_SUMMARY="matrix default"
```

inside the default path, and:

```bash
SOURCE_SUMMARY="existing Prism image name"
```

when `--source-image-name` is selected, and:

```bash
SOURCE_SUMMARY="existing Prism image UUID"
```

when `--source-image-uuid` is selected.

Declare `SOURCE_SUMMARY="matrix default"` near `declare -a COMMAND_ARGS=()`, then after calling `append_source_args "$action_arg"`, set:

```bash
source_summary="$SOURCE_SUMMARY"
```

In `append_postgres_extension_args`, declare global summaries near the existing globals:

```bash
POSTGRES_EXTENSIONS_SUMMARY="none"
POSTGRES_IMAGE_SUFFIX_SUMMARY="none"
```

When selected extensions exist, set:

```bash
POSTGRES_EXTENSIONS_SUMMARY="$(jq -r 'join(", ")' <<<"$selected_json")"
POSTGRES_IMAGE_SUFFIX_SUMMARY="$image_suffix"
```

When none are selected, set:

```bash
POSTGRES_EXTENSIONS_SUMMARY="none"
POSTGRES_IMAGE_SUFFIX_SUMMARY="none"
```

After calling `append_postgres_extension_args "$row_json"`, set:

```bash
extensions_summary="$POSTGRES_EXTENSIONS_SUMMARY"
image_suffix_summary="$POSTGRES_IMAGE_SUFFIX_SUMMARY"
```

- [ ] **Step 5: Replace build yes/no prompts with a production safety menu**

Add this helper before `main`:

```bash
append_build_safety_args() {
  local choice
  choice=$(prompt_menu "Production safety checks" \
    "Use recommended validation and manifest (--validate --validate-artifact --manifest)" \
    "Choose validation flags one by one" \
    "No validation flags")

  case "$choice" in
    0)
      COMMAND_ARGS+=("--validate" "--validate-artifact" "--manifest")
      ;;
    1)
      if choose_yes_no "Run in-guest validation?"; then
        COMMAND_ARGS+=("--validate")
      fi
      if choose_yes_no "Run saved-artifact validation?"; then
        COMMAND_ARGS+=("--validate-artifact")
      fi
      if choose_yes_no "Write manifest?"; then
        COMMAND_ARGS+=("--manifest")
      fi
      ;;
    2)
      return 0
      ;;
  esac
}
```

Then in `main`, replace:

```bash
  else
    if choose_yes_no "Run in-guest validation?"; then
      COMMAND_ARGS+=("--validate")
    fi
    if choose_yes_no "Run saved-artifact validation?"; then
      COMMAND_ARGS+=("--validate-artifact")
    fi
    if choose_yes_no "Write manifest?"; then
      COMMAND_ARGS+=("--manifest")
    fi
  fi
```

with:

```bash
  else
    append_build_safety_args
  fi
```

- [ ] **Step 6: Use selected recipe preview before command output**

Near the end of `main`, replace:

```bash
  printf '\nCommand preview:\n'
  print_row_details "$row_json"
  if [[ "$action_arg" == "build" ]]; then
    printf '  Action: build\n'
  else
    printf '  Action: %s\n' "$action_arg"
  fi
  printf '\n'
```

with:

```bash
  printf '\nCommand preview:\n'
  print_selected_recipe "$row_json" "$action_arg" "$source_summary" "$extensions_summary" "$image_suffix_summary"
  printf '\n'
```

- [ ] **Step 7: Update wizard selftests for new preview text and safety menu**

In `run_build_wizard_tests`, update assertions:

```bash
grep -Fq "MongoDB validation shape: single instance, replica set smoke test, sharded cluster smoke test" "$output" || fail "wizard did not show human MongoDB deployment list"
grep -Fq "MongoDB edition: community" "$output" || fail "wizard did not show MongoDB edition"
grep -Fq "Selected image recipe:" "$output" || fail "wizard did not print selected recipe"
grep -Fq "Validation: in-guest + saved artifact" "$output" || fail "wizard did not show recommended validation summary"
```

Update the validated build input sequence to choose production safety option `1` instead of answering three yes/no prompts. The old sequence:

```bash
printf '1\n1\n1\n1\n4\n1\n1\n1\n0\n1\n1\n1\n' | "$wizard" >"$output" 2>&1
```

should become:

```bash
printf '1\n1\n1\n1\n4\n1\n0\n1\n1\n1\n' | "$wizard" >"$output" 2>&1
```

If line numbers shifted because earlier tasks added readiness cases, update only the affected build-action test inputs, not the expected generated `./build.sh` command.

Also update the live run-now guard test added in Task 3 so it chooses the new recommended safety preset before selecting no PostgreSQL extensions:

```bash
printf '1\n1\n1\n1\n4\n1\n0\n1\n1\n2\n' | "$wizard" >"$output" 2>&1
```

- [ ] **Step 8: Run focused wizard tests**

Run:

```bash
bash scripts/selftest.sh
```

Expected: `PASS: build wizard`.

- [ ] **Step 9: Mark tracker item**

Mark `Improve selected image recipe and production safety prompts` complete in `tasks/todo.md`.

---

## Task 5: Update README Beginner Guidance

**Files:**
- Modify: `README.md`
- Modify: `scripts/selftest.sh`
- Modify: `tasks/todo.md`

- [ ] **Step 1: Rewrite Quick Start wizard section**

In `README.md`, replace the existing `### 3. Use The Guided Wizard` body with:

````markdown
If you are new to the project, start with the single-image wizard:

```bash
scripts/build_wizard.sh
```

The wizard is the safest first path because it checks your workstation before it asks image questions. It reports local tools, the Packer SSH keypair, `.env` presence, and required Prism variables as `present` or `missing` without printing secret values.

When something local is missing, the wizard can offer safe setup help:

- create `packer/id_rsa` and `packer/id_rsa.pub`
- run `packer init packer/`
- copy `.env.example` to `.env`

The wizard never creates Prism credentials and never prints secret values. If `.env` is managed by 1Password, run the wizard through `op` so the variables resolve inside the wizard:

```bash
op run --env-file .env -- scripts/build_wizard.sh
```

The wizard does not replace `build.sh`. It asks beginner-friendly questions, shows the selected matrix row, lets you choose PostgreSQL extensions one by one when the selected row is PostgreSQL, prints the exact `./build.sh --ci ...` command, and lets you either print the command or run it.
````

Keep the existing PostgreSQL extension paragraph immediately after this block.

- [ ] **Step 2: Add a short direct CLI note before manual dry-run examples**

Before `### 4. Run A Safe Dry Run`, add:

```markdown
If you already know the exact image you want, you can skip the wizard and use `build.sh` directly. The direct commands below are useful for automation and repeat builds, but the wizard is easier for first-time users.
```

- [ ] **Step 3: Strengthen README selftest coverage**

In `scripts/selftest.sh`, inside `run_readme_wizard_tests`, add:

```bash
  grep -q "safest first path" "$ROOT_DIR/README.md" || fail "README missing first build assistant positioning"
  grep -q "create \`packer/id_rsa\`" "$ROOT_DIR/README.md" || fail "README missing wizard SSH key setup guidance"
  grep -q "run \`packer init packer/\`" "$ROOT_DIR/README.md" || fail "README missing wizard Packer init guidance"
  grep -q "op run --env-file .env -- scripts/build_wizard.sh" "$ROOT_DIR/README.md" || fail "README missing 1Password wizard guidance"
```

- [ ] **Step 4: Run README-focused selftest**

Run:

```bash
bash scripts/selftest.sh
```

Expected: `PASS: README build wizard guidance`.

- [ ] **Step 5: Mark tracker item**

Mark `Update README beginner guidance` complete in `tasks/todo.md`.

---

## Task 6: Full Offline Verification And Review

**Files:**
- Modify: `tasks/todo.md`

- [ ] **Step 1: Run shell syntax checks**

Run:

```bash
bash -n build.sh test.sh scripts/*.sh
```

Expected: exit 0.

- [ ] **Step 2: Run full selftests**

Run:

```bash
bash scripts/selftest.sh
```

Expected: all tests pass, including:

```text
PASS: build wizard
PASS: README build wizard guidance
```

- [ ] **Step 3: Run matrix validation and Packer format check**

Run:

```bash
scripts/matrix_validate.sh ndb/*/matrix.json
packer fmt -check packer
```

Expected: matrix validation succeeds for all matrix files and Packer format check exits 0.

- [ ] **Step 4: Run representative print-only wizard smoke**

Run:

```bash
printf '1\n1\n1\n1\n1\n0\n1\n1\n1\n' | scripts/build_wizard.sh
```

Expected: output includes `Command preview`, `Selected image recipe`, and a `./build.sh --ci --dry-run ...` command. It must not print `Running command...`.

- [ ] **Step 5: Run diff checks**

Run:

```bash
git diff --check
git diff --stat
git diff -- scripts/build_wizard.sh scripts/selftest.sh README.md tasks/todo.md
```

Expected: diff only touches the wizard, selftests, README, and task tracker.

- [ ] **Step 6: Record final review**

Append this section below the active plan in `tasks/todo.md`:

```markdown
# Active Plan Review: First Build Assistant

- Added a first-build readiness assistant to `scripts/build_wizard.sh`.
- The wizard now reports local tools, SSH key files, `.env` presence, and required Prism variables without printing secret values.
- The wizard can create the local Packer SSH keypair, copy `.env.example` to `.env`, and run `packer init packer/` only after explicit user selection.
- Dry-run and print-only command previews remain available without Prism credentials.
- Run-now live actions stop early with beginner-readable missing prerequisite guidance.
- The selected image recipe now summarizes source image strategy, validation, manifest, PostgreSQL extensions, image variant suffixes, MongoDB edition, and MongoDB validation shape.
- README now recommends the wizard as the safest first path and keeps direct `build.sh` examples as the repeat/automation path.
- Verification passed: shell syntax checks, full selftests, matrix validation, `packer fmt -check packer`, representative print-only wizard smoke, and `git diff --check`.
```

- [ ] **Step 7: Mark tracker items**

Mark `Run offline verification and wizard smoke checks` and `Record final review` complete in `tasks/todo.md`.

- [ ] **Step 8: Commit implementation**

Run:

```bash
git add scripts/build_wizard.sh scripts/selftest.sh README.md tasks/todo.md
git commit -m "Add first build assistant to wizard"
```

Expected: commit succeeds with only implementation files staged.

---

## Task 7: Finish Branch

**Files:**
- No planned file changes.

- [ ] **Step 1: Confirm status**

Run:

```bash
git status --short --branch
git log --oneline --decorate -5
```

Expected: branch is clean and the latest commit is `Add first build assistant to wizard`.

- [ ] **Step 2: Use finishing workflow**

Use the finishing branch workflow after verification. If the user asks to merge and push, merge into `main`, rerun at least:

```bash
bash scripts/selftest.sh
git diff --check
```

Then push `main`.
