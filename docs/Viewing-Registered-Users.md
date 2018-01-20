[ClassDB Home](Home) \| [Table of Contents](Table-of-Contents)

---
# Viewing currently registered users

_Author: Andrew Figueroa, Steven Rollo_

The `ClassDB.User` view holds entries for all currently registered ClassDB users. Only users from the current ClassDB database are displayed. Any Instructor or DBManager is able to read the values from this tables. They can also modify the `FullName` and `ExtraInfo` of any user.

Three additional views: `ClassDB.Instructor`, `ClassDB.Student`, `ClassDB.DBManager` are provided to display only the corresponding type of ClassDB user.

To retrieve a list of currently registered Instructors, the following query would be run:

```sql
SELECT *
FROM ClassDB.Instructor;
```

Likewise, to obtain a list of currently registered Students:

```sql
SELECT *
FROM ClassDB.Student;
```
All four views also contain logging information if the logging capabilities of ClassDB have been enabled. See [User Logging](User-Logging) for more information. Additional logging information can also be viewed using the [Frequent User Views](Frequent-User-Views).

***
