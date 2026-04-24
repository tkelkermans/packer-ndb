# NDB Packer Image Builder

This project provides a CI/CD-oriented workflow for building Nutanix Database Services (NDB) images using HashiCorp Packer. The workflow is driven by a curated `matrix.json` file derived from the markdown release notes and validated before each build.

## Prerequisites

Before you begin, ensure you have the following installed:

- [HashiCorp Packer](https://www.packer.io/downloads)
- [jq](https://stedolan.github.io/jq/download/)
- `ansible-playbook` (Ansible Core)
- An SSH keypair in the `packer/` directory named `id_rsa` and `id_rsa.pub`. You can generate one with `ssh-keygen -t rsa -b 4096 -C "packer@nutanix" -f packer/id_rsa -N ""`

> ℹ️ Ansible output now relies on the built-in `default` callback (with `result_format=yaml`), and the Rocky CRB enablement no longer depends on the `community.general` collection.

## Project Structure

```
.
├── ansible
│   ├── 2.9/
│   └── 2.10/
├── build.sh
├── images.json
├── ndb
│   ├── 2.9
│   │   ├── matrix.json
│   │   └── ndb-2.9-pgsql.md
│   └── 2.10
│       ├── matrix.json
│       └── ndb-2.10-pgsql.md
├── packer
│   ├── database.pkr.hcl
│   ├── http/user-data
│   └── variables.pkr.hcl
├── README.md
├── scripts
│   ├── matrix_validate.sh
│   └── selftest.sh
├── source
└── test.sh
```

- **`build.sh`**: The master build script.
- **`images.json`**: Contains the source-image definitions for each supported OS/version. Entries may be direct URIs or environment-variable lookups for licensed artifacts such as RHEL.
- **`ndb/`**: Contains subdirectories for each NDB version, holding the markdown release notes and the `matrix.json` file.
- **`packer/`**: Contains the Packer HCL templates.
- **`ansible/`**: Contains version-specific playbooks, inventory, roles, and defaults used during provisioning.

## `matrix.json`

The `matrix.json` file is the core of this workflow. It defines both buildable and roadmap combinations for each NDB version. The file is still curated manually from the markdown release notes, but every build now validates it before provisioning begins.

### Structure

The `matrix.json` file is an array of JSON objects, where each object represents a unique buildable image configuration. Here is an example structure:

```json
[
  {
    "ndb_version": "2.10",
    "engine": "PostgreSQL Community Edition",
    "os_type": "Rocky Linux",
    "os_version": "9.6",
    "db_type": "pgsql",
    "db_version": "17",
    "provisioning_role": "postgresql",
    "patroni_version": "4.0.5",
    "etcd_version": "3.5.12",
    "ha_components": {
      "patroni": [
        "4.0.5"
      ],
      "etcd": [
        "3.5.12"
      ]
    },
    "extensions": [
      "pg_cron",
      "pglogical",
      "pg_partman",
      "pg_stat_statements",
      "pgvector",
      "pgaudit",
      "postgis",
      "set_user",
      "timescaledb"
    ]
  },
  {
    "ndb_version": "2.10",
    "engine": "PostgreSQL Community Edition",
    "os_type": "Red Hat Enterprise Linux (RHEL)",
    "os_version": "9.6",
    "db_type": "pgsql",
    "db_version": "17",
    "provisioning_role": "postgresql",
    "patroni_version": "4.0.5",
    "etcd_version": "3.5.12",
    "extensions": [
      "pg_cron",
      "pglogical",
      "pg_partman",
      "pg_stat_statements",
      "pgvector",
      "pgaudit",
      "postgis",
      "set_user",
      "timescaledb"
    ]
  }
]
```

If the `extensions` array is omitted, no PostgreSQL extensions are provisioned. When present, the list is forwarded to Ansible as `postgres_extensions` so that all packages are installed (via PGDG repositories) and `CREATE EXTENSION IF NOT EXISTS ...` is executed for every entry.

### Generation Prompt

You can use the following prompt with a large language model to draft the `matrix.json` from the markdown release notes:

"Please create a JSON array of all possible build combinations from the provided markdown file. Each object must include `ndb_version`, `engine`, `db_type`, `os_type`, `os_version`, `db_version`, and `provisioning_role`. Add `patroni_version`, `etcd_version`, and `ha_components` when the release notes include HA component data. Use `provisioning_role=postgresql` only for combinations that are actually buildable by the current PostgreSQL pipeline, and use `provisioning_role=metadata` for documentation-only rows."

## Environment Variables

The Packer build requires the following environment variables for connecting to Nutanix Prism Central:

You can bootstrap them from the tracked template file:

```bash
cp .env.example .env
source .env
```

```bash
export PKR_VAR_pc_username="<your_pc_username>"
export PKR_VAR_pc_password="<your_pc_password>"
export PKR_VAR_pc_ip="<your_pc_ip>"
export PKR_VAR_cluster_name="<your_cluster_name>"
export PKR_VAR_subnet_name="<your_subnet_name>"
export PKR_VAR_nutanix_insecure=true
```

RHEL source images are resolved differently because licensed download links are usually short-lived. Set the environment variable that matches the selected RHEL row before starting a build:

```bash
export NDB_RHEL_9_7_IMAGE_URI="/path/to/rhel-9.7.qcow2"
export NDB_RHEL_9_6_IMAGE_URI="/path/to/rhel-9.6.qcow2"
```

The template also includes the optional VM sizing overrides and `SKIP_MATRIX_VALIDATION` toggle that the current build/test scripts understand.

## How to Run

### Interactive Mode

To run the build in interactive mode, simply execute the `build.sh` script without any arguments:

```bash
./build.sh
```

The script prompts you to select the NDB version, database type (`db_type`), OS, OS version, and DB version from the buildable entries in `matrix.json`. A temporary Ansible vars file is generated on the fly and removed automatically when the build finishes, so you no longer need to maintain `ansible/vars.json` by hand.

Currently, only the `db_type=pgsql` entries with `provisioning_role=postgresql` are build-ready. Interactive mode only shows those buildable rows, while CI mode rejects metadata-only combinations explicitly.

### CI/CD Mode

To run the build in CI/CD mode, use the `--ci` flag and provide the desired build parameters:

```bash
./build.sh --ci --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18
```

The same transient Ansible vars file is produced in CI/CD mode, ensuring deterministic provisioning for each invocation. To inspect all available `db_type` values in the matrix, run for example:

```bash
jq -r '.[].db_type' ndb/2.10/matrix.json | sort -u
```

> ℹ️ Entries with `provisioning_role=metadata` (Oracle, SQL Server, MySQL, MongoDB, etc.) are informational only and do not yet have Packer/Ansible roles. `build.sh` rejects those combinations to avoid confusion.

If you need to override the source image for a one-off build, pass `--source-image-uri` with either a remote URI or a local qcow2 path:

```bash
./build.sh --ci --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18 --source-image-uri /tmp/custom-rocky-9.7.qcow2
```

To make the build fail if the provisioned VM does not match the selected matrix row, add `--validate`:

```bash
./build.sh --validate --ci --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18
```

To write a JSON manifest for a live build, add `--manifest`:

```bash
./build.sh --ci --validate --manifest --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18
```

Manifest files are written under `manifests/` with one JSON file per image name. These files are ignored by git, so they are safe to keep locally as build records without accidentally committing environment-specific output.

For a production build, run both validation stages and write a manifest:

```bash
./build.sh --ci --validate --validate-artifact --manifest --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18
```

### Dry Run Mode

To inspect the selected matrix row, resolved source-image plan, generated Ansible vars, and final Packer inputs without invoking Nutanix or Packer, use `--dry-run`:

```bash
./build.sh --dry-run --ci --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18
```

Dry-run mode does not require the Prism `PKR_VAR_*` environment variables, `packer`, `curl`, or the SSH public key to be present up front. Instead, it prints a readiness summary and explicitly lists any missing live-build prerequisites.

### Preflight and Source Image Staging

Before starting a long build, run a live preflight check. This contacts Prism, verifies the configured cluster and subnet, and checks that the selected source image plan is ready, but it does not start Packer:

```bash
./build.sh --preflight --ci --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18
```

If your selected source image is a remote URI, you can stage it into Prism first. This is useful when a remote image import may take a long time:

```bash
./build.sh --stage-source --ci --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18
```

`--stage-source` is only for remote source image URIs. Local qcow2 file paths still go through Packer's local upload path.

If the source image is already present in Prism, point the build at that image by name:

```bash
./build.sh --ci --source-image-name "Rocky-9-GenericCloud-LVM-9.7-20251123.2.x86_64.qcow2" --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18
```

## In-Guest Validation

When `--validate` is enabled, the `validate_postgres` role runs after provisioning and fails the build if the VM does not satisfy the expected PostgreSQL/NDB baseline. The current validation pass checks:

- `firewalld`, `chrony`, `cron`, and PostgreSQL services are active and enabled.
- The PostgreSQL client and server versions match the selected `db_version`.
- The NDB sudoers drop-in exists and the full sudoers configuration passes `visudo`.
- Every PostgreSQL extension that is expected to be created for the selected platform/version exists in the target databases.

This is an in-guest validation pass during provisioning.

## Artifact Validation

When `--validate-artifact` is enabled, `build.sh` waits for Packer to save the image, finds the saved image in Prism, and boots a fresh disposable VM from that image. It then connects over SSH with the repo key in `packer/id_rsa`, runs the `validate_postgres` role against the disposable VM, and removes the VM after validation.

If artifact validation fails, the disposable VM is still removed by default. Add `--debug` to keep the validation VM on failure so you can inspect it in Prism.

### Debug Mode

To run the build in debug mode, use the `--debug` flag. This will produce a detailed Packer log file and, in case of an error, will leave the temporary VM running so you can inspect it.

```bash
./build.sh --debug
```

The script will find the matching configuration in the `matrix.json` and proceed with the build non-interactively.

### Troubleshooting Prism Tasks

Long-running Prism operations, such as image imports and VM power or delete actions, print the Prism task UUID they are waiting on. If a build appears stuck or fails during one of those steps, copy that UUID and search for it in Prism Central's task view. The task details usually show the current progress and any Prism-side error message.

## Image Naming Convention

`ndb-<ndb_version>-<db_type>-<db_version>-<os_type>-<os_version>-<timestamp>`

For example:

`ndb-2.10-pgsql-18-Rocky-Linux-9.7-20240101120000`

## Automated Tests

The project includes a test script that iterates through the buildable combinations defined in the `matrix.json` files and runs a full Packer build for each one. This is a comprehensive end-to-end test to ensure that supported configurations keep working.

To run the tests, execute the `test.sh` script:

```bash
./test.sh
```

You can fine-tune the suite with the following options:

```bash
# Only test Rocky builds and run 3 builds in parallel
./test.sh --include-os "Rocky Linux" --max-parallel 3

# Run the same suite with in-guest validation enabled for each build
./test.sh --include-os "Rocky Linux" --max-parallel 3 --validate

# Run both validation stages and write manifests for each build
./test.sh --include-os "Rocky Linux" --max-parallel 3 --validate --validate-artifact --manifest
```

Use `./test.sh --help` for the complete list of filters (include/exclude OS, include NDB versions, control concurrency).

Before launching any build, `build.sh` validates the selected matrix file and `test.sh` validates every discovered `ndb/*/matrix.json`. The validator ensures required fields are non-empty strings, `ndb_version` matches the directory name, extensions are well formed, versions no longer contain `/`, and `ha_components` blocks are structurally valid. You can run it manually with:

```bash
scripts/matrix_validate.sh ndb/*/matrix.json
```

Matrix validation uses shell and `jq`; Python is not required to operate this tool.

## PostgreSQL Extensions

The Ansible `postgres` role can install and enable the extensions called out in `source/NDB-2.9-postgreSQL-documentation.md` (`pg_cron`, `pglogical`, `pg_partman`, `pg_stat_statements`, `pgvector`, `pgaudit`, `postgis`, `set_user`, `timescaledb`). Declare the desired list per build entry by adding an `extensions` array to `matrix.json` (as shown above). These values populate the `postgres_extensions` variable, which installs the matching PGDG packages and issues `CREATE EXTENSION IF NOT EXISTS ...` in the `postgres` database by default. You can override the target databases via `postgres_extensions_databases`.

Builds where the `extensions` array is omitted (or empty) leave the core PostgreSQL installation untouched: no extension packages are installed and Ansible simply logs that the step was skipped.

## Current PostgreSQL Prerequisites Coverage

- `packer/http/user-data` and the `common` Ansible role now apply the documented OS prerequisites automatically (firewalld + chrony on every OS, UFW removal on Debian/Ubuntu, sudo secure paths, drop-in sudoers policy for the NDB drive user, and chrony/firewalld services enabled).
- The `postgres` role installs the contrib package unconditionally and can provision the NDB-qualified extensions through the `postgres_extensions` variable.
- `ansible/2.10` also applies the Ubuntu 24.04 rsyslog AppArmor workaround called out in the NDB 2.10 known issues, so PostgreSQL 18 images can be built from that base image without manual prep.
- Additional tunables (`ndb_drive_user`, `configure_ndb_sudoers`, `postgres_extensions`, etc.) can be supplied via `matrix.json` or overridden inside Ansible to accommodate custom scenarios.

## Source Image Resolution

`images.json` supports two entry styles:

- A direct string URI for public images, for example Rocky Linux or Ubuntu cloud images.
- An object with `env_var` and optional `prefetch` for artifacts that should not be committed as long-lived URLs. This is the default pattern for RHEL.

When `prefetch` is `true`, `build.sh` downloads the source image to a local temporary file before invoking Packer. This avoids relying on short-lived remote links during the actual Nutanix image import step.

## Customizing Build Resources

The default Nutanix VM launched by Packer uses 2 vCPUs, 4 GiB RAM, and a 40 GiB disk. You can override these defaults via environment variables:

```bash
export PKR_VAR_vm_cpu=4
export PKR_VAR_vm_memory_mb=8192
export PKR_VAR_vm_disk_size_gb=80
```

This allows you to adapt image builds to heavier workloads without modifying the HCL templates.

## Multi-engine roadmap

`ndb/2.10/matrix.json` also tracks the Oracle, SQL Server, MySQL/MariaDB and MongoDB combinations listed in the NDB 2.10 release notes. Each entry exposes:

- `db_type` / `engine` to distinguish each family
- `provisioning_role`, currently `postgresql` for build-ready configurations and `metadata` for documentary rows
- optional `ha_components` (Patroni/etcd/HAProxy/Keepalived versions) and `deployment` hints (single-instance, AG, FCI, etc.)

To make additional engines buildable, add the corresponding Packer/Ansible roles and flip `provisioning_role` to something meaningful (for example `oracle`, `sqlserver`). The matrix validator already enforces the structure of these new fields, which makes extending the pipeline safe.
