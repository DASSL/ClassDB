# Removing Users

Users can be removed by calling the appropriate ClassDB function for the type of user being removed. Dropping a user will drop their `$user` schema and the objects contained within, remove them from the server, and unregister them from the classdb.Instructor or classdb.Student tables if appropriate. It is not possible to remove the role that is currently being used. To remove the last ClassDB user (which will be an Instructor or DBManager), it is necessary to call the appropriate drop function from the role that ran the setup script or a superuser.

## Instructors

Instructors can be dropped by calling the `dropInstructor()` function. This function takes one parameter, which follows the case sensitivity rules described in the [Adding Users](Adding-Users) documentation:

- `userName` - The user name of the Instructor that is being removed

To remove an Instructor with a user name of "caldwellj", the following query should be executed:

```sql
SELECT classdb.dropInstructor('caldwellj');
```

Removing an Instructor will also remove their entry from the `classdb.Instructor` table (unregistering them), and drop their `$user` schema. If the Instructor owned any objects that were not in their `$user` schema (such as those in the `public` schema), those objects will become "orphans", and ownership of those objects will be passed onto the ClassDB_Instructor role.

## Students

Students can be dropped by calling the `dropStudent()` function. This function takes one parameter, which follows the case sensitivity rules described in the [Adding Users](Adding-Users) documentation:

- `userName` - The user name of the Student that is being removed

To remove a Student with a user name of "bell001", the following query should be executed:

```sql
SELECT classdb.dropStudent('bell001');
```

Removing a Student will also remove their entry from the `classdb.Student` table (unregistering them), and drop their `$user` schema.

### Dropping all students

In order to easily remove all students registered in an instance of ClassDB, a function for dropping all Students has been provided: `dropAllStudents()`. This function does not take any parameters and can be run by either an Instructor or DBManager.

It can be run by executing the following query:

```sql
SELECT classdb.dropAllStudents();
```

Only students registered in the current ClassDB database will be removed.

## DBManagers

DBManagers can be dropped by calling the `dropDBManager()` function. This function takes one parameter, which follows the case sensitivity rules described in the [Adding Users](Adding-Users) documentation:

- `userName` - The user name of the DBManager that is being removed

To remove a DBManager with a user name of "martine", the following query should be executed:

```sql
SELECT classdb.dropDBManager('martine');
```

Removing a DBManager will also drop their `$user` schema.

***
Andrew Figueroa, Steven Rollo
Data Science & Systems Lab (DASSL), Western Connecticut State University (WCSU)

(C) 2017- DASSL. ALL RIGHTS RESERVED.  
Licensed to others under CC 4.0 BY-SA-NC: https://creativecommons.org/licenses/by-nc-sa/4.0/

PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.
