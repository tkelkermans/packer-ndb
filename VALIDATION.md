# Validation Status

This document describes how this project is validated, and which parts of the
support matrix have been proven on real hardware. It contains no Prism
hostnames, IP addresses, credentials, image UUIDs, or customer-specific values.

## Validation Layers

Each layer costs more and proves more than the one above it:

| Layer | What it proves | Needs a lab? |
|---|---|---|
| Static gates | Scripts parse and lint, matrices satisfy every schema rule, playbooks are syntactically valid, Packer template is valid | No |
| In-guest validation (`--validate`) | The engine, extensions, HA binaries and NDB prerequisites are correct inside the builder VM before capture | Yes |
| Artifact validation (`--validate-artifact`) | The **saved image** boots as a fresh VM, is reachable, and still satisfies every check | Yes |
| NDB E2E (`scripts/ndb_e2e_validate.sh`) | NDB can register the image, create a software profile, and provision a working database from it | Yes |

Run the static gates before trusting any change:

```bash
bash -n build.sh test.sh scripts/*.sh scripts/selftests/*.sh
printf '%s\n' build.sh test.sh scripts/*.sh scripts/selftests/*.sh | xargs -n1 shellcheck -S warning
jq empty images.json ndb/*/matrix.json
scripts/matrix_validate.sh ndb/*/matrix.json
bash scripts/selftest.sh
packer fmt -check packer/
for v in ansible/*/; do ANSIBLE_ROLES_PATH="${v}roles" ansible-playbook --syntax-check "${v}playbooks/site.yml"; done
for v in ansible/*/; do ANSIBLE_ROLES_PATH="${v}roles" ansible-lint --profile basic "$v"; done
for roles_dir in customizations/examples/*/roles; do ANSIBLE_ROLES_PATH="$roles_dir" ansible-lint --profile basic "$roles_dir"; done
git diff --check
```

The same gates run in CI on every pull request, so a green CI run means the
whole list above passed.

## Proven On Hardware

These paths have completed every layer, including NDB provisioning a live
database from the built image:

| Path | Build | In-guest | Artifact boot | NDB E2E |
|---|---|---|---|---|
| Rocky Linux 9.7 / PostgreSQL 18 | pass | pass | pass | pass |
| Ubuntu 24.04 / PostgreSQL 18 | pass | pass | pass | — |
| Rocky Linux 9.7 / MongoDB 6.0 | pass | pass | pass | pass |

Other buildable rows in the matrix use the same roles and differ only in
package versions, but have not been re-proven recently — build them with
`--validate --validate-artifact --manifest` before relying on them.

## Checking Your Own Coverage

Manifests under `manifests/` record what you have built locally. Audit them
against the matrix:

```bash
scripts/live_coverage_audit.sh ndb/2.9/matrix.json ndb/2.10/matrix.json ndb/2.11/matrix.json
```

A manifest proves a build *happened*; it does not prove the image still exists
in Prism, because images are routinely cleaned up. Confirm the images behind
your manifests are still present before planning an E2E run:

```bash
op run --env-file=.env -- scripts/ndb_e2e_validate.sh --preflight-images
```

## Recommended live campaign order

Hardware proof is still thin relative to the buildable matrix. Prefer this
order when a lab is available (always `--preflight-images` before E2E):

1. Ubuntu 24.04 / PostgreSQL 18 **NDB E2E** (build + artifact already pass).
2. One Debian 12 PostgreSQL path (expect the known NDB storage/protection
   blocker; track as product, not more image-side dm-alias churn).
3. Rocky Linux MongoDB 7.0 and 8.0 smoke (`--validate --validate-artifact --manifest`).
4. NDB **2.11** first-of-each-OS smoke (scaffold/review landed; no live proof yet).
5. Debian 12 MongoDB (buildable in 2.11; never built here).

Orchestrate the campaign with `scripts/live_campaign.sh` (dry-run first):

```bash
scripts/live_campaign.sh --list-phases
scripts/live_campaign.sh --check-lab --skip-e2e
scripts/live_campaign.sh --dry-run --phase 1
op run --env-file=.env -- scripts/live_campaign.sh --execute --phase 1
```

From GitHub Actions (repository secrets must match `.env.example` names), run one phase at a time via the **Live validation campaign** workflow.

Metadata engines (Oracle, SQL Server, MySQL, MariaDB, EDB) stay documentation-only
until real Ansible roles exist. RHEL 9.8 / RHEL 10 HA versions remain pinned to
the RHEL 9.7 tuple until Nutanix publishes Table 4 — see `ndb/2.11/REVIEW.md`.

## Red Hat Enterprise Linux

Full live validation is not complete until the RHEL rows have successful
manifests. RHEL source images are licensed and are not committed to this
repository. To finish coverage, provide either:

- `NDB_RHEL_9_6_IMAGE_URI`, `NDB_RHEL_9_7_IMAGE_URI`, and for NDB 2.11 also
  `NDB_RHEL_9_8_IMAGE_URI` / `NDB_RHEL_10_IMAGE_URI`, or
- staged Prism image UUIDs for the matching RHEL versions (`RHEL_96_UUID`,
  `RHEL_97_UUID`, and for 2.11 `RHEL_98_UUID` / `RHEL_10_UUID`).

Also provide `NDB_RHEL_ORGID` and `NDB_RHEL_ACTIVATIONKEY` from 1Password when
the RHEL rows should use Red Hat CDN repositories. Builds use those values only
to register the temporary builder VM, then unregister and clean RHSM state
before image capture.

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
Prism image placement or SSH bootability. Finish coverage with activation-key
registration through `NDB_RHEL_ORGID` and `NDB_RHEL_ACTIVATIONKEY`, with RHEL
images that already have the required enterprise package repositories enabled,
or with a `pre_common` customization profile that enables enterprise mirrors
before the common role installs packages. Current preflight checks reject
inactive image candidates before Packer starts.

The committed `rhel-repositories-example` customization profile is a secret-free
starter for the `pre_common` path. Copy it into `customizations/local/`, point
the copied profile at the copied vars file, and add private mirror URLs or
entitled repository IDs only in the local copies.

The public tracking issue for this blocker is:
https://github.com/tkelkermans/packer-ndb/issues/2

## Commands To Finish RHEL Coverage

When RHEL source images are available, check the values without printing the
actual URIs, org ID, or activation key:

```bash
scripts/rhel_readiness.sh
```

If using staged Prism images, set stable local shell variables:

```bash
export RHEL_96_UUID="replace-with-rhel-9.6-image-uuid"
export RHEL_97_UUID="replace-with-rhel-9.7-image-uuid"
# NDB 2.11 rows also need:
# export RHEL_98_UUID="replace-with-rhel-9.8-image-uuid"
# export RHEL_10_UUID="replace-with-rhel-10-image-uuid"
```

If a staged image is present but inactive, inspect the activation plan first:

```bash
scripts/prism_image_activate.sh --image-uuid "${RHEL_97_UUID}" --cluster-name "${PKR_VAR_cluster_name}"
```

Only add `--apply` after confirming the image UUID and cluster are correct.

Before starting a long RHEL matrix run, confirm the source images can install
packages from the required RHEL repositories or enterprise mirrors. The
repository checks above prove Prism placement and SSH reachability; they do not
prove subscription or package repository readiness inside the guest.

If `NDB_RHEL_ORGID` and `NDB_RHEL_ACTIVATIONKEY` are set, the disposable probe
VM registers with the activation key, checks packages, unregisters, and cleans
RHSM state before deletion. Prove package readiness first:

```bash
scripts/source_image_ssh_probe.sh --source-image-uuid "${RHEL_96_UUID}" --rhel-repository-check --ssh-timeout 900
scripts/source_image_ssh_probe.sh --source-image-uuid "${RHEL_97_UUID}" --rhel-repository-check --ssh-timeout 900
```

If repository setup must happen during the build, run a local copy of the RHEL
repository customization profile with the RHEL rows:

```bash
./build.sh --ci --customization-profile customizations/local/rhel-repositories.yml --validate --validate-artifact --manifest --source-image-uuid "${RHEL_97_UUID}" --ndb-version 2.10 --db-type pgsql --os "Red Hat Enterprise Linux (RHEL)" --os-version 9.7 --db-version 18
```

For the full RHEL matrix, pass the same local profile through `test.sh`:

```bash
./test.sh --allow-rhel --include-os "Red Hat Enterprise Linux (RHEL)" --customization-profile customizations/local/rhel-repositories.yml --validate --validate-artifact --manifest --continue-on-error --source-image-uuid-map "rhel-9.6=${RHEL_96_UUID},rhel-9.7=${RHEL_97_UUID}" --max-parallel 1
```

Preflight every RHEL row:

```bash
./test.sh --allow-rhel --include-os "Red Hat Enterprise Linux (RHEL)" --customization-profile customizations/local/rhel-repositories.yml --preflight --source-image-uuid-map "rhel-9.6=${RHEL_96_UUID},rhel-9.7=${RHEL_97_UUID}" --max-parallel 1
```

Run the RHEL live matrix:

```bash
./test.sh --allow-rhel --include-os "Red Hat Enterprise Linux (RHEL)" --customization-profile customizations/local/rhel-repositories.yml --validate --validate-artifact --manifest --continue-on-error --source-image-uuid-map "rhel-9.6=${RHEL_96_UUID},rhel-9.7=${RHEL_97_UUID}" --max-parallel 1
```

Audit full coverage:

```bash
scripts/live_coverage_audit.sh ndb/2.9/matrix.json ndb/2.10/matrix.json ndb/2.11/matrix.json
```

To generate individual recovery commands that include both staged RHEL image
UUIDs and a local repository customization profile:

```bash
scripts/live_coverage_audit.sh --suggest-runs --customization-profile customizations/local/rhel-repositories.yml --source-image-uuid-map "rhel-9.6=${RHEL_96_UUID},rhel-9.7=${RHEL_97_UUID}" ndb/2.9/matrix.json ndb/2.10/matrix.json ndb/2.11/matrix.json
```

Completion requires:

```text
Missing live rows: 0
```
