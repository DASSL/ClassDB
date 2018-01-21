[ClassDB Home](Home) \| [Table of Contents](Table-of-Contents)

---
# Revoking Roles

_Author: Andrew Figueroa_

Revoking a role involves revoking one of the group roles that the user had assigned to them. As such, they will no longer be considered a student, instructor, or DB manager, depending on what group role is being revoked. However, they still remain a known user within ClassDB, and will retain any other roles they may have had previously assigned to them.

After a user has a group role successfully revoked, they will still appear in the `User` view, but will not show as having the group role that was revoked, nor will they appear in the corresponding `Student`, `Instructor`, or `DBManager` view.

In ClassDB, revoking a role from a user _only_ results in removing the privileges (and possibly restrictions, in the case of students) that correspond to one of [ClassDB's group roles](Roles) that the user had assigned to them.

To do any of the following, the user must be [dropped](Dropping-Roles) instead:

- Remove the user from ClassDB's records

- Drop their corresponding server-level role

- Make any changes to all objects the user owned

## Functions

The following are partial definitions of the three functions used to revoke roles from users. Data types of parameters have been modified from their internal referential representation to their effective types.


```
ClassDB.revokeStudent(userName VARCHAR(63))

ClassDB.revokeInstructor(userName VARCHAR(63))

ClassDB.revokeDBManager(userName VARCHAR(63))
```

## Examples

The following would revoke the student role from a user with a user name of 'bell001':

```sql
SELECT ClassDB.revokeStudent('bell001');
```

Suppose there was a multi-role user with the user name of 'martinl', who was both a Student and DBManager (the most common scenario). To only revoke the DBManager role from the user, then only the following statement should be run:

```sql
SELECT ClassDB.revokeDBManager('martinl')
```

After running the statement, the user would no longer have DB manager privileges within ClassDB, but would maintain their student privileges.

All functions follow the case sensitivity rules described in the [Adding Users](Adding-Users) documentation.

## Additional Notes

In order to revoke the role from a user, the corresponding server-level role should exist, they must be a user that is known to ClassDB, and they must have the corresponding role that is being attempted to be revoked. Otherwise, a corresponding NOTICE will be raised. For more information on determining whether this is true or not, see the [Viewing Registered Users](Viewing-Registered-Users) page.

With an unmodified installation of ClassDB, only users who are registered as one of ClassDB's group roles are able to connect to a database that ClassDB is installed in. ([Superusers](https://www.postgresql.org/docs/current/static/sql-createrole.html) are always able to connect to any database.) This means that if all ClassDB group roles have been revoked from a user, they will not be able to connect a database where ClassDB is installed, even if their server-role still exists and they are registered within ClassDB as a known user. To restore their access, they can be re-granted a ClassDB group role through the [user creation process](Adding-Users), or they can be [manually granted the `CONNECT` privilege](https://www.postgresql.org/docs/9.6/static/sql-grant.html) on the database by a superuser or the database owner.

***
