# ClassDB

ClassDB is an open-source database application to help instructors provide students an environment to experiment with relational data. With ClassDB, each student gets their own space (think _schema_) with all rights to that space. The instructor is able to read from any student's space, but no student has access to another student's space. Further, the instructor can create additional common spaces with selected rights for students.

Instructors can use ClassDB to accept class assignments and term projects in both introductory courses on data management and upper-level courses where students program against a database.

## Requirements
ClassDB runs in an instance of PostgreSQL (Postgres). It has been primarily tested with [Postgres 9.6.3](https://www.postgresql.org/docs/9.6/static/index.html) on Windows 10 and Ubuntu Server 16.04, but it should run in any Postgres instance as long as the instance is "fully owned".

## Quick Start

The [ClassDB web site](https://dassl.github.io/ClassDB/) has the complete documentation, but at a high-level, ClassDB is installed in just three steps:
1. Add ClassDB to database server: run `prepareServer.sql` as a superuser
2. Create the database to be managed using ClassDB: see example below
3. Add ClassDB to the database: run `prepareDB.psql` as superuser

ClassDB may be added to any number of servers, and to any number of databases in a server: perform Step 1 once for each server which contains the database(s) to be managed; perform Steps 2 and 3 for each database to be managed.

After installation is complete, all tasks are performed by simply invoking ClassDB functions in the context of the appropriate database.

## Contributing

Contributions and ideas are welcome. Mail a summary of your thought to `murthys at wcsu dot edu`. Please include "ClassDB" in the subject line.

## Credits

ClassDB was developed at the Data Science & Systems Lab (DASSL, read _dazzle_) at the Western Connecticut State University (WCSU).

ClassDB was conceived and designed by [Sean Murthy](http://sites.wcsu.edu/murthys/), a member of the Computer Science faculty at WCSU. A large portion of ClassDB was implemented by [Andrew Figueroa](https://github.com/afig) and [Steven Rollo](https://github.com/srrollo), undergraduate students at WCSU.

## Legal Stuff

(C) 2017- DASSL. ALL RIGHTS RESERVED.

ClassDB is distributed under [Creative Commons License BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/).

PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.
