---
title: "Nutanix Database Service 2.11 - Nutanix Database Service Release Notes"
source: "https://portal.nutanix.com/page/documents/details?targetId=Release-Notes-Nutanix-NDB-v2_11:portal-full-page-view-html"
author:
published:
created: 2026-07-28
description:
tags:
  - "clippings"
---
## Nutanix Database Service Release Notes

Tags:

Nutanix Database Service

2.11

## Nutanix Database Service Release Notes

## Overview

Nutanix Database Service (NDB) automates and simplifies database administration by providing one-click operations and end-to-end lifecycle management. NDB enables you to perform database registration, provisioning, cloning, patching, snapshot management, restore (including point-in-time recovery), and disaster recovery (DR) operations. You can define provisioning standards with end-state-driven automation, including network segmentation and high-availability (HA) database deployments. With NDB multicluster support, you can centrally manage databases across multiple on-premises locations and public clouds, including AWS, Azure, and Google Cloud Platform (GCP) through Nutanix Cloud Clusters (NC2).

For more information on the new features and enhancements in this release, see.

This release includes several resolved issues. For more information, see.

For information about the known issues in this release, see.

For detailed information about the product, see [Nutanix Database Service Administration Guide](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide-v2_11:Nutanix-NDB-User-Guide-v2_11).

## NDB 2.11 Installation or Upgrade

Prerequisites, download links, and references for installing or upgrading to NDB 2.11.

Important:
- To upgrade to NDB 2.11, you must be running a 2.9.x version or later.
- NDB versions 2.8.x or earlier require an intermediate upgrade to 2.9.x before upgrading to 2.11. Attempting a direct upgrade from 2.8.x to 2.11 fails.
- Before upgrading to NDB 2.11, run the legacy external NDB Upgrade Precheck tool to verify the required pre-upgrade conditions and help ensure a successful upgrade. For information about the precheck tool, see [KB 20810](https://portal.nutanix.com/kb/20810). Starting with NDB 2.11, the Upgrade Readiness feature is integrated into NDB and is available through the UI, CLI, and API. For upgrades to future releases, you can run the integrated readiness checks as part of the upgrade workflow.

To download the NDB upgrade bundle from the Nutanix Support Portal, use the following link: [Nutanix Database Service page](https://portal.nutanix.com/page/downloads?product=ndb).

After the upgrade to a new version of NDB is complete, wait for at least 15 seconds and refresh the page to load the latest user interface.

For more information, see:

- [NDB Installation](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide-v2_11:top-installation-c.html) in Nutanix Database Service Administration Guide.
- [NDB Upgrade Management](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide-v2_11:top-version-upgrade-c.html) in Nutanix Database Service Administration Guide.

## What's New in NDB 2.11

New features and enhancements in NDB 2.11

This release includes the following new features and enhancements:

### Features

**Adding and Removing Database Nodes for SQL Server and PostgreSQL Clusters**

You can add or remove database server VMs from Windows Server Failover Cluster (WSFC) and PostgreSQL High Availability (HA) clusters provisioned by NDB without reprovisioning the DB cluster or incurring downtime. You can perform these operations from the web console, API, or CLI. You can scale a SQL Server availability group to a maximum of 9 database nodes and a PostgreSQL cluster to a maximum of 5 database nodes.

Use this capability to replace a failed database node, adjust the number of nodes as availability requirements change, or migrate database clusters and individual nodes to new infrastructure. Adding or removing nodes does not require you to create a new database cluster or migrate data.

For more information and limitations, see [SQL Server Database Server VM Management for Availability Groups](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-SQL-Server-Database-Management-Guide-v2_11:top-sql-server-db-server-vm-mgmt-c.html) in the Nutanix Database Service SQL Server Database Management Guide and [PostgreSQL Database Server VM Management for HA Clusters](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-PostgreSQL-Database-Management-Guide-v2_11:top-postgresql-vm-ha-mgmt-c.html) in the Nutanix Database Service PostgreSQL Database Management Guide.

**MySQL HA Backup and Restore Support**

NDB now extends Time Machine support to MySQL High Availability (HA) instances, including scheduled snapshots, log backups, and snapshot and PITR-based restore. You can update the Time Machine SLA for an existing MySQL HA cluster to enable scheduled snapshots and perform in-place restore operations using a snapshot or PITR. Backup operations run on the primary node of the MySQL Group Replication cluster. During a restore operation, NDB pauses the Time Machine, restores the primary node from the selected snapshot, and then restores replica nodes to re-establish the cluster. Snapshots are replicated to associated Nutanix clusters based on Data Access Management (DAM) policies.

The following requirements apply to MySQL HA backup and restore:

- InnoDB storage engine
- MySQL version 8.4 or higher
- Group Replication with GTID mode enabled
- Single-writer mode only

For more information, see [MySQL High Availability Support](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-MySQL-Database-Management-Guide-v2_10:top-mysql-db-ha-overview-c.html) in the Nutanix Database Service MySQL Database Management Guide.

**Native Database Encryption for MySQL and EDB PostgreSQL**

NDB now supports Transparent Data Encryption (TDE) for MySQL (Single Instance and High Availability) and EDB Postgres Advanced Server (EPAS) databases by integrating with Thales CipherTrust Manager. You can provision encrypted databases with externally managed encryption keys, protect data at rest, and perform key rotation through NDB to help meet security and regulatory compliance requirements.

For more information, see [Native Database Encryption](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide-v2_11:top-ndb-native-db-encryption-c.html) in the Nutanix Database Service Administration Guide.

**PostgreSQL Database Disaster Recovery**

NDB now supports disaster recovery (DR) for PostgreSQL high availability (HA) databases using native PostgreSQL streaming replication and WAL archiving. You can replicate data from a primary database to a standby database at a geographically separate site to ensure data protection and business continuity.

The DR configuration uses an HA-to-HA topology where both the primary and standby databases are multi-node Patroni-managed PostgreSQL HA clusters deployed across separate Nutanix clusters in different failure domains. Replication is asynchronous, combining streaming replication with file-based WAL archiving to Nutanix Objects. You can perform switchover and failover operations to manage planned and unplanned role transitions between primary and standby databases. Each standby database has an independent time machine with its own snapshots and backup schedule, enabling local recovery at the DR site without depending on the primary database.

For more information and limitations, see [PostgreSQL Database Disaster Recovery](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-PostgreSQL-Database-Management-Guide-v2_11:top-postgresql-dr-c.html) in the Nutanix Database Service PostgreSQL Database Management Guide.

**WAL Archival with Objects Store for PostgreSQL HA**

NDB now supports write-ahead log (WAL) archival to a Nutanix Object Store for PostgreSQL high availability databases. This option provides a more scalable and resilient alternative to volume-group based archival for replication and failover recovery. You can also migrate existing PostgreSQL HA databases from volume-group based archival to Nutanix Objects Store-based archival.

For more information, see [Provisioning a PostgreSQL HA Instance](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-PostgreSQL-Database-Management-Guide-v2_11:top-postgresql-cluster-database-provision-t.html) in the Nutanix Database Service PostgreSQL Database Management Guide.

**Entity Sharing for Databases and Database Clones**

NDB now supports additional entity-sharing access levels for databases and database clones. You can grant *Manage* or *Full* access to other users, allowing users to delegate administrative tasks without granting Super Admin privileges.

Databases now support *Manage* and *Full* access, in addition to *View*:

- *Manage* allows users to capture snapshots, restore, scale, update, and view database metadata.
- *Full* includes all *Manage* permissions and allows users to share or remove a database.

Database clones now support *Full* access, in addition to *View* and *Manage*. *Full* includes all *Manage* permissions and allows users to share or remove a database clone.

For more information, see [Entity Sharing Policies](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide:top-entity-sharing-policy-r.html) in the Nutanix Database Service Administration Guide.

**NDB Audit Management**

NDB now supports centralized audit logging for all user-initiated actions performed through the UI, CLI, or REST API. When you enable auditing, NDB captures audit entries, including user identity, source IP address, event type, operation category, entity details, timestamps, and status, and forwards them to a registered Prism Central instance for centralized storage and access.

Audited operations include database provisioning, cloning, patching, deletion, registration, snapshot creation, storage extension, Time Machine updates, RBAC changes, and profile configuration changes across all supported database engines. Audit logs are stored in Prism Central with a default 30-day retention period, and you can view and search the logs directly from the Prism Central UI. You can also forward audit logs from Prism Central to remote syslog servers using TCP, UDP, or RELP protocols.

For more information, see [NDB Audit Management](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide-v2_11:top-audit-management-c.html) in the Nutanix Database Service Administration Guide.

**MongoDB Sharded Cluster Scale-Out Support**

NDB supports horizontal scaling for existing NDB-provisioned MongoDB sharded clusters with zero downtime. You can scale the cluster incrementally by adding one component at a time:
- Add shards: Expand the data tier by adding shard replica sets to distribute data across more shards, support larger datasets, and increase throughput.
- Add mongos: Expand the routing tier by adding mongos instances to increase query capacity and help prevent routing bottlenecks as application traffic grows.

For more information, see [MongoDB Sharded Cluster Scaling](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-MongoDB-Database-Management-Guide-v2_11:top-mongodb-sharded-cluster-scale-c.html) in the Nutanix Database Service MongoDB Database Management Guide.

**Enhanced Diagnostic Bundle Generation from the Web Console**

The NDB diagnostic bundle now allows you to select log categories and refine the selection as troubleshooting progresses. You can begin with a complete set of categories and clear unnecessary categories later to reduce the data collected. You can also generate a bundle for a specified time range to collect data only for the period when the issue occurred.

For more information, see [Downloading the Diagnostics Bundle](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide:top-diagnostics-download-t.html) in the Nutanix Database Service Administration Guide.

**Oracle Data Guard Disaster Recovery IP Address Selection**

NDB now supports selecting database server IP addresses from the web console when you configure the native Oracle Data Guard disaster recovery (DR) plug-in. With this enhancement, you can assign specific IP addresses to database servers directly from the web console during DR configuration.

For more information, see [Nutanix Database Service Oracle Database Management Guide](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-Oracle-Database-Management-Guide-v2_11:Nutanix-NDB-Oracle-Database-Management-Guide-v2_11).

**Upgrade Readiness for NDB Control Plane and DB Servers**

You can now run upgrade readiness prechecks before you upgrade NDB to proactively identify and resolve issues that cause upgrade failures. The precheck validates the NDB Control Plane and all registered DB server VMs, checking disk space, agent health, DB server reachability, sudo access, RAM availability, and logical volume configuration. For high availability deployments, additional checks cover HAProxy VIP association and NDB Metastore repository health. You can run these prechecks from the web console, and NDB also runs them automatically as part of every upgrade.

For more information, see [Upgrading NDB (One-Click Upgrade)](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide:top-version-one-click-upgrade-t.html) in the Nutanix Database Service Administration Guide.

**Configurable Collation for PostgreSQL**

You can specify custom collation settings (LC\_COLLATE and LC\_TYPE) when provisioning or cloning a PostgreSQL database, instead of the previously hardcoded en\_US.UTF.8 default. This allows you to select collation options such as C locale to meet application-specific sorting and comparison requirements. Custom collation is supported for both single-instance and high-availability PostgreSQL deployments. You can configure collation through the NDB UI, API, or CLI.

For more information, see [Provisioning a PostgreSQL Instance](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-PostgreSQL-Database-Management-Guide:top-postgresql-database-provision-t.html) in the Nutanix Database Service PostgreSQL Database Management Guide.

### Enhancements

**MongoDB TDE Enhancements for Restoring and Cloning Backups**

NDB now supports restore, clone, and refresh clone operations for Transparent Data Encryption (TDE)-enabled MongoDB databases from backups encrypted with earlier master key versions. After the operation completes, NDB automatically reconfigures the database to use the latest master key.

You can also update, clone, and delete external key management server (KMS) configurations for a database type from the NDB web console.

For more information, see [Native Database Encryption](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide-v2_11:top-ndb-native-db-encryption-c.html) in the Nutanix Database Service Administration Guide.

**Default Volume Group Storage for SQL Server Provisioning**

NDB now uses Nutanix Volume Groups (VGs) as the default storage option when you provision new SQL Server databases.

New SQL Server databases are automatically provisioned using Volume Groups. Databases that were previously provisioned using vDisks continue to use their current configuration without any changes.

For more information, see [SQL Server Database Provisioning](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-SQL-Server-Database-Management-Guide-v2_11:top-sql-server-database-provision-c.html) in the Nutanix Database Service SQL Server Database Management Guide.

**Enhanced SQL Server Provisioning from Backup**

NDB now uses an index rebuild-based data distribution method for SQL Server provision-from-backup operations. This method is enabled by default through the `enable_index_rebuild_distribution` flag. This enhancement reduces provisioning time, eliminates index fragmentation, and improves post-provisioning I/O performance. For databases containing unsupported indexes, data, or tables, NDB automatically uses the DBCC SHRINKFILE-based data distribution method. For more information about unsupported data, see KB 20890.

For more information, see [SQL Server Database Provisioning](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-SQL-Server-Database-Management-Guide-v2_11:top-sql-server-database-provision-c.html) in the Nutanix Database Service SQL Server Database Management Guide.

**Storage Spaces Reliability and Performance Enhancements**

NDB includes the following enhancements for SQL Server Storage Spaces deployments:
- Restore operations now use Windows Robocopy for faster and more reliable file copying. For more information, see KB 21706.
- Storage Spaces volumes now support sizes up to 256 TB, enabling provisioning of larger SQL Server databases on a single volume.
- New Storage Spaces virtual disks now use a 64 KB interleave size by default to align with Microsoft recommendations for SQL Server workloads.

**List View for Time Machine Snapshot Data**

NDB now provides a list view option as an accessible alternative to the Calendar view on the Time Machine overview page. The List view displays snapshot dates in a sortable table with Recovery Type and Operation Status information. Click any date to view details such as Snapshot Time, Snapshot Type, Status, Retention, Action, and Log Backup information.

This enhancement enables users of screen readers such as NVDA and VoiceOver to access information previously conveyed only through color and text in the graphical Calendar view.

**Enhanced Security for Prism API Communication**

NDB enhances the security of Prism API communication from database server VMs. Prism API requests from the database server VMs are now routed through the NDB server instead of connecting directly to Prism Element or Prism Central. This enhancement centralizes Prism credential management and eliminates the need for database server VMs to store Prism administrator credentials.

This change is automatic and requires no manual configuration. Database server VMs no longer require direct network connectivity to Prism Element or Prism Central on port 9440. You no longer need to open firewall port 9440 between the database server VMs and Prism Element or Prism Central, which significantly improves the security.

NDB does not proxy iSCSI traffic, so you must keep the iSCSI ports (3205 and 3260) open between the database server VMs and Nutanix Prism Element. These ports are required in scenarios such as ESXi hosts that use iSCSI volume groups and SQL Server clusters that use a shared quorum disk.

For more information, see [NDB Network Requirements](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide:top-db-network-requirements-r.html) in the Nutanix Database Service Administration Guide.

**Backup Operations During Control Plane Upgrades**

NDB now resumes backup operations, including scheduled backups, log catchup, and snapshot replication, as soon as the first control plane VM completes its upgrade. In earlier versions, NDB paused these operations from the start of the control plane upgrade until the database server VM, where the backup operation executes, completes its upgrade. This improvement reduces potential RPO impact in scaled environments.

For more information, see [NDB Upgrade Management](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide:top-version-upgrade-c.html) in the Nutanix Database Service Administration Guide.

**Removed Agent VM Dependency for Windows NDB VM Creation**

NDB no longer requires the Agent VM to provision a Windows Server-based DB Server VM. This change reduces resource overhead, simplifies provisioning, and shortens provisioning time when you provision multiple DB Server VMs on the same Nutanix cluster.

**Control Plane Operating System Upgrade to Rocky Linux 9**

NDB upgrades the control plane operating system from Rocky Linux 8.10 to Rocky Linux 9.8, providing improved security, stability, and performance. For more information, see [KB-22179](https://portal.nutanix.com/kb/22179).

**RHEL 10 Guest Operating System Support**

NDB supports Red Hat Enterprise Linux (RHEL) 10 as a guest operating system for MySQL, MariaDB, and PostgreSQL database server VMs. This release also includes Version Currency qualifications for the following combinations:
- MySQL and MariaDB on RHEL 8.10
- PostgreSQL 17 and PostgreSQL 18 on RHEL 8.10
For more information, see and.

**Python and Ansible Upgrade**

NDB upgrades Python from 3.8 to 3.11 and Ansible from 2.8 to core 2.18 on the control plane and all database server VMs.

This upgrade provides improved performance, enhanced security, and access to the latest Python libraries and features. The upgrade is handled automatically during the NDB upgrade and requires no manual action.

If you use custom pre-script or post-script hooks, custom Ansible modules, or automation that runs in the NDB Python environment, verify that your scripts are compatible with Python 3.11 and Ansible 2.18 to avoid execution failures after the upgrade.

**Sysprep-Based Windows VM Provisioning**

NDB now uses Microsoft Sysprep for Windows VM provisioning, replacing the previous Offline Disk Processing workflow. With this architecture, NDB generalizes Windows images during database profile creation and specializes them dynamically during VM provisioning.

**Single-NIC Control Plane Networking**

NDB now uses a single-NIC architecture for control plane VMs, simplifying network management and eliminating routing issues during software upgrades. You no longer need to configure separate VLANs for Prism, UI, or database server access during setup. The following deployment specific behaviors apply:
- New deployments automatically use the single-NIC architecture for NDB server and agent VMs.
- Upgraded environments preserve existing multi-NIC configurations. However, any new clusters onboarded after the upgrade must use a single-VLAN NDB agent.
- This change applies only to NDB control plane VMs. You can continue to provision and manage database server VMs with multiple NICs.

**PostgreSQL WAL Archive Script Migration**

During the 2.11 upgrade, NDB performs a one-time migration of WAL archive command scripts on all PostgreSQL database server VMs. The migration replaces inline archive commands with template-based scripts that support node role awareness.

This migration runs automatically and requires no manual action. If the migration fails on a specific VM, it does not block the rest of the upgrade. NDB retries the migration on the next upgrade attempt.

**Stale Volume Group Detection During Provisioning**

If stale LVM volume groups from failed provisioning operations on NDB versions earlier than 2.7 exist on a database server VM, NDB now halts new Linux database server provisioning and raises an alert. You must manually remove the stale volume groups from the operating system before provisioning can succeed.

## Resolved Issues

Issues resolved in NDB version 2.11.

This release resolves the following issues:

General

ERA-66094 Resolved an issue where configuring a static IP address for the NDB server failed on RHEL 9-based deployments because the network configuration was applied through legacy ifcfg files instead of nmcli.

ERA-65480 Resolved an issue where a role-based access control (RBAC) user could not stop or resubmit operations that the same user triggered.

ERA-65222 Resolved an issue where disaster recovery (DR) configuration operations failed with a permission-denied error because internal API calls were missing the required operation authentication token.

ERA-64361 Resolved an issue where the operation executor did not automatically recover after an unexpected failure, causing the NDB daemon to become unreachable. The agent service now automatically restarts the operation executor after an unexpected failure.

ERA-64114 Resolved an issue where an incorrect package version caused the operation monitor to fail.

ERA-62137 Resolved an issue where snapshots created during the Manage and Add Database Server operations, along with their replicated copies, were not deleted after the operation completed.

ERA-56875 Resolved an issue where the stale volume group (VG) cleanup script incorrectly listed volume groups that were still in use by a time machine.

ERA-47334 Resolved an issue where the metadata refresh was not skipped for snapshot operations.

ERA-61272 Resolved an issue where the CA certificate recovery operation failed to reimport CA certificates after a control plane recovery on a high availability (HA) deployment. The missing Java keystore caused SSL handshake errors during subsequent operations.

ERA-55373 Resolved an issue where a user who was not the time machine owner could not create an on-demand snapshot through entity sharing, even when the user had Manage or Full Access. The operation failed with a failed to load details era drive info error.

ERA-46413 Resolved an issue where adding a data access management (DAM) policy to a paused time machine caused inconsistent behavior, and replication operations did not start after you resumed the time machine.

ERA-47170 Resolved an issue where increasing the number of daily snapshots could report false schedule misses on the time machine timeline.

Oracle

ERA-22721 Resolved an issue where the UI accepted Data and FRA sizes below the required 20 GB minimum during Oracle database provisioning, which caused the operation to fail. The UI now validates the minimum storage size before you submit the request.

ERA-40929 Resolved an issue where extending the storage of a database that used a striped LVM configuration could allocate more storage than requested when the disks reached the maximum vDisk size. NDB now informs you when the storage is extended beyond the requested amount.

ERA-64486 Resolved an issue where the NDB DB-Server agent upgrade failed for Oracle databases registered on VMs with SELinux in enforcing mode.

SQL Server

ERA-27599 Resolved an issue where Active Directory entries were not cleaned up when a SQL Server Always On Availability Group (AG) provisioning operation failed and rolled back. NDB now removes Active Directory entries during the rollback process.

ERA-57562 Resolved an issue where SQL Server database server registration on Windows Server 2025 failed with a Hyper-V related PowerShell error, even though the Hyper-V PowerShell module was not required in the environment. NDB now handles this error during registration, which completes as expected.

ERA-35350 Resolved an issue where SQL Server AG database provisioning failed when the generated SMB share name exceeded the 80-character limit that Windows accepts. NDB now generates a compliant share name automatically, so AG provisioning completes successfully.

ERA-61875 Resolved an issue where provisioning a SQL Server database from a backup file allowed a collation to be selected that differed from the collation in the backup file, which could cause provisioning failures. NDB now raises a warning when such a mismatch is detected, falls back to the collation from the backup file, and the provision operation completes successfully.

ERA-48864 Resolved an issue where provisioning a SQL Server Always On Availability Group (AG) with a new cluster failed when the SQL Server service account used a group Managed Service Account (gMSA). NDB now supports the override of sql\_service\_startup\_account with a gMSA user in the API payload for Provision and Clone workflows.

ERA-34326 Resolved an issue where registering a SQL Server Failover Cluster Instance (FCI) database failed when you selected a passive node. NDB now automatically detects the active node and discovers the databases on it during registration.

ERA-57361 Resolved an issue where a database provisioned from backup to a custom drive letter that matched an existing network drive was not visible under This PC in the Windows VM after provisioning.

ERA-63202 Resolved an issue where SLA synchronization failed during SQL Server Always On Availability Group (AG) database registration when the Nutanix object store was enabled for the time machine.

ERA-63733 Resolved an issue where cloning a SQL Server Always On Availability Group (AG) database failed with a WinRM authentication error when a sub-operation running on the cloned VM connected to itself using domain credentials.

ERA-65286 Resolved an issue where updating the ERA Worker service credentials failed on SQL Server WSFC cluster nodes when the service could not restart under the updated account.

ERA-18480 Resolved an issue where SQL Server Failover Cluster Instance (FCI) provisioning failed with an Instance name is already in use error when the FCI instance used the same name as the source instance from which the software profile was created.

PostgreSQL

ERA-62658 Resolved an issue where adding a database server VM to a PostgreSQL HA cluster failed when the target node resided on a cluster that hosted only an NDB agent and not the NDB server.

ERA-63562 Resolved an issue where PostgreSQL HA WAL archive migration was incorrectly marked as failed on CipherTrust Transparent Encryption (CTE)-enabled setups when the old volume group archive could not be unmounted, even though the migration completed. This failure no longer blocks PostgreSQL DR configuration for the database.

ERA-63581 Resolved an issue where adding a node to an SSL/TLS-enabled PostgreSQL HA (Patroni) cluster failed during the Configure Patroni Cluster step because the etcd commands were issued without TLS credentials.

ERA-50708 Added Swagger API support for migration operations and for updating the write-ahead log (WAL) expiry.

MongoDB

ERA-64660 Resolved an issue where CA certificates were not retained on the cluster agents after an NDB upgrade in a multi-cluster setup, which caused the MongoDB Ops Manager association to fail.

ERA-58484 Resolved an issue where snapshot creation for a MongoDB sharded cluster intermittently failed when a temporary network interruption between the Nutanix AOS cluster and the NDB server caused the snapshot API call to fail.

ERA-54219 Resolved an issue where associating a MongoDB sharded cluster with MongoDB Ops Manager failed when the cluster name or a replica set name contained a dot. NDB now prevents the use of dots in cluster and replica set names during provisioning.

UI

ERA-53039 Resolved an issue where the Time Machine Overview page displayed incorrect storage usage for log catchups on object storage-based deployments.

ERA-47499 Resolved an issue where configuring the SMTP server with Security set to None failed during NDB onboarding because of a validation error, even when you provided valid SMTP details.

## Known Issues

You might encounter the following known issues in this or recent NDB releases:

NDB Upgrade

- ERA-53275 Databases that were provisioned with a private key under a non-SLA configuration and upgraded from NDB 2.8 to a later version might retain the private key file in the temp directory after upgrade. This does not impact any database functionality. Databases configured with non-NONE SLA automatically clean up keys as part of normal operations, and databases freshly provisioned on versions higher than 2.8 are not affected.
	**Workaround**: You can manually delete the keys from the following directory:
	/opt/era\_base/era\_server\_config/temp/keys/

General

- ERA-60339 During the qualification of Ubuntu 24.04, the rsyslog-ndb service fails to start because of stricter AppArmor profiles introduced in AppArmor v4.x.
	**Workaround**: For NDB 2.10, you must apply the following workaround to use Ubuntu 24.04 with any supported database engine.
	- Log in to the gold image VM as the root user.
		- Disable the AppArmor profile for rsyslogd by running the following command:
		```
		sudo ln -s /etc/apparmor.d/usr.sbin.rsyslogd /etc/apparmor.d/disable/
		```
- ERA-54945 VM provisioning on ESXi may fail during the hostnamectl command execution if the template VM has Nutanix Guest Tools (NGT) installed.
	**Workaround**: Uninstall NGT from the template VM and retry provisioning using a new software profile.
- ERA-48808 If software profile replication in NDB fails (for example, due to a network, cluster, or internal error), NDB retains the association between the software profile and the target cluster in the backend. As a result, retrying the replication through the UI or API does not re-initiate the process. NDB considers the replication complete and prevents further replication attempts for the same cluster and software profile.
	**Workaround**: Remove the failed cluster-profile association and initiate a new software profile replication using one of the following methods:
	- **NDB server API:**
		```
		DELETE https://<ERA_IP>/era/v0.9/profiles/<SW_PROFILE_ID>?cluster_id=<CLUSTER_ID>
		```
		- **NDB CLI:**
		```
		era > profile software update engine=<ENGINE> id=<SW_PROFILE_ID> remove_nx_cluster_availability=<CLUSTER_ID>
		```
- ERA-47459 Specifying a public SSH key during database provisioning is optional. But NDB does not allow you to specify an empty key through the API or CLI.
- ERA-47351 NDB fails to generate a new machine ID during VM provisioning or cloning if the template VM does not include the dbus-uuidgen utility, which can prevent the DBus service from starting or lead to an unreachable network IP.
	**Workaround**: Install the dbus-tools package on the template VM to ensure proper machine ID generation during VM operations.
- ERA-46941 The Time Machine Status dashboard tile counts deleted databases if the time machine was retained during deletion.
- ERA-44420 You cannot perform OS patching on database server VMs provisioned from the v1 version of OOB software profiles.
- ERA-44252 If a time machine is scheduled for backup only once a week or at longer intervals, the time machine health does not accurately reflect past failures.
- ERA-38670 NDB operations might fail due to stale volume groups with the following error message.
	ERA\_LOG\_DRIVE could not be deleted from the cluster. Details: device is busy, not able to unmount
	**Workaround**: Contact Nutanix support.
- ERA-34505 Nutanix recommends enabling periodic fstrim operations on all thin-provisioned Linux VMs. NDB does not enable this on its managed VMs, which can lead to inefficient storage utilization and storage alerts in Prism.
	**Workaround**:
	1. Ensure periodic fstrim is enabled on any custom software profile.
		2. If your cluster shows a space-usage alert from Prism, run the /sbin/fstrim --all command on the database server VMs.
		3. If the issue persists, contact Nutanix Support for help with identifying bloated volume groups and trimming them.

Oracle

- ERA-61464 Refresh of an Oracle RAC clone using ASMLIB v3 might fail intermittently at the Restore Database Snapshot step. The error indicates a failure to mount ASM disk groups. An internal Oracle error causes this issue.
	**Workaround**: Re-submit the refresh operation. In most cases, the refresh completes successfully on retry.
- ERA-60217 During the Provision DBServer Cluster workflow, if you provide a password input to update the provisioned VM password, NDB does not apply the new password. Instead, NDB provisions the VM with the same password configured in the gold image VM.
	**Workaround**: Manually update the VM password after the DBServer cluster provisioning completes.
- ERA-59311 The ASMLIB driver discovery now supports the new `oracleasmlib` v3 version. ASMLIB v3 does not honor the `oracle_asmlib_sector_size_512` flag. RAC with ASMLIB v3 does not work with Oracle 19.29 directly.
	**Workaround**: You must apply one-off patches and OJVM patches using RAC with ASMLIB v3 on Oracle 19.29. For more information, see [KB-21117](https://portal.nutanix.com/kb/21117).
- ERA-25205 Clone operation fails if the Oracle inventory resides outside the software disks mount point. This issue can occur if you perform an upgrade on a brownfield database server VM.
- ERA-13749 To verify the disks before Oracle database provisioning using the Oracle ASMLIB driver, enter the directory and run the KFOD utility using the disk string provided in the configuration.
	```
	# cd /u01/app/11.2.0/grid/bin
	#./kfod nohdr=true verbose=true disks=all op=disks dscvgroup=TRUE asm_diskstring='ORCL:*'
	```
	If the command does not return any disks, the ASM driver provisioning fails with the following error:
	```
	error in configuring Clusterware
	```
- ERA-25447 PDB provisioning fails when tablespaces are encrypted on the CDB.
- ERA-28702 Deleting an Oracle database does not clear the TNS entry in the database server VM. This results in provisioning failures when using the same global database name on the same database server VM. This issue applies only to single instance databases.
	**Workaround**: Use a different database name for provisioning.
- ERA-28680 Clone creation from a snapshot fails if MRP was running on an Oracle RAC node other than the node from which the snapshot was taken. The following error message appears:
	```
	Script error: Failed to recover database instance
	```
- ERA-24813 Provisioning 19c databases on RHEL/OEL 8.x requires Grid and RDBMS release update levels 19.7 or later.
- ERA-21775 Database provisioning fails if you use the sqlnet.ora file with OS \_AUTHENTICATION set to NTS in the gold image.
- ERA-28022 The extend database storage operation fails for Oracle 18c single instance databases.
- ERA-28933 Clone refresh operation fails when the clone database server VM is upgraded from Oracle 19c to 21c.
- Oracle database provisioning for SUSE does not work with XFS filesystem.
- ERA-35169 Oracle upgrade fails if there is more than one space between alias name and the = character in the tnsnames.ora file. The IFILE parameter is not supported.
	**Workaround**: Keep all TNS entries in the tnsnames.ora file before triggering an upgrade.
- ERA-32499 You must not create datafiles in the NDB software mount or database software as it can lead to downtime or corruption during database deletion and OOP database patching respectively.
- ERA-42058 Clone refresh operation fails with the following error for Oracle 19.23 version:
	Failed to restore database snapshot. Details: Failed to Restore Log drive. Reason: cannot find the required device.
- ERA-42258 RAC to RAC clone refresh operation fails with the following error for Oracle 19.23 with ASMFD:
	Failed to restore database snapshot due to an unexpected error.
- ERA-43598 In a disaster recovery (DR) setup, after you restore the primary database, the standby and cascaded databases stop working.
	**Workaround**: Delete the existing DR configuration and recreate the configuration to set up the standby and cascaded databases.
- ERA-55712 Oracle Udev provisioning may fail during Clusterware configuration when creating disk groups due to disk permission issues for the grid user. This typically occurs if the template VM or gold image contains a udev rules file named /etc/udev/rules.d/1-era-disks.rules.
	**Workaround**: Rename the /etc/udev/rules.d/1-era-disks.rules file in the template VM, recreate the software profile, and retry the provisioning.
- ERA-22780 Oracle RAC provisioning fails when a time difference exists between CVM nodes in the AHV cluster, displaying the following prerequisite error:
	Time offset between nodes
	**Workaround**: Ensure that the same system time is configured and synchronized across all CVM nodes within the AHV cluster.

SQL Server

- ERA-66842 After you rename a SQL Server database group, deleting a database from the group reports the operation as successful, but NDB does not remove the data and log disks from the database server VM. Orphan disks accumulate over repeated deletions and can eventually exceed the VSS 64-disk limit, which blocks subsequent operations with the following error: The database group \<name> contains more than 64 disks which is not supported during VSS snapshot.
	**Workaround**: Rename the database group back to its original name before you delete databases from it.
- ERA-58516 After you rename a SQL Server database group, the extend database storage operation and other storage-dependent operations fail with the following error: Failed to identify the database storage layout. Unable to proceed with the extend operation.
	**Workaround**: Rename the database group back to its original name before you perform extend storage or scale operations.
- ERA-66531 Provisioning a SQL Server Failover Cluster Instance (FCI) fails on Nutanix Cloud Clusters (NC2) during Windows Failover Cluster creation.
- ERA-22921 SQL Server provisioning operation times out when many disks are attached to the database server VM.
	**Workaround**: Increase the provisioning operation timeout.
- ERA-23171 Windows cluster creation fails when the domain user account does not have the **Log on as a batch job** privilege. NDB uses Windows Task Scheduler to create a new Windows Failover Cluster, and Windows Task Scheduler requires the **Log on as a batch job** privilege to execute commands. If the domain user account does not have this privilege, the cluster creation process fails.
	**Workaround**:
	1. Grant **Log on as a batch job** permission to the domain user name account.
		2. Set use\_era\_worker\_to\_execute\_task to **true** so that remote commands run in the context of the NDB Worker service account. Additionally, ensure that the NDB Worker service user has **Create Computer Objects** and **Delete Computer Objects** permissions on the target Organizational Unit (OU). For information on configuring the flag, see [KB 12761](https://portal.nutanix.com/kb/12761).
- ERA-25520 Non-super admin users cannot provision SQL Server AG database into the existing AGs owned by another RBAC user.
- ERA-29683 NDB does not list software profiles with patches for FCI provisioning, even when the software profiles have ISO.
	**Workaround**: Remove the software profile version.

PostgreSQL

- ERA-59681 Updating the access key or secret key for the configured object store breaks PostgreSQL HA deployments that use Objects archival.
	**Workaround**: For PostgreSQL HA deployments that do not use Objects archival, follow these steps:
	1. Create new keys under the same IAM user in the Prism Central UI.
		2. Use the NDB storage resource update API or CLI to update the access key and secret key.
		3. Delete the old keys from the Prism Central UI.
		4. Retain the existing IAM user in Prism Central.
- ERA-44346 Registration of PostgreSQL RHEL 9.4 database server VM with the private key provided as text fails with the following error:
	Login credentials for VM are incorrect
	**Workaround**:
	- Use the Upload File option to upload the private key file, or
		- Add a new line at the end of private key content.
- ERA-23241 When NDB HA configuration fails due to NTP issues, NDB provides a warning instead of an error.
	**Workaround**: Fix the NTP configuration issues before proceeding with the operation.

MongoDB

- ERA-63477 Associating a MongoDB sharded cluster that includes an arbiter node with MongoDB Ops Manager fails when the DB parameter profile sets the operation profiling mode to `all`. The failure occurs when Ops Manager stops and restarts the MongoDB processes during the association workflow.
	**Workaround**: Use one of the following options:
	- Set the operation profiling mode in the DB parameter profile to `slowOp` or `off` instead of `all`.
		- Provision the cluster without an arbiter node.
		- Manually stop the MongoDB process on the arbiter node before you start the associate operation, so that Ops Manager does not shut it down during its workflow.
- ERA-43656 NDB does not use the custom OS user while provisioning a database server VM from a time machine. The default user `mongod` is used instead.
- ERA-52576 When you provision a cluster with a delayed replica set member, the system enables voting on that node by default. MongoDB Ops Manager does not support delayed members with votes greater than 0 in MongoDB 4.4 and later. As a result, association with the Ops Manager fails.
	**Workaround**: To resolve this issue, update the replica set configuration to disable voting on the delayed member:
	1. Identify the index of the delayed node in the members list (0-based index).
		2. Connect to the database using mongosh and run the following command:
		```
		# Set delayedNodeIndex to the index of the delayed node
		cfg = rs.conf()
		cfg.members[delayedNodeIndex].votes = 0
		cfg.version += 1
		rs.reconfig(cfg, {force: true})
		```
- ERA-55914 When cloning from a registered MongoDB Single Instance or Replica Set, the clone operation might fail during the database startup phase if the selected DB parameter profile specifies directoryPerDB or directoryForIndexes values that differ from the source database configuration.
	**Workaround**: When cloning from registered MongoDB databases, ensure that the DB parameter profile settings for directoryPerDB and directoryForIndexes match the source database configuration to prevent recovery failures.
- ERA-57733 Delays in oplog delivery in MongoDB Ops Manager might cause NDB to report point-in-time recovery (PITR) availability gaps when the backup policy is configured as Secondary-Only or Secondary-Preferred. NDB might raise RPO breach alerts even when log backup operations complete successfully.
	**Workaround**: No action is required to resolve the gaps or alerts if the underlying infrastructure is healthy. For information on how to prevent gaps in the time machine timeline for MongoDB sharded clusters, see [KB 20975](https://portal.nutanix.com/kb/20975).
- ERA-58097 After you upgrade the MongoDB Ops Manager server or Ops Manager agents, log catchup or snapshot operations in NDB might fail with HTTP error code 500 when NDB invokes the Ops Manager API.
	**Workaround**: See [KB 21032](https://portal.nutanix.com/kb/21032).
- ERA-59901 For MongoDB sharded clusters, the periodic Refresh Stats operation does not update database metadata. Metadata updates only when you perform a manual refresh through a snapshot operation.
	**Workaround**: Storage statistics refresh during snapshot or log backup operations. Enable Time Machine for the MongoDB sharded cluster to ensure NDB refreshes storage statistics during each backup operation.

UI

- ERA-45581 If a clone is provisioned but the operation fails (for example, when rollback is disabled or the provisioning process terminates unexpectedly), the clone remains in the provisioning state. You cannot remove the failed clone through NDB UI.
	**Workaround**: Delete the failed clone through the NDB CLI.

## NDB Software Compatibility and Feature Support

Detailed compatibility information for NDB, including supported Nutanix and VMware products, database engines, and operating systems.

This section also includes the following feature support matrices:

Additionally, this section also outlines unsupported versions, Oracle ASM support, and browser requirements to help you plan and manage deployments effectively.

### NDB Software Compatibility with Nutanix and VMware Products

| Software | Version |
| --- | --- |
| AOS | 7.5, 7.3, 7.0, and 6.10 |
| AHV | AHV versions supported by AOS 7.5, 7.3, 7.0, and 6.10 |
| vSphere | 8.0 |

| Software | Version |
| --- | --- |
| Prism Central | 7.5, 7.3, 2024.3, and 2024.2 |
| Objects | 5.3, 5.2, and 5.1 |
| Flow Network Security Next-Gen | 5.0.0 |

### Oracle Software Compatibility and Feature Support

Supported Oracle database versions, operating system compatibility, and NDB feature support for Oracle SIDB, SIHA, and RAC deployments.

<table><caption>Table 1. Oracle Enterprise Edition Database and Operating System Versions Supported</caption> <colgroup><col> <col> <col></colgroup><thead><tr><th>Operating System</th><th>Operating System Version</th><th>Oracle Database versions</th></tr></thead><tbody><tr><td headers="reference_z4l_kfp_3dc__entry__1" rowspan="6">Oracle Enterprise Linux (OEL)</td><td headers="reference_z4l_kfp_3dc__entry__2">9.7</td><td headers="reference_z4l_kfp_3dc__entry__3">19.29 - 19.31</td></tr><tr><td headers="reference_z4l_kfp_3dc__entry__2">9.6</td><td headers="reference_z4l_kfp_3dc__entry__3">19.26 - 19.31</td></tr><tr><td headers="reference_z4l_kfp_3dc__entry__2">9.4</td><td headers="reference_z4l_kfp_3dc__entry__3">19.25 - 19.31</td></tr><tr><td headers="reference_z4l_kfp_3dc__entry__2">8.10</td><td headers="reference_z4l_kfp_3dc__entry__3"><ul><li>21.18 - 21.29</li><li>19.23 - 19.31</li></ul></td></tr><tr><td headers="reference_z4l_kfp_3dc__entry__2">8.8</td><td headers="reference_z4l_kfp_3dc__entry__3"><ul><li>21.18 - 21.21</li><li>19.21 - 19.24</li></ul></td></tr><tr><td headers="reference_z4l_kfp_3dc__entry__2">7.8 - 7.9</td><td headers="reference_z4l_kfp_3dc__entry__3"><ul><li>21.3 - 21.15</li><li>19.7 - 19.24</li><li>12.2</li><li>12.1</li><li>11.2</li></ul></td></tr><tr><td headers="reference_z4l_kfp_3dc__entry__1" rowspan="6">Red Hat Enterprise Linux (RHEL)</td><td headers="reference_z4l_kfp_3dc__entry__2">9.7</td><td headers="reference_z4l_kfp_3dc__entry__3">19.29 - 19.31</td></tr><tr><td headers="reference_z4l_kfp_3dc__entry__2">9.6</td><td headers="reference_z4l_kfp_3dc__entry__3">19.26 - 19.31</td></tr><tr><td headers="reference_z4l_kfp_3dc__entry__2">9.4</td><td headers="reference_z4l_kfp_3dc__entry__3">19.25 - 19.31</td></tr><tr><td headers="reference_z4l_kfp_3dc__entry__2">8.10</td><td headers="reference_z4l_kfp_3dc__entry__3"><ul><li>21.18 - 21.21</li><li>19.23 - 19.31</li></ul></td></tr><tr><td headers="reference_z4l_kfp_3dc__entry__2">8.8</td><td headers="reference_z4l_kfp_3dc__entry__3"><ul><li>21.18 - 21.19</li><li>19.21 - 19.24</li></ul></td></tr><tr><td headers="reference_z4l_kfp_3dc__entry__2">7.8 - 7.9</td><td headers="reference_z4l_kfp_3dc__entry__3"><ul><li>21.3 - 21.15</li><li>19.7 - 19.24</li><li>12.2</li><li>12.1</li><li>11.2</li></ul></td></tr></tbody></table>

For information on Oracle best practices, see [Oracle on Nutanix](https://portal.nutanix.com/page/documents/solutions/details?targetId=BP-2000-Oracle-on-Nutanix:BP-2000-Oracle-on-Nutanix).

Note:
- **Supported OS and Kernel Combinations**
	- **8.10**
		- OEL 8.10 (UEK7): kernel 5.15.0-206.153.7.1.el8uek.x86\_64
				- OEL 8.10 (RHCK): kernel 4.18.0-553.el8\_10.x86\_64
				- RHEL 8.10: kernel 4.18.0-553.el8\_10.x86\_64
		- **9.4**
		- OEL 9.4 (UEK7): kernel 5.15.0-205.149.5.1.el9uek.x86\_64
				- OEL 9.4 (RHCK): kernel 5.14.0-427.13.1.el9\_4.x86\_64
				- RHEL 9.4: kernel 5.14.0-427.13.1.el9\_4.x86\_64
		- **9.6**
		- OEL 9.6 (UEK8): kernel 6.12.0-1.23.3.2.el9uek.x86\_64
				- OEL 9.6 (RHCK): kernel 5.14.0-570.12.1.el9\_6.x86\_64
				- RHEL 9.6: kernel 5.14.0-570.12.1.el9\_6.x86\_64
		- **9.7**
		- OEL 9.7 (UEK8): kernel 6.12.0-105.51.5.1.el9uek.x86\_64
				- OEL 9.7 (RHCK): kernel 5.14.0-611.11.1.el9\_7.x86\_64
				- RHEL9.7: kernel 5.14.0-611.11.1.el9\_7.x86\_64
- **Oracle Automatic Storage Management (ASM) Support**
	Oracle deprecated ASMFD. Oracle recommends using ASMLIB for ASM disk management in new deployments and, where feasible, migrating existing environments to ASMLIB. For more information, see Oracle Support Doc ID 2806979.1.
	- **Oracle 19c (Versions 19.23–19.31)**
		- **OS 9.x**
			- All RHEL 9.x and OEL 9.x operating systems support UDEV only.
						- ASMFD and ASMLIB v2 are not supported.
						- Starting with Oracle 19.29, ASMLIB v3 is supported with recommended one-off patches. For more information, see [KB 21117](https://portal.nutanix.com/kb/21117) and [KB 21160](https://portal.nutanix.com/kb/21160).
				- **OS 8.x**
			- Starting with Oracle 19.27, RHEL 8.10 and OEL 8.10 support ASMFD. However, NDB recommends that you do not use ASMFD because Oracle has started deprecating it on newer kernels (Doc ID 2806979.1).
						- OEL 8.10 UEK7 kernel does not support ASMLIB v3.
						- RHEL 8.10 does not support ASMLIB v3.
						- For OS 8.10 with the RHCK kernel, ASMLIB using the `el8` and `oracleasm` packages works only with disks having 512-byte physical sector size. ASMLIB does not work with 4K sector size disks. In such cases, you must install the following EL7 `oracleasm` packages:
				- `oracleasm-support-2.1.11-2.el7.x86_64`
								- `oracleasmlib-2.0.12-1.el7.x86_64`
						- NDB supports ASMLIB v2 and ASMLIB v3. For more information, see [KB 21117](https://portal.nutanix.com/kb/21117) and [KB 21160](https://portal.nutanix.com/kb/21160). NDB qualifies the following Oracle ASMLIB v3 package versions:
				- RHEL/OEL 8
					- Oracle ASMLIB package: `oracleasmlib-3.1.1-1.el8.x86_64.rpm`
										- Oracle ASM support package: `oracleasm-support-3.1.1-4.el8.x86_64.rpm`
								- RHEL/OEL 9
					- Oracle ASMLIB package: `oracleasmlib-3.1.1-1.el9.x86_64.rpm`
										- Oracle ASM support package: `oracleasm-support-3.1.1-4.el9.x86_64.rpm`
		- **Oracle 21c (Patch 21.18 - 21.21)**
		- **OS 9.x**
			- RHEL 9.x and OEL 9.x systems do not support Oracle 21c.
				- **OS 8.x**
			- RHEL 8.10 and OEL 8.10 support only the UDEV ASM driver.
						- ASMFD and ASMLIB are not supported.

<table><caption>Table 2. NDB Features Matrix for Oracle</caption> <colgroup><col> <col> <col> <col></colgroup><thead><tr><th rowspan="2">NDB Feature</th><th colspan="3">Oracle Database</th></tr><tr><th>SIDB</th><th>SIHA</th><th>RAC</th></tr></thead><tbody><tr><td headers="reference_z4l_kfp_3dc__entry__30">Database Provision</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__32">Yes</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__33">Yes</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__34">Yes</td></tr><tr><td headers="reference_z4l_kfp_3dc__entry__30">Provision of multiple databases on the same database server VM</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__32">Yes</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__33">Yes</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__34">Yes</td></tr><tr><td headers="reference_z4l_kfp_3dc__entry__30">Provision of a database server VM on any Nutanix cluster</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__32">Yes</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__33">Yes</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__34">Yes</td></tr><tr><td headers="reference_z4l_kfp_3dc__entry__30">Copy data management (Clone/Refresh)</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__32">Yes</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__33">Yes</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__34">Yes</td></tr><tr><td headers="reference_z4l_kfp_3dc__entry__30">Database management as a group</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__32">No</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__33">No</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__34">No</td></tr><tr><td headers="reference_z4l_kfp_3dc__entry__30">Restore</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__32">Yes</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__33">Yes</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__34">Yes</td></tr><tr><td headers="reference_z4l_kfp_3dc__entry__30">Patching</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__32">Yes</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__33">Yes</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__34">Yes</td></tr><tr><td headers="reference_z4l_kfp_3dc__entry__30">Database scaling</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__32">Yes</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__33">Yes</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__34">Yes</td></tr><tr><td headers="reference_z4l_kfp_3dc__entry__30">Create Disaster Recovery</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__32">Yes</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__33">Yes</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__34">Yes</td></tr><tr><td headers="reference_z4l_kfp_3dc__entry__30">Switchover</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__32">Yes</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__33">Yes</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__34">Yes</td></tr><tr><td headers="reference_z4l_kfp_3dc__entry__30">Failover</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__32">Yes</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__33">Yes</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__34">Yes</td></tr></tbody></table>

Note:
- Database provisioning on an ESXi hypervisor fails if you provision the database using a software profile that is replicated from AHV to ESXi. Provisioning is applicable on the database server VMs running SUSE version 15 SP2 and Oracle database version 19c.
- NDB supports CDB/PDB. For more information, see [Nutanix Database Service Oracle Database Management Guide](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-Oracle-Database-Management-Guide-v2_8:top-oracle-pdb-cdb-c.html).

### SQL Server Software Compatibility and Feature Support

Supported SQL Server database versions, operating system compatibility, and NDB feature support for standalone, AG, and FCI deployments.

| Operating System | SQL Server Database Versions |
| --- | --- |
| Windows Server 2025 | - SQL Server 2025 (RTM) - SQL Server 2022 (RTM) - SQL Server 2019 (RTM) |
| Windows Server 2022 | - SQL Server 2025 (RTM) - SQL Server 2022 (RTM) - SQL Server 2019 (RTM) - SQL Server 2017 (RTM) |
| Windows Server 2019 | - SQL Server 2025 (RTM) - SQL Server 2022 (RTM) - SQL Server 2019 (RTM) - SQL Server 2017 (RTM) - SQL Server 2016 (SP3) - SQL Server 2014 (SP3) |
| Windows Server 2016 | - SQL Server 2022 (RTM) - SQL Server 2019 (RTM) - SQL Server 2017 (RTM) - SQL Server 2016 (SP3) - SQL Server 2014 (SP3) |

Note:
- NDB supports Nutanix Cloud Clusters (NC2) on AWS, Azure, and GCP for SQL Server.
- NDB supports the following SQL Server editions:
	- Enterprise
		- Standard
		- Developer
		- Express edition
		- Web edition
- For information on SQL Server best practices, see [Microsoft SQL Server on Nutanix](https://portal.nutanix.com/page/documents/solutions/details?targetId=BP-2015-Microsoft-SQL-Server:BP-2015-Microsoft-SQL-Server).

### SQL Server Versions Supported for AG

NDB supports the following SQL Server versions for Always On Availability Group (AG).

- SQL Server 2025 (standard, developer, and enterprise editions)
- SQL Server 2022 (standard, developer, and enterprise editions)
- SQL Server 2019 (standard, developer, and enterprise editions)
- SQL Server 2017 (standard, developer, and enterprise editions), requires CU16 (KB4508218) or above.
- SQL Server 2016 (standard, developer, and enterprise editions)
- SQL Server 2014 (developer and enterprise editions)

<table><caption>Table 2. Service Support Matrix for SQL Server Flavors</caption> <colgroup><col> <col> <col> <col> <col></colgroup><thead><tr><th rowspan="3">SQL Server Workflow</th><th>Registration</th><th colspan="3">Provision</th></tr><tr><th>Multi instance (Only one instance)</th><th>Single instance</th><th>Single and Multi Nutanix Cluster HA-AG</th><th>Single Nutanix Cluster HA-FCI</th></tr><tr><th>Disk Type: Standard/Dynamic/Storage Spaces Disk Layout: vDisk/VGLB</th><th>Disk Type: Standard/Dynamic/Storage Spaces Disk Layout: vDisk/VGLB</th><th>Disk Type: Standard/Dynamic/Storage Spaces Disk Layout: vDisk/VGLB</th><th>Disk Type: Standard Disk Layout: VGLB</th></tr></thead><tbody><tr><td headers="reference_e5w_sfp_3dc__entry__11">Provision database server VM</td><td headers="reference_e5w_sfp_3dc__entry__12 reference_e5w_sfp_3dc__entry__14 reference_e5w_sfp_3dc__entry__18">Not applicable</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__15 reference_e5w_sfp_3dc__entry__19">Yes</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__16 reference_e5w_sfp_3dc__entry__20">Yes</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__17 reference_e5w_sfp_3dc__entry__21">Yes</td></tr><tr><td headers="reference_e5w_sfp_3dc__entry__11">Register database server VM</td><td headers="reference_e5w_sfp_3dc__entry__12 reference_e5w_sfp_3dc__entry__14 reference_e5w_sfp_3dc__entry__18">Yes</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__15 reference_e5w_sfp_3dc__entry__19">Not applicable</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__16 reference_e5w_sfp_3dc__entry__20">Not applicable</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__17 reference_e5w_sfp_3dc__entry__21">Not applicable</td></tr><tr><td headers="reference_e5w_sfp_3dc__entry__11">Provision database</td><td headers="reference_e5w_sfp_3dc__entry__12 reference_e5w_sfp_3dc__entry__14 reference_e5w_sfp_3dc__entry__18">Yes</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__15 reference_e5w_sfp_3dc__entry__19">Yes</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__16 reference_e5w_sfp_3dc__entry__20">Yes</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__17 reference_e5w_sfp_3dc__entry__21">Yes</td></tr><tr><td headers="reference_e5w_sfp_3dc__entry__11">Register database</td><td headers="reference_e5w_sfp_3dc__entry__12 reference_e5w_sfp_3dc__entry__14 reference_e5w_sfp_3dc__entry__18">Yes</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__15 reference_e5w_sfp_3dc__entry__19">Not applicable</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__16 reference_e5w_sfp_3dc__entry__20">Not applicable</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__17 reference_e5w_sfp_3dc__entry__21">Not applicable</td></tr><tr><td headers="reference_e5w_sfp_3dc__entry__11">Copy Data Management - Snapshot and log catchup</td><td headers="reference_e5w_sfp_3dc__entry__12 reference_e5w_sfp_3dc__entry__14 reference_e5w_sfp_3dc__entry__18">Yes</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__15 reference_e5w_sfp_3dc__entry__19">Yes</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__16 reference_e5w_sfp_3dc__entry__20">Yes</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__17 reference_e5w_sfp_3dc__entry__21">Yes</td></tr><tr><td headers="reference_e5w_sfp_3dc__entry__11">Copy Data Management - Restore</td><td headers="reference_e5w_sfp_3dc__entry__12 reference_e5w_sfp_3dc__entry__14 reference_e5w_sfp_3dc__entry__18">Yes</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__15 reference_e5w_sfp_3dc__entry__19">Yes</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__16 reference_e5w_sfp_3dc__entry__20">Yes</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__17 reference_e5w_sfp_3dc__entry__21">No</td></tr><tr><td headers="reference_e5w_sfp_3dc__entry__11">Copy Data Management - Clone and Refresh</td><td headers="reference_e5w_sfp_3dc__entry__12 reference_e5w_sfp_3dc__entry__14 reference_e5w_sfp_3dc__entry__18">Yes, can clone to any database instance at the database server VM but NDB can only manage one instance.</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__15 reference_e5w_sfp_3dc__entry__19">Yes</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__16 reference_e5w_sfp_3dc__entry__20">Yes</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__17 reference_e5w_sfp_3dc__entry__21">Yes, clone to standalone instance.</td></tr><tr><td headers="reference_e5w_sfp_3dc__entry__11">Copy Data Management - Clustered Clone [AG] in Single Nutanix cluster</td><td headers="reference_e5w_sfp_3dc__entry__12 reference_e5w_sfp_3dc__entry__14 reference_e5w_sfp_3dc__entry__18">Yes</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__15 reference_e5w_sfp_3dc__entry__19">Yes</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__16 reference_e5w_sfp_3dc__entry__20">Yes</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__17 reference_e5w_sfp_3dc__entry__21">Yes</td></tr><tr><td headers="reference_e5w_sfp_3dc__entry__11">Copy Data Management - Clustered Clone [AG] across Multiple Nutanix clusters</td><td headers="reference_e5w_sfp_3dc__entry__12 reference_e5w_sfp_3dc__entry__14 reference_e5w_sfp_3dc__entry__18">No</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__15 reference_e5w_sfp_3dc__entry__19">No</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__16 reference_e5w_sfp_3dc__entry__20">No</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__17 reference_e5w_sfp_3dc__entry__21">No</td></tr><tr><td headers="reference_e5w_sfp_3dc__entry__11">Patching</td><td headers="reference_e5w_sfp_3dc__entry__12 reference_e5w_sfp_3dc__entry__14 reference_e5w_sfp_3dc__entry__18">Yes</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__15 reference_e5w_sfp_3dc__entry__19">Yes</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__16 reference_e5w_sfp_3dc__entry__20">Yes</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__17 reference_e5w_sfp_3dc__entry__21">No</td></tr><tr><td headers="reference_e5w_sfp_3dc__entry__11">Database group</td><td headers="reference_e5w_sfp_3dc__entry__12 reference_e5w_sfp_3dc__entry__14 reference_e5w_sfp_3dc__entry__18">Yes</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__15 reference_e5w_sfp_3dc__entry__19">Yes</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__16 reference_e5w_sfp_3dc__entry__20">Yes</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__17 reference_e5w_sfp_3dc__entry__21">Yes</td></tr><tr><td headers="reference_e5w_sfp_3dc__entry__11">Storage scaling of user database</td><td headers="reference_e5w_sfp_3dc__entry__12 reference_e5w_sfp_3dc__entry__14 reference_e5w_sfp_3dc__entry__18">No</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__15 reference_e5w_sfp_3dc__entry__19">Yes</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__16 reference_e5w_sfp_3dc__entry__20">Yes</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__17 reference_e5w_sfp_3dc__entry__21">No</td></tr></tbody></table>

Note:
- By default, NDB uses vDisks for provisioning databases.
- Provisioning databases using VGLB, storage spaces, or dynamic disks available as an advanced option using the configuration file.
- Restore and clone operations are supported for TDE-enabled Availability Group (AG) and standalone databases. For clone operations, ensure that the encryption keys and certificates used to protect the database are available and properly installed on the destination server before initiating the clone.
- NDB does not support multiple SQL Server instances in the same database server VM or Windows Server failover cluster.

### PostgreSQL Software Compatibility and Feature Support

<table><caption>Table 1. PostgreSQL Community Edition Database and Operating System Versions Supported</caption> <colgroup><col> <col> <col></colgroup><thead><tr><th>Operating System</th><th>Operating System Version</th><th>PostgreSQL Database Version</th></tr></thead><tbody><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__1" rowspan="2">Rocky Linux</td><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__2">9.7</td><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__3"><ul><li>18.0 - 18.4</li><li>17.0 - 17.10</li><li>16.0 - 16.14</li><li>15.0 - 15.18</li><li>14.0 - 14.23</li></ul></td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__2">9.6</td><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__3"><ul><li>17.0 - 17.10</li><li>16.0 - 16.14</li><li>15.0 - 15.18</li><li>14.0 - 14.23</li></ul></td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__1" rowspan="8">Red Hat Enterprise Linux (RHEL)</td><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__2">10</td><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__3"><ul><li>18.0 - 18.4</li><li>17.0 - 17.10</li></ul></td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__2">9.8</td><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__3"><ul><li>18.0 - 18.4</li><li>17.0 - 17.10</li><li>16.0 - 16.14</li><li>15.0 - 15.18</li><li>14.0 - 14.23</li></ul></td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__2">9.7</td><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__3"><ul><li>18.0 - 18.4</li><li>17.0 - 17.10</li><li>16.0 - 16.14</li><li>15.0 - 15.18</li><li>14.0 - 14.23</li></ul></td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__2">9.6</td><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__3"><ul><li>17.0 - 17.10</li><li>16.0 - 16.14</li><li>15.0 - 15.18</li><li>14.0 - 14.23</li></ul></td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__2">9.4</td><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__3"><ul><li>17.0 - 17.10</li><li>16.0 - 16.14</li><li>15.0 - 15.18</li><li>14.0 - 14.23</li></ul></td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__2">8.10</td><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__3"><ul><li>18.0 - 18.4</li><li>17.0 - 17.10</li><li>16.0 - 16.14</li><li>15.0 - 15.18</li><li>14.0 - 14.23</li></ul></td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__2">8.8</td><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__3"><ul><li>15.0 - 15.18</li></ul></td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__2">7.x</td><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__3"><ul><li>15.0 - 15.18</li><li>14.0 - 14.23</li><li>13.0 - 13.16</li></ul></td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__1" rowspan="3">Ubuntu Linux</td><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__2">24.04</td><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__3">18.0 - 18.4</td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__2">22.04</td><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__3"><ul><li>16.0 - 16.14</li><li>15.0 - 15.18</li></ul></td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__2">20.04</td><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__3"><ul><li>15.0 - 15.18</li><li>14.0 - 14.23</li><li>13.0 - 13.16</li></ul></td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__1" rowspan="2">Debian</td><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__2">12</td><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__3"><ul><li>18.0 - 18.4</li><li>17.5 - 17.10</li><li>16.9 - 16.14</li></ul></td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__2">11</td><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__3"><ul><li>17.5 - 17.10</li><li>16.9 - 16.14</li><li>15.12 - 15.18</li></ul></td></tr></tbody></table>

For information on PostgreSQL best practices, see [PostgreSQL on Nutanix](https://portal.nutanix.com/page/documents/solutions/details?targetId=BP-2061-PostgreSQL-on-Nutanix:BP-2061-PostgreSQL-on-Nutanix).

Note: Ensure that the line `Conflicts` in the file `firewalld.service` does not include `nftables.service`.

<table><caption>Table 2. PostgreSQL EDB Enterprise Edition Database and Operating System Versions Supported</caption> <colgroup><col> <col> <col></colgroup><thead><tr><th>Operating System</th><th>Operating System Version</th><th>PostgreSQL Database Version</th></tr></thead><tbody><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__38" rowspan="6">RHEL</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__39">10</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__40"><ul><li>18.0 - 18.4</li><li>17.0 - 17.10</li></ul></td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__39">9.7</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__40"><ul><li>18.0 - 18.4</li><li>17.0 - 17.10</li><li>16.0 - 16.14</li><li>15.0 - 15.18</li><li>14.0 - 14.23</li></ul></td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__39">9.6</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__40"><ul><li>17.0 - 17.10</li><li>16.0 - 16.14</li><li>15.0 - 15.18</li><li>14.0 - 14.23</li></ul></td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__39">9.4</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__40"><ul><li>17.0 - 17.10</li><li>16.0 - 16.14</li><li>15.0 - 15.18</li><li>14.0 - 14.23</li></ul></td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__39">8.10</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__40"><ul><li>18.0 - 18.4</li><li>17.0 - 17.10</li><li>16.0 - 16.14</li><li>15.0 - 15.18</li><li>14.0 - 14.23</li></ul></td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__39">8.8</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__40"><ul><li>16.0 - 16.14</li><li>15.0 - 15.18</li></ul></td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__38" rowspan="2">Ubuntu</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__39">24.04</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__40">18.0 - 18.4</td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__39">20.04</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__40"><ul><li>15.0 - 15.18</li><li>14.0 - 14.23</li></ul></td></tr></tbody></table>

Note:
- NDB supports PostgreSQL database with EnterpriseDB Advanced Server (EPAS) tool but not any other EDB tools.
- NDB supports PostgreSQL EDB versions without Transparent Data Encryption (TDE).
- Ensure that the line `Conflicts` in the file `firewalld.service` does not include `nftables.service`.

| NDB Feature | Single Instance | High Availability |
| --- | --- | --- |
| Database Provision | Yes | Yes |
| Provision of database Replicas across Nutanix clusters | Not applicable | Yes |
| Provision of multiple database instance on the same VM | No | No |
| Provision of multiple databases in the same database server VM | Yes | Yes |
| Provision of database server VM on any Nutanix cluster | Yes | Yes |
| Copy data management (Clone/Refresh) | Yes (can only create a single instance clone from a single database instance) | Yes (can only create a single instance clone from a HA instance) |
| Database management as a group | No | No |
| Restore | Yes | Yes |
| Patching | Yes\* | Yes\* |
| Database scaling | Yes | Yes |

\*When installing the database using a Linux package manager like DNF or YUM, the PostgreSQL version shown in yum list or dnf list might differ from the actual database version when using NDB patching. This discrepancy does not affect database operations or compatibility with NDB management features.

<table><caption>Table 4. Software Required for PostgreSQL Provisioning</caption> <colgroup><col> <col> <col> <col> <col> <col></colgroup><thead><tr><th>PostgreSQL Community/EDB</th><th>OS</th><th>Patroni</th><th>etcd</th><th>HAProxy*</th><th>Keepalived</th></tr></thead><tbody><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__92" rowspan="7">18.0 - 18.4</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__93">RHEL 9.7</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__94">4.0.5</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__95">3.5.12</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__96">2.8.9</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__97">***2.2.8</td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__93">**Rocky Linux 9.7</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__94">4.0.5</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__95">3.5.12</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__96">2.8.9</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__97">2.2.8</td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__93">RHEL 8.10</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__94">4.0.5</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__95">3.5.12</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__96">2.8.9</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__97">2.1.5</td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__93">**Rocky Linux 8.10</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__94">4.0.5</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__95">3.5.12</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__96">2.8.9</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__97">2.1.5</td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__93">**Ubuntu 22.04</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__94">4.0.5</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__95">3.5.12</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__96">2.8.9</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__97">2.2.4</td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__93">Ubuntu 24.04</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__94">4.0.5</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__95">3.5.12</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__96">2.9.16</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__97">2.2.8</td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__93">**Debian 12</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__94">4.0.5</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__95">3.5.12</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__96">2.8.9</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__97">2.2.7</td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__92" rowspan="4">17.2 - 17.10</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__93">RHEL 9.7/9.6/9.4/8.10</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__94">*4.0.5/3.3.2</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__95">3.5.12</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__96">2.8.9</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__97">2.2.8</td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__93">**Rocky Linux 9.7/9.6</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__94">4.0.5/ 3.2.2</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__95">3.5.12</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__96">2.8.9</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__97">2.2.8</td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__93">RHEL 8.8</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__94">3.2.2</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__95">3.4.20</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__96">1.8.27</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__97">2.1.5</td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__93">**Debian 12</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__94">4.0.5</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__95">3.5.12</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__96">2.8.9</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__97">2.2.7</td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__92" rowspan="5">16.2 - 16.14</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__93">RHEL 9.7/9.6/9.4/8.10</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__94">4.0.5/ 3.3.2</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__95">3.5.12</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__96">2.8.9</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__97">2.2.8</td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__93">**Rocky Linux 9.7/9.6</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__94">4.0.5/ 3.2.2</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__95">3.5.12</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__96">2.8.9</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__97">2.2.8</td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__93">RHEL 8.8</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__94">3.2.2</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__95">3.4.20</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__96">1.8.27</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__97">2.1.5</td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__93">**Ubuntu 22.04</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__94">3.2.2</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__95">3.5.12</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__96">2.8.9</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__97">2.2.8</td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__93">**Debian 12</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__94">4.0.5</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__95">3.5.12</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__96">2.8.9</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__97">2.2.7</td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__92" rowspan="5">15.8 - 15.18</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__93">**Rocky Linux 9.7/9.6</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__94">3.2.2</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__95">3.5.12</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__96">2.8.9</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__97">2.2.8</td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__93">RHEL 9.7/9.6/9.4/8.10</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__94">3.2.2</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__95">3.5.12</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__96">2.8.9</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__97">2.2.8</td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__93">RHEL 8.6</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__94">2.1.4</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__95">3.4.20</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__96">1.8.27</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__97">2.1.5</td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__93">**Ubuntu 22.04</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__94">3.2.2</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__95">3.5.12</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__96">2.8.9</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__97">2.2.8</td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__93">Ubuntu 20.04</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__94">2.1.4</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__95">3.2.26</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__96">2.0.29</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__97">2.0.19</td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__92" rowspan="3">14.15 - 14.23</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__93">**Rocky Linux 9.7/ 9.6</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__94">3.2.2</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__95">3.5.12</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__96">2.8.9</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__97">2.2.8</td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__93">RHEL 9.7/ 9.6/ 9.4/ 8.10</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__94">3.2.2</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__95">3.5.12</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__96">2.8.9</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__97">2.2.8</td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__93">Ubuntu 20.04</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__94">2.1.4</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__95">3.2.26</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__96">2.0.29</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__97">2.0.19</td></tr></tbody></table>

Note:
- \*Patroni versions earlier than 4.x do not support or manage the new GUC parameters introduced by PostgreSQL 17.
- \*\*Supported for PostgreSQL Community Edition only.
- \*\*\*For PostgreSQL EDB on RHEL 9.7 with PostgreSQL 18, use Keepalived 2.1.5.
- Ensure that the line Conflicts in the file `firewalld.service` does not include `nftables.service`.

<table><caption>Table 5. Qualified OS versions and PostgreSQL versions for PostgreSQL extensions</caption> <colgroup><col> <col> <col></colgroup><thead><tr><th>Qualified PostgreSQL Extensions</th><th>OS Version</th><th>PostgreSQL/EDB Version</th></tr></thead><tbody><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__223" rowspan="2">pg_vector</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__224"><ul><li>RHEL 9.4</li></ul></td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__225"><ul><li>16.9</li></ul></td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__224"><ul><li>RHEL 8.10</li></ul></td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__225"><ul><li>EPAS 15.6</li></ul></td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__223" rowspan="3"><ul><li>TimescaleDB</li><li>pgAudit</li><li>pg_cron</li><li>set_user</li><li>PostGIS</li></ul></td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__224"><ul><li>RHEL 9.4</li></ul></td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__225"><ul><li>16.9</li></ul></td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__224"><ul><li>RHEL 8.4</li></ul></td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__225"><ul><li>14</li></ul></td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__224"><ul><li>RHEL 8.6</li></ul></td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__225"><ul><li>14</li></ul></td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__223"><ul><li>pg_partman</li><li>pg_logical</li><li>pg_stat_statements</li><li>citext</li><li>dblink</li><li>pg_stat_monitor</li><li>pg_trgm</li><li>pgcrypto</li><li>pgstattuple</li><li>plpgsql</li><li>postgres_fdw</li><li>tablefunc</li><li>pg_lo</li></ul></td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__224"><ul><li>RHEL 9.4</li></ul></td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__225"><ul><li>16.9</li></ul></td></tr></tbody></table>

### MongoDB Software Compatibility and Feature Support

<table><caption>Table 1. MongoDB Database and Operating System Versions Supported for Single Instance and Replica Set</caption> <colgroup><col> <col> <col></colgroup><thead><tr><th>Operating System</th><th>Operating System Version</th><th>MongoDB Database Versions</th></tr></thead><tbody><tr><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_tfk_kw5_v4__entry__1" rowspan="2">Rocky Linux</td><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_tfk_kw5_v4__entry__2">9.7</td><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_tfk_kw5_v4__entry__3"><ul><li>8.0.0 - 8.0.23 Community and Enterprise</li><li>7.0 - 7.0.34 Community and Enterprise</li><li>6.0.4 - 6.0.27 Community and Enterprise</li></ul></td></tr><tr><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_tfk_kw5_v4__entry__2">9.6</td><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_tfk_kw5_v4__entry__3"><ul><li>8.0.0 - 8.0.23 Community and Enterprise</li><li>7.0 - 7.0.34 Community and Enterprise</li><li>6.0.4 - 6.0.27 Community and Enterprise</li></ul></td></tr><tr><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_tfk_kw5_v4__entry__1" rowspan="5">Red Hat Enterprise Linux (RHEL)</td><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_tfk_kw5_v4__entry__2">9.7</td><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_tfk_kw5_v4__entry__3"><ul><li>8.0.0 - 8.0.23 Community and Enterprise</li><li>7.0 - 7.0.34 Community and Enterprise</li><li>6.0.4 - 6.0.27 Community and Enterprise</li></ul></td></tr><tr><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_tfk_kw5_v4__entry__2">9.6</td><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_tfk_kw5_v4__entry__3"><ul><li>8.0.0 - 8.0.23 Community and Enterprise</li><li>7.0 - 7.0.34 Community and Enterprise</li><li>6.0.4 - 6.0.27 Community and Enterprise</li></ul></td></tr><tr><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_tfk_kw5_v4__entry__2">9.5</td><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_tfk_kw5_v4__entry__3"><ul><li>8.0.0 - 8.0.23 Community and Enterprise</li><li>7.0 - 7.0.34 Community and Enterprise</li><li>6.0.4 - 6.0.27 Community and Enterprise</li></ul></td></tr><tr><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_tfk_kw5_v4__entry__2">9.4</td><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_tfk_kw5_v4__entry__3"><ul><li>8.0.0 - 8.0.23 Community and Enterprise</li><li>7.0 - 7.0.34 Community and Enterprise</li><li>6.0.4 - 6.0.27 Community and Enterprise</li></ul></td></tr><tr><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_tfk_kw5_v4__entry__2">8.10</td><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_tfk_kw5_v4__entry__3"><ul><li>7.0 - 7.0.34 Community and Enterprise</li><li>6.0.4 - 6.0.27 Community and Enterprise</li></ul></td></tr><tr><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_tfk_kw5_v4__entry__1" rowspan="2">Ubuntu Linux</td><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_tfk_kw5_v4__entry__2">22.04</td><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_tfk_kw5_v4__entry__3"><ul><li>8.0.0 - 8.0.23 Community and Enterprise</li><li>7.0 - 7.0.34 Community and Enterprise</li><li>6.0.4 - 6.0.27 Community and Enterprise</li></ul></td></tr><tr><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_tfk_kw5_v4__entry__2">20.04</td><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_tfk_kw5_v4__entry__3"><ul><li>7.0 - 7.0.34 Community and Enterprise</li><li>6.0.4 - 6.0.27 Community and Enterprise</li></ul></td></tr><tr><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_tfk_kw5_v4__entry__1" rowspan="2">Debian Linux</td><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_tfk_kw5_v4__entry__2">12</td><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_tfk_kw5_v4__entry__3"><ul><li>8.0.0 - 8.0.23 Community and Enterprise</li><li>7.0 - 7.0.37 Community</li></ul></td></tr><tr><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_tfk_kw5_v4__entry__2">11</td><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_tfk_kw5_v4__entry__3"><ul><li>7.0 - 7.0.34 Community and Enterprise</li><li>6.0.0 - 6.0.27 Community and Enterprise</li></ul></td></tr></tbody></table>

Note:
- NDB supports MongoDB Enterprise and Community editions.
- NDB supports WiredTiger (default storage engine for MongoDB) for all supported MongoDB versions.

<table><caption>Table 2. MongoDB Database and Operating System Versions Supported for Sharded Cluster</caption> <colgroup><col> <col> <col> <col></colgroup><thead><tr><th>Operating System</th><th>Operating System Version</th><th>MongoDB Database Versions</th><th>MongoDB Ops Manager Version</th></tr></thead><tbody><tr><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_cfz_pnb_rdc__entry__1" rowspan="2">Rocky Linux</td><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_cfz_pnb_rdc__entry__2">9.7</td><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_cfz_pnb_rdc__entry__3"><ul><li>8.0.0 - 8.0.23 Enterprise</li><li>7.0 - 7.0.34 Enterprise</li></ul></td><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_cfz_pnb_rdc__entry__4" rowspan="2">Not qualified</td></tr><tr><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_cfz_pnb_rdc__entry__2">9.6</td><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_cfz_pnb_rdc__entry__3"><ul><li>8.0.0 - 8.0.23 Enterprise</li><li>7.0 - 7.0.34 Enterprise</li></ul></td></tr><tr><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_cfz_pnb_rdc__entry__1" rowspan="5">Red Hat Enterprise Linux (RHEL)</td><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_cfz_pnb_rdc__entry__2">9.7</td><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_cfz_pnb_rdc__entry__3"><ul><li>8.0.0 - 8.0.23 Enterprise</li><li>7.0 - 7.0.34 Enterprise</li></ul></td><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_cfz_pnb_rdc__entry__4" rowspan="5">Ops Manager Server 8.0.19</td></tr><tr><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_cfz_pnb_rdc__entry__2">9.6</td><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_cfz_pnb_rdc__entry__3"><ul><li>8.0.0 - 8.0.23 Enterprise</li><li>7.0 - 7.0.34 Enterprise</li></ul></td></tr><tr><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_cfz_pnb_rdc__entry__2">9.5</td><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_cfz_pnb_rdc__entry__3"><ul><li>8.0.0 - 8.0.23 Enterprise</li><li>7.0 - 7.0.34 Enterprise</li></ul></td></tr><tr><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_cfz_pnb_rdc__entry__2">9.4</td><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_cfz_pnb_rdc__entry__3"><ul><li>8.0.0 - 8.0.23 Enterprise</li><li>7.0 - 7.0.34 Enterprise</li></ul></td></tr><tr><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_cfz_pnb_rdc__entry__2">8.10</td><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_cfz_pnb_rdc__entry__3"><ul><li>7.0 - 7.0.34 Enterprise</li></ul></td></tr></tbody></table>

For information on MongoDB best practices, see [MongoDB on Nutanix](https://portal.nutanix.com/page/documents/solutions/details?targetId=BP-2023-MongoDB-on-Nutanix:BP-2023-MongoDB-on-Nutanix).

| NDB Feature | Single Instance | Replica Set | Sharded Cluster |
| --- | --- | --- | --- |
| Registration of cluster databases deployed across Nutanix clusters | Not applicable | Not applicable | No |
| Database Provision | Yes | Yes | Yes |
| Provision of database Replicas across Nutanix clusters | Not applicable | Yes | Yes |
| Provision of multiple database instance on the same VM | No | No | No |
| Provision of multiple databases in the same database server VM | No\* | No\* | No |
| Provision of database server VM on any Nutanix cluster | Yes | Yes | Yes |
| Copy data management (Clone/Refresh) | Yes (can only create a single instance clone from a single database instance) | Yes (can only create a single instance clone from a single database instance) | No |
| Database management as a group | No | No | No |
| Restore | Yes | Yes | Yes |
| Patching | Yes\*\* | Yes\*\* | No |
| Database scaling | Yes | Yes | No |

\*Not using NDB, but you can perform the provisioning through the MongoDB Instance. You must log into a MongoDB instance through the CLI or a management tool.

\*\*Patching through NDB or outside of NDB is not supported if you use a Linux package manager such as YUM to install the database engine.

### MySQL and MariaDB Software Compatibility and Feature Support

<table><caption>Table 1. MySQL Database and Operating System Versions Supported</caption> <colgroup><col> <col> <col></colgroup><thead><tr><th>Operating System</th><th>Operating System Version</th><th>MySQL Database Versions</th></tr></thead><tbody><tr><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__table_tfk_kw5_v4__entry__1">Rocky Linux</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__table_tfk_kw5_v4__entry__2">9.7</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__table_tfk_kw5_v4__entry__3"><ul><li>*8.4.5 Community and Enterprise</li><li>8.0.36 - 8.0.43 Community</li><li>8.0.43 Enterprise (Oracle)</li></ul></td></tr><tr><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__table_tfk_kw5_v4__entry__1" rowspan="4">RHEL</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__table_tfk_kw5_v4__entry__2">10</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__table_tfk_kw5_v4__entry__3">8.4.5 Community and Enterprise</td></tr><tr><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__table_tfk_kw5_v4__entry__2"><ul><li>9.7</li><li>9.6</li></ul></td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__table_tfk_kw5_v4__entry__3"><ul><li>*8.4.5 Community and Enterprise</li><li>8.0.36 - 8.0.45 Community</li><li>8.0.43 Enterprise (Oracle)</li></ul></td></tr><tr><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__table_tfk_kw5_v4__entry__2"><ul><li>9.5</li><li>9.4</li></ul></td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__table_tfk_kw5_v4__entry__3"><ul><li>8.0.26 Enterprise (Oracle)</li><li>8.0.36 Community</li></ul></td></tr><tr><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__table_tfk_kw5_v4__entry__2">8.10</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__table_tfk_kw5_v4__entry__3"><ul><li>*8.4.5 Community and Enterprise</li><li>8.0.36 - 8.0.43 Community</li><li>8.0.26 Enterprise (Oracle)</li></ul></td></tr><tr><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__table_tfk_kw5_v4__entry__1" rowspan="3">Ubuntu Linux</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__table_tfk_kw5_v4__entry__2">24.04</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__table_tfk_kw5_v4__entry__3">8.0.36 - 8.0.45 Community and Enterprise</td></tr><tr><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__table_tfk_kw5_v4__entry__2">22.04</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__table_tfk_kw5_v4__entry__3">8.0.36 - 8.0.45 Community and Enterprise</td></tr><tr><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__table_tfk_kw5_v4__entry__2">20.04</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__table_tfk_kw5_v4__entry__3">8.0 Community</td></tr><tr><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__table_tfk_kw5_v4__entry__1" rowspan="2">Debian Linux</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__table_tfk_kw5_v4__entry__2">12</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__table_tfk_kw5_v4__entry__3">8.0.36 - 8.0.45 Community</td></tr><tr><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__table_tfk_kw5_v4__entry__2">11</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__table_tfk_kw5_v4__entry__3">8.0.36 - 8.0.45 Community and Enterprise (Oracle)</td></tr></tbody></table>

Note:
- \*Versions supported for MySQL HA.
- On RHEL and Rocky Linux 9.N, disable the `use_devicesfile` setting by setting `use_devicesfile = 0` in the file /etc/lvm/lvm.conf on the DB Server VM used to create the NDB software profile.

<table><caption>Table 2. MariaDB Database and Operating System Versions Supported</caption> <colgroup><col> <col> <col></colgroup><thead><tr><th>Operating System</th><th>Operating System Version</th><th>MariaDB Database Versions</th></tr></thead><tbody><tr><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__28">Rocky Linux</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__29">9.7</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__30">10.11 Community</td></tr><tr><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__28" rowspan="5">RHEL</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__29">10</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__30">11.8.6 Community</td></tr><tr><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__29">9.6</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__30">11.8.4 Community</td></tr><tr><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__29">9.5</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__30">10.11 Community</td></tr><tr><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__29">9.4</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__30">10.6 Enterprise</td></tr><tr><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__29">8.10</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__30"><ul><li>10.11 Community</li><li>10.6 Enterprise</li></ul></td></tr><tr><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__28" rowspan="3">Ubuntu</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__29">24.10</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__30">11.8 Community</td></tr><tr><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__29">24.04</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__30">11.8.4 Community</td></tr><tr><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__29">22.04</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__30"><ul><li>10.11 Community</li><li>10.6 Enterprise</li></ul></td></tr><tr><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__28" rowspan="2">Debian</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__29">12</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__30">10.11 Community and Enterprise</td></tr><tr><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__29">11</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__30">10.11 Community</td></tr></tbody></table>

For information on MySQL best practices, see [MySQL on Nutanix](https://portal.nutanix.com/page/documents/solutions/details?targetId=BP-2056-MySQL-on-Nutanix:BP-2056-MySQL-on-Nutanix).

<table><caption>Table 3. NDB Features Matrix for MySQL and MariaDB</caption> <colgroup><col> <col> <col> <col></colgroup><thead><tr><th rowspan="2">NDB Feature</th><th rowspan="2">Single Instance (MySQL and MariaDB)</th><th colspan="2">High Availability</th></tr><tr><th>MySQL</th><th>MariaDB</th></tr></thead><tbody><tr><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__57">Database Provision</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__58">Yes</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__59 ndb-compatibility-mysql-mariadb-v2_6-r__entry__60">Yes</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__59 ndb-compatibility-mysql-mariadb-v2_6-r__entry__61">No</td></tr><tr><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__57">Provision of database Replicas across Nutanix clusters</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__58">Not applicable</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__59 ndb-compatibility-mysql-mariadb-v2_6-r__entry__60">Yes</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__59 ndb-compatibility-mysql-mariadb-v2_6-r__entry__61">No</td></tr><tr><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__57">Provision of multiple database instance on the same VM</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__58">No</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__59 ndb-compatibility-mysql-mariadb-v2_6-r__entry__60">Not applicable</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__59 ndb-compatibility-mysql-mariadb-v2_6-r__entry__61">Not applicable</td></tr><tr><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__57">Provision of multiple databases in the same database server VM</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__58">Yes</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__59 ndb-compatibility-mysql-mariadb-v2_6-r__entry__60">Yes</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__59 ndb-compatibility-mysql-mariadb-v2_6-r__entry__61">Not applicable</td></tr><tr><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__57">Provision of database server VM on any Nutanix cluster</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__58">Yes</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__59 ndb-compatibility-mysql-mariadb-v2_6-r__entry__60">Yes</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__59 ndb-compatibility-mysql-mariadb-v2_6-r__entry__61">Not applicable</td></tr><tr><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__57">Copy data management (Clone/Refresh)</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__58">Yes (can only create a single instance clone from a single database instance)</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__59 ndb-compatibility-mysql-mariadb-v2_6-r__entry__60">No</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__59 ndb-compatibility-mysql-mariadb-v2_6-r__entry__61">Not applicable</td></tr><tr><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__57">Database management as a group</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__58">No</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__59 ndb-compatibility-mysql-mariadb-v2_6-r__entry__60">Not applicable</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__59 ndb-compatibility-mysql-mariadb-v2_6-r__entry__61">Not applicable</td></tr><tr><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__57">Restore</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__58">No</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__59 ndb-compatibility-mysql-mariadb-v2_6-r__entry__60">No</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__59 ndb-compatibility-mysql-mariadb-v2_6-r__entry__61">No</td></tr><tr><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__57">Patching</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__58">No</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__59 ndb-compatibility-mysql-mariadb-v2_6-r__entry__60">No</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__59 ndb-compatibility-mysql-mariadb-v2_6-r__entry__61">No</td></tr><tr><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__57">Database scaling</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__58">No</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__59 ndb-compatibility-mysql-mariadb-v2_6-r__entry__60">No</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__59 ndb-compatibility-mysql-mariadb-v2_6-r__entry__61">No</td></tr></tbody></table>

### Browser Compatibility

For the best user experience, access the NDB user interface using one of the following supported browsers.

| Browser | Version |
| --- | --- |
| Mozilla Firefox | 132.0.1 or later |
| Google Chrome | 135.0 or later |
| Apple Safari | 18.1 or later |