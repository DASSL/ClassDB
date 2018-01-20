[ClassDB Home](Home) \| [Table of Contents](Table-of-Contents)

---
# ClassDB Setup

_Author: Steven Rollo_

This document explains how to install and configure ClassDB on an existing PostgreSQL (Postgres) instance. It also details each ClassDB component and explains how to install them. For an install only guide, skip to the "Component Installation" section.


## Prerequisites
ClassDB requires an existing instance of Postgres to run on. ClassDB has been primarily tested with the [BigSQL Postgres 9.6.3 distribution](https://www.bigsql.org/) on Windows 10 and Ubuntu Server 16.04. This documentation will not go into further detail on how to install and configure a Posrtgres instance.

ClassDB currently requires a "fully owned instance" of Postgres to function correctly. A "fully owned instance" is defined as one which you have full control over the host server. This includes Postgres instances running on a local machine, a local virtual machine, or a virtual machine instance in a cloud service such as Amazon EC2 or Azure VM. ClassDB does not support platform as a service (PaaS) instances, such as Amazon RDS or Azure Database for PostgreSQL.

Additionally, the Postgres instance must be configured to accept connections from external clients. Depending on the distribution used, the instance may already be pre-configured to accept external connections. For example, the BigSQL distribution accepts connections from authorized database users connecting with remote clients. If the instance is not configured to accept incoming connections, refer to the [Postgres documentation](https://www.postgresql.org/docs/9.6/static/auth-pg-hba-conf.html) on how to allow connections from remote clients.


## Recommended Minimum Installation
We recommend installing all database and server level components in their respective `core` and `reco` folders. A minimal install of ClassDB with the core components only will function, however we believe that the recommend components significantly improve the overall function of ClassDB.

More details about the scripts included in ClassDB can be found on the [Scripts](Scripts) page.


## Component Installation
To install ClassDB, the script for each of the components must be executed. A user account with superuser permissions is required to install ClassDB. The components installed perform the same regardless of the account used for installation, as long as that account meets the permissions requirements.

There are two levels to the ClassDB installation: server level components and database level components. Server level components only need to be installed once for the entire Postgres installation. Database level components need to be installed on each database you want to use ClassDB on. Thus, the database level scripts may need to be run multiple times.

The following sections outline how to install ClassDB components. Core components must be installed, while recommend and optional components are not required. Additionally, scripts are provided to install all components (required, recommended, and optional). Note that some components require executing multiple scripts to install. To run each script, simply connect to the Postgres server and database ClassDB is to be installed on, and run the specified scripts. Some scripts may be run using the client of your choice, while some must be run through Postgres' command line client, [psql](https://www.postgresql.org/docs/9.6/static/app-psql.html). To run a script though psql, execute the following command, substituting appropriate values inside the angle brackets:
`psql -h <host> -p <port> -U <aSuperuserName> -d <someDatabaseName> -f <scriptName>`


### Full Installation
ClassDB provides two convince scripts that install all ClassDB components. If you wish to install all components, you may simply run these two scripts, and then skip to the `Verifying Installation` section.
1. Run `src/server/addAllToServer.psql`. Since this is a server level component, it may be installed while connected to any database on the DBMS
2. Run the command: `CREATE DATABASE <databaseName> WITH OWNER = ClassDB;`, substituting the desired name of a database to install ClassDB on. All `DB` scripts should be run while connected to this database
3. Run `src/db/addAlTolDB.psql`
 

## Individual Components
The following sections detail how to install individual ClassDB components. 

### Core Components [Required]

#### Server Core
1. Run `src/server/core/addAllServerCore.psql`. Since this is a server level component, it may be installed while connected to any database on the DBMS

#### Database Core
1. Run the command: `CREATE DATABASE <databaseName> WITH OWNER = ClassDB;`, substituting the desired name of a database to install ClassDB on. All `DB` scripts should be run while connected to this database
2. Run `src/db/core/addAllDBCore.psql`


### Recommended Components [Not Required]

#### Installing All Recommended Components
ClassDB provides two utility scripts for automatically installing all recommend components.
1. Run `src/server/reco/addAllServerReco.psql`
2. Run `src/db/reco/addAllDBReco.psql`

If you want to install individual components instead, see the next sections.

#### Connection Activity Logging
1. Run `src/server/reco/enableConnectionLoggingReco.psql`. This script is sever level, and need only be run once per Postgres server
2. Run `src/db/reco/addConnectionActivityLoggingReco.sql`
- Note: If you wish to disable connection logging in the future, run `src/server/reco/disableConnectionLoggingReco.psql`. Like `enableConnectionLoggingReco.psql`, this script only needs to be run once per Postgres instance

#### Connection Management
1. Run `/src/db/reco/addConnectionMgmtReco.sql`  

#### DDL Activity Logging
1. Run `src/db/reco/addDDLActivityLoggingReco.sql`

#### Frequent User Views
1. Run `src/db/reco/addFrequentViewsReco.sql`


### Optional Components [Not Required]

#### Catalog Management Functions
1. Run `src/db/opt/addCatalogMgmtOpt.sql`



## Verifying Installation
ClassDB provides many test scripts to verify that each component is working correctly. These scripts are found in the `tests` folder, and may be run in the same manner as the installation scripts. Please see the script source code or README files for more details about each script.

### Core Components:
The following scripts test the core components of ClassDB:
1. `testRoleBaseMgmt.sql`
2. `testUserMgmt.sql`
3. `testHelpers.sql`
4. `testClassDBRolesMgmt.sql`

Additionally, the Privileges test suite tests thoroughly tests that the access controls for each ClassDB role are working correctly. Note that this test is somewhat more involved to run than the previous tests. Please see `tests/privileges/testPrivilegesREADME.txt` for more information.

### Connection Activity Logging
To test connection activity logging, run `testAddConnectionActivityLogging.psql`. Note that this script requires some manual user interaction, see the source code for more information.

### Connection Management Functions 
While connected to the ClassDB database, you should be able to execute the function `ClassDB.listUserConnections('<username>')`.

### DDL Activity Logging
To test DDL activity logging, run `testAddDDLActivityLogging.sql`.

### Frequent User Views 
While connected to the ClassDB database, the following query should return `4`:
```sql
SELECT COUNT(*)
FROM ClassDB.listOwnedObjects('classdb')
WHERE Schema = 'public'
AND   Kind   = 'View';
```

### Catalog Management Functions
While connected to the ClassDB database, you should be able to execute the functions `public.listTables()` and
`public.describe('<tableName>')`.

## Removal
ClassDB provides separate scripts for removing database level and server level components. This allows ClassDB to be removed from individual database, or entire instances.

### Removing from a Database
`src/db/removeAllFromDB.sql` removes all ClassDB components from the database the user is currently connected to. Like the setup scripts, it must be run as superuser. `removeallFromDB.sql` must be run once on each database ClassDB is to be removed from. It performs the following operations:
1. ClassDB roles have their connection privileges revoked from the current database
2. The DDL activity triggers are dropped, if they exist
3. ClassDB functions that require superuser ownership are dropped
4. All other ClasDB object are dropped
5. The `ClassDB` schema is dropped, if it still exists

There are a number of objects that may be leftover after this process. The user must manually drop or alter these objects.
1. Any ClassDB user roles will still exist
2. Any `$user` schemas on the current database will still exist, and be owned by the related user
3. Any objects created by Instructors or superusers in the public schema will still exist
4. The current database will still exist

The uninstaller will not attempt to remove any objects except the ones listed above. Thus, the uninstaller will fail if any user objects create dependencies that prohibit ClassDB objects from being dropped. For example, a view that is derived from a ClassDB owned table, or a custom function owned by a superuser in the `ClassDB` schema. If any such object is encountered, the installer will throw an exception stating which object is causing the dependencies. Any such objects must be removed for the installer to run successfully.

There is an additional case where this script may fail. If an Instructor or DBManager creates objects in the public schema, and is subsequently dropped, those objects will be assigned to `ClassDB_Instructor` or `ClassDB_DBManager`, respectively. These objects are considered 'orphan' objects, and will not be touched by the removal script. This will cause the script to fail, because it will be unable to fully remove permissions of the ClassDB roles. A user encountering this error can run `classdb.listOrphans()`, which will provide a list of these objects. They must be either dropped or assigned to a non-ClassDB role before the removal script will execute successfully.

### Removing from Server
`src/server/removeAllFromServer.sql` removes the server level components of ClassDB. This drops the ClassDB roles from the server. `removeAlllFromDB.sql` must be run in every database ClassDB was installed in before `removeAllFromServer.sql` can be run. Once run, ClassDB will have been completely removed from the instance.

---
