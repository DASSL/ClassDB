[ClassDB Home](Home) \| [Table of Contents](Table-of-Contents)

---
# Object Placement

_Author: Steven Rollo_

ClassDB implements several objects for displaying summary data about the current ClassDB database. These views include instructor focused data, such as listing all recent student activity, and student focused data, such as listing the recent activity for the current user. These objects are placed in either the ClassDB schema or public schema depending on which users should be able to access them. The criteria we used to determine if an object should be a function or a view are listed below.

1) Any objects accessible to both students and instructors should be placed in the public schema, because student users cannot directly access objects in the ClassDB schema.

2) Any objects accessing to instructors only should be placed in the ClassDB schema. This ensures they are not accessible, or visible to, by students.