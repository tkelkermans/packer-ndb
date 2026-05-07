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

The latest Prism catalog check found RHEL 9.6 and RHEL 9.7 image candidates,
and direct source-image SSH probes reached both images successfully. A
repository probe on disposable RHEL 9.6 and RHEL 9.7 source-image VMs failed
because the guests had no enabled dnf repositories, and disposable VM cleanup
succeeded.
A representative RHEL 9.7 PostgreSQL 18 live build reached Ansible, then failed
during common package installation because the guest did not have usable RHEL
package repositories enabled for standard packages such as `bison`, `gcc`,
`lvm2`, and `sshpass`.

The remaining RHEL blocker is repository readiness inside the RHEL guest, not
Prism image placement or SSH bootability. Finish coverage with RHEL images that
already have the required enterprise package repositories enabled, or with a
`pre_common` customization profile that enables those repositories before the
common role installs packages. Current preflight checks reject inactive image
candidates before Packer starts.

The committed `rhel-repositories-example` customization profile is a secret-free
starter for the `pre_common` path. Copy it into `customizations/local/`, point
the copied profile at the copied vars file, and add private mirror URLs or
entitled repository IDs only in the local copies.

The public tracking issue for this blocker is:
https://github.com/tkelkermans/packer-ndb/issues/2

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

If a staged image is present but inactive, inspect the activation plan first:

```bash
scripts/prism_image_activate.sh --image-uuid "${RHEL_97_UUID}" --cluster-name "${PKR_VAR_cluster_name}"
```

Only add `--apply` after confirming the image UUID and cluster are correct.

Before starting a long RHEL matrix run, confirm the source images can install
packages from the required RHEL and enterprise mirrors. The repository checks
above prove Prism placement and SSH reachability; they do not prove subscription
or package repository readiness inside the guest.

If repositories are already enabled in the staged image, prove package
readiness on a disposable VM first:

```bash
scripts/source_image_ssh_probe.sh --source-image-uuid "${RHEL_96_UUID}" --rhel-repository-check --ssh-timeout 900
scripts/source_image_ssh_probe.sh --source-image-uuid "${RHEL_97_UUID}" --rhel-repository-check --ssh-timeout 900
```

If repository setup must happen during the build, run a local copy of the RHEL
repository customization profile with the RHEL rows:

```bash
./build.sh --ci --customization-profile customizations/local/rhel-repositories.yml --validate --validate-artifact --manifest --source-image-uuid "${RHEL_97_UUID}" --ndb-version 2.10 --db-type pgsql --os "Red Hat Enterprise Linux (RHEL)" --os-version 9.7 --db-version 18
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
