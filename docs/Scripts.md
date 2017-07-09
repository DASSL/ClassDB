# Scripts
This documents the scripts included in ClassDB. A description of each script, what permissions it requires, and when to use it are provided.

## Required Scripts
There are five ClassDB scripts that are required for ClassDB to function. These scripts install the core functionality of ClassDB, including
configuration of user permissions and procedures to create and manage users. In order to install the required components, you must have access to a superuser account. An additionall script is provided to help automate this process by executing four of the five required scripts.

### prepareServer.sql
- Permissions Required: `superuser`

`prepareServer.sql` performs server level configuration for ClassDB, and should be run once per Postgres instance. It creates the four user roles that are used by ClassDB:

- Instructor
- Student
- DBManager
- ClassDB

These roles are explained in detail in the [Roles overview](Roles).

### initializeDB.sql
- Permissions Required: `superuser`

`initializeDB.sql` sets appropriate permissions for each ClassDB role on the current database, and creates the ClassDB schema. It should be run once per database.

### addHelpers.sql
- Permissions Required: `superuser`

`addHelpers.sql` creates several helper functions that are used internally by ClassDB. It should be run once per database

### addConnectionMgmt.sql
- Permissions Required: `superuser`

`addConnectionMgmt.sql` creates functions used to view and terminate user connections. This is used in conjunction with a connection limit for Student users. It should be run once per database.

### addUserMgmt.sql
- Permissions Required: `superuser`

`addUserMgmt.sql` creates all procedures used to manage ClassDB users, and sets up appropriate access controls for user schemas. It should be run once per database.

### prepareDB.psql
- Permissions Required: `superuser`

'prepareDB.psql' is a helper script that runs all of the database level installation scripts at once. It uses psql meta-commands to do this, so it must be run using psql. The `.psql` file extension was added to help distinguish it from normal sql scripts.

## Optional Scripts
There are four optional components provided with ClassDB. These scripts provide useful additions, but are not required for the core functionality of ClassDB.

### addCatalogMgmt.sql
- Permissions Required: None

`addCatalogMgmt.sql` provides two helper functions intended to be used by students. These functions provide an easy way for a student to list all tables in a schema, and to get information about all columns in a given table. It should be run once per database.

### addDDLMonitors.sql
- Permissions Required: `superuser`

`addDDLMonitors.sql` provides the DDL statement logging for Student users. This facility stores information about the last DDL statement performed and the total number of DDL statements performed by each Student user in the `classdb.student` table. It should be run once per database.

### enableServerLogging.sql
- Permissions Required: `superuser`

`enableServerLogging.sql` modifies the Postgres logging system configuration. These changes cause Postgres to log connections made to the DBMS. It should be run once per Postgres instance.

### addLogMgmt.sql
- Permissions Required: `superuser`

`addLogMgmt.sql` provides connection logging using the external Postgres log file. A procedure is provided to analyze the log file, and store the last connection time and total number of connections for each Student user in `classdb.student`.
It should be run once per database.

## Example Schema
ClassDB also includes an example schema called `Shelter`. This schema contains a system for managing adoptions at a fictional animal shelter. It is intended as an example students can refer to. The schema is read-only for Students, while Instructors and DBManagers have read and write access. This example schema is not required, and is only intended as a teaching aid.

### createShelterSchema.sql
- Permissions Required: `superuser`

This script creates the `Shelter` schema. It first creates a separate schema called `shelter`, then creates the schema tables. It also sets the appropriate permissions for the schema and tables. It should be run once per database

### populateShelterSchema.sql
- Permissions Required: Write access to the shelter schema

This script populates the shelter schema with sample data. Any user with write access to the shelter schema can execute this script. By default, that includes all Instructors and DBManagers. It should be run once per database.

### dropShelterSchema.sql
- Permissions Required: `superuser`

This script removes the `shelter` schema and all objects contained within. It should be run once per database.

## Uninstall Scripts
The following scripts are used to remove ClassDB components from a database or instance.

### removeFromDB.sql

`removeFromDB.sql` removes all ClassDB database level components from a single database. This includes the ClassDB schema and all contained objects, the catalog management functions, and the DDL monitoring triggers. It also preserves all user schemas by changing their owner from ClassDB to the appropriate user.

### removeFromServer.sql

`removeFromServer.sql` removes all ClassDB server level components. This includes all the ClassDB roles. `removeFromDB.sql` must be run on all database ClassDB is installed on before `removeFromServer.sql` can be used.

---
Steven Rollo  
Data Science & Systems Lab (DASSL), Western Connecticut State University (WCSU)

(C) 2017- DASSL. ALL RIGHTS RESERVED.
Licensed to others under CC 4.0 BY-SA-NC: https://creativecommons.org/licenses/by-nc-sa/4.0/

PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.
