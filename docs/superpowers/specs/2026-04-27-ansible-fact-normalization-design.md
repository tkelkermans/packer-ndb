# Ansible Fact Normalization Design

## Goal

Remove Ansible 2.20 `INJECT_FACTS_AS_VARS` deprecation warnings from this repository's Ansible roles by replacing top-level `ansible_*` fact usage with readable role-local variables backed by `ansible_facts[...]`.

## Context

Live PostgreSQL validation on April 27, 2026 succeeded, but Ansible repeatedly warned that top-level facts such as `ansible_os_family`, `ansible_distribution`, and `ansible_distribution_major_version` are deprecated and will no longer be auto-injected after a future Ansible release. The warnings come from this repository's own role code and make live logs noisy enough that real failures are harder to spot.

The cleanup must cover both supported Ansible trees, `ansible/2.9` and `ansible/2.10`, plus committed customization examples under `customizations/examples`. It must not change image build behavior.

## Recommended Approach

Use role-local normalized variables.

Each affected role should define only the facts it needs near the start of its task file, using names that are short and beginner-readable:

```yaml
- name: Normalize OS facts
  ansible.builtin.set_fact:
    ndb_os_family: "{{ ansible_facts['os_family'] }}"
    ndb_distribution: "{{ ansible_facts['distribution'] }}"
    ndb_distribution_version: "{{ ansible_facts['distribution_version'] }}"
    ndb_distribution_major_version: "{{ ansible_facts['distribution_major_version'] }}"
    ndb_distribution_release: "{{ ansible_facts['distribution_release'] }}"
```

Roles should define the subset they actually use. For example, a role that only checks Red Hat versus Debian only needs `ndb_os_family`. A role that builds repository URLs may also need `ndb_distribution_major_version` or `ndb_distribution_release`.

This approach is preferred over direct `ansible_facts[...]` replacement everywhere because it keeps task conditions readable:

```yaml
when: ndb_os_family == "RedHat"
```

instead of:

```yaml
when: ansible_facts['os_family'] == "RedHat"
```

## Scope

Update top-level fact usage in these areas:

- `ansible/2.9/roles/common`
- `ansible/2.9/roles/postgres`
- `ansible/2.9/roles/mongodb`
- `ansible/2.9/roles/validate_postgres`
- `ansible/2.9/roles/validate_mongodb`
- `ansible/2.9/roles/image_prepare`
- `ansible/2.10/roles/common`
- `ansible/2.10/roles/postgres`
- `ansible/2.10/roles/mongodb`
- `ansible/2.10/roles/validate_postgres`
- `ansible/2.10/roles/validate_mongodb`
- `ansible/2.10/roles/image_prepare`
- PostgreSQL handlers in both Ansible trees
- committed customization example roles under `customizations/examples`

## Non-Goals

- Do not introduce a shared `ndb_facts` role in this pass.
- Do not restructure playbooks or role ordering.
- Do not change package names, repository URLs, service names, PostgreSQL extension behavior, MongoDB topology behavior, or validation semantics.
- Do not suppress deprecation warnings in `ansible.cfg` as a substitute for fixing our role code.
- Do not update beginner README guidance unless the implementation changes operator-facing commands or verification instructions.

## Architecture

Each role remains self-contained. If a role can be executed independently during artifact validation, customization preflight, or a normal Packer build, it must define the normalized facts it uses. Roles must not depend on another role having already set `ndb_os_family` or related variables.

The variable naming convention is:

- `ndb_os_family` for `ansible_facts['os_family']`
- `ndb_distribution` for `ansible_facts['distribution']`
- `ndb_distribution_version` for `ansible_facts['distribution_version']`
- `ndb_distribution_major_version` for `ansible_facts['distribution_major_version']`
- `ndb_distribution_release` for `ansible_facts['distribution_release']`

These names are intentionally project-prefixed to avoid accidental collisions with Ansible built-ins or customer variables.

## Data Flow

1. A playbook gathers facts as it does today.
2. The role starts and sets the normalized `ndb_*` facts it needs from `ansible_facts[...]`.
3. The rest of the role uses `ndb_*` variables in `when` clauses, repository strings, service-name expressions, and extension metadata lookups.
4. Validation roles and customization example roles repeat this normalization locally because they may run in different playbook contexts.

## Error Handling

Missing fact keys should fail normally through Ansible template evaluation. That is acceptable because these facts are fundamental to the supported Linux targets and should be present whenever facts are gathered.

Implementation should not add broad `default(...)` fallbacks that could hide unsupported target behavior. Existing intentional defaults, such as map lookups for PostgreSQL binary paths, should remain but use the normalized fact key.

## Testing Strategy

Add a static selftest guard that scans committed Ansible and customization YAML for deprecated top-level fact references, including:

- `ansible_os_family`
- `ansible_distribution`
- `ansible_distribution_version`
- `ansible_distribution_major_version`
- `ansible_distribution_release`

Run these checks after implementation:

- `bash -n build.sh test.sh scripts/*.sh`
- `bash scripts/selftest.sh`
- `bash scripts/matrix_validate.sh ndb/2.9/matrix.json ndb/2.10/matrix.json`
- Ansible syntax checks for `ansible/2.9/playbooks/site.yml`
- Ansible syntax checks for `ansible/2.10/playbooks/site.yml`
- Ansible syntax checks for both `customization_preflight.yml` playbooks
- Representative PostgreSQL and MongoDB dry-runs
- `git diff --check`

For live confidence, run one representative PostgreSQL Rocky build with `--validate --validate-artifact --manifest`, preferably the same NDB 2.10 PostgreSQL 18 Rocky Linux 9.7 path that previously showed the warnings. The expected live result is that repository-owned role code no longer emits `INJECT_FACTS_AS_VARS` warnings, while unrelated warnings such as Python interpreter discovery may still appear.

## Acceptance Criteria

- No committed core Ansible role or committed customization example role uses the deprecated top-level fact names listed in the static guard.
- Existing selftests pass.
- Ansible syntax checks pass for both supported NDB versions.
- Representative dry-runs preserve generated variables and build behavior.
- A representative live build, if run, succeeds with in-guest and artifact validation.
- No README operator guidance changes are made unless implementation changes operator-visible commands or behavior.
