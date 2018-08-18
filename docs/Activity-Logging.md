[ClassDB Home](Home) \| [Table of Contents](Table-of-Contents)

---
# Activity Logging

_Authors: Steven Rollo, Sean Murthy_

The ClassDB activity logging system can log two distinct kinds of activities of each user: DDL statements executed and connections made to the DBMS. The two logs are independent of each other and are managed using separate scripts: 
- `addDDLActivityLoggingReco.sql` adds DDL logging to the database
- `addConnectionActivityLoggingReco.sql` adds connection logging to the database
- `enableConnectionLoggingReco.psql` enables connection logging on the server: logging must be enabled at the server level to enable logging connection details for any database on the server 
- `disableConnectionLoggingReco.psql` disables connection logging on the server

Each log kind is maintained in a dedicated table: `ClassDB.DDLActivity` records DDL activity; `ClassDB.ConnectionActivity` records connection information. Rows in these tables may be manipulated only through the ClassDB API with the exception that the `ClassDB` role or a superuser is able to directly truncate the tables (that is, run a `TRUNCATE` query). 

**Note:** For ease of implementation, tables `ClassDB.DDLActivity` and `ClassDB.ConnectionActivity` are present even if their corresponding logging component is not installed. The tables are populated only when the appropriate logging component is active.

## DDL Activity Logging
ClassDB uses event triggers to add a new row to table `ClassDB.DDLActivity` when a ClassDB user executes any DDL statement. The columns in the table are:

| Column | Type | Description |
| ------ | ---- | ----------- |
| `UserName` | `IDDomainName` | The user name of the ClassDB user that performed this DDL operation |
| `StatementStartedAtUTC` | `TIMESTAMP` | The timestamp (at UTC) at which this DDL operation was started |
| `DDLOperation` | `VARCHAR` | The DDL operation (ex. `CREATE TABLE`) performed | 
| `DDLObject` | `VARCHAR` | The schema qualified object created or modified by this DDL operation. |
| `SessionID` | `VARCHAR(17)` | The unique Session ID of the user performing the query |

**Postgres compatibility:** The column `DDLObject` contains the fixed value `N/A` for rows logged in Postgres 9.4 or earlier (because the facility to obtain object names is unavailable in earlier Postgres versions).

The following columns in the view `ClassDB.User` provide a summary of DDL operations performed by each user. These columns are present even if DDL logging is not presently enabled. The columns are populated only if DDL logging has ever been enabled on the database (if the log table is not empty, to be precise):

| Column | Type | Description |
| ------ | ---- | ----------- |
| `DDLCount` | `INT` | The total number of DDL statements executed |
| `LastDDLOperation` | `VARCHAR` |  The latest DDL operation (ex. `CREATE TABLE`) performed |
| `LastDDLObject` | `VARCHAR` | Name of the object modified by the latest DDL statement executed |
| `LastDDLActivityAtUTC` | `TIMESTAMP` | The timestamp (at UTC) at which the latest DDL operation was started |


## Connection Activity Logging
ClassDB is also able to record each connection to and disconnection from the server by ClasDB users. Unlike DDL logging, connection logging is not fully automated (for efficiency reasons). While each connection activity is automatically recorded in Postgres' log file, `ClassDB.importConnectionLog()` must be manually executed to update the connection activity log. The Postgres log files record many database activities - only some are related to user connections.  For example, the following line is from an automated database process:
```
2017-07-06 02:49:01.234 EDT,,,5052,,59492bbe.13bc,9063,,2017-06-20 10:05:50 EDT,,0,LOG,00000,"checkpoint starting: time",,,,,,,,,""
```
Individual connections from a client often consist of two to three lines, one or two when a connection first contacts the DBMS, and another when the connection is authorized. Only lines showing the message `connection authorized` denote successful connections. Below is an example of a single connection being established:
```
2017-07-06 08:57:03.187 EDT,,,9996,"10.10.10.10:34422",595e339f.270c,1,"",2017-07-06 08:57:03 EDT,,0,LOG,00000,"connection received: host=10.10.10.10 port=34422",,,,,,,,,""
2017-07-06 08:57:03.250 EDT,"postgres","postgres",9996,"10.10.10.10:34422",595e339f.270c,2,"",2017-07-06 08:57:03 EDT,2/2681967,0,LOG,00000,"connection authorized: user=postgres database=postgres",,,,,,,,,""
```
Disconnections typically consist of a single line with a message showing `disconnection`. For example:
```
2018-06-20 17:55:52.677 UTC,"postgres","postgres",3189,"10.10.10.10:53322",5b2a9527.c75,3,"idle",2018-06-20 17:55:51 UTC,,0,LOG,00000,"disconnection: session time: 0:00:00.725 user=postgres database=postgres host=10.10.10.10 port=53322",,,,,,,,,"psql"
```

Note that ClassDB configures the Postgres instance to store the logs in a CSV format. This allows the `ClassDB.importConnectionLog()` function to easily import the log contents into a temporary table, and then process the log to update connection information.

**Postgres compatability:** The scripts to enable and disable connection logging use features added in Postgres 9.4 and thus cannot be run in Postgres 9.3 or earlier. However, connection logging is supported in Postgres 9.3 provided it is manually configured in the file `postgresql.conf` located in Postgres' data directory. The Postgres server instance should be restarted after manually changing the settings.

To enable connection logging, set:

- `log_destination` = `'csvlog'`
- `log_filename` = `'postgresql-%m.%d.log'`
- `log_connections` = `'on'`
- `log_disconnections` = `'on'`
- `logging_collector` = `'on'`

To disable connection logging, set:

- `logging_collector` = `'off'`

The location of the data directory can be found with the following command:
```sql
SHOW data_directory;
```

### Connection Activity Table
ClassDB stores one row per connection to or disconnection from a ClassDB user in table `ClassDB.ConnectionActivity`. The columns in this table are as follows:

| Column | Type | Description |
| ------ | ---- | ----------- |
| `UserName` | `IDNameDomain`  | The user name of the ClassDB user causing the connection | 
| `AcceptedAtUTC` | The timestamp (at UTC) the connection was accepted by the server |
| `ActivityType` | `CHAR(1)` | Is this row from a connection (`C`) or disconnection (`D`) |
| `SessionID` | `VARCHAR(17)` | A unique session ID generate by Postgres for this connection |
| `ApplicationName` | `ClassDB.IDNameDomain` | The application name string provided by the client application |
 
Additionally, the view `ClassDB.User` contains two columns related to connection logging, summarized in the following table:

| Column | Type | Description |
| ------ | ---- | ----------- |
| `ConnectionCount` | `INT` | The total number of connections made to the DBMS. Note that since some clients establish multiple connections per session, this number may be high than the number of times a student has actually used the DBMS |
| `LastConnectionConnectionAtUTC` | `TIMESTAMP` | Timestamp (in UTC) of the last connection made to the DBMS |


## Importing Connection Logs
Any Instructor or DBManager has permissions to import the connection logs. To import the connection logs and update the connection activity table, simply execute:
```sql
SELECT * FROM ClassDB.importConnectionLog();
```
The procedure is slightly different the first time you import the logs. `ClassDB.importConnectionLog()` checks the newest activity date in `ClassDB.ConnectionActivity` to figure out which files to import. If no connection activity data is present, the function will only try to import the log from the current date. To manually select which logs should be imported, an optional `DATE` parameter can be supplied to `ClassDB.importConnectionLog()`. When supplied, all logs between the given date and current date will be imported. 

If the following query returns `NULL`, it confirms that no connection activity is present:
```sql
date((SELECT ClassDB.ChangeTimeZone(MAX(ActivityAtUTC))
      FROM ClassDB.ConnectionActivity))
```
---
