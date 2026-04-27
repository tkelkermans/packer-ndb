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

### 3. Use The Guided Wizard

If you are new to the project, start with the single-image wizard:

```bash
scripts/build_wizard.sh
```

The wizard does not replace `build.sh`. It asks beginner-friendly questions, shows the selected matrix row, lets you choose PostgreSQL extensions one by one when the selected row is PostgreSQL, prints the exact `./build.sh --ci ...` command, and lets you either print the command or run it.

PostgreSQL extensions are optional. The wizard defaults to no extensions, shows which extensions are release-note-qualified for the selected row, and warns if you select an installable extension that is not release-note-qualified for this matrix row.

### 4. Run A Safe Dry Run

Dry-run mode does not start Packer and does not require live Prism credentials to be valid. It shows the selected matrix row, source image plan, generated Ansible variables, final Packer variables, and missing live-build prerequisites.

```bash
./build.sh --dry-run --ci --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18
```

For a MongoDB dry run, change `--db-type` and `--db-version`:

```bash
./build.sh --dry-run --ci --ndb-version 2.10 --db-type mongodb --os "Rocky Linux" --os-version 9.7 --db-version 8.0
```

### 5. Run A Production Build

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

Run every buildable PostgreSQL row that has installable release-note-qualified extensions and select those extensions automatically. This is the extension coverage command for the matrix. It includes RHEL rows, validates the temporary build VM, validates the saved artifact, writes manifests, and keeps going after failures so you get a complete report. Each background build runs with stdin isolated from the matrix reader so every selected row is tested.

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

Post-build artifact validation waits for required services to become active after SSH is reachable. This matters on first boot: SSH can be ready before `firewalld`, `chrony`, `cron`, PostgreSQL, or MongoDB have fully settled.

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

`build.sh` can use a source image in five ways:

- Remote URI: pass the URI directly to Packer.
- Local path: upload a local qcow2 file through Packer.
- Existing Prism image: pass `--source-image-name`.
- Existing Prism image UUID: pass `--source-image-uuid` when Prism has duplicate image names.
- Pre-staged Prism image: pass `--stage-source` first, then rerun with the staged image name if needed.

If a remote import is slow over VPN, staging or reusing an existing Prism image is usually faster and more reliable than asking Packer to import the remote URI every time.

If Prism has duplicate images with the same source-image name or URI, use the exact Prism image UUID:

```bash
./build.sh --ci --source-image-uuid "7a6d6c2f-90b4-4acb-bf14-6f2be1bf006e" --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18
```

## Customize The Image

Customization profiles are optional overlays for enterprise-specific tools, certificates, hardening, or validation checks. The committed `enterprise-example` profile is a safe starter that shows where profile settings live without requiring private repositories, tenant URLs, or secrets.

Start with a dry run so you can see the selected matrix row and planned customization inputs before any VM is created:

```bash
./build.sh --dry-run --ci --customization-profile enterprise-example --ndb-version 2.10 --db-type mongodb --os "Rocky Linux" --os-version 9.7 --db-version 8.0
```

When the dry run looks right, use the same profile with the normal production safety flags. This builds the image, runs in-guest validation, boots the saved artifact for final validation, and writes a manifest:

```bash
./build.sh --ci --customization-profile enterprise-example --validate --validate-artifact --manifest --ndb-version 2.10 --db-type mongodb --os "Rocky Linux" --os-version 9.7 --db-version 8.0
```

Profiles live in `customizations/profiles/` or `customizations/local/`. Use `customizations/examples/` as copyable reference material, then put real customer-specific profiles, private variables, and private roles under `customizations/local/`; that directory is ignored by git except for its README and `.gitkeep` so secrets and internal implementation details stay out of commits.

When a customization profile is selected, even a dry run validates the profile with `ansible-playbook` before printing the dry-run summary. This catches missing profile files, unsupported phase names, missing variable files, and missing custom role paths before a long image build starts.

During image builds, selected profiles can run roles before common setup, after common setup, after database installation, and during `--validate`. When `--validate-artifact` is also selected, the saved-image validation VM runs the profile's validation roles after the database validation. The example profile installs a sample internal CA, writes an OpenTelemetry Collector-style service shim, and applies one safe hardening marker so you can see the flow without adding private packages or secrets.

The committed examples use Ansible `become` for system paths and services, use OpenTelemetry Collector naming, and avoid secrets. Production profiles should include validation roles so every installed enterprise tool can be checked during build or artifact validation.

Common enterprise recipes:

- Install an internal CA certificate: copy `customizations/examples/internal-ca/roles/custom_internal_ca` into a private role, replace the generated sample certificate with your enterprise CA distribution method, and keep private CA material outside git.
- Install OpenTelemetry Collector monitoring: copy the monitoring-agent example, replace the marker service with your real OpenTelemetry Collector package, config, and service setup, and inject collector endpoints or tenant tokens from your secret manager at build time.
- Apply OS hardening: copy the hardening example, add one small validated setting at a time, and keep a matching validation task so the build proves the hardening actually landed.
- Validate custom work: keep a role like `validate_custom_enterprise` in the profile's `validate` phase so both `--validate` and `--validate-artifact` can prove the customization is present.

Do not commit real enterprise tokens, tenant URLs, private certificates, private keys, or customer-specific repository details. Put local-only profile files and private roles under `customizations/local/`, or load secrets from your organization's secret manager during the build.

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
- Injects the repo SSH key with cloud-init. By default this uses `packer/id_rsa.pub`; set `NDB_ARTIFACT_PUBLIC_KEY_PATH` only if you need a different validation public key.
- Connects as `packer` with `packer/id_rsa`. Set `NDB_ARTIFACT_PRIVATE_KEY_PATH` only if you need a different validation private key.
- Runs the matching validation role against the disposable VM: `validate_postgres` for PostgreSQL or `validate_mongodb` for MongoDB.
- Deletes the disposable VM after validation by default.

Add `--debug` to keep the validation VM on failure:

```bash
./build.sh --debug --ci --validate-artifact --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18
```

The validation role maps selected extension names to SQL extension names. For example, `pgvector` is validated as SQL extension `vector`. By default, every selected extension must be installable and must exist in PostgreSQL after provisioning. If a selected extension is not installable by the Ansible metadata, the build or artifact validation fails instead of silently skipping it.

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
- `customization`: selected customization profile, phase role names, and custom in-guest validation status.
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
|   |-- build_wizard.sh
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

The matrix file is the support contract for one NDB version. Each buildable PostgreSQL row should include release-note qualification metadata:

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
  "qualified_extensions": []
}
```

`qualified_extensions` records what Nutanix release notes qualify for that exact NDB version, OS version, PostgreSQL distribution, and PostgreSQL version. It is not an install list. PostgreSQL extension installation is a per-build choice through the wizard or `build.sh --extensions`.

For buildable PostgreSQL rows, an empty qualified extension list must be intentional. Add `qualified_extensions_empty_reason` so the validator can tell the difference between "the release notes do not qualify extensions for this exact row" and "we forgot to check the release notes":

```json
{
  "ndb_version": "2.10",
  "engine": "PostgreSQL Community Edition",
  "db_type": "pgsql",
  "os_type": "Rocky Linux",
  "os_version": "9.7",
  "db_version": "18",
  "provisioning_role": "postgresql",
  "qualified_extensions": [],
  "qualified_extensions_empty_reason": "Nutanix release notes do not list qualified PostgreSQL extensions for this exact OS and PostgreSQL version."
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
For buildable PostgreSQL rows, add release-note-qualified PostgreSQL extensions in qualified_extensions.
If Nutanix release notes do not list qualified extensions for the exact row, set qualified_extensions to [] and add a clear qualified_extensions_empty_reason.
Use provisioning_role=metadata for documentation-only rows and for database engines that are not buildable yet.
```

Always review the generated matrix manually against the release notes before building.

### PostgreSQL Extensions

PostgreSQL extensions are optional. The tool installs no extensions unless you select them.

For most DBA workflows, select only the extensions required by the application. Nutanix release notes list which extensions are qualified for specific OS and PostgreSQL combinations; this project stores that release-note metadata as `qualified_extensions` in each PostgreSQL matrix row.

The wizard is the easiest way to choose extensions for one image:

```bash
scripts/build_wizard.sh
```

Direct CLI users can pass a comma-separated list:

```bash
./build.sh --ci --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18 --extensions pgvector,postgis
```

Use `--extensions none` or omit `--extensions` to install no extensions. Use `--extensions all-qualified` only for coverage-style builds where you want every release-note-qualified extension that this project can install today.

When extensions are selected, the generated image name includes an `ext-...` suffix before the timestamp. This makes multiple images for the same NDB, OS, and PostgreSQL version easy to tell apart in Prism.

The build tool currently knows how to install and validate these PostgreSQL extensions:

- `pg_cron`
- `pglogical`
- `pg_partman`
- `pg_stat_statements`
- `pgvector`
- `pgaudit`
- `postgis`
- `set_user`
- `timescaledb`

If you choose an installable extension that is not listed as qualified for the selected row, the build continues and prints this warning:

```text
Extension <name> is installable by this tool, but is not release-note-qualified for this matrix row.
```

The role installs the matching packages for selected extensions and runs `CREATE EXTENSION IF NOT EXISTS ...` in the `postgres` database by default. Red Hat family systems use PGDG packages for these extensions. Ubuntu systems use PGDG for the PostgreSQL extension packages and add the official TimescaleDB packagecloud repository when `timescaledb` is requested, including the dearmored packagecloud keyring apt expects. Override target databases with `postgres_extensions_databases` if needed.

Package names are not always obvious. For example, Red Hat family systems use `pgaudit_16` and `timescaledb_16`, while Ubuntu uses `postgresql-16-pgaudit`, `postgresql-contrib-16`, and `timescaledb-2-postgresql-16`.

Requested extension skips fail by default. If you select an extension, the automation must install it and validation must find it in PostgreSQL.

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

PostgreSQL images with selected extensions add a readable extension suffix before the timestamp:

```text
ndb-<ndb_version>-pgsql-<db_version>-<os_type>-<os_version>-ext-<extensions>-<timestamp>
```

Example:

```text
ndb-2.10-pgsql-18-Rocky Linux-9.7-ext-pgvector-postgis-20260424000000
```

If many extensions are selected, the suffix keeps the first few extension names and adds a short checksum so the name stays shorter while still distinguishing the variant. The manifest remains the source of truth for the exact selected extension list.

### Multi-Engine Roadmap

`ndb/2.10/matrix.json` also tracks Oracle, SQL Server, MySQL, MariaDB, and MongoDB combinations from the NDB 2.10 release notes. PostgreSQL and selected MongoDB rows are buildable today. Oracle, SQL Server, MySQL, MariaDB, and any unsupported MongoDB combinations remain metadata-only.

To make another engine buildable, add matching Packer and Ansible roles, then change its matrix rows from `provisioning_role=metadata` to a real role such as `oracle` or `sqlserver`.
