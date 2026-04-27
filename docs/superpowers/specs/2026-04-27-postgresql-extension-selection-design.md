# PostgreSQL Extension Selection Design

Date: 2026-04-27

## Goal

Make PostgreSQL extension installation explicit, release-note-aware, and DBA-driven.

The current matrix can make extension lists look like default install sets. That is the wrong operator model. A DBA normally installs only the extensions required by the workload. The project should therefore separate Nutanix release-note qualification metadata from the extensions selected for a specific image build.

The tool should guide beginners toward qualified choices, warn clearly about advanced choices, and still allow experienced DBAs to build images with installable extensions that are not listed as qualified for the selected matrix row.

## Non-Goals

- Do not install every qualified extension by default.
- Do not treat Nutanix qualification as a hard block.
- Do not add a new language, rich TUI dependency, or package manager dependency.
- Do not make the wizard a second build engine.
- Do not claim vendor support policy beyond what the release notes state.
- Do not validate extensions that the user did not select for the build.

## Policy Model

Use an advisory qualification model.

For each PostgreSQL build, the project should distinguish:

- `qualified_extensions`: extensions listed in Nutanix release notes for the selected NDB version, OS version, PostgreSQL distribution, and PostgreSQL version.
- `installable_extensions`: extensions the automation knows how to package, configure, create, and validate.
- `selected_extensions`: extensions the user explicitly asked to install for this image.

Default `selected_extensions` should be empty.

If a selected extension is not installable, the build should fail before Packer starts. If a selected extension is installable but not listed in `qualified_extensions` for the selected row, the build should continue with a clear warning.

Preferred warning language:

```text
Extension <name> is installable by this tool, but is not release-note-qualified for this matrix row.
```

Avoid wording such as "unsupported" because that can imply a vendor support decision outside the scope of this project.

## User Experience

Beginners should see a simple story:

1. Pick an NDB version and image row.
2. PostgreSQL extensions are optional.
3. Qualified extensions are the safest release-note-aligned choices.
4. Select only the extensions the workload needs.
5. Advanced selections outside the qualified list are allowed, but warned.

Experienced users should be able to bypass the wizard and use `build.sh` directly.

Proposed CLI behavior:

```sh
./build.sh --ci --ndb-version 2.10 --db-type postgresql --os "Rocky Linux" --os-version 9.7 --db-version 18
./build.sh --ci --ndb-version 2.10 --db-type postgresql --os "Rocky Linux" --os-version 9.7 --db-version 18 --extensions pgvector,postgis
./build.sh --ci --ndb-version 2.10 --db-type postgresql --os "Rocky Linux" --os-version 9.7 --db-version 18 --extensions none
```

Omitting `--extensions` and passing `--extensions none` should both mean no PostgreSQL extensions are installed.

A future-friendly shortcut may be added for coverage workflows:

```sh
./build.sh --ci ... --extensions all-qualified
```

That shortcut should select only extensions that are both release-note-qualified for the row and installable by the project.

## Matrix Data

PostgreSQL matrix rows should stop using `extensions` as an install list.

Use:

```json
{
  "qualified_extensions": ["pgvector", "postgis", "pgaudit"],
  "qualified_extensions_empty_reason": "Nutanix release notes do not list qualified PostgreSQL extensions for this row yet."
}
```

Rules:

- Buildable PostgreSQL rows should include `qualified_extensions` as a list.
- Empty or omitted qualification should require `qualified_extensions_empty_reason`.
- Legacy `extensions` should be migrated away or rejected once the new model is implemented.
- Extension names should be normalized to project names, with explicit mappings from release-note spellings such as `pg_vector` to `pgvector` and `pg_logical` to `pglogical`.

The matrix should record release-note metadata only. It should not decide what gets installed by default.

## Installable Catalog

The project needs one authoritative installable extension catalog.

The catalog may be derived from existing Ansible defaults if that stays simple, or stored as a small shell/JQ-readable metadata file if that is clearer. The important rule is that `build.sh`, validation, and the wizard must agree on the same installable set.

The first implementation can expose only extensions already handled by the Ansible roles. Qualified-but-not-installable extensions should be visible in docs or wizard messaging, but not selectable until package/configuration/validation support exists.

## Build Flow

For PostgreSQL rows, `build.sh` should:

1. Load the selected matrix row.
2. Read `qualified_extensions`.
3. Resolve `selected_extensions` from `--extensions`.
4. Validate every selected extension is installable.
5. Warn when selected extensions are outside `qualified_extensions`.
6. Pass only `selected_extensions` to Ansible as `postgres_extensions`.
7. Pass only `selected_extensions` to saved-artifact validation.
8. Record both `qualified_extensions` and `selected_extensions` in the manifest.

MongoDB rows should ignore PostgreSQL extension flags and fail early if a PostgreSQL-only extension selection is provided.

## Wizard/TUI

The wizard must be updated in the same implementation because extension selection changes user choices, generated flags, warnings, and preview text.

For PostgreSQL rows, the wizard should:

- Default to no extensions.
- Offer individual extension selection.
- Show release-note-qualified installable extensions first.
- Show other installable extensions in an advanced section.
- Warn before launch when selected extensions are not release-note-qualified for the selected row.
- Generate `--extensions <comma-list>` only when the user selects extensions.
- Keep printing the exact `build.sh --ci` command before execution.

For qualified extensions that are not installable yet, the wizard may either omit them from the selectable list or show them as informational "qualified but not implemented" entries. It must not generate selections that the build cannot satisfy.

## Validation And Errors

Validation should happen before expensive work whenever possible.

Expected behavior:

- Unknown extension: fail before Packer.
- Known but not installable extension: fail before Packer.
- Installable but not release-note-qualified extension: warn and continue.
- No selected extensions: install and validate no PostgreSQL extensions.
- `--extensions all-qualified`: select qualified extensions that are installable; warn if qualified extensions are skipped because implementation support is missing.

Post-build validation must check only selected extensions. It should not check all qualified extensions.

## Testing

Offline tests should cover:

- `--extensions` omitted means no extensions.
- `--extensions none` means no extensions.
- Comma-separated extension parsing.
- Unknown extension failure before Packer.
- PostgreSQL extension flags rejected for MongoDB rows.
- Installable-but-not-qualified warning behavior.
- Manifest preview or generated-vars output includes both qualified and selected extension lists.
- Wizard command generation with individual extension selections.
- Wizard warning preview for advanced non-qualified selections.
- Matrix validation rejects ambiguous legacy `extensions` usage after migration.

Live validation should focus on representative selected-extension builds, not every possible combination by default. A coverage mode can exercise `all-qualified` where practical.

## Documentation

The README must be updated during implementation.

It should explain:

- PostgreSQL extensions are optional.
- DBAs should install only what their workload requires.
- Qualified extensions come from Nutanix release notes.
- The tool warns, but does not block, when an installable extension is outside the qualified list for the selected row.
- The wizard is the recommended beginner path for single-image extension selection.
- Direct CLI users can pass `--extensions`.

Agent-only maintenance rules should remain in `AGENTS.md` and `tasks/lessons.md`, not in the beginner README.

## Migration Plan

Implementation should migrate in a small number of clear steps:

1. Add the installable extension catalog and CLI parsing tests.
2. Add `qualified_extensions` matrix validation.
3. Migrate matrix rows from install-list `extensions` to advisory `qualified_extensions`.
4. Update `build.sh` to pass selected extensions instead of matrix extensions.
5. Update the wizard for individual extension selection and warnings.
6. Update artifact validation and manifests.
7. Update README, `AGENTS.md`, and `tasks/lessons.md`.
8. Run offline verification before any live build.

## Open Decisions Resolved

- Qualification is advisory, not a hard gate.
- The default extension selection is empty.
- DBAs can individually select extensions.
- The wizard must change with this feature.
- The matrix stores release-note qualification metadata, not default install behavior.
- Warnings should say "not release-note-qualified for this matrix row" rather than "unsupported."
