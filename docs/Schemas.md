# Schemas

Every user in an instance of ClassDB receives their own [schema](https://www.postgresql.org/docs/9.6/static/ddl-schemas.html "PostgreSQL.org - Schemas"), where they can perform operations on database objects that they have created. This schema is created with the same name as the user's database username. This "personal" schema is referred to as the `$user` schema.

The `public` schema is a special schema that can be read by any ClassDB user, but only modified by Instructors.

## User Schemas

Every user has "all" privileges on their `$user` schema. They can create, modify, and delete objects within their schema without affecting any other user's usage of the database. For Instructors and DBManagers, only the individual user that the `$user` schema corresponds to can create or access the objects within the schema. See the special note for Student users below.

It is important to note that the `$user` schema is not technically owned by the user that it corresponds to. Instead, it is owned by the `ClassDB` role. This prevents users from either inadvertently or purposefully altering the name or owner of their schema, or dropping the schema altogether. This does not otherwise affect the usage of the schema.

### Special note for Student schemas

`$user` schemas belonging to Students can be read by any Instructor (but not by DBManagers). The default privileges are also set such that Instructors can read tables created in this schema by the student. This allows instructors to view a student's progress and review any assignments or projects. Student's cannot read each other's `$user` schemas.

## Public schema

The `public` schema is a schema that is configured so that it can be read by any user, but only have objects created or modified by Instructors. This allows read access on a table to be given to all users of an instance of ClassDB.

A user's default search path is set to `'$user, public'`, which means that database objects will first be searched for in their `$user` schema, followed by the public schema. This means that if an object with the same name exists in both the `$user` schema and the public schema, the one in the `$user` schema will be used.

For example, if there exists a table named `Employee` in both the `$user` schema and the `public` schema, then the following statement will use the one in the `$user` schema:

```sql
SELECT *
FROM Employee;
```

If the `Employee` table in the public schema needs to be accessed, then a fully qualified name must be used, like so:

```sql
SELECT *
FROM public.Employee;
```

Likewise, if an Instructor wishes to create a table in the public schema, then a fully qualified name must also be used. Otherwise, it will be created in their `$user` schema.

***
Andrew Figueroa  
Data Science & Systems Lab (DASSL), Western Connecticut State University (WCSU)

(C) 2017- DASSL. ALL RIGHTS RESERVED.  
Licensed to others under CC 4.0 BY-SA-NC:  
https://creativecommons.org/licenses/by-nc-sa/4.0/

PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.
