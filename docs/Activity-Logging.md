[ClassDB Home](Home) \| [Table of Contents](Table-of-Contents)

---
# Activity Logging

_Authors: Steven Rollo, Sean Murthy_

The ClassDB activity logging system, created with `addConnectionActivityLoggingReco.sql`, `addConnectionMgmtReco.sql`, `addDDLActivityLoggingReco.sql`, and `enableConnectionLoggingReco.sql` records activities of each user. Two specific kinds of activities are recorded: DDL statements executed and connections made to the DBMS. The systems for logging each kind of activity are independent, and do not need to be installed together. This document demonstrates how to work with both logging components.

## DDL Activity Logging
ClassDB contains two event triggers that automatically execute a function when a DDL statement is executed. This function adds a new row to `ClassDB.DDLActivity`, a table which records every DDL operation performed by ClassDB users. The following table describes each column:

| Column | Type | Description |
| ------ | ---- | ----------- |
| `UserName` | `IDDomainName` | The user name of the ClassDB user that performed this DDL operation |
| `StatementStartedAtUTC` | `TIMESTAMP` | The timestamp (at UTC) at which this DDL operation was started |
| `DDLOperation` | `VARCHAR` | The DDL operation (ex. `CREATE TABLE`) performed | 
| `DDLObject` | `VARCHAR` | The schema qualified object created or modified by this DDL operation |
| `SessionID` | `VARCHAR(17)` | The unique Session ID of the user performing the query |

There are also four columns in `ClassDB.User` which show the total number of DDL operations performed by that user, as well as information about the last DDL operation performed by each user. These columns are derived from `ClassDB.DDLActivity`. The following table gives an overview of each column:

| Column | Type | Description |
| ------ | ---- | ----------- |
| `DDLCount` | `INT` | The total number of DDL statements executed |
| `LastDDLOperation` | `VARCHAR` |  The latest DDL operation (ex. `CREATE TABLE`) performed |
| `LastDDLObject` | `VARCHAR` | Name of the object modified by the latest DDL statement executed |
| `LastDDLActivityAtUTC` | `TIMESTAMP` | The timestamp (at UTC) at which the latest DDL operation was started |


## Connection Activity Logging
ClassDB is also able to record each connection to and disconnection from the server by ClasDB users. Unlike DDL statement logging, connection logging is not fully automated. While each connection activity is automatically recorded in Postgres' log file, `ClassDB.importConnectionLog()` must be manually executed to update the connection activity log. The Postgres log files record many database activities - only some are related to user connections.  For example, the following line is from an automated database process:
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

Note that ClassDB configures the Postgres instance to store the logs in a CSV format. This allows the `ClassDB.importConnectionLog()` function to easily import the log contents into a temporary table, and then process the log to update student connection information.

ClassDB stores one row per connection or disconnection to the server from a ClassDB user in `ClassDB.ConnectionActivity`. The following tables describes its columns:

| Column | Type | Description |
| ------ | ---- | ----------- |
| `UserName` | `IDNameDomain`  | The user name of the ClassDB user causing the connection | 
| `AcceptedAtUTC` | The timestamp (at UTC) the connection was accepted by the server |
| `ActivityType` | `CHAR(1)` | Is this row from a connection (`C`) or disconnection (`D`) |
| `SessionID` | `VARCHAR(17)` | A unique session ID generate by Postgres for this connection |
| `ApplicationName` | `ClassDB.IDNameDomain` | The application name string provided by the client application |
 
Additionally, `ClassDB.User` contains two columns related to connection logging, summarized in the following table:

| Column | Type | Description |
| ------ | ---- | ----------- |
| `ConnectionCount` | `INT` | The total number of connections made to the DBMS. Note that since some clients establish multiple connections per session, this number may be high than the number of times a student has actually used the DBMS |
| `LastConnectionConnectionAtUTC` | `TIMESTAMP` | Timestamp (in UTC) of the last connection made to the DBMS |


## Importing the Connection Logs
Any Instructor or DBManager has permissions to import the connection logs. To import the connection logs and update the connection activity table, simply execute:
```sql
SELECT ClassDB.importConnectionLog();
```
The procedure is slightly different the first time you import the logs. `ClassDB.importConnectionLog()` checks the newest activity date in `ClassDB.ConnectionActivity` to figure out which files to import. If no connection activity data is present, the function will only try to import the log from the current date. To manually select which logs should be imported, an optional `DATE` parameter can be supplied to `ClassDB.importConnectionLog()`. When supplied, all logs between the given date and current date will be imported. 

If the following query returns NULL, it confirms that no connection activity is present:
```sql
date((SELECT ClassDB.ChangeTimeZone(MAX(ActivityAtUTC))
      FROM ClassDB.ConnectionActivity))
```
---
