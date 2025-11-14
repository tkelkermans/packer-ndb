# NDB Packer Image Builder

This project provides a CI/CD-ready solution for building Nutanix Database Services (NDB) images using HashiCorp Packer. The workflow is dynamically driven by a manually created `matrix.json` file that is based on the markdown-based release notes.

## Prerequisites

Before you begin, ensure you have the following installed:

- [HashiCorp Packer](https://www.packer.io/downloads)
- [jq](https://stedolan.github.io/jq/download/)
- An SSH keypair in the `packer/` directory named `id_rsa` and `id_rsa.pub`. You can generate one with `ssh-keygen -t rsa -b 4096 -C "packer@nutanix" -f packer/id_rsa -N ""`

## Project Structure

```
.
├── build.sh
├── images.json
├── ndb
│   ├── 2.9
│   │   ├── matrix.json
│   │   └── ndb-2.9-pgsql.md
│   └── 3.0
├── packer
│   ├── database.pkr.hcl
│   └── variables.pkr.hcl
├── README.md
└── scripts
    ├── common_setup.sh
    └── install_postgres.sh
```

- **`build.sh`**: The master build script.
- **`images.json`**: Contains the URLs for the OS images.
- **`ndb/`**: Contains subdirectories for each NDB version, holding the markdown release notes and the `matrix.json` file.
- **`packer/`**: Contains the Packer HCL templates.
- **The `ansible/` directory contains version-specific subdirectories for each NDB version, holding the Ansible playbooks, inventory, and configuration.**: Contains provisioning scripts.

## `matrix.json`

The `matrix.json` file is the core of this workflow. It defines all the possible build combinations. This file must be created manually for each NDB version based on the information in the markdown release notes.

### Structure

The `matrix.json` file is an array of JSON objects, where each object represents a unique buildable image configuration. Here is an example structure:

```json
[
  {
    "ndb_version": "2.9",
    "os_type": "Rocky Linux",
    "os_version": "9.6",
    "db_type": "pgsql",
    "db_version": "17",
    "patroni_version": "4.0.5/ 3.2.2",
    "etcd_version": "3.5.12"
  },
  {
    "ndb_version": "2.9",
    "os_type": "Red Hat Enterprise Linux (RHEL)",
    "os_version": "9.6",
    "db_type": "pgsql",
    "db_version": "17",
    "patroni_version": "*4.0.5/ 3.3.2",
    "etcd_version": "3.5.12"
  }
]
```

### Generation Prompt

You can use the following prompt with a large language model to generate the `matrix.json` from the markdown release notes:

"Please create a JSON array of all possible build combinations from the provided markdown file. The JSON objects should have the following keys: `ndb_version`, `os_type`, `os_version`, `db_type`, `db_version`, `patroni_version`, and `etcd_version`. The `ndb_version` should be set to '2.9', and the `db_type` should be 'pgsql'. Correlate the data from the OS/DB compatibility table with the software dependency table."

## Environment Variables

The Packer build requires the following environment variables for connecting to Nutanix Prism Central:

```bash
export PKR_VAR_pc_username="<your_pc_username>"
export PKR_VAR_pc_password="<your_pc_password>"
export PKR_VAR_pc_ip="<your_pc_ip>"
export PKR_VAR_cluster_name="<your_cluster_name>"
export PKR_VAR_subnet_name="<your_subnet_name>"
export PKR_VAR_nutanix_insecure=true
```

## How to Run

### Interactive Mode

To run the build in interactive mode, simply execute the `build.sh` script without any arguments:

```bash
./build.sh
```

The script will prompt you to select the NDB version, OS, OS version, and DB version from the `matrix.json` file.

### CI/CD Mode

To run the build in CI/CD mode, use the `--ci` flag and provide the desired build parameters:

```bash
./build.sh --ci --ndb-version 2.9 --os "Rocky Linux" --os-version 9.6 --db-version 17
```

### Debug Mode

To run the build in debug mode, use the `--debug` flag. This will produce a detailed Packer log file and, in case of an error, will leave the temporary VM running so you can inspect it.

```bash
./build.sh --debug
```

The script will find the matching configuration in the `matrix.json` and proceed with the build non-interactively.

## Image Naming Convention

`ndb-<ndb_version>-<db_type>-<db_version>-<os_type>-<os_version>-<timestamp>`

For example:

`ndb-2.9-pgsql-17-Rocky-Linux-9.6-20240101120000`

## Automated Tests

The project includes a test script that iterates through all the build combinations defined in the `matrix.json` files and runs a full Packer build for each one. This is a comprehensive end-to-end test to ensure that all build configurations are working correctly.

To run the tests, execute the `test.sh` script:

```bash
./test.sh
```