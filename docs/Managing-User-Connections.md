[ClassDB Home](Home) \| [Table of Contents](Table-of-Contents)

---
# Managing User Connections

_Author: Steven Rollo_

While working with ClassDB, you may encounter situations where students are unable to log in because they have reached their connection limit. This document explains how to find and, if necessary, terminate stray connections.

## Listing User Connections
ClassDB provides the `ClassDB.listUserConnections(VARCHAR(63))` function to list user connections. This function takes the name of a user as an input parameter, and returns a table with one row for each active connection by that user. The return table is populated with information about each connection from the system view `pg_stat_activity`. Below is a description of the return table's schema, followed by a short description of each column:
```sql
TABLE
(
   userName VARCHAR(63),
   pid INT,
   applicationName VARCHAR(63),
   clientAddress INET,
   connectionStartTime TIMESTAMPTZ,
   lastQueryStartTime TIMESTAMPTZ
)
```

| Column | `pg_stat_activity` Equivalent | Description |
| ------ | --------------------------------- | ----------- |
| `UserName VARCHAR(63)` | `usename name` | User Name of user that established the connection |
| `PID INT` | `pid INTEGER` | Process ID of the connection Process |
| `ApplicationName VARCHAR(63)` | `application_name TEXT` | A short identifier string sent by the client |
| `ClientAddress INET` | `client_addr INET` | IP address of the client |
| `ConnectionStartTime TIMESTAMPTZ` | `backend_start TIMESTAMPTZ` | Timestamp marking when the connection was established |
| `LastQueryStartTime TIMESTAMPTZ` | `query_start TIMESTAMPTZ` | Timestamp marking when the connection last executed a query |

More information about `pg_stat_activity` can be found in table 28-3 on the [Postgres statistics collector documentation page.](https://www.postgresql.org/docs/9.6/static/monitoring-stats.html)

## Killing User Connections
ClassDB provides two functions that can kill connections to the database. `ClassDB.killUserConnections(VARCHAR(63))` terminates all active connections established by a given user. `ClassDB.killConnection(INT)` terminates a single connection with the given pid. Both functions return `BOOLEAN` values to signal if the termination was successful. `killConnection` returns a single value, while `killUserConnections` returns one for each connection to be terminated. Both functions use `pg_terminate_backend(INT4)` to kill connections. More information about this function can be found on the [Postgres Administration Function Documentation page.](https://www.postgresql.org/docs/9.6/static/functions-admin.html)

## Finding Stray Connections
One common connection problem observed is students being unable to open new connections because they have reached their connection limit. This often occurs when a client fails to close its connection(s) after the student has logged out. Since ClassDB sets a limit of 5 connection per student by default, students can quickly reach their connection limit when their client misbehaves. If you frequently encounter problems with students hitting their connection limit, you may want to consider increasing the connection limit.

### Isolating the Problem
A good first step is to confirm the connection problem is due to the connection limit. The item to check is the error message reported by the student. Most clients display an error message explicitly stating that the current user has reached their connection limit. Other error messages likely mean that the student has entered their connection information incorrectly, or some other network issue is interfering with the connection. Additionally, it is useful to examine the client the student is using. Many students are unaware that clients often open multiple connections to the database, even when only one instance of the client is running.

### Identifying Possible Stray Connections
Once the connection limit has been identified as the likely culprit, the data returned by `ClassDB.listUserConnections(VARCHAR(63))` can be used to find how many connections have been established by a user, when they were established, and what client established them. All three of these metrics are useful for identifying stray connections. The following query displays the number of connections that user currently has open. If this number is equal to the connection limit for Students, then the student has reached their connection limit.
```sql
SELECT userName, COUNT(*) connections
FROM ClassDB.listUserConnections('<username>')
GROUP BY userName;
```

Next, identify which of these connections should be terminated. Running the following query will lists information about all open connections:
```sql
SELECT *
FROM ClassDB.listUserConnections('<username>');
```

 When choosing connections to terminate, it is a good rule of thumb to look for connections that have an older `lastQueryStartTime` timestamp, which shows they have been idle for a longer time. Additionally, you can use this timestamp to separate connections a student may be actively using from ones that are idle.

### Killing Stray Connections
If you wish to kill all of a student's connections, you can simply execute `ClassDB.killUserConnections(VARCHAR(63))`.  However, if you have identified specific connections to kill, you can use `ClassDB.listUserConnections(VARCHAR(63))` to get their pids, then use `ClassDB.killConnection(INT)` to terminate them individually.

---
