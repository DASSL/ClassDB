[ClassDB Home](Home) \| [Table of Contents](Table-of-Contents)

---
# User Logging

_Authors: Steven Rollo, Sean Murthy_

The ClassDB user logging system, created with `enableServerLogging.sql`, `addDDLMonitors.sql`, and `addLogMgmt.sql`, records the level of activity of each student user. Two specific metrics are recorded, DDL statements executed, and connections made to the DBMS. The systems for logging each metric are independent, and do not need to be installed together. This document will demonstrate how to work with both logging components.

## DDL Statement Logging
ClassDB contains two event triggers that automatically execute a function when a DDL statement is executed. This function adds a new row to `ClassDB.DDLActivity`, a table which records every DDL operation performed by ClassDB users. The following table describes each column:

| Column | Type | Description |
| ------ | ---- | ----------- |
| `UserName` | `IDDomainName` | The user name of the ClassDB user that performed this DDL operation |
| `StatementStartedAtUTC` | `TIMESTAMP` | The timestamp (at UTC) at which this DDL operation was started |
| `DDLOperation` | `VARCHAR` | The DDL operation (ex. `CREATE TABLE`) performed | 
| `DDLObject` | `VARCHAR` | The schema qualified object created or modified by this DDL operation |

There are also four columns in `ClassDB.User` which show the total number of DDL operations performed by that user, as well as information about the last DDL operation performed by each user. These columns are derived from `ClassDB.DDLActivity`. The following table gives an overview of each column:

| Column | Type | Description |
| ------ | ---- | ----------- |
| `DDLCount` | `INT` | The total number of DDL statements executed |
| `LastDDLOperation` | `VARCHAR` |  The latest DDL operation (ex. `CREATE TABLE`) performed |
| `LastDDLObject` | `VARCHAR` | Name of the object modified by the latest DDL statement executed |
| `LastDDLActivityATUTC` | `TIMESTAMP` | The timestamp (at UTC) at which the latest DDL operation was started |


## Connection Logging
ClassDB is also able to record each connection made to the server by ClasDB users. Unlike DDL statement logging, connection logging is not fully automated. While each connection to the DBMS is automatically recorded in Postgres' log file, `ClassDB.importLog()` must be manually executed to update the connection activity log. The Postgres log files record many database activities - only some are related to user connections.  For example, the following line is from an automated database process:
```
2017-07-06 02:49:01.234 EDT,,,5052,,59492bbe.13bc,9063,,2017-06-20 10:05:50 EDT,,0,LOG,00000,"checkpoint starting: time",,,,,,,,,""
```
Connection lines generally appear in pairs, one when a connection first contacts the DBMS, and another when the connection is authorized. Below is an example of a single connection being established:
```
2017-07-06 08:57:03.187 EDT,,,9996,"10.10.10.10:34422",595e339f.270c,1,"",2017-07-06 08:57:03 EDT,,0,LOG,00000,"connection received: host=10.10.10.10 port=34422",,,,,,,,,""
2017-07-06 08:57:03.250 EDT,"postgres","postgres",9996,"10.10.10.10:34422",595e339f.270c,2,"",2017-07-06 08:57:03 EDT,2/2681967,0,LOG,00000,"connection authorized: user=postgres database=postgres",,,,,,,,,""
```

Note that ClassDB configures the Postgres instance to store the logs in a CSV format. This allows the `ClassDB.importLog()` function to easily import the log contents into a temporary table, and then process the log to update student connection information.

ClassDB stores one row for each connection to the server from a ClassDB user in `ClassDB.ConnectionActivity`. The following tables describes its columns:

| Column | Type | Description |
| ------ | ---- | ----------- |
| `UserName` | `IDNameDomain`  | The user name of the ClassDB user causing the connection | 
| `AcceptedAtUTC` | The timestamp (at UTC) the connection was accepted by the server |
 
Additionally, `ClassDB.User` contains two columns related to connection logging, summarized in the following table:

| Column | Type | Description |
| ------ | ---- | ----------- |
| `ConnectionCount` | `INT` | The total number of connections made to the DBMS. Note that since many clients establish multiple connections per session, this number is usually higher than the actual number of times a student has used the DBMS |
| `LastConnectionConnectionAtUTC` | `TIMESTAMP` | Timestamp (in UTC) of the last connection made to the DBMS |


## Importing the Connection Logs
Any Instructor or DBManager has permissions to import the connection logs. To import the connection logs and update the connection activity table, simply execute:
```sql
SELECT ClassDB.importLog();
```
The procedure is slightly different the first time you import the logs. `ClassDB.importLog()` checks the newest connection date in `ClassDB.ConnectionActivity` to figure out which files to import. If no Student has previously connected, this information is not present. The function accepts an optional `DATE` parameter for this situation. When supplied, all logs between the given date and current date will be imported. Again, this is only necessary if no Student has a lastConnection date. If the following query returns NULL, it confirms that no student has a connection recorded:
```sql
date((SELECT ClassDB.ChangeTimeZone(MAX(AcceptedAtUTC))
      FROM ClassDB.ConnectionActivity))
```
---
