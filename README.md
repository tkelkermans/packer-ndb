# NDB Packer Image Builder

## What This Tool Does

This repository builds Nutanix Database Service (NDB) image artifacts with Packer, Ansible, Terraform-backed Packer plugins, and shell scripts.

The normal workflow is:

- Choose one supported row from an NDB `matrix.json` file.
- Resolve the matching operating-system source image from `images.json`.
- Build a Prism image with Packer.
- Optionally validate the temporary build VM before Packer saves the image.
- Optionally boot the saved image as a disposable VM and validate the final artifact.
- Optionally write a JSON manifest under `manifests/` so the build can be audited later.

Today, the build-ready rows are PostgreSQL Community Edition rows with `provisioning_role=postgresql` and MongoDB rows with `provisioning_role=mongodb`. Other database engines can still appear as `provisioning_role=metadata` rows so the support list is documented, but `build.sh` rejects metadata-only rows until matching Packer/Ansible roles exist.

## Quick Start

### 1. Install The Local Tools

Install these commands on your workstation:

- `packer`
- `ansible-playbook`
- `jq`
- `curl`
- `ssh`
- `base64`

For long live validation runs, prefer `ansible-core` 2.18.x. Newer Ansible controller versions can fail on some targets with module result deserialization errors before the build reaches extension validation. A temporary local runtime is enough:

```bash
python3.11 -m venv /tmp/ndb-ansible-2.18
/tmp/ndb-ansible-2.18/bin/python -m pip install 'ansible-core>=2.18,<2.19'
export PATH="/tmp/ndb-ansible-2.18/bin:$PATH"
```

The build also needs an SSH keypair in `packer/id_rsa` and `packer/id_rsa.pub`. If you need to create one:

```bash
ssh-keygen -t rsa -b 4096 -C "packer@nutanix" -f packer/id_rsa -N ""
```

Initialize the Packer plugins once on a new workstation:

```bash
packer init packer/
```

### 2. Create Your Environment File

Copy the template and edit `.env` with your Prism Central details:

```bash
cp .env.example .env
source .env
```

### 3. Run A Safe Dry Run

Dry-run mode does not start Packer and does not require live Prism credentials to be valid. It shows the selected matrix row, source image plan, generated Ansible variables, final Packer variables, and missing live-build prerequisites.

```bash
./build.sh --dry-run --ci --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18
```

For a MongoDB dry run, change `--db-type` and `--db-version`:

```bash
./build.sh --dry-run --ci --ndb-version 2.10 --db-type mongodb --os "Rocky Linux" --os-version 9.7 --db-version 8.0
```

### 4. Run A Production Build

This is the recommended PostgreSQL production command. It builds the image, validates during provisioning, validates the saved artifact in a disposable VM, and writes a manifest.

```bash
./build.sh --ci --validate --validate-artifact --manifest --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18
```

This is the same production flow for one MongoDB row:

```bash
./build.sh --ci --validate --validate-artifact --manifest --ndb-version 2.10 --db-type mongodb --os "Rocky Linux" --os-version 9.7 --db-version 8.0
```

## Common Commands

Validate every matrix file before you trust a new release edit:

```bash
scripts/matrix_validate.sh ndb/*/matrix.json
```

Check Prism readiness and source-image readiness without starting Packer:

```bash
./build.sh --preflight --ci --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18
```

Stage a remote source image into Prism before the long build starts:

```bash
./build.sh --stage-source --ci --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18
```

Reuse a source image that is already present in Prism:

```bash
./build.sh --ci --source-image-name "Rocky-9-GenericCloud-LVM-9.7-20251123.2.x86_64.qcow2" --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18
```

Run the Rocky Linux NDB 2.10 build suite with both validation stages and manifests. This is a live Prism build suite, not a local unit test; it can create several build VMs, disposable validation VMs, saved images, and manifest files. If one parallel build fails, `test.sh` stops launching new builds, waits for already-started builds to finish, and then exits with a failure.

```bash
./test.sh --include-ndb 2.10 --include-os "Rocky Linux" --validate --validate-artifact --manifest
```

Run the MongoDB live suite with both validation stages and manifests. Keep `--max-parallel 1` while validating MongoDB topology rows so each temporary local smoke test has the host to itself.

```bash
./test.sh --include-db-type mongodb --validate --validate-artifact --manifest --max-parallel 1
```

If you use 1Password to provide `.env`, wrap the same MongoDB suite command with `op run`:

```bash
op run --env-file .env -- ./test.sh --include-db-type mongodb --validate --validate-artifact --manifest --max-parallel 1
```

`test.sh` skips RHEL rows unless you add `--allow-rhel`. Only add it after the licensed RHEL source image environment variables are set.

Run every buildable PostgreSQL row that requests extension installation. This is the full extension coverage command for the matrix. It includes RHEL rows, validates the temporary build VM, validates the saved artifact, writes manifests, and keeps going after failures so you get a complete report. Each background build runs with stdin isolated from the matrix reader so every selected row is tested.

```bash
./test.sh --extensions-only --continue-on-error --allow-rhel --validate --validate-artifact --manifest --max-parallel 1
```

If you use 1Password to provide `.env`, wrap the same command with `op run`:

```bash
op run --env-file .env -- ./test.sh --extensions-only --continue-on-error --allow-rhel --validate --validate-artifact --manifest --max-parallel 1
```

Failed Packer builder VMs are deleted automatically. Add `--debug` to `build.sh` only when you intentionally want to keep a failed builder VM for troubleshooting.

Ubuntu images can start background package work just after boot. The Ansible roles wait for apt/dpkg locks on Debian-family package tasks, so transient first-boot apt activity should slow a build down instead of failing it immediately.

At the end of every build, the final image preparation role resets cloud-init state before Packer captures the image. On Ubuntu it also removes the generated cloud-init netplan file so a VM cloned from the saved image can regenerate first-boot networking and accept the validation SSH key.

Post-build artifact validation waits for required services to become active after SSH is reachable. This matters on first boot: SSH can be ready before `firewalld`, `chrony`, `cron`, or PostgreSQL have fully settled.

Show interactive prompts for buildable matrix rows:

```bash
./build.sh
```

List available `db_type` values for one NDB version:

```bash
jq -r '.[].db_type' ndb/2.10/matrix.json | sort -u
```

Run the local shell self-tests:

```bash
bash scripts/selftest.sh
```

Run the core offline verification checks before handing off changes:

```bash
bash -n build.sh test.sh scripts/*.sh
bash scripts/selftest.sh
scripts/matrix_validate.sh ndb/*/matrix.json
packer fmt -check packer
```

## What Happens During A Build

`build.sh` performs these steps in order:

1. Reads your selected `ndb/<version>/matrix.json`.
2. Rejects combinations that are not currently buildable.
3. Validates the matrix unless `SKIP_MATRIX_VALIDATION=true`.
4. Resolves a source image from `images.json` or from `--source-image-uri` / `--source-image-name`.
5. Generates a temporary Ansible vars file for the selected row.
6. Runs Packer against `packer/database.pkr.hcl`.
7. If `--validate` is set, runs in-guest validation before the image is saved.
8. Resolves the saved image UUID in Prism after Packer succeeds.
9. If `--validate-artifact` is set, boots a disposable VM from the saved image and validates the final artifact.
10. If `--manifest` is set, writes a JSON manifest under `manifests/`.

Temporary files are removed automatically. Manifests are ignored by git because they contain environment-specific build records.

## Environment Variables

The easiest setup is:

```bash
cp .env.example .env
source .env
```

The important Prism variables are:

```bash
export PKR_VAR_pc_username="<your-prism-username>"
export PKR_VAR_pc_password="<your-prism-password>"
export PKR_VAR_pc_ip="<your-prism-central-ip-or-hostname>"
export PKR_VAR_cluster_name="<your-cluster-name>"
export PKR_VAR_subnet_name="<your-subnet-name>"
export PKR_VAR_nutanix_insecure="true"
```

Optional build VM sizing overrides:

```bash
export PKR_VAR_vm_cpu="2"
export PKR_VAR_vm_memory_mb="4096"
export PKR_VAR_vm_disk_size_gb="40"
```

Optional licensed RHEL source image overrides:

```bash
export NDB_RHEL_9_7_IMAGE_URI="/path/to/rhel-9.7.qcow2"
export NDB_RHEL_9_6_IMAGE_URI="/path/to/rhel-9.6.qcow2"
```

If you use 1Password to provide `.env`, check that required values resolve as non-empty before launching a long RHEL run:

```bash
op run --env-file .env -- bash -lc 'if [ -n "${NDB_RHEL_9_6_IMAGE_URI:-}" ]; then echo "RHEL 9.6 image is configured"; else echo "RHEL 9.6 image is missing"; fi'
```

Leave matrix validation enabled unless you are deliberately debugging the validator:

```bash
export SKIP_MATRIX_VALIDATION="false"
```

## Source Images

Source images are defined in `images.json`.

Each entry can be:

- A direct URI, usually for public Rocky Linux or Ubuntu cloud images.
- An object with `env_var` for licensed or short-lived downloads such as RHEL images.
- An object with `prefetch: true` when the image should be downloaded locally before Packer starts.

`build.sh` can use a source image in four ways:

- Remote URI: pass the URI directly to Packer.
- Local path: upload a local qcow2 file through Packer.
- Existing Prism image: pass `--source-image-name`.
- Pre-staged Prism image: pass `--stage-source` first, then rerun with the staged image name if needed.

If a remote import is slow over VPN, staging or reusing an existing Prism image is usually faster and more reliable than asking Packer to import the remote URI every time.

## Validation

### In-Guest Validation

Use `--validate` to check the temporary build VM before Packer saves the image:

```bash
./build.sh --ci --validate --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18
```

The `validate_postgres` role checks:

- `firewalld`, `chrony`, `cron`, and PostgreSQL services are active and enabled.
- PostgreSQL client and server versions match the selected `db_version`.
- The NDB sudoers drop-in exists and the full sudoers configuration passes `visudo`.
- Expected PostgreSQL extensions exist in the target databases.

For MongoDB rows, `--validate` runs `validate_mongodb` instead:

- Single-instance validation checks that `mongod` is installed, enabled, running, reachable through `mongosh`, on the selected version, and on the selected edition.
- Rows with `replica-set` in `deployment` run a temporary local replica-set smoke test and clean it up afterward.
- Rows with `sharded-cluster` in `deployment` run a temporary local sharded topology smoke test with `mongod` and `mongos`, add one shard, verify it is present, and clean it up afterward.
- `mongodb_edition=enterprise` rows install and validate MongoDB Enterprise packages. NDB 2.10 sharded-cluster readiness uses Enterprise packages because the release notes list sharded MongoDB as Enterprise-only.

### Artifact Validation

Use `--validate-artifact` to validate the saved Prism image:

```bash
./build.sh --ci --validate-artifact --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18
```

Artifact validation:

- Finds the saved image in Prism.
- Boots a disposable `validate-...` VM from that image.
- Injects the repo SSH key with cloud-init.
- Connects as `packer` with `packer/id_rsa`.
- Runs the matching validation role against the disposable VM: `validate_postgres` for PostgreSQL or `validate_mongodb` for MongoDB.
- Deletes the disposable VM after validation by default.

Add `--debug` to keep the validation VM on failure:

```bash
./build.sh --debug --ci --validate-artifact --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18
```

The validation role maps matrix extension names to SQL extension names. For example, `pgvector` is validated as SQL extension `vector`. By default, every extension listed in a buildable matrix row must be installable and must exist in PostgreSQL after provisioning. If a listed extension is marked unsupported by the Ansible metadata, the build or artifact validation fails instead of silently skipping it.

## Manifests

Add `--manifest` to write a build record:

```bash
./build.sh --ci --validate --validate-artifact --manifest --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18
```

Manifest files are written under `manifests/` and are ignored by git.

Useful fields:

- `status`: final build status, usually `success` or `failed`.
- `selection`: the matrix selection used for the build.
- `source_image`: whether the source came from a remote URI, local path, staged image, or existing Prism image.
- `packer.started_at`, `packer.finished_at`, `packer.duration_seconds`: the Packer phase only.
- `artifact.image_name`, `artifact.image_uuid`: the saved Prism image.
- `validation.in_guest`: in-guest validation status, such as `not-requested`, `running`, `passed`, or `failed`.
- `validation.artifact`: final artifact validation status.
- `cleanup.artifact_validation_vm`: whether the disposable validation VM was deleted, retained, or cleanup failed.

If artifact validation succeeds but the validation VM cannot be deleted, the build fails instead of hiding a leaked VM.

## Release Onboarding

When Nutanix publishes a new NDB release, scaffold it from the previous supported release:

```bash
scripts/release_scaffold.sh 2.11 --from 2.10
```

The scaffold:

- Copies `ndb/2.10` to `ndb/2.11`.
- Copies `ansible/2.10` to `ansible/2.11`.
- Rewrites `ndb_version` values in the copied matrix.
- Creates `ndb/2.11/REVIEW.md`.
- Runs matrix validation and Ansible syntax checks.

This is only a starting point. You must still compare the copied matrix with the new release notes before building.

After editing the new matrix, run:

```bash
scripts/matrix_validate.sh ndb/2.11/matrix.json
ANSIBLE_CONFIG=ansible/2.11/ansible.cfg ansible-playbook -i ansible/2.11/inventory/hosts ansible/2.11/playbooks/site.yml --syntax-check
```

Preview the scaffold without creating files:

```bash
scripts/release_scaffold.sh 2.11 --from 2.10 --dry-run
```

## Troubleshooting

### Source image import timed out

The Prism import may still be running even after Packer gives up. Find the task UUID in the output, wait for it to finish in Prism, then rerun the build with `--source-image-name`.

Example:

```bash
./build.sh --ci --source-image-name "Rocky-9-GenericCloud-LVM-9.7-20251123.2.x86_64.qcow2" --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18
```

### Artifact validation cannot SSH

The validation helper forces the repo key and disables the local SSH agent. Confirm the validation VM has an IP, then rerun with debug retention if inspection is needed.

```bash
./build.sh --debug --ci --validate-artifact --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18
```

### A validation VM was left behind

The failed command prints the VM name and UUID. Delete it from Prism after inspection.

If a manifest was written, also check `cleanup.artifact_validation_vm`:

- `kept-on-failure`: expected when `--debug` keeps the VM after failure.
- `delete-request-failed`: Prism rejected the delete request.
- `delete-task-failed`: Prism accepted the delete request, but the task failed.
- `result-unavailable`: artifact validation did not write usable result JSON.

### Manifest status is `failed`

A failed manifest means the build exited before every requested stage completed. Check these sections:

- `packer`: Packer timing and whether the image build finished.
- `validation`: in-guest and artifact validation status.
- `cleanup`: cleanup status for disposable validation VMs.

### Prism task appears stuck

Long-running Prism operations print task UUIDs. Search for the UUID in Prism Central's task view to see Prism-side progress or errors.

### RHEL source image is missing

RHEL downloads are licensed and often short-lived. Set the matching environment variable before building:

```bash
export NDB_RHEL_9_7_IMAGE_URI="/path/to/rhel-9.7.qcow2"
export NDB_RHEL_9_6_IMAGE_URI="/path/to/rhel-9.6.qcow2"
```

## Reference

### Project Structure

```text
.
|-- ansible/
|   |-- 2.9/
|   `-- 2.10/
|-- build.sh
|-- images.json
|-- manifests/
|-- ndb/
|   |-- 2.9/
|   `-- 2.10/
|-- packer/
|   |-- database.pkr.hcl
|   |-- http/user-data
|   `-- variables.pkr.hcl
|-- scripts/
|   |-- artifact_validate.sh
|   |-- manifest.sh
|   |-- matrix_validate.sh
|   |-- prism.sh
|   |-- release_scaffold.sh
|   |-- selftest.sh
|   `-- source_images.sh
|-- source/
|-- tasks/
`-- test.sh
```

### Matrix Files

The matrix file is the support contract for one NDB version. Each buildable PostgreSQL row should include:

```json
{
  "ndb_version": "2.10",
  "engine": "PostgreSQL Community Edition",
  "db_type": "pgsql",
  "os_type": "Rocky Linux",
  "os_version": "9.7",
  "db_version": "18",
  "provisioning_role": "postgresql",
  "patroni_version": "4.0.5",
  "etcd_version": "3.5.12",
  "ha_components": {
    "patroni": ["4.0.5"],
    "etcd": ["3.5.12"],
    "haproxy": ["2.8.9"],
    "keepalived": ["2.2.8"]
  },
  "extensions": ["pg_stat_statements", "pgvector"]
}
```

If `extensions` is omitted or empty, the PostgreSQL role does not install extension packages or create extensions.

For buildable PostgreSQL rows, an empty extension list must be intentional. Add `extensions_empty_reason` so the validator can tell the difference between "we checked and chose none" and "we forgot to add extension coverage":

```json
{
  "ndb_version": "2.10",
  "engine": "PostgreSQL Community Edition",
  "db_type": "pgsql",
  "os_type": "Rocky Linux",
  "os_version": "9.7",
  "db_version": "18",
  "provisioning_role": "postgresql",
  "extensions": [],
  "extensions_empty_reason": "Extension package coverage is pending for this newly supported OS or PostgreSQL combination."
}
```

Each buildable MongoDB row should include `mongodb_edition` and `deployment`:

```json
{
  "ndb_version": "2.10",
  "engine": "MongoDB",
  "db_type": "mongodb",
  "os_type": "Rocky Linux",
  "os_version": "9.7",
  "db_version": "8.0",
  "provisioning_role": "mongodb",
  "mongodb_edition": "community",
  "deployment": ["single-instance", "replica-set"]
}
```

Use `mongodb_edition=community` for Community packages and `mongodb_edition=enterprise` for Enterprise packages. Use `deployment` to list the MongoDB shapes the row must prove during validation:

- `single-instance`: validates the installed `mongod` service, MongoDB version, and edition.
- `replica-set`: also runs a temporary local replica-set smoke test.
- `sharded-cluster`: also runs a temporary local sharded topology smoke test.

For NDB 2.10, sharded MongoDB rows are Enterprise rows because the release notes list sharded MongoDB as Enterprise-only. If a release note combination is useful to document but is not buildable yet, keep it as `provisioning_role=metadata`.

### Matrix Drafting Prompt

You can use this prompt with a language model to draft a new matrix from release notes:

```text
Please create a JSON array of all possible build combinations from the provided markdown file.
Each object must include ndb_version, engine, db_type, os_type, os_version, db_version, and provisioning_role.
Add patroni_version, etcd_version, and ha_components when the release notes include PostgreSQL HA component data.
Use provisioning_role=postgresql only for combinations that are actually buildable by the current PostgreSQL pipeline.
Use provisioning_role=mongodb only for combinations that are actually buildable by the current MongoDB pipeline, and include mongodb_edition plus deployment metadata for those rows.
For buildable PostgreSQL rows, add the qualified PostgreSQL extensions in extensions.
If a buildable PostgreSQL row intentionally has no extension coverage yet, set extensions to [] and add a clear extensions_empty_reason.
Use provisioning_role=metadata for documentation-only rows and for database engines that are not buildable yet.
```

Always review the generated matrix manually against the release notes before building.

### PostgreSQL Extensions

The PostgreSQL role can install and enable these NDB-qualified extensions when they are listed in a matrix row:

- `pg_cron`
- `pglogical`
- `pg_partman`
- `pg_stat_statements`
- `pgvector`
- `pgaudit`
- `postgis`
- `set_user`
- `timescaledb`

The role installs the matching packages and runs `CREATE EXTENSION IF NOT EXISTS ...` in the `postgres` database by default. Red Hat family systems use PGDG packages for these extensions. Ubuntu systems use PGDG for the PostgreSQL extension packages and add the official TimescaleDB packagecloud repository when `timescaledb` is requested, including the dearmored packagecloud keyring apt expects. Override target databases with `postgres_extensions_databases` if needed.

Package names are not always obvious. For example, Red Hat family systems use `pgaudit_16` and `timescaledb_16`, while Ubuntu uses `postgresql-16-pgaudit`, `postgresql-contrib-16`, and `timescaledb-2-postgresql-16`.

Requested extension skips fail by default. This keeps the matrix honest: if an extension is listed in a buildable row, the automation must install it and validation must find it in PostgreSQL.

The matrix validator fails buildable PostgreSQL rows that have no extension list unless `extensions_empty_reason` is present. This keeps extension gaps visible before a long Packer run starts.

### Current PostgreSQL Coverage

- `packer/http/user-data` and the `common` role apply documented OS prerequisites.
- Rocky CRB is enabled before Red Hat package installation.
- EPEL is enabled when PostGIS is requested on Red Hat family systems.
- PostgreSQL contrib packages are installed unconditionally.
- `ansible/2.10` applies the Ubuntu 24.04 rsyslog AppArmor workaround from the NDB 2.10 known issues.

### Current MongoDB Coverage

- MongoDB rows install Community or Enterprise packages based on `mongodb_edition`.
- Validation checks the running service, server version, selected edition, and any requested local replica-set or sharded topology smoke tests.
- Red Hat and Rocky MongoDB builds install MongoDB's pinned SELinux policy source for default RPM layouts. This can be slow because the build needs GitHub access while Ansible clones the pinned `mongodb/mongodb-selinux` source and installs the policy.

### Image Naming

Images use this pattern:

```text
ndb-<ndb_version>-<db_type>-<db_version>-<os_type>-<os_version>-<timestamp>
```

Example:

```text
ndb-2.10-pgsql-18-Rocky Linux-9.7-20260424000000
```

### Multi-Engine Roadmap

`ndb/2.10/matrix.json` also tracks Oracle, SQL Server, MySQL, MariaDB, and MongoDB combinations from the NDB 2.10 release notes. PostgreSQL and selected MongoDB rows are buildable today. Oracle, SQL Server, MySQL, MariaDB, and any unsupported MongoDB combinations remain metadata-only.

To make another engine buildable, add matching Packer and Ansible roles, then change its matrix rows from `provisioning_role=metadata` to a real role such as `oracle` or `sqlserver`.
