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

# Active Plan: MongoDB Image Build and Validation Design

- [x] Explore current MongoDB project context.
- [x] Confirm MongoDB topology scope with the user.
- [x] Propose implementation approaches and get design approval.
- [x] Write the MongoDB design spec.
- [x] Self-review the MongoDB design spec.
- [x] Commit the approved MongoDB design spec.
- [ ] Ask the user to review the written spec before implementation planning.

# Active Plan Review: MongoDB Image Build and Validation Design

- The current matrices contain MongoDB rows for NDB 2.9 and 2.10, but all are metadata-only today.
- The current playbooks and validation helper are PostgreSQL-specific; MongoDB needs first-class role dispatch before live builds can run.
- The user approved support for MongoDB single-instance and sharded-cluster validation, using the recommended local sharded topology inside validation instead of a shallow package-only check.
- The written spec normalizes sharded topology into `deployment` metadata instead of fake OS versions such as `9.7 (sharded)`.

# Active Plan: MongoDB Implementation Plan

- [x] Create detailed implementation plan from the approved MongoDB design spec.
- [ ] User selects execution mode for implementation.

# Active Plan Review: MongoDB Implementation Plan

- The implementation plan is saved to `docs/superpowers/plans/2026-04-25-mongodb-image-build-validation-implementation.md`.
- The plan decomposes the work into matrix validation, matrix conversion, build/test dispatch, Ansible provisioning, validation, artifact validation, README updates, offline verification, and live Prism validation.

# Active Plan: MongoDB Implementation Execution

- [x] Create isolated worktree branch `codex/mongodb-image-validation`.
- [x] Execute Task 1: matrix validator and self-test guard.
- [x] Run Task 1 spec-compliance and code-quality reviews.
- [x] Correct the Task 2 sharded-readiness coverage count from 5 to 8 to match the approved matrix conversion scope.
- [x] Execute Task 2: MongoDB matrix conversion.
- [x] Run Task 2 spec-compliance and code-quality reviews.
- [x] Execute Task 3: build and test harness dispatch.
- [ ] Continue remaining MongoDB provisioning, validation, README, offline verification, and live Prism validation tasks one task at a time.

# Worker Task 3 Plan: MongoDB Harness Dispatch

**Goal:** Allow build/test harness selection to dispatch buildable MongoDB matrix rows without touching provisioning roles.

**Files:**
- Modify: `scripts/selftest.sh`
- Modify: `build.sh`
- Modify: `test.sh`

- [x] Add MongoDB dispatch guard self-tests after the existing test harness tests.
- [x] Run `bash scripts/selftest.sh` and capture the expected failure before production changes.
- [x] Extend `generate_ansible_vars_json()` to include `provisioning_role`, `mongodb_edition`, and `mongodb_deployments`.
- [x] Move role metadata extraction before Ansible vars generation and allow `postgresql|mongodb` while still rejecting `metadata` and unsupported roles.
- [x] Pass MongoDB metadata and provisioning role into artifact validation.
- [x] Update `test.sh` to skip only `metadata` rows instead of every non-PostgreSQL row.
- [x] Verify with shell syntax checks, self-tests, `git diff --check`, and the focused MongoDB dry-run probe.
- [x] Self-review the diff, document results, and commit the requested harness files.

# Worker Task 3 Review: MongoDB Harness Dispatch

- Added dispatch self-test coverage after the existing test harness tests.
- Captured the intended red failure: `FAIL: build.sh does not allow MongoDB provisioning role`.
- `build.sh` now includes `provisioning_role`, `mongodb_edition`, and `mongodb_deployments` in generated Ansible vars.
- `build.sh` now accepts `postgresql|mongodb`, rejects `metadata` as metadata-only, and reports unsupported roles distinctly.
- `build.sh` now passes provisioning role and MongoDB metadata into artifact validation command construction.
- `test.sh` now skips only `metadata` rows instead of filtering every non-PostgreSQL role.
- Verification passed with `bash -n build.sh test.sh scripts/*.sh`, `bash scripts/selftest.sh`, `git diff --check`, and the focused MongoDB dry-run probe.
- Concern: `scripts/artifact_validate.sh` does not yet parse the newly wired artifact-validation metadata flags; this task did not edit that file because it is outside Worker Task 3 ownership and later validation tasks own artifact behavior.

# Active Plan Review: MongoDB Implementation Execution

- Task 1 commit `facf389` validates MongoDB matrix metadata and adds self-test coverage for role/db-type mismatches, required edition/deployment metadata, invalid deployment values, duplicate deployments, duplicate grouping, and fake topology encoded in buildable `os_version` values.
- Task 1 verification passed with `bash scripts/selftest.sh`, `scripts/matrix_validate.sh ndb/*/matrix.json`, shell syntax checks, and targeted invalid-input probes.
- The written Task 2 plan originally expected five sharded-readiness rows, but its own row conversion scope produces eight: six NDB 2.9 community rows on Rocky/RHEL plus two NDB 2.10 Enterprise rows on RHEL.
- Task 2 commit `0617a85` converted 9 buildable MongoDB rows in each NDB matrix, removed fake sharded `os_version` values, and added matrix coverage self-tests.
- Task 2 review found the exact sharded-readiness guard should not glob future release matrices; it now scopes the exact count to NDB 2.9 and 2.10 only.
- Task 2 final verification passed with `bash scripts/selftest.sh`, `scripts/matrix_validate.sh ndb/*/matrix.json`, `jq empty ndb/2.9/matrix.json ndb/2.10/matrix.json`, and `git diff --check`.

# Worker Tasks 4+5 Plan: MongoDB Playbook Dispatch and Provisioning Roles

**Goal:** Dispatch PostgreSQL or MongoDB provisioning from the Ansible site playbooks and add MongoDB package provisioning roles for NDB 2.9 and 2.10.

**Files:**
- Modify: `scripts/selftest.sh`
- Modify: `ansible/2.9/playbooks/site.yml`
- Modify: `ansible/2.10/playbooks/site.yml`
- Create: `ansible/2.9/roles/mongodb/defaults/main.yml`
- Create: `ansible/2.9/roles/mongodb/tasks/main.yml`
- Create: `ansible/2.10/roles/mongodb/defaults/main.yml`
- Create: `ansible/2.10/roles/mongodb/tasks/main.yml`
- Modify: `tasks/todo.md`

- [x] Add playbook database dispatch and MongoDB role static self-test guards.
- [x] Run `bash scripts/selftest.sh` and capture the expected red failure before implementation.
- [x] Update both site playbooks to dispatch PostgreSQL and MongoDB roles by `provisioning_role`.
- [x] Add identical MongoDB defaults for Ansible 2.9 and 2.10.
- [x] Add identical MongoDB repository, package, keyring, daemon-reload, and service tasks for Ansible 2.9 and 2.10.
- [x] Run self-tests, shell syntax checks, Ansible syntax checks, and `git diff --check`.
- [x] Self-review the diff, document results here, and commit `Add MongoDB provisioning roles`.

# Worker Tasks 4+5 Review: MongoDB Playbook Dispatch and Provisioning Roles

- Captured the intended Task 4 red failure: `FAIL: playbook 2.9 missing postgres role dispatch`.
- Captured the intended Task 5 red failure after playbook dispatch was green: `FAIL: mongodb role 2.9 missing edition default`.
- Added static self-test coverage for database role dispatch and MongoDB provisioning role package/repository/service support.
- Updated both site playbooks to dispatch `postgres`, `validate_postgres`, `mongodb`, and `validate_mongodb` by `provisioning_role`, with `postgresql` as the default.
- Added identical MongoDB provisioning defaults and tasks for NDB 2.9 and NDB 2.10, including community/enterprise repositories, Debian keyring directory creation, apt lock waiting, dnf metadata refresh, systemd daemon reload, and `mongod` service management.
- Verification passed for `bash scripts/selftest.sh`, `bash -n build.sh test.sh scripts/*.sh`, `git diff --check`, and identical-content checks between the 2.9 and 2.10 MongoDB role files.
- Verification is blocked for both Ansible syntax checks because `validate_mongodb` is referenced by the requested playbook dispatch but the `ansible/*/roles/validate_mongodb` role files are not present in this worktree and are outside this worker's owned file list.
- Commit was deferred until expanded Task 6 supplied the missing validation role and made the combined syntax-check slice green.

# Worker Task 6 Plan: MongoDB Validation Roles

**Goal:** Add MongoDB validation roles so the Task 4 playbook dispatch can pass Ansible syntax checks and validate active/enabled MongoDB services plus version/topology smoke tests.

**Files:**
- Modify: `scripts/selftest.sh`
- Create: `ansible/2.9/roles/validate_mongodb/defaults/main.yml`
- Create: `ansible/2.9/roles/validate_mongodb/tasks/main.yml`
- Create: `ansible/2.9/roles/validate_mongodb/files/validate_mongodb_sharded.sh`
- Create: `ansible/2.10/roles/validate_mongodb/defaults/main.yml`
- Create: `ansible/2.10/roles/validate_mongodb/tasks/main.yml`
- Create: `ansible/2.10/roles/validate_mongodb/files/validate_mongodb_sharded.sh`
- Modify: `tasks/todo.md`

- [x] Add MongoDB validation-role static self-test guard.
- [x] Run `bash scripts/selftest.sh` and capture the expected red failure for missing `validate_mongodb` role files.
- [x] Add identical validation defaults for Ansible 2.9 and 2.10.
- [x] Add identical sharded-cluster validation scripts with cleanup escalation.
- [x] Add identical validation tasks for active/enabled service checks, `mongod`/server version checks, and optional sharded validation.
- [x] Run self-tests, shell syntax checks, Ansible syntax checks, whitespace checks, and identical-content checks.
- [x] Self-review the full Tasks 4+5+6 diff and commit `Add MongoDB provisioning and validation roles`.

# Worker Tasks 4+5+6 Review: MongoDB Provisioning and Validation Roles

- Captured the intended Task 6 red failure: `FAIL: validate_mongodb role 2.9 missing retry default`.
- Added identical `validate_mongodb` defaults, tasks, and sharded validation scripts for NDB 2.9 and NDB 2.10.
- Validation now checks `firewalld`, `chrony`, `cron`, and `mongod` are active with retries and enabled/static-ish before checking MongoDB versions.
- Validation checks `mongod --version`, `mongosh --quiet --eval db.version()`, and runs the local sharded topology smoke script only when `sharded-cluster` is requested.
- The sharded smoke script creates temporary config/shard servers plus `mongos`, adds the shard with `sh.addShard`, and cleans up temp files plus child processes with graceful `kill` followed by `kill -9` if needed.
- Verification passed: `bash scripts/selftest.sh`, `bash -n build.sh test.sh scripts/*.sh ansible/2.9/roles/validate_mongodb/files/validate_mongodb_sharded.sh ansible/2.10/roles/validate_mongodb/files/validate_mongodb_sharded.sh`, both requested Ansible syntax checks with `/tmp/ndb-ansible-2.18/bin` first in `PATH`, and `git diff --check`.
- Identical-content checks passed for both NDB versions' MongoDB defaults/tasks and validate_mongodb defaults/tasks/sharded scripts.

# MongoDB Role Hardening Plan

**Goal:** Address quality-review findings before accepting the MongoDB provisioning and validation slice.

**Files:**
- Modify: `ansible/2.9/roles/mongodb/defaults/main.yml`
- Modify: `ansible/2.9/roles/mongodb/tasks/main.yml`
- Modify: `ansible/2.10/roles/mongodb/defaults/main.yml`
- Modify: `ansible/2.10/roles/mongodb/tasks/main.yml`
- Modify: `ansible/2.9/roles/validate_mongodb/tasks/main.yml`
- Modify: `ansible/2.9/roles/validate_mongodb/files/validate_mongodb_sharded.sh`
- Create: `ansible/2.9/roles/validate_mongodb/files/validate_mongodb_replica_set.sh`
- Modify: `ansible/2.10/roles/validate_mongodb/tasks/main.yml`
- Modify: `ansible/2.10/roles/validate_mongodb/files/validate_mongodb_sharded.sh`
- Create: `ansible/2.10/roles/validate_mongodb/files/validate_mongodb_replica_set.sh`
- Modify: `scripts/selftest.sh`
- Modify: `tasks/todo.md`
- Modify: `tasks/lessons.md`

- [x] Add static self-test guards for SELinux policy setup, edition validation, replica-set validation, dynamic ports, and safe PID cleanup.
- [x] Run `bash scripts/selftest.sh` and capture the expected red failure.
- [x] Add RedHat-family MongoDB SELinux policy dependency, clone, `make`, and `make install` tasks.
- [x] Remove unused global MongoDB user/group defaults to avoid OS-family footguns.
- [x] Add MongoDB edition validation via `buildInfo.modules`.
- [x] Add replica-set validation script and run it for `replica-set` deployments.
- [x] Update sharded and replica-set scripts to choose available localhost ports dynamically and only kill PIDs whose command line references the tempdir.
- [x] Run self-tests, shell syntax checks, Ansible syntax checks, whitespace checks, and identical-content checks.
- [x] Document hardening results and commit `Harden MongoDB provisioning validation`.

# MongoDB Role Hardening Review

- Captured the intended red failure: `FAIL: mongodb role 2.9 does not install MongoDB SELinux policy`.
- Added RedHat-family SELinux policy setup using the official `mongodb/mongodb-selinux` repository at `/usr/local/src/mongodb-selinux`, with `git`, `make`, `checkpolicy`, `policycoreutils`, and `selinux-policy-devel` installed before `make` and `make install`.
- Removed unused global `mongodb_user` and `mongodb_group` defaults so future tasks do not inherit RedHat-only service account assumptions on Ubuntu.
- Added MongoDB edition validation by reading `buildInfo.modules` through `mongosh` and asserting the result matches `mongodb_edition`.
- Added replica-set validation scripts and role tasks so rows declaring `replica-set` get an actual temporary localhost replica set smoke test.
- Reworked sharded and replica-set smoke scripts to choose available localhost ports dynamically with `lsof`, and to verify PID command lines reference the tempdir before cleanup kills a process.
- Verification passed: `bash scripts/selftest.sh`, `bash -n build.sh test.sh scripts/*.sh ansible/2.9/roles/validate_mongodb/files/*.sh ansible/2.10/roles/validate_mongodb/files/*.sh`, both requested Ansible syntax checks with `/tmp/ndb-ansible-2.18/bin` first in `PATH`, `git diff --check`, and identical-content checks between intended 2.9/2.10 role files.

# Worker Task 7 Plan: Artifact Validation Dispatch

**Goal:** Dispatch saved-artifact validation to PostgreSQL or MongoDB validation roles based on `db_type` / `provisioning_role`.

**Files:**
- Modify: `scripts/selftest.sh`
- Modify: `scripts/artifact_validate.sh`
- Modify: `tasks/todo.md`

- [x] Add self-test capture for the generated artifact validation playbook.
- [x] Add PostgreSQL and MongoDB dispatch assertions in `run_artifact_validate_tests()`.
- [x] Run `bash scripts/selftest.sh` and capture the expected MongoDB red failure.
- [x] Update `scripts/artifact_validate.sh` to choose `validate_postgres` or `validate_mongodb`.
- [x] Require/load PostgreSQL defaults only for PostgreSQL artifact validation.
- [x] Include shared PostgreSQL and MongoDB validation vars in generated `vars.json`.
- [x] Verify with shell syntax checks, full self-tests, `git diff --check`, and focused smoke if useful.
- [x] Self-review, document results, and commit the requested files.

# Worker Task 7 Review: Artifact Validation Dispatch

- Captured the intended red failure with `bash scripts/selftest.sh`: `FAIL: MongoDB artifact validation did not dispatch validate_mongodb`.
- Extended the artifact validation self-test mock to capture generated playbooks and assert PostgreSQL still dispatches `validate_postgres`.
- Added a MongoDB artifact validation success-path self-test that passes `--db-type mongodb`, `--provisioning-role mongodb`, edition, and deployment metadata, then asserts `validate_mongodb` is generated.
- `scripts/artifact_validate.sh` now selects `validate_mongodb` when `db_type` or `provisioning_role` is MongoDB, otherwise keeps `validate_postgres`.
- PostgreSQL defaults are required and passed only for PostgreSQL artifact validation; MongoDB validation receives only the generated vars file.
- Generated vars now include `db_version`, `db_type`, `provisioning_role`, `configure_ndb_sudoers`, PostgreSQL extension defaults, `mongodb_edition`, and `mongodb_deployments`.
- Verification passed: `bash -n scripts/artifact_validate.sh scripts/selftest.sh`, `bash scripts/selftest.sh`, and `git diff --check`.
