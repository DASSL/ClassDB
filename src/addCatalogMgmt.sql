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


--Returns a list of tables and views in the current user's schema
CREATE OR REPLACE FUNCTION public.listTables(schemaName VARCHAR(63) DEFAULT SESSION_USER)
   RETURNS TABLE
(  --Since these functions access the INFORMATION_SCHEMA, we use the standard
   --info schema types for the return table
   "Schema" INFORMATION_SCHEMA.SQL_IDENTIFIER,
   "Name" INFORMATION_SCHEMA.SQL_IDENTIFIER,
   "Type" INFORMATION_SCHEMA.CHARACTER_DATA
)
AS $$
BEGIN
   --Check if the user is associated with the schema they are trying to list from.
   -- This is required because a user's schema name is not always the same as their
   -- user name.
   IF ClassDB.getSchemaOwnerName(schemaName) <> SESSION_USER::ClassDB.IDNameDomain THEN
      RAISE EXCEPTION 'Insufficient privileges: you do not have permission to access'
         ' the requested schema';

   SELECT table_schema, table_name, table_type
   FROM INFORMATION_SCHEMA.TABLES
   WHERE table_schema = schemaName;
END;
$$ LANGUAGE plpgsql
   STABLE
   SECURITY DEFINER;

ALTER FUNCTION
   Public.listTables()
   OWNER TO ClassDB;

GRANT EXECUTE ON FUNCTION
   Public.listTables()
   TO PUBLIC;

--Returns a list of columns in the specified table or view in the current user's schema
CREATE OR REPLACE FUNCTION public.describe(tableName VARCHAR(63))
RETURNS TABLE
(
   "Column" INFORMATION_SCHEMA.SQL_IDENTIFIER,
   "Type" VARCHAR(100) --Use VARCHAR since we are going to modify the
                       -- data returned from INFO_SCHEMA
)
AS $$
   SELECT column_name, data_type || COALESCE('(' || character_maximum_length || ')', '')
   FROM INFORMATION_SCHEMA.COLUMNS
   WHERE table_schema = ClassDB.getSchemaName(SESSION_USER)
   AND table_name = ClassDB.FoldPgID($1);
$$ LANGUAGE sql
   STABLE
   SECURITY DEFINER;

ALTER FUNCTION
   Public.describe(VARCHAR(63))
   OWNER TO ClassDB;

GRANT EXECUTE ON FUNCTION
   Public.describe(VARCHAR(63))
   TO PUBLIC;

--Returns a list of columns in the specified table or view in the specified schema
-- This overide allows a schema name to be specified
CREATE OR REPLACE FUNCTION public.describe(schemaName VARCHAR(63), tableName VARCHAR(63))
RETURNS TABLE
(
   "Column" INFORMATION_SCHEMA.SQL_IDENTIFIER,
   "Type" VARCHAR(100) --Use VARCHAR since we are going to modify the
                       -- data returned from INFO_SCHEMA
)
AS $$
   --Check if the user is associated with the scheam they are trying to list from.
   -- This is required because a user's schema name is not always the same as their
   -- user name.
   IF ClassDB.getSchemaOwnerName(schemaName) <> SESSION_USER::ClassDB.IDNameDomain THEN
   RAISE EXCEPTION 'Insufficient privileges: you do not have permission to access'
      ' the requested schema';

   SELECT column_name, data_type || COALESCE('(' || character_maximum_length || ')', '')
   FROM INFORMATION_SCHEMA.COLUMNS
   WHERE table_schema = ClassDB.foldPgID(schemaName)
   AND   table_name = ClassDB.foldPgID(tableName)
$$ LANGUAGE plpgsql
   STABLE
   SECURITY DEFINER;

ALTER FUNCTION
   Public.describe(VARCHAR(63), VARCHAR(63))
   OWNER TO ClassDB;

GRANT EXECUTE ON FUNCTION
   Public.describe(VARCHAR(63), VARCHAR(63))
   TO PUBLIC;


COMMIT;
