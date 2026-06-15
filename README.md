# NDB Packer Image Builder

## What This Tool Does

This repository builds Nutanix Database Service (NDB) image artifacts with Packer, Ansible, Terraform-backed Packer plugins, and shell scripts.

The normal workflow is:

- Choose one supported row from an NDB `matrix.json` file.
- Resolve the matching operating-system source image from `images.json`.
- Build a Prism image with Packer.
- Optionally validate the temporary build VM before Packer saves the image.
- Optionally boot the saved image as a disposable VM and validate the final artifact.
- Optionally write a JSON manifest under `manifests/` so the build can be audited later.

Today, the build-ready rows are PostgreSQL Community Edition rows with `provisioning_role=postgresql` and MongoDB rows with `provisioning_role=mongodb`. Other database engines can still appear as `provisioning_role=metadata` rows so the support list is documented, but `build.sh` rejects metadata-only rows until matching Packer/Ansible roles exist.

See `VALIDATION.md` for the current public validation status, including the remaining RHEL live-validation gap.

## Quick Start

### 1. Install The Local Tools

Install these commands on your workstation:

- `packer`
- `ansible-playbook`
- `jq`
- `curl`
- `ssh`
- `base64`

For long live validation runs, prefer `ansible-core` 2.18.x. Newer Ansible controller versions can fail on some targets with module result deserialization errors before the build reaches extension validation. A temporary local runtime is enough:

```bash
python3.11 -m venv /tmp/ndb-ansible-2.18
/tmp/ndb-ansible-2.18/bin/python -m pip install 'ansible-core>=2.18,<2.19'
export PATH="/tmp/ndb-ansible-2.18/bin:$PATH"
```

The build also needs an SSH keypair in `packer/id_rsa` and `packer/id_rsa.pub`. If you need to create one:

```bash
ssh-keygen -t rsa -b 4096 -C "packer@nutanix" -f packer/id_rsa -N ""
```

Initialize the Packer plugins once on a new workstation:

```bash
packer init packer/
```

### 2. Create Your Environment File

Copy the template and edit `.env` with your Prism Central details:

```bash
cp .env.example .env
source .env
```

### 3. Use The Guided Wizard

If you are new to the project, start with the single-image wizard:

```bash
scripts/build_wizard.sh
```

The wizard does not replace `build.sh`. It asks beginner-friendly questions, shows the selected matrix row, shows PostgreSQL HA profile components and package pins when the row includes them, lets you choose PostgreSQL extensions one by one when the selected row is PostgreSQL, prints the exact `./build.sh --ci ...` command, and lets you either print the command or run it.

The wizard is the safest first path because it checks your workstation before it asks image questions. It reports local tools, the Packer SSH keypair, `.env` presence, and required Prism variables as `present` or `missing` without printing secret values.

When something local is missing, the wizard can offer safe setup help:

- create `packer/id_rsa` and `packer/id_rsa.pub`
- run `packer init packer/`
- copy `.env.example` to `.env`

The wizard never creates Prism credentials and never prints secret values. If a secret manager provides your environment, run the wizard from a shell where the Prism variables are already exported.

PostgreSQL extensions are optional. The wizard defaults to no extensions, shows which extensions are release-note-qualified for the selected row, and warns if you select an installable extension that is not release-note-qualified for this matrix row. For rows with a PostgreSQL patch pin, the wizard also shows the qualified version range and the package version that will be installed.

If you already know the exact image you want, you can skip the wizard and use `build.sh` directly. The direct commands below are useful for automation and repeat builds, but the wizard is easier for first-time users.

### 4. Run A Safe Dry Run

Dry-run mode does not start Packer and does not require live Prism credentials to be valid. It shows the selected matrix row, source image plan, generated Ansible variables, final Packer variables, and missing live-build prerequisites.

```bash
./build.sh --dry-run --ci --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18
```

For a MongoDB dry run, change `--db-type` and `--db-version`:

```bash
./build.sh --dry-run --ci --ndb-version 2.10 --db-type mongodb --os "Rocky Linux" --os-version 9.7 --db-version 8.0
```

### 5. Run A Production Build

This is the recommended PostgreSQL production command. It builds the image, validates during provisioning, validates the saved artifact in a disposable VM, and writes a manifest.

```bash
./build.sh --ci --validate --validate-artifact --manifest --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18
```

This is the same production flow for one MongoDB row:

```bash
./build.sh --ci --validate --validate-artifact --manifest --ndb-version 2.10 --db-type mongodb --os "Rocky Linux" --os-version 9.7 --db-version 8.0
```

## Common Commands

Validate every matrix file before you trust a new release edit:

```bash
scripts/matrix_validate.sh ndb/*/matrix.json
```

Check Prism readiness and source-image readiness without starting Packer:

```bash
./build.sh --preflight --ci --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18
```

Preflight a selected matrix suite before launching expensive live builds:

```bash
ROCKY_96_UUID="replace-with-rocky-9.6-image-uuid"
ROCKY_97_UUID="replace-with-rocky-9.7-image-uuid"
UBUNTU_2204_UUID="replace-with-ubuntu-22.04-image-uuid"
UBUNTU_2404_UUID="replace-with-ubuntu-24.04-image-uuid"
DEBIAN_12_UUID="replace-with-debian-12-image-uuid"

./test.sh --include-db-type pgsql --preflight --source-image-uuid-map "rocky-linux-9.6=${ROCKY_96_UUID},rocky-linux-9.7=${ROCKY_97_UUID},ubuntu-linux-22.04=${UBUNTU_2204_UUID},ubuntu-linux-24.04=${UBUNTU_2404_UUID},debian-12=${DEBIAN_12_UUID}" --max-parallel 1
```

Preflight verifies the selected matrix rows, required local tools, Prism credentials, cluster/subnet lookup, and source-image object lookup. It does not boot the guest operating system, so preflight cannot prove cloud-init SSH compatibility for that image on AHV. Use the source-image SSH probe below when you need to prove that a staged image accepts the injected `packer` user and SSH key before running Packer.

Stage a remote source image into Prism before the long build starts:

```bash
./build.sh --stage-source --ci --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18
```

Reuse a source image that is already present in Prism:

```bash
./build.sh --ci --source-image-name "Rocky-9-GenericCloud-LVM-9.7-20251123.2.x86_64.qcow2" --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18
```

Run the Rocky Linux NDB 2.10 build suite with both validation stages and manifests. This is a live Prism build suite, not a local unit test; it can create several build VMs, disposable validation VMs, saved images, and manifest files. If one parallel build fails, `test.sh` stops launching new builds, waits for already-started builds to finish, and then exits with a failure.

```bash
./test.sh --include-ndb 2.10 --include-os "Rocky Linux" --validate --validate-artifact --manifest
```

Run the MongoDB live suite with both validation stages and manifests. Keep `--max-parallel 1` while validating MongoDB topology rows so each temporary local smoke test has the host to itself.

```bash
./test.sh --include-db-type mongodb --validate --validate-artifact --manifest --max-parallel 1
```

If Prism has duplicate source-image names, pass a per-OS UUID map to the suite. The keys match the source-image keys in `images.json`, such as `rocky-linux-9.6`, `rocky-linux-9.7`, and `ubuntu-linux-22.04`.

```bash
ROCKY_96_UUID="replace-with-rocky-9.6-image-uuid"
ROCKY_97_UUID="replace-with-rocky-9.7-image-uuid"
UBUNTU_2204_UUID="replace-with-ubuntu-22.04-image-uuid"

./test.sh --include-db-type mongodb --source-image-uuid-map "rocky-linux-9.6=${ROCKY_96_UUID},rocky-linux-9.7=${ROCKY_97_UUID},ubuntu-linux-22.04=${UBUNTU_2204_UUID}" --validate --validate-artifact --manifest --max-parallel 1
```

After live matrix runs, audit manifest coverage against every buildable matrix row:

```bash
scripts/live_coverage_audit.sh ndb/2.9/matrix.json ndb/2.10/matrix.json
```

The audit exits non-zero and lists missing rows until each buildable row has a manifest with `status=success`, in-guest validation `passed`, artifact validation `passed`, and validation VM cleanup `deleted`.

Add `--suggest-runs` when you want one copy-pasteable validated build command per missing row:

```bash
scripts/live_coverage_audit.sh --suggest-runs ndb/2.9/matrix.json ndb/2.10/matrix.json
```

If the missing rows should reuse staged Prism source images, pass the same source-image UUID map you use with `test.sh`. Matching rows will include `--source-image-uuid` in the suggested `build.sh` command:

```bash
scripts/live_coverage_audit.sh --suggest-runs --source-image-uuid-map "rhel-9.6=${RHEL_96_UUID},rhel-9.7=${RHEL_97_UUID}" ndb/2.9/matrix.json ndb/2.10/matrix.json
```

If the missing rows also need an enterprise customization profile, add the same profile to the suggestion command:

```bash
scripts/live_coverage_audit.sh --suggest-runs --customization-profile customizations/local/rhel-repositories.yml --source-image-uuid-map "rhel-9.6=${RHEL_96_UUID},rhel-9.7=${RHEL_97_UUID}" ndb/2.9/matrix.json ndb/2.10/matrix.json
```

`test.sh` skips RHEL rows unless you add `--allow-rhel`. Only add it after the licensed RHEL source image environment variables are set.

Run every buildable PostgreSQL row that has installable release-note-qualified extensions and select those extensions automatically. This is the extension coverage command for the matrix. It includes RHEL rows, validates the temporary build VM, validates the saved artifact, writes manifests, and keeps going after failures so you get a complete report. Each background build runs with stdin isolated from the matrix reader so every selected row is tested.

```bash
./test.sh --extensions-only --continue-on-error --allow-rhel --validate --validate-artifact --manifest --max-parallel 1
```

Failed Packer builder VMs are deleted automatically. Add `--retain-failed-builder` when you intentionally want to keep a failed builder VM for troubleshooting without enabling Packer debug logging. Use `--debug` only when you also need interactive Packer debug mode and `PACKER_LOG`.

Ubuntu images can start background package work just after boot. The Ansible roles wait for apt/dpkg locks on Debian-family package tasks, so transient first-boot apt activity should slow a build down instead of failing it immediately.

At the end of every build, the final image preparation role resets cloud-init state before Packer captures the image. On Ubuntu it also removes the generated cloud-init netplan file so a VM cloned from the saved image can regenerate first-boot networking and accept the validation SSH key.

Post-build artifact validation uses the offline-safe saved-image cloud-init template by default. It creates the `packer` SSH user and starts SSH, but it does not install packages or run repository updates. This keeps validation focused on whether the saved image is self-contained.

Post-build artifact validation waits for the guest to finish first-boot readiness after SSH is reachable. This matters on cloud images: SSH can be ready before D-Bus, systemd, cloud-init, `firewalld`, `chrony`, `cron`, PostgreSQL, or MongoDB have fully settled.

Show interactive prompts for buildable matrix rows:

```bash
./build.sh
```

List available `db_type` values for one NDB version:

```bash
jq -r '.[].db_type' ndb/2.10/matrix.json | sort -u
```

Run the local shell self-tests:

```bash
bash scripts/selftest.sh
```

Run the core offline verification checks before handing off changes:

```bash
bash -n build.sh test.sh scripts/*.sh
bash scripts/selftest.sh
scripts/matrix_validate.sh ndb/*/matrix.json
packer fmt -check packer
```

## What Happens During A Build

`build.sh` performs these steps in order:

1. Reads your selected `ndb/<version>/matrix.json`.
2. Rejects combinations that are not currently buildable.
3. Validates the matrix unless `SKIP_MATRIX_VALIDATION=true`.
4. Resolves a source image from `images.json` or from `--source-image-uri` / `--source-image-name`.
5. Generates a temporary Ansible vars file for the selected row.
6. Runs Packer against `packer/database.pkr.hcl`.
7. If `--validate` is set, runs in-guest validation before the image is saved.
8. Resolves the saved image UUID in Prism after Packer succeeds.
9. If `--validate-artifact` is set, boots a disposable VM from the saved image and validates the final artifact.
10. If `--manifest` is set, writes a JSON manifest under `manifests/`.

Temporary files are removed automatically. Manifests are ignored by git because they contain environment-specific build records.

## Environment Variables

The easiest setup is:

```bash
cp .env.example .env
source .env
```

The important Prism variables are:

```bash
export PKR_VAR_pc_username="<your-prism-username>"
export PKR_VAR_pc_password="<your-prism-password>"
export PKR_VAR_pc_ip="<your-prism-central-ip-or-hostname>"
export PKR_VAR_cluster_name="<your-cluster-name>"
export PKR_VAR_subnet_name="<your-subnet-name>"
export PKR_VAR_nutanix_insecure="true"
```

Optional build VM sizing overrides:

```bash
export PKR_VAR_vm_cpu="2"
export PKR_VAR_vm_memory_mb="4096"
export PKR_VAR_vm_disk_size_gb="40"
```

Optional licensed RHEL source image overrides:

```bash
export NDB_RHEL_9_7_IMAGE_URI="/path/to/rhel-9.7.qcow2"
export NDB_RHEL_9_6_IMAGE_URI="/path/to/rhel-9.6.qcow2"
```

Optional RHEL subscription activation values for Red Hat CDN-backed package
repositories:

```bash
export NDB_RHEL_ORGID="<from 1Password>"
export NDB_RHEL_ACTIVATIONKEY="<from 1Password>"
```

Keep those values in 1Password or an equivalent secret manager. Do not commit
them, put them in customization vars, bake them into a source image, or print
them in logs. When both values are present, RHEL builder VMs register with
`subscription-manager` before package installation, enable the matching RHEL
CodeReady Builder repository for build-time packages such as `gdbm-devel`, and
unregister/clean RHSM state before the image is captured.

Check that required RHEL values resolve as non-empty before launching a long RHEL run:

```bash
if [ -n "${NDB_RHEL_9_6_IMAGE_URI:-}" ]; then echo "RHEL 9.6 image is configured"; else echo "RHEL 9.6 image is missing"; fi
```

Leave matrix validation enabled unless you are deliberately debugging the validator:

```bash
export SKIP_MATRIX_VALIDATION="false"
```

## Source Images

Source images are defined in `images.json`.

Each entry can be:

- A direct URI, usually for public Rocky Linux or Ubuntu cloud images.
- An object with `env_var` for licensed or short-lived downloads such as RHEL images.
- An object with `prefetch: true` when the image should be downloaded locally before Packer starts.

`build.sh` can use a source image in five ways:

- Remote URI: pass the URI directly to Packer.
- Local path: upload a local qcow2 file through Packer.
- Existing Prism image: pass `--source-image-name`.
- Existing Prism image UUID: pass `--source-image-uuid` when Prism has duplicate image names.
- Pre-staged Prism image: pass `--stage-source` first, then rerun with the staged image name if needed.

If a remote import is slow over VPN, staging or reusing an existing Prism image is usually faster and more reliable than asking Packer to import the remote URI every time.

If Prism reports `ImageCreate failed`, `Unable to fetch the file size from
range request`, or an HTTP `404`, check the source image URI first. That failure
happens before the build VM exists, so it is not caused by Ansible, PostgreSQL,
MongoDB, or selected extensions. Use `./build.sh --dry-run ...` to see the exact
URI, then either fix `images.json` or pass a known-good Prism image with
`--source-image-uuid`.

If Prism has duplicate images with the same source-image name or URI, use the exact Prism image UUID:

```bash
./build.sh --ci --source-image-uuid "replace-with-prism-image-uuid" --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18
```

For multi-row suites, use `test.sh --source-image-uuid-map key=UUID,...` instead of a single `build.sh --source-image-uuid`. The suite applies the matching UUID to each selected row.

Preflight checks that the referenced Prism image exists and is active on the selected Prism cluster, but it cannot prove that the guest OS will accept AHV cloud-init data and become reachable over SSH. A source image can pass preflight and still be unsuitable for builds if the builder VM powers on, receives an IP, and never accepts SSH.

Probe a staged source image directly before spending time on a Packer build:

```bash
scripts/source_image_ssh_probe.sh --source-image-uuid "replace-with-prism-image-uuid"
```

The probe boots a disposable VM from the source image, injects the same `packer` cloud-init user data used by builds, waits for SSH as the `packer` user, then deletes the VM. Use `--source-image-name` instead of `--source-image-uuid` only when the image name is unambiguous in Prism. If the probe passes but Packer still times out, treat the problem as specific to the Packer builder/user-data delivery path or VM hardware settings rather than basic source-image cloud-init compatibility.

For RHEL source images, add the repository check before launching the full
matrix. If `NDB_RHEL_ORGID` and `NDB_RHEL_ACTIVATIONKEY` are present, the probe
registers the disposable VM with the activation key, installs representative
common packages, unregisters and cleans RHSM state, then deletes that VM:

```bash
scripts/source_image_ssh_probe.sh --source-image-uuid "${RHEL_96_UUID}" --rhel-repository-check --ssh-timeout 900
scripts/source_image_ssh_probe.sh --source-image-uuid "${RHEL_97_UUID}" --rhel-repository-check --ssh-timeout 900
```

## Customize The Image

Customization profiles are optional overlays for enterprise-specific tools, certificates, hardening, or validation checks. The committed `enterprise-example` profile is a safe starter that shows where profile settings live without requiring private repositories, tenant URLs, or secrets.

Start with a dry run so you can see the selected matrix row and planned customization inputs before any VM is created:

```bash
./build.sh --dry-run --ci --customization-profile enterprise-example --ndb-version 2.10 --db-type mongodb --os "Rocky Linux" --os-version 9.7 --db-version 8.0
```

When the dry run looks right, use the same profile with the normal production safety flags. This builds the image, runs in-guest validation, boots the saved artifact for final validation, and writes a manifest:

```bash
./build.sh --ci --customization-profile enterprise-example --validate --validate-artifact --manifest --ndb-version 2.10 --db-type mongodb --os "Rocky Linux" --os-version 9.7 --db-version 8.0
```

Profiles live in `customizations/profiles/` or `customizations/local/`. Use `customizations/examples/` as copyable reference material, then put real customer-specific profiles, private variables, and private roles under `customizations/local/`; that directory is ignored by git except for its README and `.gitkeep` so secrets and internal implementation details stay out of commits.

When a customization profile is selected, even a dry run validates the profile with `ansible-playbook` before printing the dry-run summary. This catches missing profile files, unsupported phase names, missing variable files, and missing custom role paths before a long image build starts.

During image builds, selected profiles can run roles before common setup, after common setup, after database installation, and during `--validate`. When `--validate-artifact` is also selected, the saved-image validation VM runs the profile's validation roles after the database validation. The example profile installs a sample internal CA, writes an OpenTelemetry Collector-style service shim, and applies one safe hardening marker so you can see the flow without adding private packages or secrets.

The committed examples use Ansible `become` for system paths and services, use OpenTelemetry Collector naming, and avoid secrets. Production profiles should include validation roles so every installed enterprise tool can be checked during build or artifact validation.

Common enterprise recipes:

- Install an internal CA certificate: copy `customizations/examples/internal-ca/roles/custom_internal_ca` into a private role, replace the generated sample certificate with your enterprise CA distribution method, and keep private CA material outside git.
- Enable RHEL package repositories before common setup: copy `customizations/profiles/rhel-repositories-example.yml`, `customizations/profiles/rhel-repositories-example.vars.yml`, and the `customizations/examples/rhel-repositories/` role pattern into `customizations/local/`, then add your enterprise mirror URLs or entitled repository IDs only in the local copies.
- Install OpenTelemetry Collector monitoring: copy the monitoring-agent example, replace the marker service with your real OpenTelemetry Collector package, config, and service setup, and inject collector endpoints or tenant tokens from your secret manager at build time.
- Apply OS hardening: copy the hardening example, add one small validated setting at a time, and keep a matching validation task so the build proves the hardening actually landed.
- Validate custom work: keep a role like `validate_custom_enterprise` in the profile's `validate` phase so both `--validate` and `--validate-artifact` can prove the customization is present.

Do not commit real enterprise tokens, tenant URLs, private certificates, private keys, or customer-specific repository details. Put local-only profile files and private roles under `customizations/local/`, or load secrets from your organization's secret manager during the build.

## Validation

### In-Guest Validation

Use `--validate` to check the temporary build VM before Packer saves the image:

```bash
./build.sh --ci --validate --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18
```

The `validate_postgres` role checks:

- `firewalld`, `chrony`, and `cron` services are active and enabled.
- The packaged PostgreSQL service is stopped/disabled and nothing is listening on port `5432`, so NDB can start the database it provisions from the software profile.
- PostgreSQL client and server binaries match the selected `db_version`.
- The NDB sudoers drop-in exists and the full sudoers configuration passes `visudo`.
- Expected PostgreSQL extension control files are installed. The image does not leave a default PostgreSQL database running after validation.
- On Ubuntu/Debian images, stale `/bin/reset_password.sh` hooks are removed before capture. Validation also checks D-Bus first-boot readiness plus the NDB reset helper, SSH reset-gate drop-ins, SSH reset port gate, SSH PAM auth-token/account gates, NDB-drive-user `pam_nologin` bypass, and disabled `ssh.socket` state so source clones boot cleanly and target clones do not accept or validate password SSH before NDB's injected password reset can run.

For MongoDB rows, `--validate` runs `validate_mongodb` instead:

- Single-instance validation checks that `mongod` is installed, can start, is reachable through `mongosh`, on the selected version, and on the selected edition.
- The image provides an NDB-safe MongoDB software home at `/opt/ndb/mongodb`. NDB should register MongoDB source VMs with that path, not `/usr`, because NDB mounts the profile software disk at the recorded software mount point during provisioning.
- The NDB-safe software home exposes the MongoDB server binaries plus MongoDB Database Tools such as `mongodump` and `mongorestore`; NDB software profile creation requires those tools under the selected software home.
- Validation stops/disables the packaged `mongod` service and verifies port `27017` is free before image capture, so NDB can own the MongoDB runtime on provisioned VMs.
- Validation also checks that the MongoDB DB OS user exists. Red Hat-family images use `mongod`; Ubuntu/Debian package builds use `mongodb`.
- On Ubuntu/Debian images, validation also checks D-Bus first-boot readiness, stale reset-hook cleanup, the NDB reset helper, SSH reset-gate drop-ins, SSH reset port gate, SSH PAM auth-token/account gates, NDB-drive-user `pam_nologin` bypass, and disabled `ssh.socket` state.
- On Red Hat-family MongoDB images, validation also requires SELinux to be permissive or disabled. NDB 2.10 driver logs currently report that MongoDB SELinux context setup is not implemented, and service-managed MongoDB provisioning can fail under enforcing mode even when direct `mongod` startup works.
- Rows with `replica-set` in `deployment` run a temporary local replica-set smoke test and clean it up afterward.
- Rows with `sharded-cluster` in `deployment` run a temporary local sharded topology smoke test with `mongod` and `mongos`, add one shard, verify it is present, and clean it up afterward.
- `mongodb_edition=enterprise` rows install and validate MongoDB Enterprise packages. NDB 2.10 sharded-cluster readiness uses Enterprise packages because the release notes list sharded MongoDB as Enterprise-only.

### Nutanix Linux Precheck

The common role prepares PostgreSQL and MongoDB Linux images for Nutanix's
`ndb_linux_prechecks.sh` script and NDB's later storage-mapping drivers. It
installs the required OS tools, including `parted` for disk layout discovery,
creates the default NDB drive user `era`, allows that user to run
non-interactive sudo, sets the sudo secure path, starts cron, and disables the
LVM devices file mode that the Nutanix precheck rejects. It also persists `numa=off` and
`transparent_hugepage=never` in `/etc/default/grub`, because NDB registration
checks those GRUB settings. On Ubuntu/Debian images, the build also writes a
late `/etc/default/grub.d/99-ndb-root-device.cfg` override and regenerates GRUB
so the root disk uses `root=/dev/...` instead of `root=PARTUUID=...`; NDB
software-profile creation parses the root disk from standard Linux tools and
can fail when the VM reports the root filesystem as `/dev/root`. Ubuntu/Debian
images also expose `/etc/chrony.conf` as a link to `/etc/chrony/chrony.conf`,
because NDB looks for the Red Hat-style chrony path when it applies NTP
settings during DB server registration. Ubuntu/Debian images also explicitly
anchor `dbus.socket` and `dbus.service` in systemd so offline-safe source
clones expose `/run/dbus/system_bus_socket` on first boot without depending on
package-update side effects from validation cloud-init. The same
Ubuntu/Debian preparation enables password SSH for NDB clones and adds an
explicit `PasswordAuthentication yes` in the main `sshd_config` plus a matching
drop-in, then validates the effective OpenSSH config with `sshd -T`. It also
adds `networking.service`, `ssh.service`, and `sshd.service` drop-ins. They all
call the same helper for NDB's injected `/bin/reset_password.sh`. The networking
drop-in runs before NDB's first-boot static-IP script restarts Debian
networking, so the `era` password is set before the target IP becomes
reachable. It also installs an early `nftables` SSH reset port gate. On normal
source or validation boots the gate sees no reset intent and removes any stale
gate rule. The gate is a fast `oneshot` check anchored in `sysinit.target`
before basic networking and SSH startup; it must not run a long watcher there,
because that can hold normal source clones before `basic.target` and leave
D-Bus unavailable. If reset intent is already visible on an NDB target boot,
the gate drops inbound port `22`; later reset injection is handled by the
networking, SSH, and PAM reset helpers below.
Artifact validation dry-runs the nft rule syntax without applying the port-22
drop, so validation does not cut off its own SSH connection. The SSH drop-ins
are a fallback that also order SSH after `ndb-reset-password-compat.service`.
Before image capture, the role removes any stale `/bin/reset_password.sh` file
and stale `/etc/rc.local` references left by older source images. On normal
boots this makes the systemd helper exit immediately, so source and validation
VMs can still use cloud-init SSH normally. On NDB target boots, where
`/etc/rc.local` references NDB's reset script, the helper runs the reset first
and only then lets SSH listen. The build also adds the same helper to the Debian
`sshd` PAM authentication path before `common-auth`, so a password login attempt
also performs the reset before checking the NDB-provided `era` password if any
SSH startup path bypasses the systemd gate. If the NDB server attempts password
SSH before the reset script is visible, the PAM auth helper waits briefly for
the late-injected reset script before Debian checks the attempted password; it
only does this when NDB has already created `/etc/rc.local`, so normal
validation/source boots without NDB reset intent are not delayed. If NDB's
password attempt arrives before the reset script is injected, the PAM helper
sets the drive-user password from that auth token immediately instead of
waiting for a later `rc.local` reset. It also adds a PAM account-phase
hook before `common-account`; this unlocks and unexpires the NDB drive user
before Debian's common account checks can reject a correct password while the
target clone is still converging, without opening the SSH port gate until reset
completion is marked. Because Debian can also keep `/run/nologin` active before
boot completes, the PAM account stack skips only `pam_nologin` for the
configured NDB drive user, then still runs the normal account stack. In the PAM
auth path, the helper uses
`pam_exec.so seteuid expose_authtok` so it runs with effective-root privileges
and can use the attempted password from stdin when OpenSSH provides it. The
helper preserves that token even when PAM sends stdin without a trailing
newline. Some OpenSSH/PAM combinations invoke `pam_exec` without exposing that
auth token, so the helper first makes NDB's injected reset script Debian-safe and trusts a
successful script when no token is available. If an auth token is available, the
helper also applies it to the configured NDB drive user, normally `era`, with
`chpasswd`, unlocks/unexpires that account for PAM's account phase, and does so
even when an earlier boot hook already marked the injected reset script
complete. The helper rewrites
interactive and Red Hat-style `passwd` password resets to a Debian/Ubuntu
`chpasswd` wrapper that also normalizes the account state, because those
distributions do not support `passwd --stdin`. If NDB injected a reset script, the helper serializes
concurrent calls, runs the reset synchronously, and fails closed instead of
allowing SSH to start with the wrong password. The build also disables
`ssh.socket` socket activation on Debian-family images so socket activation
cannot bypass the SSH service gate. The compatibility service uses helper-level
no-op logic instead of a systemd path condition, so it is safe on normal boots
and deterministic when NDB injects the reset script.

After building an image and booting a VM from it, copy Nutanix's precheck script
to the VM and run the matching command as `era`:

```bash
sudo -iu era
bash /path/to/ndb_linux_prechecks.sh -t postgres_database -n era -d
bash /path/to/ndb_linux_prechecks.sh -t mongodb_database -n era -u mongod -d
bash /path/to/ndb_linux_prechecks.sh -t mongodb_database -n era -u mongodb -d
```

Use the PostgreSQL command for PostgreSQL images and the MongoDB command for
MongoDB images. Use `-u mongod` on Red Hat-family MongoDB images and
`-u mongodb` on Ubuntu/Debian MongoDB images. If you want the script to check
Prism connectivity too, add `-c <prism-cluster-ip>`.

### Artifact Validation

Use `--validate-artifact` to validate the saved Prism image:

```bash
./build.sh --ci --validate-artifact --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18
```

Artifact validation:

- Finds the saved image in Prism.
- Boots a disposable `validate-...` VM from that image.
- Injects the repo SSH key with cloud-init. By default this uses `packer/id_rsa.pub`; set `NDB_ARTIFACT_PUBLIC_KEY_PATH` only if you need a different validation public key.
- Uses `packer/http/e2e-user-data` by default so validation does not depend on public package repositories. Set `NDB_ARTIFACT_USER_DATA_TEMPLATE` only if you intentionally need a custom validation boot path.
- Connects as `packer` with `packer/id_rsa`. Set `NDB_ARTIFACT_PRIVATE_KEY_PATH` only if you need a different validation private key.
- Runs the matching validation role against the disposable VM: `validate_postgres` for PostgreSQL or `validate_mongodb` for MongoDB.
- Deletes the disposable VM after validation by default.

If a lab is slow to boot clones, leave the defaults alone. If you are diagnosing
an SSH problem and want a faster failure, lower the artifact SSH wait:

```bash
NDB_ARTIFACT_SSH_MAX_POLLS=18 NDB_ARTIFACT_SSH_POLL_SECONDS=10 ./build.sh --ci --validate-artifact --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18
```

Add `--debug` to keep the validation VM on failure:

```bash
./build.sh --debug --ci --validate-artifact --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18
```

The validation role maps selected extension names to SQL extension names. For example, `pgvector` is validated as SQL extension `vector`. By default, every selected extension must be installable and must exist in PostgreSQL after provisioning. If a selected extension is not installable by the Ansible metadata, the build or artifact validation fails instead of silently skipping it.

### Full NDB Provisioning E2E

Use this only after the image builds and artifact validation are done. It is a
live NDB test, not a local unit test. It creates source VMs from the saved
Prism images, registers each source VM in NDB, creates software profiles,
provisions databases through NDB, and then connects to the provisioned guest to
prove the database starts correctly.
For PostgreSQL, the final guest smoke check records the connected database name
and server version as `database|version` in the evidence file.

Live runs need both Prism and NDB settings in `.env` or 1Password. At minimum,
set the Prism `PKR_VAR_*` values used for normal builds, the NDB login values
`NDB_SERVER_ADDRESS`, `NDB_SERVER_USER`, and `NDB_SERVER_PASSWORD`, plus these
NDB profile IDs:

- `NDB_E2E_CLUSTER_ID` is the NDB cluster where source and target VMs are created.
- `NDB_E2E_COMPUTE_PROFILE_ID` is the compute profile used for database provisioning.
- `NDB_E2E_SLA_ID` is the SLA used for the Time Machine/protection workflow.
- `NDB_E2E_POSTGRES_NETWORK_PROFILE_ID` is required for PostgreSQL rows. The legacy `NDB_E2E_NETWORK_PROFILE_ID` name is still accepted.
- `NDB_E2E_POSTGRES_DB_PARAM_PROFILE_ID` is required for PostgreSQL rows.
- `NDB_E2E_MONGODB_DB_PARAM_PROFILE_ID` is required for MongoDB rows.
- `NDB_E2E_MONGODB_NETWORK_PROFILE_ID` is optional. If omitted, the script discovers the first READY MongoDB network profile.

First preview the rows it will run:

```bash
op run --env-file=.env -- scripts/ndb_e2e_validate.sh --dry-run --limit 3
```

Run one PostgreSQL smoke test:

```bash
op run --env-file=.env -- scripts/ndb_e2e_validate.sh --db-type pgsql --limit 1
```

Run one MongoDB smoke test:

```bash
op run --env-file=.env -- scripts/ndb_e2e_validate.sh --db-type mongodb --limit 1
```

Run the full latest-success image matrix:

```bash
op run --env-file=.env -- scripts/ndb_e2e_validate.sh
```

Before a long run, check that the selected manifest images still exist in
Prism:

```bash
op run --env-file=.env -- scripts/ndb_e2e_validate.sh --preflight-images
```

The script is intentionally serialized. Do not run multiple copies at the same
time against the same NDB server. Results are appended to
`/private/tmp/ndb_e2e_results.jsonl`, and per-row payloads, responses, and state
files are written under `/private/tmp/ndb_e2e_state`.

Successful E2E rows intentionally leave the created NDB database, software
profile, source DB server record, and source/provisioned VMs available as live
evidence. Failed rows can also leave resources behind depending on where NDB
fails and whether NDB rolls back automatically. Use the IDs in the evidence file
and row state directory for a deliberate cleanup pass after validation.

For each source VM, the runner waits for SSH and then waits for first-boot
system readiness before it starts database prep. The readiness gate requires
D-Bus to be available, systemd to report `running` or `degraded`, and cloud-init
to no longer be actively running. Without this gate, Ubuntu/Debian images can
accept SSH before `systemctl` is usable.

E2E source VMs use an offline-safe E2E cloud-init template by default:
`packer/http/e2e-user-data`. It only creates the `packer` SSH user and starts
SSH. It does not run package updates or install packages, because these source
VMs are cloned from already-built images and should not depend on public
package repositories during NDB provisioning validation. Debian/Ubuntu images
therefore must start D-Bus from the image itself; the build and artifact
validation check this explicitly. Override it with
`NDB_E2E_USER_DATA_TEMPLATE` only if you need to test a custom source-VM boot
path.

Each row uses the latest successful manifest and verifies the saved image still
exists in Prism before creating a source VM. If the manifest UUID is stale but
the image name still exists, the script uses the current UUID. If both are
missing, rebuild that image before continuing full E2E validation.

For PostgreSQL source VMs, the runner attaches a small temporary software disk,
mounts it at `/opt/ndb/postgresql/<major>`, copies the packaged PostgreSQL
software tree there, and registers that mount point with NDB. This follows the
NDB custom software-profile prerequisite that the operating system and database
software live on separate disks/mount points, and avoids brittle storage mapping
from package directories on the OS disk. The runner stops before NDB
registration if that PostgreSQL software path is not a real dedicated
non-root mount point.

For Debian and Ubuntu images, the build installs an NDB Era device-mapper
compatibility helper at `/usr/local/sbin/ndb-era-dm-compat`. NDB attaches its
own Era drives as LVM volumes; on these guests the NDB 2.10 storage mapper can
look for malformed `/dev/dm-*..` paths and miss the Nutanix disk serial on the
LVM device. The helper creates narrow symlink aliases such as `/dev/dm-0..` to
the real `/dev/dm-0` device for `ntnx_era_agent_vg_*` volumes and writes udev
serial metadata. It intentionally does not create extra block-device nodes,
because those can make NDB treat its own Era agent volume group as protectable
database software storage. A lightweight systemd timer reruns it every 10
seconds because those NDB-attached volumes appear later on cloned target VMs,
after the image has already been captured. The helper only processes real
kernel device-mapper names such as `dm-0`, so the timer does not reprocess the
`/dev/dm-0..` aliases it creates.
The E2E runner also applies the same compatibility step once on disposable
Debian/Ubuntu source VMs before software-profile creation.

This helper is a compatibility guard, not a guarantee that every Debian or
Ubuntu row will pass full NDB database provisioning. If the target observer
shows NDB including its own Era agent volume group as `OS_SOFTWARE`, or Prism
rejects `add_entities` with `Detected invalid Volume Group(s)`, treat that as an
NDB-side storage/protection issue and attach the observer evidence to the NDB
support case.
For the known NDB 2.10 Debian 12 PostgreSQL rows, the E2E runner records this
as failure class `known_ndb_debian_pg_storage_protection_blocker` when the
target-observer evidence contains the Era agent VG, `OS_SOFTWARE`, and the
Prism invalid-volume-group rejection.

Useful options:

- `--db-type pgsql|mongodb` limits the run to one engine.
- `--limit N` stops after `N` attempted rows.
- `--row-id ID` reruns one row shown by `--dry-run`. The ID must match exactly; if it does not match any generated row, the runner exits with a clear error instead of reporting `Attempted rows: 0`.
- `--dry-run` previews rows without calling Prism or NDB.
- `--preflight-images` verifies selected Prism images exist and exits without creating VMs.
- `--rerun-passed` runs rows again even if the evidence file already has a pass for them.

Useful optional environment overrides:

- `NDB_E2E_POSTGRES_SOFTWARE_HOME_BASE` sets the PostgreSQL software mount base for E2E source VMs. The default is `/opt/ndb/postgresql`.
- `NDB_E2E_POSTGRES_SOFTWARE_DISK_SIZE_GB` sets the temporary PostgreSQL software disk size for E2E source VMs. The default is `10`.
- `NDB_E2E_MONGODB_SOFTWARE_HOME` sets the MongoDB software home used when registering source VMs. The default is `/opt/ndb/mongodb`; do not use `/usr`, because NDB will mount the profile software disk there during provision.
- `NDB_E2E_SOURCE_VM_MAX_ATTEMPTS` controls how many disposable source VMs the runner may try when Prism assigns an IP that never becomes SSH-ready. The default is `3`.
- `NDB_E2E_SSH_MAX_POLLS` and `NDB_E2E_GUEST_READY_MAX_POLLS` control source/provisioned guest SSH and first-boot readiness polling. SSH readiness defaults to `30` polls with a short connection timeout so unreachable Prism IPs recycle quickly; first-boot readiness still waits longer after SSH is reachable.
- `NDB_E2E_DELETE_VM_ON_FAILURE` asks NDB to delete a failed provisioned DB server VM when possible. The default is `false`, which is useful when you want failure evidence to remain available, but this is best effort: NDB 2.10 can still force rollback cleanup during PostgreSQL DB server VM creation failures. Set it to `true` when you explicitly prefer automatic cleanup.
- `NDB_E2E_NDB_API_TIMEOUT` controls how long each NDB API request may wait before failing. The default is `300` seconds. Increase it, for example to `600`, if a VPN or slow NDB server makes registration/profile/provision API calls time out.
- `NDB_E2E_OPERATION_MAX_POLLS`, `NDB_E2E_OPERATION_POLL_SECONDS`, and `NDB_E2E_OPERATION_STALL_POLLS` control how long the script waits for NDB operations and how many unchanged running polls count as stalled.
- NDB database provisioning always creates the database together with its Time Machine/protection workflow. The E2E runner intentionally keeps that payload complete so a pass proves the full NDB provisioning path, not only software-profile creation.
- `NDB_E2E_TARGET_OBSERVER=true` enables passive target diagnostics during NDB provisioning. It starts inside the same E2E run after NDB returns the provision operation ID, discovers target IP candidates from operation metadata and the Prism VM created for the target database server, then writes best-effort snapshots under the row state directory, for example `/private/tmp/ndb_e2e_state/<row>/target-observer`.
- `NDB_E2E_TARGET_OBSERVER_INTERVAL_SECONDS` controls observer polling. The default is `10`.
- `NDB_E2E_TARGET_OBSERVER_MAX_SECONDS` caps observer runtime. The default is `900`.

## Manifests

Add `--manifest` to write a build record:

```bash
./build.sh --ci --validate --validate-artifact --manifest --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18
```

Manifest files are written under `manifests/` and are ignored by git.

Useful fields:

- `status`: final build status, usually `success` or `failed`.
- `selection`: the matrix selection used for the build.
- `source_image`: whether the source came from a remote URI, local path, staged image, or existing Prism image.
- `packer.started_at`, `packer.finished_at`, `packer.duration_seconds`: the Packer phase only.
- `artifact.image_name`, `artifact.image_uuid`: the saved Prism image.
- `validation.in_guest`: in-guest validation status, such as `not-requested`, `running`, `passed`, or `failed`.
- `validation.artifact`: final artifact validation status.
- `validation.artifact_vm_ip`: disposable validation VM IP address, useful when diagnosing SSH, routing, or first-boot network readiness failures.
- `customization`: selected customization profile, phase role names, and custom in-guest validation status.
- `cleanup.artifact_validation_vm`: whether the disposable validation VM was deleted, retained, or cleanup failed.
- `cleanup.packer_builder_vm`: cleanup status for a failed Packer builder VM. `deleted` means the failed builder VM was removed; `kept-on-failure` means `--retain-failed-builder` intentionally retained it; `kept-debug` means `--debug` intentionally retained it.

If artifact validation succeeds but the validation VM cannot be deleted, the build fails instead of hiding a leaked VM.

## Release Onboarding

When Nutanix publishes a new NDB release, scaffold it from the previous supported release:

```bash
scripts/release_scaffold.sh 2.11 --from 2.10
```

The scaffold:

- Copies `ndb/2.10` to `ndb/2.11`.
- Copies `ansible/2.10` to `ansible/2.11`.
- Rewrites `ndb_version` values in the copied matrix.
- Creates `ndb/2.11/REVIEW.md`.
- Runs matrix validation and Ansible syntax checks.

This is only a starting point. You must still compare the copied matrix with the new release notes before building.

After editing the new matrix, run:

```bash
scripts/matrix_validate.sh ndb/2.11/matrix.json
ANSIBLE_CONFIG=ansible/2.11/ansible.cfg ansible-playbook -i ansible/2.11/inventory/hosts ansible/2.11/playbooks/site.yml --syntax-check
```

Preview the scaffold without creating files:

```bash
scripts/release_scaffold.sh 2.11 --from 2.10 --dry-run
```

## Troubleshooting

### NDB fails at Registering Database

If NDB creates the target DB server but fails later at `Registering Database`,
enable the target observer for the failing row. Run it inside the same serialized
E2E command, not as a separate parallel process:

```bash
op run --env-file=.env -- env NDB_E2E_TARGET_OBSERVER=true NDB_E2E_NDB_API_TIMEOUT=600 scripts/ndb_e2e_validate.sh --row-id 210-pg16-debian12 --rerun-passed
```

The observer writes best-effort NDB operation snapshots and target SSH snapshots
to the row's `target-observer` directory under `/private/tmp/ndb_e2e_state`.
Those files are troubleshooting evidence; do not paste them into tickets without
checking for sensitive environment-specific values first.

On Debian or Ubuntu rows, also confirm the rebuilt image includes the NDB Era
device-mapper helper. The build-time and saved-artifact validation roles check
this automatically: `/usr/local/sbin/ndb-era-dm-compat` must exist, the
`ndb-era-dm-compat.timer` must be enabled, the helper must use symlink aliases
instead of block-device aliases, and the helper must run without error before
image capture. If that is true and the observer still shows NDB sending its own
Era agent volume group to Prism protection-domain `add_entities`, stop changing
the image and escalate with the captured NDB operation and target-observer
evidence.
The E2E evidence row will include `failure_class:
known_ndb_debian_pg_storage_protection_blocker` for that known Debian 12
PostgreSQL pattern.

### Source image import timed out

The Prism import may still be running even after Packer gives up. Find the task UUID in the output, wait for it to finish in Prism, then rerun the build with `--source-image-name`.

Example:

```bash
./build.sh --ci --source-image-name "Rocky-9-GenericCloud-LVM-9.7-20251123.2.x86_64.qcow2" --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18
```

### Source image URL returns 404

If the build fails in a few seconds with `ImageCreate failed`, `Unable to fetch
the file size from range request`, and `GET response: 404`, Prism could not
download the qcow2 URL from `images.json`. Run the same command with
`--dry-run` and check the `Effective packer source_image_uri` line.

Fix options:

- Update the matching entry in `images.json` if the public distribution URL moved.
- Pass `--source-image-uuid` if the source image already exists and is active in Prism.
- Pass `--source-image-uri` with a reachable qcow2 URL for a one-off build.

### Source image name is ambiguous

If Prism has more than one source image with the same name or URI, Packer can
fail before it creates the builder VM. Use the exact source image UUID instead
of the URI or name:

```bash
./build.sh --ci --source-image-uuid 719eff76-48d7-4e5a-b631-4d5946c0a382 --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 14
```

Use your environment's UUID. The example above is only a pattern.

### RedHat or Rocky repositories are slow

The Ansible roles retry RedHat-family package, repository, and metadata steps so
short mirror or VPN failures do not immediately abort a build. If the same DNF
metadata error repeats across all retries, verify the source VM can reach the
configured repositories and that Rocky CRB or RHEL CodeReady Builder is enabled.

### Artifact validation cannot SSH

The validation helper forces the repo key and disables the local SSH agent. Confirm the validation VM has an IP, then rerun with debug retention if inspection is needed.

```bash
./build.sh --debug --ci --validate-artifact --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18
```

### Builder VM gets an IP but SSH never becomes available

If Packer reports a builder VM IP but times out waiting for SSH, the source image may not be accepting AHV cloud-init user data or may not start SSH in the expected way. Retry with a source image known to support AHV/cloud-init SSH, or pass a known-good Prism image UUID with `--source-image-uuid`.

You can test that hypothesis without running Packer:

```bash
scripts/source_image_ssh_probe.sh --source-image-uuid "replace-with-prism-image-uuid" --ssh-timeout 900
```

When this happens before Packer saves an image, artifact validation never starts, so `validation.artifact_vm_ip` will be empty or absent. Check `cleanup.packer_builder_vm` in the manifest when `--manifest` was enabled. If you need to inspect the failed VM, rerun with `--retain-failed-builder`, collect the VM JSON or console evidence, then delete the VM from Prism. If the probe fails too, treat the row as source-image blocked until a guest image can boot, receive the injected `packer` user/key, and accept SSH. If the probe passes but Packer still times out, investigate the Packer Nutanix builder path, boot type, disk adapter, or user-data delivery instead of retrying the same image import.

### A validation VM was left behind

The failed command prints the VM name and UUID. Delete it from Prism after inspection.

If a manifest was written, also check `validation.artifact_vm_ip` and `cleanup.artifact_validation_vm`:

- `kept-on-failure`: expected when `--debug` keeps the VM after failure.
- `delete-request-failed`: Prism rejected the delete request.
- `delete-task-failed`: Prism accepted the delete request, but the task failed.
- `result-unavailable`: artifact validation did not write usable result JSON.

### Manifest status is `failed`

A failed manifest means the build exited before every requested stage completed. Check these sections:

- `packer`: Packer timing and whether the image build finished.
- `validation`: in-guest and artifact validation status.
- `cleanup`: cleanup status for disposable validation VMs.

### Prism task appears stuck

Long-running Prism operations print task UUIDs. Search for the UUID in Prism Central's task view to see Prism-side progress or errors.

### RHEL source image is missing

RHEL downloads are licensed and often short-lived. Set the matching environment variable before building:

```bash
export NDB_RHEL_9_7_IMAGE_URI="/path/to/rhel-9.7.qcow2"
export NDB_RHEL_9_6_IMAGE_URI="/path/to/rhel-9.6.qcow2"
```

### RHEL live validation runbook

Before running RHEL rows, confirm the licensed source image values resolve without printing them:

```bash
scripts/rhel_readiness.sh
```

If the output includes `NDB_RHEL_9_6_IMAGE_URI=missing` or
`NDB_RHEL_9_7_IMAGE_URI=missing`, stop there and fix the secret or source-image
distribution path first. If the output includes `NDB_RHEL_ORGID=missing` or
`NDB_RHEL_ACTIVATIONKEY=missing`, fix the 1Password-backed activation-key
environment before using Red Hat CDN repositories.

If you expect RHEL images to already exist in Prism, scan for likely staged images:

```bash
scripts/rhel_readiness.sh --scan-prism --show-prism-matches
```

If the RHEL images are already staged in Prism, prefer stable UUIDs instead of licensed download URLs:

```bash
export RHEL_96_UUID="00000000-0000-0000-0000-000000000000"
export RHEL_97_UUID="11111111-1111-1111-1111-111111111111"
```

If `scripts/rhel_readiness.sh --scan-prism --show-prism-matches` shows a staged image with `availability=inactive`, inspect the activation plan before changing Prism:

```bash
scripts/prism_image_activate.sh --image-uuid "${RHEL_97_UUID}" --cluster-name "${PKR_VAR_cluster_name}"
```

Only add `--apply` after confirming the image UUID and cluster are correct.

Prism placement and SSH reachability are not enough for a full RHEL build. The
RHEL guest must also have usable package repositories before Ansible reaches the
common package-install step. The default path is activation-key registration:
set `NDB_RHEL_ORGID` and `NDB_RHEL_ACTIVATIONKEY`, let the build register the
temporary builder VM before common setup, enable the matching CodeReady Builder
repository, and let `image_prepare` unregister and clean RHSM state before image
capture. If your environment uses enterprise mirrors instead of Red Hat CDN
repositories, keep using a `pre_common` customization profile to enable those
mirrors. Make sure those mirrors include CodeReady Builder packages.

Prove package readiness before the long build by running the source-image probe
with the RHEL repository check:

```bash
scripts/source_image_ssh_probe.sh --source-image-uuid "${RHEL_96_UUID}" --rhel-repository-check --ssh-timeout 900
scripts/source_image_ssh_probe.sh --source-image-uuid "${RHEL_97_UUID}" --rhel-repository-check --ssh-timeout 900
```

The committed `rhel-repositories-example` profile is a disabled, secret-free
starter for enterprise mirrors or for enabling entitled repository IDs after
activation-key registration. Copy it into `customizations/local/`, point the
copied profile at the copied vars file, set `rhel_repositories_enabled: true`,
and add your enterprise mirror URLs or entitled repository IDs only in the local
vars file. Keep activation keys in `NDB_RHEL_ACTIVATIONKEY`, not in YAML. Then
run the RHEL build with the local profile:

```bash
./build.sh --ci --customization-profile customizations/local/rhel-repositories.yml --validate --validate-artifact --manifest --source-image-uuid "${RHEL_97_UUID}" --ndb-version 2.10 --db-type pgsql --os "Red Hat Enterprise Linux (RHEL)" --os-version 9.7 --db-version 18
```

For the full RHEL matrix, pass the same local profile through `test.sh`:

```bash
./test.sh --allow-rhel --include-os "Red Hat Enterprise Linux (RHEL)" --customization-profile customizations/local/rhel-repositories.yml --validate --validate-artifact --manifest --continue-on-error --source-image-uuid-map "rhel-9.6=${RHEL_96_UUID},rhel-9.7=${RHEL_97_UUID}" --max-parallel 1
```

Preflight every RHEL row before starting live builds. Use the UUID map when reusing staged images:

```bash
./test.sh --allow-rhel --include-os "Red Hat Enterprise Linux (RHEL)" --customization-profile customizations/local/rhel-repositories.yml --preflight --source-image-uuid-map "rhel-9.6=${RHEL_96_UUID},rhel-9.7=${RHEL_97_UUID}" --max-parallel 1
```

If you are using `NDB_RHEL_9_6_IMAGE_URI` and `NDB_RHEL_9_7_IMAGE_URI` instead of staged UUIDs, omit `--source-image-uuid-map`.

Run the remaining RHEL live matrix with both validation stages and manifests:

```bash
./test.sh --allow-rhel --include-os "Red Hat Enterprise Linux (RHEL)" --customization-profile customizations/local/rhel-repositories.yml --validate --validate-artifact --manifest --continue-on-error --source-image-uuid-map "rhel-9.6=${RHEL_96_UUID},rhel-9.7=${RHEL_97_UUID}" --max-parallel 1
```

When the run finishes, audit the manifests against the full buildable matrix:

```bash
scripts/live_coverage_audit.sh ndb/2.9/matrix.json ndb/2.10/matrix.json
```

The goal state is `Missing live rows: 0`. If rows still show as missing, rerun only those rows after resolving the recorded manifest error or Prism-side failure.

## Reference

### Project Structure

```text
.
|-- ansible/
|   |-- 2.9/
|   `-- 2.10/
|-- build.sh
|-- images.json
|-- manifests/
|-- ndb/
|   |-- 2.9/
|   `-- 2.10/
|-- packer/
|   |-- database.pkr.hcl
|   |-- http/user-data
|   `-- variables.pkr.hcl
|-- scripts/
|   |-- artifact_validate.sh
|   |-- build_wizard.sh
|   |-- manifest.sh
|   |-- matrix_validate.sh
|   |-- prism.sh
|   |-- release_scaffold.sh
|   |-- selftest.sh
|   `-- source_images.sh
|-- source/
|-- tasks/
`-- test.sh
```

### Matrix Files

The matrix file is the support contract for one NDB version. Each buildable PostgreSQL row should include release-note qualification metadata:

```json
{
  "ndb_version": "2.10",
  "engine": "PostgreSQL Community Edition",
  "db_type": "pgsql",
  "os_type": "Rocky Linux",
  "os_version": "9.7",
  "db_version": "18",
  "provisioning_role": "postgresql",
  "ha_components": {
    "patroni": ["4.0.5"],
    "etcd": ["3.5.12"],
    "haproxy": ["2.8.9"],
    "keepalived": ["2.2.8"]
  },
  "qualified_extensions": []
}
```

`qualified_extensions` records what Nutanix release notes qualify for that exact NDB version, OS version, PostgreSQL distribution, and PostgreSQL version. It is not an install list. PostgreSQL extension installation is a per-build choice through the wizard or `build.sh --extensions`.

For buildable PostgreSQL rows, an empty qualified extension list must be intentional. Add `qualified_extensions_empty_reason` so the validator can tell the difference between "the release notes do not qualify extensions for this exact row" and "we forgot to check the release notes":

```json
{
  "ndb_version": "2.10",
  "engine": "PostgreSQL Community Edition",
  "db_type": "pgsql",
  "os_type": "Rocky Linux",
  "os_version": "9.7",
  "db_version": "18",
  "provisioning_role": "postgresql",
  "qualified_extensions": [],
  "qualified_extensions_empty_reason": "Nutanix release notes do not list qualified PostgreSQL extensions for this exact OS and PostgreSQL version."
}
```

Each buildable MongoDB row should include `mongodb_edition` and `deployment`:

```json
{
  "ndb_version": "2.10",
  "engine": "MongoDB",
  "db_type": "mongodb",
  "os_type": "Rocky Linux",
  "os_version": "9.7",
  "db_version": "8.0",
  "provisioning_role": "mongodb",
  "mongodb_edition": "community",
  "deployment": ["single-instance", "replica-set"]
}
```

Use `mongodb_edition=community` for Community packages and `mongodb_edition=enterprise` for Enterprise packages. Use `deployment` to list the MongoDB shapes the row must prove during validation:

- `single-instance`: validates the installed `mongod` service, MongoDB version, and edition.
- `replica-set`: also runs a temporary local replica-set smoke test.
- `sharded-cluster`: also runs a temporary local sharded topology smoke test.

For NDB 2.10, sharded MongoDB rows are Enterprise rows because the release notes list sharded MongoDB as Enterprise-only. If a release note combination is useful to document but is not buildable yet, keep it as `provisioning_role=metadata`.

### Matrix Drafting Prompt

You can use this prompt with a language model to draft a new matrix from release notes:

```text
Please create a JSON array of all possible build combinations from the provided markdown file.
Each object must include ndb_version, engine, db_type, os_type, os_version, db_version, and provisioning_role.
Add ha_components (with patroni, etcd, haproxy, and keepalived version arrays) when the release notes include PostgreSQL HA component data.
Use provisioning_role=postgresql only for combinations that are actually buildable by the current PostgreSQL pipeline.
Use provisioning_role=mongodb only for combinations that are actually buildable by the current MongoDB pipeline, and include mongodb_edition plus deployment metadata for those rows.
For buildable PostgreSQL rows, add release-note-qualified PostgreSQL extensions in qualified_extensions.
If Nutanix release notes do not list qualified extensions for the exact row, set qualified_extensions to [] and add a clear qualified_extensions_empty_reason.
Use provisioning_role=metadata for documentation-only rows and for database engines that are not buildable yet.
```

Always review the generated matrix manually against the release notes before building.

### PostgreSQL Extensions

PostgreSQL extensions are optional. The tool installs no extensions unless you select them.

For most DBA workflows, select only the extensions required by the application. Nutanix release notes list which extensions are qualified for specific OS and PostgreSQL combinations; this project stores that release-note metadata as `qualified_extensions` in each PostgreSQL matrix row.

The wizard is the easiest way to choose extensions for one image:

```bash
scripts/build_wizard.sh
```

Direct CLI users can pass a comma-separated list:

```bash
./build.sh --ci --ndb-version 2.10 --db-type pgsql --os "Rocky Linux" --os-version 9.7 --db-version 18 --extensions pgvector,postgis
```

Use `--extensions none` or omit `--extensions` to install no extensions. Use `--extensions all-qualified` only for coverage-style builds where you want every release-note-qualified extension that this project can install today.

When extensions are selected, the generated image name includes an `ext-...` suffix before the timestamp. This makes multiple images for the same NDB, OS, and PostgreSQL version easy to tell apart in Prism.

The build tool currently knows how to install and validate these PostgreSQL extensions:

- `pg_cron`
- `pglogical`
- `pg_partman`
- `pg_stat_statements`
- `pgvector`
- `pgaudit`
- `postgis`
- `set_user`
- `timescaledb`

If you choose an installable extension that is not listed as qualified for the selected row, the build continues and prints this warning:

```text
Extension <name> is installable by this tool, but is not release-note-qualified for this matrix row.
```

The role installs the matching packages for selected extensions and runs `CREATE EXTENSION IF NOT EXISTS ...` in the `postgres` database by default. Red Hat family systems use PGDG packages for these extensions. Ubuntu systems use PGDG for the PostgreSQL extension packages and add the official TimescaleDB packagecloud repository when `timescaledb` is requested, including the dearmored packagecloud keyring apt expects. Override target databases with `postgres_extensions_databases` if needed.

Package names are not always obvious. For example, Red Hat family systems use `pgaudit_16` and `timescaledb_16`, while Ubuntu uses `postgresql-16-pgaudit`, `postgresql-contrib-16`, and `timescaledb-2-postgresql-16`.

Requested extension skips fail by default. If you select an extension, the automation must install it and validation must find it in PostgreSQL.

### PostgreSQL HA Components

For PostgreSQL rows, `ha_components` is also an install list. The build installs the first qualified Patroni version from the row, the matching etcd release binary, and HAProxy/Keepalived when the row lists them. This is required for NDB software profile creation, even when your first provisioned database is a single instance.

Validation checks that Patroni and etcd match the matrix version and that the
HAProxy and Keepalived system binaries are present under `/usr/sbin`. HAProxy
and Keepalived come from the OS repositories, so the package patch version can
be newer than the release-note example while still satisfying NDB's binary
checks.

### Current PostgreSQL Coverage

- `packer/http/user-data` and the `common` role apply documented OS prerequisites.
- Rocky CRB is enabled before Red Hat package installation.
- EPEL is enabled when PostGIS is requested on Red Hat family systems.
- PostgreSQL contrib support is installed or provided for every PostgreSQL row. Red Hat family builds install the major-version package name, such as `postgresql17-contrib`, without pinning to a PGDG patch release so repository updates do not break future builds. Debian/Ubuntu pinned builds rely on the pinned `postgresql-<major>` server package, which provides the matching `postgresql-contrib-<major>` capability.
- Debian and Ubuntu PostgreSQL rows can pin the package patch level with `postgres_package_version_prefix`. When `postgres_package_use_archive` is `true`, the build adds the PGDG archive repository so older release-note-qualified packages remain installable after the main PGDG repository moves forward. Pinned rows install both the PostgreSQL server package and the matching `postgresql-client-<major>` package at that patch level, because NDB reads `pg_config` from the client package when it builds software profiles.
- Validation checks both the installed PostgreSQL server binary and `pg_config` against the package pin when a row declares one. This catches release-note drift during build or saved-artifact validation instead of waiting for NDB provisioning to fail later.
- PostgreSQL HA components from `ha_components` are installed and validated for NDB software profile readiness.
- `ansible/2.10` applies the Ubuntu 24.04 rsyslog AppArmor workaround from the NDB 2.10 known issues.

### Current MongoDB Coverage

- MongoDB rows install Community or Enterprise packages based on `mongodb_edition`.
- Validation temporarily starts the packaged service, checks the server version, selected edition, and any requested local replica-set or sharded topology smoke tests, then stops/disables `mongod` and proves port `27017` is free before image capture.
- Red Hat and Rocky MongoDB builds install MongoDB's pinned SELinux policy source for default RPM layouts. This can be slow because the build needs GitHub access while Ansible clones the pinned `mongodb/mongodb-selinux` source and installs the policy.
- Red Hat and Rocky MongoDB builds also persist SELinux permissive mode for NDB provisioning. This is intentional for the current NDB MongoDB driver behavior; do not switch these images back to enforcing without validating software-profile provisioning end to end.
- MongoDB images install MongoDB Database Tools and expose `/opt/ndb/mongodb/bin` symlinks to the packaged server/tools binaries so NDB software profiles can use a dedicated software mount point instead of overmounting `/usr`.

### Image Naming

Images without a variant use this pattern:

```text
ndb-<ndb_version>-<db_type>-<db_version>-<os_type>-<os_version>-<timestamp>
```

Example:

```text
ndb-2.10-pgsql-18-Rocky Linux-9.7-20260424000000
```

PostgreSQL rows that include `ha_components` add an `ha` suffix before the timestamp. This makes NDB software-profile-ready images easy to distinguish from PostgreSQL images that do not include the HA binaries NDB checks during profile creation.

```text
ndb-<ndb_version>-pgsql-<db_version>-<os_type>-<os_version>-ha-<timestamp>
```

Example:

```text
ndb-2.10-pgsql-18-Rocky Linux-9.7-ha-20260424000000
```

PostgreSQL rows with a package patch pin add a `pg<major>-<patch>` suffix. For example, a Debian 12 PostgreSQL 16 row pinned to `16.12` uses:

```text
ndb-2.10-pgsql-16-Debian-12-ha-pg16-12-20260424000000
```

PostgreSQL images with selected extensions add a readable extension suffix after the HA and package-pin suffixes:

```text
ndb-<ndb_version>-pgsql-<db_version>-<os_type>-<os_version>-ha-pg<major>-<patch>-ext-<extensions>-<timestamp>
```

Example:

```text
ndb-2.10-pgsql-16-Debian-12-ha-pg16-12-ext-pgvector-postgis-20260424000000
```

If many extensions are selected, the suffix keeps the first few extension names and adds a short checksum so the name stays shorter while still distinguishing the variant. The manifest remains the source of truth for the exact selected extension list.

### Multi-Engine Roadmap

`ndb/2.10/matrix.json` also tracks Oracle, SQL Server, MySQL, MariaDB, and MongoDB combinations from the NDB 2.10 release notes. PostgreSQL and selected MongoDB rows are buildable today. Oracle, SQL Server, MySQL, MariaDB, and any unsupported MongoDB combinations remain metadata-only.

To make another engine buildable, add matching Packer and Ansible roles, then change its matrix rows from `provisioning_role=metadata` to a real role such as `oracle` or `sqlserver`.
