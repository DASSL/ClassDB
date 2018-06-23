[ClassDB Home](Home) \| [Table of Contents](Table-of-Contents)

---
# Frequent User Views

_Author: Steven Rollo_

ClassDB v2.0.0 adds several 'Frequent User Views', a set of functions and views providing ClassDB users with a simplified interface summarizing user data and activity. Some of these objects are intended to be used only by instructors, while some are intended for use by any ClassDB user. The instructor views display user and student activity, such as all tables owned by students or all connections to the server made by students.

A summary of the Frequent User Views developed is below. Objects that provide different interfaces to the same information are grouped together. For example, the function `ClassDB.getStudentActivitySummary()` and the view `ClassDB.StudentActivitySummary`.

Note that much of information displaed by the Frequent User Views is collected by the [DDL and connection activity logging components](Activity-Logging). These components must be installed for most of these views to display any information. See the [setup](Setup#component-installation) page for more information.


## Instructor Views


### `ClassDB.StudentTable`
This view displays a list of all tables and views owned by students. All information is taken from `pg_catalog.pg_tables` and `pg_catalog.pg_views`.

| Column | Type | Description |
| ------ | ---- | ----------- |
| `UserName` | `VARCHAR` | Student owning the table |
| `SchemaName` | `VARCHAR` | The schema the table is in |
| `TableName` | `VARCHAR` | The name of the table |
| `TableType` | `VARCHAR` | The type of the table (table or view) |


### `ClassDB.StudentTableCount`
This view displays the total number of tables and view each student currently owns. This view uses an aggregate query over `ClassDB.StudentTable` to get the table count.

| Column | Type | Description |
| ------ | ---- | ----------- |
| `UserName` | `VARCHAR` | The student's user name |
| `StudentTableCount` | `BIGINT` | The number of tables and views the student owns |


### User and Student Activity Summaries
The following objects display activity summaries for either ClassDB users or students. All objects have the same return schema. All functions take a single parameter, the user name to get an activity summary for. Additionally, supplying the default parameter of `NULL` will return activity summaries for either all ClassDB users of students.

#### `ClassDB.getUserActivitySummary(VARCHAR)`
This function returns the activity summary for the specified user.

#### `ClassDB.getStudentActivitySummary(VARCHAR)`
This function returns the activity summary for the specified student.

### `ClassDB.StudentActivitySummary`
This view displays activity summaries for all students using `ClassDb.getStudentActivitySummary()`.

| Column | Type | Description |
| ------ | ---- | ----------- |
| `UserName` | `ClassDB.IDNameDomain` | The user name of the user |
| `DDLCount` | `BIGINT` | The total number of DDL operations the user has performed |
| `LastDDLOperation` | `VARCHAR` | The last DDL operation the user performed (ex. `CREATE TABLE`) |
| `LastDDLObject` | `VARCHAR` | The schema-qualified name of the object modified by the user's last DDL operation |
| `LastDDLActivityAt` | `TIMESTAMP` | The time (at local time) the user last performed a DDL operation |
| `ConnectionCount` | `BIGINT` | The total number of times the user has connected to the server |
| `LastConnectonAt` | `TIMESTAMP` | The time (at local time) of the last connection the user made to the server |


### Anonymized Student Activity Summaries
These objects display anonymized activity summaries for ClassDB students. Usernames are not displayed in the query results, and schema names are removed. All functions take a single parameter, the user name to get activity records for. Additionally, supplying the default parameter of `NULL` will return activity records for either all ClassDB users of students. Both objects have the same return schema.

#### `ClassDB.getStudentActivitySummaryAnon(VARCHAR)`
This function returns an anonymized activity summary for the specified user.

#### `ClassDB.StudentActivitySummaryAnon`
This view displays anonymized activity summaries for all students using `ClassDB.getStudentSummaryAnon()`.

| Column | Type | Description |
| ------ | ---- | ----------- |
| `DDLCount` | `BIGINT` | The total number of DDL operations the student has performed |
| `LastDDLOperation` | `VARCHAR` | The last DDL operation the student performed (ex. `CREATE TABLE`) |
| `LastDDLObject` | `VARCHAR` | The name of the object modified by the student's last DDL operation. The schema name is explicitly remove to protect privacy. |
| `LastDDLActivityAt` | `TIMESTAMP` | The time (at local time) the student last performed a DDL operation |
| `ConnectionCount` | `BIGINT` | The total number of times the student has connected to the server |
| `LastConnectonAt` | `TIMESTAMP` | The time (at local time) of the last connection the student made to the server |


### User and Student Activity Records
The following objects display all connection and DDL activity records for either ClassDB users or students. All objects have the same return schema. All functions take a single parameter, the user name to get activity records for. Additionally, supplying the default parameter of `NULL` will return activity records for either all ClassDB users of students.

#### `ClassDB.getUserActivity(VARCHAR)`
This function returns all activity records for the specified user.

#### `ClassDB.getStudentActivity(VARCHAR)`
This function returns all activity records for the specified student.

### `ClassDB.StudentActivity`
This view displays activity records for all students using `ClassDB.getStudentActivity()`.


| Column | Type | Description |
| ------ | ---- | ----------- |
| `UserName` | `ClassDB.IDNameDomain` | The user name of the user |
| `ActivityAt` | `TIMESTAMP` | The time (at local time) the activity occured |
| `ActivityType` | `VARCHAR` | The type of activity - `Connection`, `Disconnection`, or `DDL Query` |
| `SessionID` | `VARCHAR(17)` | The unique session ID of the user generating the activity |
| `ApplicationName` | `ClassDB.IDNameDomain` | The application name provided by the client used |
| `DDLOperation` | `VARCHAR` | The DDL operation the user performed (ex. `CREATE TABLE`). Always `NULL` for connection activities |
| `DDLObject` | `VARCHAR` | The schema-qualified name of the object modified by the user's DDL operation. Always `NULL` for connection activities |


### Anonymized Student Activity Records
These objects display anonymized activity records for ClassDB students. Usernames are not displayed in the query results, and schema names are removed. All functions take a single parameter, the user name to get activity records for. Additionally, supplying the default parameter of `NULL` will return activity records for either all ClassDB users of students. Both objects have the same return schema.

#### `ClassDB.getStudentActivityAnon(VARCHAR)`
This function returns an anonymized activity summary for the specified user.

#### `ClassDB.StudentActivityAnon`
This view displays anonymized activity records for all students using `ClassDB.getStudentActivityAnon()`.

| Column | Type | Description |
| ------ | ---- | ----------- |
| `ActivityAt` | `TIMESTAMP` | The time (at local time) the activity occured |
| `ActivityType` | `VARCHAR` | The type of activity - `Connection`, `Disconnection`, or `DDL Query` |
| `SessionID` | `VARCHAR(17)` | The unique session ID of the user generating the activity |
| `ApplicationName` | `ClassDB.IDNameDomain` | The application name provided by the client used |
| `DDLOperation` | `VARCHAR` | The DDL operation the user performed (ex. `CREATE TABLE`). Always `NULL` for connection activities |
| `DDLObject` | `VARCHAR` | The sname of the object modified by the user's DDL operation. The schema name is explicitly remove to protect privacy. Always `NULL` for connection activities |


## Views For All ClassDB Users

### User Activity Summary
The following objects return the current user's activity summary. Both objects have the same return schema.

#### `public.getMyActivitySummary()`
This function returns the activity summary of the invoking user by calling `ClassDB.getUserActivitySummary(SESSION_USER)`

#### `public.MyActivitySummary`
This view displays the querying user's activity summary by calling `public.getMyActivitySummary()`.

| Column | Type | Description |
| ------ | ---- | ----------- |
| `DDLCount` | `BIGINT` | The total number of DDL operations the user has performed |
| `LastDDLOperation` | `VARCHAR` | The last DDL operation the user performed (ex. `CREATE TABLE`) |
| `LastDDLObject` | `VARCHAR` | The schema-qualified name of the object modified by the user's last DDL operation |
| `LastDDLActivityAt` | `TIMESTAMP` | The time (at local time) the user last performed a DDL operation |
| `ConnectionCount` | `BIGINT` | The total number of times the user has connected to the server |
| `LastConnectonAt` | `TIMESTAMP` | The time (at local time) of the last connection the user made to the server |


### User DDL Activity
The following objects return a list of a user's DDL activities. Both objects have the same return schema.

#### `public.getMyDDLActivity()`
This function returns a list of DDL activities for the invoking user.

#### `public.MyDDLActivity`
This view displays a list of the user's DDL activities by calling `public.getMyDDLActivity()`.

| Column | Type | Description |
| ------ | ---- | ----------- |
| `StatementStartedAt` | `TIMESTAMP` | The time (at local time) the DDL operation was started |
| `SessionID` | `VARCHAR(17)` | The unique session ID of the user generating the activity |
| `DDLOperation` | `VARCHAR` | The DDL operation the user performed (ex. `CREATE TABLE`) |
| `DDLObject` | `VARCHAR` | The schema-qualified name of the object modified by the user's DDL operation |


### User Connection Activity
The following objects return a list of a user's connection activities. Both objects have the same return schema.

#### `public.getMyConnectionActivity()`
This function returns a list of connection activities for the invoking user.

#### `public.MyConnectionActivity`
This view displays a list of the user's connection activities by calling `public.getMyConnectionActivity()`.

| Column | Type | Description |
| ------ | ---- | ----------- |
| `ActivityAt` | `TIMESTAMP` | The time (at local time) the connection was accepted by the server |
| `ActivityType` | `VARCHAR` | The type of activity - `Connection`, `Disconnection` |
| `SessionID` | `VARCHAR(17)` | The unique session ID of the user generating the activity |
| `ApplicationName` | `ClassDB.IDNameDomain` | The application name provided by the client used |


### Combined User Activity
The following objects return a combined list of a user's connection and DDL activities. Both objects have the same return schema.

#### `public.getMyActivity()`
This function returns a list of connection and DDL activities for the invoking user.

#### `public.MyActivity`
This view displays a list of the user's connection and DDL activities by calling `public.getMyActivity()`.

| Column | Type | Description |
| ------ | ---- | ----------- |
| `ActivityAt` | `TIMESTAMP` | The time (at local time) the activity occured |
| `ActivityType` | `VARCHAR` | The type of activity - `Connection`, `Disconnection`, or `DDL Query` |
| `SessionID` | `VARCHAR(17)` | The unique session ID of the user generating the activity |
| `ApplicationName` | `ClassDB.IDNameDomain` | The application name provided by the client used |
| `DDLOperation` | `VARCHAR` | The DDL operation the user performed (ex. `CREATE TABLE`). Always `NULL` for connection activities |
| `DDLObject` | `VARCHAR` | The schema-qualified name of the object modified by the user's DDL operation. Always `NULL` for connection activities |


## Additional Information
All of the Frequent User Views are derived from the core ClassDB objects in the `ClassDB` schema. This poses an issue, since several of these views are intended for student use, but students cannot access the ClassDB schema. To solve this issue, we developed two sets of criteria. [The first](Views-and-Functions) details when an object should be a function versus a view, and [the second](Object-Placement) details when an object should be placed in the `ClassDB` schema versus the `public` schema.

Using these criteria, we developed the solution summarized below:
- Objects intended for use by end-users, particularly students, should be views
- Objects only need be functions if they access other objects the invoker does not have permission to access
- Only objects that are directly accessible to students should be placed in the `public` schema
- Thus, objects accessible to students, but requiring elevated permissions should consist of three parts:
  1. A function in the `ClassDB` schema that access restricted objects
  2. A function in the `public` schema executable by students, using `SECURITY DEFINER` to maintain access to `ClassDB`
  3. A view in the `public` schema the presents the public function as a view
