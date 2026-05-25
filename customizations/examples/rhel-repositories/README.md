# RHEL Repositories Example

This example shows how to enable RHEL package repositories before the common
NDB image setup role installs packages. It is intentionally disabled by
default and contains no real mirror URLs, credentials, certificates, or
customer-specific repository IDs.

Start by copying these files into `customizations/local/`, then edit the local
copies:

```bash
cp customizations/profiles/rhel-repositories-example.yml customizations/local/rhel-repositories.yml
cp customizations/profiles/rhel-repositories-example.vars.yml customizations/local/rhel-repositories.vars.yml
```

In the local profile, point `vars_files` at the local vars file. In the local
vars file, set `rhel_repositories_enabled: true` and choose one of these
patterns:

- Add enterprise mirror definitions under `rhel_repositories_yum_repositories`.
- Add already-entitled repository IDs under `rhel_repositories_subscription_manager_repos`.

Activation-key registration is handled outside this profile by the
`NDB_RHEL_ORGID` and `NDB_RHEL_ACTIVATIONKEY` environment variables. Keep those
values in 1Password or an equivalent secret manager; do not put activation keys
or org IDs in this YAML. Use this profile only for mirror definitions or for
enabling specific repositories after the builder VM has registered.

The role runs in the `pre_common` phase, so repositories are ready before the
common package installation step. The validation role can confirm expected repo
IDs and the representative common packages after build or artifact validation.

Example local mirror entry:

```yaml
rhel_repositories_yum_repositories:
  - name: enterprise-rhel-9-baseos
    description: Enterprise RHEL 9 BaseOS mirror
    baseurl: https://repo.example.invalid/rhel/9/BaseOS/$basearch/os/
    enabled: true
    gpgcheck: true
    gpgkey: file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release
```

Example local subscription-manager entries:

```yaml
rhel_repositories_subscription_manager_repos:
  - rhel-9-for-x86_64-baseos-rpms
  - rhel-9-for-x86_64-appstream-rpms
```
