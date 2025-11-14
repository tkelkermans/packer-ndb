# Nutanix Database Service 2.9 - PostgreSQL Prerequisite

This section enlists the prerequisites for PostgreSQL database registration and provisioning.

### PostgreSQL Database Server VM Registration Prerequisites

General

-   Database server VMs must have connectivity to Prism Element through TCP port 9440.
-   The NDB server must have connectivity to the database server VM.
-   The iSSCSI and iSCSI packages must be installed.

Software Dependencies (Linux)

-   To register a database server VM with NDB, the database server VM must satisfy all the required software and configuration dependencies. (For more information about the software packages that must be installed, see [Database Server VM Registration Pre-requirement Checks](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide:top-dbserver-pre-requirement-checks-c.html) and [Running Pre-requirement Script (Linux)](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide:top-script-pre-requirement-linux-t.html).

Database Server VM Registration

-   Register only one instance on the host.
-   Run the PostgreSQL processes.
-   Enable WAL logging.
-   Ensure that you have DBA level access to the databases you want to add.
-   Ensure that NDB service has access to TCP 5432 or a custom port.

### PostgreSQL Database Registration Prerequisites

General

-   NDB supports registering databases on VMs that are a part of an existing Nutanix Protection Domain (PD): all the entities associated with or attached to the VM must be protected. For example, if there is a volume group (VG) attached to the database server VM, then the existing PD must protect both the VG and VM, not only the VG.
-   Before you register a database running on ESXi cluster, you must set disk.EnableUUID to True by using vCenter Server.  1.  Shut down the database server VM on which the database is running.
      2.  Select the database server VM, go to VM > Actions > Edit Settings > VM Options > Advanced > Configuration Parameters > Edit Configuration, and click Add Row.
      3.  In the Name field, type disk.EnableUUID.
      4.  In the Value field, type True.
      5.  Start the database server VM.

OS Configuration

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

Single-Instance Database Registration

-   Register only one instance on the host.
-   Run the PostgreSQL processes.
-   Enable write-ahead logging (WAL).
-   DBA level access is required for the databases that you want to add.
-   Ensure that NDB service has access to TCP 5432 or a custom port.
-   Ensure that the default 'postgres' database is present in the PostgresSQL instance. This database is used to connect to PostgreSQL database server during NDB operations, therefore you should not delete it.

### PostgreSQL Database Server VM Provisioning prerequisites

General

-   Create a software profile.
-   Create a network profile. If a network profile exists, you can use the existing profile. Otherwise, create a network profile.
-   Create a compute profile. A sample compute profile is available. If you do not want to use the sample profile, you can create a compute profile.
-   Generate an SSH key for database provisioning on Linux-based operating systems.

### PostgreSQL Database Provisioning prerequisites

PostgreSQL Instance Provisioning

-   Ensure that you create a software profile if you do not want to use the built-in software profile. For more information, see [Creating a Software Profile](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-PostgreSQL-Database-Management-Guide:top-software-profile-postgresql-create-t.html).

PostgreSQL HA Instance Provisioning

-   For more information on the software required for HA instance provisioning, see [PostgreSQL Database Provisioning](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-PostgreSQL-Database-Management-Guide:top-postgresql-database-provision-c.html).
-   Ensure that you have the appropriate Patroni version installed. For more information on the supported Patroni versions, see NDB release notes.
-   To create your own profile on the operating system of your choice, contact Nutanix support.

For more information on PostgreSQL limitations, see [Current Limitations](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-PostgreSQL-Database-Management-Guide:top-postgresql-limitations-c.html).