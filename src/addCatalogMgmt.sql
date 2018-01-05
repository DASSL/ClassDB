--addCatalogMgmt.sql - ClassDB

--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab (DASSL), https://dassl.github.io/

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.

--This script should be run as either a superuser or a user with write access
-- to the PUBLIC schema

--This script should be run in every database to which ClassDB is to be added
-- it should be run after running addHelpers.sql

--This script creates two publicly accessible functions, intended for students
-- These functions provide an easy way for students to DESCRIBE a tables
-- and list all tables in a schema.  Both functions are wrappers to
-- INFORMATION_SCHEMA queries


BEGIN TRANSACTION;

--Suppress NOTICE messages for this script only, this will not apply to functions
-- defined within. This hides messages that are unimportant, but possibly confusing
SET LOCAL client_min_messages TO WARNING;


--Returns a list of tables and views in the current user's schema
DROP FUNCTION IF EXISTS Public.listTables();
CREATE FUNCTION Public.listTables()
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
   WHERE table_schema = session_user;
$$ LANGUAGE sql
   SECURITY DEFINER;

ALTER FUNCTION
   public.listTables()
   OWNER TO ClassDB;

GRANT EXECUTE ON FUNCTION
   public.listTables()
   TO PUBLIC;


--Returns a list of columns in the specified table or view in the current schema
DROP FUNCTION IF EXISTS public.describe(VARCHAR(63));
CREATE FUNCTION public.describe(tableName VARCHAR(63))
RETURNS TABLE
(
   "Column" INFORMATION_SCHEMA.SQL_IDENTIFIER,
   "Type" VARCHAR(100) --Use VARCHAR since we are going to modify the
                       -- data returned from INFO_SCHEMA
)
AS $$
   SELECT column_name, data_type || COALESCE('(' || character_maximum_length || ')', '')
   FROM INFORMATION_SCHEMA.COLUMNS i
   WHERE table_schema = session_user AND table_name = ClassDB.FoldPgID($1);
$$ LANGUAGE sql
   SECURITY DEFINER;

ALTER FUNCTION
   public.describe(VARCHAR(63))
   OWNER TO ClassDB;

GRANT EXECUTE ON FUNCTION
   public.describe(VARCHAR(63))
   TO PUBLIC;


--Returns a list of columns in the specified table or view in the specified schema
-- This overide allows a schema name to be specified
DROP FUNCTION IF EXISTS public.describe(VARCHAR(63), VARCHAR(63));
CREATE FUNCTION public.describe(schemaName VARCHAR(63), tableName VARCHAR(63))
RETURNS TABLE
(
   "Column" INFORMATION_SCHEMA.SQL_IDENTIFIER,
   "Type" VARCHAR(100) --Use VARCHAR since we are going to modify the
                       -- data returned from INFO_SCHEMA
)
AS $$
   --foldedPgTable and foldedPgSchema replicate PostgreSQLs folding behvaior.
   -- This code is currently duplicated to avoid the use of foldPgID since it is
   -- in the classdb schema.
   WITH foldedPgTable(foldedTableName) AS (
      SELECT CASE WHEN SUBSTRING($2 from 1 for 1) = '"' AND
                  SUBSTRING($2 from LENGTH($2) for 1) = '"'
             THEN
                  SUBSTRING($2 from 2 for LENGTH($2) - 2)
             ELSE
                  LOWER($2)
      END
   ), foldedPgSchema(foldedSchemaName) AS (
      SELECT CASE WHEN SUBSTRING($1 from 1 for 1) = '"' AND
                  SUBSTRING($1 from LENGTH($1) for 1) = '"'
             THEN
                  SUBSTRING($1 from 2 for LENGTH($1) - 2)
             ELSE
                  LOWER($1)
      END
   ) --This formats the output to look similar to psql's \d
   SELECT column_name, data_type || COALESCE('(' || character_maximum_length || ')', '')
   FROM INFORMATION_SCHEMA.COLUMNS i JOIN foldedPgTable ft ON
      table_name = ft.foldedTableName JOIN foldedPgSchema fs ON
      table_schema = fs.foldedSchemaName;
$$
LANGUAGE sql;

ALTER FUNCTION public.describe(VARCHAR(63), VARCHAR(63)) OWNER TO ClassDB;
GRANT EXECUTE ON FUNCTION public.describe(VARCHAR(63), VARCHAR(63)) TO PUBLIC;


COMMIT;
