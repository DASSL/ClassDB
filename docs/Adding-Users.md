[ClassDB Home](Home) \| [Table of Contents](Table-of-Contents)

---
# Adding Users

_Authors: Andrew Figueroa, Sean Murthy_

ClassDB provides three functions to add database users: one for each [user role ClassDB defines](Roles). The functions are located in the `classdb` schema and can be executed by Instructors and DBManagers.

Each user-creation function creates a user on the server in which ClassDB is installed and makes the new user a member of the corresponding role. It also creates a [`$user` schema](https://github.com/DASSL/ClassDB/wiki/Schemas "ClassDB Wiki - Schemas") for each user within the database where the function is executed, assigns appropriate privileges for the user on that schema, and appropriately registers them in an internal table ClassDB maintains.

Regardless of the role, every user name must be unique among all users on the server, even among users not created through ClassDB. By default, user names are not case sensitive internally, and are folded down to lowercase. A user name may be enclosed in double quotes to preserver case. See [Postgres documentation](https://www.postgresql.org/docs/9.6/static/sql-syntax-lexical.html#SQL-SYNTAX-IDENTIFIERS) for details on user names and other PostgreSQL identifiers. In either case, clients will require the case to match what is stored internally.

In all cases, an initial password may be optionally supplied. If the initial password is not supplied, it is set to the same value as the user name. Whether an explicit initial password is provided or a default initial password is used, every user should [change their password](Changing Passwords) soon after first log in.

## Instructors

Function `createInstructor` creates an Instructor. This function takes three parameters:

- `instructorUserName` - **Required** - The username the instructor will use to connect to the server instance
- `instructorName` - **Required** - The instructor's given name. This name is stored for later reference
- `initialPwd` - **Optional** - The instructor's initial password

### Examples
Execute the following query to create an instructor with username "caldwellj", given name "Jessica Caldwell", and the default initial password (their username).

```
SELECT classdb.createInstructor('caldwellj', 'Jessica Caldwell');
```

Execute the following query to create the same user as above, but with an initial password of "LV8jzugmfFBF":

```
SELECT classdb.createInstructor('caldwellj', 'Jessica Caldwell', 'LV8jzugmfFBF');
```

In both the examples shown above, the user name is not case sensitive. To make the user name case-sensitive instead, execute the following query. This instructor will need to use the exact string `CaldwellJ` as user name at log in:

```
SELECT classdb.createInstructor('"CaldwellJ"', 'Jessica Caldwell', 'LV8jzugmfFBF');
```

## Students
Function `createStudent` creates a Student. This function takes four parameters:

- `studentUserName` - **Required** - The username the student will use to connect to the server instance
- `studentName` - **Required** - The student's given name. This name is stored for later reference
- `schoolID` - **Optional** - The school issued ID assigned to the Student. If provided, it is stored for later reference
- `initialPwd` - **Optional** - The student's initial password

### Examples
Execute the following query to create a student with username "bell001", given name "Emmett Bell", no school-issued ID, and the default initial password (their username).

```
SELECT classdb.createStudent('bell001', 'Emmett Bell');
```

Execute the following query to create the same user as above, but with a school-issued ID "B584452" and the default initial password:

```
SELECT classdb.createStudent('bell001', 'Emmett Bell', 'B584452');
```

Execute the following query to create the same student, but with an initial password of "w18nwMcK&606":

```
SELECT classdb.createStudent('bell001', 'Emmett Bell', 'B584452', 'w18nwMcK&606');
```

Finally, execute the following query to create the same student with the same explicit initial password, but not provide a school-issued ID:

```
SELECT classdb.createStudent('bell001', 'Emmett Bell', NULL, 'w18nwMcK&606');
```

## DBManagers

Function `createDBManager` creates a DBManager. This function takes two parameters:

- `managerUserName` - **Required** - The username the dbmanager will use to connect to the server instance
- `initialPwd` - **Optional** - The dbmanager's initial password

### Examples
Execute the following query to create a dbmanager with username "martine", and the default initial password (their username).

```
SELECT classdb.createDBManager('martine');
```

Execute the following query to create the same user as above, but with an initial password of "Cid8&88#M8Y8":

```
SELECT classdb.createDBManager('martine', 'Cid8&88#M8Y8');
```

In both the examples shown above, the user name is not case sensitive. To make the user name case-sensitive instead, execute the following query. This dbmanager will need to use the exact string `Martine` as user name at log in:

```
SELECT classdb.createDBManager('"Martine"', 'Cid8&88#M8Y8');
```

***
