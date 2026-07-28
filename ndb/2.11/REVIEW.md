# NDB 2.11 Release Review

Scaffolded from 2.10 with `scripts/release_scaffold.sh 2.11 --from 2.10`, then
reviewed row by row against the NDB 2.11 release notes in `source/`.

## Review outcome

- **PostgreSQL patch ranges** advanced to 18.0-18.4, 17.0-17.10, 16.0-16.14,
  15.0-15.18, 14.0-14.23. Debian/Ubuntu rows carry the matching
  `postgres_package_version_prefix` pins.
- **HA components**: Ubuntu 24.04 PostgreSQL 18 moves to HAProxy 2.9.16. All
  other tuples are unchanged from 2.10.
- **New buildable rows**: RHEL 9.8 (PostgreSQL 18/17/16/15/14), RHEL 10
  (PostgreSQL 18/17), Rocky Linux 9.6 MongoDB (8.0/7.0/6.0 Community),
  Debian 12 MongoDB (8.0/7.0 Community).
- **images.json** gained `rhel-9.8` and `rhel-10` entries with `env_var`
  indirection, as required for buildable RHEL rows.
- **Metadata rows** refreshed for EDB, Oracle, MySQL and MariaDB, including the
  new RHEL 10 entries. MariaDB 10.6 Enterprise moved from RHEL 9.6 to RHEL 9.4
  to match the 2.11 table.

## Known gaps carried into this release

- Table 4 (HA software) does not list RHEL 9.8 or RHEL 10. Those rows reuse the
  RHEL 9.7 tuple and say so in their `notes` field. Revisit when Nutanix
  publishes explicit versions.
- RHEL rows remain blocked on licensed source images and in-guest repository
  access, exactly as in 2.9 and 2.10.
- MongoDB on Debian has never been built here. The Debian repository path was
  corrected recently but is unproven on hardware; treat the Debian 12 MongoDB
  rows as unvalidated until a build succeeds.
- Enterprise MongoDB editions qualified by 2.11 on Rocky Linux and Debian are
  recorded in `notes` rather than as buildable rows.
