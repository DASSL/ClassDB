[ClassDB Home](Home) \| [Table of Contents](Table-of-Contents)

---
# Views and Functions

_Author: Steven Rollo_

ClassDB implements several objects for displaying summary data about the current ClassDB database. These views include instructor focused data, such as listing all recent student activity, and student focused data, such as listing the recent activity for the current user. These objects are implemented as either functions or views based on which users should be allowed access to set of data each object contains. The criteria we used to determine if an object should be a function or a view are listed below.

1) Unless there is a need for the object to be a function, it should be a view. This simplifies development and maintenance of the object. 

2) Objects that access other objects the accessing user does not have permission to access must be functions. This is because a Postgres view always executes the query defining the view as the current user, while a function can be executed using a different role.

3) Considering criteria 1 and 2, all objects that are accessible to instructors only should be views.

4) Considering criteria 1 and 2, all objects that are accessible to instructors and students that access objects in the ClassDB schema must be functions. As students cannot access objects in the ClassDB schema, it is necessary to execute these functions as ClassDB.

5) Any object intended for user by end-users, particularly students, should be accessible as a view. If the object requires elevated permissions, it is acceptable to create both a function, and a view that queries that function.

