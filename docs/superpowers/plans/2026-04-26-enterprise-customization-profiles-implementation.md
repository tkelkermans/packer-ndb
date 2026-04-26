# Enterprise Customization Profiles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add optional enterprise customization profiles so users can install and validate internal tooling without editing core database roles.

**Architecture:** Keep `build.sh` as the public entry point and keep Packer as the VM builder. Use Ansible-native profile loading, validation, and phase dispatch so shell never parses YAML beyond resolving profile paths. Store committed examples under `customizations/examples` and keep customer-specific overlays under gitignored `customizations/local`.

**Tech Stack:** Bash, jq, Packer, Ansible 2.18, YAML, Markdown.

---

## Scope Check

This is one cohesive feature: optional enterprise profile selection and execution. It touches shell wiring, Ansible hook points, artifact validation, manifest reporting, examples, and README guidance. It does not add a plugin runtime, introduce Python, or make customization required for existing PostgreSQL or MongoDB builds.

## File Structure

- Create `customizations/profiles/enterprise-example.yml`: committed example profile.
- Create `customizations/profiles/enterprise-example.vars.yml`: safe example variables.
- Create `customizations/examples/internal-ca/roles/custom_internal_ca/tasks/main.yml`: installs a sample internal CA when enabled.
- Create `customizations/examples/monitoring-agent/roles/custom_monitoring_agent/tasks/main.yml`: installs a small OpenTelemetry Collector config/service example when enabled.
- Create `customizations/examples/os-hardening/roles/custom_os_hardening/tasks/main.yml`: applies one safe hardening example.
- Create `customizations/examples/enterprise-validation/roles/validate_custom_enterprise/tasks/main.yml`: validates the example customizations.
- Create README files under each `customizations/examples/*/README.md` and `customizations/local/README.md`.
- Modify `.gitignore`: ignore private local customization content while keeping the local README and `.gitkeep`.
- Modify `scripts/selftest.sh`: add profile structure, CLI, README, Ansible preflight, artifact dispatch, and manifest guards.
- Modify `build.sh`: add profile CLI/env selection, dry-run reporting, Ansible preflight, Ansible vars, Packer env vars, artifact-validation arguments, and manifest updates.
- Modify `scripts/artifact_validate.sh`: accept customization profile metadata and run custom validation roles during saved-artifact validation.
- Modify `scripts/manifest.sh`: initialize and update `customization` manifest fields.
- Modify `packer/variables.pkr.hcl` and `packer/database.pkr.hcl`: add `ansible_roles_path_env` so Packer can pass custom role paths to Ansible without editing `ansible.cfg`.
- Create `ansible/2.9/roles/customization_profile/defaults/main.yml` and `ansible/2.10/roles/customization_profile/defaults/main.yml`: common profile defaults.
- Create `ansible/2.9/roles/customization_profile/tasks/main.yml` and `ansible/2.10/roles/customization_profile/tasks/main.yml`: profile loading, contract assertions, and phase execution.
- Create `ansible/2.9/playbooks/customization_preflight.yml` and `ansible/2.10/playbooks/customization_preflight.yml`: local preflight playbooks.
- Modify `ansible/2.9/playbooks/site.yml` and `ansible/2.10/playbooks/site.yml`: call customization phases.
- Modify `README.md`: add "Customize The Image" and keep command examples aligned with behavior.
- Modify `tasks/todo.md`: track execution progress and final validation results.

## Task 1: Customization Skeleton, Examples, And README Guard

**Files:**
- Modify: `.gitignore`
- Modify: `scripts/selftest.sh`
- Create: `customizations/profiles/enterprise-example.yml`
- Create: `customizations/profiles/enterprise-example.vars.yml`
- Create: `customizations/examples/internal-ca/README.md`
- Create: `customizations/examples/monitoring-agent/README.md`
- Create: `customizations/examples/os-hardening/README.md`
- Create: `customizations/examples/enterprise-validation/README.md`
- Create: `customizations/local/.gitkeep`
- Create: `customizations/local/README.md`
- Modify: `README.md`
- Modify: `tasks/todo.md`

- [ ] **Step 1: Add the active task checklist**

Append this section to `tasks/todo.md`:

```markdown
# Active Plan: Enterprise Customization Profiles

- [ ] Add customization skeleton, committed examples, private overlay ignore rules, and README guidance.
- [ ] Add `build.sh` customization profile selection and dry-run reporting.
- [ ] Add Ansible profile preflight validation.
- [ ] Add build-time customization phase dispatch.
- [ ] Add saved-artifact customization validation dispatch.
- [ ] Add manifest reporting for selected customization profiles.
- [ ] Run offline verification and live PostgreSQL/MongoDB profile smoke builds.
```

- [ ] **Step 2: Add a failing self-test for customization skeleton and README guidance**

Add this function near the other static guard tests in `scripts/selftest.sh`, then call it immediately after definition:

```bash
run_customization_profile_static_tests() {
  [[ -f "$ROOT_DIR/customizations/profiles/enterprise-example.yml" ]] || fail "missing enterprise example profile"
  [[ -f "$ROOT_DIR/customizations/profiles/enterprise-example.vars.yml" ]] || fail "missing enterprise example vars"
  [[ -f "$ROOT_DIR/customizations/local/README.md" ]] || fail "missing local customization README"
  grep -q "customizations/local/" "$ROOT_DIR/.gitignore" || fail ".gitignore does not ignore local customizations"
  grep -q "custom_internal_ca" "$ROOT_DIR/customizations/profiles/enterprise-example.yml" || fail "profile missing internal CA role"
  grep -q "custom_monitoring_agent" "$ROOT_DIR/customizations/profiles/enterprise-example.yml" || fail "profile missing monitoring role"
  grep -q "custom_os_hardening" "$ROOT_DIR/customizations/profiles/enterprise-example.yml" || fail "profile missing hardening role"
  grep -q "validate_custom_enterprise" "$ROOT_DIR/customizations/profiles/enterprise-example.yml" || fail "profile missing custom validation role"
  grep -q "OpenTelemetry Collector" "$ROOT_DIR/customizations/examples/monitoring-agent/README.md" || fail "monitoring example does not document OpenTelemetry Collector"
  grep -q "Customize The Image" "$ROOT_DIR/README.md" || fail "README missing customization section"
  grep -q -- "--customization-profile" "$ROOT_DIR/README.md" || fail "README missing customization profile command"
  pass "customization profile static skeleton"
}

run_customization_profile_static_tests
```

- [ ] **Step 3: Run the self-test and confirm the intended failure**

Run:

```bash
bash scripts/selftest.sh
```

Expected: failure with `FAIL: missing enterprise example profile`.

- [ ] **Step 4: Add private overlay ignore rules**

Append this block to `.gitignore`:

```gitignore

# Private enterprise customization overlays
customizations/local/**
!customizations/local/
!customizations/local/.gitkeep
!customizations/local/README.md
```

- [ ] **Step 5: Create the example profile**

Create `customizations/profiles/enterprise-example.yml`:

```yaml
name: enterprise-example
description: Install a sample internal CA, OpenTelemetry Collector example, and safe hardening baseline.

vars_files:
  - customizations/profiles/enterprise-example.vars.yml

phases:
  pre_common:
    roles:
      - custom_internal_ca
  post_common:
    roles: []
  post_database:
    roles:
      - custom_monitoring_agent
      - custom_os_hardening
  validate:
    roles:
      - validate_custom_enterprise
```

- [ ] **Step 6: Create safe example variables**

Create `customizations/profiles/enterprise-example.vars.yml`:

```yaml
enterprise_internal_ca_enabled: true
enterprise_internal_ca_name: ndb-example-internal-ca
enterprise_internal_ca_path_redhat: /etc/pki/ca-trust/source/anchors/ndb-example-internal-ca.crt
enterprise_internal_ca_path_debian: /usr/local/share/ca-certificates/ndb-example-internal-ca.crt
enterprise_internal_ca_private_key_path: /etc/ndb-enterprise/ndb-example-internal-ca.key
enterprise_internal_ca_subject: /CN=NDB Example Internal CA

enterprise_monitoring_enabled: true
enterprise_otel_service_name: ndb-example-otelcol
enterprise_otel_config_path: /etc/ndb-enterprise/otelcol/config.yaml
enterprise_otel_marker_path: /etc/ndb-enterprise/otelcol/enabled

enterprise_hardening_enabled: true
enterprise_hardening_marker_path: /etc/ndb-enterprise/hardening/baseline.conf
enterprise_hardening_sysctl_key: vm.swappiness
enterprise_hardening_sysctl_value: "10"
```

- [ ] **Step 7: Create example READMEs**

Create `customizations/examples/monitoring-agent/README.md`:

```markdown
# Monitoring Agent Example

This example models an enterprise monitoring customization using OpenTelemetry Collector naming and configuration conventions.

The committed example is intentionally safe: it creates a small managed service and config marker that can be validated without tenant URLs, tokens, or private repositories. Replace the package/service tasks with your real OpenTelemetry Collector installation method when adapting this profile.
```

Create `customizations/examples/internal-ca/README.md`:

```markdown
# Internal CA Example

This example generates and installs a non-secret sample CA certificate into the OS trust store. Replace the generated sample with your enterprise CA distribution method.
```

Create `customizations/examples/os-hardening/README.md`:

```markdown
# OS Hardening Example

This example applies one safe sysctl-style hardening setting and writes a marker file so validation can prove the profile ran.
```

Create `customizations/examples/enterprise-validation/README.md`:

```markdown
# Enterprise Validation Example

This role validates the example CA, monitoring, and hardening customizations. Real enterprise profiles should validate every tool they install.
```

Create `customizations/local/README.md`:

```markdown
# Local Customizations

Put customer-specific profiles, private variables, and private roles here.

This directory is ignored by git except for this README and `.gitkeep`.
```

Create an empty `customizations/local/.gitkeep`.

- [ ] **Step 8: Update the README with the customization overview**

Add a section titled `## Customize The Image` before `## Validation` in `README.md`. Include this exact starter command:

```bash
./build.sh --dry-run --ci --customization-profile enterprise-example --ndb-version 2.10 --db-type mongodb --os "Rocky Linux" --os-version 9.7 --db-version 8.0
```

Mention:

- Profiles live in `customizations/profiles/` or `customizations/local/`.
- Use `customizations/local/` for customer-specific private content.
- The committed monitoring example uses OpenTelemetry Collector naming but avoids secrets.
- Production profiles should include validation roles.

- [ ] **Step 9: Verify and commit Task 1**

Run:

```bash
bash scripts/selftest.sh
git diff --check
```

Expected: both commands pass.

Commit only Task 1 files:

```bash
git add .gitignore README.md scripts/selftest.sh customizations tasks/todo.md
git commit -m "Add enterprise customization skeleton"
```

## Task 2: Build Script Profile Selection And Dry-Run Reporting

**Files:**
- Modify: `scripts/selftest.sh`
- Modify: `build.sh`
- Modify: `README.md`
- Modify: `tasks/todo.md`

- [ ] **Step 1: Add failing CLI self-tests**

Add this function to `scripts/selftest.sh` after `run_customization_profile_static_tests()`:

```bash
run_customization_profile_cli_tests() {
  grep -q -- "--customization-profile" "$ROOT_DIR/build.sh" || fail "build.sh missing customization profile flag"
  grep -q "NDB_CUSTOMIZATION_PROFILE" "$ROOT_DIR/build.sh" || fail "build.sh missing customization profile env default"
  grep -q "CUSTOMIZATION_PROFILE_FILE" "$ROOT_DIR/build.sh" || fail "build.sh missing customization profile resolver"
  grep -q "customization_profile_file" "$ROOT_DIR/build.sh" || fail "build.sh does not pass customization profile to Ansible"
  grep -q "Customization profile:" "$ROOT_DIR/build.sh" || fail "dry-run summary missing customization profile"
  pass "customization profile CLI guards"
}

run_customization_profile_cli_tests
```

- [ ] **Step 2: Run the self-test and confirm the intended failure**

Run:

```bash
bash scripts/selftest.sh
```

Expected: failure with `FAIL: build.sh missing customization profile flag`.

- [ ] **Step 3: Add build options and environment variables**

In `build.sh`, add to `usage()`:

```text
  --customization-profile NAME_OR_PATH
                            Apply an enterprise customization profile
  --no-customizations        Disable NDB_CUSTOMIZATION_PROFILE for this build
```

Add these variables near other mode variables:

```bash
CUSTOMIZATION_PROFILE_ARG=""
CUSTOMIZATION_PROFILE_FILE=""
CUSTOMIZATION_PROFILE_NAME=""
CUSTOMIZATION_ENABLED=false
CUSTOMIZATION_NO_CUSTOMIZATIONS=false
CUSTOMIZATION_ROLE_PATHS=()
CUSTOMIZATION_SUMMARY_FILE=""
```

Add parser cases:

```bash
    --customization-profile)
      CUSTOMIZATION_PROFILE_ARG="$2"
      shift
      ;;
    --no-customizations)
      CUSTOMIZATION_NO_CUSTOMIZATIONS=true
      ;;
```

- [ ] **Step 4: Add the profile resolver**

Add this function before `generate_ansible_vars_json()`:

```bash
function resolve_customization_profile() {
  local selection=""
  local candidate=""

  if [[ "$CUSTOMIZATION_NO_CUSTOMIZATIONS" == "true" ]]; then
    CUSTOMIZATION_ENABLED=false
    CUSTOMIZATION_PROFILE_FILE=""
    CUSTOMIZATION_PROFILE_NAME=""
    return 0
  fi

  if [[ -n "$CUSTOMIZATION_PROFILE_ARG" ]]; then
    selection="$CUSTOMIZATION_PROFILE_ARG"
  elif [[ -n "${NDB_CUSTOMIZATION_PROFILE:-}" ]]; then
    selection="$NDB_CUSTOMIZATION_PROFILE"
  else
    CUSTOMIZATION_ENABLED=false
    CUSTOMIZATION_PROFILE_FILE=""
    CUSTOMIZATION_PROFILE_NAME=""
    return 0
  fi

  if [[ -f "$selection" ]]; then
    candidate="$selection"
  elif [[ -f "customizations/profiles/${selection}.yml" ]]; then
    candidate="customizations/profiles/${selection}.yml"
  elif [[ -f "customizations/local/${selection}.yml" ]]; then
    candidate="customizations/local/${selection}.yml"
  elif [[ -f "customizations/local/${selection}" ]]; then
    candidate="customizations/local/${selection}"
  else
    echo "Error: customization profile not found: ${selection}" >&2
    echo "Looked for a direct path, customizations/profiles/${selection}.yml, and customizations/local/${selection}.yml." >&2
    exit 1
  fi

  CUSTOMIZATION_ENABLED=true
  CUSTOMIZATION_PROFILE_FILE="$candidate"
  CUSTOMIZATION_PROFILE_NAME="${selection%.yml}"
}
```

Call `resolve_customization_profile` after CLI parsing and before `generate_ansible_vars_json`.

- [ ] **Step 5: Pass profile values to Ansible vars**

Extend `generate_ansible_vars_json()` parameters with:

```bash
  local customization_enabled=$9
  local customization_profile_name=${10}
  local customization_profile_file=${11}
```

Add jq args:

```bash
    --arg customization_profile_name "$customization_profile_name" \
    --arg customization_profile_file "$customization_profile_file" \
    --argjson customization_enabled "$customization_enabled" \
```

Add JSON fields:

```jq
customization_enabled: $customization_enabled,
customization_profile_name: $customization_profile_name,
customization_profile_file: $customization_profile_file
```

Update the `ANSIBLE_VARS_JSON=$(generate_ansible_vars_json ...)` call to pass:

```bash
"$CUSTOMIZATION_ENABLED" \
"$CUSTOMIZATION_PROFILE_NAME" \
"$CUSTOMIZATION_PROFILE_FILE"
```

- [ ] **Step 6: Add dry-run reporting**

Add this block to `print_dry_run_summary()` after the source-image block:

```bash
Customization profile:
  Enabled: ${CUSTOMIZATION_ENABLED}
  Profile name: ${CUSTOMIZATION_PROFILE_NAME:-none}
  Profile file: ${CUSTOMIZATION_PROFILE_FILE:-none}
  Default from NDB_CUSTOMIZATION_PROFILE: $( [[ -n "${NDB_CUSTOMIZATION_PROFILE:-}" ]] && echo "yes" || echo "no" )
  Explicitly disabled: ${CUSTOMIZATION_NO_CUSTOMIZATIONS}
```

- [ ] **Step 7: Verify and commit Task 2**

Run:

```bash
bash scripts/selftest.sh
./build.sh --dry-run --ci --customization-profile enterprise-example --ndb-version 2.10 --db-type mongodb --os "Rocky Linux" --os-version 9.7 --db-version 8.0 | grep -A5 "Customization profile:"
git diff --check
```

Expected: self-tests pass, dry-run shows `Enabled: true`, and diff check passes.

Commit:

```bash
git add build.sh scripts/selftest.sh README.md tasks/todo.md
git commit -m "Add customization profile selection"
```

## Task 3: Ansible Profile Preflight

**Files:**
- Modify: `scripts/selftest.sh`
- Create: `ansible/2.9/roles/customization_profile/defaults/main.yml`
- Create: `ansible/2.9/roles/customization_profile/tasks/main.yml`
- Create: `ansible/2.10/roles/customization_profile/defaults/main.yml`
- Create: `ansible/2.10/roles/customization_profile/tasks/main.yml`
- Create: `ansible/2.9/playbooks/customization_preflight.yml`
- Create: `ansible/2.10/playbooks/customization_preflight.yml`
- Modify: `build.sh`
- Modify: `README.md`
- Modify: `tasks/todo.md`

- [ ] **Step 1: Add failing preflight self-tests**

Add this function to `scripts/selftest.sh`:

```bash
run_customization_profile_ansible_tests() {
  for version in 2.9 2.10; do
    [[ -f "$ROOT_DIR/ansible/$version/playbooks/customization_preflight.yml" ]] || fail "missing customization preflight playbook $version"
    [[ -f "$ROOT_DIR/ansible/$version/roles/customization_profile/tasks/main.yml" ]] || fail "missing customization_profile role $version"
    grep -q "include_vars" "$ROOT_DIR/ansible/$version/roles/customization_profile/tasks/main.yml" || fail "customization_profile $version does not load profile YAML"
    grep -q "customization_allowed_phases" "$ROOT_DIR/ansible/$version/roles/customization_profile/tasks/main.yml" || fail "customization_profile $version does not validate allowed phases"
    grep -q "include_role" "$ROOT_DIR/ansible/$version/roles/customization_profile/tasks/main.yml" || fail "customization_profile $version does not run phase roles"
  done
  grep -q "customization_preflight.yml" "$ROOT_DIR/build.sh" || fail "build.sh does not run customization preflight"
  pass "customization profile Ansible preflight guards"
}

run_customization_profile_ansible_tests
```

- [ ] **Step 2: Run the self-test and confirm the intended failure**

Run:

```bash
bash scripts/selftest.sh
```

Expected: failure with `FAIL: missing customization preflight playbook 2.9`.

- [ ] **Step 3: Create customization profile defaults for both NDB versions**

Create identical `ansible/2.9/roles/customization_profile/defaults/main.yml` and `ansible/2.10/roles/customization_profile/defaults/main.yml`:

```yaml
customization_enabled: false
customization_profile_file: ""
customization_profile_name: ""
customization_phase: preflight
customization_preflight_only: false
customization_allowed_phases:
  - pre_common
  - post_common
  - post_database
  - validate
```

- [ ] **Step 4: Create customization profile role tasks for both NDB versions**

Create identical `ansible/2.9/roles/customization_profile/tasks/main.yml` and `ansible/2.10/roles/customization_profile/tasks/main.yml`:

```yaml
- name: Skip customization profile when disabled
  ansible.builtin.meta: end_role
  when: not (customization_enabled | default(false) | bool)

- name: Assert customization profile file is provided
  ansible.builtin.assert:
    that:
      - customization_profile_file | length > 0
    fail_msg: "customization_profile_file is required when customization_enabled=true"

- name: Load customization profile
  ansible.builtin.include_vars:
    file: "{{ customization_profile_file }}"
    name: customization_profile

- name: Assert customization profile has required fields
  ansible.builtin.assert:
    that:
      - customization_profile.name is defined
      - customization_profile.name | length > 0
      - customization_profile.description is defined
      - customization_profile.description | length > 0
      - customization_profile.phases is defined
      - customization_profile.phases is mapping
    fail_msg: "Customization profile must define name, description, and phases mapping"

- name: Assert customization profile phases are supported
  ansible.builtin.assert:
    that:
      - customization_profile.phases.keys() | difference(customization_allowed_phases) | length == 0
    fail_msg: "Customization profile contains unsupported phase names"

- name: Assert customization profile phase roles are lists
  ansible.builtin.assert:
    that:
      - customization_profile.phases[item].roles is not defined or customization_profile.phases[item].roles is sequence
    fail_msg: "Customization profile phase roles must be lists"
  loop: "{{ customization_profile.phases.keys() | list }}"

- name: Assert customization vars files exist
  ansible.builtin.stat:
    path: "{{ item }}"
  register: customization_vars_file_stats
  loop: "{{ customization_profile.vars_files | default([]) }}"

- name: Fail when customization vars files are missing
  ansible.builtin.assert:
    that:
      - item.stat.exists
    fail_msg: "Customization vars file does not exist: {{ item.item }}"
  loop: "{{ customization_vars_file_stats.results | default([]) }}"

- name: Load customization vars files
  ansible.builtin.include_vars:
    file: "{{ item }}"
  loop: "{{ customization_profile.vars_files | default([]) }}"

- name: Assert explicit customization role paths exist
  ansible.builtin.stat:
    path: "{{ item }}"
  register: customization_role_path_stats
  loop: "{{ customization_profile.extra_role_paths | default([]) }}"

- name: Fail when explicit customization role paths are missing
  ansible.builtin.assert:
    that:
      - item.stat.exists
      - item.stat.isdir
    fail_msg: "Customization role path does not exist or is not a directory: {{ item.item }}"
  loop: "{{ customization_role_path_stats.results | default([]) }}"

- name: Write customization summary for shell manifest reporting
  ansible.builtin.copy:
    dest: "{{ customization_summary_file }}"
    mode: "0600"
    content: |
      {{
        {
          "enabled": true,
          "profile": customization_profile.name,
          "profile_file": customization_profile_file,
          "phases": {
            "pre_common": customization_profile.phases.get("pre_common", {}).get("roles", []),
            "post_common": customization_profile.phases.get("post_common", {}).get("roles", []),
            "post_database": customization_profile.phases.get("post_database", {}).get("roles", []),
            "validate": customization_profile.phases.get("validate", {}).get("roles", [])
          },
          "validation": "not-requested"
        } | to_nice_json
      }}
  delegate_to: localhost
  when:
    - customization_summary_file | default("") | length > 0
    - customization_preflight_only | default(false) | bool

- name: Stop after profile validation when running preflight only
  ansible.builtin.meta: end_role
  when: customization_preflight_only | default(false) | bool

- name: Resolve customization phase roles
  ansible.builtin.set_fact:
    customization_phase_roles: "{{ customization_profile.phases.get(customization_phase, {}).get('roles', []) }}"

- name: Run customization phase roles
  ansible.builtin.include_role:
    name: "{{ item }}"
  loop: "{{ customization_phase_roles }}"
```

- [ ] **Step 5: Create preflight playbooks for both NDB versions**

Create identical `ansible/2.9/playbooks/customization_preflight.yml` and `ansible/2.10/playbooks/customization_preflight.yml`:

```yaml
- name: Validate customization profile
  hosts: localhost
  connection: local
  gather_facts: false
  roles:
    - role: customization_profile
      vars:
        customization_preflight_only: true
```

- [ ] **Step 6: Run customization preflight from build.sh**

Add this function to `build.sh`:

```bash
function run_customization_preflight() {
  local preflight_playbook
  local roles_path

  if [[ "$CUSTOMIZATION_ENABLED" != "true" ]]; then
    return 0
  fi

  preflight_playbook="${SCRIPT_DIR}/ansible/${NDB_VERSION}/playbooks/customization_preflight.yml"
  roles_path="${SCRIPT_DIR}/ansible/${NDB_VERSION}/roles:${SCRIPT_DIR}/customizations/examples/internal-ca/roles:${SCRIPT_DIR}/customizations/examples/monitoring-agent/roles:${SCRIPT_DIR}/customizations/examples/os-hardening/roles:${SCRIPT_DIR}/customizations/examples/enterprise-validation/roles:${SCRIPT_DIR}/customizations/local"
  CUSTOMIZATION_SUMMARY_FILE=$(mktemp -t ndb-customization-summary.XXXXXX.json)
  TEMP_FILES+=("$CUSTOMIZATION_SUMMARY_FILE")

  ANSIBLE_ROLES_PATH="$roles_path" \
  ANSIBLE_CONFIG="${SCRIPT_DIR}/ansible/${NDB_VERSION}/ansible.cfg" \
  ansible-playbook \
    -i localhost, \
    -c local \
    -e "customization_enabled=true" \
    -e "customization_profile_file=${SCRIPT_DIR}/${CUSTOMIZATION_PROFILE_FILE}" \
    -e "customization_profile_name=${CUSTOMIZATION_PROFILE_NAME}" \
    -e "customization_summary_file=${CUSTOMIZATION_SUMMARY_FILE}" \
    "$preflight_playbook"
}
```

Call it after `ANSIBLE_SITE_PLAYBOOK` is set and before the dry-run/live branch exits:

```bash
run_customization_preflight
```

If this makes dry-run require `ansible-playbook` only when a customization profile is selected, add `ansible-playbook` to missing prerequisites in `print_dry_run_summary()` when `CUSTOMIZATION_ENABLED=true`.

- [ ] **Step 7: Verify and commit Task 3**

Run:

```bash
bash scripts/selftest.sh
PATH="/tmp/ndb-ansible-2.18/bin:$PATH" ./build.sh --dry-run --ci --customization-profile enterprise-example --ndb-version 2.10 --db-type mongodb --os "Rocky Linux" --os-version 9.7 --db-version 8.0
git diff --check
```

Expected: self-tests pass and dry-run preflight succeeds.

Commit:

```bash
git add build.sh scripts/selftest.sh ansible/2.9 ansible/2.10 README.md tasks/todo.md
git commit -m "Validate customization profiles before build"
```

## Task 4: Build-Time Customization Phase Dispatch

**Files:**
- Modify: `scripts/selftest.sh`
- Modify: `packer/variables.pkr.hcl`
- Modify: `packer/database.pkr.hcl`
- Modify: `build.sh`
- Modify: `ansible/2.9/playbooks/site.yml`
- Modify: `ansible/2.10/playbooks/site.yml`
- Create: `customizations/examples/internal-ca/roles/custom_internal_ca/tasks/main.yml`
- Create: `customizations/examples/monitoring-agent/roles/custom_monitoring_agent/tasks/main.yml`
- Create: `customizations/examples/os-hardening/roles/custom_os_hardening/tasks/main.yml`
- Modify: `README.md`
- Modify: `tasks/todo.md`

- [ ] **Step 1: Add failing build-time dispatch self-tests**

Add this function to `scripts/selftest.sh`:

```bash
run_customization_build_dispatch_tests() {
  grep -q "ansible_roles_path_env" "$ROOT_DIR/packer/variables.pkr.hcl" || fail "Packer variables missing ansible_roles_path_env"
  grep -q "ANSIBLE_ROLES_PATH" "$ROOT_DIR/packer/database.pkr.hcl" || fail "Packer does not pass ANSIBLE_ROLES_PATH"
  grep -q "customization_phase: pre_common" "$ROOT_DIR/ansible/2.10/playbooks/site.yml" || fail "site playbook missing pre_common customization phase"
  grep -q "customization_phase: post_database" "$ROOT_DIR/ansible/2.10/playbooks/site.yml" || fail "site playbook missing post_database customization phase"
  grep -q "custom_internal_ca" "$ROOT_DIR/customizations/examples/internal-ca/roles/custom_internal_ca/tasks/main.yml" || fail "missing internal CA role marker"
  grep -q "ndb-example-otelcol" "$ROOT_DIR/customizations/examples/monitoring-agent/roles/custom_monitoring_agent/tasks/main.yml" || fail "missing monitoring role marker"
  grep -q "vm.swappiness" "$ROOT_DIR/customizations/examples/os-hardening/roles/custom_os_hardening/tasks/main.yml" || fail "missing hardening role marker"
  pass "customization build dispatch guards"
}

run_customization_build_dispatch_tests
```

- [ ] **Step 2: Run the self-test and confirm the intended failure**

Run:

```bash
bash scripts/selftest.sh
```

Expected: failure with `FAIL: Packer variables missing ansible_roles_path_env`.

- [ ] **Step 3: Add Packer roles path variable**

Add to `packer/variables.pkr.hcl`:

```hcl
variable "ansible_roles_path_env" {
  type    = string
  default = ""
}
```

Modify `packer/database.pkr.hcl` `ansible_env_vars`:

```hcl
    ansible_env_vars = compact([
      var.ansible_config_path,
      var.ansible_roles_path_env,
      "ANSIBLE_HOST_KEY_CHECKING=False"
    ])
```

- [ ] **Step 4: Add roles path generation in build.sh**

Add this function:

```bash
function customization_roles_path_env() {
  if [[ "$CUSTOMIZATION_ENABLED" != "true" ]]; then
    printf ''
    return
  fi

  printf 'ANSIBLE_ROLES_PATH=%s:%s:%s:%s:%s:%s' \
    "${SCRIPT_DIR}/ansible/${NDB_VERSION}/roles" \
    "${SCRIPT_DIR}/customizations/examples/internal-ca/roles" \
    "${SCRIPT_DIR}/customizations/examples/monitoring-agent/roles" \
    "${SCRIPT_DIR}/customizations/examples/os-hardening/roles" \
    "${SCRIPT_DIR}/customizations/examples/enterprise-validation/roles" \
    "${SCRIPT_DIR}/customizations/local"
}
```

Set:

```bash
ANSIBLE_ROLES_PATH_ENV=$(customization_roles_path_env)
```

Pass to Packer:

```bash
  -var "ansible_roles_path_env=${ANSIBLE_ROLES_PATH_ENV}" \
```

Show in dry-run:

```text
  ansible_roles_path_env=${ANSIBLE_ROLES_PATH_ENV:-default ansible.cfg roles_path}
```

- [ ] **Step 5: Add phase dispatch to both site playbooks**

Update `ansible/2.9/playbooks/site.yml` and `ansible/2.10/playbooks/site.yml` to:

```yaml
- name: Configure Packer VM
  hosts: all
  pre_tasks:
    - name: Run pre-common customization roles
      ansible.builtin.include_role:
        name: customization_profile
      vars:
        customization_phase: pre_common
      when: customization_enabled | default(false) | bool
  roles:
    - common
    - role: customization_profile
      vars:
        customization_phase: post_common
      when: customization_enabled | default(false) | bool
    - role: postgres
      when: (provisioning_role | default('postgresql')) == 'postgresql'
    - role: validate_postgres
      when:
        - validate_build | default(false) | bool
        - (provisioning_role | default('postgresql')) == 'postgresql'
    - role: mongodb
      when: (provisioning_role | default('postgresql')) == 'mongodb'
    - role: validate_mongodb
      when:
        - validate_build | default(false) | bool
        - (provisioning_role | default('postgresql')) == 'mongodb'
    - role: customization_profile
      vars:
        customization_phase: post_database
      when: customization_enabled | default(false) | bool
    - role: customization_profile
      vars:
        customization_phase: validate
      when:
        - validate_build | default(false) | bool
        - customization_enabled | default(false) | bool
    - image_prepare
```

- [ ] **Step 6: Create install example roles**

Create `customizations/examples/internal-ca/roles/custom_internal_ca/tasks/main.yml`:

```yaml
- name: custom_internal_ca role marker
  ansible.builtin.debug:
    msg: "custom_internal_ca"

- name: Ensure enterprise marker directory exists
  ansible.builtin.file:
    path: /etc/ndb-enterprise
    state: directory
    owner: root
    group: root
    mode: "0755"

- name: Generate sample internal CA certificate on RedHat family
  ansible.builtin.command:
    argv:
      - openssl
      - req
      - -x509
      - -newkey
      - rsa:2048
      - -nodes
      - -sha256
      - -days
      - "3650"
      - -subj
      - "{{ enterprise_internal_ca_subject }}"
      - -keyout
      - "{{ enterprise_internal_ca_private_key_path }}"
      - -out
      - "{{ enterprise_internal_ca_path_redhat }}"
    creates: "{{ enterprise_internal_ca_path_redhat }}"
  when:
    - enterprise_internal_ca_enabled | default(false) | bool
    - ansible_os_family == "RedHat"

- name: Set RedHat sample CA certificate permissions
  ansible.builtin.file:
    path: "{{ enterprise_internal_ca_path_redhat }}"
    owner: root
    group: root
    mode: "0644"
  when:
    - enterprise_internal_ca_enabled | default(false) | bool
    - ansible_os_family == "RedHat"

- name: Generate sample internal CA certificate on Debian family
  ansible.builtin.command:
    argv:
      - openssl
      - req
      - -x509
      - -newkey
      - rsa:2048
      - -nodes
      - -sha256
      - -days
      - "3650"
      - -subj
      - "{{ enterprise_internal_ca_subject }}"
      - -keyout
      - "{{ enterprise_internal_ca_private_key_path }}"
      - -out
      - "{{ enterprise_internal_ca_path_debian }}"
    creates: "{{ enterprise_internal_ca_path_debian }}"
  when:
    - enterprise_internal_ca_enabled | default(false) | bool
    - ansible_os_family == "Debian"

- name: Set Debian sample CA certificate permissions
  ansible.builtin.file:
    path: "{{ enterprise_internal_ca_path_debian }}"
    owner: root
    group: root
    mode: "0644"
  when:
    - enterprise_internal_ca_enabled | default(false) | bool
    - ansible_os_family == "Debian"

- name: Update RedHat trust store
  ansible.builtin.command: update-ca-trust
  changed_when: true
  when:
    - enterprise_internal_ca_enabled | default(false) | bool
    - ansible_os_family == "RedHat"

- name: Update Debian trust store
  ansible.builtin.command: update-ca-certificates
  changed_when: true
  when:
    - enterprise_internal_ca_enabled | default(false) | bool
    - ansible_os_family == "Debian"
```

Create `customizations/examples/monitoring-agent/roles/custom_monitoring_agent/tasks/main.yml`:

```yaml
- name: custom_monitoring_agent role marker
  ansible.builtin.debug:
    msg: "ndb-example-otelcol"

- name: Ensure OpenTelemetry Collector example directory exists
  ansible.builtin.file:
    path: "{{ enterprise_otel_config_path | dirname }}"
    state: directory
    owner: root
    group: root
    mode: "0755"
  when: enterprise_monitoring_enabled | default(false) | bool

- name: Write OpenTelemetry Collector example config
  ansible.builtin.copy:
    dest: "{{ enterprise_otel_config_path }}"
    owner: root
    group: root
    mode: "0644"
    content: |
      receivers:
        otlp:
          protocols:
            grpc:
              endpoint: 127.0.0.1:4317
      exporters:
        debug:
          verbosity: basic
      service:
        pipelines:
          traces:
            receivers: [otlp]
            exporters: [debug]
  when: enterprise_monitoring_enabled | default(false) | bool

- name: Write OpenTelemetry Collector example marker
  ansible.builtin.copy:
    dest: "{{ enterprise_otel_marker_path }}"
    owner: root
    group: root
    mode: "0644"
    content: "OpenTelemetry Collector example enabled by NDB customization profile\n"
  when: enterprise_monitoring_enabled | default(false) | bool

- name: Install example OpenTelemetry Collector systemd unit
  ansible.builtin.copy:
    dest: "/etc/systemd/system/{{ enterprise_otel_service_name }}.service"
    owner: root
    group: root
    mode: "0644"
    content: |
      [Unit]
      Description=NDB example OpenTelemetry Collector service shim
      After=network-online.target

      [Service]
      Type=simple
      ExecStart=/usr/bin/env sh -c 'while true; do sleep 3600; done'
      Restart=always

      [Install]
      WantedBy=multi-user.target
  when: enterprise_monitoring_enabled | default(false) | bool

- name: Enable and start example monitoring service
  ansible.builtin.systemd:
    name: "{{ enterprise_otel_service_name }}"
    enabled: true
    state: started
    daemon_reload: true
  when: enterprise_monitoring_enabled | default(false) | bool
```

Create `customizations/examples/os-hardening/roles/custom_os_hardening/tasks/main.yml`:

```yaml
- name: custom_os_hardening role marker
  ansible.builtin.debug:
    msg: "vm.swappiness"

- name: Ensure hardening marker directory exists
  ansible.builtin.file:
    path: "{{ enterprise_hardening_marker_path | dirname }}"
    state: directory
    owner: root
    group: root
    mode: "0755"
  when: enterprise_hardening_enabled | default(false) | bool

- name: Persist safe hardening sysctl
  ansible.builtin.copy:
    dest: /etc/sysctl.d/99-ndb-enterprise-hardening.conf
    owner: root
    group: root
    mode: "0644"
    content: "{{ enterprise_hardening_sysctl_key }}={{ enterprise_hardening_sysctl_value }}\n"
  when: enterprise_hardening_enabled | default(false) | bool

- name: Apply safe hardening sysctl at runtime
  ansible.builtin.command:
    argv:
      - sysctl
      - "-w"
      - "{{ enterprise_hardening_sysctl_key }}={{ enterprise_hardening_sysctl_value }}"
  changed_when: true
  when: enterprise_hardening_enabled | default(false) | bool

- name: Write hardening marker file
  ansible.builtin.copy:
    dest: "{{ enterprise_hardening_marker_path }}"
    owner: root
    group: root
    mode: "0644"
    content: "{{ enterprise_hardening_sysctl_key }}={{ enterprise_hardening_sysctl_value }}\n"
  when: enterprise_hardening_enabled | default(false) | bool
```

- [ ] **Step 7: Verify and commit Task 4**

Run:

```bash
bash scripts/selftest.sh
PATH="/tmp/ndb-ansible-2.18/bin:$PATH" ANSIBLE_CONFIG=ansible/2.9/ansible.cfg ansible-playbook --syntax-check -i localhost, -c local ansible/2.9/playbooks/site.yml
PATH="/tmp/ndb-ansible-2.18/bin:$PATH" ANSIBLE_CONFIG=ansible/2.10/ansible.cfg ansible-playbook --syntax-check -i localhost, -c local ansible/2.10/playbooks/site.yml
packer fmt -check packer
git diff --check
```

Expected: all pass.

Commit:

```bash
git add build.sh packer ansible customizations README.md scripts/selftest.sh tasks/todo.md
git commit -m "Run customization profiles during image builds"
```

## Task 5: Saved-Artifact Custom Validation Dispatch

**Files:**
- Modify: `scripts/selftest.sh`
- Modify: `scripts/artifact_validate.sh`
- Create: `customizations/examples/enterprise-validation/roles/validate_custom_enterprise/tasks/main.yml`
- Modify: `build.sh`
- Modify: `README.md`
- Modify: `tasks/todo.md`

- [ ] **Step 1: Add failing artifact validation self-tests**

Extend `run_artifact_validate_tests()` in `scripts/selftest.sh` with a mock call that passes customization arguments and asserts the generated playbook includes `customization_profile` or `validate_custom_enterprise`. Add static guards:

```bash
  grep -q -- "--customization-profile-file" "$ROOT_DIR/scripts/artifact_validate.sh" || fail "artifact validation missing customization profile file flag"
  grep -q "validate_custom_enterprise" "$ROOT_DIR/customizations/examples/enterprise-validation/roles/validate_custom_enterprise/tasks/main.yml" || fail "missing enterprise validation role marker"
```

- [ ] **Step 2: Run the self-test and confirm the intended failure**

Run:

```bash
bash scripts/selftest.sh
```

Expected: failure with `FAIL: artifact validation missing customization profile file flag`.

- [ ] **Step 3: Add customization options to artifact_validate.sh**

Add variables:

```bash
CUSTOMIZATION_ENABLED=false
CUSTOMIZATION_PROFILE_NAME=""
CUSTOMIZATION_PROFILE_FILE=""
CUSTOMIZATION_ROLES_PATH_ENV=""
```

Add usage lines:

```text
  --customization-enabled
                         Run selected customization validation roles
  --customization-profile-name NAME
                         Customization profile name for validation context
  --customization-profile-file FILE
                         Customization profile file to load
  --customization-roles-path PATH
                         ANSIBLE_ROLES_PATH value for custom roles
```

Add parser cases for those flags.

- [ ] **Step 4: Pass customization vars into artifact validation vars JSON**

In `scripts/artifact_validate.sh`, include:

```bash
customization_enabled: $customization_enabled,
customization_profile_name: $customization_profile_name,
customization_profile_file: $customization_profile_file
```

Use jq args equivalent to existing PostgreSQL/MongoDB vars.

- [ ] **Step 5: Generate artifact validation playbook custom phase**

When writing the temporary validation playbook, append this role after database validation:

```yaml
    - role: customization_profile
      vars:
        customization_phase: validate
      when: customization_enabled | default(false) | bool
```

Run `ansible-playbook` with:

```bash
ANSIBLE_ROLES_PATH="$CUSTOMIZATION_ROLES_PATH_ENV"
```

only when the value is non-empty.

- [ ] **Step 6: Add the enterprise validation role**

Create `customizations/examples/enterprise-validation/roles/validate_custom_enterprise/tasks/main.yml`:

```yaml
- name: validate_custom_enterprise role marker
  ansible.builtin.debug:
    msg: "validate_custom_enterprise"

- name: Check RedHat sample CA certificate
  ansible.builtin.stat:
    path: "{{ enterprise_internal_ca_path_redhat }}"
  register: enterprise_ca_redhat_stat
  when:
    - enterprise_internal_ca_enabled | default(false) | bool
    - ansible_os_family == "RedHat"

- name: Check Debian sample CA certificate
  ansible.builtin.stat:
    path: "{{ enterprise_internal_ca_path_debian }}"
  register: enterprise_ca_debian_stat
  when:
    - enterprise_internal_ca_enabled | default(false) | bool
    - ansible_os_family == "Debian"

- name: Assert sample CA certificate exists
  ansible.builtin.assert:
    that:
      - (ansible_os_family == "RedHat" and enterprise_ca_redhat_stat.stat.exists) or
        (ansible_os_family == "Debian" and enterprise_ca_debian_stat.stat.exists)
    fail_msg: "Enterprise sample CA certificate was not installed"
  when: enterprise_internal_ca_enabled | default(false) | bool

- name: Check monitoring marker
  ansible.builtin.stat:
    path: "{{ enterprise_otel_marker_path }}"
  register: enterprise_otel_marker_stat
  when: enterprise_monitoring_enabled | default(false) | bool

- name: Assert monitoring marker exists
  ansible.builtin.assert:
    that:
      - enterprise_otel_marker_stat.stat.exists
    fail_msg: "OpenTelemetry Collector example marker is missing"
  when: enterprise_monitoring_enabled | default(false) | bool

- name: Check monitoring service is active
  ansible.builtin.command:
    argv:
      - systemctl
      - is-active
      - "{{ enterprise_otel_service_name }}.service"
  register: enterprise_otel_service_active
  changed_when: false
  when: enterprise_monitoring_enabled | default(false) | bool

- name: Assert monitoring service is active
  ansible.builtin.assert:
    that:
      - enterprise_otel_service_active.stdout == "active"
    fail_msg: "OpenTelemetry Collector example service is not active"
  when: enterprise_monitoring_enabled | default(false) | bool

- name: Read hardening marker
  ansible.builtin.slurp:
    path: "{{ enterprise_hardening_marker_path }}"
  register: enterprise_hardening_marker
  when: enterprise_hardening_enabled | default(false) | bool

- name: Assert hardening marker contains expected value
  ansible.builtin.assert:
    that:
      - (enterprise_hardening_marker.content | b64decode) is search(enterprise_hardening_sysctl_key ~ "=" ~ enterprise_hardening_sysctl_value)
    fail_msg: "Hardening marker does not contain expected sysctl value"
  when: enterprise_hardening_enabled | default(false) | bool
```

- [ ] **Step 7: Pass customization arguments from build.sh**

When building `ARTIFACT_VALIDATE_CMD`, append when `CUSTOMIZATION_ENABLED=true`:

```bash
ARTIFACT_VALIDATE_CMD+=(--customization-enabled)
ARTIFACT_VALIDATE_CMD+=(--customization-profile-name "$CUSTOMIZATION_PROFILE_NAME")
ARTIFACT_VALIDATE_CMD+=(--customization-profile-file "${SCRIPT_DIR}/${CUSTOMIZATION_PROFILE_FILE}")
ARTIFACT_VALIDATE_CMD+=(--customization-roles-path "$ANSIBLE_ROLES_PATH_ENV")
```

- [ ] **Step 8: Verify and commit Task 5**

Run:

```bash
bash scripts/selftest.sh
bash -n scripts/artifact_validate.sh build.sh
git diff --check
```

Expected: all pass.

Commit:

```bash
git add build.sh scripts/artifact_validate.sh scripts/selftest.sh customizations README.md tasks/todo.md
git commit -m "Validate customization profiles on saved artifacts"
```

## Task 6: Manifest Reporting

**Files:**
- Modify: `scripts/selftest.sh`
- Modify: `scripts/manifest.sh`
- Modify: `build.sh`
- Modify: `README.md`
- Modify: `tasks/todo.md`

- [ ] **Step 1: Add failing manifest self-tests**

In `run_manifest_tests()` in `scripts/selftest.sh`, add assertions that manifests include customization fields:

```bash
  "$ROOT_DIR/scripts/manifest.sh" set-json \
    --file "$manifest" \
    --key ".customization" \
    --json-value '{"enabled":true,"profile":"enterprise-example","profile_file":"customizations/profiles/enterprise-example.yml","phases":{"pre_common":["custom_internal_ca"],"post_common":[],"post_database":["custom_monitoring_agent","custom_os_hardening"],"validate":["validate_custom_enterprise"]},"validation":"not-requested"}'

  jq -e '.customization.enabled == true and .customization.profile == "enterprise-example" and (.customization.phases.validate | index("validate_custom_enterprise"))' "$manifest" >/dev/null || fail "manifest customization JSON"
```

Add static guard:

```bash
grep -q ".customization" "$ROOT_DIR/build.sh" || fail "build.sh does not record customization manifest fields"
```

- [ ] **Step 2: Run the self-test and confirm the intended failure**

Run:

```bash
bash scripts/selftest.sh
```

Expected: failure with `FAIL: build.sh does not record customization manifest fields`.

- [ ] **Step 3: Initialize customization manifest fields**

In `scripts/manifest.sh cmd_init`, add:

```jq
customization: {
  enabled: false,
  profile: null,
  profile_file: null,
  phases: {},
  validation: "not-requested"
}
```

- [ ] **Step 4: Add build.sh manifest writer helper**

Add this helper to `build.sh`:

```bash
function customization_manifest_json() {
  if [[ "$CUSTOMIZATION_ENABLED" != "true" ]]; then
    jq -nc '{enabled:false, profile:null, profile_file:null, phases:{}, validation:"not-requested"}'
    return
  fi

  jq -c '.' "$CUSTOMIZATION_SUMMARY_FILE"
}
```

- [ ] **Step 5: Set customization manifest fields**

After manifest initialization in `build.sh`, set:

```bash
CUSTOMIZATION_MANIFEST_JSON=$(customization_manifest_json)
"$MANIFEST_HELPER" set-json --file "$MANIFEST_FILE" --key ".customization" --json-value "$CUSTOMIZATION_MANIFEST_JSON"
```

When in-guest custom validation is requested, set:

```bash
"$MANIFEST_HELPER" set --file "$MANIFEST_FILE" --key ".customization.validation" --value "running"
```

After successful Packer build and requested validation, set:

```bash
"$MANIFEST_HELPER" set --file "$MANIFEST_FILE" --key ".customization.validation" --value "passed"
```

On failure, `on_exit()` should convert `running` to `failed`, matching existing in-guest validation behavior.

- [ ] **Step 6: Verify and commit Task 6**

Run:

```bash
bash scripts/selftest.sh
bash -n build.sh scripts/manifest.sh
git diff --check
```

Expected: all pass.

Commit:

```bash
git add build.sh scripts/manifest.sh scripts/selftest.sh README.md tasks/todo.md
git commit -m "Record customization profiles in manifests"
```

## Task 7: Final Documentation, Offline Verification, And Live Smoke

**Files:**
- Modify: `README.md`
- Modify: `scripts/selftest.sh`
- Modify: `tasks/todo.md`

- [ ] **Step 1: Add final README self-test guards**

Extend `run_readme_mongodb_tests()` or add a new README guard:

```bash
run_readme_customization_tests() {
  grep -q "Customize The Image" "$ROOT_DIR/README.md" || fail "README missing Customize The Image"
  grep -q "Install an internal CA certificate" "$ROOT_DIR/README.md" || fail "README missing internal CA recipe"
  grep -q "OpenTelemetry Collector" "$ROOT_DIR/README.md" || fail "README missing OpenTelemetry explanation"
  grep -q "customizations/local" "$ROOT_DIR/README.md" || fail "README missing private overlay explanation"
  grep -q "validate_custom_enterprise" "$ROOT_DIR/README.md" || fail "README missing custom validation role guidance"
  pass "README customization guidance"
}

run_readme_customization_tests
```

- [ ] **Step 2: Expand README recipes**

In `README.md`, make sure the customization section includes:

- Dry-run command with `--customization-profile enterprise-example`.
- Production command with `--validate --validate-artifact --manifest`.
- A short internal CA recipe.
- A short OpenTelemetry Collector monitoring recipe.
- A short hardening recipe.
- A warning that real enterprise tokens, tenant URLs, and secrets belong outside git.
- A note that `customizations/local/` is ignored by git.

- [ ] **Step 3: Run complete offline verification**

Run:

```bash
bash -n build.sh test.sh scripts/*.sh ansible/2.9/roles/validate_mongodb/files/*.sh ansible/2.10/roles/validate_mongodb/files/*.sh
bash scripts/selftest.sh
scripts/matrix_validate.sh ndb/*/matrix.json
PATH="/tmp/ndb-ansible-2.18/bin:$PATH" ANSIBLE_CONFIG=ansible/2.9/ansible.cfg ansible-playbook --syntax-check -i localhost, -c local ansible/2.9/playbooks/site.yml
PATH="/tmp/ndb-ansible-2.18/bin:$PATH" ANSIBLE_CONFIG=ansible/2.10/ansible.cfg ansible-playbook --syntax-check -i localhost, -c local ansible/2.10/playbooks/site.yml
PATH="/tmp/ndb-ansible-2.18/bin:$PATH" ANSIBLE_CONFIG=ansible/2.9/ansible.cfg ansible-playbook --syntax-check -i localhost, -c local ansible/2.9/playbooks/customization_preflight.yml
PATH="/tmp/ndb-ansible-2.18/bin:$PATH" ANSIBLE_CONFIG=ansible/2.10/ansible.cfg ansible-playbook --syntax-check -i localhost, -c local ansible/2.10/playbooks/customization_preflight.yml
packer fmt -check packer
git diff --check
```

Expected: all pass.

- [ ] **Step 4: Run representative dry-runs**

Run:

```bash
./build.sh --dry-run --ci --customization-profile enterprise-example --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18
./build.sh --dry-run --ci --customization-profile enterprise-example --ndb-version 2.10 --db-type mongodb --os "Rocky Linux" --os-version 9.7 --db-version 8.0
```

Expected: both show customization enabled, the profile file, and no malformed profile errors.

- [ ] **Step 5: Run live smoke builds when Prism credentials are available**

Run PostgreSQL smoke:

```bash
PATH="/tmp/ndb-ansible-2.18/bin:$PATH" op run --env-file /Users/tristan/Developer/NDB/.env -- ./build.sh --ci --customization-profile enterprise-example --source-image-uuid 7a6d6c2f-90b4-4acb-bf14-6f2be1bf006e --validate --validate-artifact --manifest --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18
```

Run MongoDB smoke:

```bash
PATH="/tmp/ndb-ansible-2.18/bin:$PATH" op run --env-file /Users/tristan/Developer/NDB/.env -- ./build.sh --ci --customization-profile enterprise-example --source-image-uuid 7a6d6c2f-90b4-4acb-bf14-6f2be1bf006e --validate --validate-artifact --manifest --ndb-version 2.10 --db-type mongodb --os "Rocky Linux" --os-version 9.7 --db-version 8.0
```

Expected: both build-time validation and artifact validation pass. If the source image UUID differs in the target Prism environment, first run preflight or replace the UUID with a valid staged image UUID.

- [ ] **Step 6: Confirm Prism cleanup**

Run:

```bash
op run --env-file /Users/tristan/Developer/NDB/.env -- bash -lc '
set -euo pipefail
source scripts/prism.sh
prism_list_resource vms vm 2000 | jq -r '\''
  .entities[]?
  | (.spec.name // .status.name // "") as $name
  | select(($name | startswith("ndb-")) or ($name | startswith("validate-ndb-")))
  | [$name, .metadata.uuid, (.status.resources.power_state // "unknown")] | @tsv
'\'''
'
```

Expected: no builder or validation VMs from the smoke runs remain. If any remain, clean them up through Prism or `prism_delete_vm` after inspection.

- [ ] **Step 7: Document final results and commit**

Update `tasks/todo.md` with:

```markdown
# Active Plan Review: Enterprise Customization Profiles

- Added optional enterprise customization profiles with committed examples and ignored private overlays.
- Added Ansible-native profile preflight and build-time phase dispatch.
- Added saved-artifact custom validation dispatch.
- Added manifest reporting for selected customization profiles.
- Offline verification passed.
- Live PostgreSQL and MongoDB profile smoke results are recorded above with exact image names, manifest names, validation status, and any Prism or credential blockers.
```

Commit:

```bash
git add README.md scripts/selftest.sh tasks/todo.md
git commit -m "Document enterprise customization profiles"
```
