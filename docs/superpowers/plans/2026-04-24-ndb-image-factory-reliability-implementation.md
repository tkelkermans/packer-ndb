# NDB Image Factory Reliability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `build.sh` able to preflight, build, validate, artifact-validate, clean up, and emit a manifest using only Packer, Ansible, shell, `jq`, and `curl`, while adding a shell-first NDB release scaffolding workflow.

**Architecture:** Keep `build.sh` and `test.sh` as the public commands. Move reusable behavior into focused shell helpers under `scripts/`, with Ansible remaining the source of truth for in-guest validation. Keep README updates in the same tasks as behavior changes.

**Tech Stack:** Bash, `jq`, `curl`, Packer, Ansible, Nutanix Prism v3 APIs, Markdown.

---

## Scope Check

This plan covers one cohesive workflow: making the existing PostgreSQL image factory reliable and easier to advance to a new NDB version. The work is split into independently testable tasks, but the tasks are not separate products. Non-PostgreSQL engines, Terraform-managed validation VMs, and a Python CLI are outside this plan.

## File Structure

- Create `scripts/matrix_validate.sh`: shell and `jq` replacement for the current Python matrix validator.
- Create `scripts/prism.sh`: shared Prism API functions using `curl` and `jq`.
- Create `scripts/source_images.sh`: source-image lookup, preflight, staging, and retry guidance.
- Create `scripts/artifact_validate.sh`: final image clone, cloud-init injection, power-on, SSH wait, Ansible validation, and cleanup.
- Create `scripts/manifest.sh`: manifest initialization, updates, and finalization.
- Create `scripts/release_scaffold.sh`: shell-first release directory scaffolding.
- Create `scripts/selftest.sh`: local shell tests that do not require Prism credentials.
- Modify `build.sh`: add flags, source helpers, wire source staging, artifact validation, and manifests.
- Modify `test.sh`: pass through `--validate-artifact`, `--manifest`, and source-image reuse options.
- Modify `README.md`: beginner-friendly workflows and troubleshooting for every new behavior.
- Delete `scripts/validate_matrix.py` if it exists and remove every runtime reference to it: the operator-facing validation path becomes shell-only.

## Task 1: Shell Matrix Validator And Local Test Harness

**Files:**
- Create: `scripts/matrix_validate.sh`
- Create: `scripts/selftest.sh`
- Modify: `build.sh`
- Modify: `test.sh`
- Modify: `README.md`
- Delete if present and stop referencing: `scripts/validate_matrix.py`

- [ ] **Step 1: Create a failing local self-test for shell matrix validation**

Create `scripts/selftest.sh` with this structure:

```bash
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
  local tmpdir valid invalid
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' RETURN
  valid="$tmpdir/2.99/matrix.json"
  invalid="$tmpdir/2.99-invalid/matrix.json"
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
    "os_type": "Rocky Linux",
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
  if "$ROOT_DIR/scripts/matrix_validate.sh" "$invalid" >/tmp/ndb-invalid-matrix.out 2>&1; then
    fail "invalid matrix unexpectedly passed validation"
  fi
  grep -q "ndb_version" /tmp/ndb-invalid-matrix.out || fail "invalid matrix output missed version error"
  grep -q "db_version contains '/'" /tmp/ndb-invalid-matrix.out || fail "invalid matrix output missed db_version error"
  pass "matrix validator"
}

run_matrix_validator_tests
```

- [ ] **Step 2: Run the self-test and verify it fails because the validator does not exist**

Run:

```bash
bash scripts/selftest.sh
```

Expected: failure with `scripts/matrix_validate.sh: No such file or directory`.

- [ ] **Step 3: Implement `scripts/matrix_validate.sh`**

Create `scripts/matrix_validate.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

REQUIRED_FIELDS=(ndb_version engine db_type os_type os_version db_version provisioning_role)

usage() {
  cat <<'EOF'
Usage: scripts/matrix_validate.sh [MATRIX_FILE]

Validates NDB matrix files using shell and jq.
Pass one or more matrix files. When no files are provided, validates every ndb/*/matrix.json file.
EOF
}

validate_matrix() {
  local matrix_file=$1
  local expected_version
  expected_version=$(basename "$(dirname "$matrix_file")")

  if [[ ! -f "$matrix_file" ]]; then
    printf 'Matrix validation failed (%s):\n  - file does not exist\n' "$matrix_file" >&2
    return 1
  fi

  local errors
  errors=$(jq -r --arg expected_version "$expected_version" --argjson required "$(printf '%s\n' "${REQUIRED_FIELDS[@]}" | jq -R . | jq -s .)" '
    if type != "array" then
      ["Matrix must be a JSON array"]
    else
      reduce range(0; length) as $idx ([]; . + (
        . as $all
        | $all[$idx] as $entry
        | if ($entry | type) != "object" then
            ["[\($idx)] entry must be an object"]
          else
            ($entry.db_type // "") as $db_type
            | ($entry.os_type // "") as $os_type
            | ($entry.os_version // "") as $os_version
            | ($entry.db_version // "") as $db_version
            | "[\($idx)] \($db_type) | \($os_type) \($os_version) | \($db_version)" as $ctx
            | (
                [
                  $required[]
                  | select(($entry[.] // "") == "")
                  | "\($ctx): missing or empty field \(.)"
                ]
                + (if ($entry.ndb_version // "") != $expected_version then
                    ["\($ctx): ndb_version \($entry.ndb_version // "<missing>") does not match path version \($expected_version)"]
                  else [] end)
                + (if (($entry.db_version // "") | contains("/")) then
                    ["\($ctx): db_version contains '/', split versions into distinct entries (\($entry.db_version))"]
                  else [] end)
                + (if (($entry.provisioning_role // "") == "postgresql" and ($entry.db_type // "") != "pgsql") then
                    ["\($ctx): provisioning_role postgresql requires db_type pgsql"]
                  else [] end)
                + (if (($entry.extensions // []) | type) != "array" then
                    ["\($ctx): extensions must be a list or omitted"]
                  else
                    [($entry.extensions // [])[] | select((type != "string") or (. == "")) | "\($ctx): extensions must only contain non-empty strings"]
                  end)
                + (if ($entry.ha_components? and (($entry.ha_components | type) != "object")) then
                    ["\($ctx): ha_components must be an object when present"]
                  elif $entry.ha_components? then
                    [
                      $entry.ha_components | to_entries[]
                      | select((.value | type) != "array" or ((.value | map(type == "string" and . != "") | all) | not))
                      | "\($ctx): ha_components[\(.key)] must be a list of non-empty strings"
                    ]
                  else [] end)
              )
          end
      ))
      + (
        group_by([.db_type, .os_type, .os_version, .db_version])
        | map(select(length > 1))
        | map("duplicate combination " + (.[0] | [.db_type, .os_type, .os_version, .db_version] | @json))
      )
    end
    | .[]
  ' "$matrix_file")

  if [[ -n "$errors" ]]; then
    printf 'Matrix validation failed (%s):\n' "$matrix_file" >&2
    printf '%s\n' "$errors" | sed 's/^/  - /' >&2
    return 1
  fi

  printf 'Matrix validation succeeded (%s)\n' "$matrix_file"
}

main() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
  fi

  local matrix_files=("$@")
  if (( ${#matrix_files[@]} == 0 )); then
    mapfile -t matrix_files < <(find ndb -mindepth 2 -maxdepth 2 -name matrix.json | sort)
  fi

  if (( ${#matrix_files[@]} == 0 )); then
    printf 'Error: no matrix files found.\n' >&2
    exit 1
  fi

  local failed=false
  for matrix_file in "${matrix_files[@]}"; do
    if ! validate_matrix "$matrix_file"; then
      failed=true
    fi
  done

  [[ "$failed" == "false" ]]
}

main "$@"
```

- [ ] **Step 4: Run the matrix validator tests**

Run:

```bash
bash scripts/selftest.sh
scripts/matrix_validate.sh ndb/*/matrix.json
```

Expected: self-test passes and both project matrix files validate.

- [ ] **Step 5: Wire `build.sh` and `test.sh` to the shell validator**

In `build.sh`, replace:

```bash
python3 scripts/validate_matrix.py "$matrix_file"
```

with:

```bash
scripts/matrix_validate.sh "$matrix_file"
```

Remove `python3` from `COMMON_REQUIRED_COMMANDS`.

In `test.sh`, replace the Python command check and validator call with:

```bash
if [[ "${SKIP_MATRIX_VALIDATION:-false}" != "true" ]]; then
  scripts/matrix_validate.sh "${MATRIX_FILES[@]}"
fi
```

- [ ] **Step 6: Update README for shell-only validation**

In `README.md`, remove `python3` from the prerequisite list and replace the manual validation command with:

```bash
scripts/matrix_validate.sh ndb/*/matrix.json
```

Add one plain sentence: "Matrix validation uses shell and `jq`; Python is not required to operate this tool."

- [ ] **Step 7: Verify and commit**

Run:

```bash
bash -n build.sh test.sh scripts/matrix_validate.sh scripts/selftest.sh
bash scripts/selftest.sh
scripts/matrix_validate.sh ndb/*/matrix.json
./build.sh --dry-run --ci --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18
```

Expected: all commands pass.

Commit only the files touched in this task:

```bash
rm -f scripts/validate_matrix.py
git add build.sh test.sh scripts/matrix_validate.sh scripts/selftest.sh README.md
if git ls-files --error-unmatch scripts/validate_matrix.py >/dev/null 2>&1; then
  git add -u scripts/validate_matrix.py
fi
git commit -m "Replace matrix validator with shell"
```

## Task 2: Prism API Shell Library

**Files:**
- Create: `scripts/prism.sh`
- Modify: `scripts/selftest.sh`
- Modify: `README.md`

- [ ] **Step 1: Add self-tests for pure Prism helper behavior**

Append this function to `scripts/selftest.sh` and call it after `run_matrix_validator_tests`:

```bash
run_prism_helper_tests() {
  # shellcheck source=/dev/null
  source "$ROOT_DIR/scripts/prism.sh"

  [[ "$(prism_endpoint_from_host "pc.example.com")" == "https://pc.example.com:9440" ]] || fail "endpoint from host"
  [[ "$(prism_endpoint_from_host "https://pc.example.com:9440")" == "https://pc.example.com:9440" ]] || fail "endpoint from URL"

  pass "prism helper pure functions"
}

run_prism_helper_tests
```

- [ ] **Step 2: Run self-tests and verify Prism helper test fails**

Run:

```bash
bash scripts/selftest.sh
```

Expected: failure because `scripts/prism.sh` does not exist.

- [ ] **Step 3: Implement `scripts/prism.sh`**

Create `scripts/prism.sh`:

```bash
#!/usr/bin/env bash

prism_endpoint_from_host() {
  local host=$1
  if [[ "$host" == http://* || "$host" == https://* ]]; then
    printf '%s\n' "${host%/}"
  else
    printf 'https://%s:9440\n' "${host%/}"
  fi
}

prism_require_env() {
  local missing=()
  for var_name in PKR_VAR_pc_username PKR_VAR_pc_password PKR_VAR_pc_ip; do
    if [[ -z "${!var_name:-}" ]]; then
      missing+=("$var_name")
    fi
  done

  if (( ${#missing[@]} > 0 )); then
    printf 'Error: missing Prism environment variables: %s\n' "${missing[*]}" >&2
    return 1
  fi
}

prism_endpoint() {
  prism_endpoint_from_host "$PKR_VAR_pc_ip"
}

prism_curl() {
  local method=$1
  local path=$2
  local payload=${3:-}
  local endpoint
  endpoint=$(prism_endpoint)

  if [[ -n "$payload" ]]; then
    curl -sS -k -u "${PKR_VAR_pc_username}:${PKR_VAR_pc_password}" \
      -H "Content-Type: application/json" \
      -X "$method" \
      -d "$payload" \
      "${endpoint}${path}"
  else
    curl -sS -k -u "${PKR_VAR_pc_username}:${PKR_VAR_pc_password}" \
      -H "Content-Type: application/json" \
      -X "$method" \
      "${endpoint}${path}"
  fi
}

prism_list_resource() {
  local resource=$1
  local kind=$2
  local length=${3:-500}
  prism_curl POST "/api/nutanix/v3/${resource}/list" "$(jq -nc --arg kind "$kind" --argjson length "$length" '{kind: $kind, length: $length}')"
}

prism_find_uuid_by_name() {
  local resource=$1
  local kind=$2
  local name=$3
  prism_list_resource "$resource" "$kind" 2000 \
    | jq -r --arg name "$name" '.entities[]? | select((.spec.name // .status.name // "") == $name) | .metadata.uuid' \
    | head -n 1
}

prism_image_uuid_by_name() {
  prism_find_uuid_by_name images image "$1"
}

prism_vm_uuid_by_name() {
  prism_find_uuid_by_name vms vm "$1"
}

prism_cluster_uuid_by_name() {
  prism_find_uuid_by_name clusters cluster "$1"
}

prism_subnet_uuid_by_name() {
  prism_find_uuid_by_name subnets subnet "$1"
}

prism_task_json() {
  local task_uuid=$1
  prism_curl GET "/api/nutanix/v3/tasks/${task_uuid}"
}

prism_task_status() {
  local task_uuid=$1
  prism_task_json "$task_uuid" | jq -r '.status'
}

prism_wait_task() {
  local task_uuid=$1
  local timeout_seconds=${2:-1800}
  local interval_seconds=${3:-10}
  local elapsed=0
  local task status percent

  while (( elapsed <= timeout_seconds )); do
    task=$(prism_task_json "$task_uuid")
    status=$(jq -r '.status' <<<"$task")
    percent=$(jq -r '.percentage_complete // 0' <<<"$task")
    printf 'Prism task %s: %s %s%%\n' "$task_uuid" "$status" "$percent" >&2

    case "$status" in
      SUCCEEDED)
        printf '%s\n' "$task"
        return 0
        ;;
      FAILED)
        printf '%s\n' "$task" >&2
        return 1
        ;;
    esac

    sleep "$interval_seconds"
    elapsed=$((elapsed + interval_seconds))
  done

  printf 'Error: timed out waiting for Prism task %s after %s seconds.\n' "$task_uuid" "$timeout_seconds" >&2
  return 124
}

prism_vm_json() {
  local vm_uuid=$1
  prism_curl GET "/api/nutanix/v3/vms/${vm_uuid}"
}

prism_vm_ip() {
  local vm_uuid=$1
  prism_vm_json "$vm_uuid" | jq -r '.status.resources.nic_list[0].ip_endpoint_list[0].ip // ""'
}

prism_vm_power_state() {
  local vm_uuid=$1
  prism_vm_json "$vm_uuid" | jq -r '.status.resources.power_state // ""'
}

prism_power_on_vm() {
  local vm_uuid=$1
  local vm_json payload
  vm_json=$(prism_vm_json "$vm_uuid")
  payload=$(jq '.spec.resources.power_state = "ON" | {api_version: .api_version, metadata: .metadata, spec: .spec}' <<<"$vm_json")
  prism_curl PUT "/api/nutanix/v3/vms/${vm_uuid}" "$payload"
}

prism_delete_vm() {
  local vm_uuid=$1
  prism_curl DELETE "/api/nutanix/v3/vms/${vm_uuid}"
}
```

- [ ] **Step 4: Run Prism helper tests**

Run:

```bash
bash -n scripts/prism.sh scripts/selftest.sh
bash scripts/selftest.sh
```

Expected: self-tests pass without requiring Prism credentials.

- [ ] **Step 5: Update README with Prism helper behavior**

Add a troubleshooting note explaining that Prism task UUIDs are now printed for long-running image imports and VM operations.

- [ ] **Step 6: Commit**

```bash
git add scripts/prism.sh scripts/selftest.sh README.md
git commit -m "Add Prism shell helper library"
```

## Task 3: Source Image Preflight And Staging

**Files:**
- Create: `scripts/source_images.sh`
- Modify: `build.sh`
- Modify: `scripts/selftest.sh`
- Modify: `README.md`

- [ ] **Step 1: Add self-tests for source image key normalization**

Append this to `scripts/selftest.sh` and call it after the Prism tests:

```bash
run_source_image_tests() {
  # shellcheck source=/dev/null
  source "$ROOT_DIR/scripts/source_images.sh"

  [[ "$(source_image_key_for_os "Rocky Linux" "9.7")" == "rocky-linux-9.7" ]] || fail "Rocky image key"
  [[ "$(source_image_key_for_os "Red Hat Enterprise Linux (RHEL)" "9.7")" == "rhel-9.7" ]] || fail "RHEL image key"
  [[ "$(source_image_key_for_os "Ubuntu Linux" "24.04")" == "ubuntu-linux-24.04" ]] || fail "Ubuntu image key"

  pass "source image helpers"
}

run_source_image_tests
```

- [ ] **Step 2: Run self-tests and verify the source image test fails**

Run:

```bash
bash scripts/selftest.sh
```

Expected: failure because `scripts/source_images.sh` does not exist.

- [ ] **Step 3: Implement `scripts/source_images.sh`**

Create `scripts/source_images.sh`:

```bash
#!/usr/bin/env bash

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/prism.sh
source "${SCRIPT_DIR}/prism.sh"

source_image_normalize_key_part() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g'
}

source_image_key_for_os() {
  local os_type=$1
  local os_version=$2
  case "$os_type" in
    "Red Hat Enterprise Linux (RHEL)"|"RHEL")
      printf 'rhel-%s\n' "$os_version"
      ;;
    "Rocky Linux")
      printf 'rocky-linux-%s\n' "$os_version"
      ;;
    "Ubuntu Linux")
      printf 'ubuntu-linux-%s\n' "$os_version"
      ;;
    *)
      printf '%s-%s\n' "$(source_image_normalize_key_part "$os_type")" "$os_version"
      ;;
  esac
}

source_image_resolve_from_images_json() {
  local images_file=$1
  local image_key=$2
  local entry_type
  entry_type=$(jq -r --arg key "$image_key" 'if has($key) then (.[$key] | type) else "missing" end' "$images_file")

  case "$entry_type" in
    string)
      jq -r --arg key "$image_key" '.[$key]' "$images_file"
      ;;
    object)
      local env_var
      env_var=$(jq -r --arg key "$image_key" '.[$key].env_var // ""' "$images_file")
      if [[ -z "$env_var" || -z "${!env_var:-}" ]]; then
        printf 'Error: source image for %s requires environment variable %s.\n' "$image_key" "$env_var" >&2
        return 1
      fi
      printf '%s\n' "${!env_var}"
      ;;
    missing)
      printf 'Error: no source image entry for %s in %s.\n' "$image_key" "$images_file" >&2
      return 1
      ;;
    *)
      printf 'Error: unsupported image entry type %s for %s.\n' "$entry_type" "$image_key" >&2
      return 1
      ;;
  esac
}

source_image_name_from_uri() {
  local source_uri=$1
  basename "${source_uri%%\?*}"
}

source_image_value_is_real() {
  local value=${1:-}
  [[ -n "$value" && "$value" != "<not used>" && "$value" != "<temporary local file created at runtime>" && "$value" != "<unresolved"* ]]
}

source_image_preflight() {
  local source_image_name="" source_image_uri="" source_image_path="" cluster_name="" subnet_name=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --source-image-name) source_image_name=$2; shift ;;
      --source-image-uri) source_image_uri=$2; shift ;;
      --source-image-path) source_image_path=$2; shift ;;
      --cluster-name) cluster_name=$2; shift ;;
      --subnet-name) subnet_name=$2; shift ;;
      *) printf 'Error: unknown source image preflight argument: %s\n' "$1" >&2; return 1 ;;
    esac
    shift
  done

  prism_require_env

  if [[ -n "$cluster_name" && -z "$(prism_cluster_uuid_by_name "$cluster_name")" ]]; then
    printf 'Error: Prism cluster not found: %s\n' "$cluster_name" >&2
    return 1
  fi

  if [[ -n "$subnet_name" && -z "$(prism_subnet_uuid_by_name "$subnet_name")" ]]; then
    printf 'Error: Prism subnet not found: %s\n' "$subnet_name" >&2
    return 1
  fi

  if source_image_value_is_real "$source_image_name" && [[ -z "$(prism_image_uuid_by_name "$source_image_name")" ]]; then
    printf 'Error: source image does not exist in Prism: %s\n' "$source_image_name" >&2
    return 1
  fi

  if source_image_value_is_real "$source_image_path" && [[ ! -f "$source_image_path" ]]; then
    printf 'Error: source image path does not exist: %s\n' "$source_image_path" >&2
    return 1
  fi

  if source_image_value_is_real "$source_image_uri"; then
    printf 'Source image URI is ready for staging or Packer import: %s\n' "$source_image_uri"
  fi
}

source_image_stage_remote_uri() {
  local source_uri=$1
  local cluster_uuid=$2
  local image_name=${3:-}
  local timeout_seconds=${4:-3600}
  local existing_uuid payload response task_uuid

  if [[ -z "$image_name" ]]; then
    image_name=$(source_image_name_from_uri "$source_uri")
  fi

  existing_uuid=$(prism_image_uuid_by_name "$image_name")
  if [[ -n "$existing_uuid" ]]; then
    printf '%s\n' "$image_name"
    return 0
  fi

  payload=$(jq -nc \
    --arg image_name "$image_name" \
    --arg source_uri "$source_uri" \
    --arg cluster_uuid "$cluster_uuid" \
    '{
      spec: {
        name: $image_name,
        description: "staged by NDB build tooling",
        resources: {
          image_type: "DISK_IMAGE",
          source_uri: $source_uri,
          initial_placement_ref_list: [
            {kind: "cluster", uuid: $cluster_uuid}
          ]
        }
      },
      metadata: {kind: "image"}
    }')

  response=$(prism_curl POST "/api/nutanix/v3/images" "$payload")
  task_uuid=$(jq -r '.status.execution_context.task_uuid // .status.execution_context.task_uuid[0] // ""' <<<"$response")
  if [[ -z "$task_uuid" ]]; then
    printf 'Error: Prism image create response did not include a task UUID.\n%s\n' "$response" >&2
    return 1
  fi

  if ! prism_wait_task "$task_uuid" "$timeout_seconds" 15 >/dev/null; then
    printf 'Source image staging is still running or failed. Task UUID: %s\n' "$task_uuid" >&2
    printf 'Retry after the import finishes with: --source-image-name "%s"\n' "$image_name" >&2
    return 1
  fi

  printf '%s\n' "$image_name"
}
```

- [ ] **Step 4: Run local tests**

```bash
bash -n scripts/source_images.sh scripts/selftest.sh
bash scripts/selftest.sh
```

Expected: tests pass without Prism credentials.

- [ ] **Step 5: Wire `build.sh` for `--preflight` and `--stage-source`**

In `build.sh`:

Add flags:

```bash
PREFLIGHT_ONLY=false
STAGE_SOURCE=false
```

Parse:

```bash
--preflight)
  PREFLIGHT_ONLY=true
  ;;
--stage-source)
  STAGE_SOURCE=true
  ;;
```

Source helpers after `set -euo pipefail`:

```bash
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/source_images.sh
source "${SCRIPT_DIR}/scripts/source_images.sh"
```

Treat `--preflight` as a live readiness check that contacts Prism but never starts Packer or downloads remote source images. In source-image resolution branches, change conditions that currently use only `DRY_RUN` to use:

```bash
if [[ "$DRY_RUN" == "true" || "$PREFLIGHT_ONLY" == "true" ]]; then
```

Keep environment and live command checks enabled for `--preflight`, because the point of this mode is to prove Prism credentials, cluster, subnet, and source image readiness before a long build starts.

After resolving source image and before Packer:

```bash
if [[ "$PREFLIGHT_ONLY" == "true" ]]; then
  if [[ "$SOURCE_IMAGE_RESOLUTION_STATUS" == "missing-env" ]]; then
    echo "Error: source image environment variable is missing: ${SOURCE_IMAGE_REQUIRED_ENV_VAR}" >&2
    print_dry_run_summary
    exit 1
  fi
  source_image_preflight \
    --source-image-name "$PACKER_SOURCE_IMAGE_NAME" \
    --source-image-uri "$PACKER_SOURCE_IMAGE_URI" \
    --source-image-path "$PACKER_SOURCE_IMAGE_PATH" \
    --cluster-name "$PKR_VAR_cluster_name" \
    --subnet-name "$PKR_VAR_subnet_name"
  print_dry_run_summary
  exit 0
fi

if [[ "$STAGE_SOURCE" == "true" && -z "$PACKER_SOURCE_IMAGE_NAME" && -n "$PACKER_SOURCE_IMAGE_URI" ]]; then
  CLUSTER_UUID=$(prism_cluster_uuid_by_name "$PKR_VAR_cluster_name")
  if [[ -z "$CLUSTER_UUID" ]]; then
    echo "Error: could not find Prism cluster ${PKR_VAR_cluster_name}" >&2
    exit 1
  fi
  PACKER_SOURCE_IMAGE_NAME=$(source_image_stage_remote_uri "$PACKER_SOURCE_IMAGE_URI" "$CLUSTER_UUID")
  PACKER_SOURCE_IMAGE_URI=""
  PACKER_SOURCE_IMAGE_PATH=""
fi
```

- [ ] **Step 6: Update README for preflight and source staging**

Add beginner examples:

```bash
./build.sh --preflight --ci --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18

./build.sh --stage-source --ci --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18

./build.sh --ci --source-image-name "Rocky-9-GenericCloud-LVM-9.7-20251123.2.x86_64.qcow2" --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18
```

Explain that `--stage-source` is for remote source image URIs and that local file paths still go through Packer's local upload path.

- [ ] **Step 7: Verify and commit**

```bash
bash -n build.sh scripts/source_images.sh scripts/prism.sh scripts/selftest.sh
bash scripts/selftest.sh
./build.sh --preflight --ci --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18
```

Expected: local checks pass. The preflight command prints the planned build and does not start Packer.

Commit:

```bash
git add build.sh scripts/source_images.sh scripts/prism.sh scripts/selftest.sh README.md
git commit -m "Add source image preflight and staging"
```

## Task 4: Build Manifest Writer

**Files:**
- Create: `scripts/manifest.sh`
- Modify: `build.sh`
- Modify: `scripts/selftest.sh`
- Modify: `README.md`

- [ ] **Step 1: Add self-test for manifest JSON**

Append this to `scripts/selftest.sh` and call it:

```bash
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

  "$ROOT_DIR/scripts/manifest.sh" finalize \
    --file "$manifest" \
    --status success \
    --artifact-image-uuid "image-uuid-1"

  jq -e '.status == "success" and .artifact.image_uuid == "image-uuid-1"' "$manifest" >/dev/null || fail "manifest finalize JSON"
  pass "manifest helper"
}

run_manifest_tests
```

- [ ] **Step 2: Run self-test and verify manifest test fails**

```bash
bash scripts/selftest.sh
```

Expected: failure because `scripts/manifest.sh` does not exist.

- [ ] **Step 3: Implement `scripts/manifest.sh`**

Create `scripts/manifest.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/manifest.sh init --file FILE --image-name NAME --ndb-version VERSION --db-type TYPE --db-version VERSION --os-type NAME --os-version VERSION --provisioning-role ROLE --matrix-row-json JSON
  scripts/manifest.sh set --file FILE --key jq.path --value VALUE
  scripts/manifest.sh set-json --file FILE --key jq.path --json-value JSON
  scripts/manifest.sh finalize --file FILE --status STATUS [--artifact-image-uuid UUID]
EOF
}

git_commit() {
  git rev-parse HEAD 2>/dev/null || printf 'unknown'
}

git_dirty() {
  if git diff --quiet --ignore-submodules -- 2>/dev/null && git diff --cached --quiet --ignore-submodules -- 2>/dev/null; then
    printf 'false'
  else
    printf 'true'
  fi
}

manifest_init() {
  local file="" image_name="" ndb_version="" db_type="" db_version="" os_type="" os_version="" provisioning_role="" matrix_row_json="{}"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --file) file=$2; shift ;;
      --image-name) image_name=$2; shift ;;
      --ndb-version) ndb_version=$2; shift ;;
      --db-type) db_type=$2; shift ;;
      --db-version) db_version=$2; shift ;;
      --os-type) os_type=$2; shift ;;
      --os-version) os_version=$2; shift ;;
      --provisioning-role) provisioning_role=$2; shift ;;
      --matrix-row-json) matrix_row_json=$2; shift ;;
      *) usage >&2; return 1 ;;
    esac
    shift
  done

  mkdir -p "$(dirname "$file")"
  jq -nc \
    --arg image_name "$image_name" \
    --arg ndb_version "$ndb_version" \
    --arg db_type "$db_type" \
    --arg db_version "$db_version" \
    --arg os_type "$os_type" \
    --arg os_version "$os_version" \
    --arg provisioning_role "$provisioning_role" \
    --argjson matrix_row "$matrix_row_json" \
    --arg started_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg git_commit "$(git_commit)" \
    --argjson git_dirty "$(git_dirty)" \
    '{
      image_name: $image_name,
      status: "running",
      started_at: $started_at,
      selection: {
        ndb_version: $ndb_version,
        db_type: $db_type,
        db_version: $db_version,
        os_type: $os_type,
        os_version: $os_version,
        provisioning_role: $provisioning_role
      },
      matrix_row: $matrix_row,
      source_image: {},
      packer: {
        started_at: null,
        finished_at: null,
        duration_seconds: null
      },
      artifact: {},
      validation: {
        in_guest: "not-requested",
        artifact: "not-requested",
        artifact_vm_name: null,
        artifact_vm_uuid: null
      },
      cleanup: {},
      git: {
        commit: $git_commit,
        dirty: $git_dirty
      }
    }' > "$file"
}

manifest_set() {
  local file="" key="" value=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --file) file=$2; shift ;;
      --key) key=$2; shift ;;
      --value) value=$2; shift ;;
      *) usage >&2; return 1 ;;
    esac
    shift
  done

  local tmp
  tmp=$(mktemp)
  jq --arg value "$value" "$key = \$value" "$file" > "$tmp"
  mv "$tmp" "$file"
}

manifest_set_json() {
  local file="" key="" json_value=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --file) file=$2; shift ;;
      --key) key=$2; shift ;;
      --json-value) json_value=$2; shift ;;
      *) usage >&2; return 1 ;;
    esac
    shift
  done

  local tmp
  tmp=$(mktemp)
  jq --argjson value "$json_value" "$key = \$value" "$file" > "$tmp"
  mv "$tmp" "$file"
}

manifest_finalize() {
  local file="" status="" artifact_image_uuid=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --file) file=$2; shift ;;
      --status) status=$2; shift ;;
      --artifact-image-uuid) artifact_image_uuid=$2; shift ;;
      *) usage >&2; return 1 ;;
    esac
    shift
  done

  local tmp
  tmp=$(mktemp)
  jq \
    --arg status "$status" \
    --arg finished_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg artifact_image_uuid "$artifact_image_uuid" \
    '.status = $status
     | .finished_at = $finished_at
     | if $artifact_image_uuid != "" then .artifact.image_uuid = $artifact_image_uuid else . end' \
    "$file" > "$tmp"
  mv "$tmp" "$file"
}

case "${1:-}" in
  init)
    shift
    manifest_init "$@"
    ;;
  set)
    shift
    manifest_set "$@"
    ;;
  set-json)
    shift
    manifest_set_json "$@"
    ;;
  finalize)
    shift
    manifest_finalize "$@"
    ;;
  -h|--help|"")
    usage
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac
```

- [ ] **Step 4: Wire `build.sh` for `--manifest`**

Add:

```bash
WRITE_MANIFEST=false
MANIFEST_FILE=""
```

Parse:

```bash
--manifest)
  WRITE_MANIFEST=true
  ;;
```

Source helper:

```bash
MANIFEST_HELPER="${SCRIPT_DIR}/scripts/manifest.sh"
```

After `IMAGE_NAME` is generated:

```bash
if [[ "$WRITE_MANIFEST" == "true" ]]; then
  MANIFEST_FILE="manifests/${IMAGE_NAME}.json"
  "$MANIFEST_HELPER" init \
    --file "$MANIFEST_FILE" \
    --image-name "$IMAGE_NAME" \
    --ndb-version "$NDB_VERSION" \
    --db-type "$DB_TYPE" \
    --db-version "$DB_VERSION" \
    --os-type "$OS_TYPE" \
    --os-version "$OS_VERSION" \
    --provisioning-role "$PROVISIONING_ROLE" \
    --matrix-row-json "$CONFIG"
fi
```

After Packer succeeds and the artifact image UUID is resolved:

```bash
if [[ "$WRITE_MANIFEST" == "true" ]]; then
  "$MANIFEST_HELPER" finalize --file "$MANIFEST_FILE" --status success --artifact-image-uuid "$ARTIFACT_IMAGE_UUID"
fi
```

Add a failure trap that finalizes the manifest with `failed` if `MANIFEST_FILE` exists and the script exits non-zero.

- [ ] **Step 5: Update `.gitignore` for manifests**

Add:

```gitignore
manifests/*.json
!manifests/.gitkeep
```

Create `manifests/.gitkeep`.

- [ ] **Step 6: Update README for manifests**

Add:

```bash
./build.sh --ci --validate --manifest --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18
```

Explain that manifests are written under `manifests/` and are ignored by git.

- [ ] **Step 7: Verify and commit**

```bash
bash -n build.sh scripts/manifest.sh scripts/selftest.sh
bash scripts/selftest.sh
./build.sh --dry-run --manifest --ci --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18
```

Expected: local tests pass, dry-run remains non-destructive, and manifest flags are accepted.

Commit:

```bash
git add build.sh scripts/manifest.sh scripts/selftest.sh README.md .gitignore manifests/.gitkeep
git commit -m "Add build manifest support"
```

## Task 5: Artifact Validation Helper

**Files:**
- Create: `scripts/artifact_validate.sh`
- Modify: `build.sh`
- Modify: `test.sh`
- Modify: `ansible/2.9/roles/validate_postgres/tasks/main.yml`
- Modify: `ansible/2.10/roles/validate_postgres/tasks/main.yml`
- Modify: `README.md`

- [ ] **Step 1: Add argument-validation check to self-tests**

Append this to `scripts/selftest.sh` and call it:

```bash
run_artifact_validate_tests() {
  if "$ROOT_DIR/scripts/artifact_validate.sh" --help >/dev/null; then
    pass "artifact validation help"
  else
    fail "artifact validation help"
  fi
}

run_artifact_validate_tests
```

- [ ] **Step 2: Run self-tests and verify artifact helper test fails**

```bash
bash scripts/selftest.sh
```

Expected: failure because `scripts/artifact_validate.sh` does not exist.

- [ ] **Step 3: Implement `scripts/artifact_validate.sh`**

Create `scripts/artifact_validate.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "${SCRIPT_DIR}/.." && pwd)
# shellcheck source=scripts/prism.sh
source "${SCRIPT_DIR}/prism.sh"

usage() {
  cat <<'EOF'
Usage: scripts/artifact_validate.sh --image-name NAME --ndb-version VERSION --db-version VERSION [options]

Options:
  --image-name NAME       Final Prism image name to validate
  --ndb-version VERSION   NDB version whose Ansible validation role should run
  --db-version VERSION    PostgreSQL major version expected in the image
  --db-type TYPE          Database type, default pgsql
  --extensions JSON       JSON array of matrix extension IDs; Ansible maps them to expected SQL extension names
  --result-file FILE      Write validation VM status and cleanup status as JSON
  --keep-on-failure       Leave validation VM running when validation fails
  -h, --help              Show help
EOF
}

IMAGE_NAME=""
NDB_VERSION=""
DB_VERSION=""
DB_TYPE="pgsql"
EXTENSIONS_JSON="[]"
RESULT_FILE=""
KEEP_ON_FAILURE=false
VALIDATION_STATUS="not-started"
CLEANUP_STATUS="not-started"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image-name) IMAGE_NAME=$2; shift ;;
    --ndb-version) NDB_VERSION=$2; shift ;;
    --db-version) DB_VERSION=$2; shift ;;
    --db-type) DB_TYPE=$2; shift ;;
    --extensions) EXTENSIONS_JSON=$2; shift ;;
    --result-file) RESULT_FILE=$2; shift ;;
    --keep-on-failure) KEEP_ON_FAILURE=true ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 1 ;;
  esac
  shift
done

if [[ -z "$IMAGE_NAME" || -z "$NDB_VERSION" || -z "$DB_VERSION" ]]; then
  usage >&2
  exit 1
fi

prism_require_env

KEY_FILE="${ROOT_DIR}/packer/id_rsa"
PUBLIC_KEY_FILE="${ROOT_DIR}/packer/id_rsa.pub"
USER_DATA_TEMPLATE="${ROOT_DIR}/packer/http/user-data"
ANSIBLE_DIR="${ROOT_DIR}/ansible/${NDB_VERSION}"
VALIDATION_VM_NAME="validate-$(printf '%s' "${IMAGE_NAME}" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g' | cut -c1-48)-$(date +%Y%m%d%H%M%S)"
SSH_ARGS="-o IdentitiesOnly=yes -o IdentityAgent=none -o PreferredAuthentications=publickey -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
VM_UUID=""
TMPDIR=$(mktemp -d)

write_result_file() {
  [[ -z "$RESULT_FILE" ]] && return 0
  mkdir -p "$(dirname "$RESULT_FILE")"
  jq -nc \
    --arg image_name "$IMAGE_NAME" \
    --arg image_uuid "${IMAGE_UUID:-}" \
    --arg vm_name "$VALIDATION_VM_NAME" \
    --arg vm_uuid "${VM_UUID:-}" \
    --arg status "$VALIDATION_STATUS" \
    --arg cleanup_status "$CLEANUP_STATUS" \
    '{
      image_name: $image_name,
      image_uuid: $image_uuid,
      vm_name: $vm_name,
      vm_uuid: $vm_uuid,
      status: $status,
      cleanup_status: $cleanup_status
    }' > "$RESULT_FILE"
}

cleanup() {
  local rc=$?
  if [[ "$VALIDATION_STATUS" == "running" && "$rc" -ne 0 ]]; then
    VALIDATION_STATUS="failed"
  fi
  if [[ -n "$VM_UUID" && ( "$rc" -eq 0 || "$KEEP_ON_FAILURE" != "true" ) ]]; then
    if prism_delete_vm "$VM_UUID" >/dev/null; then
      CLEANUP_STATUS="deleted"
    else
      CLEANUP_STATUS="delete-failed"
      printf 'Warning: failed to delete validation VM %s (%s)\n' "$VALIDATION_VM_NAME" "$VM_UUID" >&2
    fi
  elif [[ -n "$VM_UUID" ]]; then
    CLEANUP_STATUS="retained"
    printf 'Validation VM retained: %s (%s)\n' "$VALIDATION_VM_NAME" "$VM_UUID" >&2
  else
    CLEANUP_STATUS="not-created"
  fi
  write_result_file
  rm -rf "$TMPDIR"
  exit "$rc"
}
trap cleanup EXIT

IMAGE_UUID=$(prism_image_uuid_by_name "$IMAGE_NAME")
if [[ -z "$IMAGE_UUID" ]]; then
  printf 'Error: image not found in Prism: %s\n' "$IMAGE_NAME" >&2
  exit 1
fi

CLUSTER_UUID=$(prism_cluster_uuid_by_name "$PKR_VAR_cluster_name")
SUBNET_UUID=$(prism_subnet_uuid_by_name "$PKR_VAR_subnet_name")
if [[ -z "$CLUSTER_UUID" || -z "$SUBNET_UUID" ]]; then
  printf 'Error: cluster or subnet not found in Prism.\n' >&2
  exit 1
fi

PUBLIC_KEY=$(tr -d '\n' < "$PUBLIC_KEY_FILE" | sed 's/[\/&]/\\&/g')
USER_DATA=$(sed "s|\${ssh_public_key}|${PUBLIC_KEY}|" "$USER_DATA_TEMPLATE")
USER_DATA_B64=$(printf '%s' "$USER_DATA" | base64 | tr -d '\n')

CREATE_PAYLOAD=$(jq -nc \
  --arg name "$VALIDATION_VM_NAME" \
  --arg cluster_uuid "$CLUSTER_UUID" \
  --arg subnet_uuid "$SUBNET_UUID" \
  --arg image_uuid "$IMAGE_UUID" \
  --arg user_data "$USER_DATA_B64" \
  '{
    spec: {
      name: $name,
      cluster_reference: {kind: "cluster", uuid: $cluster_uuid},
      resources: {
        num_threads_per_core: 1,
        num_sockets: 2,
        num_vcpus_per_socket: 1,
        memory_size_mib: 4096,
        boot_config: {boot_type: "UEFI", boot_device_order_list: ["CDROM", "DISK", "NETWORK"]},
        disk_list: [
          {
            data_source_reference: {kind: "image", uuid: $image_uuid},
            device_properties: {device_type: "DISK", disk_address: {adapter_type: "SCSI", device_index: 0}}
          },
          {
            device_properties: {device_type: "CDROM", disk_address: {adapter_type: "IDE", device_index: 0}}
          }
        ],
        nic_list: [
          {subnet_reference: {kind: "subnet", uuid: $subnet_uuid}, is_connected: true}
        ],
        guest_customization: {cloud_init: {user_data: $user_data}}
      }
    },
    metadata: {kind: "vm"}
  }')

CREATE_RESPONSE=$(prism_curl POST "/api/nutanix/v3/vms" "$CREATE_PAYLOAD")
VM_UUID=$(jq -r '.metadata.uuid' <<<"$CREATE_RESPONSE")
CREATE_TASK_UUID=$(jq -r '.status.execution_context.task_uuid' <<<"$CREATE_RESPONSE")
printf 'Validation VM: %s (%s)\n' "$VALIDATION_VM_NAME" "$VM_UUID"
VALIDATION_STATUS="running"
prism_wait_task "$CREATE_TASK_UUID" 900 5 >/dev/null
prism_power_on_vm "$VM_UUID" >/dev/null

VM_IP=""
for _ in $(seq 1 120); do
  VM_IP=$(prism_vm_ip "$VM_UUID")
  [[ -n "$VM_IP" ]] && break
  sleep 5
done

if [[ -z "$VM_IP" ]]; then
  printf 'Error: timed out waiting for validation VM IP.\n' >&2
  exit 1
fi
printf 'Validation VM IP: %s\n' "$VM_IP"

for _ in $(seq 1 90); do
  if ssh $SSH_ARGS -i "$KEY_FILE" -o ConnectTimeout=5 "packer@${VM_IP}" true >/dev/null 2>&1; then
    break
  fi
  sleep 10
done
ssh $SSH_ARGS -i "$KEY_FILE" -o ConnectTimeout=5 "packer@${VM_IP}" true >/dev/null

cat > "${TMPDIR}/playbook.yml" <<'YAML'
---
- hosts: all
  gather_facts: true
  roles:
    - validate_postgres
YAML

jq -nc \
  --arg db_version "$DB_VERSION" \
  --arg db_type "$DB_TYPE" \
  --argjson extensions "$EXTENSIONS_JSON" \
  '{
    db_version: $db_version,
    db_type: $db_type,
    configure_ndb_sudoers: true,
    postgres_extensions: $extensions,
    postgres_extensions_databases: ["postgres"]
  }' > "${TMPDIR}/vars.json"

(
  cd "$ANSIBLE_DIR"
  ANSIBLE_CONFIG=ansible.cfg ansible-playbook \
    -i "${VM_IP}," \
    -u packer \
    --private-key "$KEY_FILE" \
    --ssh-common-args "$SSH_ARGS" \
    -e "@${ANSIBLE_DIR}/roles/postgres/defaults/main.yml" \
    -e "@${TMPDIR}/vars.json" \
    "${TMPDIR}/playbook.yml"
)

VALIDATION_STATUS="passed"
printf 'Artifact validation passed for %s\n' "$IMAGE_NAME"
```

- [ ] **Step 4: Teach `validate_postgres` to derive expected SQL extension names**

In both `ansible/2.9/roles/validate_postgres/tasks/main.yml` and `ansible/2.10/roles/validate_postgres/tasks/main.yml`, replace the single "Determine expected PostgreSQL extensions for validation" task with these two tasks:

```yaml
- name: Use explicit PostgreSQL extension creation list when provided
  ansible.builtin.set_fact:
    validate_expected_postgres_extensions: "{{ postgres_extensions_to_create | default([]) | unique }}"
  when:
    - postgres_extensions_to_create | default([]) | length > 0

- name: Derive expected PostgreSQL extensions from extension metadata
  ansible.builtin.set_fact:
    validate_expected_postgres_extensions: "{{ (validate_expected_postgres_extensions | default([])) + (version_supported | ternary([sql_extension_name], [])) }}"
  loop: "{{ postgres_extensions | default([]) }}"
  loop_control:
    loop_var: extension_name
  vars:
    extension_metadata_family: "{{ postgres_extension_metadata.get(ansible_os_family, {}) }}"
    extension_metadata: "{{ extension_metadata_family.get(extension_name, {}) }}"
    unsupported_versions: "{{ extension_metadata.get('unsupported_versions', []) }}"
    supported_versions: "{{ extension_metadata.get('supported_versions', []) }}"
    version_supported: "{{ (supported_versions | length == 0 or validate_postgres_major_version in supported_versions) and (validate_postgres_major_version not in unsupported_versions) }}"
    sql_extension_name: "{{ extension_metadata.get('sql_name', extension_name) }}"
  when:
    - validate_expected_postgres_extensions | default([]) | length == 0
    - postgres_extensions | default([]) | length > 0
```

This keeps artifact validation aligned with provisioning behavior: `pgvector` validates as SQL extension `vector`, while extensions skipped during provisioning because upstream packages are unavailable are not falsely required during final image validation.

- [ ] **Step 5: Wire `build.sh` for `--validate-artifact`**

Add:

```bash
VALIDATE_ARTIFACT=false
```

Parse:

```bash
--validate-artifact)
  VALIDATE_ARTIFACT=true
  ;;
```

After Packer succeeds:

```bash
ARTIFACT_IMAGE_UUID=$(prism_image_uuid_by_name "$IMAGE_NAME")
if [[ "$VALIDATE_ARTIFACT" == "true" ]]; then
  ARTIFACT_VALIDATION_RESULT_FILE=$(mktemp -t ndb-artifact-validation.XXXXXX.json)
  TEMP_FILES+=("$ARTIFACT_VALIDATION_RESULT_FILE")
  scripts/artifact_validate.sh \
    --image-name "$IMAGE_NAME" \
    --ndb-version "$NDB_VERSION" \
    --db-type "$DB_TYPE" \
    --db-version "$DB_VERSION" \
    --extensions "$(printf '%s\n' "$POSTGRES_EXTENSIONS_JSON")" \
    --result-file "$ARTIFACT_VALIDATION_RESULT_FILE"
fi
```

If `DEBUG=true`, pass `--keep-on-failure`.

- [ ] **Step 6: Wire `test.sh` pass-through**

Add option parsing for:

```bash
--validate-artifact)
  VALIDATE_ARTIFACT=true
  ;;
--manifest)
  WRITE_MANIFEST=true
  ;;
```

When building `BUILD_ARGS`, append:

```bash
if [[ "$VALIDATE_ARTIFACT" == "true" ]]; then
  BUILD_ARGS+=(--validate-artifact)
fi
if [[ "$WRITE_MANIFEST" == "true" ]]; then
  BUILD_ARGS+=(--manifest)
fi
```

- [ ] **Step 7: Update README for artifact validation**

Add the production command:

```bash
./build.sh --ci --validate --validate-artifact --manifest --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18
```

Explain that artifact validation boots a disposable VM from the saved image and removes it after validation.

- [ ] **Step 8: Verify and commit**

```bash
bash -n build.sh test.sh scripts/artifact_validate.sh scripts/prism.sh scripts/selftest.sh
bash scripts/selftest.sh
ANSIBLE_CONFIG=ansible/2.9/ansible.cfg ansible-playbook -i ansible/2.9/inventory/hosts ansible/2.9/playbooks/site.yml --syntax-check
ANSIBLE_CONFIG=ansible/2.10/ansible.cfg ansible-playbook -i ansible/2.10/inventory/hosts ansible/2.10/playbooks/site.yml --syntax-check
./build.sh --dry-run --validate --validate-artifact --manifest --ci --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18
```

Expected: local checks pass and dry-run shows artifact validation enabled without contacting Prism.

Commit:

```bash
git add build.sh test.sh scripts/artifact_validate.sh scripts/selftest.sh ansible/2.9/roles/validate_postgres/tasks/main.yml ansible/2.10/roles/validate_postgres/tasks/main.yml README.md
git commit -m "Add final artifact validation"
```

## Task 6: Manifest Status Integration And Failure Handling

**Files:**
- Modify: `build.sh`
- Modify: `scripts/manifest.sh`
- Modify: `scripts/artifact_validate.sh`
- Modify: `README.md`

- [ ] **Step 1: Add manifest status updates around source and validation stages**

In `build.sh`, after source image resolution:

```bash
if [[ "$WRITE_MANIFEST" == "true" ]]; then
  SOURCE_IMAGE_UUID=""
  if [[ -n "$PACKER_SOURCE_IMAGE_NAME" ]]; then
    SOURCE_IMAGE_UUID=$(prism_image_uuid_by_name "$PACKER_SOURCE_IMAGE_NAME" || true)
  fi

  "$MANIFEST_HELPER" set --file "$MANIFEST_FILE" --key '.source_image.mode' --value "$SOURCE_IMAGE_RUNTIME_ACTION"
  "$MANIFEST_HELPER" set --file "$MANIFEST_FILE" --key '.source_image.name' --value "$PACKER_SOURCE_IMAGE_NAME"
  "$MANIFEST_HELPER" set --file "$MANIFEST_FILE" --key '.source_image.uri' --value "$PACKER_SOURCE_IMAGE_URI"
  "$MANIFEST_HELPER" set --file "$MANIFEST_FILE" --key '.source_image.path' --value "$PACKER_SOURCE_IMAGE_PATH"
  "$MANIFEST_HELPER" set --file "$MANIFEST_FILE" --key '.source_image.uuid' --value "$SOURCE_IMAGE_UUID"
fi
```

Immediately before invoking Packer:

```bash
PACKER_STARTED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
PACKER_STARTED_EPOCH=$(date -u +%s)
if [[ "$WRITE_MANIFEST" == "true" ]]; then
  "$MANIFEST_HELPER" set --file "$MANIFEST_FILE" --key '.packer.started_at' --value "$PACKER_STARTED_AT"
fi
```

Immediately after Packer succeeds and `ARTIFACT_IMAGE_UUID` is resolved:

```bash
PACKER_FINISHED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
PACKER_DURATION_SECONDS=$(( $(date -u +%s) - PACKER_STARTED_EPOCH ))
if [[ "$WRITE_MANIFEST" == "true" ]]; then
  "$MANIFEST_HELPER" set --file "$MANIFEST_FILE" --key '.packer.finished_at' --value "$PACKER_FINISHED_AT"
  "$MANIFEST_HELPER" set-json --file "$MANIFEST_FILE" --key '.packer.duration_seconds' --json-value "$PACKER_DURATION_SECONDS"
  "$MANIFEST_HELPER" set --file "$MANIFEST_FILE" --key '.artifact.image_name' --value "$IMAGE_NAME"
  "$MANIFEST_HELPER" set --file "$MANIFEST_FILE" --key '.artifact.image_uuid' --value "$ARTIFACT_IMAGE_UUID"
fi
```

After in-guest validation is requested:

```bash
if [[ "$WRITE_MANIFEST" == "true" && "$VALIDATE_BUILD" == "true" ]]; then
  "$MANIFEST_HELPER" set --file "$MANIFEST_FILE" --key '.validation.in_guest' --value "passed"
fi
```

After artifact validation succeeds:

```bash
if [[ "$WRITE_MANIFEST" == "true" && "$VALIDATE_ARTIFACT" == "true" ]]; then
  "$MANIFEST_HELPER" set --file "$MANIFEST_FILE" --key '.validation.artifact' --value "passed"
fi
```

- [ ] **Step 2: Add a build failure trap**

Add near the top of `build.sh` and replace the old `trap cleanup EXIT` with this combined trap:

```bash
function finalize_on_exit() {
  local rc=$?
  cleanup
  if [[ "$rc" -ne 0 && -n "${MANIFEST_FILE:-}" && -f "${MANIFEST_FILE:-}" ]]; then
    scripts/manifest.sh finalize --file "$MANIFEST_FILE" --status failed || true
  fi
  exit "$rc"
}
trap finalize_on_exit EXIT
```

Move successful manifest finalization to the very end of the build, after Packer, in-guest validation, and artifact validation have all completed:

```bash
if [[ "$WRITE_MANIFEST" == "true" ]]; then
  "$MANIFEST_HELPER" finalize --file "$MANIFEST_FILE" --status success --artifact-image-uuid "$ARTIFACT_IMAGE_UUID"
fi
```

Remove any earlier `finalize --status success` call that runs immediately after Packer but before artifact validation.

- [ ] **Step 3: Keep failed artifact validation explicit**

Wrap the artifact validation call:

```bash
if [[ "$VALIDATE_ARTIFACT" == "true" ]]; then
  ARTIFACT_VALIDATION_RESULT_FILE=$(mktemp -t ndb-artifact-validation.XXXXXX.json)
  TEMP_FILES+=("$ARTIFACT_VALIDATION_RESULT_FILE")
  ARTIFACT_VALIDATION_ARGS=(
    scripts/artifact_validate.sh
    --image-name "$IMAGE_NAME"
    --ndb-version "$NDB_VERSION"
    --db-type "$DB_TYPE"
    --db-version "$DB_VERSION"
    --extensions "$(printf '%s\n' "$POSTGRES_EXTENSIONS_JSON")"
    --result-file "$ARTIFACT_VALIDATION_RESULT_FILE"
  )
  if [[ "$DEBUG" == "true" ]]; then
    ARTIFACT_VALIDATION_ARGS+=(--keep-on-failure)
  fi

  ARTIFACT_VALIDATION_STATUS="passed"
  if "${ARTIFACT_VALIDATION_ARGS[@]}"; then
    [[ "$WRITE_MANIFEST" == "true" ]] && "$MANIFEST_HELPER" set --file "$MANIFEST_FILE" --key '.validation.artifact' --value "passed"
  else
    ARTIFACT_VALIDATION_STATUS="failed"
    [[ "$WRITE_MANIFEST" == "true" ]] && "$MANIFEST_HELPER" set --file "$MANIFEST_FILE" --key '.validation.artifact' --value "failed"
  fi

  if [[ "$WRITE_MANIFEST" == "true" && -f "$ARTIFACT_VALIDATION_RESULT_FILE" ]]; then
    "$MANIFEST_HELPER" set --file "$MANIFEST_FILE" --key '.validation.artifact_vm_name' --value "$(jq -r '.vm_name // ""' "$ARTIFACT_VALIDATION_RESULT_FILE")"
    "$MANIFEST_HELPER" set --file "$MANIFEST_FILE" --key '.validation.artifact_vm_uuid' --value "$(jq -r '.vm_uuid // ""' "$ARTIFACT_VALIDATION_RESULT_FILE")"
    "$MANIFEST_HELPER" set --file "$MANIFEST_FILE" --key '.cleanup.artifact_validation_vm' --value "$(jq -r '.cleanup_status // ""' "$ARTIFACT_VALIDATION_RESULT_FILE")"
  fi

  if [[ "$ARTIFACT_VALIDATION_STATUS" == "failed" ]]; then
    exit 1
  fi
fi
```

- [ ] **Step 4: Update README troubleshooting**

Add short troubleshooting entries for:

- Source image import timed out.
- Artifact validation VM was left behind.
- SSH authentication fails during artifact validation.
- Manifest status is `failed`.

- [ ] **Step 5: Verify and commit**

```bash
bash -n build.sh scripts/manifest.sh scripts/artifact_validate.sh
bash scripts/selftest.sh
./build.sh --dry-run --validate --validate-artifact --manifest --ci --ndb-version 2.9 --db-type pgsql --os "Rocky Linux" --os-version 9.6 --db-version 17
```

Expected: checks pass.

Commit:

```bash
git add build.sh scripts/manifest.sh scripts/artifact_validate.sh README.md
git commit -m "Record build and validation status in manifests"
```

## Task 7: Release Scaffolding

**Files:**
- Create: `scripts/release_scaffold.sh`
- Modify: `scripts/selftest.sh`
- Modify: `README.md`

- [ ] **Step 1: Add release scaffold dry-run self-test**

Append this to `scripts/selftest.sh` and call it:

```bash
run_release_scaffold_tests() {
  "$ROOT_DIR/scripts/release_scaffold.sh" 9.99 --from 2.10 --dry-run | grep -q "ansible/9.99" || fail "release scaffold dry-run"
  pass "release scaffold dry-run"
}

run_release_scaffold_tests
```

- [ ] **Step 2: Run self-test and verify release scaffold test fails**

```bash
bash scripts/selftest.sh
```

Expected: failure because `scripts/release_scaffold.sh` does not exist.

- [ ] **Step 3: Implement `scripts/release_scaffold.sh`**

Create `scripts/release_scaffold.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/release_scaffold.sh NEW_VERSION --from OLD_VERSION [--dry-run]

Creates ndb/NEW_VERSION and ansible/NEW_VERSION from an existing release.
EOF
}

NEW_VERSION=""
FROM_VERSION=""
DRY_RUN=false

if [[ $# -gt 0 ]]; then
  NEW_VERSION=$1
  shift
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --from)
      FROM_VERSION=$2
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 1
      ;;
  esac
  shift
done

if [[ -z "$NEW_VERSION" || -z "$FROM_VERSION" ]]; then
  usage >&2
  exit 1
fi

for source_path in "ndb/${FROM_VERSION}" "ansible/${FROM_VERSION}"; do
  if [[ ! -d "$source_path" ]]; then
    printf 'Error: source path missing: %s\n' "$source_path" >&2
    exit 1
  fi
done

for target_path in "ndb/${NEW_VERSION}" "ansible/${NEW_VERSION}"; do
  if [[ -e "$target_path" ]]; then
    printf 'Error: target already exists: %s\n' "$target_path" >&2
    exit 1
  fi
done

if [[ "$DRY_RUN" == "true" ]]; then
  printf 'Would copy ndb/%s to ndb/%s\n' "$FROM_VERSION" "$NEW_VERSION"
  printf 'Would copy ansible/%s to ansible/%s\n' "$FROM_VERSION" "$NEW_VERSION"
  printf 'Would rewrite ndb_version values in ndb/%s/matrix.json\n' "$NEW_VERSION"
  printf 'Would create ndb/%s/REVIEW.md\n' "$NEW_VERSION"
  exit 0
fi

cp -R "ndb/${FROM_VERSION}" "ndb/${NEW_VERSION}"
cp -R "ansible/${FROM_VERSION}" "ansible/${NEW_VERSION}"

if [[ -f "ndb/${NEW_VERSION}/matrix.json" ]]; then
  tmp=$(mktemp)
  jq --arg version "$NEW_VERSION" 'map(.ndb_version = $version)' "ndb/${NEW_VERSION}/matrix.json" > "$tmp"
  mv "$tmp" "ndb/${NEW_VERSION}/matrix.json"
fi

cat > "ndb/${NEW_VERSION}/REVIEW.md" <<EOF
# NDB ${NEW_VERSION} Release Review

Review these items before building this release:

- Confirm every PostgreSQL row against the NDB ${NEW_VERSION} release notes.
- Confirm OS versions and source image entries exist in images.json.
- Confirm PostgreSQL extensions are available for each OS and DB version.
- Confirm HA metadata versions for Patroni and etcd.
- Run scripts/matrix_validate.sh ndb/${NEW_VERSION}/matrix.json.
- Run Ansible syntax check for ansible/${NEW_VERSION}/playbooks/site.yml.
EOF

scripts/matrix_validate.sh "ndb/${NEW_VERSION}/matrix.json"
ANSIBLE_CONFIG="ansible/${NEW_VERSION}/ansible.cfg" ansible-playbook -i "ansible/${NEW_VERSION}/inventory/hosts" "ansible/${NEW_VERSION}/playbooks/site.yml" --syntax-check
```

- [ ] **Step 4: Update README with release onboarding**

Add:

```bash
scripts/release_scaffold.sh 2.11 --from 2.10
scripts/matrix_validate.sh ndb/2.11/matrix.json
ANSIBLE_CONFIG=ansible/2.11/ansible.cfg ansible-playbook -i ansible/2.11/inventory/hosts ansible/2.11/playbooks/site.yml --syntax-check
```

Explain that the scaffold creates a starting point and that the matrix must still be reviewed against release notes.

- [ ] **Step 5: Verify and commit**

```bash
bash -n scripts/release_scaffold.sh scripts/selftest.sh
bash scripts/selftest.sh
scripts/release_scaffold.sh 9.99 --from 2.10 --dry-run
```

Expected: checks pass and no `ndb/9.99` or `ansible/9.99` directory is created.

Commit:

```bash
git add scripts/release_scaffold.sh scripts/selftest.sh README.md
git commit -m "Add NDB release scaffolding"
```

## Task 8: Beginner README Restructure

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Reorder README around beginner workflows**

Restructure `README.md` into these top-level sections:

```markdown
# NDB Packer Image Builder

## What This Tool Does
## Quick Start
## Common Commands
## What Happens During A Build
## Environment Variables
## Source Images
## Validation
## Manifests
## Release Onboarding
## Troubleshooting
## Reference
```

- [ ] **Step 2: Add a complete happy-path command block**

Include this command sequence in `Quick Start`:

```bash
cp .env.example .env
source .env

./build.sh --dry-run --ci --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18

./build.sh --ci --validate --validate-artifact --manifest --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18
```

- [ ] **Step 3: Add common task commands**

Include exact commands for:

```bash
scripts/matrix_validate.sh ndb/*/matrix.json

./build.sh --preflight --ci --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18

./build.sh --stage-source --ci --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18

./build.sh --ci --source-image-name "Rocky-9-GenericCloud-LVM-9.7-20251123.2.x86_64.qcow2" --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18

./test.sh --include-ndb 2.10 --include-os "Rocky Linux" --validate --validate-artifact --manifest
```

- [ ] **Step 4: Add troubleshooting entries**

Add entries with this structure:

```markdown
### Source image import timed out

The Prism import may still be running even after Packer gives up. Find the task UUID in the output, wait for it to finish in Prism, then rerun the build with `--source-image-name`.

### Artifact validation cannot SSH

The validation helper forces the repo key and disables the local SSH agent. Confirm the validation VM has an IP, then rerun with debug retention if inspection is needed.

### A validation VM was left behind

The failed command prints the VM name and UUID. Delete it from Prism after inspection.
```

- [ ] **Step 5: Verify README command references**

Run:

```bash
! grep -En -- "python3 scripts/validate_matrix.py" README.md
grep -En -- "--validate-artifact|--manifest|release_scaffold|stage-source|preflight" README.md
```

Expected: no Python validator reference, and all new commands are present.

- [ ] **Step 6: Commit**

```bash
git add README.md
git commit -m "Clarify image builder operator guide"
```

## Task 9: Final Verification Pass

**Files:**
- Modify only if a verification failure requires a fix.

- [ ] **Step 1: Run shell syntax checks**

```bash
bash -n build.sh test.sh scripts/*.sh
```

Expected: no output and exit code `0`.

- [ ] **Step 2: Run shell self-tests**

```bash
bash scripts/selftest.sh
```

Expected: every test prints `PASS`.

- [ ] **Step 3: Run matrix validation**

```bash
scripts/matrix_validate.sh ndb/*/matrix.json
```

Expected: every matrix prints `Matrix validation succeeded`.

- [ ] **Step 4: Run Packer formatting and validation**

```bash
packer fmt -check packer
packer validate packer
```

Expected: both pass. If `packer validate` requires Prism variables, source `.env` first.

- [ ] **Step 5: Run Ansible syntax checks**

```bash
for version in ansible/*; do
  if [[ -d "$version" ]]; then
    ANSIBLE_CONFIG="$version/ansible.cfg" ansible-playbook -i "$version/inventory/hosts" "$version/playbooks/site.yml" --syntax-check
  fi
done
```

Expected: every playbook reports syntax check passed.

- [ ] **Step 6: Run representative dry-runs**

```bash
./build.sh --dry-run --validate --validate-artifact --manifest --ci --ndb-version 2.9 --db-type pgsql --os "Rocky Linux" --os-version 9.6 --db-version 17

./build.sh --dry-run --validate --validate-artifact --manifest --ci --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18
```

Expected: both dry-runs complete without contacting Prism or Packer.

- [ ] **Step 7: Run one real smoke build when Prism credentials are available**

```bash
source .env
./build.sh --ci --validate --validate-artifact --manifest --source-image-name "Rocky-9-GenericCloud-LVM-9.7-20251123.2.x86_64.qcow2" --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18
```

Expected: Packer build succeeds, in-guest validation passes, artifact validation passes, disposable validation VM is removed, and `manifests/ndb-2.10-pgsql-18-Rocky Linux-9.7-TIMESTAMP.json` is written.

- [ ] **Step 8: Confirm cleanup**

Use Prism UI or `scripts/prism.sh` helper functions to confirm no VMs with names beginning `validate-` remain from the smoke build.

Expected: no disposable validation VMs remain.

- [ ] **Step 9: Commit verification fixes**

If verification required fixes:

```bash
git status --short
git add build.sh test.sh scripts/matrix_validate.sh scripts/prism.sh scripts/source_images.sh scripts/artifact_validate.sh scripts/manifest.sh scripts/release_scaffold.sh scripts/selftest.sh README.md .gitignore manifests/.gitkeep ansible/2.9/roles/validate_postgres/tasks/main.yml ansible/2.10/roles/validate_postgres/tasks/main.yml
git commit -m "Fix reliability workflow verification issues"
```

If no fixes were needed, do not create an empty commit.
