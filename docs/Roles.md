# ClassDB Roles

ClassDB creates and uses the following [database roles](https://www.postgresql.org/docs/9.6/static/database-roles.html) in the PostgreSQL (Postgres) instance where it is installed:

* `ClassDB_Instructor` for instructors

* `ClassDB_Student` for students

* `ClassDB_DBManager` for users who are not instructors, but still perform administrative tasks

* `ClassDB` for internal ClassDB operations

For ease of reading, the first three roles will be referred to without the `ClassDB_` prefix in ClassDB's documentation.

Each user created by ClassDB is assigned their own schema where they can perform Create, Read, Update, and Delete (CRUD) operations on objects within that schema. This schema will usually be referred to as the `$user` schema.

A user may be a member of more than one of the roles created by ClassDB, in which case they will have the privileges and restrictions of both roles. In conflicts between the two, privileges supersede restrictions, as the more permissive role will be used in such a situation.


## ClassDB

ClassDB is a role that is used solely for internal operations. In an unmodified instance of ClassDB, this role cannot login or connect to the ClassDB database. However, it is not necessary to do so for any of ClassDB's facilities. Another thing of note is that the ClassDB role is granted to the user who runs the setup for an instance of ClassDB.

After running `prepareClassDB.sql`, the ClassDB role becomes the owner of all ClassDB related functions, except for `listUserConnections()`, which remains owned by the user who ran the script. Additionally, most functions will also run under the security context of the ClassDB role. This makes ClassDB the owner of all ClassDB objects, including the `$user` schemas.

## Instructor

As the name implies, users who have the Instructor role will typically be instructors in a class that uses an instance of ClassDB. Users with the Instructor role are the only ones who are allowed to read from `$user` schemas belonging to Students. In addition to this, they are able to view Student logging information in the Student table, along with the ability to add or remove DBManagers, Students, and other Instructors.

### ClassDB Capabilities

* Create and drop Instructors, Students, and DBManagers
* Update studentName and schoolID for Students
* Update instructorName for Instructors
* Reset a user's password

### Privileges

* All on `$user` schema
* All on `public` schema
* All on `classdb` schema
* Read on Students `$user` schemas

## DBManager

A DBManager is a type of user who performs administrative tasks for an instance of ClassDB, but is not considered an instructor in a class that uses ClassDB. It is not necessary to have a DBManager within an instance of ClassDB. A DBManager has all of the same capabilities and privileges of an instructor, but does not have read access on the `$user` schema of Student roles and cannot create on the `public` schema.

### ClassDB Capabilities

* Create and drop Instructors, Students, and DBManagers
* Update studentName and schoolID for Students
* Update instructorName for Instructors
* Reset a user's password

### Privileges

* All on `$user` schema
* All on `classdb` schema
* Read on `public` schema


## Student

Students will typically be students in a class that uses an instance of ClassDB. Students have the fewest privileges of all roles. In a well organized setup, the instance of ClassDB should be completely invisible to Students. Instead, from their perspective, they will simply be using a database to experiment with queries or complete assignments. Unlike other roles, Students may be limited in the number of connections they can have open, and by the amount of time that a query they execute can run. These two limits exist to reduce the impact that any one student has on a server running an instance of ClassDB.

### ClassDB Capabilities

None

### Privileges

* All on `$user` schema
* Read on `public` schema

### Restrictions

* Optional [connection limit](Configuring ClassDB)
* Optional [query timeout](Configuring ClassDB)

## Other Notes

Having "all" privileges on an object does not include ownership. This means that merely having all privileges on a schema is not sufficient to drop said schema. Also, it does not include "all" privileges on objects in the schema that were not created by the same user. In most situations, the ClassDB role is the actual owner of these database objects.


***
Andrew Figueroa  
Data Science & Systems Lab (DASSL), Western Connecticut State University (WCSU)

(C) 2017- DASSL. ALL RIGHTS RESERVED.  
Licensed to others under CC 4.0 BY-SA-NC: https://creativecommons.org/licenses/by-nc-sa/4.0/

PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.
