# ClassDB Setup
This document will explain how to install and configure ClassDB in an existing PostgreSQL (Postgres) instance.  It will also detail each ClassDB component,
and explain how to install them.  For the install guide only, skip to the "Component Installation" secion.

## Prerequisites
ClassDB requires an existing instance of Postgres to run on.  This documentation will not go into detail on how to install and configure a Posrtgres
instance, however it will detail some requirements for ClassDB to function correctly.  ClassDB has been primarily tested with the [BigSQL Postgres 9.6.3 distribution](https://www.bigsql.org/)
on Windows 10 and Ubuntu Server 16.04.

ClassDB currently requires a "fully owned instance" of Postgres to function correctly.  We define "fully owned instance" as one which you have full control 
over the host server.  This includes Postgres instances running on a local machine, a local virtual machine, or a virtual machine instance in a cloud service
such as Amazon EC2 or Azure VM.  ClassDB does not support platform as a service (PaaS) instances, such as Amazon RDS or Azure Database for PostgreSQL.

Additionally, your Postgres instance must be configured to accept connections from external clients.  Depening on the distribution used, your instance
may come pre-configured to accept external connections.  For example, the BigSQL distribution will accept connections from authorized database users
connecting with remote clients.  If your instance is not configured to accept incomming connections, please refer to the ```pg_hba.conf``` [documentation](https://www.postgresql.org/docs/9.6/static/auth-pg-hba-conf.html)
for information on how to allow connections from remote clients.

## Required Components
There are three ClassDB components that are required for ClassDB to function.  These components provide the core functionality of ClassDB, including
configuration of user permissions and procedures to create and manage users. In order to install the required components, you must have access to a 
database user account with ```CREATEROLE``` and ```CREATEDB``` permissions.
 
### prepareClassServer.sql
- Permissions Required: ```CREATEROLE```

```prepareClassServer.sql``` performs server level configuration for ClassDB.  It will create the four user roles that are used by ClassDB:

- ClassDB
- DBManager
- Instructor
- Student

These roles are explained in detail in the Application Overview.

### createClassDB.sql
- Permissions Required: ```CREATEDB```

```createClassDB.sql``` creates a seperate database of use by ClassDB.  All operations related to ClassDB will be isolated to this database.  For instance,
all student schemas will be stored in this database. 

### prepareClassDB.sql
- Permissions Required: ```CREATEROLE```

```prepareClassDB.sql``` will create all procedures used to manage ClassDB users, and will set up appropriate access controls for each of the
four ClassDB roles.

## Optional Components
There are two optional components provided with ClassDB.  These components are not required for the core functionality of ClassDB.  Additionally,
they may require extended permissions to install and use.

### metaFunctions.sql
- Permissions Required: None

```metaFunctions.sql``` provides two helper functions intened to be used by students.  These functions provide an easy way for a student to list all
tables in a schema, and to get information about all columns in a given table.

### prepareUserLogging.sql
- Permissions Required: ```superuser```

```prepareUserLogging.sql``` provides a set of facilities to log and monitor user activity against the ClassDB database.  The first facility provided
is DDL statement logging.  This will store data about the last DDL statement performed and the total number of DDL statements performed
for each Student user in the ```classdb.student``` table.  The second facility is connection logging using the
external Postgres log file.  A procedure is provided to analyze the log file, and store the last connection time and total number of connections
for each Student user in ```classdb.student```.

## Recommended Minimum Installation
We recommend that all of the required components, and ```metaFunctions.sql``` are installed at a minimum.  ```metaFunctions.sql``` requires
no privileges beyond the required components, and provides useful functionality to students.  We would only recommend leaving out ```metaFunctions.sql```
if you specifically do not want students to have access to those functions.

We also recommend installing ```prepareUserLogging.sql``` if you have sufficient privileges.  It is not a required component only because
the monitoring facilities require superuser permissions, which might not always be available.

## Component Installation
To install ClassDB, the script for each of the components must be executed.  To do this, connect to your Postgres instance using the credentials
of an account that has sufficient permissions to install the desired components.  To reiterate, ```CREATEROLE``` and ```CREATEDB``` are required
to install the required components.  ```superuser``` is required only to install ```prepareUserLogging.sql```.  The components installed will
perform exactly the same, regardless of the account used for installation, as long as that account meets the permissions requirements.

Once your are connected to your instance, the scripts must be run in the following order ([R] denotes required, [O] denotes optional):
1. [R] ```prepareClassServer.sql```
2. [R] ```createClassDB.sql```
3. [R] ```prepareClassDB.sql```
4. [O] ```metaFunctions.sql```
5. [O] ```prepareUserLogging.sql```

## Verifying Installation
The following queries can be used to verify that each component has been installed correctly:
1. ```prepareClassServer.sql```: Executing the folloing query should return four rows, once matching each role in the ```WHERE``` clause.
```sql
SELECT * FROM pg_roles
WHERE rolname = 'student'
   OR rolname = 'instructor'
   OR rolname = 'dbmanager'
   OR rolname = 'classdb';
```

2. ```createClassDB.sql```: When connection to your Postgresinstance, you should be able to connect to a databse with the appropriate name.

3. ```prepareClassDB.sql```: Once connected to the ClassDB database, executing the following query should return one row, showing a schema named 'classdb'.
```sql
SELECT * 
FROM INFORMATION_SCHEMA.SCHEMATA
WHERE schema_name = 'classdb';
```

4. ```metaFunctions.sql```:  While connected to the ClassDB database, you should be able to execute the functions ```public.listTables()``` and
```public.describe()```.

5. ```prepareUserLogging.sql```: While connected to the ClassDB database, you should be able to execute the function ```classdb.importLog()```.
Additionally, the following query should return two rows.
```sql
SELECT * 
FROM pg_event_trigger
WHERE evtname = 'updatestudentactivitytriggerdrop'
   OR evtname = 'updatestudentactivitytriggerddl';
```
---
setup.md - ClassDB Documentation

Steven Rollo, Sean Murthy  
Data Science & Systems Lab (DASSL), Western Connecticut State University (WCSU)

(C) 2017- DASSL. ALL RIGHTS RESERVED.  
Licensed to others under CC 4.0 BY-SA-NC: https://creativecommons.org/licenses/by-nc-sa/4.0/

PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.
