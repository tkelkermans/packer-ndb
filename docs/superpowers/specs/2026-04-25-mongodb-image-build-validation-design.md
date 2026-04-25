# MongoDB Image Build and Validation Design

Date: 2026-04-25

## Goal

Add first-class MongoDB image builds to the existing NDB image factory, including live build-time validation and saved-artifact validation.

The target scope is MongoDB single-instance readiness and sharded-cluster readiness. Sharded validation should prove that the image can run the sharded MongoDB binaries and bootstrap a minimal topology, without requiring multiple Nutanix VMs.

## Current State

The repository already has MongoDB compatibility rows in `ndb/2.9/matrix.json` and `ndb/2.10/matrix.json`, but every MongoDB row currently uses `provisioning_role=metadata`. As a result:

- `build.sh` rejects MongoDB rows as metadata-only.
- `test.sh` skips MongoDB rows because it only runs `provisioning_role=postgresql`.
- `scripts/artifact_validate.sh` always generates a validation playbook using `validate_postgres`.
- The Ansible site playbooks always run `common`, `postgres`, optional `validate_postgres`, and `image_prepare`.

The PostgreSQL work established reusable patterns that MongoDB should follow: strict matrix metadata, explicit role dispatch, build-time validation, saved-artifact validation, failed builder cleanup, cloud-init image preparation, README updates, and self-test coverage.

## Support Model

MongoDB images will be buildable only when the release notes and local source-image catalog support the selected operating system version.

The buildable first slice is:

- NDB 2.9 Rocky Linux 9.6 MongoDB 8.0, 7.0, and 6.0 for single-instance, replica-set, and sharded-cluster readiness.
- NDB 2.9 RHEL 9.6 MongoDB 8.0, 7.0, and 6.0 for single-instance, replica-set, and sharded-cluster readiness when `NDB_RHEL_9_6_IMAGE_URI` resolves non-empty.
- NDB 2.9 Ubuntu 22.04 MongoDB 8.0, 7.0, and 6.0 for single-instance and replica-set readiness only.
- NDB 2.10 Rocky Linux 9.7 MongoDB 8.0, 7.0, and 6.0 for single-instance and replica-set readiness only.
- NDB 2.10 RHEL 9.7 MongoDB 8.0 and 7.0 for single-instance, replica-set, and sharded-cluster readiness, using Enterprise packages because the NDB 2.10 sharded-cluster table lists Enterprise only.
- NDB 2.10 RHEL 9.7 MongoDB 6.0 for single-instance and replica-set readiness when `NDB_RHEL_9_7_IMAGE_URI` resolves non-empty.
- NDB 2.10 Ubuntu 22.04 MongoDB 8.0, 7.0, and 6.0 for single-instance and replica-set readiness only.

Rows that remain metadata-only:

- NDB 2.10 Rocky Linux sharded-cluster rows, because the NDB 2.10 release notes mark Ops Manager as not qualified for Rocky Linux sharded clusters.
- NDB 2.10 RHEL 8.10 sharded-cluster rows, because `images.json` does not currently define a RHEL 8.10 source image.
- Any MongoDB OS/version combination from the release notes that is not represented by a source image in `images.json`.

## Matrix Model

MongoDB buildable rows should use:

```json
{
  "db_type": "mongodb",
  "provisioning_role": "mongodb",
  "mongodb_edition": "community",
  "deployment": ["single-instance", "replica-set"]
}
```

When one image must cover sharded-cluster readiness, include `sharded-cluster` in `deployment`. Use `mongodb_edition=enterprise` only where the selected row requires Enterprise packages to cover sharded support.

The matrix should not encode deployment by changing the operating system version, for example `9.7 (sharded)`. `os_version` remains the real OS version. Topology belongs in `deployment`.

The matrix validator will be updated so duplicate detection includes MongoDB deployment/edition semantics instead of relying on fake OS versions. The preferred end state is still one buildable image row per NDB version, OS, MongoDB major version, and package edition.

## Build Flow

`build.sh` will support `provisioning_role=mongodb` alongside `postgresql`.

The generated Ansible vars will include:

- `db_type`.
- `db_version`.
- `ndb_version`.
- `validate_build`.
- `mongodb_edition`.
- `mongodb_deployments`.

Playbook dispatch will be explicit:

- PostgreSQL rows run `postgres`, optional `validate_postgres`, then `image_prepare`.
- MongoDB rows run `mongodb`, optional `validate_mongodb`, then `image_prepare`.

This keeps each database family understandable and avoids putting MongoDB conditionals inside PostgreSQL roles.

## MongoDB Provisioning Role

Create `ansible/<version>/roles/mongodb` for NDB 2.9 and 2.10.

The role will:

- Install the official MongoDB repository for the selected major version.
- Use `repo.mongodb.org` and `mongodb-org` packages for Community.
- Use `repo.mongodb.com` and `mongodb-enterprise` packages for Enterprise.
- Support RedHat-family systems with yum/dnf repository files.
- Support Ubuntu with apt keyrings and source-list files.
- Install server, shell, mongos, and tools packages needed for single-instance and local sharded validation.
- Enable and start the default `mongod` service.
- Keep the default package-managed directories and service layout.

Package installation will follow the same reliability rules as PostgreSQL:

- Debian-family apt tasks use `lock_timeout`, retries, and `until` guards.
- RedHat-family metadata refreshes are retried.
- Repository keys are installed in the format expected by the package manager.
- Package naming is centralized in role defaults where practical.

## MongoDB Validation Role

Create `ansible/<version>/roles/validate_mongodb`.

Single-instance validation will check:

- Required services are active after a short retry window.
- `mongod --version` reports the expected major version.
- `mongosh` can connect to localhost.
- `db.version()` reports the expected major version.

Sharded-cluster validation will run only when `mongodb_deployments` contains `sharded-cluster`.

Sharded validation will:

- Stop or avoid the default `mongod` service only if needed to prevent port conflicts.
- Create temporary data directories under `/tmp` or another disposable validation path.
- Start a config-server replica set on localhost using alternate ports.
- Start one shard replica set on localhost using alternate ports.
- Start `mongos` on an alternate localhost port.
- Initiate both replica sets with `mongosh`.
- Add the shard through `mongos`.
- Verify that `sh.status()` or an equivalent admin command shows the shard.
- Clean up temporary `mongod` and `mongos` processes and data directories even on failure.

This validation is intentionally a smoke topology, not a production deployment. It proves the image has the correct binaries, service dependencies, storage paths, permissions, and shell tooling to run sharded MongoDB.

## Artifact Validation

`scripts/artifact_validate.sh` will dispatch validation by `db_type`.

For MongoDB artifacts, it will:

- Clone the saved image into a disposable validation VM.
- Wait for SSH.
- Generate an Ansible playbook using `validate_mongodb`.
- Pass `mongodb_edition` and `mongodb_deployments` from the matrix row.
- Delete the disposable validation VM after success or failure, preserving the current cleanup semantics.

Artifact validation must fail when:

- The validation VM cannot boot or accept SSH.
- The MongoDB version does not match the selected major version.
- `mongosh` cannot connect.
- The sharded smoke topology cannot be initialized for rows that require sharded validation.
- Cleanup fails after otherwise successful validation.

## Test Harness

`test.sh` will support MongoDB rows without weakening the PostgreSQL flow.

The default can remain PostgreSQL-focused for backwards compatibility. Operators can run MongoDB explicitly:

```bash
./test.sh --include-db-type mongodb --validate --validate-artifact --manifest --max-parallel 1
```

For 1Password-managed environments:

```bash
op run --env-file .env -- ./test.sh --include-db-type mongodb --validate --validate-artifact --manifest --max-parallel 1
```

If RHEL source-image variables are missing, RHEL rows should fail early with a clear missing-env message or be excluded with `--exclude-os`, rather than failing deep inside Packer.

## Documentation

The README will be updated as part of implementation. It should explain:

- MongoDB support is now buildable for selected matrix rows.
- Which rows validate single-instance only and which also validate sharded readiness.
- Which rows require Enterprise packages.
- How to run the MongoDB live matrix.
- How to check required RHEL source-image variables through `op run`.
- That local sharded validation is a smoke topology inside the validation VM, not a production sharded deployment.

## Verification Plan

Offline verification:

- `bash -n build.sh test.sh scripts/*.sh`.
- `bash scripts/selftest.sh`.
- `scripts/matrix_validate.sh ndb/*/matrix.json`.
- Ansible syntax checks for NDB 2.9 and 2.10 playbooks with Ansible 2.18.
- `packer fmt -check packer`.
- `packer validate` with dummy variables.
- `git diff --check`.

Self-tests will cover:

- `provisioning_role=mongodb` is accepted for `db_type=mongodb`.
- PostgreSQL rows still use PostgreSQL roles.
- MongoDB rows use `mongodb` and `validate_mongodb`.
- Artifact validation dispatches to MongoDB validation for `db_type=mongodb`.
- Matrix validation rejects fake sharded OS versions after normalization.
- Matrix validation accepts buildable MongoDB rows with explicit edition and deployment metadata.
- Sharded validation scripts include cleanup traps for temporary processes.
- README MongoDB commands are present.

Live verification:

- Run the MongoDB live suite for non-RHEL rows first.
- Run RHEL MongoDB rows only after `op run --env-file .env` confirms the required RHEL image variables resolve non-empty.
- Validate every successful build artifact by cloning the saved image and running the same MongoDB validation role.
- Confirm no failed builder or validation VMs remain in Prism after the run.

## Risks and Constraints

- MongoDB package repositories and latest patch versions change over time. The role should pin by major repository but validate major version, unless a future requirement asks for exact patch pinning.
- Enterprise packages may be downloadable from public repositories but still carry licensing obligations. Rows that require Enterprise must be marked explicitly in the matrix and README.
- A localhost sharded smoke topology is not a full production sharded cluster. It is the right image-level validation for this repo, but it does not replace NDB-level multi-node deployment testing.
- RHEL rows remain dependent on working `NDB_RHEL_*_IMAGE_URI` values from the environment.
- NDB 2.10 Rocky Linux sharded clusters should remain metadata-only because the release notes say Ops Manager is not qualified.

## Out of Scope

- MongoDB Ops Manager installation or registration.
- Multi-VM sharded cluster orchestration.
- MongoDB backup, PITR, KMS, or TDE feature validation.
- Separate Community and Enterprise image variants for every single-instance row.
- Exact patch-version pinning beyond validating the selected MongoDB major version.

## References

- MongoDB Community on RedHat/Rocky: https://www.mongodb.com/docs/v8.0/tutorial/install-mongodb-on-red-hat/
- MongoDB Community on Ubuntu: https://www.mongodb.com/docs/v8.0/tutorial/install-mongodb-on-ubuntu/
- MongoDB Enterprise on Ubuntu: https://www.mongodb.com/docs/v8.0/tutorial/install-mongodb-enterprise-on-ubuntu/
- NDB 2.9 release notes: `source/ndb-2.9-release-notes.md`
- NDB 2.10 release notes: `source/Nutanix Database Service 2.10 - Nutanix Database Service Release Notes.md`
