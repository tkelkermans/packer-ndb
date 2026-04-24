# Nutanix Database Service 2.10 - PostgreSQL Compatibility Notes

This file is a curated working extract from `/Users/tristan/Developer/NDB/source/Nutanix Database Service 2.10 - Nutanix Database Service Release Notes.md` that we use while maintaining `ndb/2.10/matrix.json`. The release notes remain the source of truth.

## Community Edition highlights

- Rocky Linux 9.7 adds PostgreSQL 18.0-18.2 support and continues 17/16/15/14.
- Rocky Linux 9.6 continues PostgreSQL 17/16/15/14.
- RHEL 9.7 adds PostgreSQL 18.0-18.2 support and continues 17/16/15/14.
- RHEL 9.6 continues PostgreSQL 17/16/15/14, while RHEL 9.4 and 8.10 remain documented as compatibility rows in the matrix.
- Ubuntu 24.04 is newly supported for PostgreSQL 18.0.
- Debian 12 is newly supported for PostgreSQL 18.0, 17.5-17.8, and 16.9-16.12.

## EDB highlights

- RHEL 9.7 adds EPAS 18.1-18.3.
- Ubuntu 24.04 adds EPAS 18.0.
- Existing RHEL 9.6/9.4/8.10/8.8 and Ubuntu 20.04 compatibility rows continue with newer patch levels.

## HA component notes

- PostgreSQL 18 on Rocky Linux 9.7 and RHEL 9.7 uses Patroni 4.0.5 and etcd 3.5.12.
- PostgreSQL 18 on Ubuntu 24.04 uses HAProxy 2.8.16 and Keepalived 2.2.8.
- Debian 12 community rows use Patroni 4.0.5, etcd 3.5.12, HAProxy 2.8.9, and Keepalived 2.2.7.
- RHEL/Rocky 17 and 16 rows continue to expose both the newer Patroni recommendation and the prior fallback version in `ha_components.patroni`.

## Repo curation notes

- `provisioning_role=postgresql` is used only for rows that the current Packer + Ansible pipeline can attempt to build.
- The Ubuntu 24.04 build path in `ansible/2.10` applies the rsyslog AppArmor workaround documented in the NDB 2.10 known issues.
- Newer 2.10 rows intentionally omit the `extensions` array unless we already had packaging confidence from the existing PostgreSQL automation. This keeps PostgreSQL 18 and newly added distro rows conservative until extension coverage is revalidated.
