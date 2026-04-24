# NDB Image Factory Reliability Design

## Purpose

Make the NDB image builder a simple, reliable image factory for PostgreSQL-based NDB images while keeping the operator-facing toolchain limited to Packer, Ansible, shell, `jq`, `curl`, and optional Terraform later.

The design focuses on two goals:

- Production CI/CD reliability: predictable source-image handling, first-class artifact validation, cleanup, manifests, and clear failure recovery.
- Release velocity: faster NDB version onboarding with less copy/paste and less drift between release-specific directories.

This design intentionally does not add a Python orchestration package. Shell remains the orchestration layer because it is easier for this repo's intended operators to read, explain, and debug.

## Current Context

The latest validated run built and verified:

- `ndb-2.9-pgsql-17-Rocky Linux-9.6-20260423171907`
- `ndb-2.10-pgsql-18-Rocky Linux-9.7-20260423175551`

The run exposed the main reliability gaps:

- Prism source-image imports can outlive Packer's wait path. A retry using `--source-image-name` after the import completes is faster and more reliable.
- Artifact validation is proven manually, but it is not yet a first-class command.
- Disposable Prism validation VMs require base64-encoded cloud-init, an explicit power-on step, SSH with `IdentitiesOnly=yes`, and reliable cleanup.
- `build.sh` has grown into a large script that handles selection, source image logic, Packer invocation, validation state, and dry-run output.
- `ansible/2.9` and `ansible/2.10` duplicate a lot of role content, which makes future NDB releases more error-prone.

## Architecture

Keep `build.sh` and `test.sh` as the public entrypoints. Split reusable orchestration into focused shell helpers under `scripts/`.

Planned helper scripts:

- `scripts/prism.sh`: shared Prism API functions using `curl` and `jq`.
- `scripts/source_images.sh`: source-image preflight, staging, reuse, and timeout guidance.
- `scripts/artifact_validate.sh`: final image clone, cloud-init injection, VM power-on, SSH wait, Ansible validation, and cleanup.
- `scripts/manifest.sh`: build and validation manifest generation.
- `scripts/release_scaffold.sh`: NDB release scaffolding from a previous version.

The existing Ansible validation role remains the source of truth for in-guest PostgreSQL checks:

- `ansible/<version>/roles/validate_postgres`

Terraform is optional for a later phase. It should only be introduced if disposable validation VMs or source-image staging become better modeled as declarative infrastructure than shell-managed API operations.

## Command Flow

`build.sh` gains focused flags rather than introducing a new CLI.

Proposed flags:

- `--preflight`: validate local prerequisites, matrix selection, Prism access, source-image readiness, and required commands.
- `--stage-source`: import or verify the source image in Prism before the Packer build.
- `--validate-artifact`: after Packer creates the final image, boot a disposable VM from that image and run validation.
- `--manifest`: write a JSON manifest for the build, including failures.

The normal production path should be:

```bash
./build.sh --ci --validate --validate-artifact --manifest \
  --ndb-version 2.10 \
  --db-type pgsql \
  --os "Rocky Linux" \
  --os-version 9.7 \
  --db-version 18
```

The internal flow is:

1. Validate the selected matrix file and resolve the build row.
2. Run local and Prism preflight checks.
3. Resolve the source image.
4. Reuse a named Prism image when available.
5. If needed, stage/import the source image and wait for completion.
6. Run Packer.
7. Run in-guest Ansible validation when `--validate` is set.
8. Resolve the final image name and UUID.
9. Clone the final image into a disposable validation VM when `--validate-artifact` is set.
10. Power on the validation VM, wait for SSH, and run the existing validation role.
11. Clean up disposable validation VMs.
12. Write the manifest when `--manifest` is set.

`test.sh` should pass through the same production gates so matrix testing exercises the same path:

```bash
./test.sh --include-ndb 2.10 --include-os "Rocky Linux" --validate --validate-artifact
```

## Source Image Handling

Source image handling should become explicit and repeatable.

The build should:

- Check whether the desired source image already exists in Prism.
- Prefer `--source-image-name` when a matching source image is present.
- Stage source images before the Packer build when requested.
- Poll Prism task UUIDs directly and report status clearly.
- If staging times out, print the task UUID and the exact retry command using `--source-image-name`.

This matches the successful 2.10 recovery path from the last run: wait for the Rocky 9.7 source image import to complete, then rerun the build using the staged image name.

## Artifact Validation

Artifact validation proves the saved image, not just the temporary Packer build VM.

When `--validate-artifact` is enabled, the flow should:

1. Find the final image UUID in Prism.
2. Clone it into a disposable VM with a unique `validate-...` name.
3. Base64-encode the cloud-init `user_data` passed to Prism.
4. Wait for the VM create task to succeed.
5. Explicitly power on the VM.
6. Wait for an IP address.
7. Wait for SSH using the repo key and `IdentitiesOnly=yes`.
8. Run the existing `validate_postgres` role against the disposable VM.
9. Delete the disposable VM on success or failure unless debug mode asks to keep it.

The first implementation should support PostgreSQL images only, matching the current buildable pipeline.

## Manifest

Each build should be able to emit:

```text
manifests/<image-name>.json
```

The manifest should include:

- Build selection: NDB version, database type/version, OS type/version, provisioning role.
- Matrix row used for the build.
- Source image mode: URI, local path, or Prism image name.
- Source image Prism UUID when available.
- Final artifact image name and UUID.
- Packer start/end time and duration.
- In-guest validation status.
- Artifact validation VM name, status, and cleanup status.
- Git commit and dirty-worktree indicator.
- Overall result: `success`, `failed`, or `partial`.

If a build fails, the manifest should still be written when enough information is available.

## Release Velocity

Add a shell-first release scaffolding workflow:

```bash
scripts/release_scaffold.sh 2.11 --from 2.10
```

The scaffold should:

- Create `ndb/<new-version>/`.
- Create `ansible/<new-version>/` from the previous version.
- Copy release-specific PostgreSQL docs when provided by the operator.
- Update obvious version references.
- Leave clear review markers for human decisions that cannot be inferred safely.
- Run syntax checks after scaffolding.

Matrix generation should remain curated for now. A future enhancement can add a `jq`-based or prompt-assisted draft workflow, but the first release-velocity improvement should reduce directory setup and drift without pretending release-note interpretation is fully automatic.

## Error Handling

The design should handle the observed failures directly.

Source-image import timeout:

- Print Prism task UUID.
- Print current task status if available.
- Print a retry command using `--source-image-name`.

Disposable validation VM create failure:

- Print VM name and task UUID.
- Print Prism error detail when available.
- Attempt cleanup.

SSH failure:

- Use `IdentitiesOnly=yes`, `IdentityAgent=none`, and repo key explicitly.
- Print VM name and IP.
- Clean up unless debug mode requests retention.

Validation failure:

- Preserve Ansible output in the terminal.
- Mark manifest validation status as failed.
- Clean up validation VM unless debug mode requests retention.

Cleanup failure:

- Print leftover VM names and UUIDs.
- Keep the manifest explicit about cleanup status.

## Documentation

Every behavior change must update `README.md` in the same work item.

The README should remain the operator manual and stay beginner-friendly. It should explain:

- What the tool does.
- Required local tools.
- Environment setup from `.env.example`.
- Dry-run usage.
- One-image build usage.
- Build with in-guest validation.
- Build with final artifact validation.
- Source-image staging and reuse.
- Manifest output.
- Release scaffolding.
- Common troubleshooting steps.

The README should favor short copy/paste commands and plain-language explanations over dense reference text. Reference sections are still useful, but they should come after the beginner workflows.

## Testing

Required checks for this improvement set:

- `bash -n` for all shell scripts.
- `shellcheck` when available.
- `packer fmt -check`.
- `packer validate`.
- Ansible syntax checks for every `ansible/<version>/playbooks/site.yml`.
- Dry-run checks for representative NDB 2.9 and 2.10 rows.
- Artifact validation helper dry-run or argument validation.
- A real Rocky Linux smoke build with `--validate --validate-artifact --manifest` when Prism credentials are available.

## Out Of Scope

These are intentionally not part of the first implementation pass:

- Adding Oracle, SQL Server, MySQL, MariaDB, MongoDB, or EDB provisioning roles.
- Rewriting the project as a Python CLI.
- Fully automatic matrix extraction from release notes.
- Terraform-based validation VM lifecycle.
- Publishing images to external registries or catalogs.

## Definition Of Done

The improvement is done when:

- Operators can run one command to build, validate, artifact-validate, clean up, and emit a manifest.
- Source-image import timeouts produce a clear recovery path.
- The manual artifact-validation runbook from the last successful build is encoded in shell.
- `test.sh` can exercise the same validation gates.
- NDB release scaffolding exists for the next release.
- README explains all new commands clearly enough for a new operator to follow.
- Verification commands pass, or any unavailable checks are documented clearly.
