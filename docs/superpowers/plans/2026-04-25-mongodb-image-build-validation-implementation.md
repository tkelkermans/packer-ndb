# MongoDB Image Build and Validation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and validate MongoDB NDB images for supported single-instance, replica-set, and sharded-cluster rows.

**Architecture:** Add `mongodb` as a first-class provisioning role beside `postgresql`. Dispatch build-time and artifact validation by `provisioning_role`/`db_type`, keep MongoDB provisioning and validation isolated in their own Ansible roles, and reuse the existing Packer, Prism, manifest, cleanup, and image-preparation flow.

**Tech Stack:** Bash, jq, Packer, Ansible 2.18, MongoDB official packages, Nutanix Prism API helpers.

---

## File Structure

- Modify `scripts/matrix_validate.sh`: validate MongoDB role, edition, deployment metadata, and duplicate grouping.
- Modify `scripts/selftest.sh`: add regression tests for MongoDB matrix validation, build dispatch, artifact dispatch, Ansible roles, and README commands.
- Modify `ndb/2.9/matrix.json`: convert supported MongoDB rows from `metadata` to `mongodb`, normalize sharded topology into `deployment`, remove fake sharded OS versions.
- Modify `ndb/2.10/matrix.json`: convert supported MongoDB rows from `metadata` to `mongodb`, keep unsupported sharded rows metadata-only, normalize topology metadata.
- Modify `build.sh`: generate MongoDB vars, accept `provisioning_role=mongodb`, pass MongoDB metadata to artifact validation.
- Modify `test.sh`: run every non-metadata provisioning role selected by `--include-db-type`, not only PostgreSQL.
- Modify `scripts/artifact_validate.sh`: dispatch validation roles by `db_type` and pass MongoDB metadata.
- Modify `ansible/2.9/playbooks/site.yml` and `ansible/2.10/playbooks/site.yml`: conditionally dispatch database roles.
- Create `ansible/2.9/roles/mongodb/defaults/main.yml` and `ansible/2.10/roles/mongodb/defaults/main.yml`: package/repository defaults.
- Create `ansible/2.9/roles/mongodb/tasks/main.yml` and `ansible/2.10/roles/mongodb/tasks/main.yml`: MongoDB package installation and service setup.
- Create `ansible/2.9/roles/validate_mongodb/defaults/main.yml` and `ansible/2.10/roles/validate_mongodb/defaults/main.yml`: validation defaults.
- Create `ansible/2.9/roles/validate_mongodb/tasks/main.yml` and `ansible/2.10/roles/validate_mongodb/tasks/main.yml`: service/version/connectivity/topology validation.
- Create `ansible/2.9/roles/validate_mongodb/files/validate_mongodb_sharded.sh` and `ansible/2.10/roles/validate_mongodb/files/validate_mongodb_sharded.sh`: local sharded topology smoke test.
- Modify `README.md`: MongoDB beginner instructions and validation commands.
- Modify `tasks/todo.md`: track implementation progress and final results.
- Modify `tasks/lessons.md` only if the user corrects the implementation approach.

## Task 1: Matrix Validator and Self-Test Guard

**Files:**
- Modify: `scripts/matrix_validate.sh`
- Modify: `scripts/selftest.sh`

- [ ] **Step 1: Add failing MongoDB matrix validator tests**

Add these cases inside `run_matrix_validator_tests()` in `scripts/selftest.sh`, after the existing PostgreSQL invalid matrix assertions:

```bash
  assert_invalid_matrix "mongodb role requires mongodb db type" '[{"ndb_version":"2.99","engine":"MongoDB","db_type":"pgsql","os_type":"Rocky Linux","os_version":"9.9","db_version":"8.0","provisioning_role":"mongodb","mongodb_edition":"community","deployment":["single-instance"]}]' "provisioning_role.*mongodb.*requires db_type"
  assert_invalid_matrix "mongodb edition required" '[{"ndb_version":"2.99","engine":"MongoDB","db_type":"mongodb","os_type":"Rocky Linux","os_version":"9.9","db_version":"8.0","provisioning_role":"mongodb","deployment":["single-instance"]}]' "mongodb_edition"
  assert_invalid_matrix "mongodb deployment required" '[{"ndb_version":"2.99","engine":"MongoDB","db_type":"mongodb","os_type":"Rocky Linux","os_version":"9.9","db_version":"8.0","provisioning_role":"mongodb","mongodb_edition":"community"}]' "deployment"
  assert_invalid_matrix "mongodb fake sharded os version" '[{"ndb_version":"2.99","engine":"MongoDB","db_type":"mongodb","os_type":"Rocky Linux","os_version":"9.9 (sharded)","db_version":"8.0","provisioning_role":"mongodb","mongodb_edition":"community","deployment":["sharded-cluster"]}]' "os_version.*must not encode MongoDB topology"
```

Also add this valid matrix after the existing valid PostgreSQL matrix write block:

```bash
  cat > "$tmpdir/2.99-mongodb/matrix.json" <<'JSON'
[
  {
    "ndb_version": "2.99-mongodb",
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
    "ndb_version": "2.99-mongodb",
    "engine": "MongoDB",
    "db_type": "mongodb",
    "os_type": "Rocky Linux",
    "os_version": "9.9",
    "db_version": "8.0",
    "provisioning_role": "metadata",
    "mongodb_edition": "enterprise",
    "deployment": ["sharded-cluster"],
    "notes": "metadata-only sharded row"
  }
]
JSON
  "$ROOT_DIR/scripts/matrix_validate.sh" "$tmpdir/2.99-mongodb/matrix.json" >/dev/null
```

- [ ] **Step 2: Run the focused self-test and verify failure**

Run:

```bash
bash scripts/selftest.sh
```

Expected: FAIL during `matrix validator`, with missing MongoDB validation errors not yet enforced.

- [ ] **Step 3: Implement MongoDB validation rules**

In `scripts/matrix_validate.sh`, add these jq checks after the existing PostgreSQL role/db_type check:

```jq
            (
              select(($entry.provisioning_role // null) == "mongodb" and ($entry.db_type // null) != "mongodb")
              | "\(ctx($idx; $entry)): provisioning_role '\''mongodb'\'' requires db_type '\''mongodb'\''"
            ),
            (
              select(($entry.db_type // null) == "mongodb" and (($entry.os_version // "") | test("\\(")))
              | "\(ctx($idx; $entry)): os_version must not encode MongoDB topology; use deployment metadata instead"
            ),
            (
              select(($entry.provisioning_role // null) == "mongodb" and (($entry.mongodb_edition // "") | IN("community", "enterprise") | not))
              | "\(ctx($idx; $entry)): buildable MongoDB rows require mongodb_edition community or enterprise"
            ),
            (
              select(($entry.provisioning_role // null) == "mongodb" and (($entry.deployment | type) != "array" or ($entry.deployment | length) == 0))
              | "\(ctx($idx; $entry)): buildable MongoDB rows require deployment as a non-empty list"
            ),
            (
              select(($entry.db_type // null) == "mongodb" and ($entry.deployment | type) == "array")
              | select(any($entry.deployment[]; (. | IN("single-instance", "replica-set", "sharded-cluster") | not)))
              | "\(ctx($idx; $entry)): MongoDB deployment values must be single-instance, replica-set, or sharded-cluster"
            ),
```

Replace duplicate grouping with this expression so MongoDB deployment metadata is part of the duplicate key:

```jq
        | group_by([
            .db_type,
            .os_type,
            .os_version,
            .db_version,
            (.mongodb_edition // ""),
            ((.deployment // []) | sort | join("+")),
            (.provisioning_role // "")
          ])[]
```

- [ ] **Step 4: Re-run focused verification**

Run:

```bash
bash scripts/selftest.sh
scripts/matrix_validate.sh ndb/*/matrix.json
```

Expected: self-tests pass. Matrix validation still passes before MongoDB matrix conversion.

- [ ] **Step 5: Commit**

Run:

```bash
git add scripts/matrix_validate.sh scripts/selftest.sh
git commit -m "Validate MongoDB matrix metadata"
```

## Task 2: MongoDB Matrix Conversion

**Files:**
- Modify: `ndb/2.9/matrix.json`
- Modify: `ndb/2.10/matrix.json`
- Modify: `scripts/selftest.sh`

- [ ] **Step 1: Add matrix coverage self-tests**

Add a new function near the other self-test functions:

```bash
run_mongodb_matrix_coverage_tests() {
  local buildable_29 buildable_210 fake_versions
  buildable_29=$(jq '[.[] | select(.db_type == "mongodb" and .provisioning_role == "mongodb")] | length' "$ROOT_DIR/ndb/2.9/matrix.json")
  buildable_210=$(jq '[.[] | select(.db_type == "mongodb" and .provisioning_role == "mongodb")] | length' "$ROOT_DIR/ndb/2.10/matrix.json")
  fake_versions=$(jq -s '[.[][] | select(.db_type == "mongodb" and (.os_version | test("\\(")))] | length' "$ROOT_DIR"/ndb/*/matrix.json)

  [[ "$buildable_29" == "9" ]] || fail "expected 9 buildable NDB 2.9 MongoDB rows, got $buildable_29"
  [[ "$buildable_210" == "9" ]] || fail "expected 9 buildable NDB 2.10 MongoDB rows, got $buildable_210"
  [[ "$fake_versions" == "0" ]] || fail "MongoDB topology is still encoded in os_version"

  jq -se '[.[][] | select(.db_type == "mongodb" and .provisioning_role == "mongodb" and (.deployment | index("sharded-cluster")))] | length == 5' "$ROOT_DIR"/ndb/*/matrix.json >/dev/null || fail "expected five buildable MongoDB sharded-readiness rows"
  jq -e '[.[] | select(.ndb_version == "2.10" and .db_type == "mongodb" and .provisioning_role == "mongodb" and (.deployment | index("sharded-cluster")) and .mongodb_edition != "enterprise")] | length == 0' "$ROOT_DIR/ndb/2.10/matrix.json" >/dev/null || fail "NDB 2.10 sharded MongoDB rows must be enterprise"

  pass "MongoDB matrix coverage"
}

run_mongodb_matrix_coverage_tests
```

- [ ] **Step 2: Run self-tests and verify failure**

Run:

```bash
bash scripts/selftest.sh
```

Expected: FAIL in `MongoDB matrix coverage` because all MongoDB rows are metadata-only today.

- [ ] **Step 3: Convert NDB 2.9 MongoDB rows**

Edit `ndb/2.9/matrix.json` so MongoDB rows become:

- Rocky Linux 9.6 MongoDB 8.0, 7.0, and 6.0: `provisioning_role="mongodb"`, `mongodb_edition="community"`, `deployment=["single-instance","replica-set","sharded-cluster"]`.
- RHEL 9.6 MongoDB 8.0, 7.0, and 6.0: `provisioning_role="mongodb"`, `mongodb_edition="community"`, `deployment=["single-instance","replica-set","sharded-cluster"]`.
- Ubuntu 22.04 MongoDB 8.0, 7.0, and 6.0: `provisioning_role="mongodb"`, `mongodb_edition="community"`, `deployment=["single-instance","replica-set"]`.

Remove the separate fake OS rows with `os_version` values like `9.6 (sharded)`. The sharded coverage is represented by the Rocky/RHEL deployment lists.

- [ ] **Step 4: Convert NDB 2.10 MongoDB rows**

Edit `ndb/2.10/matrix.json` so MongoDB rows become:

- Rocky Linux 9.7 MongoDB 8.0, 7.0, and 6.0: `provisioning_role="mongodb"`, `mongodb_edition="community"`, `deployment=["single-instance","replica-set"]`.
- RHEL 9.7 MongoDB 8.0 and 7.0: `provisioning_role="mongodb"`, `mongodb_edition="enterprise"`, `deployment=["single-instance","replica-set","sharded-cluster"]`, `notes="Enterprise packages required for NDB 2.10 sharded-cluster readiness"`.
- RHEL 9.7 MongoDB 6.0: `provisioning_role="mongodb"`, `mongodb_edition="community"`, `deployment=["single-instance","replica-set"]`.
- Ubuntu 22.04 MongoDB 8.0, 7.0, and 6.0: `provisioning_role="mongodb"`, `mongodb_edition="community"`, `deployment=["single-instance","replica-set"]`.
- RHEL 8.10 MongoDB 7.0 sharded: keep `provisioning_role="metadata"`, `mongodb_edition="enterprise"`, `deployment=["sharded-cluster"]`, `os_version="8.10"`.
- Rocky Linux 9.7 sharded metadata rows: keep metadata-only if retained, set `os_version="9.7"`, `mongodb_edition="enterprise"`, `deployment=["sharded-cluster"]`, and keep the not-qualified note.

- [ ] **Step 5: Run matrix verification**

Run:

```bash
jq empty ndb/2.9/matrix.json ndb/2.10/matrix.json
scripts/matrix_validate.sh ndb/*/matrix.json
bash scripts/selftest.sh
```

Expected: JSON parses, matrix validation passes, and MongoDB matrix coverage passes.

- [ ] **Step 6: Commit**

Run:

```bash
git add ndb/2.9/matrix.json ndb/2.10/matrix.json scripts/selftest.sh
git commit -m "Enable MongoDB buildable matrix rows"
```

## Task 3: Build and Test Harness Dispatch

**Files:**
- Modify: `build.sh`
- Modify: `test.sh`
- Modify: `scripts/selftest.sh`

- [ ] **Step 1: Add failing dispatch self-tests**

Add this function to `scripts/selftest.sh` after test harness tests:

```bash
run_mongodb_dispatch_guard_tests() {
  grep -q 'PROVISIONING_ROLE.*mongodb' "$ROOT_DIR/build.sh" || fail "build.sh does not allow MongoDB provisioning role"
  grep -q 'mongodb_edition' "$ROOT_DIR/build.sh" || fail "build.sh does not pass MongoDB edition to Ansible"
  grep -q 'mongodb_deployments' "$ROOT_DIR/build.sh" || fail "build.sh does not pass MongoDB deployments to Ansible"
  grep -q 'PROVISIONING_ROLE=$(echo "$CONFIG"' "$ROOT_DIR/build.sh" || fail "build.sh does not extract provisioning role from the matrix"
  grep -q -- '--provisioning-role "$PROVISIONING_ROLE"' "$ROOT_DIR/build.sh" || fail "build.sh does not pass provisioning role to artifact validation"
  grep -q 'if [[ "$provisioning_role" == "metadata" ]]' "$ROOT_DIR/test.sh" || fail "test.sh still filters to one hard-coded provisioning role"
  pass "MongoDB build and test dispatch guards"
}

run_mongodb_dispatch_guard_tests
```

- [ ] **Step 2: Run self-tests and verify failure**

Run:

```bash
bash scripts/selftest.sh
```

Expected: FAIL in `MongoDB build and test dispatch guards`.

- [ ] **Step 3: Update generated Ansible vars**

Change `generate_ansible_vars_json()` in `build.sh` to accept matrix metadata:

```bash
function generate_ansible_vars_json() {
  local ndb_version=$1
  local db_version=$2
  local extensions_json=$3
  local db_type=$4
  local validate_build=$5
  local provisioning_role=$6
  local mongodb_edition=$7
  local mongodb_deployments_json=$8

  jq -nc \
    --arg db_version "$db_version" \
    --arg db_type "$db_type" \
    --arg ndb_version "$ndb_version" \
    --arg provisioning_role "$provisioning_role" \
    --arg mongodb_edition "$mongodb_edition" \
    --argjson validate_build "$validate_build" \
    --argjson postgres_extensions "${extensions_json:-[]}" \
    --argjson mongodb_deployments "${mongodb_deployments_json:-[]}" \
    '{
      db_version: $db_version,
      db_type: $db_type,
      ndb_version: $ndb_version,
      provisioning_role: $provisioning_role,
      validate_build: $validate_build,
      postgres_extensions: $postgres_extensions,
      mongodb_edition: $mongodb_edition,
      mongodb_deployments: $mongodb_deployments
    }'
}
```

- [ ] **Step 4: Move role metadata extraction before vars generation**

In `build.sh`, after `CONFIG` is loaded and before `ANSIBLE_VARS_JSON` is created, extract:

```bash
POSTGRES_EXTENSIONS_JSON=$(echo "$CONFIG" | jq -c '.extensions // []')
ENGINE_NAME=$(echo "$CONFIG" | jq -r '.engine // ""')
PROVISIONING_ROLE=$(echo "$CONFIG" | jq -r '.provisioning_role // "postgresql"')
MONGODB_EDITION=$(echo "$CONFIG" | jq -r '.mongodb_edition // "community"')
MONGODB_DEPLOYMENTS_JSON=$(echo "$CONFIG" | jq -c '.deployment // []')
ANSIBLE_VARS_JSON=$(generate_ansible_vars_json "$NDB_VERSION" "$DB_VERSION" "$POSTGRES_EXTENSIONS_JSON" "$DB_TYPE" "$VALIDATE_BUILD" "$PROVISIONING_ROLE" "$MONGODB_EDITION" "$MONGODB_DEPLOYMENTS_JSON")
```

Replace the PostgreSQL-only guard with:

```bash
case "$PROVISIONING_ROLE" in
  postgresql|mongodb)
    ;;
  metadata)
    echo "Selected configuration (${ENGINE_NAME:-$DB_TYPE} on ${OS_TYPE} ${OS_VERSION}) is metadata-only." >&2
    exit 1
    ;;
  *)
    echo "Selected configuration (${ENGINE_NAME:-$DB_TYPE} on ${OS_TYPE} ${OS_VERSION}) uses unsupported provisioning role: ${PROVISIONING_ROLE}" >&2
    exit 1
    ;;
esac
```

- [ ] **Step 5: Pass MongoDB metadata to artifact validation**

Add these arguments to `ARTIFACT_VALIDATE_CMD` in `build.sh`:

```bash
    --provisioning-role "$PROVISIONING_ROLE"
    --mongodb-edition "$MONGODB_EDITION"
    --mongodb-deployments "$MONGODB_DEPLOYMENTS_JSON"
```

- [ ] **Step 6: Update test harness role filtering**

In `test.sh`, replace:

```bash
    if [[ "$provisioning_role" != "postgresql" ]]; then
      continue
    fi
```

with:

```bash
    if [[ "$provisioning_role" == "metadata" ]]; then
      continue
    fi
```

- [ ] **Step 7: Verify dispatch**

Run:

```bash
bash -n build.sh test.sh scripts/*.sh
bash scripts/selftest.sh
```

Expected: syntax checks and self-tests pass.

- [ ] **Step 8: Commit**

Run:

```bash
git add build.sh test.sh scripts/selftest.sh
git commit -m "Dispatch MongoDB builds through harness"
```

## Task 4: Ansible Playbook Role Dispatch

**Files:**
- Modify: `ansible/2.9/playbooks/site.yml`
- Modify: `ansible/2.10/playbooks/site.yml`
- Modify: `scripts/selftest.sh`

- [ ] **Step 1: Add failing playbook dispatch test**

Add this function near the existing image preparation guard tests:

```bash
run_playbook_database_dispatch_tests() {
  local version
  for version in 2.9 2.10; do
    grep -q "role: postgres" "$ROOT_DIR/ansible/$version/playbooks/site.yml" || fail "playbook $version missing postgres role dispatch"
    grep -q "role: mongodb" "$ROOT_DIR/ansible/$version/playbooks/site.yml" || fail "playbook $version missing mongodb role dispatch"
    grep -q "role: validate_mongodb" "$ROOT_DIR/ansible/$version/playbooks/site.yml" || fail "playbook $version missing validate_mongodb dispatch"
    grep -q "provisioning_role | default" "$ROOT_DIR/ansible/$version/playbooks/site.yml" || fail "playbook $version does not dispatch by provisioning_role"
  done
  pass "playbook database role dispatch"
}

run_playbook_database_dispatch_tests
```

- [ ] **Step 2: Run self-tests and verify failure**

Run:

```bash
bash scripts/selftest.sh
```

Expected: FAIL because `mongodb` and `validate_mongodb` roles do not exist in playbooks.

- [ ] **Step 3: Update both site playbooks**

Replace the role list in `ansible/2.9/playbooks/site.yml` and `ansible/2.10/playbooks/site.yml` with:

```yaml
- name: Configure Packer VM
  hosts: all
  roles:
    - common
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
    - image_prepare
```

- [ ] **Step 4: Run verification**

Run:

```bash
bash scripts/selftest.sh
PATH="/tmp/ndb-ansible-2.18/bin:$PATH" ANSIBLE_CONFIG=ansible/2.9/ansible.cfg ansible-playbook --syntax-check -i localhost, -c local ansible/2.9/playbooks/site.yml
PATH="/tmp/ndb-ansible-2.18/bin:$PATH" ANSIBLE_CONFIG=ansible/2.10/ansible.cfg ansible-playbook --syntax-check -i localhost, -c local ansible/2.10/playbooks/site.yml
```

Expected: self-tests pass. Ansible syntax checks may fail until the MongoDB roles are created in Task 5; if they fail with missing role `mongodb`, continue to Task 5 and rerun there.

- [ ] **Step 5: Commit after roles exist**

Commit this task together with Task 5 if syntax checks need the new roles:

```bash
git add ansible/2.9/playbooks/site.yml ansible/2.10/playbooks/site.yml scripts/selftest.sh
git commit -m "Dispatch Ansible database roles"
```

## Task 5: MongoDB Provisioning Roles

**Files:**
- Create: `ansible/2.9/roles/mongodb/defaults/main.yml`
- Create: `ansible/2.9/roles/mongodb/tasks/main.yml`
- Create: `ansible/2.10/roles/mongodb/defaults/main.yml`
- Create: `ansible/2.10/roles/mongodb/tasks/main.yml`
- Modify: `scripts/selftest.sh`

- [ ] **Step 1: Add failing provisioning-role self-test**

Add to `scripts/selftest.sh`:

```bash
run_mongodb_role_static_tests() {
  local version
  for version in 2.9 2.10; do
    grep -q "mongodb_edition" "$ROOT_DIR/ansible/$version/roles/mongodb/defaults/main.yml" || fail "mongodb role $version missing edition default"
    grep -q "repo.mongodb.org" "$ROOT_DIR/ansible/$version/roles/mongodb/tasks/main.yml" || fail "mongodb role $version missing community repository"
    grep -q "repo.mongodb.com" "$ROOT_DIR/ansible/$version/roles/mongodb/tasks/main.yml" || fail "mongodb role $version missing enterprise repository"
    grep -q "lock_timeout: 600" "$ROOT_DIR/ansible/$version/roles/mongodb/tasks/main.yml" || fail "mongodb role $version does not wait for apt locks"
    grep -q "mongodb-enterprise" "$ROOT_DIR/ansible/$version/roles/mongodb/tasks/main.yml" || fail "mongodb role $version does not support enterprise packages"
    grep -q "mongod" "$ROOT_DIR/ansible/$version/roles/mongodb/tasks/main.yml" || fail "mongodb role $version does not manage mongod service"
  done
  pass "MongoDB provisioning role static checks"
}

run_mongodb_role_static_tests
```

- [ ] **Step 2: Run self-tests and verify failure**

Run:

```bash
bash scripts/selftest.sh
```

Expected: FAIL because the MongoDB role files do not exist.

- [ ] **Step 3: Create defaults for both versions**

Create identical `ansible/2.9/roles/mongodb/defaults/main.yml` and `ansible/2.10/roles/mongodb/defaults/main.yml`:

```yaml
---
mongodb_edition: community
mongodb_deployments: []
mongodb_supported_versions:
  - "6.0"
  - "7.0"
  - "8.0"
mongodb_service_name: mongod
mongodb_user: mongod
mongodb_group: mongod
mongodb_config_file: /etc/mongod.conf
mongodb_keyring_dir: /etc/apt/keyrings
mongodb_redhat_arch: x86_64
mongodb_debian_arch: amd64
mongodb_package_names:
  community:
    RedHat:
      - mongodb-org
      - mongodb-mongosh
    Debian:
      - mongodb-org
      - mongodb-mongosh
  enterprise:
    RedHat:
      - mongodb-enterprise
      - mongodb-mongosh
    Debian:
      - mongodb-enterprise
      - mongodb-mongosh
```

- [ ] **Step 4: Create tasks for both versions**

Create identical `ansible/2.9/roles/mongodb/tasks/main.yml` and `ansible/2.10/roles/mongodb/tasks/main.yml`:

```yaml
---
- name: Validate MongoDB role inputs
  ansible.builtin.assert:
    that:
      - db_version in mongodb_supported_versions
      - mongodb_edition in ["community", "enterprise"]
      - mongodb_deployments | type_debug == "list"
      - mongodb_deployments | length > 0
    fail_msg: "Unsupported MongoDB selection: version={{ db_version }}, edition={{ mongodb_edition }}, deployments={{ mongodb_deployments }}"

- name: Set MongoDB package facts
  ansible.builtin.set_fact:
    mongodb_major_version: "{{ db_version }}"
    mongodb_package_family: "{{ 'mongodb-enterprise' if mongodb_edition == 'enterprise' else 'mongodb-org' }}"
    mongodb_repo_host: "{{ 'repo.mongodb.com' if mongodb_edition == 'enterprise' else 'repo.mongodb.org' }}"
    mongodb_gpg_key_url: "https://pgp.mongodb.com/server-{{ db_version }}.asc"

- name: Configure MongoDB repository (RedHat family)
  ansible.builtin.yum_repository:
    name: "{{ mongodb_package_family }}-{{ mongodb_major_version }}"
    description: "MongoDB {{ mongodb_edition }} Repository {{ mongodb_major_version }}"
    baseurl: "https://{{ mongodb_repo_host }}/yum/redhat/{{ ansible_distribution_major_version }}/{{ mongodb_package_family }}/{{ mongodb_major_version }}/{{ mongodb_redhat_arch }}/"
    gpgcheck: true
    enabled: true
    gpgkey: "{{ mongodb_gpg_key_url }}"
  when: ansible_os_family == "RedHat"
  become: yes

- name: Download MongoDB GPG key (Debian family)
  ansible.builtin.get_url:
    url: "{{ mongodb_gpg_key_url }}"
    dest: "{{ mongodb_keyring_dir }}/mongodb-server-{{ mongodb_major_version }}.asc"
    owner: root
    group: root
    mode: "0644"
  when: ansible_os_family == "Debian"
  become: yes

- name: Install MongoDB GPG keyring (Debian family)
  ansible.builtin.command:
    argv:
      - gpg
      - --dearmor
      - --yes
      - --output
      - "{{ mongodb_keyring_dir }}/mongodb-server-{{ mongodb_major_version }}.gpg"
      - "{{ mongodb_keyring_dir }}/mongodb-server-{{ mongodb_major_version }}.asc"
    creates: "{{ mongodb_keyring_dir }}/mongodb-server-{{ mongodb_major_version }}.gpg"
  when: ansible_os_family == "Debian"
  become: yes

- name: Configure MongoDB repository (Debian family)
  ansible.builtin.apt_repository:
    repo: "deb [ arch={{ mongodb_debian_arch }} signed-by={{ mongodb_keyring_dir }}/mongodb-server-{{ mongodb_major_version }}.gpg ] https://{{ mongodb_repo_host }}/apt/ubuntu {{ ansible_distribution_release }}/{{ mongodb_package_family }}/{{ mongodb_major_version }} multiverse"
    filename: "{{ mongodb_package_family }}-{{ mongodb_major_version }}"
    state: present
    update_cache: true
  when: ansible_os_family == "Debian"
  become: yes

- name: Refresh dnf metadata after MongoDB repository change (RedHat family)
  ansible.builtin.command:
    argv:
      - dnf
      - -y
      - makecache
  register: mongodb_dnf_makecache_result
  retries: 5
  delay: 10
  until: mongodb_dnf_makecache_result.rc == 0
  changed_when: false
  when: ansible_os_family == "RedHat"
  become: yes

- name: Install MongoDB packages (RedHat family)
  ansible.builtin.package:
    name: "{{ mongodb_package_names[mongodb_edition].RedHat }}"
    state: present
  when: ansible_os_family == "RedHat"
  become: yes

- name: Install MongoDB packages (Debian family)
  ansible.builtin.apt:
    name: "{{ mongodb_package_names[mongodb_edition].Debian }}"
    state: present
    lock_timeout: 600
  register: mongodb_apt_install_result
  retries: 6
  delay: 10
  until: mongodb_apt_install_result is succeeded
  when: ansible_os_family == "Debian"
  become: yes

- name: Ensure MongoDB service is enabled and running
  ansible.builtin.service:
    name: "{{ mongodb_service_name }}"
    state: started
    enabled: true
  become: yes
```

- [ ] **Step 5: Run syntax and static verification**

Run:

```bash
bash scripts/selftest.sh
PATH="/tmp/ndb-ansible-2.18/bin:$PATH" ANSIBLE_CONFIG=ansible/2.9/ansible.cfg ansible-playbook --syntax-check -i localhost, -c local ansible/2.9/playbooks/site.yml
PATH="/tmp/ndb-ansible-2.18/bin:$PATH" ANSIBLE_CONFIG=ansible/2.10/ansible.cfg ansible-playbook --syntax-check -i localhost, -c local ansible/2.10/playbooks/site.yml
```

Expected: self-tests pass through MongoDB provisioning checks. Syntax checks pass or expose YAML/Jinja issues to fix immediately.

- [ ] **Step 6: Commit**

Run:

```bash
git add ansible/2.9/playbooks/site.yml ansible/2.10/playbooks/site.yml ansible/2.9/roles/mongodb ansible/2.10/roles/mongodb scripts/selftest.sh
git commit -m "Add MongoDB provisioning roles"
```

## Task 6: MongoDB Validation Roles

**Files:**
- Create: `ansible/2.9/roles/validate_mongodb/defaults/main.yml`
- Create: `ansible/2.9/roles/validate_mongodb/tasks/main.yml`
- Create: `ansible/2.9/roles/validate_mongodb/files/validate_mongodb_sharded.sh`
- Create: `ansible/2.10/roles/validate_mongodb/defaults/main.yml`
- Create: `ansible/2.10/roles/validate_mongodb/tasks/main.yml`
- Create: `ansible/2.10/roles/validate_mongodb/files/validate_mongodb_sharded.sh`
- Modify: `scripts/selftest.sh`

- [ ] **Step 1: Add failing validation-role self-test**

Add to `scripts/selftest.sh`:

```bash
run_validate_mongodb_role_static_tests() {
  local version
  for version in 2.9 2.10; do
    grep -q "validate_mongodb_service_active_retries" "$ROOT_DIR/ansible/$version/roles/validate_mongodb/defaults/main.yml" || fail "validate_mongodb role $version missing retry default"
    grep -q "mongod --version" "$ROOT_DIR/ansible/$version/roles/validate_mongodb/tasks/main.yml" || fail "validate_mongodb role $version does not check mongod version"
    grep -q "db.version()" "$ROOT_DIR/ansible/$version/roles/validate_mongodb/tasks/main.yml" || fail "validate_mongodb role $version does not check server version"
    grep -q "validate_mongodb_sharded.sh" "$ROOT_DIR/ansible/$version/roles/validate_mongodb/tasks/main.yml" || fail "validate_mongodb role $version does not run sharded validation"
    grep -q "trap cleanup EXIT" "$ROOT_DIR/ansible/$version/roles/validate_mongodb/files/validate_mongodb_sharded.sh" || fail "sharded validation $version lacks cleanup trap"
    grep -q "sh.addShard" "$ROOT_DIR/ansible/$version/roles/validate_mongodb/files/validate_mongodb_sharded.sh" || fail "sharded validation $version does not add a shard"
  done
  pass "MongoDB validation role static checks"
}

run_validate_mongodb_role_static_tests
```

- [ ] **Step 2: Run self-tests and verify failure**

Run:

```bash
bash scripts/selftest.sh
```

Expected: FAIL because `validate_mongodb` role files do not exist.

- [ ] **Step 3: Create validation defaults**

Create identical defaults in both NDB versions:

```yaml
---
validate_mongodb_major_version: "{{ db_version }}"
validate_mongodb_deployments: "{{ mongodb_deployments | default([]) }}"
validate_mongodb_service_active_retries: 12
validate_mongodb_service_active_delay: 5
validate_mongodb_mongod_binary: /usr/bin/mongod
validate_mongodb_mongosh_binary: /usr/bin/mongosh
validate_mongodb_mongos_binary: /usr/bin/mongos
validate_mongodb_sharded_script_path: /tmp/validate_mongodb_sharded.sh
```

- [ ] **Step 4: Create sharded validation shell script**

Create identical executable content in both `files/validate_mongodb_sharded.sh` files:

```bash
#!/usr/bin/env bash
set -euo pipefail

TMPDIR=$(mktemp -d /tmp/ndb-mongodb-sharded.XXXXXX)
PIDS=()

cleanup() {
  local pid
  for pid_file in "$TMPDIR"/*.pid; do
    [[ -f "$pid_file" ]] || continue
    pid=$(cat "$pid_file")
    if [[ -n "$pid" ]] && kill -0 "$pid" >/dev/null 2>&1; then
      kill "$pid" >/dev/null 2>&1 || true
    fi
  done
  rm -rf "$TMPDIR"
}
trap cleanup EXIT

wait_for_primary() {
  local port=$1
  for _ in {1..60}; do
    if mongosh --quiet --port "$port" --eval 'db.hello().isWritablePrimary' 2>/dev/null | grep -q true; then
      return 0
    fi
    sleep 1
  done
  echo "Timed out waiting for primary on port $port" >&2
  return 1
}

mkdir -p "$TMPDIR/config" "$TMPDIR/shard"

mongod --configsvr --replSet cfg --dbpath "$TMPDIR/config" --port 27091 --bind_ip 127.0.0.1 --fork --logpath "$TMPDIR/config.log" --pidfilepath "$TMPDIR/config.pid"
mongod --shardsvr --replSet shard1 --dbpath "$TMPDIR/shard" --port 27092 --bind_ip 127.0.0.1 --fork --logpath "$TMPDIR/shard.log" --pidfilepath "$TMPDIR/shard.pid"

mongosh --quiet --port 27091 --eval 'rs.initiate({_id:"cfg", configsvr:true, members:[{_id:0, host:"127.0.0.1:27091"}]})'
mongosh --quiet --port 27092 --eval 'rs.initiate({_id:"shard1", members:[{_id:0, host:"127.0.0.1:27092"}]})'
wait_for_primary 27091
wait_for_primary 27092

mongos --configdb cfg/127.0.0.1:27091 --bind_ip 127.0.0.1 --port 27093 --fork --logpath "$TMPDIR/mongos.log" --pidfilepath "$TMPDIR/mongos.pid"
for _ in {1..60}; do
  if mongosh --quiet --port 27093 --eval 'db.adminCommand({ping:1}).ok' 2>/dev/null | grep -q 1; then
    break
  fi
  sleep 1
done

mongosh --quiet --port 27093 --eval 'sh.addShard("shard1/127.0.0.1:27092")'
mongosh --quiet --port 27093 --eval 'db.adminCommand({listShards:1}).shards.length' | grep -Eq '^[1-9][0-9]*$'
```

- [ ] **Step 5: Create validation tasks**

Create identical `tasks/main.yml` in both NDB versions:

```yaml
---
- name: Build MongoDB validation service list
  ansible.builtin.set_fact:
    validate_mongodb_services:
      - label: firewalld
        unit: firewalld.service
      - label: chrony
        unit: "{{ 'chronyd.service' if ansible_os_family == 'RedHat' else 'chrony.service' }}"
      - label: cron
        unit: "{{ 'crond.service' if ansible_os_family == 'RedHat' else 'cron.service' }}"
      - label: mongod
        unit: mongod.service

- name: Check required services are active
  ansible.builtin.command:
    argv:
      - systemctl
      - is-active
      - "{{ item.unit }}"
  register: validate_mongodb_service_active_result
  changed_when: false
  failed_when: false
  retries: "{{ validate_mongodb_service_active_retries }}"
  delay: "{{ validate_mongodb_service_active_delay }}"
  until: validate_mongodb_service_active_result.stdout == "active"
  loop: "{{ validate_mongodb_services }}"

- name: Assert required services are active
  ansible.builtin.assert:
    that:
      - item.stdout == "active"
    fail_msg: "Expected {{ item.item.label }} service {{ item.item.unit }} to be active, got {{ item.stdout | default('') }}"
  loop: "{{ validate_mongodb_service_active_result.results }}"

- name: Check mongod binary version
  ansible.builtin.command:
    argv:
      - "{{ validate_mongodb_mongod_binary }}"
      - --version
  register: validate_mongodb_mongod_version
  changed_when: false

- name: Assert mongod binary major version
  ansible.builtin.assert:
    that:
      - validate_mongodb_mongod_version.stdout is regex("db version v" ~ validate_mongodb_major_version ~ "\\.")
    fail_msg: "Expected mongod major version {{ validate_mongodb_major_version }}, got {{ validate_mongodb_mongod_version.stdout | default('') | trim }}"

- name: Check MongoDB server version with mongosh
  ansible.builtin.command:
    argv:
      - "{{ validate_mongodb_mongosh_binary }}"
      - --quiet
      - --eval
      - "db.version()"
  register: validate_mongodb_server_version
  changed_when: false

- name: Assert MongoDB server major version
  ansible.builtin.assert:
    that:
      - validate_mongodb_server_version.stdout is regex("^" ~ validate_mongodb_major_version ~ "\\.")
    fail_msg: "Expected MongoDB server major version {{ validate_mongodb_major_version }}, got {{ validate_mongodb_server_version.stdout | default('') | trim }}"

- name: Install sharded validation script
  ansible.builtin.copy:
    src: validate_mongodb_sharded.sh
    dest: "{{ validate_mongodb_sharded_script_path }}"
    owner: root
    group: root
    mode: "0755"
  when: "'sharded-cluster' in validate_mongodb_deployments"
  become: yes

- name: Run local MongoDB sharded topology smoke validation
  ansible.builtin.command:
    argv:
      - "{{ validate_mongodb_sharded_script_path }}"
  changed_when: false
  when: "'sharded-cluster' in validate_mongodb_deployments"
```

- [ ] **Step 6: Run verification**

Run:

```bash
bash scripts/selftest.sh
PATH="/tmp/ndb-ansible-2.18/bin:$PATH" ANSIBLE_CONFIG=ansible/2.9/ansible.cfg ansible-playbook --syntax-check -i localhost, -c local ansible/2.9/playbooks/site.yml
PATH="/tmp/ndb-ansible-2.18/bin:$PATH" ANSIBLE_CONFIG=ansible/2.10/ansible.cfg ansible-playbook --syntax-check -i localhost, -c local ansible/2.10/playbooks/site.yml
```

Expected: self-tests and Ansible syntax checks pass.

- [ ] **Step 7: Commit**

Run:

```bash
git add ansible/2.9/roles/validate_mongodb ansible/2.10/roles/validate_mongodb scripts/selftest.sh
git commit -m "Add MongoDB validation roles"
```

## Task 7: Artifact Validation Dispatch

**Files:**
- Modify: `scripts/artifact_validate.sh`
- Modify: `scripts/selftest.sh`

- [ ] **Step 1: Add failing artifact-dispatch self-test**

Extend `run_artifact_validate_tests()` so the mocked `ansible-playbook` records the generated playbook:

```bash
  cat > "$tmpdir/bin/ansible-playbook" <<'SH'
#!/usr/bin/env bash
for arg in "$@"; do
  case "$arg" in
    *.yml)
      if [[ -n "${NDB_SELFTEST_PLAYBOOK_CAPTURE:-}" ]]; then
        cp "$arg" "$NDB_SELFTEST_PLAYBOOK_CAPTURE"
      fi
      ;;
  esac
done
exit "${NDB_SELFTEST_ANSIBLE_RC:-42}"
SH
```

Add a success-path MongoDB invocation after the PostgreSQL success path:

```bash
  (
    export PATH="$tmpdir/bin:$PATH"
    export PKR_VAR_pc_username=user
    export PKR_VAR_pc_password=password
    export PKR_VAR_pc_ip=pc.example.com
    export PKR_VAR_cluster_name=mock-cluster
    export PKR_VAR_subnet_name=mock-subnet
    export NDB_SELFTEST_DELETE_MARKER="$tmpdir/delete-called"
    export NDB_SELFTEST_ANSIBLE_RC=0
    export NDB_SELFTEST_PLAYBOOK_CAPTURE="$tmpdir/mongodb-validate.yml"
    "$ROOT_DIR/scripts/artifact_validate.sh" \
      --image-name test-image \
      --ndb-version 2.10 \
      --db-version 8.0 \
      --db-type mongodb \
      --provisioning-role mongodb \
      --mongodb-edition community \
      --mongodb-deployments '["single-instance","replica-set","sharded-cluster"]' \
      --result-file "$tmpdir/mongodb-result.json" >/dev/null
  ) || fail "MongoDB artifact validation success path failed"

  grep -q "validate_mongodb" "$tmpdir/mongodb-validate.yml" || fail "MongoDB artifact validation did not dispatch validate_mongodb"
  jq -e '.status == "passed"' "$tmpdir/mongodb-result.json" >/dev/null || fail "MongoDB artifact validation result JSON"
```

- [ ] **Step 2: Run self-tests and verify failure**

Run:

```bash
bash scripts/selftest.sh
```

Expected: FAIL because `artifact_validate.sh` does not accept MongoDB arguments or dispatch `validate_mongodb`.

- [ ] **Step 3: Add MongoDB options and validation**

In `scripts/artifact_validate.sh`, add variables:

```bash
PROVISIONING_ROLE=""
MONGODB_EDITION="community"
MONGODB_DEPLOYMENTS_JSON="[]"
```

Add usage lines:

```text
  --provisioning-role ROLE       Provisioning role from matrix row
  --mongodb-edition EDITION      MongoDB edition: community or enterprise
  --mongodb-deployments JSON     MongoDB deployment list JSON
```

Parse the three options in the `case` statement.

Add a helper:

```bash
json_mongodb_deployments() {
  local json=$1
  jq -ce 'if type == "array" and all(.[]; type == "string" and (. == "single-instance" or . == "replica-set" or . == "sharded-cluster")) then . else error("expected MongoDB deployment array") end' <<<"$json"
}
```

Normalize:

```bash
PROVISIONING_ROLE=${PROVISIONING_ROLE:-$([[ "$DB_TYPE" == "mongodb" ]] && echo "mongodb" || echo "postgresql")}
MONGODB_DEPLOYMENTS_JSON=$(json_mongodb_deployments "$MONGODB_DEPLOYMENTS_JSON")
```

- [ ] **Step 4: Dispatch generated validation playbook**

Replace the fixed `validate_postgres` playbook generation with:

```bash
VALIDATION_ROLE="validate_postgres"
if [[ "$DB_TYPE" == "mongodb" ]]; then
  VALIDATION_ROLE="validate_mongodb"
fi

cat > "$TMPDIR/validate.yml" <<EOF
---
- name: Validate saved NDB image artifact
  hosts: validation
  roles:
    - ${VALIDATION_ROLE}
EOF
```

Only require PostgreSQL defaults for PostgreSQL:

```bash
POSTGRES_DEFAULTS="$ANSIBLE_DIR/roles/postgres/defaults/main.yml"
if [[ "$DB_TYPE" == "pgsql" ]]; then
  require_file "$POSTGRES_DEFAULTS"
fi
```

Generate vars:

```bash
jq -n \
  --arg db_version "$DB_VERSION" \
  --arg db_type "$DB_TYPE" \
  --arg provisioning_role "$PROVISIONING_ROLE" \
  --arg mongodb_edition "$MONGODB_EDITION" \
  --argjson postgres_extensions "$EXTENSIONS_JSON" \
  --argjson mongodb_deployments "$MONGODB_DEPLOYMENTS_JSON" \
  '{
    db_version: $db_version,
    db_type: $db_type,
    provisioning_role: $provisioning_role,
    configure_ndb_sudoers: true,
    postgres_extensions: $postgres_extensions,
    postgres_extensions_databases: ["postgres"],
    mongodb_edition: $mongodb_edition,
    mongodb_deployments: $mongodb_deployments
  }' > "$TMPDIR/vars.json"
```

Build `ansible-playbook` arguments conditionally so `-e "@${POSTGRES_DEFAULTS}"` is included only for PostgreSQL.

- [ ] **Step 5: Verify artifact dispatch**

Run:

```bash
bash -n scripts/artifact_validate.sh
bash scripts/selftest.sh
```

Expected: self-tests pass and MongoDB artifact validation dispatch captures `validate_mongodb`.

- [ ] **Step 6: Commit**

Run:

```bash
git add scripts/artifact_validate.sh scripts/selftest.sh
git commit -m "Dispatch artifact validation by database type"
```

## Task 8: README and Operator Guidance

**Files:**
- Modify: `README.md`
- Modify: `scripts/selftest.sh`
- Modify: `tasks/todo.md`

- [ ] **Step 1: Add failing README self-test**

Add to `scripts/selftest.sh`:

```bash
run_readme_mongodb_tests() {
  grep -q "MongoDB" "$ROOT_DIR/README.md" || fail "README does not mention MongoDB"
  grep -q -- "--include-db-type mongodb" "$ROOT_DIR/README.md" || fail "README missing MongoDB test command"
  grep -q "sharded topology" "$ROOT_DIR/README.md" || fail "README missing local sharded topology explanation"
  grep -q "mongodb_edition" "$ROOT_DIR/README.md" || fail "README missing MongoDB edition matrix guidance"
  pass "README MongoDB guidance"
}

run_readme_mongodb_tests
```

- [ ] **Step 2: Run self-tests and verify failure**

Run:

```bash
bash scripts/selftest.sh
```

Expected: FAIL until README MongoDB instructions are added.

- [ ] **Step 3: Update README**

Add a beginner-facing MongoDB section covering:

```markdown
## MongoDB Builds

MongoDB rows use `provisioning_role=mongodb`.

Run the MongoDB live suite:

```bash
./test.sh --include-db-type mongodb --validate --validate-artifact --manifest --max-parallel 1
```

With 1Password-managed `.env`:

```bash
op run --env-file .env -- ./test.sh --include-db-type mongodb --validate --validate-artifact --manifest --max-parallel 1
```

Some MongoDB rows validate only single-instance and replica-set readiness. Rows whose `deployment` includes `sharded-cluster` also run a local sharded topology smoke test inside the validation VM. That smoke test starts temporary localhost `mongod` and `mongos` processes, adds one shard, verifies the shard list, and cleans up before validation exits.

MongoDB Enterprise rows are explicit in the matrix with `mongodb_edition=enterprise`. NDB 2.10 sharded-cluster readiness uses Enterprise packages because the NDB 2.10 release notes list sharded MongoDB as Enterprise-only.
```

Add matrix guidance:

```markdown
Buildable MongoDB rows require:

```json
{
  "db_type": "mongodb",
  "provisioning_role": "mongodb",
  "mongodb_edition": "community",
  "deployment": ["single-instance", "replica-set"]
}
```

Do not encode topology in `os_version`; use `deployment`.
```

- [ ] **Step 4: Update task log**

Append to `tasks/todo.md` that implementation has moved from spec to execution and that README was updated with MongoDB usage.

- [ ] **Step 5: Verify docs**

Run:

```bash
bash scripts/selftest.sh
git diff --check
```

Expected: self-tests and whitespace check pass.

- [ ] **Step 6: Commit**

Run:

```bash
git add README.md scripts/selftest.sh tasks/todo.md
git commit -m "Document MongoDB image validation"
```

## Task 9: Full Offline Verification

**Files:**
- No edits unless verification exposes defects.

- [ ] **Step 1: Run shell syntax**

Run:

```bash
bash -n build.sh test.sh scripts/*.sh
```

Expected: exit 0.

- [ ] **Step 2: Run self-tests**

Run:

```bash
bash scripts/selftest.sh
```

Expected: every `PASS:` line prints and exit code is 0.

- [ ] **Step 3: Run matrix validation**

Run:

```bash
scripts/matrix_validate.sh ndb/*/matrix.json
```

Expected: each matrix reports `Matrix validation succeeded`.

- [ ] **Step 4: Run Ansible syntax**

Run:

```bash
PATH="/tmp/ndb-ansible-2.18/bin:$PATH" ANSIBLE_CONFIG=ansible/2.9/ansible.cfg ansible-playbook --syntax-check -i localhost, -c local ansible/2.9/playbooks/site.yml
PATH="/tmp/ndb-ansible-2.18/bin:$PATH" ANSIBLE_CONFIG=ansible/2.10/ansible.cfg ansible-playbook --syntax-check -i localhost, -c local ansible/2.10/playbooks/site.yml
```

Expected: both commands print the playbook path and exit 0.

- [ ] **Step 5: Run Packer checks**

Run:

```bash
packer fmt -check packer
PKR_VAR_pc_username=user PKR_VAR_pc_password=password PKR_VAR_pc_ip=127.0.0.1 PKR_VAR_cluster_name=cluster PKR_VAR_subnet_name=subnet packer validate -var 'image_name=validation' -var 'ndb_version=2.10' -var 'db_type=mongodb' -var 'db_version=8.0' -var 'os_type=Rocky Linux' -var 'os_version=9.7' -var 'patroni_version=' -var 'etcd_version=' -var 'source_image_name=source' -var 'ansible_site_playbook=ansible/2.10/playbooks/site.yml' packer
```

Expected: Packer format check exits 0 and validate prints `The configuration is valid.`

- [ ] **Step 6: Run dry-run examples**

Run:

```bash
./build.sh --dry-run --ci --ndb-version 2.10 --db-type mongodb --os "Rocky Linux" --os-version 9.7 --db-version 8.0 --validate --validate-artifact
./build.sh --dry-run --ci --ndb-version 2.9 --db-type mongodb --os "Ubuntu Linux" --os-version 22.04 --db-version 7.0 --validate --validate-artifact
```

Expected: dry-run summaries show `Provisioning role: mongodb`, MongoDB edition/deployments in generated vars, and no hard-coded PostgreSQL rejection.

- [ ] **Step 7: Run whitespace check**

Run:

```bash
git diff --check
```

Expected: exit 0.

- [ ] **Step 8: Commit verification fixes if needed**

If any verification command exposed a defect, fix the defect, rerun the failing command and the relevant broader check, then commit:

```bash
git add <fixed-files>
git commit -m "Fix MongoDB offline validation issues"
```

## Task 10: Live MongoDB Validation

**Files:**
- Modify: `tasks/todo.md`
- Modify: `tasks/lessons.md` only if a user correction occurs.

- [ ] **Step 1: Check non-secret environment readiness**

Run:

```bash
op run --env-file .env -- bash -lc '
for name in PKR_VAR_pc_username PKR_VAR_pc_password PKR_VAR_pc_ip PKR_VAR_cluster_name PKR_VAR_subnet_name NDB_RHEL_9_6_IMAGE_URI NDB_RHEL_9_7_IMAGE_URI; do
  value=${!name:-}
  if [ -n "$value" ]; then
    printf "%s=set\n" "$name"
  else
    printf "%s=missing\n" "$name"
  fi
done
'
```

Expected: Prism variables are `set`. RHEL variables may be `missing`; if missing, exclude RHEL rows and record the blocker.

- [ ] **Step 2: Run non-RHEL live MongoDB validation first**

Run:

```bash
mkdir -p logs
PATH="/tmp/ndb-ansible-2.18/bin:$PATH" op run --env-file .env -- ./test.sh --include-db-type mongodb --exclude-os "Red Hat Enterprise Linux (RHEL)" --validate --validate-artifact --manifest --continue-on-error --max-parallel 1 > logs/mongodb-validation-$(date +%Y%m%d)-nonrhel.log 2>&1
```

Expected: all selected non-RHEL MongoDB rows build and artifact-validate, or failures are captured without stopping remaining rows.

- [ ] **Step 3: Run RHEL live MongoDB validation if image variables are set**

Only run this if the RHEL source image variables are non-empty:

```bash
PATH="/tmp/ndb-ansible-2.18/bin:$PATH" op run --env-file .env -- ./test.sh --include-db-type mongodb --include-os "Red Hat Enterprise Linux (RHEL)" --allow-rhel --validate --validate-artifact --manifest --continue-on-error --max-parallel 1 > logs/mongodb-validation-$(date +%Y%m%d)-rhel.log 2>&1
```

Expected: all selected RHEL MongoDB rows build and artifact-validate. If RHEL image variables are missing, do not claim RHEL validation.

- [ ] **Step 4: Summarize live logs**

Run:

```bash
for f in logs/mongodb-validation-*.log; do
  awk -v file="$f" '/^--> Testing build:/{started++} /Error: build process/{errors++} /Build .* finished after/{finished++} /PLAY RECAP/{recaps++} /All requested tests completed successfully/{success++} END {printf "%s started=%d errors=%d finished=%d recaps=%d success=%d\n", file, started, errors, finished, recaps, success}' "$f"
done
```

Expected: counts match selected rows. Any errors are investigated before completion.

- [ ] **Step 5: Confirm cleanup in Prism**

Run:

```bash
op run --env-file .env -- bash -lc '
set -euo pipefail
source scripts/prism.sh
prism_list_resource vms vm 2000 | jq -r '"'"'
  .entities[]?
  | select((.spec.name // .status.name // "") | test("^(ndb|validate-ndb)-.*mongodb|^(ndb|validate-ndb)-.*MongoDB"))
  | [.metadata.uuid, (.spec.name // .status.name), (.status.resources.power_state // "")] | @tsv
'"'"'
'
```

Expected: empty output. If VMs remain, clean them up through existing Prism helper flow and record what was removed.

- [ ] **Step 6: Update task review with final evidence**

Update `tasks/todo.md` with:

- validated row count by NDB version and OS family.
- sharded validation row count.
- log file names.
- any RHEL blocker.
- cleanup result.

- [ ] **Step 7: Final verification before closeout**

Run:

```bash
git diff --check
git status --short
```

Expected: whitespace clean. Status shows only intended modified files plus unrelated untracked `.vscode/` and `package-lock.json` if they still exist.

- [ ] **Step 8: Commit final task-log update**

Run:

```bash
git add tasks/todo.md tasks/lessons.md
git commit -m "Record MongoDB validation results"
```
