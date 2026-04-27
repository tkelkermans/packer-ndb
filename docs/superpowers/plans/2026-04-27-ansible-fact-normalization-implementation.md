# Ansible Fact Normalization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove repository-owned Ansible `INJECT_FACTS_AS_VARS` deprecation warnings by replacing top-level `ansible_*` fact usage with readable `ndb_*` variables backed by `ansible_facts[...]`.

**Architecture:** Each role that uses OS facts defines the normalized `ndb_*` values it needs locally, near the start of its task file. Roles remain independent so artifact validation, customization preflight, and normal Packer builds do not rely on another role setting facts first.

**Tech Stack:** Ansible YAML, shell selftests, `rg`, `jq`, Packer dry-runs, optional live Prism validation.

---

## File Map

- Modify `scripts/selftest.sh`: add a static guard that fails while committed Ansible/customization YAML still uses deprecated top-level fact names.
- Modify `ansible/2.9/roles/common/tasks/main.yml` and `ansible/2.10/roles/common/tasks/main.yml`: normalize common role OS facts and update conditions/service-name expressions.
- Modify `ansible/2.9/roles/image_prepare/tasks/main.yml` and `ansible/2.10/roles/image_prepare/tasks/main.yml`: normalize `ndb_os_family` for final image preparation.
- Modify `ansible/2.9/roles/postgres/tasks/main.yml`, `ansible/2.10/roles/postgres/tasks/main.yml`, and both PostgreSQL handler files: normalize PostgreSQL repository, package, service, and extension metadata fact usage.
- Modify `ansible/2.9/roles/mongodb/tasks/main.yml` and `ansible/2.10/roles/mongodb/tasks/main.yml`: normalize MongoDB repository and package fact usage.
- Modify `ansible/2.9/roles/validate_postgres/tasks/main.yml`, `ansible/2.10/roles/validate_postgres/tasks/main.yml`, `ansible/2.9/roles/validate_mongodb/tasks/main.yml`, and `ansible/2.10/roles/validate_mongodb/tasks/main.yml`: normalize validation role service and extension metadata usage.
- Modify committed customization example roles under `customizations/examples`: normalize OS family checks in example install and validation roles.
- Modify `tasks/todo.md`: track execution and record verification results.
- Do not modify `README.md` unless implementation changes operator-facing commands or behavior. This cleanup should not.

---

## Task 1: Add Static Guard For Deprecated Facts

**Files:**
- Modify: `scripts/selftest.sh`
- Modify: `tasks/todo.md`

- [ ] **Step 1: Add execution tracker**

Add this block near the top of `tasks/todo.md`:

```markdown
# Active Plan: Ansible Fact Normalization Cleanup

- [ ] Add static selftest guard for deprecated top-level Ansible facts.
- [ ] Normalize core common and image preparation roles.
- [ ] Normalize PostgreSQL roles and handlers.
- [ ] Normalize MongoDB roles.
- [ ] Normalize validation roles.
- [ ] Normalize committed customization examples.
- [ ] Run offline verification and representative dry-runs.
- [ ] Run representative live PostgreSQL validation if environment is available.
- [ ] Record final review.
```

- [ ] **Step 2: Write the failing selftest**

Add this function near the other static guard tests in `scripts/selftest.sh`, before `run_agent_guidance_tests`:

```bash
run_ansible_fact_normalization_guard_tests() {
  local deprecated_pattern deprecated_refs
  deprecated_pattern='ansible_(os_family|distribution|distribution_version|distribution_major_version|distribution_release)'
  deprecated_refs=$(
    find "$ROOT_DIR/ansible" "$ROOT_DIR/customizations/examples" -name '*.yml' -print0 \
      | xargs -0 rg -n "$deprecated_pattern" || true
  )

  if [[ -n "$deprecated_refs" ]]; then
    printf '%s\n' "$deprecated_refs" >&2
    fail "committed Ansible YAML still uses deprecated top-level ansible_* facts"
  fi

  pass "Ansible fact normalization guard"
}

run_ansible_fact_normalization_guard_tests
```

- [ ] **Step 3: Verify the test fails for the right reason**

Run:

```bash
bash scripts/selftest.sh
```

Expected: failure with `FAIL: committed Ansible YAML still uses deprecated top-level ansible_* facts`, and output lines pointing at existing `ansible_os_family`, `ansible_distribution_major_version`, or related references.

- [ ] **Step 4: Confirm no implementation files changed yet**

Run:

```bash
git diff -- scripts/selftest.sh tasks/todo.md
git status --short
```

Expected: only `scripts/selftest.sh` and `tasks/todo.md` changed in this task.

---

## Task 2: Normalize Common And Image Preparation Roles

**Files:**
- Modify: `ansible/2.9/roles/common/tasks/main.yml`
- Modify: `ansible/2.10/roles/common/tasks/main.yml`
- Modify: `ansible/2.9/roles/image_prepare/tasks/main.yml`
- Modify: `ansible/2.10/roles/image_prepare/tasks/main.yml`
- Modify: `tasks/todo.md`

- [ ] **Step 1: Add normalized facts to `common` roles**

At the top of both `ansible/2.9/roles/common/tasks/main.yml` and `ansible/2.10/roles/common/tasks/main.yml`, add:

```yaml
- name: Normalize OS facts
  ansible.builtin.set_fact:
    ndb_os_family: "{{ ansible_facts['os_family'] }}"
    ndb_distribution: "{{ ansible_facts['distribution'] }}"
    ndb_distribution_version: "{{ ansible_facts['distribution_version'] }}"
```

- [ ] **Step 2: Replace common role fact references**

In both common role files, replace:

```yaml
ansible_os_family
```

with:

```yaml
ndb_os_family
```

In both common role files, replace:

```yaml
ansible_distribution
```

with:

```yaml
ndb_distribution
```

In `ansible/2.10/roles/common/tasks/main.yml`, replace:

```yaml
ansible_distribution_version
```

with:

```yaml
ndb_distribution_version
```

- [ ] **Step 3: Add normalized facts to `image_prepare` roles**

At the top of both `ansible/2.9/roles/image_prepare/tasks/main.yml` and `ansible/2.10/roles/image_prepare/tasks/main.yml`, add:

```yaml
- name: Normalize OS facts
  ansible.builtin.set_fact:
    ndb_os_family: "{{ ansible_facts['os_family'] }}"
```

- [ ] **Step 4: Replace image preparation fact references**

In both image preparation files, replace:

```yaml
ansible_os_family
```

with:

```yaml
ndb_os_family
```

- [ ] **Step 5: Run focused checks**

Run:

```bash
rg -n "ansible_(os_family|distribution|distribution_version|distribution_major_version|distribution_release)" \
  ansible/2.9/roles/common/tasks/main.yml \
  ansible/2.10/roles/common/tasks/main.yml \
  ansible/2.9/roles/image_prepare/tasks/main.yml \
  ansible/2.10/roles/image_prepare/tasks/main.yml
```

Expected: no output.

- [ ] **Step 6: Mark tracker items**

Mark `Normalize core common and image preparation roles` complete in `tasks/todo.md`.

---

## Task 3: Normalize PostgreSQL Roles And Handlers

**Files:**
- Modify: `ansible/2.9/roles/postgres/tasks/main.yml`
- Modify: `ansible/2.10/roles/postgres/tasks/main.yml`
- Modify: `ansible/2.9/roles/postgres/handlers/main.yml`
- Modify: `ansible/2.10/roles/postgres/handlers/main.yml`
- Modify: `tasks/todo.md`

- [ ] **Step 1: Add normalized facts to PostgreSQL task files**

At the top of both PostgreSQL task files, add:

```yaml
- name: Normalize OS facts
  ansible.builtin.set_fact:
    ndb_os_family: "{{ ansible_facts['os_family'] }}"
    ndb_distribution_major_version: "{{ ansible_facts['distribution_major_version'] }}"
    ndb_distribution_release: "{{ ansible_facts['distribution_release'] }}"
```

- [ ] **Step 2: Replace PostgreSQL task fact references**

In both PostgreSQL task files, replace:

```yaml
ansible_os_family
```

with:

```yaml
ndb_os_family
```

Replace:

```yaml
ansible_distribution_major_version
```

with:

```yaml
ndb_distribution_major_version
```

Replace:

```yaml
ansible_distribution_release
```

with:

```yaml
ndb_distribution_release
```

- [ ] **Step 3: Derive the PostgreSQL service name in normal tasks**

After the `Normalize OS facts` task in both PostgreSQL task files, add:

```yaml
- name: Derive PostgreSQL service name
  ansible.builtin.set_fact:
    postgres_service_name: "{{ 'postgresql-' ~ postgres_version_map[db_version] if ndb_os_family == 'RedHat' else 'postgresql' }}"
```

Then update both PostgreSQL task files and both PostgreSQL handler files to use:

```yaml
name: "{{ postgres_service_name }}"
```

instead of:

```yaml
name: "{{ 'postgresql-' + postgres_version_map[db_version] if ansible_os_family == 'RedHat' else 'postgresql' }}"
```

Handlers run after normal role tasks, so they can consume `postgres_service_name` without adding a handler-local `set_fact` that would need to be notified separately.

- [ ] **Step 4: Run focused checks**

Run:

```bash
rg -n "ansible_(os_family|distribution|distribution_version|distribution_major_version|distribution_release)" \
  ansible/2.9/roles/postgres/tasks/main.yml \
  ansible/2.10/roles/postgres/tasks/main.yml \
  ansible/2.9/roles/postgres/handlers/main.yml \
  ansible/2.10/roles/postgres/handlers/main.yml
```

Expected: no output.

- [ ] **Step 5: Run PostgreSQL syntax checks**

Run:

```bash
ANSIBLE_CONFIG=ansible/2.9/ansible.cfg ansible-playbook -i localhost, -c local ansible/2.9/playbooks/site.yml --syntax-check
ANSIBLE_CONFIG=ansible/2.10/ansible.cfg ansible-playbook -i localhost, -c local ansible/2.10/playbooks/site.yml --syntax-check
```

Expected: both syntax checks pass.

- [ ] **Step 6: Mark tracker item**

Mark `Normalize PostgreSQL roles and handlers` complete in `tasks/todo.md`.

---

## Task 4: Normalize MongoDB Roles

**Files:**
- Modify: `ansible/2.9/roles/mongodb/tasks/main.yml`
- Modify: `ansible/2.10/roles/mongodb/tasks/main.yml`
- Modify: `tasks/todo.md`

- [ ] **Step 1: Add normalized facts**

At the top of both MongoDB task files, add:

```yaml
- name: Normalize OS facts
  ansible.builtin.set_fact:
    ndb_os_family: "{{ ansible_facts['os_family'] }}"
    ndb_distribution_major_version: "{{ ansible_facts['distribution_major_version'] }}"
    ndb_distribution_release: "{{ ansible_facts['distribution_release'] }}"
```

- [ ] **Step 2: Replace MongoDB fact references**

In both MongoDB task files, replace:

```yaml
ansible_os_family
```

with:

```yaml
ndb_os_family
```

Replace:

```yaml
ansible_distribution_major_version
```

with:

```yaml
ndb_distribution_major_version
```

Replace:

```yaml
ansible_distribution_release
```

with:

```yaml
ndb_distribution_release
```

- [ ] **Step 3: Run focused checks**

Run:

```bash
rg -n "ansible_(os_family|distribution|distribution_version|distribution_major_version|distribution_release)" \
  ansible/2.9/roles/mongodb/tasks/main.yml \
  ansible/2.10/roles/mongodb/tasks/main.yml
```

Expected: no output.

- [ ] **Step 4: Run MongoDB dry-runs**

Run:

```bash
./build.sh --ci --dry-run --ndb-version 2.9 --db-type mongodb --os "Rocky Linux" --os-version 9.6 --db-version 8.0 --source-image-name test-image
./build.sh --ci --dry-run --ndb-version 2.10 --db-type mongodb --os "Rocky Linux" --os-version 9.7 --db-version 8.0 --source-image-name test-image
```

Expected: both dry-runs exit 0 and still show `provisioning_role: mongodb`, `mongodb_edition`, and `mongodb_deployments` in generated Ansible vars.

- [ ] **Step 5: Mark tracker item**

Mark `Normalize MongoDB roles` complete in `tasks/todo.md`.

---

## Task 5: Normalize Validation Roles

**Files:**
- Modify: `ansible/2.9/roles/validate_postgres/tasks/main.yml`
- Modify: `ansible/2.10/roles/validate_postgres/tasks/main.yml`
- Modify: `ansible/2.9/roles/validate_mongodb/tasks/main.yml`
- Modify: `ansible/2.10/roles/validate_mongodb/tasks/main.yml`
- Modify: `tasks/todo.md`

- [ ] **Step 1: Add normalized facts to PostgreSQL validation roles**

At the top of both `validate_postgres` task files, before the existing `Derive PostgreSQL validation facts` task, add:

```yaml
- name: Normalize OS facts
  ansible.builtin.set_fact:
    ndb_os_family: "{{ ansible_facts['os_family'] }}"
```

- [ ] **Step 2: Replace PostgreSQL validation fact references**

In both `validate_postgres` task files, replace:

```yaml
ansible_os_family
```

with:

```yaml
ndb_os_family
```

- [ ] **Step 3: Add normalized facts to MongoDB validation roles**

At the top of both `validate_mongodb` task files, add:

```yaml
- name: Normalize OS facts
  ansible.builtin.set_fact:
    ndb_os_family: "{{ ansible_facts['os_family'] }}"
```

- [ ] **Step 4: Replace MongoDB validation fact references**

In both `validate_mongodb` task files, replace:

```yaml
ansible_os_family
```

with:

```yaml
ndb_os_family
```

- [ ] **Step 5: Run focused checks**

Run:

```bash
rg -n "ansible_(os_family|distribution|distribution_version|distribution_major_version|distribution_release)" \
  ansible/2.9/roles/validate_postgres/tasks/main.yml \
  ansible/2.10/roles/validate_postgres/tasks/main.yml \
  ansible/2.9/roles/validate_mongodb/tasks/main.yml \
  ansible/2.10/roles/validate_mongodb/tasks/main.yml
```

Expected: no output.

- [ ] **Step 6: Run artifact validation helper syntax check**

Run:

```bash
bash -n scripts/artifact_validate.sh
```

Expected: exit 0.

- [ ] **Step 7: Mark tracker item**

Mark `Normalize validation roles` complete in `tasks/todo.md`.

---

## Task 6: Normalize Customization Examples

**Files:**
- Modify: `customizations/examples/internal-ca/roles/custom_internal_ca/tasks/main.yml`
- Modify: `customizations/examples/enterprise-validation/roles/validate_custom_enterprise/tasks/main.yml`
- Modify: `tasks/todo.md`

- [ ] **Step 1: Add normalized facts to internal CA example**

At the top of `customizations/examples/internal-ca/roles/custom_internal_ca/tasks/main.yml`, add:

```yaml
- name: Normalize OS facts
  ansible.builtin.set_fact:
    ndb_os_family: "{{ ansible_facts['os_family'] }}"
```

- [ ] **Step 2: Replace internal CA fact references**

In that file, replace:

```yaml
ansible_os_family
```

with:

```yaml
ndb_os_family
```

- [ ] **Step 3: Add normalized facts to enterprise validation example**

At the top of `customizations/examples/enterprise-validation/roles/validate_custom_enterprise/tasks/main.yml`, add:

```yaml
- name: Normalize OS facts
  ansible.builtin.set_fact:
    ndb_os_family: "{{ ansible_facts['os_family'] }}"
```

- [ ] **Step 4: Replace enterprise validation fact references**

In that file, replace:

```yaml
ansible_os_family
```

with:

```yaml
ndb_os_family
```

- [ ] **Step 5: Run focused checks**

Run:

```bash
rg -n "ansible_(os_family|distribution|distribution_version|distribution_major_version|distribution_release)" customizations/examples
```

Expected: no output.

- [ ] **Step 6: Run customization preflight syntax checks**

Run:

```bash
ANSIBLE_CONFIG=ansible/2.9/ansible.cfg ansible-playbook -i localhost, -c local ansible/2.9/playbooks/customization_preflight.yml --syntax-check
ANSIBLE_CONFIG=ansible/2.10/ansible.cfg ansible-playbook -i localhost, -c local ansible/2.10/playbooks/customization_preflight.yml --syntax-check
```

Expected: both syntax checks pass.

- [ ] **Step 7: Mark tracker item**

Mark `Normalize committed customization examples` complete in `tasks/todo.md`.

---

## Task 7: Full Offline Verification And Dry-Runs

**Files:**
- Modify: `tasks/todo.md`

- [ ] **Step 1: Confirm no deprecated references remain**

Run:

```bash
find ansible customizations/examples -name '*.yml' -print0 \
  | xargs -0 rg -n "ansible_(os_family|distribution|distribution_version|distribution_major_version|distribution_release)"
```

Expected: no output.

- [ ] **Step 2: Run full local checks**

Run:

```bash
bash -n build.sh test.sh scripts/*.sh
bash scripts/selftest.sh
bash scripts/matrix_validate.sh ndb/2.9/matrix.json ndb/2.10/matrix.json
packer fmt -check packer
git diff --check
```

Expected: all commands exit 0.

- [ ] **Step 3: Run Ansible syntax checks**

Run:

```bash
ANSIBLE_CONFIG=ansible/2.9/ansible.cfg ansible-playbook -i localhost, -c local ansible/2.9/playbooks/site.yml --syntax-check
ANSIBLE_CONFIG=ansible/2.10/ansible.cfg ansible-playbook -i localhost, -c local ansible/2.10/playbooks/site.yml --syntax-check
ANSIBLE_CONFIG=ansible/2.9/ansible.cfg ansible-playbook -i localhost, -c local ansible/2.9/playbooks/customization_preflight.yml --syntax-check
ANSIBLE_CONFIG=ansible/2.10/ansible.cfg ansible-playbook -i localhost, -c local ansible/2.10/playbooks/customization_preflight.yml --syntax-check
```

Expected: all syntax checks pass.

- [ ] **Step 4: Run representative dry-runs**

Run:

```bash
./build.sh --ci --dry-run --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18 --extensions pg_stat_statements --source-image-name test-image
./build.sh --ci --dry-run --ndb-version 2.10 --db-type mongodb --os "Rocky Linux" --os-version 9.7 --db-version 8.0 --source-image-name test-image
./build.sh --ci --dry-run --customization-profile enterprise-example --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18 --source-image-name test-image
```

Expected: all dry-runs exit 0 and preserve the selected matrix row, extension selection, MongoDB metadata, and customization profile summary.

- [ ] **Step 5: Update tracker**

Mark `Run offline verification and representative dry-runs` complete in `tasks/todo.md`, and add a short review section with exact commands that passed.

---

## Task 8: Optional Representative Live Validation

**Files:**
- Modify: `tasks/todo.md`

- [ ] **Step 1: Check live environment readiness without printing secrets**

Run:

```bash
op run --env-file .env -- bash -c 'for key in PKR_VAR_pc_username PKR_VAR_pc_password PKR_VAR_pc_ip PKR_VAR_cluster_name PKR_VAR_subnet_name; do if [ -n "${!key:-}" ]; then printf "%s=present\n" "$key"; else printf "%s=missing\n" "$key"; fi; done'
```

Expected: all required Prism variables print `present`.

- [ ] **Step 2: Run live preflight**

Run:

```bash
op run --env-file .env -- ./build.sh --ci --preflight \
  --ndb-version 2.10 \
  --db-type pgsql \
  --os "Rocky Linux" \
  --os-version 9.7 \
  --db-version 18 \
  --source-image-uuid 7a6d6c2f-90b4-4acb-bf14-6f2be1bf006e \
  --extensions pg_stat_statements
```

Expected: preflight exits 0 and reports `Ready for live build: yes`.

- [ ] **Step 3: Run live build with validations**

Run:

```bash
op run --env-file .env -- ./build.sh --ci \
  --validate \
  --validate-artifact \
  --manifest \
  --ndb-version 2.10 \
  --db-type pgsql \
  --os "Rocky Linux" \
  --os-version 9.7 \
  --db-version 18 \
  --source-image-uuid 7a6d6c2f-90b4-4acb-bf14-6f2be1bf006e \
  --extensions pg_stat_statements
```

Expected: build exits 0, in-guest validation passes, artifact validation passes, validation VM cleanup is `deleted`, and repository-owned role output no longer emits `INJECT_FACTS_AS_VARS` deprecation warnings.

- [ ] **Step 4: Verify manifest**

Run:

```bash
latest_manifest=$(ls -t manifests/*.json | head -n 1)
printf 'Inspecting manifest: %s\n' "$latest_manifest"
jq '{status, image_name, artifact, validation, cleanup, extensions, source_image, packer}' "$latest_manifest"
```

Expected:

```json
{
  "status": "success",
  "validation": {
    "in_guest": "passed",
    "artifact": "passed"
  },
  "cleanup": {
    "artifact_validation_vm": "deleted"
  },
  "extensions": {
    "selected": ["pg_stat_statements"]
  }
}
```

- [ ] **Step 5: Update tracker**

If live validation runs, mark `Run representative live PostgreSQL validation if environment is available` complete and record the saved image name, image UUID, manifest path, validation statuses, and cleanup result in `tasks/todo.md`.

If live validation is skipped, leave the item unchecked and record the reason in `tasks/todo.md`.

---

## Task 9: Final Review And Commit

**Files:**
- Modify: `tasks/todo.md`

- [ ] **Step 1: Review final diff**

Run:

```bash
git diff --stat
git diff -- ansible customizations scripts/selftest.sh tasks/todo.md
```

Expected: diff only contains Ansible fact normalization, selftest guard, and task tracking.

- [ ] **Step 2: Confirm README was not changed**

Run:

```bash
git diff --name-only | rg '^README\.md$' || true
```

Expected: no output unless implementation changed operator-facing commands or behavior. If README changed, explain why in `tasks/todo.md`.

- [ ] **Step 3: Commit**

Run:

```bash
git add ansible customizations scripts/selftest.sh tasks/todo.md
git commit -m "Normalize Ansible OS fact usage"
```

Expected: commit succeeds.

- [ ] **Step 4: Decide integration path**

Use the finishing branch workflow after verification. If the user asked to merge and push, switch to `main`, fast-forward merge the feature branch, re-run at least `bash scripts/selftest.sh` and `git diff --check`, then push `main`.
