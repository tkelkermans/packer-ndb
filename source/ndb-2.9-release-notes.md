# Nutanix Database Service 2.9 - Nutanix Database Service Release Note

### Nutanix Database Service 2.9

Product Release Date: 2025-10-01

Last updated: 2025-11-14

## [Overview](https://portal.nutanix.com/page/documents/details?targetId=Release-Notes-Nutanix-NDB-v2_9:v29-ndb-release-notes-about-this-release-r.html)

Nutanix Database Service (NDB) automates and simplifies database administration, bringing one-click simplicity and seamless automations to database provisioning and life-cycle management. NDB enables database administrators to perform operations such as database registration, provisioning, cloning, patching, restore and more. It allows administrators to define provisioning standards with end-state-driven functionality that includes network segmentation, High Availability (HA) database deployments, and more. With NDB multi-clusters, you can easily manage databases across multiple locations, both on-prem and in the cloud, with Nutanix Cloud Clusters (NC2).

Note: To upgrade to NDB 2.9, you must be running a 2.7.x version or later. NDB versions 2.6.x or earlier require an intermediate upgrade to 2.7.x before upgrading to 2.9. Attempting a direct upgrade from 2.6.x to 2.9 fails.

For information on the new features and enhancements in this release, see [What's New in NDB 2.9](https://portal.nutanix.com/page/documents/details?targetId=Release-Notes-Nutanix-NDB-v2_9:v29-ndb-main-features-r.html).

This release includes several resolved issues. For more information, see [Resolved Issues](https://portal.nutanix.com/page/documents/details?targetId=Release-Notes-Nutanix-NDB-v2_9:v29-resolved-issues-release-notes-ndb-r.html).

For information about the known issues in this release, see [Known Issues](https://portal.nutanix.com/page/documents/details?targetId=Release-Notes-Nutanix-NDB-v2_9:v29-ndb-release-notes-known-issues-r.html).

For detailed information about the product, see [Nutanix Database Service Administration Guide](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide).

## [NDB 2.9 Installation or Upgrade](https://portal.nutanix.com/page/documents/details?targetId=Release-Notes-Nutanix-NDB-v2_9:v29-install-or-upgrade-version-ndb-c.html)

NDB 2.9 installation or upgrade related information.

Note: Upgrading to NDB 2.9 requires NDB to be currently running 2.7.x version or later.

To download the NDB upgrade bundle, see [Nutanix Database Service page](https://portal.nutanix.com/page/downloads?product=ndb).

After you upgrade NDB to a new version, wait for at least 15 seconds and refresh the page to load the latest user interface.

For more information, see:

-   [NDB Installation](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide:top-installation-c.html) in Nutanix Database Service Administration Guide.
-   [NDB Upgrade Management](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide:top-version-upgrade-c.html) in Nutanix Database Service Administration Guide.

## [What's New in NDB 2.9](https://portal.nutanix.com/page/documents/details?targetId=Release-Notes-Nutanix-NDB-v2_9:v29-ndb-main-features-r.html)

New features and enhancements in NDB 2.9.

This release includes the following new features and enhancements:

Disaster Recovery for Oracle Database

NDB now supports setting up and managing disaster recovery for Oracle database instances using native Oracle Data Guard DR features from the NDB console, API, and CLI.

For more information, see [Oracle Database Disaster Recovery](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-Oracle-Database-Management-Guide:top-oracle-db-dr-c.html) in the Nutanix Database Service Oracle Database Management Guide.

Multi Database Group Support for SQL Server

NDB now supports creating up to five database groups per VM. Each database group can include up to 35 databases, allowing a total of 175 databases per server. A database group can contain databases from multiple Always On Availability Groups (AGs) and uses a shared Time Machine for coordinated snapshots and log backups.

For more information, see [SQL Server Multi Database Group Support](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-SQL-Server-Database-Management-Guide:top-sql-server-multi-db-c.html) in the Nutanix Database Service SQL Server Database Management Guide.

Windows Remote Management over HTTPS Support for SQL Server

NDB now supports Windows Remote Management (WinRM) over HTTPS, enabling secure communication between NDB control plane VMs and SQL Server database server VMs. WinRM over HTTPS introduces transport layer encryption using the SSL/TLS protocol, enhancing protection against interception and meeting enterprise security requirements.

For more information, see [Windows Remote Management over HTTPS Support](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-SQL-Server-Database-Management-Guide:top-sql-server-winrm-support-c.html) in the Nutanix Database Service SQL Server Database Management Guide.

Security-Enhanced Linux Configuration

NDB now supports configuring SELinux enforcing mode for database server VMs running single instance (SI) or high availability (HA) databases. For MongoDB, Oracle, and PostgreSQL database servers, you can enable enforcing mode in line with the NDB recommended SELinux policy. Custom SELinux policies are not supported by NDB. This enhancement improves security while ensuring compatibility with supported database engines.

For more information, see [Security-Enhanced Linux Configuration](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide:top-selinux-config-c.html) in the Nutanix Database Service Administration Guide.

High Availability (HA) Support for MySQL

NDB now supports provisioning of MySQL High Availability (HA) instances across different Nutanix clusters through NDB’s API and CLI. This capability enables fault-tolerant MySQL deployments in addition to single-instance databases.

For more information, see [MySQL High Availability Support](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-MySQL-Database-Management-Guide:top-mysql-db-ha-overview-c.html) in the Nutanix Database Service MySQL Database Management Guide.

Backup And Recovery Management for NDB Control Plane

NDB now supports creating and restoring control plane backups to recover from critical failures. This capability restores the control plane to an earlier backed-up state and minimizes the impact of failures such as metadata corruption, human error, ransomware, or cyberattacks.

For more information, see [NDB Control Plane Backup and Recovery Management](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide:top-ndb-cp-intro-c.html) in the Nutanix Database Service Administration Guide.

Enhanced Storage Consumption Reporting

NDB now provides built-in Storage Consumption Reporting in the NDB console. You can view detailed insights into storage usage by databases, clones, and Time Machines—including snapshots and log backups—as well as overall Nutanix cluster (NCI or NC2) storage and available capacity.

For more information, see [NDB Dashboard](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide:top-dashboard-r.html) and [Time Machine Behavior and Functionality](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide:top-time-machine-functionality-c.html) in the Nutanix Database Service Administration Guide.

Cloud-init Support for Linux-based Database Engines

NDB introduces support for Cloud-Init to configure Linux DBServer VMs at runtime. Cloud-Init improves performance and reliability, and ensures cross-platform compatibility.

For more information, see the [Database Server VM Registration](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-Oracle-Database-Management-Guide:top-oracle-db-server-vm-registration-c.html) topics in the Oracle, PostgreSQL, MySQL, MongoDB, and MariaDB Database Management Guides.

Nutanix Product Accessibility (a11y) Program

This release includes major remediations aligned to the [Web Content Accessibility Guidelines (WCAG) 2.2 Level AA accessibility standards](https://www.w3.org/TR/WCAG22/), allowing a more seamless experience for customers who might require the use of assistive technology and better user interface (UI) navigability in support of users with disabilities. These critical improvements update the user experience with keyboard navigability and assistive technology, including applying accessible labels to interactive elements, creating a semantic structure of content with headings, and implementing code-level navigational aids (for example, landmarks).

Bulk Patching Improvements

NDB now supports up to 80 database server VMs per Maintenance Window. For more information, see the [Maintenance Window](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide:top-maintenance-window-c.html) in the Nutanix Database Service Administration Guide.

## [Resolved Issues](https://portal.nutanix.com/page/documents/details?targetId=Release-Notes-Nutanix-NDB-v2_9:v29-resolved-issues-release-notes-ndb-r.html)

This release resolves the following issues:

Upgrade

-   ERA-48762ERA-49749 The SQL Database Server VM upgrade failed during the replacement of the shippable Python stack.
-   ERA-44191 When you attempt unsupported upgrade paths, the UI shows only generic failure messages, which do not clearly communicate the reason for the failure.
-   ERA-40265 NDB agent upgrade failed with the error, Error when performing 'Era Cluster Agent' components upgrade.

General

-   ERA-55673 Upgrading from NDB version 2.7 to 2.9 might trigger alerts such as Time Machine Unhealthy on Cluster xxx. Backup schedule missed - see KB-18431 for more information in environments with high backup frequencies.
-   ERA-52535 NDB Control Plane was running on unsupported PostgreSQL version 10.23, which exposed the control plane to potential vulnerabilities.
-   ERA-54825 Vertical scaling of database servers failed when the DB Server VM was registered with SSH-key authentication.
-   ERA-49854 If the era\_cli\_cfg.json file was empty on the NDB Server VM, NDB Agent VM, or DB Server VM, it impacted the execution of the NDB processes on the corresponding VM.
-   ERA-48022 Deleting a group entity sharing policy after it was assigned to a user group entity as a recipient failed.
-   ERA-48021 The database provisioning screen failed to load when stale group entity sharing policies existed.
-   ERA-27507 NDB does not support database servers with the timezone set as EU/Volgograd (UTC+3).
-   ERA-21022 For RHEL 8.x and 9.x versions, NDB requires the NetworkManager-initscripts-updown package to be installed on the database server VM. You can install this package by using the following command:
    ```
    
    ```
    dnf install NetworkManager-initscripts-updown
    ```
    
    ```

Oracle

-   ERA-47666 When creating multiple standby databases in a RAC setup, standby creation failed with the following error:
    ```
    
    ```
    Error in Creating Standby Database.  
    RMAN-05501: aborting duplication of target database.  
    RMAN-03015: error occurred in stored script Memory Script.
    ```
    
    ```

SQL Server

-   ERA-51675 LDAP precheck failures occurred when creating test computer objects in the specified OU using non-domain Administrator accounts with appropriate privileges. The workflow did not append a trailing “$” to the sAMAccountName, which caused WSFC and AAG provisioning to fail when creating test computer objects for non-domain Administrator users.
-   ERA-49644 Database server patching failed because the attached patch disk was not brought online.
-   ERA-44496 Subsequent in-place restores for SQL Server databases hosted on shared storage spaces with other databases might fail following the first restore.
-   ERA-36427 During Failover Cluster Instance (FCI) re-installation, the AdvancedAnalytics feature was not skipped for SQL Server versions earlier than 2019. This caused failures if the feature was present in the source database server profile.

PostgreSQL

-   ERA-22669 Rollback fails when disk-based PostgreSQL provisioning into an existing database server VM fails.
-   ERA-46660 In NDB HA deployments with VG-based archive log storage, one of the NDB PG repository nodes ran out of storage space. The system triggered an alert when the archive storage was low.

MongoDB

-   ERA-37926 Restore in-place from either snapshot or PITR on registered MongoDB replica set (brownfield use case) failed.

UI

-   ERA-38544 While configuring advanced network profile options for Oracle, NDB lets you select VLANs from the VLAN menu even when the corresponding VLAN access type checkboxes are not selected.

## [Known Issues](https://portal.nutanix.com/page/documents/details?targetId=Release-Notes-Nutanix-NDB-v2_9:v29-ndb-release-notes-known-issues-r.html)

NDB Upgrade

NDB upgrade functionality has the following known issues:-   ERA-26275 Database server agent upgrade fails with the error, Expecting value: line 1 column 1 (char 0).
    
    **Workaround**: Resubmit the failed operation. For more information, see [KB 14802](http://portal.nutanix.com/kb/14802).
    
-   ERA-47727 During an upgrade, after the NDB server upgrade is complete but before the DB Server upgrades finish, time machines may enter a critical state. This occurs if the backup schedule is not met during the upgrade. The issue is expected in high-scale environments with high-frequency backups (15-minute intervals). Time machines automatically exit the critical state once the upgrade is complete.

General

-   ERA-38670 NDB operations might fail due to stale volume groups with the following error message.
    
    ERA\_LOG\_DRIVE could not be deleted from cluster. Details:device is busy,not able to unmount
    
    **Workaround**: Contact Nutanix support.
    
-   ERA-34505 Nutanix recommends enabling periodic 
    ```
    fstrim
    ```
     operations on all thin provisioned Linux VMs. NDB does not enable this on the managed VMs, which might lead to inefficient storage utilization and storage alerts in Prism.
    
    **Workaround**:
    
      -   Ensure periodic fstrim is enabled on any custom software profile.
      -   If your cluster shows a space usage alert from Prism, run the 
          ```
          /sbin/fstrim --all
          ```
           command on your database server VMs.
      -   If the issue persists, contact Nutanix Support for help with identifying bloated volume groups and trimming them.
    
-   ERA-39460 In a single-cluster NDB HA deployment with Objects-based log catchup, log copy fails intermittently with the following error:
    
    Error while copying logs: SSL validation failed for <endpoint\_url>
    
    **Workaround**: No action is required.
    
-   ERA-40883 By default, the 
    ```
    use_devicesfile
    ```
     configuration is enabled in RHEL 9.x which can cause NDB provisioned VMs to fail to boot after a restart with the following error:
    
    Failed to create DBServer VM. Reason: Failed to get the IP.
    
    **Workaround**: To prevent this, disable the 
    ```
    use_devicesfile
    ```
     setting in the 
    ```
    /etc/lvm/lvm.conf
    ```
     file on the gold image VM:
    
    ```
    
    ```
    use_devicesfile = 0
    ```
    
    ```
    For more information, see [Red Hat KB](https://access.redhat.com/solutions/6889951).
-   ERA-44252 If a time machine is scheduled for backup only once a week or at longer intervals, the time machine health does not accurately reflect past failures.
-   ERA-44420 You cannot perform OS patching on database server VMs provisioned from the v1 version of OOB software profiles.
-   ERA-46413 Adding a DAM policy to a paused time machine leads to inconsistent behaviour.
    
    **Workaround**: Resume the time machine before adding new DAM policies.
    
-   ERA-46941 The **Time Machine Status** dashboard tile counts deleted databases if the time machine was retained during deletion.
-   ERA-47170 If you increase the number of daily snapshots, Phantom Schedule Misses might occur. If a schedule miss is reported on your timeline within 24 hours of the change, verify whether a snapshot was expected.
-   ERA-47351 NDB fails to generate a new machine ID during VM provisioning or cloning if the template VM does not include the dbus-uuidgen utility, which can prevent the DBus service from starting or lead to an unreachable network IP.
    
    **Workaround**: Install the dbus-tools package on the template VM to ensure proper machine ID generation during VM operations.
    
-   ERA-47439 Creating an entity sharing policy fails when sharing clones with AD groups with MANAGE access.
    
    **Workaround**: Share the clone individually with users within the group. Creating an entity sharing policy fails when sharing clones with AD groups with MANAGE access.
    
-   ERA-47459 Specifying a public SSH key during database provisioning is optional. But NDB does not allow you to specify an empty key through the API or CLI.
-   ERA-48808 If software profile replication in NDB fails (for example, due to a network, cluster, or internal error), NDB retains the association between the software profile and the target cluster in the backend. As a result, retrying the replication through the UI or API does not re-initiate the process. NDB considers the replication complete and prevents further replication attempts for the same cluster and software profile.
    
    **Workaround**: Remove the failed cluster-profile association and initiate a new software profile replication using one of the following methods:
    
      -   **NDB server API:**
          ```
          
          ```
          DELETE https://<ERA_IP>/era/v0.9/profiles/<SW_PROFILE_ID>?cluster_id=<CLUSTER_ID>
          ```
          
          ```
          
      -   **NDB CLI:**
          ```
          
          ```
          era > profile software update engine=<ENGINE> id=<SW_PROFILE_ID> remove_nx_cluster_availability=<CLUSTER_ID>
          ```
          
          ```
    
-   ERA-54945 VM provisioning on ESXi might fail during the hostnamectl command execution if the template VM has Nutanix Guest Tools (NGT) installed.
    
    **Workaround**: Uninstall NGT from the template VM and retry provisioning using a new software profile.
    
-   ERA-55373 On-demand snapshot creation fails with the error, failed to load details era drive info when a user who is not the Time Machine owner executes the operation, even if the user has Manage or Full Access through Entity Sharing.
    
    **Workaround**: Run the operation using the Time Machine owner’s credentials. Alternatively, share View access to the Time Machine’s DB Server VMs with the user in addition to sharing the Time Machine.
    
-   ERA-56484 Diagnostic bundle download fails for VMs with a positive UTC offset.
    
    **Workaround**: On the VM with the positive UTC offset, change the time zone (TZ) to the equivalent one that includes a valid time zone abbreviation:
    
    ```
    
    ```
    sudo timedatectl set-timezone tz_identifier
    ```
    
    ```
    
    where tz\_identifier is the standard TZ identifier (for example, Africa/Nairobi).

Oracle

-   ERA-25205 Clone operation fails if the Oracle inventory resides outside the software disks mount point. This issue can occur if you perform an upgrade on a brownfield database server VM.
-   ERA-13749 To verify the disks before Oracle database provisioning using the Oracle ASMLIB driver, enter the GRID\_HOME/bin directory and run the KFOD utility using the disk string provided in the configuration.
    ```
    
    ```
    # cd /u01/app/11.2.0/grid/bin
    #./kfod nohdr=true verbose=true disks=all op=disks dscvgroup=TRUE asm_diskstring='ORCL:*'
    ```
    
    ```
    
    If the command does not return any disks, the ASM driver provisioning fails with the following error:
    
    ```
    
    ```
    error in configuring Clusterware
    ```
    
    ```
    
-   ERA-25447 PDB provisioning fails when tablespaces are encrypted on the CDB.
-   ERA-28702 Deleting an Oracle database does not clear the TNS entry in the database server VM. This results in provisioning failures when using the same global database name on the same database server VM. This issue applies only to single instance databases.
    
    **Workaround**: Use a different database name for provisioning.
    
-   ERA-28680 Clone creation from a snapshot fails if MRP was running on an Oracle RAC node other than the node from which the snapshot was taken. The following error message appears:
    ```
    
    ```
    Script error: Failed to recover database instance
    ```
    
    ```
    
-   ERA-24813 Provisioning 19c databases on RHEL/OEL 8.x requires Grid and RDBMS release update levels 19.7 or later.
-   ERA-21775 Database provisioning fails if you use the sqlnet.ora file with OS \_AUTHENTICATION set to NTS in the gold image.
-   ERA-28022 The extend database storage operation fails for Oracle 18c single instance databases.
-   ERA-28933 Clone refresh operation fails when the clone database server VM is upgraded from Oracle 19c to 21c.
-   Oracle database provisioning for SUSE does not work with XFS filesystem.
-   ERA-32499 You must not create datafiles in the NDB software mount or database software as it can lead to downtime or corruption during database deletion and OOP database patching respectively.
-   ERA-35169 Oracle upgrade fails if there is more than one space between alias name and the \= character in the tnsnames.ora file. The IFILE parameter is not supported.
    
    **Workaround**: Keep all TNS entries in the tnsnames.ora file before triggering an upgrade.
    
-   ERA-42058 Clone refresh operation fails with the following error for Oracle 19.23 version:
    
    Failed to restore database snapshot. Details: Failed to Restore Log drive. Reason: cannot find the required device.
    
-   ERA-42258 RAC to RAC clone refresh operation fails with the following error for Oracle 19.23 with ASMFD:
    
    Failed to restore database snapshot due to an unexpected error.
    
-   ERA-43598 In a disaster recovery (DR) setup, after you restore the primary database, the standby and cascaded databases stop working.
    
    **Workaround**: Delete the existing DR configuration and recreate the configuration to set up the standby and cascaded databases.
    
-   ERA-55712 Oracle Udev provisioning may fail during Clusterware configuration when creating disk groups due to disk permission issues for the grid user. This typically occurs if the template VM or gold image contains a udev rules file named /etc/udev/rules.d/1-era-disks.rules.
    
    **Workaround**: Rename the /etc/udev/rules.d/1-era-disks.rules file in the template VM, recreate the software profile, and retry the provisioning.

SQL Server

-   ERA-18480 When the source SQL instance from which the software profile is created has SQL Server Analysis Services feature installed, FCI installation fails with the following error:
    
    '-2054422508', "Instance name '<instance\_name>' is already in use. To continue, specify a unique instance name."
    
    This applies only if the FCI instance has the same name as the original one.
    
    **Workaround**: Create a software profile from an instance where SQL Analysis Services feature is not installed.
    
-   ERA-22921 SQL Server provisioning operation times out when many disks are attached to the database server VM.
    
    **Workaround**: Increase the provisioning operation timeout.
    
-   ERA-23171 If you block the Windows Task Scheduler from executing any scheduled tasks through your GPO policy, the commands for new cluster creation and GMSA update fail, and the associated operations fail eventually. This is because NDB uses Task Scheduler to run these remote commands.
    
    **Workaround**: Set 
    ```
    use_era_worker_to_execute_task
    ```
     as true and the remote commands will be executed with the NDB worker service user's context. Also, ensure the NDB worker service user has the **Create and Delete Computer Objects** permission on the organizational unit (OU). For more information, see [KB 12761](https://portal.nutanix.com/kb/12761).
    
-   ERA-24462 SQL Server database server VM provisioning fails intermittently with the following failure message:
    
    Failed to Provision Database Server VM. Reason: ‘Failed to clone db server. Reason: VM did not power off . Possible Reasons: sysprep fail in windows / vmware tools installation failed in Unix . Pls check provisioned vm logs.’
    
    **Workaround**: See [KB 14575](http://portal.nutanix.com/kb/14575), [KB 14734](https://portal.nutanix.com/kb/14734), and [KB 14702](https://portal.nutanix.com/kb/14702)
    
-   ERA-25520 Non-super admin users cannot provision SQL Server AG database into the existing AGs owned by another RBAC user.
-   ERA-29683 NDB does not list software profiles with patches for FCI provisioning, even when the software profiles have ISO.
-   ERA-49763 When VirtIO 1.2.4 is installed on a Windows VM, database operations such as refresh clone, patch DB server, and cleanup might fail, which causes the VM to stop responding.
    
    **Solution**: Upgrade to VirtIO 1.2.5.
    
    **Workaround**: Downgrade to VirtIO 1.2.3 or 1.1.7. For more information, see [KB 18999](https://portal.nutanix.com/kb/18999).
    
-   ERA-51469 During Microsoft SQL Server upgrades in a two-node availability group, a log catch-up operation might fail if it starts while one node has completed the upgrade and the other is still upgrading.
    
    **Workaround**: Resubmit the operation.

PostgreSQL

-   ERA-23241 When NDB HA configuration fails due to NTP issues, NDB provides a warning instead of an error.
    
    **Workaround**: Fix the NTP configuration issues before proceeding with the operation.
    
-   ERA-47236 If after-local is already configured to boot at rc-local, NDB might add the same configuration again.
    
    **Workaround**: Remove after-local.service from both the VM template and any Time Machine clones before provisioning.
    
-   ERA-44346 Registration of PostgreSQL RHEL 9.4 database server VM with the private key provided as text fails with the following error:
    
    Login credentials for VM are incorrect
    
    **Workaround:**
    
      -   Use the Upload File option to upload the private key file, or
      -   Add a new line at the end of private key content.
    
-   ERA-47254 PostgreSQL provisioning from old OOB profiles fails with the error:
    ```
    
    ```
    Failed to provision DB
    ```
    
    ```
    
    **Workaround**: Use the latest version of OOB software profile for provisioning.

MongoDB

-   ERA-43656 NDB does not use the custom OS user while provisioning a database server VM from a time machine. The default user 
    ```
    mongod
    ```
     is used instead.
-   ERA-42848 If you abort the sharded cluster provisioning operation, the clean-up of VMs does not happen automatically in some cases.
    
    **Workaround**: Clean up the database server VMs or NDB metadata manually. For more information, see [KB 17506](https://portal.nutanix.com/kb/17506).

UI

-   ERA-53039 In an NDB cluster running on Object Storage, the Time Machine Overview page in the NDB console displays only cluster storage usage information and does not include Object storage usage.
    
    **Workaround**: View the Time Machine Properties page to see the correct storage information.

## [NDB Software Compatibility and Feature Support](https://portal.nutanix.com/page/documents/details?targetId=Release-Notes-Nutanix-NDB-v2_9:v29-ndb-software-compatibility-r.html)

Detailed compatibility information for NDB, including supported Nutanix and VMware products, database engines, and operating systems.

This section also includes the following feature support matrices:

-   [NDB Software Compatibility with Nutanix and VMware Products](https://portal.nutanix.com/page/documents/details?targetId=Release-Notes-Nutanix-NDB-v2_9:v29-ndb-compatibility-general-ndb-r.html)
-   [Oracle Software Compatibility and Feature Support](https://portal.nutanix.com/page/documents/details?targetId=Release-Notes-Nutanix-NDB-v2_9:v29-ndb-compatibility-oracle-r.html)
-   [SQL Server Software Compatibility and Feature Support](https://portal.nutanix.com/page/documents/details?targetId=Release-Notes-Nutanix-NDB-v2_9:v29-ndb-compatibility-sql-server-r.html)
-   [PostgreSQL Software Compatibility and Feature Support](https://portal.nutanix.com/page/documents/details?targetId=Release-Notes-Nutanix-NDB-v2_9:v29-ndb-compatibility-postgresql-r.html)
-   [MongoDB Software Compatibility and Feature Support](https://portal.nutanix.com/page/documents/details?targetId=Release-Notes-Nutanix-NDB-v2_9:v29-ndb-compatibility-mongodb-r.html)
-   [MySQL and MariaDB Software Compatibility and Feature Support](https://portal.nutanix.com/page/documents/details?targetId=Release-Notes-Nutanix-NDB-v2_9:v29-ndb-compatibility-mysql-mariadb-r.html)
-   [Browser Compatibility](https://portal.nutanix.com/page/documents/details?targetId=Release-Notes-Nutanix-NDB-v2_9:v29-ndb-browser-compatibility-r.html)

Additionally, it outlines unsupported versions, Oracle ASM support, and browser requirements to help you plan and manage deployments effectively.

### [NDB Software Compatibility with Nutanix and VMware Products](https://portal.nutanix.com/page/documents/details?targetId=Release-Notes-Nutanix-NDB-v2_9:v29-ndb-compatibility-general-ndb-r.html)

Table 1. Supported AOS, AHV, and vSphere Software Versions for NDB and NDB Multi Cluster
 Software | Version |
| --- | --- |
 AOS | 7.3, 7.0, 6.10, and 6.5 |
 AHV | AHV versions supported by AOS 7.3, 7.0, 6.10, and 6.5 |
 vSphere | 8.0 and 7.0 |

Table 2. Supported Prism Central, Objects, and Flow Network Security Versions
 Software | Version |
| --- | --- |
 Prism Central | 2024.2, 2024.3 and 7.3 |
 Objects | 5.0, 5.0.1 and 5.1 |
 Flow Network Security | 5.0.0 |

Table 3. Unsupported Operating System and Database Versions
 Software | Version |
| --- | --- |
 AOS | 6.8 |
 SUSE Linux Enterprise Server | 15 SP5, 15 SP2 and 12 SP5 |
 RHEL | 7.3 - 7.8 |
 Objects | 4.4 and 4.3 |

### [Oracle Software Compatibility and Feature Support](https://portal.nutanix.com/page/documents/details?targetId=Release-Notes-Nutanix-NDB-v2_9:v29-ndb-compatibility-oracle-r.html)

Table 1. Oracle Enterprise Edition Database and Operating System Versions Supported
 Operating System | Operating System Version | Oracle Database versions |
| --- | --- | --- |
 Oracle Enterprise Linux (OEL) | 9.6 | 19.26 - 19.28 |
 9.4 | 19.25 - 19.28 |
 8.10 | 19.23 - 19.28 |
 8.8 | -   21.18 - 21.19
-   19.21 - 19.24
 |
 7.8 - 7.9 | -   21.3 - 21.15
-   19.7 - 19.24
-   18.14
-   12.2
-   12.1
-   11.2
 |
 Red Hat Enterprise Linux (RHEL) | 9.6 | 19.26 - 19.28 |
 9.4 | 19.25 - 19.28 |
 8.10 | 19.23 - 19.28 |
 8.8 | -   21.18 - 21.19
-   19.21 - 19.24
 |
 7.8 - 7.9 | -   21.3 - 21.15
-   19.7 - 19.24
-   18.14
-   12.2
-   12.1
-   11.2
 |

For information on Oracle best practices, see [Oracle on Nutanix](https://portal.nutanix.com/page/documents/solutions/details?targetId=BP-2000-Oracle-on-Nutanix:BP-2000-Oracle-on-Nutanix).

Note:

-   **Supported OS and Kernel Combinations**  -   **Oracle 19c (Versions 19.23–19.28)**    -   OEL 9.6: kernel 6.12.0-1.23.3.2.el9uek.x86\_64
              -   RHEL 9.6: kernel 5.14.0-570.12.1.el9\_6.x86\_64
              -   OEL 9.4: kernel 5.15.0-205.149.5.1.el9uek.x86\_64
              -   RHEL 9.4: kernel 5.14.0-427.13.1.el9\_4.x86\_64
              -   OEL 9.4: kernel 5.14.0-427.13.1.el9\_4.x86\_64
              -   OEL 8.10: kernel 4.18.0-553.el8\_10.x86\_64
    
-   **Oracle Automatic Storage Management (ASM) Support**  -   **Oracle 19c (Versions 19.23–19.28)**    -   All RHEL 9.x and OEL 9.x systems support UDEV only. ASMFD and ASMLIB are not supported.
              -   OEL 9.4 RHCK supports UDEV.
              -   Starting with Oracle 19.27, RHEL 8.10 and OEL 8.10 support ASMFD.
              -   RHEL 8.10 and OEL 8.10 RHCK supports ASMLIB.
              -   OEL 8.10 UEK7 kernel does not support ASMLIB.
              -   NDB supports ASMLIB v2, but not ASMLIB v3.
          
      -   **Oracle 21c (Patch 21.18 and later)**    -   RHEL 9.x and OEL 9.x are not supported.
              -   RHEL 8.10 supports UDEV. It does not support ASMFD and ASMLIB.
              -   OEL 8.10 supports UDEV only. It does not support ASMFD or ASMLIB on UEK7 kernel.
              -   Upgrade to Oracle 21c only if the source database does not use TDE encryption.
    
-   Use an SID with eight or fewer characters when you create databases in Oracle 11.2.0.1 and 12.1.0.2 to ensure Oracle RAC provisioning succeeds.
-   Oracle database provisioning for SUSE does not work with XFS filesystem.

Table 2. NDB Features Matrix for Oracle
 NDB Feature | Oracle Database |
| --- | --- |
 SIDB | SIHA | RAC |
| --- | --- | --- |
 Database Provision | Yes | Yes | Yes |
 Provision of multiple databases in the same database server VM | Yes | Yes | Yes |
 Provision of database server VM on any Nutanix cluster | Yes | Yes | Yes |
 Copy data management (Clone/Refresh) | Yes | Yes | Yes |
 Database management as a group | No | No | No |
 Restore | Yes | Yes | Yes |
 Patching | Yes | Yes | Yes |
 Database scaling | Yes | Yes | Yes |
 Create Disaster Recovery | Yes | Yes | Yes |
 Switchover | Yes | Yes | Yes |
 Failover | Yes | Yes | Yes |

Note:

-   Database provisioning on an ESXi hypervisor fails if you provision the database using a software profile that is replicated from AHV to ESXi. This is applicable on the database server VMs running SUSE version 15 SP2 and Oracle database version 19c.
    
-   NDB supports CDB/PDB. For more information, see [Nutanix Database Service Oracle Database Management Guide](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-Oracle-Database-Management-Guide-v2_8:top-oracle-pdb-cdb-c.html).

### [SQL Server Software Compatibility and Feature Support](https://portal.nutanix.com/page/documents/details?targetId=Release-Notes-Nutanix-NDB-v2_9:v29-ndb-compatibility-sql-server-r.html)

Table 1. SQL Server Database and Operating System Versions Supported
 Operating System | SQL Server Database Versions |
| --- | --- |
 Windows Server 2025 | -   SQL Server 2022 (RTM)
-   SQL Server 2019 (RTM)
 |
 Windows Server 2022 | -   SQL Server 2022 (RTM)
-   SQL Server 2019 (RTM)
-   SQL Server 2017 (RTM)
 |
 Windows Server 2019 | -   SQL Server 2022 (RTM)
-   SQL Server 2019 (RTM)
-   SQL Server 2017 (RTM)
-   SQL Server 2016 (SP3)
-   SQL Server 2014 (SP3)
 |
 Windows Server 2016 | -   SQL Server 2022 (RTM)
-   SQL Server 2019 (RTM)
-   SQL Server 2017 (RTM)
-   SQL Server 2016 (SP3)
-   SQL Server 2014 (SP3)
 |

Note:

-   NDB supports Nutanix Cloud Clusters (NC2) on AWS and Azure for SQL Server.
-   NDB supports the following SQL Server editions:  -   Enterprise
      -   Standard
      -   Developer
      -   Express edition
    
-   For information on SQL Server best practices, see [Microsoft SQL Server on Nutanix](https://portal.nutanix.com/page/documents/solutions/details?targetId=BP-2015-Microsoft-SQL-Server:BP-2015-Microsoft-SQL-Server).

### SQL Server Versions Supported for AG

NDB supports the following SQL Server version for Always On Availability Group (AG).

-   SQL Server 2022 (standard, developer, and enterprise editions)
-   SQL Server 2019 (standard, developer, and enterprise editions)
-   SQL Server 2017 (standard, developer, and enterprise editions), requires CU16 (KB4508218) or above.
-   SQL Server 2016 (standard, developer, and enterprise editions)
-   SQL Server 2014 (developer and enterprise editions)

Table 2. Service Support Matrix for SQL Server Flavors
 SQL Server Workflow | Registration | Provision |
| --- | --- | --- |
 Multi instance (Only one instance) | Single instance | Single and Multi Nutanix Cluster HA - AG | Single Nutanix Cluster HA -FCI |
| --- | --- | --- | --- |
 Disk Type: Standard/Dynamic/Storage Spaces Disk Layout: vDisk/VGLB | Disk Type: Standard/Dynamic/Storage Spaces Disk Layout: vDisk/VGLB | Disk Type: Standard/Dynamic/Storage Spaces Disk Layout: vDisk/VGLB | Disk Type: Standard Disk Layout: VGLB |
| --- | --- | --- | --- |
 Provision database server VM | Not applicable | Yes | Yes | Yes |
 Register database server VM | Yes | Not applicable | Not applicable | Not applicable |
 Provision database | Yes | Yes | Yes | Yes |
 Register database | Yes | Not applicable | Not applicable | Not applicable |
 Copy Data Management - Snapshot and log catchup | Yes | Yes | Yes | Yes |
 Copy Data Management - Restore | Yes | Yes | Yes | No |
 Copy Data Management - Clone and Refresh | Yes, can clone to any database instance at the database server VM but NDB can only manage one instance. | Yes | Yes | Yes, clone to standalone instance. |
 Copy Data Management - Clustered Clone \[AG\] in Single Nutanix cluster | Yes | Yes | Yes | Yes |
 Copy Data Management - Clustered Clone \[AG\] across Multiple Nutanix cluster | No | No | No | No |
 Patching | Yes | Yes | Yes | No |
 Database group | Yes | Yes | Yes | Yes |
 Storage scaling of user database | No | Yes | Yes | No |

Note:

-   By default, NDB uses vDisks for provisioning databases.
-   Provisioning databases using VGLB, storage spaces, or dynamic disks are available as an advanced option using the configuration file.
-   Restore and clone operations are supported for TDE enabled AG and standalone databases.
-   NDB does not support multiple SQL Server instances in the same database server VM or cluster.

### [PostgreSQL Software Compatibility and Feature Support](https://portal.nutanix.com/page/documents/details?targetId=Release-Notes-Nutanix-NDB-v2_9:v29-ndb-compatibility-postgresql-r.html)

Table 1. PostgreSQL Community Edition Database and Operating System Versions Supported
 Operating System | Operating System Version | PostgreSQL Database Version |
| --- | --- | --- |
 Rocky Linux | 9.6 | -   17.0 - 17.6
-   16.0 - 16.10
-   15.0 - 15.14
-   14.0 - 14.18
 |
 Red Hat Enterprise Linux (RHEL) | 9.6 | -   17.0 - 17.6
-   16.0 - 16.10
-   15.0 - 15.14
-   14.0 - 14.17
 |
 9.4 | -   17.0 - 17.6
-   16.0 - 16.10
-   15.0 - 15.14
-   14.0 - 14.17
 |
 8.10 | -   17.0 - 17.6
-   16.0 - 16.10
-   15.0 - 15.14
-   14.0 - 14.17
 |
 8.8 | -   15.0 - 15.14
 |
 7.x | -   15.0 - 15.14
-   14.0 - 14.17
-   13.0 - 13.16
 |
 Ubuntu Linux | 22.04 | -   16.0 - 16.10
-   15.0 - 15.14
 |
 20.04 | -   15.0 - 15.14
-   14.0 - 14.17
-   13.0 - 13.16
 |
 Debian | 12 | -   17.5 - 17.6
-   16.9 - 16.10
 |
 11 | -   17.5 - 17.6
-   16.9 - 16.10
-   15.12 - 15.14
 |

For information on PostgreSQL best practices, see [PostgreSQL on Nutanix](https://portal.nutanix.com/page/documents/solutions/details?targetId=BP-2061-PostgreSQL-on-Nutanix:BP-2061-PostgreSQL-on-Nutanix).

Table 2. PostgreSQL EDB Enterprise Edition Database and Operating System Versions Supported
 Operating System | Operating System Version | PostgreSQL Database Version |
| --- | --- | --- |
 RHEL | 9.6 | -   17.2 - 17.6
-   16.1 - 16.10
-   15.2 - 15.14
-   14.1 - 14.17
 |
 9.4 | -   17.2 - 17.6
-   16.1 - 16.10
-   15.2 - 15.14
-   14.1 - 14.17
 |
 8.10 | -   17.2 - 17.6
-   16.1 - 16.10
-   15.2 - 15.14
-   14.1 - 14.17
 |
 8.8 | -   16.1 - 16.10
-   15.2 - 15.14
 |
 Ubuntu | 20.04 | -   15.2 - 15.14
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
 17.2 - 17.5 | RHEL 9.6/ 9.4/ 8.10 | \*4.0.5/ 3.3.2 | 3.5.12 | 2.8.9 | 2.2.8 |
 Rocky Linux 9.6 | 4.0.5/ 3.2.2 | 3.5.12 | 2.8.9 | 2.2.8 |
 RHEL 8.8 | 3.2.2 | 3.4.20 | 1.8.27 | 2.1.5 |
 16.4/ 16.6 | RHEL 9.6/ 9.4/ 8.10 | 4.0.5/ 3.3.2 | 3.5.12 | 2.8.9 | 2.2.8 |
 Rocky Linux 9.6 | 4.0.5/ 3.2.2 | 3.5.12 | 2.8.9 | 2.2.8 |
 RHEL 8.8 | 3.2.2 | 3.4.20 | 1.8.27 | 2.1.5 |
 \*\*Ubuntu 22.04 | 3.2.2 | 3.5.12 | 2.8.9 | 2.2.8 |
 15.8/ 15.10 | Rocky Linux 9.6 | 3.2.2 | 3.5.12 | 2.8.9 | 2.2.8 |
 RHEL 9.6/ 9.4/ 8.10 | 3.2.2 | 3.5.12 | 2.8.9 | 2.2.8 |
 RHEL 8.6 | 2.1.4 | 3.4.20 | 1.8.27 | 2.1.5 |
 \*\*Ubuntu 22.04 | 3.2.2 | 3.5.12 | 2.8.9 | 2.2.8 |
 Ubuntu 20.04 | 2.1.4 | 3.2.26 | 2.0.29 | 2.0.19 |
 14.15/ 14.17 | Rocky Linux 9.6 | 3.2.2 | 3.5.12 | 2.8.9 | 2.2.8 |
 RHEL 9.6/ 9.4/ 8.10 | 3.2.2 | 3.5.12 | 2.8.9 | 2.2.8 |
 Ubuntu 20.04 | 2.1.4 | 3.2.26 | 2.0.29 | 2.0.19 |

Note:

-   \*Patroni versions earlier than 4.x do not support or manage the new GUC parameters introduced by PostgreSQL 17.
-   \*\* Supported for PostgreSQL Community Edition only.

Table 5. Qualified OS versions and PostgreSQL versions for PostgreSQL extensions
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

## JSON Build Matrix Coverage

The repository now publishes all of these combinations in `ndb/2.9/matrix.json`. Each entry mirrors the compatibility tables above:

- `db_type` / `engine` identify the family (for example `pgsql`, `pgsql_edb`, `oracle`, `sqlserver`, `mysql`, `mariadb`, `mongodb`).
- `os_type` / `os_version` match the rows shown in the tables.
- `db_version` is either a single version (PostgreSQL 17) or a range (`19.26-19.28` for Oracle) depending on the official documentation.
- `ha_components` records, when applicable, the Patroni/etcd/HAProxy/Keepalived versions from Table 4 so that automation can consume the recommended patch levels.
- `extensions` lists the qualified PostgreSQL extensions (Table 5) for Community builds. When the array is absent (or empty), the build intentionally skips extension packages so that only configurations that explicitly request them receive the additional software.
- `provisioning_role` indicates whether today’s Packer/Ansible pipeline can build the image (`postgresql`) or whether the entry is informational only (`metadata` while the corresponding roles are still pending).

### Engine coverage inside `matrix.json`

- **PostgreSQL Community Edition (`db_type=pgsql`)**  
  - Rocky Linux 9.6, RHEL 9.6 and Ubuntu 22.04 carry `provisioning_role=postgresql` for versions 17/16/15/14 with the Patroni/etcd/HAProxy/Keepalived tuples extracted from Table 4.  
  - Additional rows (RHEL 9.4/8.10/8.8/8.6 and Ubuntu 20.04) are flagged as `metadata` to mirror the complete compatibility matrix.
- **PostgreSQL EDB Advanced Server (`db_type=pgsql_edb`)**  
  - RHEL 9.6/9.4/8.10/8.8 and Ubuntu 20.04 cover the ranges 17.2‑17.6, 16.1‑16.10, 15.2‑15.14 and 14.1‑14.17. These lines act as the source of truth for future EPAS automation.
- **Oracle Enterprise Edition (`db_type=oracle`)**  
  - OEL/RHEL 9.6 and 8.10 entries (versions 19.23‑19.28) reference this section for ASM/SELinux constraints.
- **Microsoft SQL Server (`db_type=sqlserver`)**  
  - Windows Server 2016→2025 rows include the corresponding SQL Server versions and AG/FCI workflows.
- **MySQL / MariaDB (`db_type=mysql`, `db_type=mariadb`)**  
  - Rocky/RHEL/Ubuntu/Debian combinations are stored with the 8.4.5 / 8.0.x (MySQL) and 10.11 / 10.6 (MariaDB) ranges cited earlier.
- **MongoDB (`db_type=mongodb`)**  
  - Single-instance, replica-set and sharded deployments (see the MongoDB tables) are differentiated through the `deployment` field.

`build.sh` now accepts `--db-type` and explicitly rejects entries whose `provisioning_role` is `metadata`, which ensures that only the PostgreSQL Community rows are buildable until the remaining playbooks are delivered.

| db_type | Engine | Current status | Notes |
| --- | --- | --- | --- |
| `pgsql` | PostgreSQL Community Edition | ✅ Buildable (`provisioning_role=postgresql`) | Packer/Ansible roles live in this repository. |
| `pgsql_edb` | PostgreSQL EDB Advanced Server | ℹ️ Metadata | Waiting for an EPAS-specific role. |
| `oracle` | Oracle Enterprise Edition | ℹ️ Metadata | Reference for future profiles (ASM/SELinux). |
| `sqlserver` | Microsoft SQL Server | ℹ️ Metadata | AG/FCI workflows captured for documentation. |
| `mysql` / `mariadb` | MySQL & MariaDB | ℹ️ Metadata | Version ranges catalogued ahead of role development. |
| `mongodb` | MongoDB | ℹ️ Metadata | Distinguishes single-instance / replica-set / sharded deployments. |

Future work will introduce dedicated Packer/Ansible roles and evolve `provisioning_role` (for example `oracle`, `sqlserver`) so that `build.sh` can eventually build these additional engines.

### [MongoDB Software Compatibility and Feature Support](https://portal.nutanix.com/page/documents/details?targetId=Release-Notes-Nutanix-NDB-v2_9:v29-ndb-compatibility-mongodb-r.html)

Table 1. MongoDB Database and Operating System Versions Supported for Single Instance and Replica Set
 Operating System | Operating System Version | MongoDB Database Versions |
| --- | --- | --- |
 Rocky Linux | 9.6 | -   8.0.0 - 8.0.15 Community and Enterprise
-   7.0 - 7.0.25 Community and Enterprise
-   6.0.4 - 6.0.25 Community and Enterprise
 |
 9.5 | -   8.0.0 - 8.0.15 Community and Enterprise
-   7.0 - 7.0.25 Community and Enterprise
-   6.0.4 - 6.0.25 Community and Enterprise
 |
 9.4 | -   8.0.0 - 8.0.15 Community and Enterprise
-   7.0 - 7.0.25 Community and Enterprise
-   6.0.4 - 6.0.25 Community and Enterprise
 |
 Red Hat Enterprise Linux (RHEL) | 9.6 | -   8.0.0 - 8.0.15 Community and Enterprise
-   7.0 - 7.0.25 Community and Enterprise
-   6.0.4 - 6.0.25 Community and Enterprise
 |
 9.5 | -   8.0.0 - 8.0.15 Community and Enterprise
-   7.0 - 7.0.25 Community and Enterprise
-   6.0.4 - 6.0.25 Community and Enterprise
 |
 9.4 | -   8.0.0 - 8.0.15 Community and Enterprise
-   7.0 - 7.0.25 Community and Enterprise
-   6.0.4 - 6.0.25 Community and Enterprise
 |
 8.10 | -   7.0 - 7.0.25 Community and Enterprise
-   6.0.4 - 6.0.25 Community and Enterprise
 |
 Ubuntu Linux | 22.04 | -   8.0.0 - 8.0.15 Community and Enterprise
-   7.0 - 7.0.25 Community and Enterprise
-   6.0.4 - 6.0.25 Community and Enterprise
 |
 20.04 | -   7.0 - 7.0.25 Community and Enterprise
-   6.0.4 - 6.0.21 Community and Enterprise
 |
 Debian Linux | 12 | -   8.0.0 - 8.0.15 Community and Enterprise
-   7.0 - 7.0.25 Community
 |
 11 | -   7.0 - 7.0.25 Community and Enterprise
-   6.0.0 - 6.0.25 Community and Enterprise
 |

Note:

-   NDB supports MongoDB Enterprise and Community editions.
-   NDB supports WiredTiger (default storage engine for MongoDB) for all supported MongoDB versions.

Table 2. MongoDB Database and Operating System Versions Supported for Sharded Cluster
 Operating System | Operating System Version | MongoDB Database Versions |
| --- | --- | --- |
 Rocky Linux | 9.6 | -   8.0.0 - 8.0.15 Community and Enterprise
-   7.0 - 7.0.25 Community and Enterprise
-   6.0.0 - 6.0.25 Community and Enterprise
 |
 9.5 | -   8.0.0 - 8.0.15 Community and Enterprise
-   7.0 - 7.0.25 Community and Enterprise
-   6.0.0 - 6.0.25 Community and Enterprise
 |
 9.4 | -   8.0.0 - 8.0.15 Community and Enterprise
-   7.0 - 7.0.25 Community and Enterprise
-   6.0.0 - 6.0.25 Community and Enterprise
 |
 Red Hat Enterprise Linux (RHEL) | 9.6 | -   8.0.0 - 8.0.15 Community and Enterprise
-   7.0 - 7.0.25 Community and Enterprise
-   6.0.0 - 6.0.25 Community and Enterprise
 |
 9.5 | -   8.0.0 - 8.0.15 Community and Enterprise
-   7.0 - 7.0.25 Community and Enterprise
-   6.0.0 - 6.0.25 Community and Enterprise
 |
 9.4 | -   8.0.0 - 8.0.15 Community and Enterprise
-   7.0 - 7.0.25 Community and Enterprise
-   6.0.4 - 6.0.21 Community and Enterprise
 |
 8.10 | -   7.0 - 7.0.25 Community and Enterprise
-   6.0.0 - 6.0.25 Community and Enterprise
 |

For information on MongoDB best practices, see [MongoDB on Nutanix](https://portal.nutanix.com/page/documents/solutions/details?targetId=BP-2023-MongoDB-on-Nutanix:BP-2023-MongoDB-on-Nutanix).

Table 3. NDB Features Matrix for MongoDB
 NDB Feature | Single Instance | Replica Set | Sharded Cluster |
| --- | --- | --- | --- |
 Registration of cluster databases deployed across Nutanix clusters | Not applicable | Not applicable | No |
 Database Provision | Yes | Yes | Yes |
 Provision of database Replicas across Nutanix clusters | Not applicable | Yes | Yes |
 Provision of multiple database instance on the same host | No | No | No |
 Provision of multiple databases in the same database server VM | No\* | No\* | No |
 Provision of database server VM on any Nutanix cluster | Yes | Yes | Yes |
 Copy data management (Clone/Refresh) | Yes (can only create a single instance clone from a single database instance) | Yes (can only create a single instance clone from a single database instance) | No |
 Database management as a group | No | No | No |
 Restore | Yes | Yes | No |
 Patching | Yes\*\* | Yes\*\* | No |
 Database scaling | Yes | Yes | No |

\* Not using NDB, but you can perform the provisioning through the MongoDB Instance. You must log into a MongoDB instance through the CLI or a management tool.

\* \*Patching through NDB or outside of NDB is not supported if you use a Linux package manager such as YUM to install the database engine.

### [MySQL and MariaDB Software Compatibility and Feature Support](https://portal.nutanix.com/page/documents/details?targetId=Release-Notes-Nutanix-NDB-v2_9:v29-ndb-compatibility-mysql-mariadb-r.html)

Table 1. MySQL Database and Operating System Versions Supported
 Operating System | Operating System Version | MySQL Database Versions |
| --- | --- | --- |
 Rocky Linux | 9.6 | -   \*8.4.5 Community and Enterprise
-   8.0.36 - 8.0.43 Community
-   8.0.43 Enterprise (Oracle)
 |
 -   9.5
-   9.4
 | 8.0 Community |
 RHEL | 9.6 | -   \*8.4.5 Community and Enterprise
-   8.0.36 - 8.0.45 Community
-   8.0.43 Enterprise (Oracle)
 |
 -   9.5
-   9.4
 | -   8.0.26 Enterprise (Oracle)
-   8.0.36 Community
 |
 8.10 | -   \*8.4.5 Community and Enterprise
-   8.0.36 - 8.0.43 Community
-   8.0.26 Enterprise (Oracle)
 |
 8.8 | -   8.0.36 Community
-   8.0.36 Percona
 |
 Ubuntu Linux | 22.04 | -   8.0.36 - 8.0.45 Community
-   8.0 Community and Enterprise (Oracle)
 |
 20.04 | 8.0 Community |
 Debian Linux | 12 | -   8.0.36 - 8.0.45 Community
-   8.0 Community and Enterprise (Oracle)
 |
 11 | 8.0 Community and Enterprise (Oracle) |

Note:

-   \*Versions supported for MySQL HA.
-   On RHEL and Rocky Linux 9.N, disable the 
    ```
    use_devicesfile
    ```
     setting by setting 
    ```
    use_devicesfile = 0
    ```
     in the file /etc/lvm/lvm.conf on the DB Server VM used to create the NDB software profile.

Table 2. MariaDB Database and Operating System Versions Supported
 Operating System | Operating System Version | MariaDB Database Versions |
| --- | --- | --- |
 Rocky Linux | 9.5 | 10.11 Community |
 RHEL | -   9.5
-   9.4
 | -   10.11 Community
-   10.6 Enterprise
 |
 8.10 | -   10.11 Community
-   10.6 Enterprise
 |
 Ubuntu | 22.04 | -   10.11 Community
 |
 Debian | 12 | -   10.11 Community and Enterprise
 |
 11 | -   10.11 Community
 |

For information on MySQL best practices, see [MySQL on Nutanix](https://portal.nutanix.com/page/documents/solutions/details?targetId=BP-2056-MySQL-on-Nutanix:BP-2056-MySQL-on-Nutanix).

Table 3. NDB Features Matrix for MySQL and MariaDB
 NDB Feature | Single Instance | High Availability |
| --- | --- | --- |
 MySQL | MariaDB |
| --- | --- |
 Database Provision | Yes | Yes | No |
 Provision of database Replicas across Nutanix clusters | Not applicable | Yes | No |
 Provision of multiple database instance on the same host | No | Not applicable | Not applicable |
 Provision of multiple databases in the same database server VM | Yes | Not applicable | Not applicable |
 Provision of database server VM on any Nutanix cluster | Yes | Yes | Not applicable |
 Copy data management (Clone/Refresh) | Yes (can only create a single instance clone from a single database instance) | Not applicable | Not applicable |
 Database management as a group | No | Not applicable | Not applicable |
 Restore | No | No | No |
 Patching | No | No | No |
 Database scaling | No | No | No |

### [Browser Compatibility](https://portal.nutanix.com/page/documents/details?targetId=Release-Notes-Nutanix-NDB-v2_9:v29-ndb-browser-compatibility-r.html)

For the best user experience, access the NDB user interface using one of the following supported browsers.

Table 1. NDB Browser Compatibility
 Browser | Version |
| --- | --- |
 Mozilla Firefox | 132.0.1 or later |
 Google Chrome | 130.0 or later |
 Apple Safari | 18.1 or later |

Minimum Recommended Browser Resolution

1280 px \* 800 px