[ClassDB Home](Home) \| [Table of Contents](Table-of-Contents)

---
# Scripts

_Author: Steven Rollo_

This documents the scripts included in ClassDB. A description of each script, what permissions it requires, and when to use it are provided. The directory structure of the ClassDB repository is also provided.

## Directory Structure
The `src` folder is organized in a hierarchy designed to clarify the usage of each ClassDB script. There are two top level directories:

| Name | Description |
| ---- | ----------- |
| [`db`](#database-level) | The scripts in this folder contain the database-level components of ClassDB. They must be run once per database. |  
| [`server`](#server-level) | The scripts in this folder contain the server-level components of ClassDB. They only need to be ran once per server. |

Each of these directories contains up to three sub-directories. Additionally, each contains install and uninstall script for all components located in the sub-directories.

| Name | Description |
| ---- | ----------- |
| [`core`](#core-scripts) | These scripts install components that are required for ClassDB to function |
| [`opt`](#optional-scripts) | These scripts install components that are useful, but are not necessary to use ClassDB to its full potential |
| [`reco`](#recommend-scripts) | These scripts install components that significantly increase the utility of ClassDB, but are not necessary for ClassDB to function |


## Database-Level

#### addAllToDB.psql
- Permissions Required: `superuser`

`addAllToDB.psql` installs all database level ClassDB components. This is useful if you want to perform a full installation without selecting individual components to install.

### Core Scripts

#### addAllDBCore.psql
- Permissions Required: `superuser`

`addAllDBCore.psql` is a psql helper script that runs all of the core database-level installation scripts at once. It uses psql meta-commands to do this, so it must be run using psql. The `.psql` file extension was added to help distinguish it from normal sql scripts.

#### addClassDBRolesMgmtCore.sql
- Permissions Required: `superuser`

`addClassDBRolesMgmtCore.sql` creates functions for managing ClassDB users.

#### addClassDBRolesViewsCore.sql
- Permissions Required: `superuser`

`addClassDBRolesViewsCore.sql` creates views displaying each type of ClassDB user.

#### addHelpersCore.sql
- Permissions Required: `superuser`

`addHelpers.sql` creates several helper functions that are used internally by ClassDB.

#### addRoleBaseMgmtCore.sql
- Permissions Required: `superuser`

`addRoleBaseMgmtCore.sql` creates the base ClassDB role system, which all other ClassDB roles are based on.

#### addUserMgmtCore.sql
- Permissions Required: `superuser`

`addUserMgmtCore.sql` creates tables for logging information about ClassDB users.

#### initializeDBCore.sql
- Permissions Required: `superuser`

`initializeDBCore.sql` sets appropriate permissions for each ClassDB role on the current database, and creates the ClassDB schema.


### Optional Scripts

#### addAllDBOpt.psql
- Permissions Required: `superuser`

`addAllDBOpt.psql` is a psql helper script that runs all of the optional database-level installation scripts at once.

#### addCatalogMgmtOpt.sql
- Permissions Required: None

`addCatalogMgmtOpt.sql` provides two helper functions intended to be used by students. These functions provide an easy way for a student to list all tables in a schema, and to get information about all columns in a given table.


### Recommend Scripts

#### addAllDBReco.psql.psql
- Permissions Required: `superuser`

`addAllDBReco.psql` is a psql helper script that runs all of the recommend database-level installation scripts at once.

#### addDisallowSchemaDropReco.sql
- Permissions Required: `superuser`

`addDisallowSchemaDropReco.sql` provides functions to let instructors and dbmanagers control whether students can drop any schema. This script by default disallows students from dropping any schema. When schema-drop is disallowed, students are prevented from executing the statements `DROP SCHEMA` and `DROP OWNED BY`.

#### addConnectionActivityLoggingReco.sql
- Permissions Required: `superuser`

`addConnectionActivityLoggingReco.sql` provides a function to record connections made by ClassDB users to the DBMS in `ClassDB.ConnectionActivity`. This function imports Postgres' external server logs to get connection records. `enableConnectionLoggingReco.psql` must also be run in order for connection logging to function.

#### addConnectionMgmtReco.sql
- Permissions Required: `superuser`

`addConnectionMgmtReco.sql` provides several function allowing instructors and dbmanagers to monitor and shutdown connections to the Postgres server.

#### addDDLActivityLoggingReco.sql
- Permissions Required: `superuser`

`addDDLActivityLoggingReco.sql` provides DDL statement logging for all ClassDB users. This script installs triggers that record every DDL statement performed by a ClassDB user in `ClassDB.DDLActivity`.

#### addFrequentViewsReco.sql
- Permissions Required: `superuser`

`addFrequentViewsReco.sql` provides several views accessible to ClassDB users summarizing user data and activity. A detailed description of each can be found [here](Frequent-User-Views).



## Server-Level

#### addAllToServer.psql
- Permissions Required: `superuser`

`addAllToServer.psql` installs all server level ClassDB components. This is useful if you want to perform a full installation without selecting individual components to install.

### Core Scripts

#### addAllServerCore.psql
- Permissions Required: `superuser`

`addAllServerCore.psql` is a psql helper script that install all of the core server-level components at once.

#### initializeServerCore.sql
- Permissions Required: `superuser`

`initializeServerCore.sql` performs server level configuration for ClassDB, and should be run once per Postgres instance. It creates the five server-level roles that are used by ClassDB:

- `classdb_instructor`
- `classdb_student`
- `classdb_dbmanager`
- `classdb_team`
- `classdb`

These roles are explained in detail in the [Roles overview](Roles).


### Recommend Scripts

#### addAllServerReco.psql
- Permissions Required: `superuser`

`addAllServerReco.psql` is a psql helper script that install all of the recommend server-level components at once.

#### enableConnectionLoggingReco.psql and disableConnectionLoggingReco.psql
- Permissions Required: `superuser`

 `enableConnectionLoggingReco.psql` modifies the Postgres logging system configuration. These changes cause Postgres to log connections made to the DBMS in the external server logs. This is intended to be used with `addConnectionActivityLoggingReco.sql` to log connections made by ClassDB users to the DBMS.
 `disableConnectionLoggingReco.psql` turns off server connection logging. Thus, it only needs to be run if you want to disable connection logging after running `enableConnectionLoggingReco.psql`.
 We recomend that psql be used to run these scripts.



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

### removeAllFromDB.sql

`removeAllFromDB.sql` removes all ClassDB database level components from a single database. This includes the ClassDB schema and all contained objects, the catalog management functions, and the DDL monitoring triggers. It makes efforts to not interfere with user data - user schemas are not removed, and the uninstall will fail if there are user-created objects dervided from ClassDB objects.

### removeAllFromServer.sql

`removeAllFromServer.sql` removes all ClassDB server level components. This includes all the ClassDB roles. `removeAllFromDB.sql` must be run on all database ClassDB is installed on before `removeAllFromServer.sql` can be used.

---
