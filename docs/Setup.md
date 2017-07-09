# ClassDB Setup
This document explains how to install and configure ClassDB in an existing PostgreSQL (Postgres) instance. It also details each ClassDB component and explains how to install them. For the install guide only, skip to the "Component Installation" section.

## Prerequisites
ClassDB requires an existing instance of Postgres to run on. This documentation does not go into detail on how to install and configure a Posrtgres instance, however it details some requirements for ClassDB to function correctly. ClassDB has been primarily tested with the [BigSQL Postgres 9.6.3 distribution](https://www.bigsql.org/) on Windows 10 and Ubuntu Server 16.04.

ClassDB currently requires a "fully owned instance" of Postgres to function correctly. A "fully owned instance" is defined as one which you have full control over the host server. This includes Postgres instances running on a local machine, a local virtual machine, or a virtual machine instance in a cloud service such as Amazon EC2 or Azure VM. ClassDB does not support platform as a service (PaaS) instances, such as Amazon RDS or Azure Database for PostgreSQL.

Additionally, the Postgres instance must be configured to accept connections from external clients. Depending on the distribution used, the instance may already be pre-configured to accept external connections. For example, the BigSQL distribution accepts connections from authorized database users connecting with remote clients. If the instance is not configured to accept incoming connections, refer to the [Postgres documentation](https://www.postgresql.org/docs/9.6/static/auth-pg-hba-conf.html) on how to allow connections from remote clients.

## Recommended Minimum Installation
It is recommend that all of the required components, and the catalog management functions are installed at a minimum.
The catalog management functions require no privileges beyond the required components, and provides useful functionality to students. It is only recommend leaving out the catalog management functions if you specifically do not want students to have access to those functions.

It is also recommend to install both the DDL statement and connection logging systems if you have sufficient privileges. It is not a required component only because the monitoring facilities require superuser permissions, which may not always be available.

More details about the scripts included in ClassDB can be found on the [Scripts](Scripts) page.

## Component Installation
To install ClassDB, the script for each of the components must be executed. A user account with superuser permissions is required to install ClassDB. The components installed perform the same regardless of the account used for installation, as long as that account meets the permissions requirements.

There are two levels to the ClassDB installation: server level components and database level components. Server level components only need to be installed once for the entire Postgres installation. Database level components need to be installed on each database you want to use ClassDB on. Thus, the database level scripts may need to be run multiple times.

The following sections outline how to install each ClassDB component. Required components must be installed, optional components are optional. However, if you choose to install a component, all scripts in that component must be run. To run each script, simply connect to the Postgres server and database ClassDB is to be installed on, and run the specified scripts. Some scripts may be run using the client of your choice, while some must be run through Postgres' command line client, [psql](https://www.postgresql.org/docs/9.6/static/app-psql.html). To run a script though psql, execute the following command, substituting appropriate values inside the angle brackets:
`psql -h <host> -p <port> -U <aSuperuserName> -d <someDatabaseName> -f <scriptName>`

### Server Core Components [Required, Server Level]
1. Run `prepareServer.sql`. Since this is a server level component, it may be installed while connected to any database on the DBMS.

### Database Core Components [Required, Database Level]
1. Run the command: `CREATE DATABASE <databaseName> WITH OWNER = ClassDB;`, substituting the desired name of a database to install ClassDB on. All further scripts should be run while connected to this database.
2. Run `prepareDB.psql`. Note, this script MUST be run using psql client.

### Catalog Management [Optional, Database Level]
1. Run `addCatalogMgmt.sql`

### DDL Statement Logging [Optional, Database Level]:
1. Run `addDDLMonitors.sql`

### Connection Logging [Optional]:
Note that this component has both a server level and database level component. To reiterate, the server level component only needs to be run once.
1. [Server Level] Run `enableServerLogging.sql`. Note, this script MUST be run using psql client.
2. [Database Level] Run `addLogMgmt.sql`

## Verifying Installation
The following queries can be used to verify that each component has been installed correctly:
1. Server Core Components: Executing the following query should return four rows, once matching each role in the `WHERE` clause.
```sql
SELECT * FROM pg_roles
WHERE rolname = 'classdb_instructor
   OR rolname = 'classdb_student'
   OR rolname = 'classdb_dbmanager'
   OR rolname = 'classdb';
```

2. Database Core Components: Once connected to the ClassDB database, executing the following query should return one row, showing a schema named 'classdb'.
```sql
SELECT *
FROM INFORMATION_SCHEMA.SCHEMATA
WHERE schema_name = 'classdb';
```

3. Catalog Management Functions: While connected to the ClassDB database, you should be able to execute the functions `public.listTables()` and
`public.describe('<tableName>')`.

4. DDL Statement Logging: While connected to the ClassDB database, the following query should return two rows:
```sql
SELECT *
FROM pg_event_trigger
WHERE evtname = 'updatestudentactivitytriggerdrop'
   OR evtname = 'updatestudentactivitytriggerddl';
```

5. Connection Logging: While connected to the ClassDB database, you should be able to execute the function `classdb.importLog()`.

## Removal
ClassDB provides separate scripts for removing database level and server level components. This allows ClassDB to be removed from individual database, or entire instances.

### Removing from a Database
`removeFromDB.sql` removes ClassDB components from the database the user is currently connected to. Like the setup scripts, it must be run as superuser. `removeFromDB.sql` must be run once on each database ClassDB is to be removed from. It performs the following operations:
1. ClassDB roles have their connection privileges revoke from the current database
2. ClassDB users are given ownership of their `$user` schema, if one exists on the current database
3. The DDL monitoring triggers are dropped, if they exist
4. The catalog management functions are dropped, if they exist
5. The classdb schema is dropped

There are a number of objects that may be leftover after this process. The user must manually drop or alter these objects.
1. Any ClassDB user roles will still exist
2. Any `$user` schemas on the current database will still exist, and be owned by the related user
3. Any objects created by Instructors or superusers in the public schema will still exist
4. The current database will still exist

Additionally, there is a case where this script may fail. If an Instructor or DBManager creates objects in the public schema, and is subsequently dropped, those objects will be assigned to `ClassDB_Instructor` or `ClassDB_DBManager`, respectively. These objects are considered 'orphan' objects, and will not be touched by the removal script. This will cause the script to fail, because it will be unable to fully remove permissions of the ClassDB roles. A user encountering this error can run `classdb.listOrphans()`, which will provide a list of these objects. They must be either dropped or assigned to a non-ClassDB role before the removal script will execute successfully.

### Removing from Server
`removeFromServer.sql` removes the server level components of ClassDB. This drops the ClassDB roles from the server. `removeFromDB.sql` must be run in every database ClassDB was installed in before `removeFromServer.sql` can be run. Once run, ClassDB will have been completely removed from the instance.

---
Steven Rollo  
Data Science & Systems Lab (DASSL), Western Connecticut State University (WCSU)

(C) 2017- DASSL. ALL RIGHTS RESERVED.  
Licensed to others under CC 4.0 BY-SA-NC: https://creativecommons.org/licenses/by-nc-sa/4.0/

PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.
