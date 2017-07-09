# Introduction to ClassDB
This document provides a high-level introduction to ClassDB.

## Overview
ClassDB is an open-source database application to help instructors provide students an environment to experiment with relational data. With ClassDB, each student gets their own space (think _schema_) with all rights to that space. The instructor is able to read from any student's space, but no student has access to another student's space. Further, the instructor can create additional common spaces with selected rights for students.

Instructors can use ClassDB to accept class assignments and term projects in both introductory courses on data management and upper-level courses where students program against a database.

ClassDB was developed at the Data Science & Systems Lab ([[DASSL|Credits]], read _dazzle_) at the Western Connecticut State University (WCSU). It is distributed under [Creative Commons License BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/).

## Goals
ClassDB is developed with the following goals:
1. Let instructors offer students dedicated spaces to experiment with relational data
2. Permit instructors to read and evaluate student work
3. Allow instructors to delegate certain operations to "database managers"
4. Enable instructors to customize the application
5. Provide an example implementation of a simple yet useful database application
6. Use (and demonstrate the use of) modern software-engineering tools and processes

ClassDB uses roles, schemas, and access control to achieve Goals 1, 2, and 3. Specifically, it organizes users as [[roles|Roles]], creates a dedicated schema for each user, and uses a combination of role-based and user-based access controls. To meet Goals 4 and 5, ClassDB is distributed "open source" and is well-documented both inside and outside the source code. To meet Goal 6, ClassDB is implemented using modern tools for collaboration, [version control](https://github.com/DASSL/ClassDB), and issue management. All documentation is written in [markdown format](https://help.github.com/articles/about-writing-and-formatting-on-github/) and all code units have tests.

Overall, in addition to providing a tool for use in educational settings, ClassDB is also designed to be a study for students in intermediate and advanced courses on data management and software engineering. (Much of ClassDB was implemented by [[two undergraduate students|Credits]].)

## Benefits
Other than the obvious benefit of using a tool to easily create sandboxes for students, the architecture and implementation of ClassDB offers several operational benefits:

1. Installation does not require any special tool or process: just run a few SQL scripts
2. Runs completely inside an existing DBMS instance
3. Requires no new tool to interact with the DBMS during or after installation
4. Causes little to no interference to DBMS usage or operations
5. Uses only SQL for all ClassDB operations

## Requirements
ClassDB runs in an instance of PostgreSQL (Postgres). It has been primarily tested with [Postgres 9.6.3](https://www.postgresql.org/docs/9.6/static/index.html) on Windows 10 and Ubuntu Server 16.04, but it should run in any Postgres instance as long as the instance is [["fully owned"|Setup]].

## Quick Start
The [[installation document|Setup]] provides the details, but at a high-level, ClassDB is installed in just three steps (see examples below):
1. Add ClassDB to database server: run `prepareServer.sql` as a superuser
2. Create the database to be managed using ClassDB: see example below
3. Add ClassDB to the database: run `prepareDB.psql` as superuser

ClassDB may be added to any number of servers, and to any number of databases in a server: perform Step 1 once for each server which contains the database(s) to be managed; perform Steps 2 and 3 for each database to be managed.

After installation is complete, all tasks are performed by simply invoking ClassDB functions in the context of the appropriate database.


### Examples

#### Add ClassDB to a server
Use any Postgres client to execute the contents of the script file `prepareServer.sql`. This example shows the use of [psql](https://www.postgresql.org/docs/9.6/static/app-psql.html) to execute the script. The values is angle brackets are self-explanatory.

```
psql -h <host> -p <port> -U <aSuperuserName> -d <someDatabaseName> -f prepareServer.sql
```

#### Create a database
Create a database with the name `databaseName` and make the `ClassDB` role the owner of the new database.

```sql
CREATE DATABASE databaseName WITH OWNER = ClassDB;
```

#### Add ClassDB to a database
Use psql to execute the contents of the script file `prepareDB.psql`. (The filename extension is indeed `.psql`.) The values is angle brackets are self-explanatory.

```
psql -h <host> -p <port> -U <aSuperuserName> -d <targetDatabaseName> -f prepareDB.psql
```

#### Add an instructor
Create an instructor whose login name will be `dbmsUserName` and their given name is `givenName`.

```sql
SELECT classdb.createInstructor('dbmsUsername', 'givenName');
```
#### Add a student
Create a student whose login name will be `dbmsUserName` and their given name is `givenName`.

```sql
SELECT classdb.createStudent('dbmsUsername', 'givenName');
```
An expanded version of the function `createStudent` is available to store more details about students.

#### Reset a password
[[Reset|Troubleshooting]] password of the user whose login name is `dbmsUserName`.

```sql
SELECT classdb.resetUserPassword('dbmsUsername');
```
---

Sean Murthy
Data Science & Systems Lab (DASSL), Western Connecticut State University (WCSU)

(C) 2017- DASSL. ALL RIGHTS RESERVED.
Licensed to others under CC 4.0 BY-SA-NC: https://creativecommons.org/licenses/by-nc-sa/4.0/

PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.
