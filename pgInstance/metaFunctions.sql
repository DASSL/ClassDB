--metaFunctions.sql - ClassDB

--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab (DASSL), Western Connecticut State University (WCSU)

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC: https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.


--Drop old functions and return types if they exist
DROP FUNCTION IF EXISTS public.listTables();
DROP FUNCTION IF EXISTS public.listTables(VARCHAR(63));
DROP FUNCTION IF EXISTS public.describe(VARCHAR(63));
DROP FUNCTION IF EXISTS public.describe(VARCHAR(63), VARCHAR(63));

DROP TYPE IF EXISTS public.listTablesReturn;
DROP TYPE IF EXISTS public.describeRetrun;

--Prototype of a row that will be returned by the public.list_tables function
--Matches the output of the contained SELECT query
CREATE TYPE public.listTablesReturn AS (
   "Name" INFORMATION_SCHEMA.SQL_IDENTIFIER,
   "Type" INFORMATION_SCHEMA.CHARACTER_DATA
);

--Prototype of a row that will be returned by the public.describe function
--Matches the output of the contained SELECT query
CREATE TYPE public.describeRetrun AS (
   "Table Name" INFORMATION_SCHEMA.SQL_IDENTIFIER,
   "Column Name" INFORMATION_SCHEMA.SQL_IDENTIFIER,
   "Data Type" INFORMATION_SCHEMA.CHARACTER_DATA,
   "Maximum Length" INFORMATION_SCHEMA.CARDINAL_NUMBER
);

--Returns a list of tables and views in the current user's schema
--Assumes a schema named <username>
CREATE OR REPLACE FUNCTION public.listTables()
RETURNS SETOF public.listTablesReturn
AS $$
   SELECT table_name, table_type
   FROM INFORMATION_SCHEMA.TABLES
   WHERE table_schema = current_user;
$$
LANGUAGE sql;

--Returns a list of tables and views in the specified schema
CREATE OR REPLACE FUNCTION public.listTables(schemaName VARCHAR(63))
RETURNS SETOF public.listTablesReturn
AS $$
   SELECT table_name, table_type
   FROM INFORMATION_SCHEMA.TABLES
   WHERE table_schema = $1;
$$
LANGUAGE sql;

--Returns a list of columns in the specified table or view
--Will only work on tables in the user's search_path
CREATE OR REPLACE FUNCTION public.describe(tableName VARCHAR(63))
RETURNS SETOF public.describeRetrun
AS $$
   SELECT table_name, column_name, data_type, character_maximum_length 
   FROM INFORMATION_SCHEMA.COLUMNS 
   WHERE table_name = $1
   AND table_schema =  current_user;
$$
LANGUAGE sql;

--Returns a list of columns in the specified table or view in the specified schema
CREATE OR REPLACE FUNCTION public.describe(schemaName VARCHAR(63), tableName VARCHAR(63))
RETURNS SETOF public.describeRetrun
AS $$
   SELECT table_name, column_name, data_type, character_maximum_length 
   FROM INFORMATION_SCHEMA.COLUMNS 
   WHERE table_name = $2
   AND table_schema = $1;
$$
LANGUAGE sql;