[ClassDB Home](Home) \| [Table of Contents](Table-of-Contents)

---
# Removing Users

_Authors: Andrew Figueroa, Steven Rollo_

Users can be removed (also referred to as "dropped") by calling the appropriate ClassDB function for the type of user being removed. These are `ClassDB.dropStudent()`, `ClassDB.dropInstructor()`, and `ClassDB.dropDBManager()`, for students, instructors, and DB managers respectively. However, there remain two important decisions that have to be made when removing a user:

- What should be done with the server role associated with their user name?
- What should be done with their assigned schema and any other objects they may own?

ClassDB allows the end-user to decide what should be done for each of these two questions. Regardless of the decision made, successful execution of one of the drop user functions will mean that the user is no longer registered as a user in ClassDB's records.

Before dropping a user, it is a good idea to ensure that they do not have any connections to the database that ClassDB is installed in. See [Managing User Connections](Managing-User-Connections) for information on viewing currently connected users.

## Functions

The following are partial definitions of the three functions used to remove users from ClassDB. Data types of parameters have been modified from their internal referential representation to their effective types.

```
ClassDB.dropStudent(userName VARCHAR(63),
                    dropFromServer BOOLEAN DEFAULT FALSE,
                    okIfRemainsClassDBRoleMember BOOLEAN DEFAULT TRUE,
                    objectsDisposition VARCHAR DEFAULT 'assign',
                    newObjectsOwnerName VARCHAR(63) DEFAULT NULL)

ClassDB.dropInstructor(userName VARCHAR(63),
                       dropFromServer BOOLEAN DEFAULT FALSE,
                       okIfRemainsClassDBRoleMember BOOLEAN DEFAULT TRUE,
                       objectsDisposition VARCHAR DEFAULT 'assign',
                       newObjectsOwnerName VARCHAR(63) DEFAULT NULL)

ClassDB.dropDBManager(userName VARCHAR(63),
                      dropFromServer BOOLEAN DEFAULT FALSE,
                      okIfRemainsClassDBRoleMember BOOLEAN DEFAULT TRUE,
                      objectsDisposition VARCHAR DEFAULT 'assign',
                      newObjectsOwnerName VARCHAR(63) DEFAULT NULL)
```

## Parameters

| Parameter | Default Value | Notes |
|-------------------------------------------|-------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `userName`: `VARCHAR(63)` | None - **required parameter** | The user name of the user to be removed |
| `dropFromServer`: `BOOLEAN` | `FALSE` | Whether or not the user's corresponding server-level role should be removed from the server. See the [Removing From Server](#removing-from-server) section for more information |
| `okIfRemainsClassDBRoleMember`: `BOOLEAN` | `TRUE` | Whether or not it is acceptable that the user has a ClassDB role other than the one that is specified by the function used to remove the user.<br/><br/>If `FALSE`, then attempting to remove a multi-role user will fail |
| `objectsDisposition`: `VARCHAR` | `'assign'` | The action to take with the objects the user being dropped currently owns. See the [Object Disposition](#object-disposition) section for more information |
| `newObjectsOwnerName`: `VARCHAR(63)` | `NULL` | The role name that objects will be assigned to if the `assign`/`xfer` option is chosen for `objectsDisposition` |

The `userName` and `newObjectsOwnerName` parameters follow the case-sensitivity and folding rules described in [Adding Users](Adding-Users).

## Removing From Server

Although under all circumstances, successfully dropping a user removes them from ClassDB's records, it may be desired to keep their server-level roles. This can be chosen by through the value of the `dropFromServer` parameter. If `FALSE`, the default value, then the server-level role for the user being dropped is kept. Otherwise, if it set to `TRUE`, then the server-level role is dropped in addition to the user being removed from ClassDB's records.

Removing the server-level role from a user also restricts the options available for object disposition, namely, the `as_is` and `drop` options are no longer available, since those require the server-level role to continue existing. Instead `drop_c` or one of the assign options must be used.

In some cases it may not be possible to drop the server-level role from the user, such as if their role owns objects located in other databases, or if for some reason the server-level role no longer exists.

## Object Disposition

Rather than always dropping all of the objects owned by the user being dropped, ClassDB offers several options to decide what to do with these objects. These are specified with the `objectDisposition` parameter when calling one of the drop user functions, and the `newObjectsOwnerName` parameter if `assign` is used as the object disposition option.

| Option     | Description                                                                                                                                                                                |
|------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `as_is`    | Do nothing with the objects that are owned by the user, leaving them as the owner of these objects. This can only be used if `dropFromServer` is `FALSE`.                                    |
| `drop`     | Restrictively drops the objects owned by the user, meaning objects which are depended on by any other database objects are not dropped. This can only be used if `dropFromServer` is `FALSE` |
| `drop_c`   | Drops objects owned by the user in a "cascading" manner. In addition to dropping objects that the user owns, also drops objects that depend on any objects that the user owns                                                                       |
| `assign`   | Reassigns objects owned by the user being dropped to the role specified by the `newObjectsOwnerName` parameter. This is the default option. If no `newOjectsOwnerName` is specified, then the objects are assigned to the current [`SESSION_USER`](https://www.postgresql.org/docs/9.6/static/functions-info.html#FUNCTIONS-INFO-SESSION-TABLE).                                                                           |

Underscores (`_`) can be replaced with dashes (`-`) for any of the options that contain them. For example, `drop_c` and `drop-c` are equivalent. Additionally, `assign` can be replaced with `xfer`.

In order to assign ownership of objects to a specific role, ClassDB must have the necessary privileges to assign that role to the `classdb` role. In practice, this results in it not being possible to assign ownership of objects to a role that has superuser privileges.

Note when using `drop_c`: Due to the nature of the cascade option and the fact that the object disposition is carried out under the execution context of the `classdb` role, using the `drop_c` option can lead to the possibility of dropping of objects that might want to be maintained.

## Examples

To drop a student from ClassDB that has a user name of `bell001`:

```sql
SELECT ClassDB.dropStudent('bell001');
```

This would remove the corresponding entry in ClassDB, and reassign ownership of the objects owned by the `bell001` role to the user that is executing the statement, but will leave a server-level role named `bell001`.

To also remove the `bell001` role from the server, the following should be run instead:

```sql
SELECT ClassDB.dropStudent('bell001', TRUE);
```

Suppose it was required to remove `bell001` both from ClassDB and the server, while reassign the objects that `bell001` owned to a user with the user name of `calwellj`, the following could be run:

```sql
SELECT ClassDB.dropStudent('bell001', TRUE, TRUE, 'assign', 'caldwellj');
```

Note that since the value for the third parameter, `okIfRemainsClassDBRoleMember`, was `TRUE`, this user would be dropped even if they also had another ClassDB role. If we wanted to ensure that they were not, a value of `FALSE` would be used instead.

Usage of these functions is identical for removing instructors and DB managers, apart from having to use `ClassDB.dropInstructor()` or `ClassDB.dropDBManager()` instead of `ClassDB.dropStudent()`.

## Additional Information

If the `dropFromServer` option is TRUE, then is not possible to drop the role that is currently being used to perform the drop. This means that to remove the last ClassDB user (which will be an instructor or DB manager), it is necessary to call the appropriate drop function from the role that ran the setup script or a superuser.

Since it is not possible to assign ownership of objects to a superuser, the default object disposition behavior cannot be used if logged in as a superuser. Instead, an alternative disposition option, or a different, non-superuser `newObjectsOwnerName` must be used.

***
