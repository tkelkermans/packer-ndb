# AGENTS.md

This file is project memory for Codex agents working in this repository. Keep it practical, current, and focused on rules that prevent repeated mistakes.

## Project Purpose

- This repository builds Nutanix Database Service image artifacts with Packer, Terraform-backed Packer plugins, Ansible, and shell.
- Buildable matrix rows currently use `provisioning_role=postgresql` for PostgreSQL Community Edition and `provisioning_role=mongodb` for MongoDB.
- Metadata-only rows may document support information, but `build.sh` must reject them until matching Packer/Ansible implementation exists.

## Tooling Rules

- Keep operator-facing orchestration limited to Packer, Terraform, Ansible, and shell unless the user explicitly approves another language.
- Prefer simple shell and `jq` helpers over Python or package-managed helper CLIs.
- Do not add rich TUI dependencies such as `dialog`, `whiptail`, `gum`, or `fzf` unless the user explicitly approves the dependency tradeoff.
- Use `rg` / `rg --files` for searching when available.

## Documentation Boundaries

- Keep the README beginner-facing. It should explain how to use the tool, not carry internal maintainer rules for agents.
- Every behavior change should update the README when it changes how a human operator uses the tool.
- Put agent-only maintainer rules in `AGENTS.md` and durable mistakes/patterns in `tasks/lessons.md`.
- When changing the README, keep examples copy-pasteable and explain what each command does before showing advanced variants.

## Planning And Tracking

- For non-trivial changes, write or update the active plan in `tasks/todo.md` before implementation.
- Mark checklist items complete as work progresses and add a short review/result section when done.
- `docs/superpowers/specs/*.md` and `docs/superpowers/plans/*.md` may contain historical blueprint checkboxes; `tasks/todo.md` is the execution tracker for current branch state.
- After a user correction, update `tasks/lessons.md` with the reusable rule that would have prevented it.

## Build Wizard / TUI

- `scripts/build_wizard.sh` is a thin shell wrapper for single-image builds. It must generate ordinary `./build.sh --ci ...` commands rather than becoming a second build engine.
- When adding or changing single-image build behavior, update the shell wizard/TUI in the same work item if the change affects user choices, generated flags, warnings, validation defaults, or preview text.
- PostgreSQL extension matrix data is advisory release-note metadata. Use `qualified_extensions` for what Nutanix release notes qualify, and use build-time `--extensions` / wizard selections for what gets installed.
- Do not treat `qualified_extensions` as default installs. Default selected PostgreSQL extensions should be empty.
- When changing extension choices, warnings, validation defaults, or generated flags, update `scripts/build_wizard.sh` in the same change.
- Keep the wizard print-only path safe: it must be possible to preview a command without Prism credentials and without starting Packer.

## Matrix And Release Rules

- Run `scripts/matrix_validate.sh ndb/*/matrix.json` after matrix edits.
- Buildable PostgreSQL rows with empty or missing `qualified_extensions` must include a non-empty `qualified_extensions_empty_reason`.
- MongoDB rows require `mongodb_edition` and a non-empty `deployment` list using `single-instance`, `replica-set`, and/or `sharded-cluster`.
- Do not encode MongoDB topology in `os_version`; use `deployment` metadata.
- When adding a new NDB release, scaffold first if useful, then compare the copied matrix against the release notes before building.

## Source Images And Environment

- Slow Prism-side image imports over VPN are common. Prefer reusing or pre-staging cluster images with `--source-image-name` or `--source-image-uuid` instead of retrying long local uploads.
- Duplicate source image names can exist in Prism. Use `--source-image-uuid` when name/URI lookup is ambiguous.
- RHEL source images are licensed and short-lived. RHEL live builds are blocked until `NDB_RHEL_9_6_IMAGE_URI` or `NDB_RHEL_9_7_IMAGE_URI` resolves to a non-empty value.
- When the user says a 1Password-managed `.env` is mounted, verify with `op run --env-file .env -- ...` that required values resolve non-empty before launching expensive live matrix runs.
- Never print secret values while checking environment readiness.

## Validation Rules

- Do not claim work is complete without proving it. Prefer, as applicable:
  - `bash -n build.sh test.sh scripts/*.sh`
  - `bash scripts/selftest.sh`
  - `scripts/matrix_validate.sh ndb/*/matrix.json`
  - `packer fmt -check packer`
  - representative `packer validate`
  - Ansible syntax checks for affected NDB versions
  - `git diff --check`
- Post-build artifact validation clones the saved image into a disposable VM, powers it on, waits for SSH, runs the matching validation role, and should delete the VM afterward.
- Artifact validation cloud-init `user_data` must be base64-encoded, and cloned VMs may need explicit power-on after creation.
- If validation succeeds but cleanup fails, the build should fail rather than hide a leaked VM.
- MongoDB validation should cover installed version/edition and the requested deployment shapes. Sharded validation uses local temporary processes and must clean them up.
- PostgreSQL extension validation must fail when a matrix-listed extension is skipped or missing.

## Customization Profiles

- Enterprise customizations live in committed examples plus ignored local overlays under `customizations/local/`.
- Keep real enterprise tokens, tenant URLs, private certificates, private keys, and customer-specific repository details out of git.
- Selected customization profiles must be preflighted before dry-run or live build work continues.
- Example roles that touch system paths, services, trust stores, sysctl, or validation reads should use privilege escalation.
- Production customization profiles should include validation roles so both `--validate` and `--validate-artifact` can prove the customization landed.

## Live Build Evidence And Known Gaps

- Representative live evidence has covered NDB 2.10 PostgreSQL 18 on Rocky Linux 9.7, NDB 2.10 MongoDB 8.0 on Rocky Linux 9.7, and NDB 2.9 MongoDB 8.0 on Rocky Linux 9.6.
- NDB 2.9 MongoDB artifact validation exercised local replica-set and sharded-cluster smoke scripts on the saved artifact.
- Non-RHEL PostgreSQL extension rows have been live validated across representative NDB 2.9 and 2.10 rows.
- A full MongoDB non-RHEL matrix live sweep has not been completed.
- RHEL live validation has been blocked by missing resolved RHEL image URI variables.

## Git Hygiene

- The worktree may contain unrelated user files. Do not revert or stage unrelated changes.
- Current recurring untracked local files have included `.vscode/` and `package-lock.json`; leave them alone unless the user asks.
- Use non-interactive git commands. Do not amend commits unless explicitly requested.
- Before asking another agent or process to verify/commit, make sure required files are committed or otherwise available in that workspace.
