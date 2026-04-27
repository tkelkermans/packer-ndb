# First Build Assistant Design

## Goal

Make this project easier for operators, DBAs, and platform engineers who are new to Packer and Ansible by turning `scripts/build_wizard.sh` into the default guided path for one safe image build.

## Context

The project already has a beginner-facing README, a shell wizard, `.env.example`, dry-run and preflight modes, post-build validation, manifests, PostgreSQL extension selection, MongoDB metadata, and customization profile examples.

The remaining beginner friction is not the build engine itself. It is the number of concepts a new user has to understand before the first successful image:

- local tools such as `packer`, `ansible-playbook`, `jq`, `curl`, `ssh`, and `base64`
- Packer plugin initialization
- repository SSH keys under `packer/id_rsa` and `packer/id_rsa.pub`
- `.env` versus 1Password-managed environment variables
- source image strategy
- dry run, preflight, live build, in-guest validation, artifact validation, and manifests
- PostgreSQL extension qualification versus extension installation
- MongoDB edition and deployment validation shapes
- optional enterprise customization profiles

The design keeps the operator-facing toolchain limited to shell, Packer, Terraform-backed Packer plugins, Ansible, and existing small command-line utilities. It does not introduce rich TUI dependencies or another build engine.

## Recommended Approach

Extend `scripts/build_wizard.sh` into a "first build assistant" while preserving its current role as a thin wrapper that generates ordinary `./build.sh --ci ...` commands.

The assistant should:

1. Run a friendly readiness check before matrix selection.
2. Offer safe setup help for local, non-secret assets.
3. Keep dry-run and print-only paths available without Prism credentials.
4. Stop live builds early when required prerequisites are missing.
5. Explain DBA choices in image-intent terms rather than Packer or Ansible implementation terms.

This is preferred over a separate `doctor.sh` because beginners should not need to remember multiple commands before their first build. It is preferred over README-only onboarding because the most confusing checks are environment-specific and should be detected directly.

## Non-Goals

- Do not replace `build.sh`.
- Do not create, store, or edit Prism credentials.
- Do not print secret values.
- Do not add dependencies such as `dialog`, `whiptail`, `gum`, `fzf`, Python packages, or package-managed helper CLIs.
- Do not change matrix semantics.
- Do not change Packer templates, Ansible roles, validation behavior, or build image contents.
- Do not make the wizard responsible for matrix-wide build suites. It remains for single-image builds only.

## Beginner Flow

When a user runs:

```bash
scripts/build_wizard.sh
```

the wizard should start with a short readiness phase before asking for NDB and database choices.

The readiness phase should check:

- required commands: `jq`, `cksum`, `packer`, `ansible-playbook`, `curl`, `ssh`, and `base64`
- optional command: `op`, used only for guidance when `.env` is managed by 1Password
- SSH key files: `packer/id_rsa` and `packer/id_rsa.pub`
- Packer plugin initialization status. The wizard should prefer the safe, idempotent action of offering to run `packer init packer/` over trying to infer plugin state through expensive validation.
- `.env` presence
- required live-build environment variable presence without printing values

The readiness phase should report each item as plain language:

```text
Local tools:
  jq: present
  packer: missing - install Packer before live builds

SSH key:
  packer/id_rsa.pub: missing - required for live builds and artifact validation

Environment:
  PKR_VAR_pc_username: present
  PKR_VAR_pc_password: missing
```

For missing local assets, the wizard may offer safe actions:

- create an SSH keypair with `ssh-keygen -t rsa -b 4096 -C "packer@nutanix" -f packer/id_rsa -N ""`
- run `packer init packer/`
- copy `.env.example` to `.env` if `.env` does not exist

For secrets, the wizard must only explain the next step:

- edit `.env` manually
- source `.env`
- or run through 1Password, for example:

```bash
op run --env-file .env -- scripts/build_wizard.sh
```

If the user chooses dry-run or print-only output, missing Prism credentials should be shown as warnings but should not block the command preview.

If the user chooses to run a live build, missing required commands, SSH keys, Packer initialization, or Prism variables should stop the wizard before `build.sh` runs.

## DBA And Platform Engineer Choices

After readiness, the wizard should keep asking about image intent:

- NDB version
- database family
- operating system
- database version
- action: dry run, preflight, stage source, or build
- source image strategy
- optional PostgreSQL extensions
- optional customization profile

The wizard should show a compact selected image recipe before final confirmation:

```text
Selected image recipe:
  Database: PostgreSQL 18
  OS: Rocky Linux 9.7
  NDB: 2.10
  Source image: existing Prism image UUID
  Validation: in-guest + saved artifact
  Manifest: yes
  PostgreSQL extensions: pg_stat_statements
  Image variant suffix: ext-pg-stat-statements
```

For PostgreSQL:

- default selected extensions remain empty
- each extension remains individually selectable
- choices are labeled as qualified for this matrix row or advanced installable choices that are not release-note-qualified
- the wizard explains that DBAs usually select only extensions required by the application
- the preview shows the extension image-name suffix when selected extensions change the image variant

For MongoDB:

- show `mongodb_edition` as Community or Enterprise
- show `deployment` values in human language
- explain what validation proves if validation is enabled:
  - single instance checks installed service, version, and edition
  - replica set runs a temporary local replica-set smoke test
  - sharded cluster runs a temporary local sharded topology smoke test

For customization profiles:

- present them as optional company-specific tools, certificates, hardening, and validation overlays
- keep the existing repository profile and manual path choices
- explain that private profiles, private roles, and secrets belong under `customizations/local/` or in the user's secret manager
- recommend dry-run or preflight before live customized builds

## Safety Defaults

For live builds, the wizard should recommend production safety flags:

```bash
--validate --validate-artifact --manifest
```

The user can opt out, but the prompts should make the tradeoff clear:

- `--validate` proves the temporary build VM before image capture
- `--validate-artifact` proves the saved Prism image by booting a disposable VM
- `--manifest` writes an ignored local JSON build record

Dry-run should remain the safest first action. Preflight should be the next recommended action when the user has Prism credentials and wants to confirm live readiness before spending time on a build.

The wizard must keep a safe print-only path. It must always be possible to generate and inspect the command without starting Packer.

## Error Handling

Errors should be actionable and beginner-readable.

Examples:

```text
Missing jq.
Install jq, then rerun scripts/build_wizard.sh.
```

```text
Missing packer/id_rsa.pub.
Live builds and artifact validation need this public key.
Choose "create SSH keypair" or run:
  ssh-keygen -t rsa -b 4096 -C "packer@nutanix" -f packer/id_rsa -N ""
```

```text
Prism variables are missing.
Dry-run can continue, but live builds need PKR_VAR_pc_username,
PKR_VAR_pc_password, PKR_VAR_pc_ip, PKR_VAR_cluster_name, and PKR_VAR_subnet_name.
Edit .env and run source .env, or use:
  op run --env-file .env -- scripts/build_wizard.sh
```

Warnings should distinguish safe dry-run gaps from live-build blockers.

## Documentation

The README should stay beginner-facing. It should describe the wizard as the recommended starting point, explain what the first build assistant checks, and show the shortest safe path:

```bash
scripts/build_wizard.sh
```

Then it should explain the manual CLI path as an advanced or direct-use alternative.

The README should not carry agent-only maintainer rules.

## Testing Strategy

Add or extend shell selftests for `scripts/build_wizard.sh` using temporary mini repositories and stub commands where needed.

Coverage should include:

- missing command detection prints a friendly message
- SSH key missing path offers safe key creation or stops live run
- SSH key creation path creates `packer/id_rsa` and `packer/id_rsa.pub` in a temporary repository
- Packer init offer path invokes a stub `packer init packer/`
- missing `.env` path offers to copy `.env.example` to `.env`
- environment reporting shows variable names and `present` / `missing`, never values
- dry-run and print-only flows do not require Prism credentials
- live run-now flow stops before `build.sh` when live prerequisites are missing
- PostgreSQL extension selection still emits expected `--extensions` and image suffix preview
- MongoDB row preview still shows edition and deployment shapes
- customization profile preview still emits expected `--customization-profile`
- README includes the first build assistant guidance

Run the existing verification set after implementation:

- `bash -n build.sh test.sh scripts/*.sh`
- `bash scripts/selftest.sh`
- `scripts/matrix_validate.sh ndb/*/matrix.json`
- `packer fmt -check packer`
- `git diff --check`

## Acceptance Criteria

- A new operator can run `scripts/build_wizard.sh` and see what is ready, what is missing, and what to do next without reading Packer or Ansible docs first.
- The wizard can create local SSH keys, run Packer initialization, and copy `.env.example` only after explicit user confirmation.
- The wizard never creates, edits, or prints Prism secrets.
- Dry-run and print-only command generation remain possible without live Prism access.
- Run-now live builds are blocked early when prerequisites are missing.
- PostgreSQL extension choices remain individual and default to none.
- MongoDB edition and deployment validation shapes are visible in the wizard preview.
- Customization profiles remain optional and are explained in enterprise-operator language.
- README guidance is updated for the new beginner path.
