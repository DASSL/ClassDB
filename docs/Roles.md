[ClassDB Home](Home) \| [Table of Contents](Table-of-Contents)

---
# ClassDB Roles

_Author: Andrew Figueroa_

ClassDB creates and uses the following [database roles](https://www.postgresql.org/docs/9.6/static/database-roles.html) in the PostgreSQL (Postgres) instance where it is installed:

* `classdb_instructor` for instructors

* `classdb_student` for students

* `classdb_dbmanager` for users who are not instructors, but still perform administrative tasks

* `classdb` for internal ClassDB operations

For ease of reading, the first three roles will be referred to without the "classDB_" prefix in ClassDB's documentation. dbmanager will also be referred to as DB manager.

Each user created by ClassDB is assigned their own schema where they can perform Create, Read, Update, and Delete (CRUD) operations on objects within that schema. This schema will usually be referred to as their "assigned" schema.

A user may be a member of more than one of the roles created by ClassDB, in which case they will have the privileges and restrictions of both roles. In conflicts between the two, privileges supersede restrictions, as the more permissive role will be used in such a situation.


## ClassDB

`classdb` is a role that is used solely for internal operations. In an unmodified instance of ClassDB, this role cannot login or connect to a ClassDB database. However, it is not necessary to do so for any of ClassDB's facilities. Another thing of note is that the `classdb` role is granted to the user who runs the setup for an instance of ClassDB.

After running all of the "Core" ClassDB scripts, the `classdb` role becomes the owner of all ClassDB related functions, tables, and views, except for the following four functions: `listUserConnections()`, `enableDDLActivityLogging()`, `disableDDLActivityLogging()`, and `importConnectionLog()`. These functions remain owned by the user who ran the script due to requiring `superuser` privileges. In addition to being owned by `classdb`, most functions will also run under the security context of the `classdb` role.

## Instructor

As the name implies, users who have the instructor role will typically be instructors in a class that uses an instance of ClassDB. Users with the instructor role are allowed to read from the schema assigned to each student. In addition to this, they are able to view all activity that has been logged (if the logging facilities are enabled), along with having the ability to add or remove DB managers, students, and other instructors.

### ClassDB Capabilities

* Create and drop instructors, students, and DB managers
* Update FullName and ExtraInfo for roles
* View activity logs for all roles (if enabled)
* Reset a user's password

### Privileges

* Owner of assigned schema
* All on `public` schema
* Usage on `classdb` schema
* Usage on students' assigned schemas, including Select on tables and views in those schemas

## DB Manager

A DB manager is a type of user who performs administrative tasks for an instance of ClassDB, but is not considered an instructor in a class that uses ClassDB. It is not necessary to have a DB manager within an instance of ClassDB. A DB manager has all of the same capabilities and privileges of an instructor, but does not have read access on the assigned schema of student roles and cannot Create on the `public` schema.

### ClassDB Capabilities

* Create and drop Instructors, Students, and DBManagers
* Update FullName and ExtraInfo for roles
* View activity logs for all roles (if enabled)
* Reset a user's password

### Privileges

* Owner of assigned schema
* Usage on `classdb` schema
* Read on `public` schema


## Student

Students will typically be students in a class that uses an instance of ClassDB. Students have the fewest privileges of all roles. In a well organized setup, the instance of ClassDB should be completely invisible to students. Instead, from their perspective, they will simply be using a database to experiment with queries or complete assignments. Unlike other roles, students may be limited in the number of connections they can have open, and by the amount of time that a query they execute can run. These two limits exist to reduce the impact that any one student has on a server running an instance of ClassDB.

### ClassDB Capabilities

* View activity logs for activity performed by them (if activity logging is enabled)

### Privileges

* Owner of assigned schema
* Read on `public` schema

### Additional Restrictions

* Optional [connection limit](Configuring ClassDB)
* Optional [query timeout](Configuring ClassDB)


***
