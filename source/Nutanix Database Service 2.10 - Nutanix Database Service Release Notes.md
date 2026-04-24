---
title: "Nutanix Database Service 2.10 - Nutanix Database Service Release Notes"
source: "https://portal.nutanix.com/page/documents/details?targetId=Release-Notes-Nutanix-NDB-v2_10:portal-full-page-view-html"
author:
published:
created: 2026-04-20
description:
tags:
  - "clippings"
---
## Nutanix Database Service Release Notes

Tags:

Nutanix Database Service

2.10

## Nutanix Database Service Release Notes

## Overview

Nutanix Database Service (NDB) automates and simplifies database administration, bringing one-click simplicity and seamless automations to database provisioning and life-cycle management. NDB enables database administrators to perform operations such as database registration, provisioning, cloning, patching, restore and more. It allows administrators to define provisioning standards with end-state-driven functionality that includes network segmentation, High Availability (HA) database deployments, and more. With NDB multi-clusters, you can easily manage databases across multiple locations, both on-prem and in the cloud, with Nutanix Cloud Clusters (NC2).

Note: To upgrade to NDB 2.10, you must be running a 2.8.x version or later. NDB versions 2.7.x or earlier require an intermediate upgrade to 2.8.x before upgrading to 2.10. Attempting a direct upgrade from 2.7.x to 2.10 fails.

This release includes several resolved issues. For more information, see.

For information about the known issues in this release, see.

For detailed information about the product, see [Nutanix Database Service Administration Guide](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide).

## NDB 2.10 Installation or Upgrade

NDB 2.10 installation or upgrade related information.

Important:
- Ensure that NDB is running version 2.8.x or later before upgrading to NDB 2.10.
- Before upgrading to NDB 2.10, run the NDB upgrade precheck tool to verify required pre-upgrade conditions and help ensure a successful upgrade. For more information on the precheck tool, see [KB 20810](https://portal.nutanix.com/kb/20810).

To download the NDB upgrade bundle, see [Nutanix Database Service page](https://portal.nutanix.com/page/downloads?product=ndb).

After you upgrade NDB to a new version, wait for at least 15 seconds and refresh the page to load the latest user interface.

For more information, see:

- [NDB Installation](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide:top-installation-c.html) in Nutanix Database Service Administration Guide.
- [NDB Upgrade Management](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide:top-version-upgrade-c.html) in Nutanix Database Service Administration Guide.

## What's New in NDB 2.10

New features and enhancements in NDB 2.10.

This release includes the following new features and enhancements:

### Features

Backup and Restore Support for MongoDB Sharded Cluster

NDB now supports backup, restore, and point-in-time recovery (PITR) capabilities for MongoDB sharded clusters by integrating with the MongoDB Ops Manager Third-Party Backup Platforms.

NDB orchestrates and controls the complete backup and restore workflow, while Ops Manager coordinates MongoDB-specific operations across shards and config servers. This integration ensures synchronized snapshots, consistent point-in-time recovery, and enforcement of MongoDB-native consistency requirements across the cluster.

For more information, see [MongoDB Ops Manager Registration for Sharded Cluster](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-MongoDB-Database-Management-Guide:top-mongodb-sharded-ops-manager-registration-c.html) in Nutanix Database Service MongoDB Database Management Guide.

Prism Central and Objects Store Management from NDB Web Console

NDB now supports managing the lifecycle of one or more Prism Central and Nutanix Objects instances directly from the NDB web console.

For more information, see [Registering Prism Central with NDB](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide:top-ndb-pc-register-t.html) and [Creating an Object Store in NDB](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide:top-ndb-create-object-store-t.html) in Nutanix Database Service Administration Guide.

MySQL High Availability (HA) provisioning support through NDB Web Console

NDB now supports provisioning of MySQL High Availability (HA) instances across different Nutanix clusters through NDB web console.

For more information, see [Provisioning a MySQL HA Instance](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-MySQL-Database-Management-Guide:top-mysql-db-provision-console-t.html) in Nutanix Database Service MySQL Database Management Guide.

Custom Drive Letter Support for SQL Server Data, Log, and TempDB Disks

NDB now supports configuring custom drive letters for SQL Server data and log disks for both provisioned and cloned databases, and for tempdb disks on provisioned DB Server VMs. You can define the drive letters using a global configuration setting. NDB applies the configured drive letters to all newly provisioned and cloned SQL Server databases, and creates data, log, and tempdb files on the specified drives.

For more information, see the Provisioning databases using Custom Drive Letter Configuration for Data and Log Disks section of [SQL Server Database Provisioning](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-SQL-Server-Database-Management-Guide:top-sql-server-database-provision-c.html) in Nutanix Database Service SQL Server Database Management Guide.

Custom IP, AG Listener Name, and Port Selection for SQL Server Provisioning and Cloning

NDB now supports specifying custom IP addresses, Availability Group (AG) listener names, and listener ports during SQL Server provisioning and cloning operations. By default, NDB automatically allocates IP addresses from the associated network profile VLAN and uses the SQL Server instance port for the AG listener. With this enhancement, you can override the default assignments and manually configure IP address, listener name, and port for database server VMs, AG listeners, Failover Cluster Instances, and Windows Server Failover Clusters. These customization options are not supported for network profiles configured with DHCP. For IPAM-managed VLANs, NDB supports IP selection when provisioning standalone SQL Server VMs. NDB does not support the use of IPAM-managed VLANs when provisioning SQL Server HA configurations.

For more information, see [SQL Server Database Provisioning](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-SQL-Server-Database-Management-Guide:top-sql-server-database-provision-c.html) and [SQL Server Database Clone](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-SQL-Server-Database-Management-Guide:top-sql-server-db-clone-c.html) sections in Nutanix Database Service SQL Server Database Management Guide.

### Enhancements

MongoDB TDE enhancements with KMS Master Key and Certificate Rotation Support

NDB now supports KMS master key and certificate rotation for MongoDB Enterprise. You can create a new KMS key or a new version of an existing key and use NDB to rotate the master key for your MongoDB deployments. During provisioning, NDB configures MongoDB with the required KMS connection details and master key identifiers, enabling secure encryption management through KMS integration.

For more information, see [Native Database Encryption](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide:top-ndb-native-db-encryption-c.html) in Nutanix Database Service Administration Guide.

Support for VLANs managed by Flow Virtual Networking Network Controller and extended networking support for MongoDB Replica Sets

NDB extends its networking support to include VLANs managed by the Flow Virtual Networking Network Controller across the NDB control plane and all supported database engines.

NDB now also supports a mix of different VLAN types (basic VLANs, VLANs, and overlay subnets) within MongoDB cluster network profiles. If you use different types of subnets, make sure that they can communicate with each other.

For more information, see [Migrating to Flow Virtual Networking Network Controller VLANs](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide:top-migrating_flow_network_controller_t.html).

Security Enhancements through Updated Directory Permissions

NDB enhances the security of Linux file and directory permissions and introduces rsyslog logging for Oracle database engines.

**PostgreSQL Database Monitoring and Reliability Enhancements**

PostgreSQL HA clusters now detect and reflect primary and standby role changes in real time, including for NDB repository databases. The topology view updates immediately when roles transition, regardless of whether Time Machine is enabled. NDB also improves status monitoring accuracy for databases and nodes. NDB automatically creates a dedicated read-only monitoring user in the managed database and the NDB repository database on each PostgreSQL VM.

NDB deploys and manages a dedicated PostgreSQL monitoring service on all PostgreSQL VMs to enable these capabilities.

Storage Health Monitoring and Alerting Enhancements

Storage capacity monitoring now supports configurable thresholds and automatically clears alerts when usage drops below the configured level. NDB applies this enhancement to all database server VMs, including Linux and Windows.

NDB deploys and manages a dedicated storage monitoring service on all database server VMs to enable these capabilities. The storage monitoring service starts automatically after a VM reboot.

Enhanced Log Collection with Time-Range-Based filtering

NDB CLI now allows you to collect diagnostic logs for specific time windows to reduce bundle sizes and streamline troubleshooting. This feature includes customizable time offsets and automatic size limits.

For more information, see [Downloading the Diagnostics Bundle Using the NDB CLI](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide:top-diagnostics-download-cli-t.html) in Nutanix Database Service Administration Guide.

## Resolved Issues

This release resolves the following issues:

General

ERA-56484 Resolved an issue where the diagnostic bundle download failed for VMs with a positive UTC offset.

ERA-47439 Resolved an issue where creating an entity sharing policy failed when clones were shared with Active Directory (AD) groups with MANAGE access.

ERA-46636 Resolved an issue where the AD group refresh operation was reported as successful in the UI even when authentication failed due to invalid service account credentials or a disabled service account.

Oracle

ERA-53054 Resolved an issue where snapshot-based Oracle database clones failed to start because of inconsistent db\_unique\_name directory renaming across ASM disk groups (DATADG and RECODG). This inconsistency caused control file path mismatches when control files were multiplexed across multiple disk groups.

ERA-47413 Resolved an issue where Oracle log catchup deleted archive logs before log copy to object storage completed Oracle log catchup operations now wait for the log copy to object storage to complete before deleting archive logs from the staging drive, preventing potential Time Machine gaps. This ensures only successfully uploaded logs are purged.

ERA-46901 Resolved an issue where the use\_devicesfile configuration was enabled by default on RHEL 9.x, which caused NDB-provisioned VMs to fail to boot after a restart.

ERA-29638 Resolved an issue where NDB could not read the /etc/oraInst.loc file when restrictive permissions prevented access. As a result, custom Oracle installation paths were not detected during software profile creation, and provisioned databases used default Oracle home paths instead of the source paths, even when oracle\_use\_source\_software\_path\_provision was enabled.

ERA-22716 Resolved an extend storage issue that caused the removal of a database physical disk during rollback, resulting in service downtime.

SQL Server

ERA-52436 Resolved an issue in the CLI that caused AG provisioning to fail when the cluster\_resource\_type parameter was specified during new AAG provisioning.

ERA-51390 Resolved an issue where provisioning an Always On Availability Group (AG) database to an existing Windows Server Failover Cluster (WSFC) using a gMSA through a Windows domain profile failed due to a NetBIOS name resolution error.

ERA-49790 Resolved an issue where system-triggered log catch-up fails during AG restore operations due to an EraActiveNode mismatch. The failure occurred when restore, snapshot replication, and log catch-up operations overlapped, causing inconsistent era metadata during recovery.

ERA-48035 Resolved an issue where SQL Server provisioning from backup failed due to a drive letter conflict when network drives were mounted in an interactive session.

PostgreSQL

ERA-47236 Resolved an issue where, if after-local was already configured to boot at rc-local, NDB added the same configuration again.

MongoDB

ERA-42848 Resolved an issue where VMs were not automatically cleaned up in certain scenarios after the sharded cluster provisioning operation was stopped.

ERA-57890 Resolved an issue where Brownfield MongoDB replica set registration fails with `ERA-INT-0000001` and `NoneType` errors during host IP lookup in multi-cluster environments; Brownfield registration for multi-cluster MongoDB is now fully supported.

MySQL

ERA-56810 Resolved an issue where special characters were not supported in the MySQL Group Replication password. Previously, passwords were restricted to alphanumeric characters. NDB now supports special characters, including space, (<), (>), (%),(;), and (,), enabling stronger and more secure passwords.

ERA-56612 Resolved an issue where provisioning a DB group into an existing WSFC fails when a gMSA is used.

ERA-56088 Resolved an issue where MySQL Router details were not displayed in the CLI output for MySQL HA clusters.

ERA-57756 Enabled hugepages support for MySQL HA VMs. Hugepages reduce memory management overhead, lower page table lookups, and help improve database performance by reducing TLB misses and page faults.

ERA-32030 Resolved an issue where a systemd service for a MySQL or MariaDB instance was not created by NDB during the clone workflow.

## Known Issues

NDB Upgrade

NDB upgrade functionality has the following known issues:
- ERA-47727 During an upgrade, after the NDB Server upgrade is complete but before the DB Server upgrades finish, time machines may enter a critical state. This occurs if the backup schedule is not met during the upgrade. The issue is expected in high-scale environments with high-frequency backups (15-minute intervals). Time machines automatically exit the critical state once the upgrade is complete.
- ERA-53275 Databases that were provisioned with a private key under a non-SLA configuration and upgraded from NDB 2.8 to a later version might retain the private key file in the temp directory after upgrade. This does not impact any database functionality. Databases configured with non-NONE SLA automatically clean up keys as part of normal operations, and databases freshly provisioned on versions higher than 2.8 are not affected.
	**Workaround**: You can manually delete the keys from the following directory:
	/opt/era\_base/era\_server\_config/temp/keys/

General

- ERA-61272 On NDB High Availability (HA) configurations, the recover\_ca\_certificates.py script fails to import the CA certificates after a recovery operation. This failure results in a missing Java keystore and SSL handshake errors.
	**Workaround**: You can manually delete the failed CA certificate entries from the NDB console or CLI, import the PEM files, and restart services to restore the Java keystore. For more information, see [Configuring Post-Recovery Environment for NDB Control Plane](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide:top-ndb-cp-configure-post-recovery-environment-t.html).
- ERA-60339 During the qualification of Ubuntu 24.04, the rsyslog-ndb service fails to start because of stricter AppArmor profiles introduced in AppArmor v4.x.
	**Workaround**: For NDB 2.10, you must apply the following workaround to use Ubuntu 24.04 with any supported database engine.
	- Log in to the gold image VM as the root user.
	- Disable the AppArmor profile for rsyslogd by running the following command:
		```
		sudo ln -s /etc/apparmor.d/usr.sbin.rsyslogd /etc/apparmor.d/disable/
		```
- ERA-58015 Remote cluster registration fails on AOS 7.3.0.6 because access to port 2020 is restricted.
	**Workaround**: See [KB 20664](https://portal.nutanix.com/kb/20664).
- ERA-38670 NDB operations might fail due to stale volume groups with the following error message.
	ERA\_LOG\_DRIVE could not be deleted from the cluster. Details: device is busy, not able to unmount
	**Workaround**: Contact Nutanix support.
- ERA-34505 Nutanix recommends enabling periodic fstrim operations on all thin-provisioned Linux VMs. NDB does not enable this on its managed VMs, which can lead to inefficient storage utilization and storage alerts in Prism.
	**Workaround**:
	1. Ensure periodic fstrim is enabled on any custom software profile.
	2. If your cluster shows a space-usage alert from Prism, run the /sbin/fstrim --all command on the database server VMs.
	3. If the issue persists, contact Nutanix Support for help with identifying bloated volume groups and trimming them.
- ERA-39460 In a single-cluster NDB HA deployment with Objects-based log catchup, log copy fails intermittently with the following error:
	Error while copying logs: SSL validation failed for <endpoint\_url>
	**Workaround**: No action is required.
- ERA-44252 If a time machine is scheduled for backup only once a week or at longer intervals, the time machine health does not accurately reflect past failures.
- ERA-44420 You cannot perform OS patching on database server VMs provisioned from the v1 version of OOB software profiles.
- ERA-46413 Adding a DAM policy to a paused time machine results in inconsistent behaviour.
	**Workaround**: Resume the time machine before adding new DAM policies.
- ERA-46941 The Time Machine Status dashboard tile counts deleted databases if the time machine was retained during deletion.
- ERA-47170 If you increase the number of daily snapshots, Phantom Schedule Misses might occur. If a schedule miss is reported on your timeline within 24 hours of the change, verify whether a snapshot was expected.
- ERA-47351 NDB fails to generate a new machine ID during VM provisioning or cloning if the template VM does not include the dbus-uuidgen utility, which can prevent the DBus service from starting or lead to an unreachable network IP.
	**Workaround**: Install the dbus-tools package on the template VM to ensure proper machine ID generation during VM operations.
- ERA-47459 Specifying a public SSH key during database provisioning is optional. But NDB does not allow you to specify an empty key through the API or CLI.
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
- ERA-54945 VM provisioning on ESXi may fail during the hostnamectl command execution if the template VM has Nutanix Guest Tools (NGT) installed.
	**Workaround**: Uninstall NGT from the template VM and retry provisioning using a new software profile.
- ERA-55373 On-demand snapshot creation fails with the error, failed to load details era drive info when a user who is not the Time Machine owner executes the operation, even if the user has Manage or Full Access through Entity Sharing.
	**Workaround**: Run the operation using the Time Machine owner’s credentials. Alternatively, share View access to the Time Machine’s DB Server VMs with the user in addition to sharing the Time Machine.

Oracle

- ERA-60217 During the Provision DBServer Cluster workflow, if you provide a password input to update the provisioned VM password, NDB does not apply the new password. Instead, NDB provisions the VM with the same password configured in the gold image VM.
	**Workaround**: Manually update the VM password after the DBServer cluster provisioning completes.
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
	**Workaround**:Ensure that the same system time is configured and synchronized across all CVM nodes within the AHV cluster.

SQL Server

- ERA-18480 When the source SQL instance from which the software profile is created has SQL Server Analysis Services feature installed, FCI installation fails with the following error:
	'-2054422508', "Instance name '<instance\_name>' is already in use. To continue, specify a unique instance name."
	This applies only if the FCI instance has the same name as the original one.
	**Workaround**: Create a software profile from an instance where SQL Analysis Services feature is not installed.
- ERA-22921 SQL Server provisioning operation times out when many disks are attached to the database server VM.
	**Workaround**: Increase the provisioning operation timeout.
- ERA-23171 Windows cluster creation fails when the domain user account does not have the **Log on as a batch job** privilege. NDB uses Windows Task Scheduler to create a new Windows Failover Cluster, and Windows Task Scheduler requires the **Log on as a batch job** privilege to execute commands. If the domain user account does not have this privilege, the cluster creation process fails.
	**Workaround**:
	1. Grant **Log on as a batch job** permission to the domain user name account.
	2. Set use\_era\_worker\_to\_execute\_task to **true** so that remote commands run in the context of the NDB Worker service account. Additionally, ensure that the NDB Worker service user has **Create Computer Objects** and **Delete Computer Objects** permissions on the target Organizational Unit (OU). For information on configuring the flag, see [KB 12761](https://portal.nutanix.com/kb/12761).
- ERA-25520 Non-super admin users cannot provision SQL Server AG database into the existing AGs owned by another RBAC user.
- ERA-29683 NDB does not list software profiles with patches for FCI provisioning, even when the software profiles have ISO.
	**Workaround**: Remove the software profile version.
- ERA-57562 SQL Server 2022 provisioning fails when the Hyper-V PowerShell module is missing.
	**Workaround**: For Windows Server 2025 Standard edition VMs:
	- If you are creating a new software profile, install Hyper-V PowerShell on the template VM before creating the profile.
	- If the DBVM or cluster is already provisioned, install Hyper-V PowerShell manually on each DBVM before registering it with NDB.
	To install Hyper-V PowerShell, run the following command:
	```
	Install-WindowsFeature -Name Hyper-V-PowerShell -IncludeManagementTools
	```

PostgreSQL

- ERA-23241 When NDB HA configuration fails due to NTP issues, NDB provides a warning instead of an error.
	**Workaround**: Fix the NTP configuration issues before proceeding with the operation.
- ERA-44346 Registration of PostgreSQL RHEL 9.4 database server VM with the private key provided as text fails with the following error:
	Login credentials for VM are incorrect
	**Workaround:**
	- Use the Upload File option to upload the private key file, or
	- Add a new line at the end of private key content.
- ERA-59681 Updating the access key or secret key for the configured object store breaks PostgreSQL HA deployments that use Objects archival.
	**Workaround**: For PostgreSQL HA deployments that do not use Objects archival, follow these steps:
	1. Create new keys under the same IAM user in the Prism Central UI.
	2. Use the NDB storage resource update API or CLI to update the access key and secret key.
	3. Delete the old keys from the Prism Central UI.
	4. Retain the existing IAM user in Prism Central.

MongoDB

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
- ERA-54219 Associating MongoDB Ops Manager with a provisioned cluster fails if the cluster name or any replica set name (including shard replica sets or the config server replica set) contains a dot (.). MongoDB Ops Manager does not support dots in cluster or replica set names and treats such names as invalid during association.
	**Workaround**:
	- If the cluster does not contain critical data, provision a new cluster with a name that does not include a dot (.) and ensure that all replica set names (including shard and config server replica sets) do not contain dots. Then associate the new cluster with MongoDB Ops Manager.
	- If the existing cluster contains data:
		- Provision a new cluster with a dot-free cluster name and dot-free replica set names.
			- Migrate the data from the existing cluster to the new cluster based on data size and downtime requirements.
			- Associate the new database with MongoDB Ops Manager.
- ERA-55914 When cloning from a registered MongoDB Single Instance or Replica Set, the clone operation might fail during the database startup phase if the selected DB parameter profile specifies directoryPerDB or directoryForIndexes values that differ from the source database configuration.
	**Workaround**: When cloning from registered MongoDB databases, ensure that the DB parameter profile settings for directoryPerDB and directoryForIndexes match the source database configuration to prevent recovery failures.
- ERA-58484 Snapshot creation for a MongoDB sharded cluster database fails while taking a snapshot on Nutanix AOS. Temporary communication issues or network interruptions between the AOS cluster and the NDB API server might cause the create-snapshot API call to fail.
	**Workaround**: Verify that the Nutanix AOS cluster and the NDB server are operational, and retry the snapshot operation. If the issue persists, contact Nutanix Support.
- ERA-57733 Delays in oplog delivery in MongoDB Ops Manager might cause NDB to report point-in-time recovery (PITR) availability gaps when the backup policy is configured as Secondary-Only or Secondary-Preferred. NDB might raise RPO breach alerts even when log backup operations complete successfully.
	**Workaround**: No action is required to resolve the gaps or alerts if the underlying infrastructure is healthy. For information on how to prevent gaps in the time machine timeline for MongoDB sharded clusters, see [KB 20975](https://portal.nutanix.com/kb/20975).
- ERA-58097 After you upgrade the MongoDB Ops Manager server or Ops Manager agents, log catchup or snapshot operations in NDB might fail with HTTP error code 500 when NDB invokes the Ops Manager API.
	**Workaround**: See [KB 21032](https://portal.nutanix.com/kb/21032).
- ERA-59901 For MongoDB sharded clusters, the periodic Refresh Stats operation does not update database metadata. Metadata updates only when you perform a manual refresh through a snapshot operation.
	**Workaround**: Storage statistics refresh during snapshot or log backup operations. Enable Time Machine for the MongoDB sharded cluster to ensure NDB refreshes storage statistics during each backup operation.

UI

- ERA-53039 In an NDB cluster running on Object Storage, the Time Machine Overview page in the NDB console displays only cluster storage usage information and does not include Object storage usage.
	**Workaround**: View the Time Machine Properties page to see the correct storage information.
- ERA-47499 During NDB onboarding, configuring the SMTP server from the NDB UI with Security set to None fails due to a validation issue, even when valid SMTP details are provided.
	**Workaround**: Configure or update the SMTP settings from the NDB UI after completing onboarding.
	- To set up the notifications email:
		Log on to the NDB console and navigate to Settings \> NDB Service \> Configure Notifications \> SMTP Server Configuration \> Update.
	- To update the default notifications email:
		Log on to the NDB console and navigate to Admin \> Update SMTP Mail ID, and update the SMTP configuration.
- ERA-45581 If a clone is provisioned but the operation fails (for example, when rollback is disabled or the provisioning process terminates unexpectedly), the clone remains in the provisioning state. You cannot remove the failed clone through NDB UI.
	**Workaround**: Delete the failed clone through the NDB CLI.

## NDB Software Compatibility and Feature Support

Detailed compatibility information for NDB, including supported Nutanix and VMware products, database engines, and operating systems.

This section also includes the following feature support matrices:

Additionally, it outlines unsupported versions, Oracle ASM support, and browser requirements to help you plan and manage deployments effectively.

### NDB Software Compatibility with Nutanix and VMware Products

| Software | Version |
| --- | --- |
| AOS | 7.3, 7.0, and 6.10 |
| AHV | AHV versions supported by AOS 7.3, 7.0, and 6.10 |
| vSphere | 8.0 |

| Software | Version |
| --- | --- |
| Prism Central | 2024.2, 2024.3 and 7.3 |
| Objects | 5.1 and 5.2 |
| Flow Network Security Next-Gen | 5.0.0 |

| Software | Version |
| --- | --- |
| AOS | 6.5 |
| vSphere | 7.0 |
| Objects | 5.0 |
| Oracle | 18 |

### Oracle Software Compatibility and Feature Support

<table><caption>Table 1. Oracle Enterprise Edition Database and Operating System Versions Supported</caption> <colgroup><col> <col> <col></colgroup><thead><tr><th>Operating System</th><th>Operating System Version</th><th>Oracle Database versions</th></tr></thead><tbody><tr><td headers="reference_z4l_kfp_3dc__entry__1" rowspan="6">Oracle Enterprise Linux (OEL)</td><td headers="reference_z4l_kfp_3dc__entry__2">9.7</td><td headers="reference_z4l_kfp_3dc__entry__3"><ul><li>19.30</li><li>19.29</li></ul></td></tr><tr><td headers="reference_z4l_kfp_3dc__entry__2">9.6</td><td headers="reference_z4l_kfp_3dc__entry__3">19.26 - 19.30</td></tr><tr><td headers="reference_z4l_kfp_3dc__entry__2">9.4</td><td headers="reference_z4l_kfp_3dc__entry__3">19.25 - 19.30</td></tr><tr><td headers="reference_z4l_kfp_3dc__entry__2">8.10</td><td headers="reference_z4l_kfp_3dc__entry__3"><ul><li>21.18 - 21.21</li><li>19.23 - 19.30</li></ul></td></tr><tr><td headers="reference_z4l_kfp_3dc__entry__2">8.8</td><td headers="reference_z4l_kfp_3dc__entry__3"><ul><li>21.18 - 21.19</li><li>19.21 - 19.24</li></ul></td></tr><tr><td headers="reference_z4l_kfp_3dc__entry__2">7.8 - 7.9</td><td headers="reference_z4l_kfp_3dc__entry__3"><ul><li>21.3 - 21.15</li><li>19.7 - 19.24</li><li>12.2</li><li>12.1</li><li>11.2</li></ul></td></tr><tr><td headers="reference_z4l_kfp_3dc__entry__1" rowspan="6">Red Hat Enterprise Linux (RHEL)</td><td headers="reference_z4l_kfp_3dc__entry__2">9.7</td><td headers="reference_z4l_kfp_3dc__entry__3"><ul><li>19.30</li><li>19.29</li></ul></td></tr><tr><td headers="reference_z4l_kfp_3dc__entry__2">9.6</td><td headers="reference_z4l_kfp_3dc__entry__3">19.26 - 19.30</td></tr><tr><td headers="reference_z4l_kfp_3dc__entry__2">9.4</td><td headers="reference_z4l_kfp_3dc__entry__3">19.25 - 19.30</td></tr><tr><td headers="reference_z4l_kfp_3dc__entry__2">8.10</td><td headers="reference_z4l_kfp_3dc__entry__3"><ul><li>21.18 - 21.21</li><li>19.23 - 19.30</li></ul></td></tr><tr><td headers="reference_z4l_kfp_3dc__entry__2">8.8</td><td headers="reference_z4l_kfp_3dc__entry__3"><ul><li>21.18 - 21.19</li><li>19.21 - 19.24</li></ul></td></tr><tr><td headers="reference_z4l_kfp_3dc__entry__2">7.8 - 7.9</td><td headers="reference_z4l_kfp_3dc__entry__3"><ul><li>21.3 - 21.15</li><li>19.7 - 19.24</li><li>12.2</li><li>12.1</li><li>11.2</li></ul></td></tr></tbody></table>

For information on Oracle best practices, see [Oracle on Nutanix](https://portal.nutanix.com/page/documents/solutions/details?targetId=BP-2000-Oracle-on-Nutanix:BP-2000-Oracle-on-Nutanix).

Note:
- **Supported OS and Kernel Combinations**
	- **8.10**
		- OEL 8.10 (UEK6): kernel 5.15.0-206.153.7.1.el8uek.x86\_64
				- OEL 8.10 (RHCK): kernel 4.18.0-553.el8\_10.x86\_64
				- RHEL 8.10: kernel 4.18.0-553.el8\_10.x86\_64
		- **9.4**
		- OEL 9.4 (UEK 7): kernel 5.15.0-205.149.5.1.el9uek.x86\_64
				- OEL 9.4 (RHCK): kernel 5.14.0-427.13.1.el9\_4.x86\_64
				- RHEL9.4: kernel 5.14.0-427.13.1.el9\_4.x86\_64
		- **9.6**
		- OEL 9.6 (UEK 8 ): kernel 6.12.0-1.23.3.2.el9uek.x86\_64
				- OEL 9.6 (RHCK): kernel 5.14.0-570.12.1.el9\_6.x86\_64
				- RHEL 9.6: kernel 5.14.0-570.12.1.el9\_6.x86\_64
		- **9.7**
		- OEL 9.7(UEK 8): kernel 6.12.0-105.51.5.1.el9uek.x86\_64
				- OEL 9.7(RHCK): kernel 5.14.0-611.11.1.el9\_7.x86\_64
				- RHEL9.7: kernel 5.14.0-611.11.1.el9\_7.x86\_64
- **Oracle Automatic Storage Management (ASM) Support**
	- **Oracle 19c (Versions 19.23–19.30)**
		- **OS 9.x**
			- All RHEL 9.x and OEL 9.x operating systems support UDEV only.
						- ASMFD and ASMLIB are not supported.
				- **OS 8.x**
			- Starting with Oracle 19.27, RHEL 8.10 and OEL 8.10 support ASMFD. However, NDB recommends not to use ASMFD because Oracle has started deprecating it on newer kernels (Doc ID 2806979.1).
						- OEL 8.10 UEK7 kernel does not support ASMLIB.
						- For OS 8.10 with the RHCK kernel, ASMLIB using the el8 oracleasm packages works only with disks having 512-byte physical sector size. ASMLIB does not work with 4K sector size disks. In such cases, you must install the following EL7 oracleasm packages:
				- oracleasm-support-2.1.11-2.el7.x86\_64
								- oracleasmlib-2.0.12-1.el7.x86\_64
						- NDB currently supports ASMLIB v2.
		- **Oracle 21c (Patch 21.18 - 21.21)**
		- **OS 9.x**
			- RHEL 9.x and OEL 9.x systems do not support Oracle 21c.
				- **OS 8.x**
			- RHEL 8.10 and OEL 8.10 support only the UDEV ASM driver.
						- ASMFD and ASMLIB are not supported.

<table><caption>Table 2. NDB Features Matrix for Oracle</caption> <colgroup><col> <col> <col> <col></colgroup><thead><tr><th rowspan="2">NDB Feature</th><th colspan="3">Oracle Database</th></tr><tr><th>SIDB</th><th>SIHA</th><th>RAC</th></tr></thead><tbody><tr><td headers="reference_z4l_kfp_3dc__entry__30">Database Provision</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__32">Yes</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__33">Yes</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__34">Yes</td></tr><tr><td headers="reference_z4l_kfp_3dc__entry__30">Provision of multiple databases in the same database server VM</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__32">Yes</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__33">Yes</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__34">Yes</td></tr><tr><td headers="reference_z4l_kfp_3dc__entry__30">Provision of database server VM on any Nutanix cluster</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__32">Yes</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__33">Yes</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__34">Yes</td></tr><tr><td headers="reference_z4l_kfp_3dc__entry__30">Copy data management (Clone/Refresh)</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__32">Yes</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__33">Yes</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__34">Yes</td></tr><tr><td headers="reference_z4l_kfp_3dc__entry__30">Database management as a group</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__32">No</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__33">No</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__34">No</td></tr><tr><td headers="reference_z4l_kfp_3dc__entry__30">Restore</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__32">Yes</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__33">Yes</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__34">Yes</td></tr><tr><td headers="reference_z4l_kfp_3dc__entry__30">Patching</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__32">Yes</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__33">Yes</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__34">Yes</td></tr><tr><td headers="reference_z4l_kfp_3dc__entry__30">Database scaling</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__32">Yes</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__33">Yes</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__34">Yes</td></tr><tr><td headers="reference_z4l_kfp_3dc__entry__30">Create Disaster Recovery</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__32">Yes</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__33">Yes</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__34">Yes</td></tr><tr><td headers="reference_z4l_kfp_3dc__entry__30">Switchover</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__32">Yes</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__33">Yes</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__34">Yes</td></tr><tr><td headers="reference_z4l_kfp_3dc__entry__30">Failover</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__32">Yes</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__33">Yes</td><td headers="reference_z4l_kfp_3dc__entry__31 reference_z4l_kfp_3dc__entry__34">Yes</td></tr></tbody></table>

Note:
- Database provisioning on an ESXi hypervisor fails if you provision the database using a software profile that is replicated from AHV to ESXi. This is applicable on the database server VMs running SUSE version 15 SP2 and Oracle database version 19c.
- NDB supports CDB/PDB. For more information, see [Nutanix Database Service Oracle Database Management Guide](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-Oracle-Database-Management-Guide-v2_8:top-oracle-pdb-cdb-c.html).

### SQL Server Software Compatibility and Feature Support

| Operating System | SQL Server Database Versions |
| --- | --- |
| Windows Server 2025 | - SQL Server 2022 (RTM) - SQL Server 2019 (RTM) |
| Windows Server 2022 | - SQL Server 2022 (RTM) - SQL Server 2019 (RTM) - SQL Server 2017 (RTM) |
| Windows Server 2019 | - SQL Server 2022 (RTM) - SQL Server 2019 (RTM) - SQL Server 2017 (RTM) - SQL Server 2016 (SP3) - SQL Server 2014 (SP3) |
| Windows Server 2016 | - SQL Server 2022 (RTM) - SQL Server 2019 (RTM) - SQL Server 2017 (RTM) - SQL Server 2016 (SP3) - SQL Server 2014 (SP3) |

Note:
- NDB supports Nutanix Cloud Clusters (NC2) on AWS and Azure for SQL Server.
- NDB supports the following SQL Server editions:
	- Enterprise
		- Standard
		- Developer
		- Express edition
		- Web edition
- For information on SQL Server best practices, see [Microsoft SQL Server on Nutanix](https://portal.nutanix.com/page/documents/solutions/details?targetId=BP-2015-Microsoft-SQL-Server:BP-2015-Microsoft-SQL-Server).

### SQL Server Versions Supported for AG

NDB supports the following SQL Server version for Always On Availability Group (AG).

- SQL Server 2022 (standard, developer, and enterprise editions)
- SQL Server 2019 (standard, developer, and enterprise editions)
- SQL Server 2017 (standard, developer, and enterprise editions), requires CU16 (KB4508218) or above.
- SQL Server 2016 (standard, developer, and enterprise editions)
- SQL Server 2014 (developer and enterprise editions)

<table><caption>Table 2. Service Support Matrix for SQL Server Flavors</caption> <colgroup><col> <col> <col> <col> <col></colgroup><thead><tr><th rowspan="3">SQL Server Workflow</th><th>Registration</th><th colspan="3">Provision</th></tr><tr><th>Multi instance (Only one instance)</th><th>Single instance</th><th>Single and Multi Nutanix Cluster HA - AG</th><th>Single Nutanix Cluster HA -FCI</th></tr><tr><th>Disk Type: Standard/Dynamic/Storage Spaces Disk Layout: vDisk/VGLB</th><th>Disk Type: Standard/Dynamic/Storage Spaces Disk Layout: vDisk/VGLB</th><th>Disk Type: Standard/Dynamic/Storage Spaces Disk Layout: vDisk/VGLB</th><th>Disk Type: Standard Disk Layout: VGLB</th></tr></thead><tbody><tr><td headers="reference_e5w_sfp_3dc__entry__11">Provision database server VM</td><td headers="reference_e5w_sfp_3dc__entry__12 reference_e5w_sfp_3dc__entry__14 reference_e5w_sfp_3dc__entry__18">Not applicable</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__15 reference_e5w_sfp_3dc__entry__19">Yes</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__16 reference_e5w_sfp_3dc__entry__20">Yes</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__17 reference_e5w_sfp_3dc__entry__21">Yes</td></tr><tr><td headers="reference_e5w_sfp_3dc__entry__11">Register database server VM</td><td headers="reference_e5w_sfp_3dc__entry__12 reference_e5w_sfp_3dc__entry__14 reference_e5w_sfp_3dc__entry__18">Yes</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__15 reference_e5w_sfp_3dc__entry__19">Not applicable</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__16 reference_e5w_sfp_3dc__entry__20">Not applicable</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__17 reference_e5w_sfp_3dc__entry__21">Not applicable</td></tr><tr><td headers="reference_e5w_sfp_3dc__entry__11">Provision database</td><td headers="reference_e5w_sfp_3dc__entry__12 reference_e5w_sfp_3dc__entry__14 reference_e5w_sfp_3dc__entry__18">Yes</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__15 reference_e5w_sfp_3dc__entry__19">Yes</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__16 reference_e5w_sfp_3dc__entry__20">Yes</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__17 reference_e5w_sfp_3dc__entry__21">Yes</td></tr><tr><td headers="reference_e5w_sfp_3dc__entry__11">Register database</td><td headers="reference_e5w_sfp_3dc__entry__12 reference_e5w_sfp_3dc__entry__14 reference_e5w_sfp_3dc__entry__18">Yes</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__15 reference_e5w_sfp_3dc__entry__19">Not applicable</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__16 reference_e5w_sfp_3dc__entry__20">Not applicable</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__17 reference_e5w_sfp_3dc__entry__21">Not applicable</td></tr><tr><td headers="reference_e5w_sfp_3dc__entry__11">Copy Data Management - Snapshot and log catchup</td><td headers="reference_e5w_sfp_3dc__entry__12 reference_e5w_sfp_3dc__entry__14 reference_e5w_sfp_3dc__entry__18">Yes</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__15 reference_e5w_sfp_3dc__entry__19">Yes</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__16 reference_e5w_sfp_3dc__entry__20">Yes</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__17 reference_e5w_sfp_3dc__entry__21">Yes</td></tr><tr><td headers="reference_e5w_sfp_3dc__entry__11">Copy Data Management - Restore</td><td headers="reference_e5w_sfp_3dc__entry__12 reference_e5w_sfp_3dc__entry__14 reference_e5w_sfp_3dc__entry__18">Yes</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__15 reference_e5w_sfp_3dc__entry__19">Yes</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__16 reference_e5w_sfp_3dc__entry__20">Yes</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__17 reference_e5w_sfp_3dc__entry__21">No</td></tr><tr><td headers="reference_e5w_sfp_3dc__entry__11">Copy Data Management - Clone and Refresh</td><td headers="reference_e5w_sfp_3dc__entry__12 reference_e5w_sfp_3dc__entry__14 reference_e5w_sfp_3dc__entry__18">Yes, can clone to any database instance at the database server VM but NDB can only manage one instance.</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__15 reference_e5w_sfp_3dc__entry__19">Yes</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__16 reference_e5w_sfp_3dc__entry__20">Yes</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__17 reference_e5w_sfp_3dc__entry__21">Yes, clone to standalone instance.</td></tr><tr><td headers="reference_e5w_sfp_3dc__entry__11">Copy Data Management - Clustered Clone [AG] in Single Nutanix cluster</td><td headers="reference_e5w_sfp_3dc__entry__12 reference_e5w_sfp_3dc__entry__14 reference_e5w_sfp_3dc__entry__18">Yes</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__15 reference_e5w_sfp_3dc__entry__19">Yes</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__16 reference_e5w_sfp_3dc__entry__20">Yes</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__17 reference_e5w_sfp_3dc__entry__21">Yes</td></tr><tr><td headers="reference_e5w_sfp_3dc__entry__11">Copy Data Management - Clustered Clone [AG] across Multiple Nutanix cluster</td><td headers="reference_e5w_sfp_3dc__entry__12 reference_e5w_sfp_3dc__entry__14 reference_e5w_sfp_3dc__entry__18">No</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__15 reference_e5w_sfp_3dc__entry__19">No</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__16 reference_e5w_sfp_3dc__entry__20">No</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__17 reference_e5w_sfp_3dc__entry__21">No</td></tr><tr><td headers="reference_e5w_sfp_3dc__entry__11">Patching</td><td headers="reference_e5w_sfp_3dc__entry__12 reference_e5w_sfp_3dc__entry__14 reference_e5w_sfp_3dc__entry__18">Yes</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__15 reference_e5w_sfp_3dc__entry__19">Yes</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__16 reference_e5w_sfp_3dc__entry__20">Yes</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__17 reference_e5w_sfp_3dc__entry__21">No</td></tr><tr><td headers="reference_e5w_sfp_3dc__entry__11">Database group</td><td headers="reference_e5w_sfp_3dc__entry__12 reference_e5w_sfp_3dc__entry__14 reference_e5w_sfp_3dc__entry__18">Yes</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__15 reference_e5w_sfp_3dc__entry__19">Yes</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__16 reference_e5w_sfp_3dc__entry__20">Yes</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__17 reference_e5w_sfp_3dc__entry__21">Yes</td></tr><tr><td headers="reference_e5w_sfp_3dc__entry__11">Storage scaling of user database</td><td headers="reference_e5w_sfp_3dc__entry__12 reference_e5w_sfp_3dc__entry__14 reference_e5w_sfp_3dc__entry__18">No</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__15 reference_e5w_sfp_3dc__entry__19">Yes</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__16 reference_e5w_sfp_3dc__entry__20">Yes</td><td headers="reference_e5w_sfp_3dc__entry__13 reference_e5w_sfp_3dc__entry__17 reference_e5w_sfp_3dc__entry__21">No</td></tr></tbody></table>

Note:
- By default, NDB uses vDisks for provisioning databases.
- Provisioning databases using VGLB, storage spaces, or dynamic disks are available as an advanced option using the configuration file.
- Restore and clone operations are supported for TDE-enabled Availability Group (AG) and standalone databases. For clone operations, ensure that the encryption keys and certificates used to protect the database are available and properly installed on the destination server before initiating the clone.
- NDB does not support multiple SQL Server instances in the same database server VM or windows server failover cluster..

### PostgreSQL Software Compatibility and Feature Support

<table><caption>Table 1. PostgreSQL Community Edition Database and Operating System Versions Supported</caption> <colgroup><col> <col> <col></colgroup><thead><tr><th>Operating System</th><th>Operating System Version</th><th>PostgreSQL Database Version</th></tr></thead><tbody><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__1" rowspan="2">Rocky Linux</td><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__2">9.7</td><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__3"><ul><li>18.0 - 18.2</li><li>17.0 - 17.8</li><li>16.0 - 16.12</li><li>15.0 - 15.16</li><li>14.0 - 14.21</li></ul></td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__2">9.6</td><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__3"><ul><li>17.0 - 17.8</li><li>16.0 - 16.12</li><li>15.0 - 15.16</li><li>14.0 - 14.21</li></ul></td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__1" rowspan="6">Red Hat Enterprise Linux (RHEL)</td><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__2">9.7</td><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__3"><ul><li>18.0 - 18.2</li><li>17.0 - 17.8</li><li>16.0 - 16.12</li><li>15.0 - 15.16</li><li>14.0 - 14.21</li></ul></td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__2">9.6</td><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__3"><ul><li>17.0 - 17.8</li><li>16.0 - 16.12</li><li>15.0 - 15.16</li><li>14.0 - 14.21</li></ul></td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__2">9.4</td><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__3"><ul><li>17.0 - 17.8</li><li>16.0 - 16.12</li><li>15.0 - 15.16</li><li>14.0 - 14.21</li></ul></td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__2">8.10</td><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__3"><ul><li>18.0 - 18.2</li><li>17.0 - 17.8</li><li>16.0 - 16.12</li><li>15.0 - 15.16</li><li>14.0 - 14.21</li></ul></td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__2">8.8</td><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__3"><ul><li>15.0 - 15.16</li></ul></td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__2">7.x</td><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__3"><ul><li>15.0 - 15.16</li><li>14.0 - 14.21</li><li>13.0 - 13.16</li></ul></td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__1" rowspan="3">Ubuntu Linux</td><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__2">24.04</td><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__3">18.0</td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__2">22.04</td><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__3"><ul><li>16.0 - 16.12</li><li>15.0 - 15.16</li></ul></td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__2">20.04</td><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__3"><ul><li>15.0 - 15.16</li><li>14.0 - 14.21</li><li>13.0 - 13.16</li></ul></td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__1" rowspan="2">Debian</td><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__2">12</td><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__3"><ul><li>18.0</li><li>17.5 - 17.8</li><li>16.9 - 16.12</li></ul></td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__2">11</td><td headers="ndb-compatibility-postgresql-2_5_5-r__table_tfk_kw5_v4__entry__3"><ul><li>17.5 - 17.8</li><li>16.9 - 16.12</li><li>15.12 - 15.16</li></ul></td></tr></tbody></table>

For information on PostgreSQL best practices, see [PostgreSQL on Nutanix](https://portal.nutanix.com/page/documents/solutions/details?targetId=BP-2061-PostgreSQL-on-Nutanix:BP-2061-PostgreSQL-on-Nutanix).

Note: Ensure that the line Conflicts in the file `firewalld.service` does not include `nftables.service`.

<table><caption>Table 2. PostgreSQL EDB Enterprise Edition Database and Operating System Versions Supported</caption> <colgroup><col> <col> <col></colgroup><thead><tr><th>Operating System</th><th>Operating System Version</th><th>PostgreSQL Database Version</th></tr></thead><tbody><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__34" rowspan="5">RHEL</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__35">9.7</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__36"><ul><li>18.1 - 18.3</li><li>17.2 - 17.9</li><li>16.1 - 16.13</li><li>15.2 - 15.17</li><li>14.1 - 14.22</li></ul></td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__35">9.6</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__36"><ul><li>17.2 - 17.9</li><li>16.1 - 16.13</li><li>15.2 - 15.17</li><li>14.1 - 14.22</li></ul></td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__35">9.4</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__36"><ul><li>17.2 - 17.9</li><li>16.1 - 16.13</li><li>15.2 - 15.17</li><li>14.1 - 14.22</li></ul></td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__35">8.10</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__36"><ul><li>18.0</li><li>17.2 - 17.9</li><li>16.1 - 16.13</li><li>15.2 - 15.17</li><li>14.1 - 14.22</li></ul></td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__35">8.8</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__36"><ul><li>16.1 - 16.13</li><li>15.2 - 15.17</li></ul></td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__34" rowspan="2">Ubuntu</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__35">24.04</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__36">18.0</td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__35">20.04</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__36"><ul><li>15.2 - 15.17</li><li>14.1 - 14.22</li></ul></td></tr></tbody></table>

Note:
- NDB supports PostgreSQL database with EnterpriseDB Advanced Server (EPAS) tool but not any other EDB tools.
- NDB supports PostgreSQL EDB versions without Transparent Data Encryption (TDE).
- Ensure that the line Conflicts in the file `firewalld.service` does not include `nftables.service`.

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

<table><caption>Table 4. Software Required for PostgreSQL Provisioning</caption> <colgroup><col> <col> <col> <col> <col> <col></colgroup><thead><tr><th>PostgreSQL Community/EDB</th><th>OS</th><th>Patroni</th><th>etcd</th><th>HAProxy*</th><th>Keepalived</th></tr></thead><tbody><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__86" rowspan="7">18.0 - 18.2</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__87">RHEL 9.7</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__88">4.0.5</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__89">3.5.12</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__90">2.8.9</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__91">***2.2.8</td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__87">**Rocky Linux 9.7</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__88">4.0.5</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__89">3.5.12</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__90">2.8.9</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__91">2.2.8</td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__87">RHEL 8.10</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__88">4.0.5</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__89">3.5.12</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__90">2.8.9</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__91">2.1.5</td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__87">**Rocky Linux 8.10</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__88">4.0.5</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__89">3.5.12</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__90">2.8.9</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__91">2.1.5</td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__87">**Ubuntu 22.04</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__88">4.0.5</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__89">3.5.12</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__90">2.8.9</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__91">2.2.4</td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__87">Ubuntu 24.04</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__88">4.0.5</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__89">3.5.12</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__90">2.8.16</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__91">2.2.8</td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__87">**Debian 12</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__88">4.0.5</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__89">3.5.12</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__90">2.8.9</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__91">2.2.7</td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__86" rowspan="4">17.2 - 17.8</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__87">RHEL 9.7/9.6/9.4/ 8.10</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__88">*4.0.5/ 3.3.2</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__89">3.5.12</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__90">2.8.9</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__91">2.2.8</td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__87">**Rocky Linux9.7/9.6</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__88">4.0.5/ 3.2.2</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__89">3.5.12</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__90">2.8.9</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__91">2.2.8</td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__87">RHEL 8.8</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__88">3.2.2</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__89">3.4.20</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__90">1.8.27</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__91">2.1.5</td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__87">**Debian 12</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__88">4.0.5</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__89">3.5.12</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__90">2.8.9</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__91">2.2.7</td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__86" rowspan="5">16.4 - 16.2</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__87">RHEL 9.7/9.6/9.4/ 8.10</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__88">4.0.5/ 3.3.2</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__89">3.5.12</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__90">2.8.9</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__91">2.2.8</td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__87">**Rocky Linux 9.7/9.6</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__88">4.0.5/ 3.2.2</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__89">3.5.12</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__90">2.8.9</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__91">2.2.8</td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__87">RHEL 8.8</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__88">3.2.2</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__89">3.4.20</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__90">1.8.27</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__91">2.1.5</td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__87">**Ubuntu 22.04</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__88">3.2.2</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__89">3.5.12</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__90">2.8.9</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__91">2.2.8</td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__87">**Debian 12</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__88">4.0.5</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__89">3.5.12</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__90">2.8.9</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__91">2.2.7</td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__86" rowspan="5">15.8 - 15.16</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__87">**Rocky Linux 9.7/9.6</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__88">3.2.2</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__89">3.5.12</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__90">2.8.9</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__91">2.2.8</td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__87">RHEL 9.7/ 9.6/ 9.4/ 8.10</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__88">3.2.2</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__89">3.5.12</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__90">2.8.9</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__91">2.2.8</td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__87">RHEL 8.6</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__88">2.1.4</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__89">3.4.20</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__90">1.8.27</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__91">2.1.5</td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__87">**Ubuntu 22.04</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__88">3.2.2</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__89">3.5.12</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__90">2.8.9</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__91">2.2.8</td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__87">Ubuntu 20.04</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__88">2.1.4</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__89">3.2.26</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__90">2.0.29</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__91">2.0.19</td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__86" rowspan="3">14.15 - 14.21</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__87">**Rocky Linux 9.7/ 9.6</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__88">3.2.2</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__89">3.5.12</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__90">2.8.9</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__91">2.2.8</td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__87">RHEL 9.7/ 9.6/ 9.4/ 8.10</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__88">3.2.2</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__89">3.5.12</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__90">2.8.9</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__91">2.2.8</td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__87">Ubuntu 20.04</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__88">2.1.4</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__89">3.2.26</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__90">2.0.29</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__91">2.0.19</td></tr></tbody></table>

Note:
- \*Patroni versions earlier than 4.x do not support or manage the new GUC parameters introduced by PostgreSQL 17.
- \*\* Supported for PostgreSQL Community Edition only.
- \*\*\*For PostgreSQL EDB on RHEL 9.7 with PostgreSQL 18, use Keepalived 2.1.5.
- Ensure that the line Conflicts in the file `firewalld.service` does not include `nftables.service`.

<table><caption>Table 5. Qualified OS versions and PostgreSQL versions for PostgreSQL extensions</caption> <colgroup><col> <col> <col></colgroup><thead><tr><th>Qualified PostgreSQL Extensions</th><th>OS Version</th><th>PostgreSQL/EDB Version</th></tr></thead><tbody><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__217" rowspan="2">pg_vector</td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__218"><ul><li>RHEL 9.4</li></ul></td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__219"><ul><li>16.9</li></ul></td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__218"><ul><li>RHEL 8.10</li></ul></td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__219"><ul><li>EPAS 15.6</li></ul></td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__217" rowspan="3"><ul><li>TimescaleDB</li><li>pgAudit</li><li>pg_cron</li><li>set_user</li><li>PostGIS</li></ul></td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__218"><ul><li>RHEL 9.4</li></ul></td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__219"><ul><li>16.9</li></ul></td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__218"><ul><li>RHEL 8.4</li></ul></td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__219"><ul><li>14</li></ul></td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__218"><ul><li>RHEL 8.6</li></ul></td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__219"><ul><li>14</li></ul></td></tr><tr><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__217"><ul><li>pg_partman</li><li>pg_logical</li><li>pg_stat_statements</li><li>citext</li><li>dblink</li><li>pg_stat_monitor</li><li>pg_trgm</li><li>pgcrypto</li><li>pgstattuple</li><li>plpgsql</li><li>postgres_fdw</li><li>tablefunc</li><li>pg lo</li></ul></td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__218"><ul><li>RHEL 9.4</li></ul></td><td headers="ndb-compatibility-postgresql-2_5_5-r__entry__219"><ul><li>16.9</li></ul></td></tr></tbody></table>

### MongoDB Software Compatibility and Feature Support

<table><caption>Table 1. MongoDB Database and Operating System Versions Supported for Single Instance and Replica Set</caption> <colgroup><col> <col> <col></colgroup><thead><tr><th>Operating System</th><th>Operating System Version</th><th>MongoDB Database Versions</th></tr></thead><tbody><tr><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_tfk_kw5_v4__entry__1" rowspan="2">Rocky Linux</td><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_tfk_kw5_v4__entry__2">9.7</td><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_tfk_kw5_v4__entry__3"><ul><li>8.0.0 - 8.0.19 Community and Enterprise</li><li>7.0 - 7.0.30 Community and Enterprise</li><li>6.0.4 - 6.0.27 Community and Enterprise</li></ul></td></tr><tr><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_tfk_kw5_v4__entry__2">9.6</td><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_tfk_kw5_v4__entry__3"><ul><li>8.0.0 - 8.0.19 Community and Enterprise</li><li>7.0 - 7.0.30 Community and Enterprise</li><li>6.0.4 - 6.0.27 Community and Enterprise</li></ul></td></tr><tr><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_tfk_kw5_v4__entry__1" rowspan="5">Red Hat Enterprise Linux (RHEL)</td><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_tfk_kw5_v4__entry__2">9.7</td><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_tfk_kw5_v4__entry__3"><ul><li>8.0.0 - 8.0.19 Community and Enterprise</li><li>7.0 - 7.0.30 Community and Enterprise</li><li>6.0.4 - 6.0.27 Community and Enterprise</li></ul></td></tr><tr><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_tfk_kw5_v4__entry__2">9.6</td><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_tfk_kw5_v4__entry__3"><ul><li>8.0.0 - 8.0.19 Community and Enterprise</li><li>7.0 - 7.0.30 Community and Enterprise</li><li>6.0.4 - 6.0.27 Community and Enterprise</li></ul></td></tr><tr><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_tfk_kw5_v4__entry__2">9.5</td><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_tfk_kw5_v4__entry__3"><ul><li>8.0.0 - 8.0.19 Community and Enterprise</li><li>7.0 - 7.0.30 Community and Enterprise</li><li>6.0.4 - 6.0.27 Community and Enterprise</li></ul></td></tr><tr><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_tfk_kw5_v4__entry__2">9.4</td><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_tfk_kw5_v4__entry__3"><ul><li>8.0.0 - 8.0.19 Community and Enterprise</li><li>7.0 - 7.0.30 Community and Enterprise</li><li>6.0.4 - 6.0.27 Community and Enterprise</li></ul></td></tr><tr><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_tfk_kw5_v4__entry__2">8.10</td><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_tfk_kw5_v4__entry__3"><ul><li>7.0 - 7.0.30 Community and Enterprise</li><li>6.0.4 - 6.0.27 Community and Enterprise</li></ul></td></tr><tr><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_tfk_kw5_v4__entry__1" rowspan="2">Ubuntu Linux</td><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_tfk_kw5_v4__entry__2">22.04</td><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_tfk_kw5_v4__entry__3"><ul><li>8.0.0 - 8.0.19 Community and Enterprise</li><li>7.0 - 7.0.30 Community and Enterprise</li><li>6.0.4 - 6.0.27 Community and Enterprise</li></ul></td></tr><tr><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_tfk_kw5_v4__entry__2">20.04</td><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_tfk_kw5_v4__entry__3"><ul><li>7.0 - 7.0.30 Community and Enterprise</li><li>6.0.4 - 6.0.27 Community and Enterprise</li></ul></td></tr><tr><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_tfk_kw5_v4__entry__1" rowspan="2">Debian Linux</td><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_tfk_kw5_v4__entry__2">12</td><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_tfk_kw5_v4__entry__3"><ul><li>8.0.0 - 8.0.19 Community and Enterprise</li><li>7.0 - 7.0.30 Community</li></ul></td></tr><tr><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_tfk_kw5_v4__entry__2">11</td><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_tfk_kw5_v4__entry__3"><ul><li>7.0 - 7.0.30 Community and Enterprise</li><li>6.0.0 - 6.0.27 Community and Enterprise</li></ul></td></tr></tbody></table>

Note:
- NDB supports MongoDB Enterprise and Community editions.
- NDB supports WiredTiger (default storage engine for MongoDB) for all supported MongoDB versions.

<table><caption>Table 2. MongoDB Database and Operating System Versions Supported for Sharded Cluster</caption> <colgroup><col> <col> <col> <col></colgroup><thead><tr><th>Operating System</th><th>Operating System Version</th><th>MongoDB Database Versions</th><th>MongoDB Ops Manager Version</th></tr></thead><tbody><tr><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_cfz_pnb_rdc__entry__1" rowspan="2">Rocky Linux</td><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_cfz_pnb_rdc__entry__2">9.7</td><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_cfz_pnb_rdc__entry__3"><ul><li>8.0.0 - 8.0.19 Enterprise</li><li>7.0 - 7.0.30 Enterprise</li></ul></td><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_cfz_pnb_rdc__entry__4" rowspan="2">Not qualified</td></tr><tr><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_cfz_pnb_rdc__entry__2">9.6</td><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_cfz_pnb_rdc__entry__3"><ul><li>8.0.0 - 8.0.19 Enterprise</li><li>7.0 - 7.0.30 Enterprise</li></ul></td></tr><tr><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_cfz_pnb_rdc__entry__1" rowspan="5">Red Hat Enterprise Linux (RHEL)</td><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_cfz_pnb_rdc__entry__2">9.7</td><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_cfz_pnb_rdc__entry__3"><ul><li>8.0.0 - 8.0.19 Enterprise</li><li>7.0 - 7.0.30 Enterprise</li></ul></td><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_cfz_pnb_rdc__entry__4" rowspan="5">Ops Manager Server 8.0.19</td></tr><tr><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_cfz_pnb_rdc__entry__2">9.6</td><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_cfz_pnb_rdc__entry__3"><ul><li>8.0.0 - 8.0.19 Enterprise</li><li>7.0 - 7.0.30 Enterprise</li></ul></td></tr><tr><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_cfz_pnb_rdc__entry__2">9.5</td><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_cfz_pnb_rdc__entry__3"><ul><li>8.0.0 - 8.0.19 Enterprise</li><li>7.0 - 7.0.30 Enterprise</li></ul></td></tr><tr><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_cfz_pnb_rdc__entry__2">9.4</td><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_cfz_pnb_rdc__entry__3"><ul><li>8.0.0 - 8.0.19 Enterprise</li><li>7.0 - 7.0.30 Enterprise</li></ul></td></tr><tr><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_cfz_pnb_rdc__entry__2">8.10</td><td headers="ndb-compatibility-mongodb-v2_5_5-r__table_cfz_pnb_rdc__entry__3"><ul><li>7.0 - 7.0.30 Enterprise</li></ul></td></tr></tbody></table>

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

\* Not using NDB, but you can perform the provisioning through the MongoDB Instance. You must log into a MongoDB instance through the CLI or a management tool.

\* \*Patching through NDB or outside of NDB is not supported if you use a Linux package manager such as YUM to install the database engine.

### MySQL and MariaDB Software Compatibility and Feature Support

<table><caption>Table 1. MySQL Database and Operating System Versions Supported</caption> <colgroup><col> <col> <col></colgroup><thead><tr><th>Operating System</th><th>Operating System Version</th><th>MySQL Database Versions</th></tr></thead><tbody><tr><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__table_tfk_kw5_v4__entry__1">Rocky Linux</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__table_tfk_kw5_v4__entry__2">9.7</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__table_tfk_kw5_v4__entry__3"><ul><li>*8.4.5 Community and Enterprise</li><li>8.0.36 - 8.0.43 Community</li><li>8.0.43 Enterprise (Oracle)</li></ul></td></tr><tr><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__table_tfk_kw5_v4__entry__1" rowspan="4">RHEL</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__table_tfk_kw5_v4__entry__2"><ul><li>9.7</li><li>9.6</li></ul></td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__table_tfk_kw5_v4__entry__3"><ul><li>*8.4.5 Community and Enterprise</li><li>8.0.36 - 8.0.45 Community</li><li>8.0.43 Enterprise (Oracle)</li></ul></td></tr><tr><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__table_tfk_kw5_v4__entry__2"><ul><li>9.5</li><li>9.4</li></ul></td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__table_tfk_kw5_v4__entry__3"><ul><li>8.0.26 Enterprise (Oracle)</li><li>8.0.36 Community</li></ul></td></tr><tr><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__table_tfk_kw5_v4__entry__2">8.10</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__table_tfk_kw5_v4__entry__3"><ul><li>*8.4.5 Community and Enterprise</li><li>8.0.36 - 8.0.43 Community</li><li>8.0.26 Enterprise (Oracle)</li></ul></td></tr><tr><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__table_tfk_kw5_v4__entry__2">8.8</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__table_tfk_kw5_v4__entry__3"><ul><li>8.0.36 Community</li><li>8.0.36 Percona</li></ul></td></tr><tr><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__table_tfk_kw5_v4__entry__1" rowspan="2">Ubuntu Linux</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__table_tfk_kw5_v4__entry__2">22.04</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__table_tfk_kw5_v4__entry__3"><ul><li>8.0.36 - 8.0.45 Community and Enterprise</li></ul></td></tr><tr><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__table_tfk_kw5_v4__entry__2">20.04</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__table_tfk_kw5_v4__entry__3">8.0 Community</td></tr><tr><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__table_tfk_kw5_v4__entry__1" rowspan="2">Debian Linux</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__table_tfk_kw5_v4__entry__2">12</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__table_tfk_kw5_v4__entry__3"><ul><li>8.0.36 - 8.0.45 Community and Enterprise</li></ul></td></tr><tr><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__table_tfk_kw5_v4__entry__2">11</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__table_tfk_kw5_v4__entry__3">8.0.36 - 8.0.45 Community and Enterprise (Oracle)</td></tr></tbody></table>

Note:
- \*Versions supported for MySQL HA.
- On RHEL and Rocky Linux 9.N, disable the `use_devicesfile` setting by setting `use_devicesfile = 0` in the file /etc/lvm/lvm.conf on the DB Server VM used to create the NDB software profile.

<table><caption>Table 2. MariaDB Database and Operating System Versions Supported</caption> <colgroup><col> <col> <col></colgroup><thead><tr><th>Operating System</th><th>Operating System Version</th><th>MariaDB Database Versions</th></tr></thead><tbody><tr><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__26">Rocky Linux</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__27">9.7</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__28">10.11 Community</td></tr><tr><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__26" rowspan="2">RHEL</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__27"><ul><li>9.6</li><li>9.5</li><li>9.4</li></ul></td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__28"><ul><li>11.8.4 Community</li><li>10.11 Community</li><li>10.6 Enterprise</li></ul></td></tr><tr><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__27">8.10</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__28"><ul><li>10.11 Community</li><li>10.6 Enterprise</li></ul></td></tr><tr><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__26" rowspan="3">Ubuntu</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__27">24.10</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__28">11.8 Community</td></tr><tr><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__27">24.04</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__28">11.8.4 Community</td></tr><tr><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__27">22.04</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__28"><ul><li>10.11 Community</li><li>10.6 Enterprise</li></ul></td></tr><tr><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__26" rowspan="2">Debian</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__27">12</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__28">10.11 Community and Enterprise</td></tr><tr><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__27">11</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__28">10.11 Community</td></tr></tbody></table>

For information on MySQL best practices, see [MySQL on Nutanix](https://portal.nutanix.com/page/documents/solutions/details?targetId=BP-2056-MySQL-on-Nutanix:BP-2056-MySQL-on-Nutanix).

<table><caption>Table 3. NDB Features Matrix for MySQL and MariaDB</caption> <colgroup><col> <col> <col> <col></colgroup><thead><tr><th rowspan="2">NDB Feature</th><th rowspan="2">Single Instance</th><th colspan="2">High Availability</th></tr><tr><th>MySQL</th><th>MariaDB</th></tr></thead><tbody><tr><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__49">Database Provision</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__50">Yes</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__51 ndb-compatibility-mysql-mariadb-v2_6-r__entry__52">Yes</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__51 ndb-compatibility-mysql-mariadb-v2_6-r__entry__53">No</td></tr><tr><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__49">Provision of database Replicas across Nutanix clusters</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__50">Not applicable</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__51 ndb-compatibility-mysql-mariadb-v2_6-r__entry__52">Yes</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__51 ndb-compatibility-mysql-mariadb-v2_6-r__entry__53">No</td></tr><tr><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__49">Provision of multiple database instance on the same VM</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__50">No</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__51 ndb-compatibility-mysql-mariadb-v2_6-r__entry__52">Not applicable</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__51 ndb-compatibility-mysql-mariadb-v2_6-r__entry__53">Not applicable</td></tr><tr><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__49">Provision of multiple databases in the same database server VM</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__50">Yes</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__51 ndb-compatibility-mysql-mariadb-v2_6-r__entry__52">No</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__51 ndb-compatibility-mysql-mariadb-v2_6-r__entry__53">Not applicable</td></tr><tr><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__49">Provision of database server VM on any Nutanix cluster</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__50">Yes</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__51 ndb-compatibility-mysql-mariadb-v2_6-r__entry__52">Yes</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__51 ndb-compatibility-mysql-mariadb-v2_6-r__entry__53">Not applicable</td></tr><tr><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__49">Copy data management (Clone/Refresh)</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__50">Yes (can only create a single instance clone from a single database instance)</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__51 ndb-compatibility-mysql-mariadb-v2_6-r__entry__52">No</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__51 ndb-compatibility-mysql-mariadb-v2_6-r__entry__53">Not applicable</td></tr><tr><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__49">Database management as a group</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__50">No</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__51 ndb-compatibility-mysql-mariadb-v2_6-r__entry__52">Not applicable</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__51 ndb-compatibility-mysql-mariadb-v2_6-r__entry__53">Not applicable</td></tr><tr><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__49">Restore</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__50">No</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__51 ndb-compatibility-mysql-mariadb-v2_6-r__entry__52">No</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__51 ndb-compatibility-mysql-mariadb-v2_6-r__entry__53">No</td></tr><tr><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__49">Patching</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__50">No</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__51 ndb-compatibility-mysql-mariadb-v2_6-r__entry__52">No</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__51 ndb-compatibility-mysql-mariadb-v2_6-r__entry__53">No</td></tr><tr><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__49">Database scaling</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__50">No</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__51 ndb-compatibility-mysql-mariadb-v2_6-r__entry__52">No</td><td headers="ndb-compatibility-mysql-mariadb-v2_6-r__entry__51 ndb-compatibility-mysql-mariadb-v2_6-r__entry__53">No</td></tr></tbody></table>

### Browser Compatibility

For the best user experience, access the NDB user interface using one of the following supported browsers.

| Browser | Version |
| --- | --- |
| Mozilla Firefox | 132.0.1 or later |
| Google Chrome | 135.0 or later |
| Apple Safari | 18.1 or later |