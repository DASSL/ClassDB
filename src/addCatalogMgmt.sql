--addCatalogMgmt.sql - ClassDB

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
-- it should be run after running addHelpers.sql

--This script creates two publicly accessible functions, intended for students
-- These functions provide an easy way for students to DESCRIBE a tables
-- and list all tables in a schema.  Both functions are wrappers to
-- INFORMATION_SCHEMA queries


BEGIN TRANSACTION;

--Suppress NOTICE messages for this script only, this will not apply to functions
-- defined within. This hides messages that are unimportant, but possibly confusing
SET LOCAL client_min_messages TO WARNING;


--Define a function to replicate PostgreSQL's folding behavior for SQL IDs
-- This function is a duplicate of ClassDB.foldPgID(). Since students cannot access
-- objects in the ClassDB schema, this version is required so that students can use
-- the catalog management functions. Any change to foldPgID() must also be made to
-- the version in addHelpers.sql
CREATE OR REPLACE FUNCTION public.foldPgID(identifier ClassDB.IDNameDomain)
RETURNS ClassDB.IDNameDomain AS
$$
SELECT CASE WHEN SUBSTRING($1 from 1 for 1) = '"' AND
                 SUBSTRING($1 from LENGTH($1) for 1) = '"'
            THEN
                 SUBSTRING($1 from 2 for LENGTH($1) - 2)
            ELSE
                 LOWER($1)
       END;
$$ LANGUAGE sql
   STABLE;

ALTER FUNCTION public.foldPgID(ClassDB.IDNameDomain) OWNER TO ClassDB;


--Returns a list of tables and views in the current user's schema
CREATE OR REPLACE FUNCTION public.listTables(schemaName ClassDB.IDNameDomain
   DEFAULT CURRENT_SCHEMA::ClassDB.IDNameDomain)
RETURNS TABLE
(  --Since these functions access the INFORMATION_SCHEMA, we use the standard
   --info schema types for the return table
   "Schema" INFORMATION_SCHEMA.SQL_IDENTIFIER,
   "Name" INFORMATION_SCHEMA.SQL_IDENTIFIER,
   "Type" INFORMATION_SCHEMA.CHARACTER_DATA
)
AS $$
BEGIN
   SELECT table_schema, table_name, table_type
   FROM INFORMATION_SCHEMA.TABLES
   WHERE table_schema = ClassDB.foldPgID(schemaName);
END;
$$ LANGUAGE plpgsql
   STABLE;

ALTER FUNCTION Public.listTables(ClassDB.IDNameDomain) OWNER TO ClassDB;


--Returns a list of columns in the specified table or view in the specified schema
-- This overide allows a schema name to be specified
CREATE OR REPLACE FUNCTION public.describe(schemaName ClassDB.IDNameDomain,
   tableName ClassDB.IDNameDomain)
RETURNS TABLE
(
   "Column" INFORMATION_SCHEMA.SQL_IDENTIFIER,
   "Type" VARCHAR --Use VARCHAR since we modify data returned from info schema
)
AS $$
   SELECT column_name, data_type || COALESCE('(' || character_maximum_length || ')', '')
   FROM INFORMATION_SCHEMA.COLUMNS
   WHERE table_schema = ClassDB.foldPgID(schemaName)
   AND   table_name = ClassDB.foldPgID(tableName)
$$ LANGUAGE plpgsql
   STABLE;

ALTER FUNCTION public.describe(ClassDB.IDNameDomain, ClassDB.IDNameDomain) OWNER TO ClassDB;


--Returns a list of columns in the specified table or view in the current user's schema
CREATE OR REPLACE FUNCTION public.describe(tableName ClassDB.IDNameDomain)
RETURNS TABLE
(
   "Column" INFORMATION_SCHEMA.SQL_IDENTIFIER,
   "Type" VARCHAR --Use VARCHAR since we modify data returned from info schema
)
AS $$
   SELECT "Column", "Type"
   FROM public.describe(CURRENT_SCHEMA::ClasDB.IDNameDomain, ClassDB.FoldPgID($1));
$$ LANGUAGE sql
   STABLE;

ALTER FUNCTION public.describe(ClassDB.IDNameDomain) OWNER TO ClassDB;


COMMIT;
