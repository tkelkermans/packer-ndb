# Nutanix Database Service 2.11 - PostgreSQL Compatibility Notes

This file is a curated extract from the Nutanix Database Service 2.11 release notes for maintaining `ndb/2.11/matrix.json`. The release notes remain the source of truth.

## Community Edition highlights

- Patch ranges advance across the board: PostgreSQL 18.0-18.4, 17.0-17.10, 16.0-16.14, 15.0-15.18, and 14.0-14.23.
- RHEL 9.8 is newly supported for PostgreSQL 18/17/16/15/14.
- RHEL 10 is newly supported for PostgreSQL 18 and 17.
- Rocky Linux 9.7 continues 18/17/16/15/14; Rocky Linux 9.6 continues 17/16/15/14.
- Ubuntu 24.04 widens from 18.0 to 18.0-18.4; Ubuntu 22.04 continues 16 and 15.
- Debian 12 continues 18, 17.5-17.10, and 16.9-16.14.

## EDB highlights

- RHEL 10 adds EPAS 18.0-18.4 and 17.0-17.10.
- RHEL 9.7 and 8.10 carry EPAS 18.0-18.4; RHEL 9.6/9.4 continue 17/16/15/14.
- Ubuntu 24.04 carries EPAS 18.0-18.4; Ubuntu 20.04 continues 15.0-15.18.

## HA component notes

- PostgreSQL 18 on Ubuntu 24.04 moves to HAProxy 2.9.16 (Keepalived stays 2.2.8).
- PostgreSQL 18 on Rocky Linux 9.7 and RHEL 9.7 stays on Patroni 4.0.5 with etcd 3.5.12, HAProxy 2.8.9, Keepalived 2.2.8.
- Debian 12 rows stay on Patroni 4.0.5, etcd 3.5.12, HAProxy 2.8.9, Keepalived 2.2.7.
- RHEL/Rocky 17 and 16 rows continue to expose both the newer Patroni recommendation and the prior fallback version in `ha_components.patroni`.
- Table 4 does not list HA software for RHEL 9.8 or RHEL 10. Those rows reuse the RHEL 9.7 tuple and carry a `notes` field saying so; revisit when Nutanix publishes explicit versions.

## MongoDB highlights

- Rocky Linux 9.6 and Debian 12 are newly represented as buildable rows.
- Debian 12 qualifies MongoDB 8.0 (Community and Enterprise) and 7.0 (Community); sharded cluster is not qualified on Debian, so those rows carry single-instance and replica-set only.
- Sharded cluster remains Enterprise-only and is unchanged for Rocky Linux and RHEL.

## Repo curation notes

- `provisioning_role=postgresql` and `provisioning_role=mongodb` are used only for rows the current Packer + Ansible pipeline can attempt to build; everything else is a `metadata` row.
- New buildable rows for licensed RHEL versions require `images.json` entries; 2.11 adds `rhel-9.8` and `rhel-10` with `env_var` indirection.
- MongoDB rows are modelled Community-first: Enterprise availability is recorded in `notes` rather than as separate buildable rows unless the pipeline already builds that edition.
