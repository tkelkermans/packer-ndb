# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A matrix-driven Packer + Ansible image factory that builds Nutanix Database Service (NDB) gold images on Nutanix AHV via Prism Central. Buildable engines: PostgreSQL Community Edition and MongoDB (community/enterprise) across Rocky Linux, Ubuntu, Debian, and RHEL, for NDB 2.9 and 2.10. Matrix rows with `provisioning_role=metadata` (Oracle, SQL Server, MySQL, MariaDB) document future support and are rejected by `build.sh`.

## CRITICAL: .env is a 1Password FIFO

`.env` can be a 1Password-managed named pipe. NEVER read it directly (`cat`, `sed`, Read tool, `source .env`) — reads block forever and consume the mount stream. Run exactly ONE serialized `op run --env-file=.env -- <command>` at a time; parallel `op run` calls cause intermittent secret-read failures. `.env.example` is the safe schema reference. Never print NDB payload `actionArguments` values; redact fields whose names include `password`, `secret`, `key`, or `token`.

## Commands

All helper scripts are Bash, not zsh (they use `${!var}` indirect expansion). One-time setup:

```bash
ssh-keygen -t rsa -b 4096 -C "packer@nutanix" -f packer/id_rsa -N ""
packer init packer/
cp .env.example .env   # or wire up 1Password; then prefix live commands with: op run --env-file=.env --
```

Build (single matrix row):

```bash
# Dry run — no Prism credentials needed; shows row, source image plan, Ansible/Packer vars
./build.sh --dry-run --ci --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18

# Preflight — Prism/source-image readiness only, no build
./build.sh --preflight --ci --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18

# Production build with all validation stages + manifest
./build.sh --ci --validate --validate-artifact --manifest --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18

# Guided interactive build
scripts/build_wizard.sh
```

Useful `build.sh` flags: `--extensions none|all-qualified|csv-list`, `--source-image-uuid|--source-image-name|--source-image-uri` (override `images.json`), `--stage-source`, `--customization-profile NAME`, `--debug`, `--retain-failed-builder`.

Matrix test suites (`test.sh` fans out to `build.sh` per row; skips RHEL unless `--allow-rhel`; stops at first failure unless `--continue-on-error`):

```bash
./test.sh --include-ndb 2.10 --include-os "Rocky Linux" --validate --validate-artifact --manifest
./test.sh --include-db-type mongodb --validate --validate-artifact --manifest --max-parallel 1
```

Static gates (offline, run before claiming any change works):

```bash
bash -n build.sh test.sh scripts/*.sh
bash scripts/selftest.sh
scripts/matrix_validate.sh ndb/*/matrix.json
git diff --check
```

Live NDB E2E provisioning (serialized — never run two against the same NDB server; leaves NDB databases/profiles/VMs behind as evidence on success):

```bash
op run --env-file=.env -- scripts/ndb_e2e_validate.sh --dry-run --limit 3
op run --env-file=.env -- scripts/ndb_e2e_validate.sh --db-type pgsql --limit 1
op run --env-file=.env -- scripts/ndb_e2e_validate.sh --preflight-images   # Prism image preflight before full runs
```

Coverage + release onboarding:

```bash
scripts/live_coverage_audit.sh --suggest-runs ndb/2.9/matrix.json ndb/2.10/matrix.json
scripts/release_scaffold.sh 2.11 --from 2.10   # then human-review against new release notes
```

Other scripts: `artifact_validate.sh` (boots disposable VM from saved image — live), `source_image_ssh_probe.sh` (proves cloud-init SSH works on a source image — live), `prism_image_activate.sh` (adds cluster placement — live, dry-run by default), `rhel_readiness.sh` (RHEL env check), `manifest.sh` / `prism.sh` / `source_images.sh` / `postgres_extensions.sh` (sourced libraries).

## Architecture

Data-driven pipeline; the support matrix is the single source of truth:

```
ndb/<ver>/matrix.json row  →  build.sh (selection + ansible-vars JSON in /tmp)
  →  packer build packer/database.pkr.hcl (Nutanix plugin; cloud-init from packer/http/)
  →  ansible/<ver>/playbooks/site.yml roles:
       rhel_subscription → [pre_common hook] → common → [post_common hook]
       → postgresql|mongodb → validate_postgres|validate_mongodb
       → [post_database hook] → [validate hook] → image_prepare
  →  Prism image  →  optional artifact validation (disposable VM, offline-safe cloud-init)
  →  manifests/<image_name>.json (git-ignored; source of truth for what was built)
```

- **Matrix rows** (`ndb/2.9/matrix.json`, `ndb/2.10/matrix.json`): keyed by `db_type` + `os_type` + `os_version` + `db_version`. `ha_components` (Patroni/etcd/HAProxy/Keepalived versions) is an **install list, not documentation** — components are installed, validated, and reflected in the image name (`-ha` suffix) because NDB profile creation checks HA binaries even for single-instance databases. PostgreSQL rows carry `qualified_extensions` (empty requires `qualified_extensions_empty_reason`) and optional `postgres_package_version_prefix` patch pin (Debian/Ubuntu only — RHEL-family is never patch-pinned). MongoDB rows carry `mongodb_edition` and `deployment`.
- **NDB versions** are parallel trees (`ndb/<ver>/` + `ansible/<ver>/`), structurally identical; new versions are scaffolded with `release_scaffold.sh`, never hand-copied.
- **Source images** resolve via `images.json` (URL, or `env_var` indirection for licensed RHEL: `NDB_RHEL_9_6_IMAGE_URI`/`NDB_RHEL_9_7_IMAGE_URI`), overridable by UUID/name/URI flags. Public URLs rot: HEAD-check before trusting or editing `images.json` — Prism `ImageCreate ... 404` means bad source URL, not an Ansible problem.
- **Customization profiles** (`customizations/profiles/*.yml`; secrets-bearing ones in git-ignored `customizations/local/`) inject extra Ansible roles at the four hook phases above.
- **Image naming**: `ndb-<ndb>-<db_type>-<dbver>-<os>-<osver>[-ha][-pgX-Y][-ext-...]-<timestamp>`.
- `src/` and `package-lock.json` are vestigial; `logs/` is debug output; `source/` is read-only vendor docs.

## Behavioral constraints that are easy to get wrong

- Images must NOT boot with the packaged PostgreSQL/MongoDB service enabled or port 5432 bound — NDB owns the runtime; validation enforces inactive/disabled before capture.
- NDB APIs return `status=success` for the *dispatch*, not the operation. Always poll the returned `operationId` to terminal state, and read failed *step* messages, not just the top-level error. Diagnostic bundle downloads use the bundle response `workId`/`id`, not the operation ID.
- NDB E2E env vars are exactly `NDB_SERVER_ADDRESS`, `NDB_SERVER_USER`, `NDB_SERVER_PASSWORD` (no legacy variants). Keep generated NDB database names ≤ 28 chars.
- Artifact validation and E2E source VMs use offline-safe cloud-init on purpose: images must be self-contained at first boot; don't "fix" validation by installing packages during it.
- A successful manifest is not proof the Prism image still exists — preflight images before E2E.

`tasks/lessons.md` holds 50+ hard-won operational lessons (Debian/Ubuntu NDB target-clone PAM/SSH reset gating, device-mapper alias pitfalls, SELinux limits for MongoDB, diagnostic workflows). Read it at session start and before touching anything NDB-, PAM-, or storage-related; append new lessons after corrections. `tasks/todo.md` carries the running plan and current blocker state; `VALIDATION.md` defines validation layers and live coverage status. The README is the authoritative long-form reference for all command variants.
