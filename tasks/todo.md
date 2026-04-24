# Task Plan

- [x] Record current build/debug state
- [x] Debug and fix the Rocky package install failure (`gdbm-devel` missing)
- [x] Re-run and complete the NDB 2.9 build
- [x] Check/reuse the Rocky 9.7 Prism image for NDB 2.10
- [x] Re-run and complete the NDB 2.10 build
- [x] Document results and follow-up
- [x] Remove retained failed build VMs from Prism
- [x] Launch a disposable validation VM from the NDB 2.9 image and run validation
- [x] Launch a disposable validation VM from the NDB 2.10 image and run validation
- [x] Confirm 2.9 validation VMs are removed
- [x] Confirm final 2.10 validation VMs are removed and summarize the final state

# Review

- Built `ndb-2.9-pgsql-17-Rocky Linux-9.6-20260423171907` successfully from the pre-staged Prism image `Rocky-9-GenericCloud-LVM-9.6-20250531.0.x86_64.qcow2`.
- Verified the saved `ndb-2.9-pgsql-17-Rocky Linux-9.6-20260423171907` artifact by cloning it into a disposable VM, powering it on, reaching it over SSH, and running the `validate_postgres` role successfully.
- Built `ndb-2.10-pgsql-18-Rocky Linux-9.7-20260423175551` successfully after allowing Prism to finish importing `Rocky-9-GenericCloud-LVM-9.7-20251123.2.x86_64.qcow2` and then reusing that staged image by name.
- Verified the saved `ndb-2.10-pgsql-18-Rocky Linux-9.7-20260423175551` artifact by cloning it into a disposable VM, powering it on, reaching it over SSH, and running the `validate_postgres` role successfully.
- Removed retained failed build VMs and cleaned up all disposable `validate-` / `probe-` VMs after the 2.9 validation pass.
- Removed retained failed build VMs and cleaned up all disposable `validate-` / `probe-` VMs after the 2.10 validation pass as well.
- The first 2.10 attempt failed only because Packer timed out while waiting for Prism to ingest the Rocky 9.7 source image; once the image import completed, the retry using `--source-image-name` succeeded quickly.
- Root-cause fixes applied during the build work:
- Rocky CRB is now enabled unconditionally before Red Hat package installation.
- RedHat PostGIS dependency installation now enables EPEL when `postgis` is requested.
- PostgreSQL extension handling now maps `pgvector` to the SQL extension name `vector`.
- Extension preload/config settings are written to `postgresql.conf` before restart so `pg_cron`, `pglogical`, and related extensions can be created successfully.

# Active Plan

Implementation plan approved for the next reliability pass:

- [x] Capture approved design in `docs/superpowers/specs/2026-04-24-ndb-image-factory-reliability-design.md`
- [x] Write detailed implementation plan in `docs/superpowers/plans/2026-04-24-ndb-image-factory-reliability-implementation.md`
- [x] Confirm execution mode before implementation
- [x] Execute Task 1: shell matrix validator and self-test harness
- [x] Execute Task 2: Prism shell helper library
- [x] Execute Task 3: source image preflight and staging
- [x] Execute Task 4: build manifest writer
- [x] Execute Task 5: artifact validation helper
- [x] Execute Task 6: manifest status and failure integration
- [x] Execute Task 7: release scaffolding
- [x] Execute Task 8: beginner README restructure
- [x] Run final verification and document results

# Active Plan Review

- Task 5 added `scripts/artifact_validate.sh`, `--validate-artifact` build/test wiring, README guidance, and self-tests for artifact validation failure handling.
- Spec review found the artifact-validation trap could mask failures after temp-directory creation; fixed by preserving the original exit status inside one EXIT handler before cleanup.
- Code-quality review found extension validation only derived the first expected extension; fixed both NDB 2.9 and 2.10 validation roles so all supported expected SQL extensions are checked.
- Code-quality review found VM cleanup failures could be hidden; fixed artifact validation so successful validation plus failed VM deletion fails the run and records the cleanup status.
- Code-quality review found Packer manifest timing could drift into artifact validation; fixed `build.sh` so `packer.finished_at` and `packer.duration_seconds` are written immediately when Packer exits.
- Task 6 completed manifest source, Packer, artifact, validation, cleanup, and failed-status reporting. Code-quality review found empty artifact result files could bypass the failed fallback; fixed with `manifest.sh record-artifact-validation`, valid-JSON checks, and self-test coverage.
- Task 7 added `scripts/release_scaffold.sh`, release onboarding README guidance, and a dry-run self-test. Code-quality review found partial scaffold cleanup risks; fixed by staging under the repo, rolling back incomplete publishes, always cleaning staging, and using a generated dry-run test version.
- Task 8 restructured README into a beginner operator guide. Quality review found missing `packer init packer/` guidance and an under-warned live `test.sh` example; both were added before approval.
- Final verification found only Packer formatting drift in `packer/database.pkr.hcl` and `packer/variables.pkr.hcl`; fixed with `packer fmt packer` and added README offline verification commands. Live Prism smoke was skipped because the current shell has no `PKR_VAR_*` credentials and `.env` is a named pipe, not a readable env file.
- Final branch review found parallel `test.sh` failures could leave active builds running; fixed by draining already-started builds, stopping new launches after failure, and adding self-test coverage. It also found failed in-guest validation stayed `not-requested` in manifests; fixed by recording `running` before Packer and converting that to `failed` on nonzero exit.

# Active Plan: PostgreSQL Extension Coverage Guard

- [x] Add a failing self-test proving PostgreSQL matrix rows with empty extensions must be explicitly justified.
- [x] Implement the matrix validator guard in shell/jq without adding a new language or dependency.
- [x] Annotate existing intentional empty PostgreSQL extension rows in the 2.9 and 2.10 matrices.
- [x] Update the README so new users understand extension validation and the intentional-empty marker.
- [x] Run the focused self-test plus full offline verification.

# Active Plan Review: PostgreSQL Extension Coverage Guard

- Added `extensions_empty_reason` validation to `scripts/matrix_validate.sh` for buildable PostgreSQL rows whose `extensions` list is empty or omitted.
- Added a self-test that first failed without the guard, then passed after the validator change.
- Marked the 14 buildable NDB 2.10 PostgreSQL rows with pending extension package coverage as `extensions: []` plus `extensions_empty_reason`.
- NDB 2.9 already had extension lists for buildable PostgreSQL rows, so no NDB 2.9 matrix annotation was needed.
- Updated the README matrix guidance, drafting prompt, and PostgreSQL extension section to explain the marker in beginner-friendly terms.
- Verified with shell syntax checks, self-tests, matrix validation, Packer formatting, Packer validation, Ansible syntax checks, representative 2.9 and 2.10 dry-runs, `git diff --check`, and a jq query proving no buildable empty-extension PostgreSQL rows lack a reason.

# Active Plan: Full Extension Installation Validation

- [x] Inventory all matrix rows that request PostgreSQL extensions and record the exact coverage size.
- [x] Add a tested `test.sh --extensions-only` mode so live validation can target only rows that request extension installation.
- [x] Make PostgreSQL extension handling fail when a matrix-listed extension is skipped, unless the matrix is changed to stop listing it.
- [x] Update the README with the exact beginner-safe command for validating every matrix extension row.
- [x] Run offline verification for the runner, Ansible roles, matrices, Packer config, and dry-runs.
- [x] Run the live extension validation suite if Prism credentials are available in this shell; otherwise record the credential blocker without claiming live validation.

# Active Plan Review: Full Extension Installation Validation

- Inventory found 29 PostgreSQL rows with non-empty extension lists across NDB 2.9 and NDB 2.10; 22 are buildable `provisioning_role=postgresql` rows selected by `test.sh`.
- Those rows list 9 unique extension names: `pg_cron`, `pg_partman`, `pg_stat_statements`, `pgaudit`, `pglogical`, `pgvector`, `postgis`, `set_user`, and `timescaledb`.
- Added `test.sh --extensions-only` so the live suite can target only matrix rows that request extension installation.
- Added `test.sh --continue-on-error` so a full coverage run keeps going after a failed row and reports all selected rows instead of stopping at the first failure.
- Made both NDB 2.9 and 2.10 PostgreSQL roles fail when a requested extension is skipped instead of silently continuing.
- Made both NDB 2.9 and 2.10 validation roles fail when a requested extension would be skipped during standalone artifact validation.
- Updated the README with the full extension coverage command and strict extension semantics.
- Offline verification passed: shell syntax, self-tests, matrix validation, Packer formatting, Packer validation, Ansible syntax checks, and representative dry-runs.
- The first live attempt did not run because this shell was missing `PKR_VAR_pc_username`, `PKR_VAR_pc_password`, `PKR_VAR_pc_ip`, `PKR_VAR_cluster_name`, and `PKR_VAR_subnet_name`; the 1Password-mounted `.env` later resolved that blocker.

# Active Plan: Extension Package Mapping Fix and Rerun

- [x] Confirm the 1Password-mounted `.env` exposes the required Prism variables without printing secret values.
- [x] Start the full extension validation suite with `op run --env-file .env`.
- [x] Stop the first pass after real package-map defects were found instead of burning through the full matrix.
- [x] Fix Red Hat family package names for `pgaudit` and `timescaledb` in both NDB role versions.
- [x] Add the TimescaleDB Ubuntu repository and package name in both NDB role versions.
- [x] Install the TimescaleDB packagecloud key as a dearmored apt keyring.
- [x] Fix `test.sh` so background builds cannot consume the matrix reader stdin and skip rows.
- [x] Harden Debian/Ubuntu apt package tasks against first-boot dpkg lock races.
- [x] Update README guidance for the package source/name behavior.
- [x] Re-run offline verification after the package mapping and harness fixes.
- [x] Fix the Debian/Ubuntu PostgreSQL contrib package name exposed by the focused Ubuntu rerun.
- [x] Re-run offline verification after the contrib package-name fix.
- [x] Add final image-prep tasks so cloned Ubuntu artifacts boot with reusable cloud-init/network state.
- [x] Re-run offline verification after the image-prep change.
- [x] Add boot-readiness retries to post-build service validation.
- [x] Re-run offline verification after the service-readiness change.
- [x] Re-run the live extension validation suite and capture every row result.
- [x] Confirm no failed builder or validation VMs remain.
- [x] Document final validation results.

# Active Plan Review: Extension Package Mapping Fix and Rerun

- 1Password env injection works with `op run --env-file .env`; the raw shell still intentionally does not expose the secrets.
- The stopped live pass proved the strict guard and failed-builder cleanup work, and exposed incorrect package assumptions before completing the full matrix.
- PGDG RPM metadata shows Red Hat family systems use package names such as `pgaudit_16`, `pgaudit16_14`, `pgaudit17_15`, and `timescaledb_16`.
- Timescale packagecloud metadata shows Ubuntu uses package names such as `timescaledb-2-postgresql-16`, so the role now adds that repository only when `timescaledb` is requested.
- Packagecloud's installer dearmors the TimescaleDB key before using it in `signed-by`; the Ansible role now follows that pattern after apt rejected the raw public key with `NO_PUBKEY E7391C94080429FF`.
- The second live pass proved a shell harness bug: a background build could inherit the `jq` process-substitution stdin and drain the remaining matrix rows. `test.sh` now launches builds with stdin from `/dev/null`, and self-tests cover that case.
- The third live pass proved Ubuntu cloud images can still hold `/var/lib/dpkg/lock-frontend` immediately after SSH becomes available. Debian-family apt installs now use explicit lock waiting and retries so transient first-boot package work slows the build instead of failing it immediately.
- The focused Ubuntu rerun proved the Debian-family contrib package name was wrong. PGDG apt packages use names such as `postgresql-contrib-16`, not `postgresql-16-contrib`.
- Both NDB role versions now use `postgresql-contrib-%s` for Debian-family `pg_stat_statements` and the always-installed contrib package. Self-tests, matrix validation, Ansible syntax checks, Packer validation, Packer formatting, and `git diff --check` passed after the fix.
- The next focused Ubuntu rerun built and in-guest validated the NDB 2.10 Ubuntu 22.04 PostgreSQL 16 image successfully, but the saved-image validation clone never became reachable on its assigned IP. Prism showed the clone powered on; the VPN router returned `Destination Host Unreachable`. This points to artifact image first-boot/network preparation, not extension installation.
- Added a final `image_prepare` role to both NDB playbooks after optional validation. It removes the generated Ubuntu cloud-init netplan file, resets cloud-init state with `/usr/bin/cloud-init clean --logs --machine-id` when available, and syncs before Packer captures the image.
- The next saved-image validation clone became reachable over SSH, proving the image-prep fix addressed clone networking. Artifact validation then failed because it checked services immediately after SSH and `firewalld.service` was still `inactive`, so validation needs to wait for boot services to settle before asserting.
- Validation now retries required service active checks before asserting. Offline verification passed again: shell syntax, self-tests, matrix validation, Ansible syntax checks, Packer formatting, Packer validation, and `git diff --check`.
- The NDB 2.10 Ubuntu 22.04 PostgreSQL 16 and 15 focused rerun passed build-time validation and saved-artifact validation. Both cloned artifacts reported all requested extensions present.
- The NDB 2.9 non-RHEL extension rerun passed 8 selected rows: Rocky Linux 9.6 PostgreSQL 17, 16, 15, and 14; Ubuntu 22.04 PostgreSQL 17, 16, 15, and 14. Each saved artifact validation reported `ok=18`, `unreachable=0`, and `failed=0`.
- The final NDB 2.10 Rocky Linux 9.6 extension rerun passed PostgreSQL 17, 16, 15, and 14. Each saved artifact validation reported `ok=18`, `unreachable=0`, and `failed=0`.
- In total, 14 buildable non-RHEL extension rows passed build-time validation and saved-artifact validation across NDB 2.9 and 2.10.
- The RHEL rows remain unvalidated because `NDB_RHEL_9_6_IMAGE_URI` is still empty after the 1Password env mount. The key exists in `.env`, but `op run --env-file .env` resolves it as missing.
- Prism cleanup verification returned no `ndb-*20260424` builder VMs and no `validate-ndb-*20260424` disposable validation VMs.
