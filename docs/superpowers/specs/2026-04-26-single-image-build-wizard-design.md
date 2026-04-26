# Single-Image Build Wizard Design

Date: 2026-04-26

## Goal

Make the first single-image build experience safer and easier for operators who do not know Packer, Ansible, or the project matrix format yet.

The wizard must stay a thin shell wrapper. It should guide the user through choices, generate a normal `./build.sh ...` command, and either run that command or print it. It must not become a second build engine.

## Non-Goals

- Do not add a rich TUI dependency such as `dialog`, `whiptail`, `gum`, or `fzf`.
- Do not change CI or scripted usage of `build.sh`.
- Do not support full matrix validation in the first wizard version.
- Do not hide the generated command from the user.
- Do not print secrets or resolved secret values.

## User Experience

The wizard is intended for interactive terminal use:

```sh
scripts/build_wizard.sh
```

It walks the operator through one image build:

1. Select the NDB version from `ndb/*/matrix.json`.
2. Select a buildable matrix row.
3. Choose an action: dry run, preflight, stage source, or build.
4. Choose validation options where they make sense.
5. Choose whether to write a manifest.
6. Choose a source image strategy.
7. Choose whether to apply an enterprise customization profile.
8. Review the exact generated command.
9. Choose to run the command now or print it only.

Safe defaults should favor learning and validation:

- Default action: dry run.
- Default build validation: enabled when the selected action is build.
- Default artifact validation: enabled when the selected action is build.
- Default manifest: enabled when the selected action is build.
- Default customization: none.
- Default source image strategy: matrix default.

## Architecture

Add one shell entrypoint:

```text
scripts/build_wizard.sh
```

The script owns only interactive selection and command composition. It delegates all real behavior to `build.sh`.

The first version should use portable Bash prompts and `select`-style menus. That keeps the tool aligned with the existing shell-only project direction and avoids dependency friction in restricted enterprise environments.

The generated command should always call `./build.sh --ci` plus explicit matrix selectors. Example:

```sh
./build.sh --ci --dry-run --ndb-version 2.10 --db-type mongodb --os "Rocky Linux" --os-version 9.7 --db-version 8.0
```

When the operator chooses to run the command, the wizard should execute the generated command from the repository root. When the operator chooses print-only, it should exit successfully after printing the command.

## Matrix Selection

The wizard should read `ndb/<version>/matrix.json` with `jq`.

It must only offer rows whose `provisioning_role` is buildable. Today that means:

- `postgresql`
- `mongodb`

Rows with `provisioning_role=metadata` must not appear as build choices.

The row label should be beginner-readable, for example:

```text
MongoDB 8.0 on Rocky Linux 9.7
PostgreSQL 18 on Rocky Linux 9.7
```

If the selected row needs RHEL source image variables that are missing, the wizard should warn before the final confirmation. The warning should explain that the command may be blocked until the required image URI variable is available.

## Options

The wizard should compose only existing `build.sh` options.

Actions:

- Dry run: `--dry-run`
- Preflight: `--preflight`
- Stage source image: `--stage-source`
- Build: no action flag

Build-only options:

- In-guest validation: `--validate`
- Saved-artifact validation: `--validate-artifact`
- Manifest writing: `--manifest`

Source image options:

- Matrix default: no source image override.
- Existing image name: `--source-image-name <name>`.
- Existing image UUID: `--source-image-uuid <uuid>`.
- Stage source image: select the stage-source action instead of adding a source image override.

Customization options:

- None: no customization flag.
- Disable env-selected customizations: `--no-customizations`.
- Repository profile: `--customization-profile <name>`.
- Manual path: `--customization-profile <path>`.

## Guardrails

The wizard should fail early with clear messages when required local tools are missing:

- `bash`
- `jq`

It should warn, not fail, for live-build environment values because dry-run and print-only workflows remain useful without Prism credentials.

The final confirmation screen should include:

- Selected NDB version.
- Selected database, OS, and database version.
- Selected action.
- Validation choices.
- Source image strategy.
- Customization choice.
- Exact generated command.

No secret values should be displayed.

## Testing

Add offline tests to `scripts/selftest.sh`.

The tests should feed scripted menu choices to the wizard and assert the generated command for at least:

- A default dry-run PostgreSQL command.
- A build command with `--validate`, `--validate-artifact`, and `--manifest`.
- A MongoDB row selection.
- A source image UUID override.
- A customization profile selection.

The tests should not require Prism access and should not start Packer.

## Documentation

Update the README with a beginner section that presents the wizard as the recommended first step for a single-image build:

```sh
scripts/build_wizard.sh
```

The README should explain that the wizard prints a normal `build.sh` command and that experienced users can keep using `build.sh` directly.

## Open Decisions Resolved

- The wizard targets single-image builds only.
- The implementation should use a separate wrapper script, not more logic inside `build.sh`.
- The first version should avoid rich TUI dependencies.
- Matrix validation runs stay out of scope for the first wizard.
