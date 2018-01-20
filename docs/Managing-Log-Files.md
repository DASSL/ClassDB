[ClassDB Home](Home) \| [Table of Contents](Table-of-Contents)

---
# Managing Log Files

_Author: Steven Rollo_

ClassDB's connection logging facilities rely on the external Postgres server log files. This document explains how ClassDB configures Postgres' logging system and how to monitor log file usage. This information most relevant to ClassDB deployments using the connection logging facility.  

## ClassDB Log File Configuration
If [connection logging is enabled](User-Logging), ClassDB makes several modifications to the Postgres instance's settings. These changes allow ClassDB to retrieve connection information from the logs. The following SQL statements from `enableServerLogging.sql` are used to configure Postgres' log system, followed by a table describing each setting:
```sql
ALTER SYSTEM SET log_connections TO 'on';
ALTER SYSTEM SET log_destination TO 'csvlog';
ALTER SYSTEM SET log_filename TO 'postgresql-%m.%d.log';
SELECT pg_reload_conf();
```

| Setting | Description |
| ------- | ----------- |
| `log_connections TO 'on'` | Causes Postgres to write one line to the log file for each connection established to the DBMS |
| `log_destination TO 'csvlog'` | Causes Postgres to write logs in a csv format instead of plain text |
| `log_filename TO 'postgresql-%m.%d.log'` | Sets the log file name.  `%m` and `%d` are placeholders for the current month and day, respectively |

The function `pg_reload_conf()` applies these settings without having to restart the DBMS.

The above log_filename setting creates one log file for each day of the year.  Postgres automatically rotates the log every day, writing to the appropriate file. For example, on a June 5th, Postgres will write to the log file `postgresql-6.5.log`. At midnight on June 6th, Postgres will stop writing to that file, and begin writing to `postgresql-6.6.log`. Existing files will be truncated and reused. With this system, a maximum of 366 logs will be stored at any given time, one for each possible day of the year.

## Log Storage Space
When dealing with a large number of users, it is possible for the log files to take a modest amount of space. Testing with default log setting plus connection logging has shown that the logs consume about 40KB per user per day with light to moderate usage.

These numbers were not obtained rigorously, since user activity was not controlled. Additionally, Postgres logs a large amount of information related to automatic processes that are unrelated to users. However, this is a reasonable estimate, since the amount of connections logged is more related to number of users, rather than activity. Additionally, an upper limit can be placed on log usage using this estimate, since a maximum of 366 log files are stored at any given time. The following table shows various numbers of daily users, and the estimated maximum log size:

| Daily Users (#) | Maximum Log Size (MB) |
| --------------- | --------------------- |
| 10              | 143                   |
| 25              | 357                   |
| 50              | 715                   |
| 100             | 1,430                 |

## Free Log Storage Space
If you find the logs are taking too much space on your server, there are a few possible remedies.

First, you may manually delete old log files that have already been imported to the server. Execute the following query as a superuser to display the directory where the logs are stored:
```sql
SHOW log_directory;
```
The next query shows the latest connection date imported from the logs. This date also corresponds to the last log file that was imported. Log files matching dates earlier than the one returned may be safely deleted.
```sql
date((SELECT ClassDB.ChangeTimeZone(MAX(AcceptedAtUTC))
      FROM ClassDB.ConnectionActivity));
```

Another method to reduce log size is to reduce the amount of information stored. For example, setting `log_error_verbosity` to `TERSE` will disable the logging of full statements on errors. This can greatly reduce the amount of data logged. For more information about logging configuration, see the [Postgres error reporting and logging documentation.](https://www.postgresql.org/docs/9.6/static/runtime-config-logging.html)

---
