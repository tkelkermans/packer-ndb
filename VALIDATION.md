# Validation Status

This report records the sanitized public validation state for this branch as of
May 7, 2026. It contains no Prism hostnames, IP addresses, credentials, saved
image UUIDs, manifest filenames, or customer-specific values.

## What Has Been Verified

The repository passed these local and static gates from the current branch:

```bash
bash -n build.sh test.sh scripts/*.sh
bash scripts/selftest.sh
scripts/matrix_validate.sh ndb/*/matrix.json
packer fmt -check packer
packer validate ...
ansible-playbook --syntax-check ...
git diff --check
```

The representative `packer validate` used placeholder Prism values and the NDB
2.10 PostgreSQL 18 Rocky Linux 9.7 row. The Ansible syntax checks covered both
NDB 2.9 and NDB 2.10 site and customization preflight playbooks.

Live manifests currently prove successful in-guest validation, saved-artifact
validation, and validation VM cleanup for all buildable non-RHEL rows. The live
coverage audit reports:

```text
Buildable rows: 54
Successful live rows: 35
Missing live rows: 19
```

All 19 missing rows are Red Hat Enterprise Linux rows.

## Remaining Gap

Full live validation is not complete until the RHEL rows have successful
manifests. RHEL source images are licensed and are not committed to this
repository. To finish coverage, provide either:

- `NDB_RHEL_9_6_IMAGE_URI` and `NDB_RHEL_9_7_IMAGE_URI`, or
- staged Prism image UUIDs for RHEL 9.6 and RHEL 9.7.

No staged Prism images matching RHEL naming were found during the latest
catalog check, and the RHEL source image environment values were missing.

## Commands To Finish RHEL Coverage

When RHEL source images are available, check the values without printing the
actual URIs:

```bash
scripts/rhel_readiness.sh
```

If using staged Prism images, set stable local shell variables:

```bash
export RHEL_96_UUID="replace-with-rhel-9.6-image-uuid"
export RHEL_97_UUID="replace-with-rhel-9.7-image-uuid"
```

Preflight every RHEL row:

```bash
./test.sh --allow-rhel --include-os "Red Hat Enterprise Linux (RHEL)" --preflight --source-image-uuid-map "rhel-9.6=${RHEL_96_UUID},rhel-9.7=${RHEL_97_UUID}" --max-parallel 1
```

Run the RHEL live matrix:

```bash
./test.sh --allow-rhel --include-os "Red Hat Enterprise Linux (RHEL)" --validate --validate-artifact --manifest --continue-on-error --max-parallel 1
```

Audit full coverage:

```bash
scripts/live_coverage_audit.sh ndb/2.9/matrix.json ndb/2.10/matrix.json
```

Completion requires:

```text
Missing live rows: 0
```
