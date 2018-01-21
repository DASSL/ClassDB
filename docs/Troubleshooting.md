[ClassDB Home](Home) \| [Table of Contents](Table-of-Contents)

---
# Troubleshooting

_Author: Andrew Figueroa_


Although ClassDB is designed to be easy to use and cause minimal issues, some problems or concerns could occur during use. This page describes these issues and potential solutions.

## Cannot connect to the database

| Cause | Solution |
| ----- | -------- |
| Username is not correct | Ensure the user name is correct and that the user has been created. Keep in mind that user names are case-sensitive. See the [Adding Users](Adding-Users) page and [Postgres' documentation](https://www.postgresql.org/docs/current/static/sql-syntax-lexical.html#SQL-SYNTAX-CONSTANTS) for more information on identifier quoting and folding. |
| Password is not correct | Use the correct password. If the password has been forgotten, it can [be reset](Changing-Passwords#resetting-a-forgotten-password) by an instructor or DB manager. |
| Connection information is not correct or the server is refusing connections. | Ensure the server, port, and database information is correct and that it is being given to the client in the proper format. Also ensure that the PostgreSQL instance is running and has been configured to accept connections from the user's computer. |
| User is a student and has too many connections open | [Close stray connections](Managing-User-Connections#killing-user-connections). If this becomes a recurring problem, consider [raising the Connection Limit](Student-Limitations#number-of-connections) and/or using a different client. |


## Issues with queries

| Cause | Solution |
| ----- | -------- |
| Query is improperly formatted or too complex | Fix issues with the query and/or reduce the complexity of the query. |
| User is a student and is executing a complex query | The query may be timing out due to the statement timeout that is set on student users. [Increase the timeout](Student-Limitations#query-timeout) if necessary. |
| Connection to the database has been lost | Reestablish the connection to the database. |

## Log files are too large

| Cause | Solution |
| ----- | -------- |
| Old log files are being maintained longer than necessary | By default, ClassDB sets log files to be maintained for up to 1 year. If this is not necessary, they can be [manually removed](Managing-Log-Files#free-log-storage-space). |
| Too many users are using the Postgres instance | Reduce the number of users, or implement other solutions to reduce the size of log files. |
| Log verbosity is set too high | By default, Postgres may set the log verbosity to a value that is higher than necessary. See [Managing Log Files](Managing-Log-Files#free-log-storage-space) or the [Postgres documentation](https://www.postgresql.org/docs/9.6/static/runtime-config-logging.html) for more information. |


***
