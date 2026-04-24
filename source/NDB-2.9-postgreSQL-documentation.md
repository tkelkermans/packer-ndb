# Nutanix Database Service 2.9 - Nutanix Database Service PostgreSQL Database Management Guide

With NDB you can easily register, provision, clone, and administer all of your PostgreSQL databases on one or more Nutanix clusters with a single click.

NDB supports PostgreSQL database with EnterpriseDB Advance Server (EPAS) tool but not any other EDB tools.

NDB allows the postgres and custom users (database server VM operating system user) to run the following database operations using the EPAS tool:

-   database provision
-   database registration
-   database clone
-   database patch
-   database instance restore

You start the PostgreSQL instance as a postgres or custom user.

Note:

-   Install sshpass on database server VMs for successful clone, patch, and restore operations.
-   The postgres user and custom users can have the read, write, and execute permissions to the data and tsdata directories. Other users must not create any additional custom directories or files inside the data or tsdata directories as this might cause PostgreSQL and NDB operations to fail.

For information on NDB installation, initial configuration, and administration, see [NDB Administration Guide](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide) for your NDB version.

### Community Edition Support

Nutanix provides enterprise-grade support for PostgreSQL Community Edition deployed and managed through NDB. Nutanix Support covers installation, configuration, high availability (using Patroni, etcd, and HAProxy), backup and recovery workflows, and interoperability with NDB\-qualified extensions. For more information see, [Appendix](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-PostgreSQL-Database-Management-Guide-v2_9:top-postgresql-appendix-c.html).

### [PostgreSQL High Availability (HA) Support](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-PostgreSQL-Database-Management-Guide-v2_9:top-postgres-high-availability-cluster-c.html)

You can provision a highly available PostgreSQL instance to avoid service disruption when there is a node failure. When you provision a highly available PostgreSQL instance, NDB provisions multiple database server VMs to form a cluster. Each VM has the PostgreSQL instance, Patroni, and etcd running on it. The etcd processes running on each database server VM form a cluster that acts as the distributed configuration store to be used by Patroni for cluster management and leader election. Each VM has dedicated storage for the database. One of the PostgreSQL instances in the cluster acts as the primary, and other instances serve as replicas. The replicas connect to the primary PostgreSQL instance over the network and use physical streaming replication to ship write-ahead log segments. Connections to the primary instance can be used for both read and write operations, while connections to the replica can be used only for read-only requests. When a primary PostgreSQL instance becomes unavailable, Patroni promotes one of the replicas to the role of the primary, ensuring the availability of the database for all write operations. 

When you provision a highly available cluster, NDB creates a time machine for it. The time machine selects the primary node of the cluster as the active node for its operations. In the event of a failover or switchover, NDB auto-detects such changes, and the time machine selects the new primary as the active node. If a primary node is available in the cluster, the time machine continues to function seamlessly. If there is an entire cluster breakdown, time machine activities stop until the cluster is repaired and a new primary node is elected.

A three-node cluster consists of three PostgreSQL nodes, two optional HAProxy nodes, and a virtual IP address that floats between the two HAProxy servers. Each PostgreSQL node runs a PostgreSQL database, etcd, and Patroni software. Each HAProxy node has Keepalived software running that assigns a virtual IP address to one of the HAProxy nodes. If one HAProxy node fails, Keepalived binds the virtual IP address to the second HAProxy node. HAProxy nodes then redirect the traffic to either primary or replica nodes based on the port (read/write or read-only) selected.

Note:

-   Nutanix does not recommend deploying PostgreSQL HA across geographical locations for disaster recovery use cases.
-   In the event of losing a majority of database server VMs in an HA deployment, the PostgreSQL HA cluster is no longer functional. In this state, the NDB time machine operations and management do not function. You must bring back the majority of database server VMs to continue the successful operation of the PostgreSQL HA cluster.

See [PostgreSQL Database Provisioning](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-PostgreSQL-Database-Management-Guide-v2_9:top-postgresql-database-provision-c.html) for information on the software required for PostgreSQL HA provisioning.

### [Current Limitations](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-PostgreSQL-Database-Management-Guide-v2_9:top-postgresql-limitations-c.html)

NDB has the following limitations for PostgreSQL:

-   NDB does not support OS or database patching for deployments from out-of-the-box (OOB) software profiles.
-   NDB does not support provisioning multiple PostgreSQL instances in the same database server VM.
-   NDB does not support provisioning multiple PostgreSQL clones in the same database server VM.
-   NDB does not support registration of brownfield Highly Available instances.
-   NDB does not support addition or removal of databases on an existing PostgreSQL clone.
-   NDB does not support addition or removal of nodes on an existing PostgreSQL HA database.
-   NDB does not support re-registration of a PostgreSQL HA cluster in NDB, after you de-register the cluster from NDB and add new nodes. This is because NDB does not support PostgreSQL HA registration.
-   NDB supports ext4 file system but does not support XFS file system.
-   NDB supports PostgreSQL database with EnterpriseDB Advance Server (EPAS) tool but not any other EDB tools.
-   PostgreSQL provisioning operation fails if the database server name has more than 64 characters in Ubuntu or Debian.
-   NDB does not support the hyphen character (-) in user-defined volume group names.
-   Nutanix does not recommend deploying PostgreSQL HA across geographical locations for disaster recovery use cases.
-   Occasionally, the number of HugePages that NDB sets in a newly deployed database server VM does not reflect since the OS does not instantly honor the changes. You must restart the VM for the modifications to take effect.
-   NDB does not allow special characters in names and descriptions while provisioning or registering PostgreSQL databases.
-   If the pre/post commands have multiple lines or double quotes (""), PostgreSQL operations might fail. **Workaround**:  1.  Create a new single script and include all the commands in the script.
      2.  Copy the script to the gold image server.
      3.  Create a new software profile from the gold image server.
      4.  Use the newly created software for provisioning and use the script as pre and post commands.
    
-   Provisioning PostgreSQL HA databases fails with the following error:
    ```
    
    ```
    Failed to initialize application discovery
    ```
    
    ```
    Or
    ```
    
    ```
    database layout discovery.
    ```
    
    ```
    
    For more information, see [KB 17952](http://portal.nutanix.com/kb/17952).
    
-   Clone refresh operation completes with the following warning if you use a registered database server VM for clone and the VM has a service file with a database OS user that does not match the actual database OS user from the clone operation:
    ```
    
    ```
    Could not start postgres using era_postgres service. Starting it using pg_ctl
    ```
    
    ```
    **Workaround**: If the database is not running, manually start the database using pg\_ctl or update the service file with the appropriate database OS username.

### [PostgreSQL Database Profiles](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-PostgreSQL-Database-Management-Guide-v2_9:top-postgresql-db-profiles-c.html)

Profiles enable you to create templates of database software, networking, compute, and database parameters that help you to provision databases or database server VMs on NDB.

The software profiles might contain third-party proprietary or open-source software that is subject to intellectual property rights owned by third parties. Such third-party software is licensed to you under separate terms presented during installation, in the third-party notices files or disclosure accompanying the software, or in another manner such as on a download portal. The included software profiles are provided for your convenience and are not a part of the Nutanix software.

Note:

-   NDB no longer supports CentOS version 7 or earlier in the out-of-the-box (OOB) software profiles. Use the new OOB software profiles with Rocky Linux 8.10 OS instead.
-   NDB no longer supports PostgreSQL version 10 and earlier in the OOB software profiles. Use the new OOB software profiles with PostgreSQL 15 instead.
-   If you are running a Debian OS, the PostgreSQL database might not accept external connections in these situations:  -   When the database server VM reboots. This is caused when both iptables and nftables packages are installed in the VM. The iptables package installs another package called ebtables that overwrites nftables configurations.
          
          Workaround: Uninstall the iptables package.
          
      -   When a registered database is unable to accept external connections. This is caused due to incorrect ingress rules configured in the nftables.
          
          Workaround: Add the ingress rules for nftables manually.
    
-   PostgreSQL provisioning using NDB might fail if 
    ```
    systemd
    ```
     is not configured correctly. To avoid such failures when 
    ```
    systemd
    ```
     is in use in the VM, see [PostgreSQL Documentation](https://www.postgresql.org/docs/current/kernel-resources.html#:~:text=and%20prctl.-,19.4.2.%C2%A0systemd%20RemoveIPC,-If%20systemd%20is).

See [NDB Profiles](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide:top-getting-started-profiles-c.html) for more information on the available NDB profiles.

### [Creating a Software Profile](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-PostgreSQL-Database-Management-Guide-v2_9:top-software-profile-postgresql-create-t.html)

### Before you begin

-   Ensure that you have registered an existing PostgreSQL database server VM with NDB. NDB uses a registered database server VM to create a software profile.
-   To verify the SELinux options available for DB Server VMs, see [Security-Enhanced Linux Configuration](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide:top-selinux-config-c.html).

### About this task

Perform the following procedure to create a software profile. A software profile is created from the software installed on the registered instances.

Note: Create a software profile only if you do not want to use or update the built-in sample profiles 
```
POSTGRES_15.6_ROCKY_LINUX_8_OOB
```
 or 
```
POSTGRES_15.6_HA_ENABLED_ROCKY_LINUX_8_OOB
```
.

### Procedure

1.  From the main menu, select Profiles.
2.  Go to Software, click Create, and select either Instance or HA Instance under the PostgreSQL engine. The Create Software Profile window appears. You create a software profile in the following steps:  1.  Software
      2.  Notes
      3.  Availability
    
    Note:
    
      8.   The database server VM used for creating the software profile for HA instance must have Patroni, HAProxy, etcd, and Keepalived software installed.
      9.   Availability is displayed only when you have enabled multi-cluster in NDB. See [Enabling NDB Multi-Cluster](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide:top-multicluster-enable-t.html) for more information.
    
3.  In the Software step, do the following in the indicated fields.  1.  Profile Name. Type a name for the software profile.
      2.  Profile Description. Type a description for the software profile.
      3.  Software Profile Version Name. The software profile version name is auto-populated based on the Profile Name.
      4.  Software Profile Version Description. Type a description for the software profile version.
      5.  Nutanix Cluster. Select the Nutanix cluster on which you want to create the profile.
          
          Note: NDB multi-cluster must be enabled to select different Nutanix clusters. See [Nutanix Cluster Management](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide:top-multicluster-management-c.html) for more information.
          
      6.  Select a database server VM from the list of available database server VMs that you previously registered with NDB.
      7.  Click Next.
    
4.  In the Notes step, do the following in the indicated fields.
    
    Note: Notes are optional. You can enter notes if you want to provide more information about the software profile.
    
      1.  Operating System Notes. Type a note to provide additional information about the operating system.
      2.  Database Software Notes. Type a note to provide additional information about the database software.
    
5.  In the Availability step, select the Nutanix clusters where this profile is available.
6.  Click Create to create a software profile.
    
    The new profile appears in the list of software profiles and a message appears indicating that the operation to create a software profile has started. Click the message to monitor the progress of the operation. Alternatively, select Operations from the drop-down list of the main menu to monitor the progress of the operation.
    
    Click the name of the profile to view the version information and create a new version of the software profile. For more information, see [Creating a Software Profile Version](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-PostgreSQL-Database-Management-Guide-v2_9:top-software-profile-version-create-t.html) .

### [Creating a Software Profile Version](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-PostgreSQL-Database-Management-Guide-v2_9:top-software-profile-version-create-t.html)

A software profile version is required when you update a database server VM. You can create a software profile version to provision and update other database server VMs using this software profile.

### Before you begin

You need an existing software profile. For more information, see [Creating a Software Profile](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-PostgreSQL-Database-Management-Guide:top-software-profile-postgresql-create-t.html).

### About this task

Perform the following procedure to create a version of the software profile.

### Procedure

1.  From the main menu, select Profiles.
2.  Go to Software and open the software profile used by the database server VM.
3.  Click Create.
    
    The Create Software Profile Version window appears.
    
4.  In the Software step, do the following in the indicated fields.  1.  Name. Type a name for the software profile version.
      2.  Description. Type a description for the software profile version.
      3.  Nutanix Cluster. Select the Nutanix cluster on which you want to create the profile.
          
          Note: NDB multi-cluster must be enabled to select different Nutanix clusters. See [Nutanix Cluster Management](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide:top-multicluster-management-c.html) for more information.
          
      4.  Select a database server VM from the list of available database server VMs that you previously registered with NDB. Ensure that the database server VM selected has the same OS and the same edition of the database engine (community edition) which was selected to create the first version.
    
5.  In the Notes step, do the following in the indicated fields.
    
    Note: Notes are optional. You can enter notes if you want to provide more information about the software profile version.
    
      1.  Operating System Notes. Type a note to provide additional information about the operating system.
      2.  Database Software Notes. Type a note to provide additional information about the database software.
    
6.  Click Create.
    
    NDB creates a version of the software profile for provisioning and updating other database server VMs and displays it in the list. NDB extracts more details about the software profile version from the database server VM and displays them in a separate widget below the profile version list. NDB categorizes the details in the following manner.
    
      26.   Operating System. Displays information about the operating system such as vendor name, version, OS packages, and notes.
      27.   Database Software. Displays information about the database version, patches, and bug fixes. Click the plus icon to view the bug fixes for the respective PSU.
      28.   Database Server VMs. Displays the database server VMs that are using this version of the profile.
      29.   Availability. Displays the profile availability across clusters.

### What to do next

After profile creation is successful, you must publish the profile to make the profile version visible for updates. See [Updating a Software Profile Version](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-Oracle-Database-Management-Guide:top-oracle-software-profile-version-update-t.html) for more details.

### [Updating a Software Profile Version](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-PostgreSQL-Database-Management-Guide-v2_9:top-software-profile-version-update-t.html)

### About this task

Perform the following procedure to update a software profile version.

### Procedure

1.  From the main menu, select Profiles.
2.  Go to Software and open the software profile used by the database server VM.
3.  Select the profile version and click Update.
    
    The Update Software Profile Version window appears.
    
4.  In the General step, do the following in the indicated fields.  1.  Name. Type a name for the software profile version.
      2.  Description. Type a description for the software profile version.
      3.  Status. Select one of the following:    -   Unpublished. Select this option if you want to hide the profile version.
              4.   Published. Select this option to make the profile version visible for updates. If you have selected this option, NDB provides a recommendation on the database server VM homepage that all database server VMs using an earlier version of this software profile should update to this new version.
              5.   Deprecated. Select this option if you want to prevent this version from being used in provisioning. A message is displayed on the homepages of the database server VMs and server clusters using this version of the software profiles that they must update to a newer version of the profile.
          
      4.  Click Next.
    
5.  In the Notes step, do the following in the indicated fields.
    
    Note: Notes are optional. You can enter notes if you want to provide more information about this version of the software profile.
    
      1.  Operating System Notes. Type a note to provide additional information about the operating system.
      2.  Database Software Notes. Type a note to provide additional information about the database software.
    
6.  Click Update.
    
    NDB updates the version of the software profile and displays the details in a separate widget below the profile version list.

### [Creating a Compute Profile](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-PostgreSQL-Database-Management-Guide-v2_9:top-compute-profile-create-t.html)

### About this task

Perform the following procedure to create a compute profile.

Note: Create a compute profile only if you do not want to use the sample profile (DEFAULT\_OOB\_COMPUTE).

### Procedure

1.  From the main menu, select Profiles.
2.  Go to Compute and click Create.
    
    The Create Compute Profile window appears.
    
3.  Do the following in the indicated fields.  1.  Name. Type a name for the compute profile.
      2.  Description. Type a description for the compute profile.
      3.  vCPUs. Type the number of vCPUs for the database server VM.
      4.  Cores Per vCPU. Type the number of cores per vCPU for the database server VM.
      5.  Memory (GB). Type the memory for the database server VM.
    
4.  Click Create to create the compute profile.
    
    The new profile appears in the list of compute profiles. Click the name of the profile to view the number of vCPUs, cores per CPU, and memory allocated to this profile.

### [Creating a Network Profile](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-PostgreSQL-Database-Management-Guide-v2_9:top-network-profile-postgresql-create-t.html)

A network profile specifies the VLAN for the new database server.

### Before you begin

Ensure the following before you create a network profile.1.  Create VLANs on the Nutanix cluster for your database environment.
2.  Add the VLANs to NDB. For more information, see [Adding a VLAN to NDB](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide:top-vlan-add-t.html).

### About this task

Create a network profile, as a sample network profile is not available in NDB. You can create a sample network profile either by using the Welcome to NDB wizard, or by performing the following procedure.

Perform the following procedure to create a network profile for PostgreSQL single instance.

### Procedure

1.  From the main menu, select Profiles.
2.  Go to Network, click Create, and select Instance under the PostgreSQL engine. The Create Network Profile window appears.
3.  Do the following in the indicated fields.  1.  Name. Type a name for the network profile.
      2.  Description. Type a description for the network profile.
      3.  Public Service VLAN. Select the VLAN to provide the IP address used to connect the database from the public network.
      4.  Optionally, if the VLAN you want to select does not appear in the Public Service VLAN drop-down list, click the Click here option.
          
          You can add one or more VLANs to NDB. For more information about how to add a VLAN to NDB, see [Adding a VLAN to NDB](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide:top-vlan-add-t.html).
          
      5.  IP Address. Select this option to provide IP addresses as an input during the PostgreSQL instance provision operation.
          
          Note: The IP Address option can only be selected for profiles containing static VLANs managed in NDB or Prism-based IPAM VLANs.
    
4.  Click Create to create a network profile.
    
    The new profile appears in the list of network profiles. Click the name of the profile to view the engine, deployment type, and public service VLAN associated with the respective profile.

### [Creating a HA Instance Network Profile](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-PostgreSQL-Database-Management-Guide-v2_9:top-ha-network-profile-postgresql-create-t.html)

A network profile specifies the VLAN for the new database server VM. With NDB multi-cluster, you can create a network profile specifying the VLANs to be used for each Nutanix cluster while provisioning a HA instance across different Nutanix clusters.

### Before you begin

Ensure the following before you create a network profile.1.  Create VLANs on the Nutanix cluster for your database environment.
2.  Add the VLANs to NDB. For more information, see [Adding a VLAN to NDB](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide:top-vlan-add-t.html).

### About this task

Perform the following procedure to create a HA network profile for PostgreSQL.

### Procedure

1.  From the main menu, select Profiles.
2.  Go to Network, click Create, and select HA Instance under the PostgreSQL engine. The Create Network Profile window appears.
3.  Do the following in the indicated fields.  1.  Name. Type a name for the network profile.
      2.  Description. Type a description for the network profile.
      3.  Under Show Nutanix Clusters where the VLAN's IP Address Pool is, select one of the following.
          
              5.   Managed in NDB. Select this option to display the VLANs managed by NDB in the Nutanix clusters.
              6.   Managed Outside NDB. Select this option to display the VLANs managed outside NDB in the Nutanix clusters.
          
      4.  Use Stretched vLAN. Select this option to create a HA network profile using a stretched VLAN. This profile can only be used to enable NDB Service high availability. See [Adding a stretched VLAN to NDB](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide:top-stretched-vlan-add-t.html) for details on adding a stretched VLAN to NDB.
          
          Note: A HA network profile using a stretched VLAN cannot be used to provision a PostgreSQL HA instance.
          
      5.  If you did not select the Use Stretched vLAN option in the previous step, then select all the Nutanix clusters and the VLANs configured in those clusters to be used with the profile.
      6.  (Only if you selected the Use Stretched vLAN option in the previous step) Stretched vLAN. Select stretched VLAN to be used with the profile.
      7.  IP Address. Select this option to provide IP addresses as an input during the PostgreSQL HA instance provision operation.
          
          Note: The IP Address option can only be selected for profiles containing static VLANs managed in NDB or Prism-based IPAM VLANs.
    
4.  Click Create to create a network profile.
    
    The new profile appears in the list of network profiles. Click the name of the profile to view the engine, deployment type, and VLANs associated with the respective profile.

### [Creating a Database Parameter Profile](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-PostgreSQL-Database-Management-Guide-v2_9:top-database-parameters-profile-postgresql-create-t.html)

A database parameter profile is a template of custom database parameters that you want to apply to your database.

### About this task

Perform the following procedure to create a database parameter profile for PostgreSQL.

Note: Create a database parameter profile only if you do not want to use the sample database parameter profile.

### Procedure

1.  From the main menu, select Profiles.
2.  Go to Database Parameters and click Create. The Create Database Parameter Profile window appears. You create a database parameter profile in the following steps:  1.  Engine
      2.  Parameters
    
3.  In the Engine step, select PostgreSQL as the database engine and click Next.
4.  In the Parameters step, do the following in the indicated fields.  1.  Name. Type a name for the database parameter profile.
      2.  Description. Type a description for the database parameter profile.
    
    The parameters in the profile are populated with the recommended values and are optional to configure. You can update these parameters to suit your requirements. Click the page navigation arrows to display all the available parameters. To search for a parameter, type the name of the parameter in the search text box.
    
    The Value column displays the default values of the parameters. You can choose to update the value of the parameters to suit your requirements.
    
    If you want to display only those parameters that you have updated, select the Modified Only option.
    
    Note: In the Description column, you can view the detailed information for each parameter.
    
5.  Click Create to create the database parameter profile.
    
    The new profile appears in the list of database parameter profiles. Click the name of the profile to view information about the parameters associated with the respective profile.

### [Updating PostgreSQL Profiles](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-PostgreSQL-Database-Management-Guide-v2_9:top-postgresql-profile-update-t.html)

After a profile is successfully created, you can update the profile details and the availability of the profile across the available clusters.

### About this task

Perform the following procedure to update profile availability.

### Procedure

1.  From the main menu, select Profiles.
2.  Select one of the following profiles.  -   Software Profile.
      3.   Compute Profile.
      4.   Network Profile.
      5.   Database Parameter Profile.
    
3.  If you selected Software Profile, do the following:  1.  Select the software profile and click Update. The Update Profile window appears.
      2.  Update the profile name, description, and profile availability for the listed Nutanix clusters.
      3.  Click Update.
          
          NDB updates the software profile and replicates the profile to the selected clusters. A message appears indicating that the operation to update a software profile has started. Click the message to monitor the progress of the operation. Alternatively, select Operations from the drop-down list of the main menu to monitor the progress of the operation.
    
4.  If you selected Compute Profile, do the following:  1.  Select the compute profile and click Update. The Update Compute Profile window appears.
      2.  Update the profile name, description, vCPUs, cores per CPU, and memory details.
      3.  Publish. Select this check box to publish the profile.
      4.  Click Update.
    
5.  If you selected Network Profile, do the following:  1.  Select the network profile and click Update. The Update Network Profile window appears.
      2.  Update the profile name, description, and service VLANs details.
      3.  (Only for PostgreSQL) IP Address. Update this option to either provide IP addresses as an input during the PostgreSQL instance provision operation or otherwise.
          
          Note: The IP Address option can only be selected for profiles containing static VLANs managed in NDB or Prism-based IPAM VLANs.
          
      4.  Publish. Select this check box to publish the profile.
      5.  Click Update.
    
6.  If you selected Database Parameter Profile, do the following:  1.  Select the database parameter profile and click Update. The Update Database Parameter Profile window appears.
      2.  Update the profile name and description.
      3.  Publish. Select this check box to publish the profile.
      4.  Click Update.

### [PostgreSQL Database Server VM Registration](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-PostgreSQL-Database-Management-Guide-v2_9:top-postgresql-db-server-vm-registration-c.html)

You can register a source (production) database running on a Nutanix cluster with NDB. When you register a database with NDB, the database server VM (VM that hosts the source database) is also registered with NDB. After you have registered a database with NDB, a time machine is created for that database.

Important: Nutanix recommends installing Cloud-init on a database server VM before registering the VM with NDB. Installing CloudInit reduces provisioning time. For information about installing and enabling Cloud-init, see KB 19302.

### [Database Server VM Registration Prerequisites](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-PostgreSQL-Database-Management-Guide-v2_9:top-opensource-db-server-registration-prereq-r.html)

Ensure that you meet the following requirements before you start registering a database server VM.

### General

-   Ensure that the designated database OS user is present on the database server VM.
-   Database server VMs must have connectivity to Prism Element through TCP port 9440.
-   The NDB server must have connectivity to the database server VM.
-   The iSSCSI and iSCSI packages must be installed.

### Software Dependencies (Linux)

-   To register a database server VM with NDB, the database server VM must meet all the required software and configuration dependencies. (For more information about the software packages that must be installed, see [Database Server VM Registration Pre-requirement Checks](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide:top-dbserver-pre-requirement-checks-c.html) and [Running the Pre-requisites Script (Linux)](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide:top-script-pre-requirement-linux-t.html)).

### Software Dependencies (Ubuntu)

Before you register an Ubuntu Database Server VM with NDB, ensure that the VM meets the following software dependencies. NDB uses firewalld to manage port dependencies and chrony for time synchronization in MySQL HA.

-   Install the firewalld utility using the default package manager.
    ```
    
    ```
    sudo apt-get install firewalld
    ```
    
    ```
    
-   Install the chrony utility for time synchronization.
    ```
    
    ```
    sudo apt-get install chrony
    ```
    
    ```
    
-   Stop and disable the UFW service.
    ```
    
    ```
    sudo systemctl stop ufw
    
    sudo systemctl disable ufw
    
    sudo ufw disable
    
    ```
    
    ```
    
-   Enable and start the firewalld service.
    ```
    
    ```
    sudo systemctl enable firewalld
    
    sudo systemctl start firewalld
    
    ```
    
    ```

### [Registering a PostgreSQL Database Server VM](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-PostgreSQL-Database-Management-Guide-v2_9:top-postgresql-database-server-register-t.html)

### Before you begin

Ensure that you meet the following requirements before you register a PostgreSQL database server VM with NDB. For general requirements, see [Database Server VM Registration Prerequisites](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-PostgreSQL-Database-Management-Guide-v2_9:top-opensource-db-server-registration-prereq-r.html).-   Register only one instance on the host.
-   Run the PostgreSQL processes.
-   Enable WAL logging.
-   Ensure that you have DBA level access to the databases you want to add.
-   Ensure that NDB service has access to TCP 5432 or a custom port.

Note: Registering an existing database server VM is only meant for creating software profiles for new provisioning use cases. If you need to migrate your database to Nutanix, it is recommended to provision a new database and database server VM with NDB to follow the best practices and then migrate your data (for example, ELT, backup, or restore) to the new database.

### About this task

Perform the following procedure to register a PostgreSQL database server VM:

### Procedure

1.  From the main menu, select Database Server VMs.
2.  Go to the List tab, click Register, and select the PostgreSQL engine. The Register Database Server VM window appears.
3.  Do the following in the indicated fields.  1.  Select the Nutanix cluster on which you want to register the database server VM.
          
          NDB multi-cluster must be enabled to select different Nutanix clusters. See [Nutanix Cluster Management](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide:top-multicluster-management-c.html) for more information.
          
      2.  IP Address or Name of VM. Type the IP address or name of the database server VM.
      3.  Description. Enter a description for the database server VM.
      4.  Update in Nutanix Cluster. Select this checkbox to update the description of the VM in the Nutanix cluster.
      5.  NDB Drive User. Type the username of the NDB drive user account that has sudo access.
      6.  PG Home. Type the path to the PostgreSQL home directory in which the PostgreSQL software is installed.
      7.  Provide Credentials Through. Select Password or Private Key from the dropdown list.
      8.  If you selected Password in the previous step, in thePassword field, type the password of the NDB drive user account.
      9.  If you selected Private Key in the previous step, select one of the following:    -   File. Upload a file that includes the private key.
              13.   Text. Type or copy and paste the private key.
          
      10.  Database Operating System User. Enter the name of the pre-created database server VM operating system user that will run the database in the VM.
          
          You cannot change the database operating system user after the registration is complete.
    
4.  Under Additional Configurations, do the following in the indicated fields:  1.  Operating System Patching. Select this option if you want NDB to perform OS patching automatically. As part of the procedure, the underlying OS gets updated with the latest patch available in the local repository.
      2.  Database Patching. Select this option if you want NDB to perform database patching automatically.
      3.  Maintenance Window. Associate an existing maintenance window schedule. NDB starts OS patching or database patching as per the schedule defined in the maintenance window.
    
    Note: You must have at least one maintenance window configured to enable automated patching. Automated patching in database provisioning and registration workflows is disabled if:
    
      27.   No maintenance window schedules are available.
      28.   Database registration or provisioning is performed on an existing database server VM.
    
5.  (Optional) Under Advanced Options, Expand Pre-Post Commands and do the following:  1.  Pre Operating System Patching Command: Type a complete OS command to run before patching the OS.
      2.  Post Operating System Patching Command: Type a complete OS command to run after patching the OS.
    
6.  (Optional) Expand Operating System Patching Custom Commands and do the following:  1.  Operating System Patching Command: Enter a custom patch command. This can be calling a script located in the database server VM(s) or a specific command that the VM can run directly.
      2.  Rollback Command: Enter a custom rollback command to undo any changes if the OS patching operation fails to apply the patches correctly.
      3.  Under Reboot Needed, select either of the following:
          
              5.   Yes, I want NDB to Reboot VMs: Select this option to reboot the database server VM(s) at the end of the patching operation.
              6.   No, I don't want NDB to Reboot VMs: Select this option to not reboot the database server VM(s) at the end of the patching operation.
    
7.  Click Register to register the database server VM.
    
    A message appears indicating that the operation to register a database server VM has started. Click the message to monitor the progress of the operation. Alternatively, select Operations in the drop-down list of the main menu to monitor the progress of the operation.
    
    After the registration operation is completed, the database server VM appears in the list of the registered database server VMs. Click the name of the database server VM to open the homepage for the selected database server VM. This page displays the following widgets:
    
      46.   Database Server VM Summary. Displays the name, time zone, status, date of registration, and version of the database server VM.
          
      48.   Alerts. Displays the alert messages, the number of occurrences, and the last occurred time of the alerts.
      49.   Profiles. Displays the software, compute, and network profiles that were applied when the database server VM was created. You can click the hyperlinks to view further details of each profile.
          
      51.   Node. Displays the IP address, operating system type, and status of the database server VM. Click Open to open the homepage in Prism for the respective database server VM. Click See Description to view the steps to connect to the database server VM using SSH.
          
      53.   Databases. Displays a list of the databases that are registered with the respective database server VM. You can view the name, associated time machine, status, type, and size of the database.
          
      55.   Network Interfaces. Displays a list of the databases that are registered with the respective database server VM. You can view the name, associated time machine, status, type, and size of the database.
          
      57.   Resource Capacity and Usage. Displays CPU, memory, and storage usage for the database server VM.
          
      59.   Tags. Displays a list of the tags that are applied to this database server VM. Click Update to set the tag values.

### [PostgreSQL Database Registration](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-PostgreSQL-Database-Management-Guide-v2_9:top-database-registration-postgresql-c.html)

You can register a source (production) database running on a Nutanix cluster with NDB. When you register a database with NDB, the database server VM(VM that hosts the source database) is also registered with NDB. After you have registered a database with NDB, a time machine is created for that database.

The time machine takes periodic database snapshots and log catch-ups (see [NDB Time Machine Management](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide:top-time-machine-management-c.html)). The time machine performs the snapshot and log catch-up operations as defined in the SLA that you have selected or created during the registration of the database (see [SLA Management](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide:top-sla-management-c.html)).

### [PostgreSQL Database Registration Prerequisites](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-PostgreSQL-Database-Management-Guide-v2_9:top-postgresql-db-registration-prerequisite-r.html)

Ensure that you meet the following requirements before you start registering a database.

### General

-   NDB supports registering databases on VMs that are a part of an existing Nutanix Protection Domain (PD): all the entities associated with or attached to the VM must be protected. For example, if there is a volume group (VG) attached to the database server VM, then the existing PD must protect both the VG and VM, not only the VG.
-   Before you register a database running on ESXi cluster, you must set disk.EnableUUID to True by using vCenter Server.  1.  Shut down the database server VM on which the database is running.
      2.  Select the database server VM, go to VM > Actions > Edit Settings > VM Options > Advanced > Configuration Parameters > Edit Configuration, and click Add Row.
      3.  In the Name field, type disk.EnableUUID.
      4.  In the Value field, type True.
      5.  Start the database server VM.

### OS Configuration (Linux)

-   SUDO NOPASS access is required.
-   (Optional) Invoke restricted sudo access by configuring a sudoers file for one or more database server VMs. Content of the sudoers file are as follows:
    ```
    
    ```
    user ALL=(ALL) NOPASSWD:SETENV: /opt/era_base/era_priv_cmd.sh,/home/user/era_priv_cmd.sh,/sbin/su - postgres
    user ALL=(postgres:postgres) NOPASSWD:ALL
    ```
    
    ```
    
    Where 
    ```
    user
    ```
     indicates the sudo user and 
    ```
    /home/user
    ```
     indicates the sudo user home directory. Replace 
    ```
    postgres
    ```
     with the name of the database OS user, if configured.
    
-   If you are using software profiles with restricted sudo access, add the following rule for the 'etcd' user in the visudo file:
    ```
    
    ```
    era ALL=(etcd:etcd) NOPASSWD:ALL
    ```
    
    ```
    
-   Configure binary paths as secure\_paths in the etc/sudoers file.
-   Ensure that the /etc/sudoers file includes the following line under defaults:
    ```
    
    ```
    secure_path = /sbin:/bin:/usr/sbin:/usr/bin
    ```
    
    ```
    
-   Linux OS root user account equivalent access, via non-root OS user account, is required via sudo. Linux OS root user access is not required.
-   Install and configure crontab.
-   Install OS and database software on separate disks. does not support OS and database software on the same disk or on different partitions on the same disk.
-   While preparing the PostgreSQL database for registration with , you must place the PostgreSQL database data and database log files on separate disks and not on the disks used for the operating system or PostgreSQL binary installation. This means a separate mount point must exist for the data and log files within the database server VM. This is only applicable when you register a database server VM with a database. If you want to register a database server VM only, you do not require data and log file disks. However, ensure that you have the operating system and binary installation on separate disks (and mount points).
-   Ensure that Prism APIs are callable from the VM.
-   /tmp folder must have read and write permissions.
-   The /tmp and /var/tmp folders can have the noexec parameter set in /etc/fstab if the PostgreSQL instance or PostgreSQL HA dependencies like Patroni, etcd, Keepalived, and HAPproxy are not configured to use these locations for any executable.
-   Disable requiretty setting on the source database to register the database.

### [Registering a PostgreSQL Instance](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-PostgreSQL-Database-Management-Guide-v2_9:top-postgresql-database-register-t.html)

### Before you begin

Ensure that you meet the following requirements before you register a PostgreSQL instance with NDB. For general requirements, see [Database Registration Prerequisites](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide:top-opensource-db-registration-prereq-r.html).-   Register only one instance on the host.
-   Run the PostgreSQL processes.
-   Enable write-ahead logging (WAL).
-   DBA level access is required for the databases that you want to add.
-   Ensure that NDB service has access to TCP 5432 or a custom port.
-   Ensure that the default 'postgres' database is present in the PostgresSQL instance. This database is used to connect to PostgreSQL database server during NDB operations, therefore you should not delete it.

Note: Registering an existing database server VM is only meant for creating software profiles for new provisioning use cases. If you need to migrate your database to Nutanix, it is recommended to provision a new database and database server VM with NDB to follow the best practices and then migrate your data (for example, ELT, backup, or restore) to the new database.

### About this task

Perform the following procedure to register a PostgreSQL instance.

### Procedure

1.  From the main menu, select Settings.
2.  Go to Migration > Register with NDB and select the PostgreSQL engine.
    
    The Register a PostgreSQL Instance window appears.
    
3.  In the Database Server VM section, select one the following.  -   Registered. Select this option if you want to register an instance running on a database server VM that is already registered with NDB.
          
          Automated patching is not allowed for a database server VM that is already registered with NDB.
          
      10.   Not Registered. Select this option if the database server VM on which the instance you want to register is not registered with NDB.
    
4.  If you selected Registered in the previous step, select the database server VM on which the instance you want to register is running, and click Next.
    
    If you have associated a tag with a database server VM, click the search bar and select the tag. This step displays the database server VMs that are associated with the selected tag.
    
5.  If you selected Not Registered in the previous step, do the following in the indicated fields.  1.  Select the Nutanix cluster on which you want to register the instance.
          
          NDB multi-cluster must be enabled to select different Nutanix clusters. See [Nutanix Cluster Management](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide:top-multicluster-management-c.html) for more information.
          
      2.  IP Address or Name of VM. Type the IP address or name of the database server VM on which the instance you want to register is running.
      3.  Description. Type a description for the database server VM.
      4.  NDB Drive User. Type the username of the NDB drive user account that has sudo access.
      5.  PG Home. Type the path to the PostgreSQL home directory in which the PostgreSQL software is installed.
          
          For example, if your pg\_ctl binary is located in /usr/pgsql-10/bin folder, then PG Home is /usr/pgsql-10/.
          
          Following are the default PG Home paths for different PostgreSQL versions.
          
              14.   /usr/pgsql-10/ for PostgreSQL 10.
              15.   /usr/pgsql-11/ for PostgreSQL 11.
              16.   /usr/pgsql-12/ for PostgreSQL 12.
              17.   /usr/pgsql-13/ for PostgreSQL 13.
              18.   /usr/pgsql-14/ for PostgreSQL 14.
              19.   /usr/pgsql-15/ for PostgreSQL 15.
          
      6.  Provide Credentials Through. Select Password or Private Key from the drop-down list.
      7.  If you selected Password in the previous step, in the Password field, type the password of the NDB drive user account.
      8.  If you selected Private Key in the previous step, select one of the following:    -   File. Upload a file that includes the private key.
              24.   Text. Type or copy and paste the private key.
          
      9.  Database Operating System User. Enter the name of the pre-created database server VM operating system user that runs the database in the VM.
          
          You cannot change the database operating system user after the registration is complete.
          
      10.  Click Next.
    
6.  Under Instance, do the following in the indicated fields.  1.  Instance Name in NDB. Type a name for the instance that you want to be displayed in NDB.
      2.  Description. Type a description for the instance.
      3.  Port. This field is populated with the default port number of a PostgreSQL instance.
      4.  Database User. Enter the name of the pre-existing database user with superuser privileges that facilitates connection to the database. You cannot change the database user once defined.
      5.  Database User Password. Type the password for the database user.
      6.  Name of a Database on the Instance. Type the name of a database on the instance you want to register.
          
          NDB will discover and register all the databases found on the instance at the port provided.
          
      7.  Click Next.
    
7.  Under Time Machine, do the following in the indicated fields.  1.  Name. Type a name for the time machine.
      2.  Description. Type a description for the time machine.
      3.  SLA. Select an SLA from the drop-down list. An SLA is a snapshot retention policy that indicates how long snapshots are retained in NDB. For more information, see [SLA Management](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide:top-sla-management-c.html).
    
8.  Under Schedule, specify a schedule to take and retain the snapshots. Do the following in the indicated fields.  1.  Initial Daily Snapshot at. The snapshot taken at this time everyday is retained as a daily snapshot in NDB.
      2.  Snapshots Per Day. Type the number of snapshots you want NDB to take everyday.
      3.  Log Catch Up Every. Select the frequency of log catch-ups in minutes. The log catch-up operation copies transaction logs to NDB from your source database.
      4.  Weekly Snapshot on. The snapshot taken on this day of every week is retained as a weekly snapshot in NDB.
      5.  Monthly Snapshot on the. The snapshot taken on this day of every month is retained as a monthly snapshot in NDB.
      6.  Quarterly Snapshot on the. The snapshot taken on the first day of the first month of the quarter is retained as a quarterly snapshot in NDB. For example, if you select Jan, Apr, Jul, Oct from the drop-down list, snapshots taken on January 1, April 1, July 1, and October 1 are retained as quarterly snapshots.
      7.  Click Next.
    
9.  Under Additional Configurations, do the following in the indicated fields:  1.  Operating System Patching. Select this option if you want NDB to perform OS patching automatically. As part of the procedure, the underlying OS gets updated with the latest patch available in the local repository.
      2.  Database Patching. Select this option if you want NDB to perform database patching automatically.
      3.  Maintenance Window. Associate an existing maintenance window schedule. NDB starts OS patching or database patching as per the schedule defined in the maintenance window.
    
    Note: You must have at least one maintenance window configured to enable automated patching. Automated patching in database provisioning and registration workflows is disabled if:
    
      76.   No maintenance window schedules are available.
      77.   Database registration or provisioning is performed on an existing database server VM.
    
10.  (Optional) Under Advanced Options, Expand Pre-Post Commands and do the following:  1.  Pre Operating System Patching Command: Type a complete OS command to run before patching the OS.
      2.  Post Operating System Patching Command: Type a complete OS command to run after patching the OS.
    
11.  (Optional) Expand Operating System Patching Custom Commands and do the following:  1.  Operating System Patching Command: Enter a custom patch command. This can be calling a script located in the database server VM(s) or a specific command that the VM can run directly.
      2.  Rollback Command: Enter a custom rollback command to undo any changes if the OS patching operation fails to apply the patches correctly.
      3.  Under Reboot Needed, select either of the following:
          
              5.   Yes, I want NDB to Reboot VMs: Select this option to reboot the database server VM(s) at the end of the patching operation.
              6.   No, I don't want NDB to Reboot VMs: Select this option to not reboot the database server VM(s) at the end of the patching operation.
    
12.  In the Tags step, click each tag and type a tag value. You can hover over the info icon to view the details of each tag.
    
    The Tags window is displayed when a database server VM, database, or time machine is associated with a tag.
    
13.  Click Register to start the registration operation.
    
    A message appears indicating that the operation to register an instance has started. Click the message to monitor the progress of the operation. Alternatively, select Operations in the drop-down list of the main menu to monitor the progress of the operation.
    
    After the registration operation is completed, the instance appears in the list of the registered database. Click the name of the instance to open the homepage for the selected instance. This page displays the following widgets:
    
      99.   PostgreSQL Instance Summary. Displays a brief summary of the instance that includes the name, description, status, and version.
          
      101.   Alerts. Displays the alert messages, the number of occurrences, and the last occurred time of the alerts.
      102.   Time Machine. Displays the name, description, age, and size of the time machine.
          
      104.   Databases. Displays the list of databases in the instance. Click See Description to view details on accessing the respective database.
          
      106.   Profiles. Displays the software, compute, and network profiles that were applied when the database was created. You can click the hyperlinks to view further details of each profile.
          
      108.   Database Server VM. Displays the name, time zone, status, date of registration, and version of the database server VM.
          
      110.   Tags. Displays a list of the tags that are applied to this database server VM. Click Update to set the tag values.

### [PostgreSQL Database Server VM Provisioning](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-PostgreSQL-Database-Management-Guide-v2_9:top-postgresql-db-server-vm-provision-c.html)

You can provision database server VMs and databases on the Nutanix cluster. As part of the database provisioning process, you can either create a database server VM on which you provision the database or select a database server VM that you have already provisioned.

### [Database Server VM Provisioning Prerequisites](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-PostgreSQL-Database-Management-Guide-v2_9:top-postgresql-db-provision-prerequisite-r.html)

Before provisioning a PostgreSQL database server VM, ensure that you complete the following tasks.

-   Create a software profile.
-   Create a network profile. If a network profile exists, you can use the existing profile. Otherwise, create a network profile.
-   Create a compute profile. A sample compute profile is available. If you do not want to use the sample profile, you can create a compute profile.
-   Generate an SSH key for database provisioning on Linux-based operating systems.

### [Provisioning a PostgreSQL Database Server VM](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-PostgreSQL-Database-Management-Guide-v2_9:top-database-server-vm-postgresql-provision-t.html)

### Before you begin

Ensure that you have completed the tasks listed in [Database Server VM Provisioning Prerequisites](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-PostgreSQL-Database-Management-Guide-v2_9:top-postgresql-db-provision-prerequisite-r.html).

### About this task

Perform the following procedure to provision a database server VM.

Note: NDB does not allow you to use the profiles and profile versions (unpublished) created by another user while provisioning a database server VM.

### Procedure

1.  From the main menu, select Database Server VMs.
2.  Go to List.
    
    This page displays a list of database server VMs that are provisioned in NDB.
    
3.  Click Provision, and select the PostgreSQL engine. The Provision Database Server VM window appears.
4.  Under Source, do the following:  -   Software Profile. Select this option if you want to provision a database server VM from an existing software profile. Select a software profile from the list.
      8.   Time Machine. Select this option if you want to provision a database server VM by using the database and operating system software stored in a time machine. Select a time machine from the list.
    
    If you selected the Software Profile option, you can update the software profile version by clicking Update Version to view all the versions available for the selected profile. Select the required version from the list and click Update.
    
5.  Select the Nutanix cluster on which you want to provision the database server VM and click Next.
    
    Note: NDB multi-cluster must be enabled to select different Nutanix clusters. See [Nutanix Cluster Management](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide:top-multicluster-management-c.html) for more information.
    
6.  Under Database Server VM, do the following in the indicated fields.  1.  Database Server VM Name. Type a name for the database server VM.
      2.  Description. Type a description for the database server VM.
      3.  Compute Profile. Select a compute profile from the drop-down list of the compute profiles available.
      4.  Network Profile. Select a network profile from the list of network profiles available.
      5.  NDB Drive User. Displays the username of the NDB drive user account that has sudo access.
      6.  Update Password (Optional). Type the password of the NDB drive user account.
      7.  SSH Public Key (Optional). Do one of the following to use SSH public keys to access the database server VM:    -   File. Upload a file that includes the public key.
              8.   Text. Type or copy and paste the public key.
          
      8.  Database OS User. Verify the name of the database OS user defined during database server VM registration. NDB fetches this username from the software profile you selected.
    
7.  Under Additional Configurations, do the following in the indicated fields for Automated Patching and Maintenance:  1.  Operating System Patching: Select this option if you want NDB to perform OS patching automatically. As part of the procedure, the underlying OS gets updated with the latest patch available in the local repository.
      2.  Database Patching: Select this option if you want NDB to perform database patching automatically.
      3.  Maintenance Window: Associate an existing maintenance window schedule. NDB starts OS patching or database patching as per the schedule defined in the maintenance window.
    
    Note: You must have at least one maintenance window configured to enable automated patching. Automated patching in database provisioning and registration workflows is disabled if:
    
      33.   No maintenance window schedules are available.
      34.   Database registration or provisioning is performed on an existing database server VM.
    
8.  (Optional) Under Advanced Options, Expand Pre-Post Commands and do the following:  1.  Pre Operating System Patching Command: Type a complete OS command to run before patching the OS.
      2.  Post Operating System Patching Command: Type a complete OS command to run after patching the OS.
    
9.  (Optional) Expand Operating System Patching Custom Commands and do the following:  1.  Operating System Patching Command: Enter a custom patch command. This can be calling a script located in the database server VM(s) or a specific command that the VM can run directly.
      2.  Rollback Command: Enter a custom rollback command to undo any changes if the OS patching operation fails to apply the patches correctly.
      3.  Under Reboot Needed, select either of the following:
          
              5.   Yes, I want NDB to Reboot VMs: Select this option to reboot the database server VM(s) at the end of the patching operation.
              6.   No, I don't want NDB to Reboot VMs: Select this option to not reboot the database server VM(s) at the end of the patching operation.
    
    Note:
    
      48.   Nutanix does not recommend rebooting the VMs through the OS patching command or the rollback command.
      49.   Specify absolute paths for the pre-patching, post-patching, custom OS patching, and rollback commands.
    
10.  Click Provision to provision the database server VM.
    
    A message indicating that the operation to provision a database server VM has started is displayed. Click the message to monitor the progress of the operation. Alternatively, select Operations in the drop-down list of the main menu to monitor the progress of the operation.
    
    After the provisioning operation is completed, the database server VM appears in the list of the provisioned database server VMs. Click the name of the database server VM to open the homepage for the selected database server VM. This page displays the following widgets:
    
      57.   Database Server VM Summary. Displays the name, time zone, status, date of registration, the database OS user, and version of the database server VM.
          
      59.   Alerts. Displays the alert messages, the number of occurrences, and the last occurred time of the alerts.
      60.   Profiles. Displays the software, compute, and network profiles that were applied when the database server VM was created. You can click the hyperlinks to view further details of each profile.
          
      62.   Node. Displays the IP address, operating system type, and status of the database server VM. Click Open to open the homepage in Prism for the respective database server VM. Click See Description to view the steps to connect to the database server VM using SSH.
          
      64.   Databases. Displays a list of the databases that are registered with the respective database server VM. You can view the name, associated time machine, status, type, and size of the database.
          
      66.   Network Interfaces. Displays a list of the databases that are registered with the respective database server VM. You can view the name, associated time machine, status, type, and size of the database.
          
      68.   Resource Capacity and Usage. Displays CPU, memory, and storage usage for the database server VM.
          
      70.   Tags. Displays a list of the tags that are applied to this database server VM. Click Update to set the tag values.

### [PostgreSQL Database Provisioning](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-PostgreSQL-Database-Management-Guide-v2_9:top-postgresql-database-provision-c.html)

You can provision database server VMs and databases on the Nutanix cluster. As part of the database provisioning process, you can either create a database server VM on which you provision the database or select a database server VM that you have already provisioned.

You use the built-in database parameter profiles or profiles you created to provision the databases.

You can provision both a PostgreSQL instance and a PostgreSQL HA instance. With NDB multi-cluster, both the PostgreSQL instance and the HA instance can be provisioned across different Nutanix clusters.

NDB allows you to assign different compute profiles to the database server VMs and HA Proxy VMs during a PostgreSQL HA cluster provisioning operation. This helps in saving memory and vCPU that are assigned to HAProxy VMs.

However, all database server VMs in an HA deployment must use the same compute profile.

### Software Required for PostgreSQL HA Provisioning

 Software | Supported Versions | Description |
| --- | --- | --- |
 etcd | etcd versions 3.3.11, 3.4.20, and 3.2.26 | etcd is a fault-tolerant, open source, distributed key-value store that is used to store the state of the PostgreSQL cluster. Through Patroni, all the PostgreSQL nodes use etcd as a distributed configuration store to maintain the state of the PostgreSQL cluster. Patroni uses etcd for primary election and storing the PostgreSQL configuration parameters.
For more information about etcd, see etcd Documentation.

 |
 Patroni | Patroni versions 1.5.6, 1.6.x, 2.0.2, 2.1.1, and 2.1.4, and 3.2.2 | Patroni is an open source Python package that manages PostgreSQL configuration. Patroni manages the state of the cluster and handles the failover of the primary node to replicas when needed.

Note: For PostgreSQL HA systems, NDB configures the Linux softdog module to reboot the system if Patroni is unresponsive for 60 seconds.

For more information about Patroni, see Patroni Documentation.

 |
 HAProxy | HAProxy versions 1.8.19, 1.8.20, 1.8.27, 2.0.29, and 2.8.9. | HAProxy is free, open source software that provides a High Availability load balancer and proxy server for TCP and HTTP-based applications that spread requests across multiple servers. HAProxy is used to direct the traffic to the appropriate node. Based on the port number provided by you, HAProxy redirects the traffic either to primary or replica node. If a read/write port is selected, the traffic goes to the primary. Otherwise, traffic is randomly distributed within the replica nodes.

For more information about HAProxy, see HAProxy Documentation.

 |
 Keepalived | Keepalived versions 1.3.5, 2.0.10, 2.0.19, and 2.1.5. | Keepalived uses a virtual IP address to provide the single end point of the cluster. Initially, Keepalived assigns the virtual IP address to HAProxy node 1 and then, based on the port selected, HAProxy redirects traffic to either primary or asynchronous replica nodes. In the event that HAProxy node 1 fails, Keepalived reassigns the virtual IP address to HAProxy node 2. At a given time, a virtual IP address is bound to only one HAProxy node if the node is up and running.

If you select the HAProxy configuration during the provision workflow on RHEL 9.x or Rocky Linux 9.x, the HA provisioning fails with the following error:

```

```
Failed to configure keepalived
```

```

To prevent this failure, install the 
```
iptables-nft-services
```
 package in the gold VM before you start the provisioning process.

For more information about Keepalived, see Keepalived Documentation.

 |

Note:

-   If you enable services such as etcd, HAProxy, Patroni, and Keepalived, and create a software profile version from the same VM, you might observe issues in provisioning or the functionalities of PostgreSQL HA service while using the software profile.
    
    Follow the steps below to avoid any potential issues later while trying to use the software profile created from any of PostgreSQL clustered database server VMs as source VM:
    
      -   Disable Patroni, etcd, Keepalived, and HAProxy services (if enabled):
          
          Command to disable a service: sudo systemctl disable <service\_name>
          
          For example:
          
          ```
          
          ```
          sudo systemctl disable patroni
          ```
          
          ```
          
      -   Create a software profile from NDB.
    
    During the provisioning process, NDB has checks in place to ensure the necessary services (etcd, HAProxy, Patroni, and Keepalived) are enabled and start with the proper parameters (only in the VMs where the services are required). If the services are already operating under an outdated configuration, NDB's new configuration modifications do not take effect, and the PostgreSQL HA service's functions may be affected.
    
-   For more information about the supported OS versions and the corresponding Patroni, etcd, HAProxy, and Keepalived versions, see [PostgreSQL Software Compatibility and Feature Support](https://portal.nutanix.com/page/documents/details?targetId=Release-Notes-Nutanix-NDB-v2_5_2:v25-ndb-compatibility-postgresql-2_5_2-r.html).

### [Provisioning a PostgreSQL Instance](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-PostgreSQL-Database-Management-Guide-v2_9:top-postgresql-database-provision-t.html)

### Before you begin

-   Ensure that you create a software profile if you do not want to use the built-in software profile. For more information, see [Creating a Software Profile](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-PostgreSQL-Database-Management-Guide:top-software-profile-postgresql-create-t.html).

### About this task

Perform the following procedure to provision a PostgreSQL instance.

Note: NDB does not allow you to use the profiles and profile versions (unpublished) created by another user while provisioning a database server VM.

### Procedure

1.  From the main menu, select Databases.
2.  Go to Sources, click Provision, and select Instance under the PostgreSQL engine. The Provision a PostgreSQL Instance window appears.
3.  Under Database Server VM, select one of the following:  -   Create New Server. Select this option if you want to provision an instance on a new database server VM.
      4.   Use Registered Server. Select this option if you want to provision an instance on a database server VM that you have previously registered with NDB.
    
4.  If you selected Use Registered Server, select the database server VM on which you want to provision the instance and click Next.
5.  If you selected Create New Server, do the following under New Database Server VM.  1.  Database Server VM Name. Type a name for the database server VM.
          
          The name that you provide in this field is used as the VM name created for the PostgreSQL instance.
          
      2.  Description. Type a description for the database server VM.
      3.  Select the Nutanix cluster on which you want to provision the instance.
          
          NDB multi-cluster must be enabled to select different Nutanix clusters. See [Nutanix Cluster Management](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide:top-multicluster-management-c.html) for more information.
          
      4.  Software Profile. Select a software profile from the drop-down list of the software profiles available.
          
          If you want to update the version of the profile selected, click Update Version to view all the versions available for the selected profile. Select the required version from the list and click Update.
          
          The software profiles appears in this list only if you have created or replicated the profile on the selected Nutanix cluster. See [Updating Profiles](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide:top-profile-availability-update-t.html) for more information.
          
      5.  Compute Profile. Select a compute profile from the drop-down list of compute profiles available.
      6.  Network Profile. Select a network profile from the drop-down list of network profiles available.
      7.  IP Address. Select an IP address for the database server VM.
          
          This option is only enabled if the selected network profile has the IP address selection option enabled.
          
      8.  NDB Drive User. Enter the name of the NDB drive user.
      9.  Update Password (Optional). Enter the password for NDB drive user.
      10.  SSH Public Key (Optional). Do one of the following to use SSH public keys to access the database server:    -   File. Upload a file that includes the public key.
              25.   Text. Type or copy and paste the public key.
          
      11.  Database Operating System User. Verify the name of the database OS user defined during database server VM registration. This username is fetched from the software profile you selected.
      12.  Click Next.
    
6.  Under Instance, do the following in the indicated fields:  1.  PostgreSQL Instance Name. Type a name for the instance.
      2.  Description. Type a description for the instance.
      3.  Listener Port. By default, this field is populated with the port number 5432 of a PostgreSQL instance.
      4.  Size (GB). Type the size of the node in GB.
      5.  Name of Initial Database. Type the name of the initial database that is created in the PostgreSQL instance.
      6.  Database Parameter Profile - Database. Select a database parameter profile from the dropdown list.
      7.  Database User. Enter the name of the database user with superuser privileges that facilitates connection to the database. You cannot change the database user once defined.
      8.  Database User Password. Type the password for the database user.
      9.  Click Pre-Post Commands and do the following in the indicated fields:
          
              11.   Pre-Create Command. Type a complete OS command that you want to run before the instance is created.
              12.   Post-Create Command. Type a complete OS command that you want to run after the instance is created.
          
      10.  Click Next.
    
7.  Under Time Machine, do the following in the indicated fields.  1.  Name. Type a name for the time machine.
      2.  Description. Type a description for the time machine.
      3.  SLA. Select an SLA from the drop-down list.
          
          An SLA is a snapshot retention policy that indicates how long snapshots are retained in NDB. For more information, see [SLA Management](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide:top-sla-management-c.html).
    
8.  Under Schedule, specify a schedule to take and retain the snapshots. Do the following in the indicated fields.  1.  Initial Daily Snapshot at. The snapshot taken at this time everyday is retained as a daily snapshot in NDB.
      2.  Snapshots Per Day. Type the number of snapshots you want Nutanix to take everyday.
      3.  Log Catch Up Every. Select the frequency of log catch-ups in minutes. The log catch-up operation copies transaction logs to NDB from your source database.
      4.  Weekly Snapshot on. The snapshot taken on this day of every week is retained as a weekly snapshot in NDB.
      5.  Monthly Snapshot on the. The snapshot taken on this day of every month is retained as a monthly snapshot in NDB.
      6.  Quarterly Snapshot in. The snapshot taken on the first day of the first month of the quarter is retained as a quarterly snapshot in NDB.
          
          For example, if you select Jan, Apr, Jul, Oct from the drop-down list, snapshots taken on January 1, April 1, July 1, and October 1 are retained as quarterly snapshots.
          
      7.  Click Next to proceed to the Automated Patching (Optional) step.
    
9.  Under Additional Configurations, do the following in the Encryption section:  1.  Enable Encryption: Select this checkbox if you intend to enable encryption for PostgreSQL.
      2.  Third party Encryption by CipherTrust Encryption (CTE): Click this button if you intend to enable Thales Group CTE.
          
          This step only sets the intent to encrypt the database. After provisioning the database, NDB reminds you to perform the remaining steps to complete the encryption. For more information, see [Enabling Encryption for PostgreSQL Databases](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide:top-db-encryption-cte-provision-t.html).
    
10.  Under Automated Patching and Maintenance, do the following:  1.  Operating System Patching. Select this option if you want NDB to perform OS patching automatically. As part of the procedure, the underlying OS gets updated with the latest patch available in the local repository.
      2.  Database Patching. Select this option if you want NDB to perform database patching automatically.
      3.  Maintenance Window. Associate an existing maintenance window schedule. NDB starts OS patching or database patching as per the schedule defined in the maintenance window.
    
    Note: You must have at least one maintenance window configured to enable automated patching. Automated patching in database provisioning and registration workflows is disabled if:
    
      79.   No maintenance window schedules are available.
      80.   Database registration or provisioning is performed on an existing database server VM.
    
11.  (Optional) Under Advanced Options, Expand Pre-Post Commands and do the following:  1.  Pre Operating System Patching Command: Type a complete OS command to run before patching the OS.
      2.  Post Operating System Patching Command: Type a complete OS command to run after patching the OS.
    
12.  (Optional) Expand Operating System Patching Custom Commands and do the following:  1.  Operating System Patching Command: Enter a custom patch command. This can be calling a script located in the database server VM(s) or a specific command that the VM can run directly.
      2.  Rollback Command: Enter a custom rollback command to undo any changes if the OS patching operation fails to apply the patches correctly.
      3.  Under Reboot Needed, select either of the following:
          
              5.   Yes, I want NDB to Reboot VMs: Select this option to reboot the database server VM(s) at the end of the patching operation.
              6.   No, I don't want NDB to Reboot VMs: Select this option to not reboot the database server VM(s) at the end of the patching operation.
    
13.  In the Tags step, click each tag and type a tag value. You can hover over the info icon to view the details of each tag.
    
    The Tags window is displayed when a database server VM, database, or time machine is associated with a tag.
    
14.  Click Provision to start the provisioning operation.
    
    A message indicating that the operation to provision an instance has started is displayed. Click the message to monitor the progress of the operation. Alternatively, select Operations in the drop-down list of the main menu to monitor the progress of the operation.
    
    After the provisioning operation is completed, the instance appears in the list of the provisioned database. The PostgreSQL data directory location can be obtained by checking the PGDATA environment variable inside the PostgreSQL OS user bash profile.
    
    Click the name of the instance to open the homepage for the selected instance. This page displays the following widgets:
    
      104.   PostgreSQL Instance Summary. Displays a brief summary of the instance that includes the name, description, status, database user, and version.
          
      106.   Alerts. Displays the alert messages, the number of occurrences, and the last occurred time of the alerts.
      107.   Time Machine. Displays the name, description, age, and size of the time machine.
          
      109.   Databases. Displays the list of databases in the instance. Click See Description to view details on accessing the respective database.
          
      111.   Profiles. Displays the software, compute, and network profiles that were applied when the database was created. You can click the hyperlinks to view further details of each profile.
          
      113.   Database Server VM. Displays the name, time zone, status, date of registration, and version of the database server VM.
          
      115.   Tags. Displays a list of the tags that are applied to this database server VM. Click Update to set the tag values.

### [Provisioning a PostgreSQL HA Instance](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-PostgreSQL-Database-Management-Guide-v2_9:top-postgresql-cluster-database-provision-t.html)

### Before you begin

Ensure the following before you provision a PostgreSQL HA instance:-   For more information on the software required for HA instance provisioning, see [PostgreSQL Database Provisioning](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-PostgreSQL-Database-Management-Guide:top-postgresql-database-provision-c.html).
-   Ensure that you have the appropriate Patroni version installed. For more information on the supported Patroni versions, see NDB release notes.
-   To create your own profile on the operating system of your choice, contact Nutanix support.

### About this task

Perform the following procedure to provision a PostgreSQL HA instance.

Note: NDB does not allow you to use the profiles and profile versions (unpublished) created by another user while provisioning a database server VM.

### Procedure

1.  From the main menu, select Databases.
2.  Go to Sources, click Provision, and select HA Instance under the PostgreSQL engine.
    
    The Provision a PostgreSQL HA Instance window appears.
    
3.  Under Server Cluster, do the following in the indicated fields.  1.  Server Cluster Name. Type a name for the server cluster.
          
          The server cluster is a set of all VMs which make up the PostgreSQL HA instance. It includes the PostgreSQL database VMs and the HAProxy VMs if provisioned.
          
      2.  Description. Type a description for the server cluster.
      3.  Select the Nutanix clusters on which the server cluster is hosted.
          
          Note: NDB multi-cluster must be enabled to select different Nutanix clusters. See [Nutanix Cluster Management](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide:top-multicluster-management-c.html) for more information.
          
      4.  Network Profile. Select a network profile from the drop-down list of network profiles available. The network profile displayed is based on the Nutanix clusters selected in the previous step.
      5.  Manually select IP addresses. Select this option to manually provide different IP addresses for the database server VMs and HAProxy VMs in the upcoming step.
          
          Note: This option is only displayed if the selected network profile has the IP address selection option enabled.
          
      6.  Click Next.
    
4.  Under Database Server VM, do the following in the indicated fields.  1.  Under Attributes of All Database Server VMs, do the following in the indicated fields:
          
              3.   Software Profile. Select POSTGRES\_10.4\_HA\_ENABLED\_OOB as the software profile.
                  
                  If you want to update the version of the profile selected, click Update Version to view all the versions available for the selected profile. Select the required version from the list and click Update.
                  
                  Note: The software profiles appears in this list only if you have created or replicated the profile on the selected Nutanix cluster. See [Updating Profiles](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide:top-profile-availability-update-t.html) for more information.
                  
              9.   Compute Profile. Select a compute profile from the drop-down list of compute profiles available.
              10.   Archive Log Destination (File Share). Type a path to a file share which can be used as an archive store for replication.
                  
                  The path must be of the following format: File\_Server:directory\_to\_be\_shared. Example: 1.2.3.4:/path/to/folder
                  
                  Note: If you do not provide a Archive Log Destination, NDB uses a volume group which is attached to one of the n-node PG VMs as the archive store for replication.
          
      2.  Under Credential Access, do the following in the indicated fields:
          
              18.   NDB Drive User. Enter the name of the NDB drive user.
              19.   Update Password (Optional). Enter the password for NDB drive user.
              20.   SSH Public Key (Optional). Do one of the following to use SSH public keys to access the database server:      -   File. Upload a file that includes the public key.
                        21.   Text. Type or copy and paste the public key.
                  
              23.   Database Operating System User. Verify the name of the database OS user defined during database server VM registration. NDB fetches this username from the software profile you selected.
          
      3.  Under Attributes of Individual Database Server VMs, do the following in the indicated fields:
          
              27.   Click Add to add a database server VM. You can select the cluster on which the database server VM must be added.
                  
                  Note: Three database server VMs are added by default.
                  
              31.   Click Remove to remove a database server VM.
              32.   Database server VM names are auto-populated based on the Server Cluster Name. You can type or edit the name prefix for the database server VM.
                  
                  You can also select the Nutanix cluster and IP address for the individual database server VMs. Note that this can be done only if the Manually select IP addresses option is enabled
          
      4.  Click Next.
    
5.  Under HA, do the following in the indicated fields.  1.  Name. Type a name for the Patroni cluster. Patroni uses this name to administer the Nutanix cluster.
      2.  Create HAProxy Servers. Select this check box if you want HA proxy to direct traffic to the primary node.
          
          If you have selected the static network profile, NDB provisions two HAProxy servers on new VMs. As a result, connections to the database are performed through the proxy with a floating IP address.
          
          If you have selected the DHCP-based network profile, NDB provisions one HAProxy server on a new VM. As a result, connections to the database are done through the VM IP address.
          
      3.  Read/Write Port. Enter a port number for read/write request. By default, NDB uses port number 5000.
      4.  Read Port. Enter a port number for read request. By default, NDB uses port number 5001. Connections to the port are directed to read replicas, if the read replicas are not available, then the connections are directed to the primary node.
      5.  Virtual IP Address. You can create a virtual IP address for the cluster if you choose to create the HAProxy servers on the same Nutanix cluster.
      6.  Select the Nutanix cluster and IP address for the individual HA proxy VMs. Note that this can be done only if the Manually select IP addresses option is enabled
      7.  Under Database Server VM Roles, select the database server VM and set the attributes for each database in the cluster. You can set the following attributes.
          
              14.   Primary. Select this check box if you want to set the selected node as primary.
                  
                  Note: One node must be selected as primary.
                  
              18.   Auto Failover. Select this check box to enable automatic failover on the selected node. If you enable this option and the primary node fails, it automatically fails over to the node that you have selected.
          
      8.  Enable Synchronous Replication. Select this option if you want to enable synchronous replication.
          
          Note:
          
              24.   NDB does not support provisioning more than one synchronous replica in a Highly Available instance.
              25.   If the Enable Synchronous Replication option is selected, synchronous replication is enabled on one of the nodes in the cluster so that the node is always in sync with the primary node.
          
      9.  Click Next.
    
6.  Under Instance, do the following in the indicated fields.  1.  PostgreSQL Instance Name. Type a name for the instance.
      2.  Description. Type a description for the instance.
      3.  Listener Port. By default, this field is populated with the port number 5432 of a PostgreSQL instance.
      4.  Size (GB). Type the size of the node in GB.
      5.  Name of Initial Database. Type the name of the initial database that is created in the PostgreSQL instance.
      6.  Database Parameter Profile - Database. Select a database parameter profile from the drop-down list of database parameter profiles available.
      7.  Database User. Enter the name of the database user with superuser privileges that facilitates connection to the database. You cannot change the database user once defined.
      8.  Database User Password. Type the password for the database user.
      9.  Click Pre-Post Commands and do the following in the indicated fields:
          
              11.   Pre-Create Command. Type a complete OS command that you want to run before the instance is created.
              12.   Post-Create Command. Type a complete OS command that you want to run after the instance is created.
          
      10.  Click Next.
    
7.  Under Time Machine, do the following in the indicated fields.  1.  Name. Type a name for the time machine.
      2.  Description. Type a description for the time machine.
      3.  SLA. Select an SLA from the drop-down list. An SLA is a snapshot retention policy that indicates how long snapshots are retained in NDB. For more information, see [SLA Management](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide:top-sla-management-c.html).
    
8.  Select the Nutanix clusters on which you want the logs/snapshots to be available.
9.  Under Schedule, specify a schedule to take and retain the snapshots. Do the following in the indicated fields.  1.  Initial Daily Snapshot at. The snapshot taken at this time everyday is retained as a daily snapshot in NDB.
      2.  Snapshots Per Day. Type the number of snapshots you want Nutanix to take everyday.
      3.  Log Catch Up Every. Select the frequency of log catch-ups in minutes. The log catch-up operation copies transaction logs to NDB from your source database.
      4.  Weekly Snapshot on. The snapshot taken on this day of every week is retained as a weekly snapshot in NDB.
      5.  Monthly Snapshot on the. The snapshot taken on this day of every month is retained as a monthly snapshot in NDB.
      6.  Quarterly Snapshot in. The snapshot taken on the first day of the first month of the quarter is retained as a quarterly snapshot in NDB.
          
          For example, if you select Jan, Apr, Jul, Oct from the drop-down list, snapshots taken on January 1, April 1, July 1, and October 1 are retained as quarterly snapshots.
          
      7.  Click Next to proceed to the Tags step.
    
10.  Under Additional Configurations, do the following in the Encryption section:  1.  Enable Encryption: Select this checkbox if you intend to enable encryption for PostgreSQL.
      2.  Third party Encryption by CipherTrust Encryption (CTE): Click this button if you intend to enable Thales Group CTE.
          
          Note: This step only sets the intent to encrypt the database. After provisioning the database, NDB reminds you to perform the remaining steps to complete the encryption. For more information, see [Enabling Encryption for PostgreSQL Databases](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide:top-db-encryption-cte-provision-t.html).
    
11.  Under Automated Patching and Maintenance, do the following:  1.  Operating System Patching. Select this option if you want NDB to perform OS patching automatically. As part of the procedure, the underlying OS gets updated with the latest patch available in the local repository.
      2.  Database Patching. Select this option if you want NDB to perform database patching automatically.
      3.  Maintenance Window. Associate an existing maintenance window schedule. NDB starts OS patching or database patching as per the schedule defined in the maintenance window.
    
    Note: You must have at least one maintenance window configured to enable automated patching. Automated patching in database provisioning and registration workflows is disabled if:
    
      129.   No maintenance window schedules are available.
      130.   Database registration or provisioning is performed on an existing database server VM.
    
12.  (Optional) Under Advanced Options, Expand Pre-Post Commands and do the following:  1.  Pre Operating System Patching Command: Type a complete OS command to run before patching the OS.
      2.  Post Operating System Patching Command: Type a complete OS command to run after patching the OS.
    
13.  (Optional) Expand Operating System Patching Custom Commands and do the following:  1.  Operating System Patching Command: Enter a custom patch command. This can be calling a script located in the database server VM(s) or a specific command that the VM can run directly.
      2.  Rollback Command: Enter a custom rollback command to undo any changes if the OS patching operation fails to apply the patches correctly.
      3.  Under Reboot Needed, select either of the following:
          
              5.   Yes, I want NDB to Reboot VMs: Select this option to reboot the database server VM(s) at the end of the patching operation.
              6.   No, I don't want NDB to Reboot VMs: Select this option to not reboot the database server VM(s) at the end of the patching operation.
    
14.  Under Tags, click each tag and type a tag value. You can hover over the info icon to view the details of each tag.
    
    Note: The Tags window is displayed when a database server VM, database, or time machine is associated with a tag.
    
15.  Click Provision to start the provisioning operation.
    
    A message indicating that the operation to provision a HA instance has started is displayed. Click the message to monitor the progress of the operation. Alternatively, select Operations in the drop-down list of the main menu to monitor the progress of the operation.
    
    After the provisioning operation is completed, the HA instance appears in the list of the provisioned databases. Click the name of the instance to open the homepage for the selected instance. This page displays the following widgets:
    
      152.   PostgreSQL HA Instance Summary. Displays a brief summary of the HA instance that includes the name, description, deployment type, status, database user, and version.
          
      154.   Alerts. Displays the alert messages, the number of occurrences, and the last occurred time of the alerts.
      155.   PostgreSQL Instances. Displays the list of database instances created. Details including name, primary and failover nodes, status, database server VM, IP addresses and time machine status are also displayed.
          
      157.   Databases. Displays the list of databases in the instance. Click See Description to view details on accessing the respective database.
          
      159.   Profiles. Displays the software, compute, and network profiles that were applied when the database was created. You can click the hyperlinks to view further details of each profile.
          
      161.   Time Machine for instance. Displays the name, description, age, and size of the time machine.
          
      163.   Tags. Displays a list of the tags that are applied to this database server. You can click Update to set the tag values.
          
      165.   Server Cluster. Displays the name, virtual IP address, and OS details of the PostgreSQL server cluster.

### [Adding a Database to an Existing PostgreSQL Instance](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-PostgreSQL-Database-Management-Guide-v2_9:top-database-to-postgresql-instance-add-t.html)

All PostgreSQL instances consist of user-created and system-created databases. NDB provides multiple database support for PostgreSQL at the instance level.

### About this task

Perform the following to add a new database to an existing PostgreSQL instance.

Note: Multiple databases can be added using NDB CLI or API, but only one database can be added at a time using the NDB UI.

### Procedure

1.  From the main menu, select Databases.
2.  Go to Sources and click the instance to which you want to add a new database.
    
    The PostgreSQL Instance Summary page appears.
    
3.  Go to the Databases widget and click Add.
    
    The Add Database window appears.
    
4.  Enter the name of the new database in the Database Name field.
5.  Click Create.
    
    NDB adds the new database to the selected instance. A message indicating that the operation to add a database has started is displayed. Click the message to monitor the progress of the operation. Alternatively, select Operations in the drop-down list of the main menu to monitor the progress of the operation.
    
    After the operation is completed, the database appears in the list of the databases under the Databases widget.

### [Removing a Database from an Existing PostgreSQL Instance](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-PostgreSQL-Database-Management-Guide-v2_9:top-database-to-postgresql-instance-remove-t.html)

All PostgreSQL instances consist of user-created and system-created databases. NDB provides multiple database support for PostgreSQL at the instance level.

### About this task

Perform the following to remove a database from an existing PostgreSQL instance.

Note:

-   System-created databases cannot be removed using the following procedure.
    
    For example, postgres, template0, template1, and so on.
    
-   Only one database can be removed at a time using the NDB UI, CLI, or API.

### Procedure

1.  From the main menu, select Databases.
2.  Go to Sources and click the instance from which you want to remove a database.
    
    The PostgreSQL Instance Summary page appears.
    
3.  Go to the Databases widget and select the database that you want to remove from the instance.
4.  Click Remove.
5.  Type the database name to confirm and click Yes.
    
    NDB displays a message indicating that the operation to remove a database has started. Click the message to monitor the progress of the operation. Alternatively, select Operations in the drop-down list of the main menu to monitor the progress of the operation.

### [Peer Authentication for PostgreSQL Instances](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-PostgreSQL-Database-Management-Guide-v2_9:top-peer-authentication-postgres.html)

NDB supports peer authentication feature.

Peer authentication is a safe authentication method that relies on OS level security. This method does not require a password to authenticate. Instead, peer authentication works by obtaining the client's operating system username from the kernel and using it as the allowed database username.

If you enable peer authentication feature for a PostgreSQL database then time machine operations do not require any credentials. All database access for time machine operations are done using the peer authentication.

### [Enabling Peer Authentication for PostgreSQL Instances](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-PostgreSQL-Database-Management-Guide-v2_9:top-peer-authentication-postgres-enable-t.html)

This task shows how to enable peer authentication.

### About this task

By default, NDB disables peer authentication.

You can enable peer authentication by updating the database provision API payload. You can get the API payload while provisioning a database.

### Procedure

1.  Follow the procedure until the Tags step as described in Provisioning a PostgreSQL Instance or Provisioning a PostgreSQL HA Instance topic.
2.  In the Tags step, click API Equivalent.
    
    The API Equivalent window appears. The page shows JSON and script data.
    
3.  Copy the script and paste the script content in a text editor.
    
    To enable peer authentication, set the 
    ```
    enable_peer_auth
    ```
     flag to true in the API payload's 
    ```
    actionArguments
    ```
     field.
    
    For example:
    
    ```
    
    ```
    "actionArguments":
    [{"name":"enable_peer_auth","value":true}]
    ```
    
    ```
    
4.  Add the basic authentication header to the script as described in the user interface and run the script in the terminal.
    
    This enables peer authentication. All the database access for time machine operations are done using the peer authentication.

### [PostgreSQL Database Clone](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-PostgreSQL-Database-Management-Guide-v2_9:top-postgresql-db-clone-c.html)

You can create clones either to a point in time (by using transaction logs) or by using snapshots. Select the clone time to clone the source database at a point in time. NDB then clones the source database to its state at that time. If you want to use snapshots to clone the source database, select an available snapshot and the source database is cloned to a state when the snapshot is taken.

See [Clone Management](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide:top-clone-database-management-c.html) for information updating, refreshing, and removing clones.

### [Creating Instance Clones](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-PostgreSQL-Database-Management-Guide-v2_9:top-database-clones-posgresql-create-t.html)

### Before you begin

If you want to create instance clones on a non-source Nutanix cluster, ensure that you have configured the time machine data access policies for the Nutanix cluster on which you want to perform the clone operation. See [Data Access Management](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide:top-data-access-management-c.html) for more details.

### About this task

Perform the following procedure to clone an PostgreSQL instance.

### Procedure

1.  From the main menu, select Data Protection > Time Machines.
2.  Select the time machine of the PostgreSQL source instance you want to clone, click Actions and select Create a Clone of the PostgreSQL Instance.
    
    The Create Clone of PostgreSQL Instance from Time Machine window appears.
    
3.  In the Time/Snapshot step, select the clone time to which you want to clone the instance. Do the following to select the time.  1.  Select the Nutanix cluster on which you want to clone the instance.
          
          Note:
          
              5.   NDB multi-cluster must be enabled to select different Nutanix clusters. See [Nutanix Cluster Management](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide:top-multicluster-management-c.html) for more information.
              6.   Only the Nutanix clusters that have a time machine data access (DAM) policy configured are displayed in the drop-down list. For more information, see [Adding Time Machine Data Access to a Nutanix Cluster](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide:top-time-machine-data-access-add.html).
          
      2.  On the Month tab, select a day of the month.
      3.  Click the Day tab to select the clone time to which you want to clone the instance.
      4.  Do one of the following:    -   Point in time. Select this option if you want to clone the source instance to a point in time. If you select this option, the instance is cloned by using the transaction logs.
              11.   Snapshot. Select this option if you want to clone the source instance by using the available snapshots.
          
      5.  Click Next.
    
4.  Under Database Server VM, select one of the following.  -   Create New Server. Select this option to create a new target database server VM and clone the instance on the newly created target database server VM.
      21.   Use an Authorized Server. Select this option to clone the instance to a database server VM that you have already registered with NDB.
    
5.  If you have selected Create New Server in the previous step, do the following in the indicated fields.  1.  Database Server VM Name. Type a name for the database server VM.
      2.  Description. Type a description for the database server VM.
      3.  Compute Profile. Select a compute profile from the drop-down list of compute profiles available.
      4.  Network Profile. Select a network profile from the drop-down list of network profiles available.
      5.  NDB Drive User. Type the username of the NDB drive user account that has sudo access.
      6.  Update Password (Optional). Type the password for the NDB drive user account.
      7.  SSH Public Key (Optional). Do one of the following to use SSH public keys to access the database server VM:    -   File. Upload a file that includes the public key.
              8.   Text. Type or copy and paste the public key.
          
      8.  Click Next.
    
6.  If you have selected Use an Authorized Server in the previous step, select a target database server VM from the list of available database server VMs that are registered with NDB and click Next.
    
    If there are no database servers authorized, click the plus icon to authorize one or more database server VMs.
    
7.  Under Instance step, do the following in the indicated fields:  1.  Name. Type a name for the cloned instance.
      2.  Description. Type a description for the cloned instance.
      3.  Database Parameter Profile. Select a database parameter profile from the list of the profiles available.
      4.  Database User. Enter the name of the database user with superuser privileges that facilitates connection to the database. You cannot change the database user once defined.
      5.  Database User Password. Type the password for the database user.
      6.  Schedule Data Refresh. You can schedule data refresh to refresh the clone automatically. Select this option and define the frequency and time slots to refresh the clone.
      7.  Removal Schedule. You can schedule the removal of the instance clone by specifying the number of days after which NDB automatically deletes the clone.
      8.  Delete the Database Clone from the VM. Select this checkbox to delete the database clone from the VM.
      9.  Click Pre-Post Commands and do the following in the indicated fields:
          
              11.   Pre-Create Command. Type a complete OS command that you want to run before the instance is created.
              12.   Post-Create Command. Type a complete OS command that you want to run after the instance is created.
    
8.  Under the Additional Configurations section, do the following in the indicated fields:  1.  CipherTrust Transparent Encryption: Enter the name of the CTE configuration.
      2.  CipherTrust Client ID (DB Server VM): Enter the CTE client ID.
      3.  CipherTrust Guard Point ID: Enter the guard point ID of the protected path in the database server VM.
      4.  Click Add to add a second CipherTrust Guard Point ID.
    
9.  Click Clone to clone the source instance.
    
    A message appears indicating that the operation to clone instance has started. Click the message to monitor the progress of the operation. Alternatively, select Operations in the drop-down list of the main menu to monitor the progress of the operation.
    
    After the operation is completed, the instance clone appears in the list of the cloned databases. Go to Databases > Clones to view the clone that is created. Click the name of the instance clone to view more details.

### [Restoring a PostgreSQL Instance](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-PostgreSQL-Database-Management-Guide-v2_9:top-postgresql-database-restore-t.html)

Restoring allows you to restore a source instance registered with NDB to a snapshot or point in time supported by the source instance time machine. You can restore an instance by using a snapshot ID, the point-in-time recovery (PITR) timestamp, or the latest snapshot. A database restore operation replaces the current instance with data as of the specified snapshot or point in time. The time machine for the source instance is paused before a restore operation is initiated. After a successful restore, the time machine is automatically resumed triggering a new snapshot and log catch-up operation for the restored instance. If the restore operation fails, the instance is left in the state that it was before the restore was initiated.

### Before you begin

Ensure the following before you restore a PostgreSQL instance.-   Register the source instance running on that cluster with Nutanix NDB.
-   Ensure that the instance has a time machine that supports the required snapshot or point-in-time restore capability.
-   NDB multi-cluster must be enabled for multi-cluster restore. See [Nutanix Cluster Management](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide:top-multicluster-management-c.html) for more information.

### About this task

Perform the following procedure to restore a PostgreSQL instance (single instance or HA). You can restore a PostgreSQL instance across one or more Nutanix clusters from the Database home page or the Time Machine page.

Note:

-   Perform this operation with caution as there might be some data loss.
-   While restoring a PostgreSQL HA instance, it is possible that the restore of standby nodes fails for various reasons. In such cases, NDB leaves the database in a 
    ```
    PARTIAL_READY
    ```
     state, and the primary node is ready to serve application traffic. Use the 
    ```
    patronictl
                                    reinit
    ```
     command to rebuild the standby node.

### Procedure

1.  From the main menu, select Databases.
2.  Go to Sources and click the instance you want to restore.
3.  You can restore a instance by doing any one of the following.  -   Click Restore in the instance summary page.
          
          Or
          
      7.   Click the time machine name in the Time Machine widget.
          
          In the Actions drop-down list, select Restore Source Instance.
          
          The Restore Source Database window appears displaying a combined time line of the data available (point in time or snapshot) across all the associated clusters of the time machine.
    
4.  Do the following in the indicated fields.  1.  Select any one of the following restore options.
          
              3.   Point in Time. Select this option and enter the time to which you want to restore your instance.
              4.   Snapshot. Select this option and choose the snapshot you want to use for restoring the instance from the drop-down list.
                  
                  NDB provides you the flexibility to perform a remote snapshot restore operation in case the snapshot is not available locally. You can replicate snapshots available in the other Nutanix clusters that are associated with the time machine and perform a restore operation.
                  
                  Select a Nutanix cluster from the Replicate Snapshot from drop-down list, and proceed with the restore procedure.
          
      2.  Write Ahead Logs. Select this check box and click Run to backup all the available additional logs and shut down the time machine.
          
          A confirmation box is displayed when you click Next. Type the instance name and click Shutdown to start the backup and recovery operations.
          
          Note:
          
              16.   This option can only be selected for time machines supporting continuous recovery.
              17.   The PostgreSQL instance is stopped as part of this action.
          
      3.  (Only for multi-cluster restore) The following options are displayed when the selected snapshot is not available in the same cluster as the primary database node.
          
              21.   Failover the primary for the instance <primary instance name> (Faster). Select this option to exit the restoring operation and failover the primary to a node that is present on a cluster where the required snapshot is available.
              22.   Perform Remote Snapshot Restore (Slower). Select a Nutanix cluster from where the snapshot will be replicated.
          
          Note:
          
          To manually specify the primary database node, change the value in the actionArguments field of the restore operation payload as shown below:
          
          ```
          
          ```
          {
          "name": "targetPrimaryNodeId",
          "value": <database_node_id>
          }
          ```
          
          ```
    
5.  Click Restore.
    
    A message appears stating that the restore operation has started. You can click on the message to view the status.

### [Scaling a PostgreSQL Database](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-PostgreSQL-Database-Management-Guide-v2_9:top-postgresql-db-scale-t.html)

Scaling the database extends the storage size proportionally across the attached virtual disks or volume groups. Scaling is supported for both single and HA instances.

### About this task

Perform the following procedure to scale a PostgreSQL instance.

Note:

-   NDB allows you to only scale instances that are provisioned in NDB.

### Procedure

1.  You can scale the database by doing any one of the following.  -   From the main menu, go to Databases > Sources and select the instance, which you want to scale.
          
          Click the Database Actions drop-down list and select Scale.
          
      5.   From the main menu, go to Databases > Sources and click the instance that you want to scale.
          
          The instance summary page appears. Click Scale.
    
    The Scale Database window appears.
    
2.  Do the following in the indicated fields.  1.  Expand Data Area by. Enter the additional data area (in GiB) to be added to the existing database.
      2.  Expand Log Area by. This field is auto-calculated by NDB. By default, the log area is calculated as 50% of the data area.
    
3.  Click Update.
    
    NDB increases the storage size of the selected database according to the specified expansion values.

### [Patching a PostgreSQL Database Server VM](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-PostgreSQL-Database-Management-Guide-v2_9:top-postgresql-db-patch-t.html)

### About this task

NDB supports automated minor version upgrades for PostgreSQL. For example, you can upgrade from PostgreSQL 13.1 to 13.8 but not to 14. You need a software profile version to update a database server VM to a newly available patch version. Perform the following procedure to apply a minor version upgrade of the PostgreSQL software to an NDB provisioned instance.

Note:

-   Patching outside NDB is not recommended for PostgreSQL database server VMs that are associated with an existing software profile. In such scenarios, the Database Server VM Summary page displays a warning message stating the mismatch of database server VM versions.
-   Ensure to use a consistent timezone configuration across all the database server VMs, including those provisioned using a specific software profile and the database server VM used to create a new version of that profile.

### Procedure

1.  To create a software profile version for patching a PostgreSQL database, do the following:  1.  Provision a database server VM using the software profile you wish to update.
      2.  Use Prism Central to clone the database server VM you just provisioned and sign in to the cloned VM and install a minor version upgrade of PostgreSQL.
      3.  Register the cloned database server VM with NDB.
      4.  Create a software profile update version for the original software profile using the new VM with the upgraded database software. For more information, see [Creating a Software Profile Version](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-PostgreSQL-Database-Management-Guide-v2_9:top-software-profile-version-create-t.html).
    
2.  From the main menu, select Database Server VMs.
3.  Go to List and click the database server VM for which you want to update the software profile version.
    
    The Database Server VM Summary page appears.
    
4.  Go to the Software Profile Version widget and click Update. The Update Database Server VM window appears.
    
    The Software Profile Version widget displays the current version, recommended version, and the status of the software profile version.
    
5.  Do the following in the indicated fields:  1.  Update to Software Profile Version. Select the software profile version from the drop-down list.
      2.  Under Start Update, select one of the following:    -   Now. Select this option if you want to start updating the software version now.
              3.   Later. Select this option and then select the day and time if you want to create a schedule for patching the software profile version.
          
      3.  Click Pre-Post Commands and do the following in the indicated fields:
          
              7.   Pre-Create Command. Type a complete OS command that you want to run before the single-instance database is created.
              8.   Post-Create Command. Type a complete OS command that you want to run after the single-instance database is created.
    
6.  Provide the database server VM name as confirmation and click Update.
    
    A message appears indicating that the operation to update a database has started. Click the message to monitor the progress of the operation. Alternatively, select Operations in the drop-down list of the main menu to monitor the progress of the operation.
    
    If you selected the Later option in the previous step, then the Software Profile Version widget displays the status of the scheduled patching operation. You can click Cancel Scheduled Update to cancel the scheduled patching operation.

### [Patching a PostgreSQL Database Server Cluster](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-PostgreSQL-Database-Management-Guide-v2_9:top-postgresql-ha-database-patch-t.html)

### Before you begin

A software profile version is required when you update a database server cluster to a newly available update version. See [Creating a Software Profile Version](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-PostgreSQL-Database-Management-Guide-v2_9:top-software-profile-version-create-t.html)

### About this task

Perform the following procedure to apply a minor version upgrade of the PostgreSQL software to an NDB provisioned HA instance.

Note:

-   Patching outside NDB is not recommended for PostgreSQL database server VMs that are associated with an existing software profile. If NDB detects a version mismatch on any of the database server VMs in the server cluster, the PostgreSQL version for all database server VMs on the cluster will be updated to keep the behavior consistent and prevent any future errors. A warning message stating the mismatch of database server VM versions is displayed in the Database Server Cluster Summary page for such scenarios.
-   Patching of PostgreSQL HA databases only upgrades minor versions of the PostgreSQL binaries on all HA nodes.
-   Ensure to use a consistent timezone configuration across all the database server VMs, including those provisioned using a specific software profile and the database server VM used to create a new version of that profile.

### Procedure

1.  From the main menu, select Database Server VMs.
2.  Go to List and click the database server cluster for which you want to update the software profile version.
    
    The Server Cluster Summary page appears.
    
3.  Go to the Software Profile Version widget and click Update. The Update DB Server VM Cluster window appears.
    
    The Software Profile Version widget displays the current version, recommended version, and the status of the software profile version.
    
4.  Do the following in the indicated fields:  1.  Update to Software Profile Version. Select a software profile version from the drop-down list.
      2.  Under Start Update, select one of the following:    -   Now. Select this option if you want to start updating the software version now.
              3.   Later. Select this option and then select the day and time if you want to create a schedule for patching the software profile version.
          
      3.  Click Pre-Post Commands and do the following in the indicated fields:
          
              7.   Pre-Create Command. Type a complete OS command that you want to run before the single-instance database is created.
              8.   Post-Create Command. Type a complete OS command that you want to run after the single-instance database is created.
    
5.  Provide the database server cluster name as confirmation and click Update.
    
    A message appears indicating that the operation to update a database has started. Click the message to monitor the progress of the operation. Alternatively, select Operations in the drop-down list of the main menu to monitor the progress of the operation.
    
    If you selected the Later option in the previous step, then the Software Profile Version widget displays the status of the scheduled patching operation. You can click Cancel Scheduled Update to cancel the scheduled patching operation.

### [NDB Interoperability with PostgreSQL Extensions](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-PostgreSQL-Database-Management-Guide-v2_9:top-postgresql-extensions-c.html)

NDB supports several PostgreSQL extensions that enhance database functionality and improve certain processes. These extensions integrate seamlessly with NDB workflows to meet diverse application needs.

To identify which extension each PostgreSQL distribution supports, and to verify compatibility with specific operating systems and their versions, see the [Nutanix Database Service Release Notes](https://portal.nutanix.com/page/documents/details?targetId=Release-Notes-Nutanix-NDB-v2_8_1_1:Release-Notes-Nutanix-NDB-v2_8_1_1).

NDB provides interoperability with the following PostgreSQL extensions:

-   pg\_cron
-   pg\_logical
-   pg\_partman
-   pg\_stat\_statements
-   pg\_vector
-   pgAudit
-   PostGIS
-   set\_user
-   TimescaleDB

You can patch minor versions for extensions if the following conditions are met:

-   The PostgreSQL binary is patched at the same time.
-   The extension is installed in the same directory on the database server VM as the PostgreSQL binary. For example, the extension TimescaleDB is installed in the folder /usr/pgsql-NN/ where the database binary is installed.

Important: Patching the extension without patching the PostgreSQL binary using the software profile is not supported.

Table 1. Supported extensions patching examples
 Software Profile name and Version | PostgreSQL version | Extensions version |
| --- | --- | --- |
 PostgreSQL version 1.0 | 16.4 | 2.21.2 |
 PostgreSQL version 2.0 | 16.5 | 2.21.3 |

After completing the patching operation, run the following psql command to enable the patched extension in the database:

ALTER EXTENSION extension-name UPDATE;

### [SSL Support for PostgreSQL](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-PostgreSQL-Database-Management-Guide-v2_9:top-postgresql-ssl-support-c.html)

NDB supports SSL for the PostgreSQL database engine.

Secure sockets layer (SSL) is a security protocol for encrypting, securing, and authenticating communications that take place on the internet. Transport Layer Security (TLS) is the newer version of the protocol. NDB supports TLS 1.2.

NDB offers support for SSL connections on PostgreSQL single instance and high availability (HA) databases. Enabling SSL on a single instance database secures all the communication calls to it. On a PostgreSQL HA database, SSL also secures the communication with etcd and Patroni nodes.

Note:

-   NDB support for SSL is limited to PostgreSQL databases on which SSL is configured. NDB does not support enabling or disabling SSL on a PostgreSQL database.
-   The PostgreSQL out-of-the-box (OOB) profile does not support SSL-encrypted communication. Create a custom software profile to enable SSL.

### [Configuring SSL for PostgreSQL Single Instance](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-PostgreSQL-Database-Management-Guide-v2_9:top-postgresql-ssl-confirgure-t.html)

This task describes how to configure SSL for a single instance PostgreSQL database.

### Before you begin

Create the server certificate and private key files.

### About this task

Follow the steps below to enable SSL for a PostgreSQL single instance database.

Note:

-   NDB supports all database operations with TLS except provisioning (as TLS is configured after provisioning).
-   For greenfield databases, you can configure TLS after database provisioning. However, for brownfield databases, you can register a TLS-enabled instance.
-   NDB supports single-instance clones with TLS. You can configure TLS after provisioning the clone database. NDB retains the configuration settings after a clone refresh operation.

### Procedure

1.  Access the postgresql.conf file in the Postgres data directory as the 
    ```
    postgres
    ```
     user.
2.  Use the 
    ```
    vi postgresql.conf
    ```
     command to edit the file and modify the following parameters.
    
      12.   ```
          ssl
          ```
          : Specify the value of this parameter as 
          ```
          on
          ```
           or 
          ```
          off
          ```
           to enable or disable SSL.
      24.   ```
          ssl_cert_file
          ```
          : Specify the server certificate path. This certificate is sent to the client to indicate the server's identity.
      28.   ```
          ssl_key_file
          ```
          : Specify the path of the server's private key. The key proves that the owner sent the server certificate but it does not indicate that the certificate owner is trustworthy.
      32.   ```
          ssl_ca_file
          ```
          : Specify the path of the trusted certificate authority. Use this parameter if you need to enable client certificate authentication.
    
3.  Update the pg\_hba.conf file by replacing the required entries having the keyword 
    ```
    host
    ```
     with 
    ```
    hostssl
    ```
    .
    
    This ensures that only the required connections are secured.
    
4.  If you enabled client certificate authentication in Step 1, add an entry to the pg\_hba.conf file with either of the following parameters:
    
      51.   ```
          clientcert=verify-ca
          ```
          : If you specify this parameter, the server verifies that the client's certificate is signed by a trusted certificate authority.
      55.   ```
          clientcert=verify-full
          ```
          : If you specify this parameter, the server verifies the certificate chain and checks whether the username or its mapping matches the common name (CN) of the provided certificate.
          
          For example, to allow any user to connect to any database while verifying the authenticity of the client, create the following entry:
          
          ```
          
          ```
          hostssl all all 0.0.0.0/0 md5 clientcert=verify-ca
          ```
          
          ```
    
5.  Restart the PostgreSQL instance to apply the changes.
    
    ```
    
    ```
    [era@pgsi-inst ~]$ sudo systemctl restart era_postgres
    ```
    
    ```
    
    Note: This command only applies when the 
    ```
    era_postgres
    ```
     service manages the 
    ```
    postgres
    ```
     process. Always restart the 
    ```
    postgres
    ```
     process using binaries or the relevant service present on the system.

### [Configuring SSL for PostgreSQL HA](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-PostgreSQL-Database-Management-Guide-v2_9:top-postgresql-ssl-ha-configure-t.html)

This task describes the steps to configure SSL for a PostgreSQL high availability (HA) database.

### Before you begin

Create the server certificate and private key files.

### About this task

Enabling SSL on a PostgreSQL HA instance involves configuration of SSL for etcd and Patroni services. Follow the steps below to enable SSL for PostgreSQL HA database.

### Procedure

1.  Update the etcd configuration file /etc/etcd/etcd.yml with the following SSL parameters:
    
      3.   ```
          cert-file
          ```
          : Specify the certificate path of the etcd node. This certificate is sent to the client to indicate the identity of the etcd node.
      7.   ```
          key-file
          ```
          : Specify the private key path of the etcd node. The key proves that the owner sent the server certificate but does not indicate that the owner is trustworthy.
      11.   ```
          client-cert-auth
          ```
          : Specify the value of this parameter as 
          ```
          true
          ```
           or 
          ```
          false
          ```
          . If 
          ```
          true
          ```
          , the etcd node checks all incoming requests for client certificates signed by the trusted CA. Requests without a valid client certificate will fail.
      27.   ```
          trusted-ca-file
          ```
          : Specify the path of the trusted certificate authority. If you specify this parameter, the etcd node checks that client certificate is signed by a trusted certificate authority.
    
2.  Update the Patroni configuration file /etc/patroni/patroni.yml with the following SSL parameters:
    
      34.   ```
          cert-file
          ```
          : Specify the certificate path of the Patroni node. This certificate is sent to the client to indicate the identity of the Patroni node.
      38.   ```
          key-file
          ```
          : Specify the private key path of the Patroni node. The key proves that the server certificate was sent by the owner but does not indicate that the owner is trustworthy.
      42.   ```
          verify_client
          ```
          : Specify the value of this parameter as 
          ```
          none
          ```
          , 
          ```
          optional
          ```
          , or 
          ```
          required
          ```
          . The effects of specifying these values are as follows:    -   ```
                  none
                  ```
                  : The Patroni REST API does not check the client certificates.
              61.   ```
                  optional
                  ```
                  : The client certificates are required for all unsafe REST API calls.
              65.   ```
                  required
                  ```
                  : The client certificates are required for all REST API calls.
          
      70.   ```
          cafile
          ```
          : Specify the path of the trusted certificate authority. The etcd node checks that client certificate is signed by a trusted certificate authority.
    
3.  Update the etcd section of the Patroni configuration file /etc/patroni/patroni.yml with the following SSL parameters:
    
      77.   ```
          protocol
          ```
          : Specify the protocol as 
          ```
          http
          ```
           or 
          ```
          https
          ```
          . Specify the 
          ```
          https
          ```
           protocol to use secure communication.
      93.   ```
          cert
          ```
          : Specify the certificate path of the etcd node. This certificate is sent to the client to indicate the identity of the etcd node.
      97.   ```
          key
          ```
          : Specify private key path of the etcd node. The key proves that the owner sent the server certificate but does not indicate the owner is trustworthy.
      101.   ```
          cacert
          ```
          : Specify the path of the trusted certificate authority. If you specify this parameter, the etcd node checks that client certificate is signed by a trusted certificate authority.
    
4.  Update the 
    ```
    pg_hba
    ```
     section in the Patroni configuration file /etc/patroni/patroni.yml by replacing the entries having the keyword
    ```
    host
    ```
     with 
    ```
    hostssl
    ```
    .
5.  If you chose to enable client certificate authentication in Step 1, add an entry to the 
    ```
    pg_hba
    ```
     section with either of the following parameters:
    
      125.   ```
          clientcert=verify-ca
          ```
          : If you specify this parameter, the server verifies that the client's certificate is signed by one of the trusted certificate authorities.
      129.   ```
          clientcert=verify-full
          ```
          : If you specify this parameter, the server verifies the certificate chain and checks whether the username or its mapping matches the common name (CN) of the provided certificate.
          
          For example, to allow any user to connect to any database while verifying the certificate authority, create the following entry:
          
          ```
          
          ```
          hostssl all all 0.0.0.0/0 md5 clientcert=verify-ca
          ```
          
          ```
    
6.  Update the /home/postgres/era\_custom\_pg\_params.conf file with the following SSL parameters:
    
      146.   ```
          ssl
          ```
          : Specify the value of this parameter as 
          ```
          on
          ```
           or 
          ```
          off
          ```
           to enable or disable SSL.
      158.   ```
          ssl_cert_file
          ```
          : Specify the server certificate path. This certificate is sent to the client to indicate the server's identity.
      162.   ```
          ssl_key_file
          ```
          : Specify the path of the server's private key. The key proves that the owner sent the server certificate but does not indicate that the owner is trustworthy.
      166.   ```
          ssl_ca_file
          ```
          : Specify the path of the trusted certificate authority. Use this parameter if you need to enable client certificate authentication.
    
7.  Restart etcd on each node:
    
    ```
    
    ```
    [era@pgha-inst ~]$ sudo systemctl restart etcd
    ```
    
    ```
    
8.  Restart Patroni on each node:
    
    ```
    
    ```
    [era@pgha-inst ~]$ sudo systemctl restart patroni
    ```
    
    ```

### [Appendix](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-PostgreSQL-Database-Management-Guide-v2_9:top-postgresql-appendix-c.html)

Standard support policy for PostgreSQL Community Edition on NDB and frequently asked questions about database issues encountered when using PostgreSQL database with NDB.

For more information, see the following topics:

-   [Nutanix Support Policy for PostgreSQL Community Edition](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-PostgreSQL-Database-Management-Guide-v2_9:top-support-policy-postgresql-r.html)
-   [FAQs](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-PostgreSQL-Database-Management-Guide-v2_9:top-postgresql-faqs-c.html)

### [Nutanix Support Policy for PostgreSQL Community Edition](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-PostgreSQL-Database-Management-Guide-v2_9:top-support-policy-postgresql-r.html)

Detailed information about supported and unsupported service areas within the product scope of PostgreSQL Community Edition on NDB.

Table 1. Scope of Support for PostgreSQL Community Edition
 Service Area | Support Scope | Description |
| --- | --- | --- |
 PostgreSQL Installation | Yes | Provisioning of PostgreSQL clusters through NDB in standard configuration, including troubleshooting installations or startup failures at the setup time. |
 Database Configuration | Yes | Supported PostgreSQL server parameters and operational guidance within NDB provisioned PostgreSQL clusters. |
 High Availability Setup | Yes | NDB provisioned HA components (Patroni, etcd, HAProxy) including troubleshooting cluster setup, failover, and coordination issues. |
 Infrastructure Support | Yes | Ongoing PostgreSQL service issues within NDB provisioned instances - for example, failures to start, unexpected crashes, or configuration errors after deployment. General OS or hypervisor-level issues are out of scope. |
 Security Configuration | Yes | Roles and users, authentication, access controls, and SSL/TLS configuration within NDB workflows. |
 Backup and Recovery | Yes | PostgreSQL backup, restore, and point-in-time recovery (PITR) through Nutanix Time Machine; troubleshooting failed backup/restore/PITR operations and usage guidance. |
 Version Patching | Yes | Issues related to PostgreSQL patching performed through NDB workflows, including troubleshooting patch apply failures. |
 Extension Interoperability with NDB | Yes | Interoperability validation for NDB\-qualified extensions. |
 Documentation and Best Practices | Yes | Access to Nutanix KB articles, procedures, and best-practice guidance for NDB\-provisioned PostgreSQL. |
 Application and Query | No | Custom application code development or debugging; SQL query tuning, index optimization, workload-specific performance analysis, or business-logic troubleshooting. |
 Extensions/Third-party | No | Installation, configuration, or lifecycle management of extensions; custom/proprietary or unsupported extensions; integrations and external tooling beyond the NDB platform. |

Note: For help with edge cases or scenarios not covered here, contact Nutanix Support.

### [FAQs](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-PostgreSQL-Database-Management-Guide-v2_9:top-postgresql-faqs-c.html)

Frequently asked questions about database issues encountered when using PostgreSQL database with NDB.

1.  **My database is down or having critical issues. How quickly will NDB support respond?**
    
    Database outages and critical issues receive our highest priority as it relates to the infrastructure. Contact support immediately through your NDB dashboard for the fastest response. Specific response times depend on your support plan and case priority. For SLA details, refer to your service agreement. For more information, see [Product Support Programs](https://www.nutanix.com/support-services/product-support/product-support-programs).
    
2.  **Does Nutanix provide enterprise support for PostgreSQL (including Patroni, etcd)?**
    
    Yes. Nutanix provides enterprise break/fix support for PostgreSQL as deployed and managed through NDB, including High Availability components such as Patroni, etcd, and HAProxy.
    
    This support covers issues encountered during NDB\-managed PostgreSQL operations, including configuration failures, installation problems, patching errors, HA deployment issues, or failover scenarios.
    
    Proactive installation, configuration, and patching services are not part of Support. These are available through Nutanix Professional Services. Contact your account team for details.
    
3.  **My application is running slowly. Can Nutanix support help improve performance?**
    
    Nutanix Support assists with infrastructure-related issues that might affect performance. For example, PostgreSQL service errors, HA failover misbehavior, or resource allocation problems in NDB\-provisioned clusters.
    
    Support does not include SQL query tuning, index design, or application-specific workload optimization. These activities are best handled by your development team or through Nutanix Professional Services.
    
4.  **What does Nutanix Support assist with and what I need to handle myself?**
    
    Nutanix Support provides assistance for issues related to PostgreSQL infrastructure, database operations, and platform integration. Troubleshooting related to application development, custom code, query optimization, and business logic remains your responsibility.
    
5.  **What is Nutanix Support’s role with PostgreSQL extensions?**
    
    Nutanix Support validates interoperability for [NDB-qualified extensions](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-PostgreSQL-Database-Management-Guide-v2_9:top-postgresql-extensions-c.html) to ensure they work within your deployment. Nutanix Support does not cover installing, configuring, or managing extension life cycles. Third-party or custom extensions are outside the scope of support.