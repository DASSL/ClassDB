[ClassDB Home](Home) \| [Table of Contents](Table-of-Contents)

---
# User Logging

_Authors: Steven Rollo, Sean Murthy_

The ClassDB user logging system, created with `enableServerLogging.sql`, `addDDLMonitors.sql`, and `addLogMgmt.sql`, records the level of activity of each student user. Two specific metrics are recorded, DDL statements executed, and connections made to the DBMS. The systems for logging each metric are independent, and do not need to be installed together. This document will demonstrate how to work with both logging components.

## DDL Statement Logging
ClassDB contains two event triggers that automatically execute a function when a DDL statement is executed. This function modifies four columns in the `classdb.student` table. The following table gives an overview of each column:

| Column | Type | Description |
| ------ | ---- | ----------- |
| `lastDDLActivity` | `TIMESTAMP` | Timestamp (in UTC) of the last DDL statement the student executed |
| `lastDDLOperation` | `VARCHAR(64)` | Tag of the last DDL statement executed, for example `CREATE TABLE` |
| `lastDDLObject` | `VARCHAR(256)` | Name of the object modified by the last DDL statement executed |
| `DDLCount` | `INT` | The total number of DDL statements executed |

## Connection Logging
Unlike DDL statement logging, connection logging is not fully automated. While each connection to the DBMS is automatically recorded in Postgres' log file, `classdb.importLog()` must be manually executed to update the `classdb.student` table. The Postgres log files records many database activities - only some are related to user connections.  For example, the following line is from an automated database process:
```
2017-07-06 02:49:01.234 EDT,,,5052,,59492bbe.13bc,9063,,2017-06-20 10:05:50 EDT,,0,LOG,00000,"checkpoint starting: time",,,,,,,,,""
```
Connection lines generally appear in pairs, one when a connection first contacts the DBMS, and another when the connection is authorized. Below is an example of a single connection being established:
```
2017-07-06 08:57:03.187 EDT,,,9996,"10.10.10.10:34422",595e339f.270c,1,"",2017-07-06 08:57:03 EDT,,0,LOG,00000,"connection received: host=10.10.10.10 port=34422",,,,,,,,,""
2017-07-06 08:57:03.250 EDT,"postgres","postgres",9996,"10.10.10.10:34422",595e339f.270c,2,"",2017-07-06 08:57:03 EDT,2/2681967,0,LOG,00000,"connection authorized: user=postgres database=postgres",,,,,,,,,""
```

Note that ClassDB has configured the Postgres instance to store the logs in a CSV format. This allows the `classdb.importLog()` function to easily import the log contents into a temporary table, and then process the log to update student connection information.

There are two columns in the student table for connection logging, summarized in the following table:

| Column | Type | Description |
| ------ | ---- | ----------- |
| `lastConnection` | `TIMESTAMP` | Timestamp (in UTC) of the last connection made to the DBMS |
| `connectionCount` | `INT` | The total number of connections made to the DBMS. Note that since many clients establish multiple connections per session, this number is usually higher than the actual number of times a student has used the DBMS |

## Importing the Connection Logs
Any Instructor or DBManager has permissions to import the connection logs. To import the connection logs and update the student table, simply execute:
```sql
SELECT classdb.importLog();
```
The procedure is slightly different the first time you import the logs. `classdb.importLog()` relies on dates in the student table to figure out which files to import, however if no Student has previously connected, this information is not present. The function accepts an optional `DATE` parameter for this situation. When supplied, all logs between the given date and current date will be imported. Again, this is only necessary if no Student has a lastConnection date. If the following query returns NULL, it confirms that no student has a connection recorded:
```sql
SELECT MAX(lastConnection)
FROM classdb.student;
```

---
