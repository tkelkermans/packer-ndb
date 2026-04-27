# Task Plan

# Active Plan: PostgreSQL Extension Image Name Suffix

- [x] Add failing selftest coverage that selected PostgreSQL extensions appear in generated image names.
- [x] Implement a shell-only extension image-name suffix helper in `build.sh`.
- [x] Keep no-extension builds on the current image naming pattern.
- [x] Update the single-image wizard/TUI preview so operators know extension choices affect the image name.
- [x] Update README image naming and PostgreSQL extension guidance.
- [x] Update durable lessons for this naming pitfall.
- [x] Run verification: targeted selftest, shell syntax, full selftest if feasible, dry-run checks, and `git diff --check`.

# Active Plan Review: PostgreSQL Extension Image Name Suffix

- Added a shared shell helper that converts selected PostgreSQL extensions into an image-name suffix such as `ext-pg-stat-statements` or `ext-pgvector-postgis`.
- Builds with no PostgreSQL extensions keep the existing image naming pattern.
- Builds with selected PostgreSQL extensions now include the suffix before the timestamp in both the saved image name and generated VM name base.
- The dry-run summary now shows `Image variant suffix`, and the wizard/TUI previews the extension suffix after individual extension selection.
- Long extension selections keep the first three extension names and add a checksum-backed `plus-N-<hash>` tail.
- README now explains the extension suffix in both PostgreSQL extension guidance and image naming guidance.
- Verification passed: red selftest first failed with `FAIL: selected extensions missing from image name`; `bash -n build.sh test.sh scripts/*.sh`; selected-extension dry-run; no-extension dry-run; `bash scripts/selftest.sh`; `bash scripts/matrix_validate.sh ndb/2.9/matrix.json ndb/2.10/matrix.json`; and `git diff --check`.
- Live validation passed on Prism with `--validate --validate-artifact --manifest --extensions pg_stat_statements` using source image UUID `7a6d6c2f-90b4-4acb-bf14-6f2be1bf006e`.
- Live saved image: `ndb-2.10-pgsql-18-Rocky Linux-9.7-ext-pg-stat-statements-20260427091501` (`d44c8a46-58b9-40b2-9e09-529c25bc7a86`).
- Live manifest recorded `validation.in_guest == "passed"`, `validation.artifact == "passed"`, `cleanup.artifact_validation_vm == "deleted"`, and `extensions.selected == ["pg_stat_statements"]`.

# Active Plan Review: Live PostgreSQL Extension Selection Smoke

- Live preflight passed for NDB 2.10 PostgreSQL 18 on Rocky Linux 9.7 using source image UUID `7a6d6c2f-90b4-4acb-bf14-6f2be1bf006e` and selected extension `pg_stat_statements`.
- Live build command passed with `--validate --validate-artifact --manifest --extensions pg_stat_statements`.
- Saved Prism image: `ndb-2.10-pgsql-18-Rocky Linux-9.7-20260427090011` (`e530a5d2-71bc-45a5-9e00-a91a24182a45`).
- In-guest validation passed, saved-artifact validation passed, and the manifest records the disposable validation VM cleanup as `deleted`.
- Manifest evidence: `extensions.selected == ["pg_stat_statements"]`, `extensions.qualified == []`, and `extensions.not_release_note_qualified == ["pg_stat_statements"]`, matching the expected advisory warning path for this matrix row.
- Follow-up debt observed during live Ansible runs: top-level `ansible_*` fact usage emits Ansible 2.20 deprecation warnings and should be migrated to `ansible_facts[...]` before Ansible 2.24.

# Active Plan: PostgreSQL Extension Selection Implementation

- [x] Approve advisory extension qualification design.
- [x] Write and commit the design spec.
- [x] Write detailed implementation plan.
- [x] Confirm execution approach before implementation.
- [x] Fix isolated-worktree baseline artifact validation selftest failure.
- [x] Execute Task 1: shared PostgreSQL extension catalog helper.
- [x] Execute Task 2: qualified extension matrix validation.
- [x] Execute Task 3: matrix migration from install lists to release-note metadata.
- [x] Execute Task 4: `build.sh --extensions` explicit selection.
- [x] Execute Task 5: artifact validation and test harness semantics.
- [x] Execute Task 6: wizard/TUI individual extension selection.
- [x] Execute Task 7: README and agent memory updates.
- [x] Execute Task 8: final offline verification and review notes.

# Active Plan Review: PostgreSQL Extension Selection Implementation

- PostgreSQL matrix rows now use `qualified_extensions` as release-note qualification metadata, not as a default install list.
- Buildable PostgreSQL rows that do not match exact release-note extension qualification rows now carry an explicit `qualified_extensions_empty_reason`.
- `build.sh --extensions` controls per-build PostgreSQL extension installation; omitted or `--extensions none` installs no extensions, and `--extensions all-qualified` selects only qualified extensions this tool can install today.
- The single-image wizard/TUI now lets operators individually select PostgreSQL extensions, defaults to none, and warns for installable choices that are not release-note-qualified for the selected row.
- Offline verification passed: shell syntax, selftests, matrix validation, representative dry-runs, `packer fmt -check`, `packer validate`, NDB 2.9 and 2.10 Ansible syntax checks, dry-run assertions, and `git diff --check`.
- `packer validate` in the isolated global worktree required a temporary ignored `packer/id_rsa` keypair because Packer validates the private-key file format; the temporary keypair was removed after validation.

# Active Plan: Consolidate AGENTS Project Memory

- [x] Review current lessons, task notes, README guidance, and existing AGENTS file.
- [x] Expand `AGENTS.md` with durable project rules and learned gotchas.
- [x] Add selftest guards for important agent guidance.
- [x] Run verification.
- [x] Commit and push the update.

# Active Plan Review: Consolidate AGENTS Project Memory

- The expanded `AGENTS.md` keeps agent-only rules out of the beginner README while preserving operational lessons for future Codex agents.
- Important guidance now covers toolchain constraints, README boundaries, planning, the build wizard/TUI, matrix rules, source-image pitfalls, validation, customization profiles, live evidence gaps, and git hygiene.
- Verification passed with shell syntax checks, `bash scripts/selftest.sh`, and `git diff --check`.

# Active Plan: Single-Image Build Wizard Implementation

- [x] Create the implementation plan from the approved wizard design.
- [x] Add failing offline wizard selftests.
- [x] Implement `scripts/build_wizard.sh`.
- [x] Add PostgreSQL extension awareness to the wizard preview.
- [x] Add source image and customization choices.
- [x] Update the README beginner workflow.
- [x] Run offline verification.
- [x] Commit the implementation.

# Active Plan Review: Single-Image Build Wizard Implementation

- Implementation plan saved to `docs/superpowers/plans/2026-04-26-single-image-build-wizard-implementation.md`.
- The plan keeps the wizard as a shell-only wrapper that prints ordinary `build.sh` commands.
- PostgreSQL extensions remain matrix-driven; the wizard will display them but will not add a new extension flag.
- Future single-image build features must update the wizard when they add or change choices, generated flags, warnings, or preview content.
- The README now documents the wizard as the beginner starting point and records the maintainer rule to update the wizard/TUI with future single-image build changes.
- Offline verification passed with shell syntax checks, `bash scripts/selftest.sh`, matrix validation, `packer fmt -check packer`, `git diff --check`, and a print-only wizard smoke that generated a dry-run `build.sh` command without starting Packer.

# Active Plan: Single-Image Build Wizard Design

- [x] Explore whether a TUI fits the current shell/Packer/Ansible project.
- [x] Confirm the wizard scope is single-image builds only.
- [x] Choose the separate thin wrapper approach.
- [x] Write the single-image build wizard design spec.
- [x] Self-review the design spec.
- [x] Commit the design spec.
- [x] Ask the user to review the written spec before implementation planning.

# Active Plan Review: Single-Image Build Wizard Design

- The wizard is intentionally a shell-only helper that generates ordinary `build.sh` commands instead of becoming a second build engine.
- The first version targets one image at a time and leaves matrix validation flows unchanged.
- Rich TUI dependencies are out of scope to preserve enterprise portability and readability.
- Safe defaults should favor dry-run first, then validated builds with artifact validation and manifests enabled.
- User review caught that the wizard must support PostgreSQL extension awareness; the design now requires showing the selected row's extension list, empty-extension reason, and validation-friendly defaults without adding ad hoc extension flags outside the matrix.

# Active Plan: Source Image UUID Smoke Fix

- [x] Reproduce live customization smoke blocker: Packer failed before VM creation because Prism returned more than one image with the same source image name/URI.
- [x] Add `--source-image-uuid` support to `build.sh`, Packer variables, Packer disk configuration, source-image preflight, README, and selftests.
- [x] Re-run offline verification after the UUID patch.
- [x] Run live preflight with the known Rocky 9.7 source image UUID.
- [x] Reproduce second live smoke blocker: example roles attempted system writes without privilege escalation.
- [x] Add `become: yes` to committed example install and validation tasks that touch system paths or services.
- [x] Re-run PostgreSQL live customization smoke with the known Rocky 9.7 source image UUID.
- [x] Re-run MongoDB live customization smoke with the known Rocky 9.7 source image UUID.
- [x] Re-run sharded MongoDB live customization smoke with the known Rocky 9.6 source image UUID.
- [x] Commit and push when verification succeeds.

# Active Plan Review: Source Image UUID Smoke Fix

- PostgreSQL live smoke reached Packer with `enterprise-example` and failed before provisioning with `your query returned more than one result with same Name/URI`.
- The current Prism environment has duplicate `Rocky-9-GenericCloud-LVM-9.7-20251123.2.x86_64.qcow2` images, so source image UUID selection is required for reliable live testing from this branch.
- UUID patch verification passed with `bash -n build.sh scripts/*.sh`, `bash scripts/selftest.sh`, `packer fmt -check packer`, and a dry-run showing `Source image mode: existing-prism-image-uuid`.
- Live UUID preflight passed with `Ready for live build: yes` using source image UUID `7a6d6c2f-90b4-4acb-bf14-6f2be1bf006e`.
- PostgreSQL live smoke with UUID reached in-guest customization execution, then failed creating `/etc/ndb-enterprise` as `packer`; failed builder VM cleanup succeeded.
- The example customization roles now use privilege escalation for system file, trust-store, systemd, sysctl, and validation reads.
- PostgreSQL live smoke passed after the privilege fix with image `ndb-2.10-pgsql-18-Rocky Linux-9.7-20260426134316` (`78f1e6d1-db88-4759-9f39-31d413eda27a`), in-guest validation `passed`, saved-artifact validation `passed`, customization validation `passed`, and validation VM cleanup `deleted`.
- Prism cleanup verification returned no matching PostgreSQL builder or disposable validation VMs for the successful smoke run.
- MongoDB NDB 2.10 live smoke passed with image `ndb-2.10-mongodb-8.0-Rocky Linux-9.7-20260426134924` (`ccdfa044-3c5b-4479-952f-5a01e3d912ba`), in-guest validation `passed`, saved-artifact validation `passed`, customization validation `passed`, and validation VM cleanup `deleted`.
- MongoDB NDB 2.9 live smoke passed with image `ndb-2.9-mongodb-8.0-Rocky Linux-9.6-20260426135554` (`e4373c6f-41bb-42d7-863d-56305ed198bc`), in-guest validation `passed`, saved-artifact validation `passed`, customization validation `passed`, and validation VM cleanup `deleted`.
- The NDB 2.9 MongoDB artifact validation exercised the local replica-set and sharded-cluster smoke validation scripts on the cloned VM.
- Prism cleanup verification returned no matching MongoDB builder or disposable validation VMs for either successful smoke run.
- Final offline verification passed with `bash scripts/selftest.sh`, shell syntax checks, matrix validation, `packer fmt -check packer`, explicit-var `packer validate packer`, NDB 2.9 and 2.10 Ansible syntax checks, and `git diff --check`.
- Commit `828295f` was pushed to `origin/codex/enterprise-customization-profiles`.

# Plan Audit: 2026-04-26

- Current enterprise customization work is implemented, validated, committed, and pushed.
- Source image UUID selection is implemented in `build.sh`, Packer variables, Packer disk configuration, source-image preflight, README guidance, and selftests.
- Enterprise customization profiles are implemented across CLI selection, Ansible preflight, build-time phases, saved-artifact validation, manifest reporting, committed examples, gitignored local overlays, README guidance, and selftests.
- Live validation evidence covers NDB 2.10 PostgreSQL 18 on Rocky 9.7, NDB 2.10 MongoDB 8.0 on Rocky 9.7, and NDB 2.9 MongoDB 8.0 on Rocky 9.6.
- The NDB 2.9 MongoDB validation exercised both replica-set and sharded-cluster smoke scripts on the saved artifact.
- Historical `docs/superpowers/plans/*.md` files are blueprint/spec files and still contain unchecked template steps; `tasks/todo.md` is the execution tracker for actual branch state.
- A full MongoDB non-RHEL matrix live sweep was not run in this branch; the branch has representative PostgreSQL, MongoDB single/replica, and MongoDB sharded live smoke evidence.
- RHEL live validation is blocked because `NDB_RHEL_9_6_IMAGE_URI` and `NDB_RHEL_9_7_IMAGE_URI` are missing from the resolved 1Password environment.

# Active Plan: Final Customization Profile Review Fixes

- [x] Add a failing selftest for scalar customization phase `roles` values.
- [x] Add a focused build-time customization probe for `enterprise-example` so `customization_repo_root` must be present in generated vars.
- [x] Pass `customization_repo_root` through generated Packer/site Ansible vars.
- [x] Update both customization_profile roles so controller-only `vars_files` and `extra_role_paths` checks run on localhost and loaded vars use controller paths.
- [x] Strengthen phase role-list validation to reject scalar strings and mappings.
- [x] Mark stale Task 6/7 commit checklist items complete and add final review-fix notes.
- [x] Run selftests, syntax checks, focused build-time probes for 2.10 and 2.9 where possible, representative dry-runs, `git diff --check`, and shell syntax checks.
- [x] Stage only review-fix files and commit `Harden customization profile validation`.

# Active Plan Review: Final Customization Profile Review Fixes

- Added regression selftests for scalar and mapping `roles` values; captured the intended red failure before hardening the role assertion.
- Added a dry-run/generated-vars selftest that feeds the generated Ansible vars into a local build-time `customization_profile` role probe with `enterprise-example`.
- `build.sh` now passes `customization_repo_root` in generated Packer/site Ansible vars.
- Both NDB 2.9 and 2.10 customization_profile roles now resolve relative profile and vars files against `customization_repo_root`, stat controller-only paths on localhost, and reject string/mapping phase roles.
- Verification passed with full selftests, both customization preflight syntax checks, generated-vars build-time probes for 2.10 and 2.9, representative customized dry-runs, shell syntax checks, and `git diff --check`.

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
- [x] Ask the user to review the written spec before implementation planning.

# Active Plan Review: MongoDB Image Build and Validation Design

- The current matrices contain MongoDB rows for NDB 2.9 and 2.10, but all are metadata-only today.
- The current playbooks and validation helper are PostgreSQL-specific; MongoDB needs first-class role dispatch before live builds can run.
- The user approved support for MongoDB single-instance and sharded-cluster validation, using the recommended local sharded topology inside validation instead of a shallow package-only check.
- The written spec normalizes sharded topology into `deployment` metadata instead of fake OS versions such as `9.7 (sharded)`.

# Active Plan: MongoDB Implementation Plan

- [x] Create detailed implementation plan from the approved MongoDB design spec.
- [x] User selects execution mode for implementation.

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
- [x] Continue remaining MongoDB provisioning, validation, README, offline verification, and live Prism validation tasks one task at a time.

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

# Worker Task 3 Review Fix Plan: Customization Dry-Run Preflight Ordering

**Goal:** Fix only the Task 3 review finding where customized dry-runs crash before reporting missing `ansible-playbook`.

**Files:**
- Modify: `build.sh`
- Modify: `scripts/selftest.sh`
- Modify: `tasks/todo.md`

- [x] Add a selftest proving customized dry-run without `ansible-playbook` prints the summary and reports `ansible-playbook=missing`.
- [x] Skip customized dry-run preflight only when `ansible-playbook` is missing, while keeping live/preflight customization builds protected by an early required-command check.
- [x] Verify full selftests, customized dry-run with Ansible present, missing-Ansible dry-run reproduction, and `git diff --check`.

# Worker Task 3 Review Fix Plan: Customization Preflight Profile Validation

**Goal:** Fix only the remaining Task 3 review finding where customized `--preflight` exits before validating the selected customization profile contract.

**Files:**
- Modify: `build.sh`
- Modify: `scripts/selftest.sh`
- Modify: `tasks/todo.md`

- [x] Add a selftest proving customized `--preflight` invokes customization profile validation before Prism/source-image preflight.
- [x] Move customized `--preflight` profile validation ahead of source-image preflight while preserving missing-`ansible-playbook` early failure.
- [x] Preserve customized dry-run without `ansible-playbook` friendly summary behavior.
- [x] Run requested verification probes and `git diff --check`.
- [x] Stage only Task 3 fix files and commit with the requested message.

# Worker Task 3 Review Fix Review: Customization Preflight Profile Validation

- Added selftest coverage proving customized `--preflight` validates the selected profile before Prism/source-image checks.
- `build.sh --preflight --customization-profile <bad>` now runs `run_customization_preflight` first and fails with the Ansible customization profile contract error.
- Direct absolute customization profile paths are passed to preflight Ansible unchanged instead of being prefixed with the repo root.
- Verified customized dry-run still reports missing `ansible-playbook` with the friendly summary instead of crashing.
- [x] Self-review staged files and commit `Fix customization preflight prerequisite reporting`.

# Worker Task 3 Review Fix Review: Customization Dry-Run Preflight Ordering

- Added selftest coverage for a customized dry-run with a constrained `PATH` that intentionally lacks `ansible-playbook`.
- `build.sh` now reports the dry-run summary with `ansible-playbook=missing` instead of invoking a missing command.
- Customized dry-runs still run the Ansible customization preflight when `ansible-playbook` is present.
- Customized live builds and `--preflight` runs now fail early through `require_commands "ansible-playbook"` when Ansible is unavailable.
- Verification passed with `bash scripts/selftest.sh`, the required customized dry-run using `/tmp/ndb-ansible-2.18/bin`, the missing-Ansible dry-run reproduction, a missing-Ansible customized `--preflight` probe, and `git diff --check`.

# Active Plan Review: MongoDB Implementation Execution

- Task 1 commit `facf389` validates MongoDB matrix metadata and adds self-test coverage for role/db-type mismatches, required edition/deployment metadata, invalid deployment values, duplicate deployments, duplicate grouping, and fake topology encoded in buildable `os_version` values.
- Task 1 verification passed with `bash scripts/selftest.sh`, `scripts/matrix_validate.sh ndb/*/matrix.json`, shell syntax checks, and targeted invalid-input probes.
- The written Task 2 plan originally expected five sharded-readiness rows, but its own row conversion scope produces eight: six NDB 2.9 community rows on Rocky/RHEL plus two NDB 2.10 Enterprise rows on RHEL.
- Task 2 commit `0617a85` converted 9 buildable MongoDB rows in each NDB matrix, removed fake sharded `os_version` values, and added matrix coverage self-tests.
- Task 2 review found the exact sharded-readiness guard should not glob future release matrices; it now scopes the exact count to NDB 2.9 and 2.10 only.
- Task 2 final verification passed with `bash scripts/selftest.sh`, `scripts/matrix_validate.sh ndb/*/matrix.json`, `jq empty ndb/2.9/matrix.json ndb/2.10/matrix.json`, and `git diff --check`.

# Worker Task 4 Review Fix Plan: Custom Profile Role Paths

**Goal:** Fix only the Task 4 review finding where profile `extra_role_paths` pass customization preflight but are omitted from the Packer `ANSIBLE_ROLES_PATH`.

**Files:**
- Modify: `build.sh`
- Modify: `scripts/selftest.sh`
- Modify: `tasks/todo.md`

- [x] Add a failing selftest proving a temporary profile `extra_role_paths` entry appears in the customized dry-run/Packer roles path preview.
- [x] Include selected profile `extra_role_paths` in `customization_roles_path_env`, normalizing relative entries to absolute repo paths.
- [x] Preserve non-customized behavior: no `ANSIBLE_ROLES_PATH` override when customization is disabled.
- [x] Run requested verification and commit `Include custom profile role paths in builds`.

# Worker Task 4 Review Fix Review: Custom Profile Role Paths

- Added selftest coverage using a temporary `customizations/local` profile with a relative `extra_role_paths` entry.
- `build.sh` now extracts selected profile `extra_role_paths` with Ansible, normalizes relative paths under the repo root, and appends them to the generated `ANSIBLE_ROLES_PATH`.
- Customized dry-runs and Packer builds now preview/use built-in roles, example customization roles, `customizations/local`, and any selected profile extra role paths.
- Non-customized dry-runs still show `default ansible.cfg roles_path`, preserving the no-override behavior when customization is disabled.
- Verification passed with selftests, customized dry-run proof, non-customized dry-run proof, both site playbook syntax checks, `packer fmt -check packer`, and `git diff --check`.

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

# Worker Task 8 Plan: MongoDB README and Operator Guidance

**Goal:** Update the beginner operator README so MongoDB buildable rows, validation behavior, matrix metadata, and live-suite commands match the implemented MongoDB pipeline.

**Files:**
- Modify: `README.md`
- Modify: `scripts/selftest.sh`
- Modify: `tasks/todo.md`

- [x] Add the README MongoDB guidance self-test to `scripts/selftest.sh`.
- [x] Run `bash scripts/selftest.sh` and capture the expected red failure before README changes.
- [x] Update the README opening, quick-start/common commands, validation explanation, matrix guidance, drafting prompt, roadmap, and MongoDB SELinux policy note.
- [x] Run requested verification: self-tests, shell syntax checks, matrix validation, and whitespace checks.
- [x] Self-review the diff, document results here, and commit `Document MongoDB image builds`.

# Worker Task 8 Review: MongoDB README and Operator Guidance

- Captured the intended red failure after adding the README guard: `FAIL: README missing MongoDB test command`.
- Updated the README opening to say PostgreSQL and MongoDB rows are build-ready while other engines can remain metadata-only.
- Added MongoDB dry-run, one-row production build, live suite, and 1Password-wrapped live suite commands.
- Documented MongoDB validation in plain language: service/version/edition checks for single-instance rows, temporary local replica-set smoke tests, and temporary local sharded topology smoke tests that add and verify one shard before cleanup.
- Documented `mongodb_edition`, `deployment`, Enterprise sharded-cluster rows, matrix drafting guidance, artifact validation dispatch, and the Red Hat/Rocky pinned MongoDB SELinux policy source requirement.
- Verification passed: `bash scripts/selftest.sh`; `bash -n build.sh test.sh scripts/*.sh ansible/2.9/roles/validate_mongodb/files/*.sh ansible/2.10/roles/validate_mongodb/files/*.sh`; `scripts/matrix_validate.sh ndb/*/matrix.json`; `git diff --check`.
- Self-review found no out-of-scope file changes beyond `README.md`, `scripts/selftest.sh`, and `tasks/todo.md`.
- Note: live Prism MongoDB builds were not run in this documentation-only worker task; coverage here is offline README/self-test validation.

# Final Offline Verification: MongoDB Pipeline

- [x] Run shell syntax checks for `build.sh`, `test.sh`, `scripts/*.sh`, and MongoDB validation smoke scripts.
- [x] Run full shell self-tests.
- [x] Run matrix validation for all NDB matrices.
- [x] Run Ansible syntax checks for NDB 2.9 and NDB 2.10 site playbooks with the Ansible 2.18 runtime first in `PATH`.
- [x] Run Packer formatting and validation checks.
- [x] Run MongoDB dry-run examples for NDB 2.10 Rocky Linux 9.7 MongoDB 8.0 and NDB 2.9 Ubuntu Linux 22.04 MongoDB 7.0 with `--validate --validate-artifact`.
- [x] Run whitespace and git status checks.

# Final Offline Verification Review

- `bash -n build.sh test.sh scripts/*.sh ansible/2.9/roles/validate_mongodb/files/*.sh ansible/2.10/roles/validate_mongodb/files/*.sh` passed.
- `bash scripts/selftest.sh` passed, including MongoDB matrix coverage, MongoDB build/test dispatch, playbook dispatch, provisioning role, validation role, artifact validation dispatch, and README guidance guards.
- `scripts/matrix_validate.sh ndb/*/matrix.json` passed for NDB 2.9 and NDB 2.10.
- Both Ansible syntax checks passed:
- `PATH="/tmp/ndb-ansible-2.18/bin:$PATH" ANSIBLE_CONFIG=ansible/2.9/ansible.cfg ansible-playbook --syntax-check -i localhost, -c local ansible/2.9/playbooks/site.yml`
- `PATH="/tmp/ndb-ansible-2.18/bin:$PATH" ANSIBLE_CONFIG=ansible/2.10/ansible.cfg ansible-playbook --syntax-check -i localhost, -c local ansible/2.10/playbooks/site.yml`
- `packer fmt -check packer` passed.
- `packer validate` passed for a representative NDB 2.10 MongoDB 8.0 Rocky Linux 9.7 configuration and printed `The configuration is valid.`
- The NDB 2.10 Rocky Linux 9.7 MongoDB 8.0 dry run showed `Provisioning role: mongodb`, `mongodb_edition: community`, and `mongodb_deployments: ["single-instance","replica-set"]`.
- The NDB 2.9 Ubuntu Linux 22.04 MongoDB 7.0 dry run showed `Provisioning role: mongodb`, `mongodb_edition: community`, and `mongodb_deployments: ["single-instance","replica-set"]`.
- `git diff --check` passed and `git status --short --branch` was clean before recording this review note.

# Live MongoDB Validation Status

- [x] Check whether Prism credentials can be resolved without printing secret values.
- [x] Run representative non-RHEL live MongoDB validation.
- [x] Check RHEL live MongoDB validation availability; RHEL image variables are missing, so this run is blocked.
- [x] Confirm MongoDB builder and validation VM cleanup in Prism for the representative live validation runs.

# Live MongoDB Validation Review

- Live Prism validation is currently blocked in this shell because the 1Password-managed environment file is not readable.
- The isolated worktree does not contain `.env`.
- The original repository `.env` at `/Users/tristan/Developer/NDB/.env` exists as a FIFO named pipe.
- A watchdog-protected probe against `/Users/tristan/Developer/NDB/.env` timed out after 20 seconds before producing any non-secret `set` or `missing` output.
- No required `PKR_VAR_*` Prism variables are present in the raw shell environment.
- Because credentials could not be resolved, no live MongoDB builds were launched and no Prism cleanup query was possible from this shell.

# Active Plan: Enterprise Customization Profiles

- [x] Add customization skeleton, committed examples, private overlay ignore rules, and README guidance.
- [x] Add `build.sh` customization profile selection and dry-run reporting.
- [x] Add Ansible profile preflight validation.
- [x] Add build-time customization phase dispatch.
- [x] Add saved-artifact customization validation dispatch.
- [x] Add manifest reporting for selected customization profiles.
- [x] Run offline verification and document live PostgreSQL/MongoDB profile smoke as pending controller/human environment decision.

# Active Plan Review: Enterprise Customization Profiles

- Task 1 added the static customization skeleton self-test and confirmed the intended initial failure: `FAIL: missing enterprise example profile`.
- Added the committed `enterprise-example` profile and safe example variables, example README files, and the gitignored `customizations/local` placeholder.
- Added private overlay ignore rules for `customizations/local/**` while keeping the local README and `.gitkeep` tracked.
- Added the beginner-facing `Customize The Image` README section before `Validation` with the exact starter dry-run command.
- Verification passed with `bash scripts/selftest.sh` and `git diff --check`.

# Worker Task 2 Plan: Build Script Profile Selection And Dry-Run Reporting

**Goal:** Make the documented customization dry-run command runnable by wiring profile selection into `build.sh` and reporting it in dry-run output.

**Files:**
- Modify: `scripts/selftest.sh`
- Modify: `build.sh`
- Modify: `README.md`
- Modify: `tasks/todo.md`

- [x] Add customization profile CLI static self-tests.
- [x] Run `bash scripts/selftest.sh` and capture the intended failure before implementation.
- [x] Add `build.sh` customization usage text, variables, and parser cases.
- [x] Add customization profile resolution from CLI/env/local profile paths.
- [x] Pass customization profile metadata into generated Ansible vars JSON.
- [x] Add dry-run customization profile reporting.
- [x] Keep README beginner-facing customization docs accurate for the runnable dry-run command.
- [x] Run `bash scripts/selftest.sh`.
- [x] Run the documented customization dry-run command and confirm enabled/profile-file output.
- [x] Run `git diff --check`.
- [x] Commit only Task 2 files with message `Add customization profile selection`.

# Worker Task 2 Review: Build Script Profile Selection And Dry-Run Reporting

- Added CLI static guards and confirmed the intended initial failure: `FAIL: build.sh missing customization profile flag`.
- Added `--customization-profile`, `--no-customizations`, and `NDB_CUSTOMIZATION_PROFILE` profile resolution for committed and local profile paths.
- Added customization profile metadata to generated Ansible vars JSON.
- Added dry-run reporting for enabled state, profile name, profile file, env default usage, and explicit disablement.
- Updated the README customization paragraph so the documented starter command matches the new behavior.
- Verification passed with `bash scripts/selftest.sh`, the documented MongoDB customization dry-run command, and `git diff --check`.

# Worker Task 3 Plan: Ansible Profile Preflight

**Goal:** Validate selected customization profiles with Ansible before dry-run or live build execution continues.

**Files:**
- Modify: `scripts/selftest.sh`
- Create: `ansible/2.9/roles/customization_profile/defaults/main.yml`
- Create: `ansible/2.9/roles/customization_profile/tasks/main.yml`
- Create: `ansible/2.10/roles/customization_profile/defaults/main.yml`
- Create: `ansible/2.10/roles/customization_profile/tasks/main.yml`
- Create: `ansible/2.9/playbooks/customization_preflight.yml`
- Create: `ansible/2.10/playbooks/customization_preflight.yml`
- Modify: `build.sh`
- Modify: `README.md`
- Modify: `tasks/todo.md`

- [x] Add customization profile Ansible preflight self-tests.
- [x] Run `bash scripts/selftest.sh` and capture the intended failure before implementation.
- [x] Add `customization_profile` role defaults and tasks for NDB 2.9 and 2.10.
- [x] Add `customization_preflight.yml` playbooks for NDB 2.9 and 2.10.
- [x] Run customization preflight from `build.sh` when a profile is selected.
- [x] Report `ansible-playbook` as a dry-run prerequisite only when customization needs it.
- [x] Update README and task notes for preflight behavior.
- [x] Run Task 3 verification and commit only Task 3 files.

# Worker Task 3 Review: Ansible Profile Preflight

- Added Ansible preflight static guards and confirmed the intended initial failure: `FAIL: missing customization preflight playbook 2.9`.
- Added matching `customization_profile` defaults and tasks for NDB 2.9 and 2.10.
- Added matching `customization_preflight.yml` playbooks for NDB 2.9 and 2.10.
- `build.sh` now validates a selected customization profile with `ansible-playbook` before dry-run output or live build execution continues.
- Dry-run prerequisite reporting now includes `ansible-playbook` only when customization is enabled and artifact validation has not already reported it.
- README now explains that selected profiles are validated even during dry runs.
- Verification passed with `bash scripts/selftest.sh`, the required MongoDB customization dry-run command, and `git diff --check`.

# Worker Task 4 Plan: Build-Time Customization Phase Dispatch

**Goal:** Run selected customization profile phases during image builds while keeping saved-artifact validation and manifest reporting for later tasks.

**Files:**
- Modify: `scripts/selftest.sh`
- Modify: `packer/variables.pkr.hcl`
- Modify: `packer/database.pkr.hcl`
- Modify: `build.sh`
- Modify: `ansible/2.9/playbooks/site.yml`
- Modify: `ansible/2.10/playbooks/site.yml`
- Create: `customizations/examples/internal-ca/roles/custom_internal_ca/tasks/main.yml`
- Create: `customizations/examples/monitoring-agent/roles/custom_monitoring_agent/tasks/main.yml`
- Create: `customizations/examples/os-hardening/roles/custom_os_hardening/tasks/main.yml`
- Modify: `README.md`
- Modify: `tasks/todo.md`

- [x] Add build-time dispatch selftests.
- [x] Run `bash scripts/selftest.sh` and capture the intended failure before implementation.
- [x] Add the Packer `ansible_roles_path_env` variable and pass it to the Ansible provisioner.
- [x] Add `build.sh` roles-path generation, Packer variable wiring, and dry-run reporting.
- [x] Dispatch `pre_common`, `post_common`, `post_database`, and build-time `validate` customization phases in both site playbooks.
- [x] Create install example roles for internal CA, monitoring agent, and OS hardening.
- [x] Update README/tasks for beginner-facing build-time behavior.
- [x] Run Task 4 verification and commit only Task 4 files.

# Worker Task 4 Review: Build-Time Customization Phase Dispatch

- Added build-time dispatch guards and captured the intended red failure: `FAIL: Packer variables missing ansible_roles_path_env`.
- Added `ansible_roles_path_env` to Packer variables and Ansible provisioner environment so `build.sh` can supply customization role paths without editing `ansible.cfg`.
- Added `customization_roles_path_env()` in `build.sh`, reused it for preflight, passed it to Packer, and showed it in dry-run output.
- Both NDB 2.9 and NDB 2.10 site playbooks now dispatch customization phases at `pre_common`, `post_common`, `post_database`, and build-time `validate`.
- Added install example roles for `custom_internal_ca`, `custom_monitoring_agent`, and `custom_os_hardening`.
- README now explains build-time customization phase behavior in the existing beginner-facing customization section.
- Verification passed: `bash scripts/selftest.sh`; both requested Ansible syntax checks with `/tmp/ndb-ansible-2.18/bin` first in `PATH`; `packer fmt -check packer`; `git diff --check`; and the documented customization dry-run showed the generated `ansible_roles_path_env`.
- Concern: the example profile's `validate` phase names `validate_custom_enterprise`, but that role is intentionally left for Task 5 per the committed plan and this worker's scope. Build-time `--validate --customization-profile enterprise-example` will need Task 5 before that validation phase can succeed.

# Worker Task 5 Plan: Saved-Artifact Custom Validation Dispatch

**Goal:** Run selected customization profile validation roles during saved-artifact validation.

**Files:**
- Modify: `scripts/selftest.sh`
- Modify: `scripts/artifact_validate.sh`
- Create: `customizations/examples/enterprise-validation/roles/validate_custom_enterprise/tasks/main.yml`
- Modify: `build.sh`
- Modify: `README.md`
- Modify: `tasks/todo.md`

- [x] Add artifact validation selftests for customization arguments, generated playbook dispatch, custom roles path, and static role markers.
- [x] Run `bash scripts/selftest.sh` and capture the intended failure before implementation.
- [x] Add customization arguments and vars JSON wiring to `scripts/artifact_validate.sh`.
- [x] Generate artifact validation playbooks with the customization `validate` phase after database validation.
- [x] Run `ansible-playbook` with a custom `ANSIBLE_ROLES_PATH` when provided.
- [x] Create the `validate_custom_enterprise` role.
- [x] Have `build.sh` pass customization arguments to artifact validation when customization is enabled.
- [x] Update README/tasks for saved-artifact customization validation behavior.
- [x] Run Task 5 verification and commit only Task 5 files.

# Worker Task 5 Review: Saved-Artifact Custom Validation Dispatch

- Added artifact-validation selftests and captured the intended red failure: `FAIL: artifact validation missing customization profile file flag`.
- `scripts/artifact_validate.sh` now accepts customization profile flags, includes customization context in validation vars, and appends the `customization_profile` validate phase after database validation.
- Artifact validation uses the provided custom `ANSIBLE_ROLES_PATH` when present, including the `ANSIBLE_ROLES_PATH=...` form produced by `build.sh`.
- Added the `validate_custom_enterprise` example role for sample CA, monitoring, and hardening validation.
- `build.sh` now forwards selected customization profile metadata and role paths to saved-artifact validation when customization is enabled.
- README now notes that `--validate-artifact` runs profile validation roles after database validation.
- Verification passed with `bash scripts/selftest.sh`, `bash -n scripts/artifact_validate.sh build.sh`, and `git diff --check`.

# Worker Task 6 Plan: Manifest Reporting

**Goal:** Record selected customization profile metadata and custom validation status in build manifests.

**Files:**
- Modify: `scripts/selftest.sh`
- Modify: `scripts/manifest.sh`
- Modify: `build.sh`
- Modify: `README.md`
- Modify: `tasks/todo.md`

- [x] Add manifest selftests for customization fields and build.sh recording guards.
- [x] Run `bash scripts/selftest.sh` and capture the intended failure before implementation.
- [x] Initialize default customization fields in `scripts/manifest.sh`.
- [x] Add `build.sh` customization manifest JSON helper.
- [x] Set `.customization` after manifest initialization and update custom validation status around requested in-guest validation.
- [x] Update README/tasks for manifest customization behavior.
- [x] Run `bash scripts/selftest.sh`.
- [x] Run `bash -n build.sh scripts/manifest.sh`.
- [x] Run `git diff --check`.
- [x] Commit only Task 6 files with message `Record customization profiles in manifests`.

# Worker Task 6 Review: Manifest Reporting

- Added manifest selftests for customization JSON and captured the intended red failure: `FAIL: build.sh does not record customization manifest fields`.
- `scripts/manifest.sh` now initializes `.customization` with disabled defaults.
- `build.sh` now writes `.customization` from the preflight summary when available, falls back to selected profile metadata before summary generation, and records disabled defaults when no profile is selected.
- `build.sh` now marks `.customization.validation` as `running`, `passed`, or `failed` around requested in-guest custom validation.
- README now lists `customization` as a useful manifest field.
- Verification passed with `bash scripts/selftest.sh`, `bash -n build.sh scripts/manifest.sh`, and `git diff --check`.

# Worker Task 7 Plan: Final Documentation, Offline Verification, And Live Smoke

**Goal:** Finish beginner-facing customization documentation, add final README self-test guards, run local offline verification, run representative customization dry-runs, and record that live smoke is pending controller/human environment selection.

**Files:**
- Modify: `README.md`
- Modify: `scripts/selftest.sh`
- Modify: `tasks/todo.md`

- [x] Add final README customization self-test guards.
- [x] Expand README recipes for dry-run, production validate+artifact+manifest, internal CA, OpenTelemetry Collector, hardening, secrets outside git, and `customizations/local/` ignored content.
- [x] Run complete local offline verification available in this shell.
- [x] Run representative PostgreSQL and MongoDB customization dry-runs.
- [x] Update this task log with exact offline verification and dry-run results.
- [x] Run `git diff --check`.
- [x] Commit only Task 7 doc/offline files with message `Document enterprise customization profiles`.

# Active Plan Review: Enterprise Customization Profiles

- Added optional enterprise customization profiles with committed examples and ignored private overlays.
- Added Ansible-native profile preflight and build-time phase dispatch.
- Added saved-artifact custom validation dispatch.
- Added manifest reporting for selected customization profiles.
- Added the final README customization guard in `scripts/selftest.sh`.
- Expanded README customization recipes for the safe dry-run, production `--validate --validate-artifact --manifest` flow, internal CA, OpenTelemetry Collector, OS hardening, secrets outside git, validation roles, and gitignored `customizations/local/` overlays.
- Offline verification passed: `bash -n build.sh test.sh scripts/*.sh ansible/2.9/roles/validate_mongodb/files/*.sh ansible/2.10/roles/validate_mongodb/files/*.sh`; `bash scripts/selftest.sh`; `scripts/matrix_validate.sh ndb/*/matrix.json`; NDB 2.9 and 2.10 `site.yml` Ansible syntax checks; NDB 2.9 and 2.10 `customization_preflight.yml` Ansible syntax checks; `packer fmt -check packer`; and `git diff --check`.
- PostgreSQL customization dry-run passed: `./build.sh --dry-run --ci --customization-profile enterprise-example --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18` exited 0, validated the profile, showed `Enabled: true`, and showed `Profile file: customizations/profiles/enterprise-example.yml`.
- MongoDB customization dry-run passed: `./build.sh --dry-run --ci --customization-profile enterprise-example --ndb-version 2.10 --db-type mongodb --os "Rocky Linux" --os-version 9.7 --db-version 8.0` exited 0, validated the profile, showed `Enabled: true`, and showed `Profile file: customizations/profiles/enterprise-example.yml`.
- Live PostgreSQL and MongoDB profile smoke builds were not launched by this worker per Task 7 handoff instructions; live smoke remains pending controller/human environment decision, including source image UUID choice, Prism credentials, exact image names, manifest names, validation status, and cleanup confirmation.
- Controller follow-up: `/Users/tristan/Developer/NDB/.env` is present as a 1Password-managed FIFO, but the `op run --env-file /Users/tristan/Developer/NDB/.env -- ...` credential probe produced no output and was killed. This branch also does not include the separate `--source-image-uuid` work, so live smoke should either use supported source-image options on this branch or first integrate the source-image UUID changes.
