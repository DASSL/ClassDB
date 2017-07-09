# Listing and Describing Tables
A common activity for both students and instructors is listing all tables in a schema, and describing individual columns in a table. This document will explain how to use the ClassDB meta functions for this purpose. These functions provide a simple way to perform these operations, and are intended to be used by students. This document will also demonstrate other ways to perform these operations, such as querying the `INFORMATION_SCHEMA`.

## Listing Tables
This section will show four different methods to list all tables in a given schema.
### ClassDB `public.listTables()`
ClassDB provides the `public.listTables()` function as an easy way to list all tables in a single schema. Since public is on all ClassDB users' search paths by default, `public` can be omitted from the function call. The following query displays a list of all tables in the current user's `$user` schema:
```sql
SELECT * FROM listTables();
```
Optionally, a schema name may be provided to the function. The following query lists all tables in the schema `public`:
```sql
SELECT * FROM public.listTables('public');
```
Internally, both instances of the function execute a query against the `INFORMATION_SCHEMA`.

### `INFORMATION_SCHEMA.TABLES`
Querying the [`INFORMATION_SCHEMA.TABLES` view](https://www.postgresql.org/docs/9.6/static/infoschema-tables.html) can also provide a list of all tables in a schema. This may be used on its own, or combined with other `INFORMATION_SCHEMA` queries. It may be helpful to show more advanced students the following query similar to the one used by the `public.listTables()` function:
```sql
SELECT table_schema, table_name, table_type
FROM INFORMATION_SCHEMA.TABLES i JOIN foldedpgSchema fs ON
i.table_schema  = '<schema_name>';
```

### `pg_tables`
Postgres also provides a [system view called `pg_tables`](https://www.postgresql.org/docs/9.6/static/view-pg-tables.html), which contains a list of all tables in the database. The following query can be used against it, similar to the `INFORMATION_SCHEMA` query:
```sql
SELECT *
FROM pg_tables
WHERE schemaname = '<schema_name>';
```

### `psql \dt` Command
The psql command line client also contains a helper command `\dt`, which lists all tables matching a certain pattern. Executing `\dt` by itself lists all tables you are the owner of. Optionally, `\dt` takes a string parameter consisting of a pattern to match against table names. For example, the following command lists all tables in the `public` schema:
```
\dt public.*
```

## Describing Tables
Describing a table refers to listing all columns in a table. The four methods above can also be applied to describing table.

### ClassDB `public.describe()` Function
ClassDB provides the `public.describe()` function to list all columns in a given table. It takes up to two parameters, one table name, and an optional schema name. If no schema name is given, the user's current schema is assumed. The following two queries demonstrate this. The first describes the table `mytable` in the current schema, while the second describes the table `shelter.dog`.
```sql
SELECT * FROM describe('mytable');
```
```sql
SELECT * FROM describe('shelter', 'dog');
```

### INFORMATION_SCHEMA.COLUMNS
The [`INFORMATION_SCHEMA.COLUMNS` view](https://www.postgresql.org/docs/9.6/static/infoschema-columns.html) maintains a list of all columns in the DBMS. The following query lists all the columns in the `shelter.dog` table.

```sql
SELECT table_name, column_name, data_type, character_maximum_length
FROM INFORMATION_SCHEMA.COLUMNS
WHERE table_name = 'dog'
AND table_schema = 'shelter';
```

### `psql \d` Command
The psql `\d` command describes one table. This command provides much more information than the previous two queries, although it is limited to use in the psql client.

---
Steven Rollo  
Data Science & Systems Lab (DASSL), Western Connecticut State University (WCSU)

(C) 2017- DASSL. ALL RIGHTS RESERVED.  
Licensed to others under CC 4.0 BY-SA-NC: https://creativecommons.org/licenses/by-nc-sa/4.0/

PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.
