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

Today, the build-ready rows are PostgreSQL Community Edition rows with `provisioning_role=postgresql`. Other matrix rows may exist as release-note metadata so the support list is documented, but `build.sh` will reject them until matching Packer/Ansible roles exist.

## Quick Start

### 1. Install The Local Tools

Install these commands on your workstation:

- `packer`
- `ansible-playbook`
- `jq`
- `curl`
- `ssh`
- `base64`

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

### 4. Run A Production Build

This is the recommended production command. It builds the image, validates during provisioning, validates the saved artifact in a disposable VM, and writes a manifest.

```bash
./build.sh --ci --validate --validate-artifact --manifest --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18
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

Run the Rocky Linux NDB 2.10 build suite with both validation stages and manifests. This is a live Prism build suite, not a local unit test; it can create several build VMs, disposable validation VMs, saved images, and manifest files.

```bash
./test.sh --include-ndb 2.10 --include-os "Rocky Linux" --validate --validate-artifact --manifest
```

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
- Runs the same `validate_postgres` role against the disposable VM.
- Deletes the disposable VM after validation by default.

Add `--debug` to keep the validation VM on failure:

```bash
./build.sh --debug --ci --validate-artifact --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18
```

The validation role maps matrix extension names to SQL extension names. For example, `pgvector` is validated as SQL extension `vector`, and extensions that are unsupported for the selected PostgreSQL version are not expected.

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
- `validation.in_guest`: in-guest validation status.
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

Use `provisioning_role=metadata` for combinations that should be documented but are not buildable yet.

### Matrix Drafting Prompt

You can use this prompt with a language model to draft a new matrix from release notes:

```text
Please create a JSON array of all possible build combinations from the provided markdown file. Each object must include ndb_version, engine, db_type, os_type, os_version, db_version, and provisioning_role. Add patroni_version, etcd_version, and ha_components when the release notes include HA component data. Use provisioning_role=postgresql only for combinations that are actually buildable by the current PostgreSQL pipeline, and use provisioning_role=metadata for documentation-only rows.
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

The role installs the matching PGDG packages and runs `CREATE EXTENSION IF NOT EXISTS ...` in the `postgres` database by default. Override target databases with `postgres_extensions_databases` if needed.

### Current PostgreSQL Coverage

- `packer/http/user-data` and the `common` role apply documented OS prerequisites.
- Rocky CRB is enabled before Red Hat package installation.
- EPEL is enabled when PostGIS is requested on Red Hat family systems.
- PostgreSQL contrib packages are installed unconditionally.
- `ansible/2.10` applies the Ubuntu 24.04 rsyslog AppArmor workaround from the NDB 2.10 known issues.

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

`ndb/2.10/matrix.json` also tracks Oracle, SQL Server, MySQL, MariaDB, and MongoDB combinations from the NDB 2.10 release notes.

To make those buildable, add matching Packer and Ansible roles, then change their matrix rows from `provisioning_role=metadata` to a real role such as `oracle` or `sqlserver`.
