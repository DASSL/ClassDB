# Viewing currently registered users

The `classdb.Instructor` and `classdb.Student` tables hold entries for the currently registered Instructor and Students, respectively. Only users from the current ClassDB database are displayed. Any Instructor or DBManager is able to read the values from these tables. They can also modify the givenName for any Instructor or Student, and modify the schoolID for any student.

To retrieve a list of currently registered Instructors, the following query would be run:

```sql
SELECT *
FROM classdb.Instructor;
```

Likewise, to obtain a list of currently registered Students:

```sql
SELECT *
FROM classdb.Student;
```
The `classdb.Student` table also contains logging information if the logging capabilities of ClassDB have been enabled. See [User Logging](User-Logging) for more information

***
Andrew Figueroa  
Data Science & Systems Lab (DASSL), Western Connecticut State University (WCSU)

(C) 2017- DASSL. ALL RIGHTS RESERVED.  
Licensed to others under CC 4.0 BY-SA-NC: https://creativecommons.org/licenses/by-nc-sa/4.0/

PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.
