[ClassDB Home](Home) \| [Table of Contents](Table-of-Contents)

---
# Changing Passwords

_Authors: Steven Rollo, Andrew Figueroa_

Postgres provides multiple ways to change a user's password. ClassDB also provides a function to reset a password that a user has forgotten. This document demonstrates a recommended method for changing a user's password and how to reset a password for a user.

## Modifying a Password

### Using psql (Recommended)
The recommended way to change a user's password is through psql's `\password` meta-command. Executing this command causes psql to prompt the user to enter a new password, twice for confirmation. For security purposes, the new password is not displayed while it is being typed in. The user can then keep their current session open after using this password. In the future, they will need to use their new password to connect to a database.

### Using ALTER ROLE
Postgres' `ALTER ROLE` statement can be used to change the password of a user, but this is not recommended for two reasons. First, this method requires that the user execute a query containing their password in plain text. In a command-line client like psql, their plain text password will be kept in the command history. Second, Postgres stores the full text of executed queries, at least temporarily. For example, the `pg_stat_activity` system view shows the full text of the last query sent by each connection. Therefore, when using an `ALTER ROLE` statement with their password, it will be stored in plain text for some time.

ClassDB does use `ALTER ROLE` internally to reset user passwords, however this is only intended to set a temporary password that the user will change as soon as possible.

## Resetting a Forgotten Password

One of the more common issues that will occur during the use of ClassDB is a user forgetting their password. Because of this, ClassDB provides a `ClassDB.resetPassword()` function which takes one parameter and can be executed by an Instructor or DBManager:

- `roleName` - The user name of the user who requires a password reset

This function will reset the given user's password to their user name. This is not necessarily the same as the `initialPassword` given during the creation of the user. Additionally, this function will work on any server role, not just ClassDB users.

---
