# Nutanix Database Service 2.9 - PostgreSQL Software Compatibility and Feature Support

## Table 1. PostgreSQL Community Edition Database and Operating System Versions Supported
 Operating System | Operating System Version | PostgreSQL Database Version |
| --- | --- | --- |
 Rocky Linux | 9.6 | -   17.0 - 17.5
-   16.0 - 16.9
-   15.0 - 15.13
-   14.0 - 14.18
 |
 Red Hat Enterprise Linux (RHEL) | 9.6 | -   17.0 - 17.5
-   16.0 - 16.9
-   15.0 - 15.13
-   14.0 - 14.17
 |
 9.4 | -   17.0 - 17.5
-   16.0 - 16.9
-   15.0 - 15.13
-   14.0 - 14.17
 |
 8.10 | -   17.0 - 17.5
-   16.0 - 16.9
-   15.0 - 15.13
-   14.0 - 14.17
 |
 8.8 | -   15.0 - 15.12
 |
 7.x | -   15.0 - 15.12
-   14.0 - 14.17
-   13.0 - 13.16
 |
 Ubuntu Linux | 22.04 | -   16.0 - 16.9
-   15.0 - 15.12
 |
 20.04 | -   15.0 - 15.12
-   14.0 - 14.17
-   13.0 - 13.16
 |
 Debian | 12 | -   17.5
-   16.9
 |
 11 | -   17.5
-   16.9
-   15.12
 |

For information on PostgreSQL best practices, see [PostgreSQL on Nutanix](https://portal.nutanix.com/page/documents/solutions/details?targetId=BP-2061-PostgreSQL-on-Nutanix:BP-2061-PostgreSQL-on-Nutanix).

Table 2. PostgreSQL EDB Enterprise Edition Database and Operating System Versions Supported
 Operating System | Operating System Version | PostgreSQL Database Version |
| --- | --- | --- |
 RHEL | 9.6 | -   17.2 - 17.5
-   16.1 - 16.9
-   15.2 - 15.13
-   14.1 - 14.17
 |
 9.4 | -   17.2 - 17.5
-   16.1 - 16.9
-   15.2 - 15.13
-   14.1 - 14.17
 |
 8.10 | -   17.2 - 17.5
-   16.1 - 16.9
-   15.2 - 15.13
-   14.1 - 14.17
 |
 8.8 | -   16.1 - 16.8
-   15.2 - 15.12
 |
 Ubuntu | 20.04 | -   15.2 - 15.13
-   14.1 - 14.17
 |

Note:

-   NDB supports PostgreSQL database with EnterpriseDB Advanced Server (EPAS) tool but not any other EDB tools.
-   NDB supports PostgreSQL EDB versions without Transparent Data Encryption (TDE).

Table 3. NDB Features Matrix for PostgreSQL
 NDB Feature | Single Instance | High Availability |
| --- | --- | --- |
 Database Provision | Yes | Yes |
 Provision of database Replicas across Nutanix clusters | Not applicable | Yes |
 Provision of multiple database instance on the same host | No | No |
 Provision of multiple databases in the same database server VM | Yes | Yes |
 Provision of database server VM on any Nutanix cluster | Yes | Yes |
 Copy data management (Clone/Refresh) | Yes (can only create a single instance clone from a single database instance) | Yes (can only create a single instance clone from a HA instance) |
 Database management as a group | No | No |
 Restore | Yes | Yes |
 Patching | Yes\* | Yes\* |
 Database scaling | Yes | Yes |

\*When installing the database using a Linux package manager like DNF or YUM, the PostgreSQL version shown in yum list or dnf list might differ from the actual database version when using NDB patching. This discrepancy does not affect database operations or compatibility with NDB management features.

Table 4. Software Required for PostgreSQL Provisioning
 PostgreSQL Community/EDB | OS | Patroni | etcd | HAProxy\* | Keepalived |
| --- | --- | --- | --- | --- | --- |
 17.2 - 17.5 | RHEL 9.4/ 8.10 | \*4.0.5/ 3.3.2 | 3.5.12 | 2.8.9 | 2.2.8 |
 Rocky Linux 9.4 | 4.0.5/ 3.2.2 | 3.5.12 | 2.8.9 | 2.2.8 |
 RHEL 8.8 | 3.2.2 | 3.4.20 | 1.8.27 | 2.1.5 |
 16.4/ 16.6 | RHEL 9.4/ 8.10 | 4.0.5/ 3.3.2 | 3.5.12 | 2.8.9 | 2.2.8 |
 Rocky Linux 9.5/ 9.4 | 4.0.5/ 3.2.2 | 3.5.12 | 2.8.9 | 2.2.8 |
 RHEL 8.8 | 3.2.2 | 3.4.20 | 1.8.27 | 2.1.5 |
 \*\*Ubuntu 22.04 | 3.2.2 | 3.5.12 | 2.8.9 | 2.2.8 |
 15.8/ 15.10 | Rocky Linux 9.4 | 3.2.2 | 3.5.12 | 2.8.9 | 2.2.8 |
 RHEL 9.4/ 8.10 | 3.2.2 | 3.5.12 | 2.8.9 | 2.2.8 |
 RHEL 8.6 | 2.1.4 | 3.4.20 | 1.8.27 | 2.1.5 |
 \*\*Ubuntu 22.04 | 3.2.2 | 3.5.12 | 2.8.9 | 2.2.8 |
 Ubuntu 20.04 | 2.1.4 | 3.2.26 | 2.0.29 | 2.0.19 |
 14.15/ 14.17 | Rocky Linux 9.4 | 3.2.2 | 3.5.12 | 2.8.9 | 2.2.8 |
 RHEL 9.4/ 8.10 | 3.2.2 | 3.5.12 | 2.8.9 | 2.2.8 |
 Ubuntu 20.04 | 2.1.4 | 3.2.26 | 2.0.29 | 2.0.19 |

Note:

-   \*Patroni versions earlier than 4.x do not support or manage the new GUC parameters introduced by PostgreSQL 17.
-   \*\* Supported for PostgreSQL Community Edition only.

## Table 5. Qualified OS versions and PostgreSQL versions for PostgreSQL extensions
 Qualified PostgreSQL Extensions | OS Version | PostgreSQL/EDB Version |
| --- | --- | --- |
 pg\_vector | -   RHEL 9.4
 | -   16
 |
 -   RHEL 8.10
 | -   EPAS 15.6
 |
 -   TimescaleDB
-   pgAudit
-   pg\_cron
-   set\_user
-   PostGIS
 | -   RHEL 9.4
 | -   16
 |
 -   RHEL 8.4
 | -   14
 |
 -   RHEL 8.6
 | -   14
 |
 -   pg\_partman
-   pg\_logical
-   pg\_stat\_statements
 | -   RHEL 9.4
 | -   16
 |