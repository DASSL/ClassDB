--addCatalogMgmtOpt.sql - ClassDB

--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab (DASSL)
--https://dassl.github.io/

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.

--This script should be run as either a superuser or a user with write access
-- to the PUBLIC schema

--This script should be run in every database to which ClassDB is to be added
-- it should be run after running addHelpersCore.sql

--This script creates two publicly accessible functions, intended for students
-- These functions provide an easy way for students to DESCRIBE a tables
-- and list all tables in a schema.  Both functions are wrappers to
-- INFORMATION_SCHEMA queries


START TRANSACTION;

--Suppress NOTICE messages for this script only, this will not apply to functions
-- defined within. This hides messages that are unimportant, but possibly confusing
SET LOCAL client_min_messages TO WARNING;


--Define a function to replicate PostgreSQL's folding behavior for SQL IDs
-- This function is a duplicate of ClassDB.foldPgID(). Since students cannot access
-- objects in the ClassDB schema, this version is required so that students can use
-- the catalog management functions. Any change to foldPgID() must also be made to
-- the version in addHelpersCore.sql
CREATE OR REPLACE FUNCTION public.foldPgID(identifier VARCHAR(65))
RETURNS VARCHAR(63) AS
$$
SELECT CASE WHEN SUBSTRING($1 from 1 for 1) = '"' AND
                 SUBSTRING($1 from LENGTH($1) for 1) = '"'
            THEN
                 SUBSTRING($1 from 2 for LENGTH($1) - 2)
            ELSE
                 LOWER($1)
       END;
$$ LANGUAGE sql
   IMMUTABLE
   RETURNS NULL ON NULL INPUT;

ALTER FUNCTION public.foldPgID(VARCHAR(63)) OWNER TO ClassDB;


--Returns a list of tables and views in the invoker's current schema
CREATE OR REPLACE FUNCTION public.listTables(schemaName VARCHAR(63) DEFAULT CURRENT_SCHEMA)
RETURNS TABLE
(  --Since these functions access the INFORMATION_SCHEMA, we use the standard
   --info schema types for the return table
   "Schema" INFORMATION_SCHEMA.SQL_IDENTIFIER,
   "Name" INFORMATION_SCHEMA.SQL_IDENTIFIER,
   "Type" INFORMATION_SCHEMA.CHARACTER_DATA
)
AS $$
   SELECT table_schema, table_name, table_type
   FROM INFORMATION_SCHEMA.TABLES
   WHERE table_schema = COALESCE(public.foldPgID(schemaName), CURRENT_SCHEMA);
$$ LANGUAGE sql
   STABLE;

ALTER FUNCTION public.listTables(VARCHAR(63)) OWNER TO ClassDB;


--Returns a list of columns in the specified table or view in the specified schema
-- This override allows a schema name to be specified
CREATE OR REPLACE FUNCTION public.describe(schemaName VARCHAR(63), tableName VARCHAR(63))
RETURNS TABLE
(
   "Column" INFORMATION_SCHEMA.SQL_IDENTIFIER,
   "Type" VARCHAR --Use VARCHAR since we modify data returned from info schema
)
AS $$
   SELECT column_name, data_type || COALESCE('(' || character_maximum_length || ')', '')
   FROM INFORMATION_SCHEMA.COLUMNS
   WHERE table_schema = public.foldPgID(schemaName)
   AND   table_name = public.foldPgID(tableName)
$$ LANGUAGE sql
   STABLE;

ALTER FUNCTION public.describe(VARCHAR(63), VARCHAR(63)) OWNER TO ClassDB;


--Returns a list of columns in the specified table or view in the invoker's current schema
CREATE OR REPLACE FUNCTION public.describe(tableName VARCHAR(63))
RETURNS TABLE
(
   "Column" INFORMATION_SCHEMA.SQL_IDENTIFIER,
   "Type" VARCHAR --Use VARCHAR since we modify data returned from info schema
)
AS $$
   --We have to explicitly cast "Name" to "VARCHAR" here as well
   SELECT "Column", "Type"
   FROM public.describe(CURRENT_SCHEMA::VARCHAR(63), $1);
$$ LANGUAGE sql
   STABLE;

ALTER FUNCTION public.describe(VARCHAR(63)) OWNER TO ClassDB;


COMMIT;
