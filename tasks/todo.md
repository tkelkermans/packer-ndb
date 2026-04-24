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
- [ ] Execute Task 3: source image preflight and staging
- [ ] Execute Task 4: build manifest writer
- [ ] Execute Task 5: artifact validation helper
- [ ] Execute Task 6: manifest status and failure integration
- [ ] Execute Task 7: release scaffolding
- [ ] Execute Task 8: beginner README restructure
- [ ] Run final verification and document results
