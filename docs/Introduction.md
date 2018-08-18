[ClassDB Home](Home) \| [Table of Contents](Table-of-Contents)

---
# Introduction to ClassDB

_Author: Sean Murthy_

This document provides a high-level introduction to ClassDB.

## Overview
ClassDB is an open-source database application to help instructors create sandboxes
for students (and other users) to experiment with relational data. Each sandbox
is a _database schema_ with the owner having all rights to that space. The instructor
is able to read from any student's schema, but no student has access to another
student's schema. Further, the instructor can create additional common schemas with
selected rights for students.

Instructors can use ClassDB to accept class assignments and term projects in both
introductory courses on data management and upper-level courses where students program
against a database.

ClassDB is developed at the Data Science & Systems Lab ([DASSL](Credits), read _dazzle_).
It is distributed under [Creative Commons License BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/).

## Goals
ClassDB is developed with the following goals:
1. Let instructors offer students dedicated spaces to experiment with relational data
2. Permit instructors to read and evaluate student work
3. Allow instructors to delegate certain operations to "database managers"
4. Enable instructors to customize the application
5. Provide an example implementation of a simple yet useful database application
6. Use (and demonstrate the use of) modern software-engineering tools and processes

ClassDB uses roles, schemas, and access control to achieve Goals 1, 2, and 3.
Specifically, it organizes users as [roles](Roles), creates a dedicated schema for
each user, and uses a combination of role-based and user-based access controls.
To meet Goals 4 and 5, ClassDB is distributed "open source" and is well-documented
both inside and outside the source code. To meet Goal 6, ClassDB is implemented
using modern tools for collaboration, [version control](https://github.com/DASSL/ClassDB),
and issue management. All external documentation is written in [markdown format](https://help.github.com/articles/about-writing-and-formatting-on-github/) and
all code units have tests.

Overall, in addition to providing a tool for use in educational settings, ClassDB
is also designed to be a study for students in intermediate and advanced courses
on data management and software engineering. (Significant parts of ClassDB were
implemented by [two undergraduate students](Credits).)

## Benefits
Other than the obvious benefit of using a tool to easily create sandboxes for students,
the architecture and implementation of ClassDB offers several operational benefits:

1. Installation does not require any special tool or process: just run a few SQL scripts
2. Runs completely inside an existing DBMS instance
3. Requires no new tool to interact with the DBMS during or after installation
4. Causes little to no interference to DBMS usage or operations
5. Uses only SQL for all ClassDB operations

## Requirements
ClassDB runs in an instance of [PostgreSQL](https://www.postgresql.org/) (Postgres) and is 
compatible with Postgres 9.3 and later versions. It has been primarily tested with 
[BigSQL distributions of Postgres](https://www.bigsql.org/) on Windows 10, but it should run 
in any Postgres distribution on any operating system as long as the Postgres instance is ["fully owned"](Setup#prerequisites).

## Quick Start
The [Setup page](Setup) provides details, but at a high-level, a full installation of ClassDB requires just three steps (see examples below):
1. Add ClassDB to database server: run [`addAllToServer.psql`](Scripts#server-level) as a superuser
2. Create the database to be managed using ClassDB: see example below
3. Add ClassDB to the database created in Step 2: run [`addAllToDB.psql`](Scripts#database-level) as superuser

ClassDB may be added to any number of servers, and to any number of databases in
a server: perform Step 1 once for each server which contains the database(s) to
be managed; perform Steps 2 and 3 for each database to be managed.

After the installation is complete, all tasks are performed by simply invoking ClassDB
functions in the context of the appropriate database.


### Examples

The examples show the use of [psql](https://www.postgresql.org/docs/9.6/static/app-psql.html)
to run script files. They show the use of `-f` switch to run scripts from the
command line, but the scripts may also be run from inside the psql shell using the
`\ir` meta-command. The location of each script file is shown in the [file list](File-List).

The example SQL queries shown may be executed in any Postgres client. All queries, except the 
one to create the database, should all be executed in the context of the database where ClassDB
is to be used.

#### Add ClassDB to a server
Use psql to execute the contents of the script file `addAllToServer.psql`.
(The filename extension is indeed `.psql`.) This script may be run in the
context of any database, and it needs to be run only once on any server 
where ClassDB is to be used. 

```
psql -h <host> -p <port> -U <aSuperuserName> -f addAllToServer.psql
```

#### Create a database
Create a database with the name `databaseName` and make the `ClassDB` role the owner
of the new database.

```sql
CREATE DATABASE databaseName WITH OWNER = ClassDB;
```

#### Add ClassDB to a database
Use psql to execute the contents of the script file `addAllToDB.psql`. This script must 
be run in the context of the database (and each database) where ClassDB is to be used. 
That is, the value of the `-d` switch should be the name of the database where ClassDB 
is to be used.

```
psql -h <host> -p <port> -U <aSuperuserName> -d <targetDatabaseName> -f addAllToDB.psql
```

#### Add an instructor
Create an instructor whose login name will be `caldwellj` and their given name is
`Jessica Caldwell`.

```sql
SELECT ClassDB.createInstructor('caldwellj', 'Jessica Caldwell');
```
#### Add a student
Create a student whose login name will be `bell001` and their given name is
`Emmett Bell`.

```sql
SELECT ClassDB.createStudent('bell001', 'Emmett Bell');
```
Expanded versions of the [functions to create users](Adding-Users#functions) are
available to store more information about users as well as to customize certain
parameters related to users.

#### Reset a password
[Reset](Changing-Passwords#resetting-a-forgotten-password) password of the user
whose login name is `bell001`.

```sql
SELECT ClassDB.resetPassword('bell001');
```

#### Create a team
Create a student team named `thunderbolt`.

```sql
SELECT ClassDB.createTeam('thunderbolt');
```
Expanded versions of the [functions to create teams](Adding-Teams#functions) are
available to store more information about teams as well as to customize certain
parameters related to teams.


#### Add a student to a team
Add a student whose login name is `bell001` to the team named `thunderbolt`.

```sql
SELECT ClassDB.addToTeam('bell001', 'thunderbolt');
```

---
