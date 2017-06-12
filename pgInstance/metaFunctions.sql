--Created at the WCSU DASSL
--By Andrew Figueroa, Steven Rollo and Sean Murthy
--
--metaFunctions.sql
--
--Functions for simple access to table metadata; Created: 2017-06-07; Modified 2017-06-07

--Drop old functions and return types if they exist
DROP FUNCTION IF EXISTS public.list_tables();
DROP FUNCTION IF EXISTS public.list_tables(TEXT);
DROP FUNCTION IF EXISTS public.describe(TEXT);
DROP FUNCTION IF EXISTS public.describe(TEXT, TEXT);

DROP TYPE IF EXISTS public.list_tables_return;
DROP TYPE IF EXISTS public.describe_retrun;

--Prototype of a row that will be returned by the public.list_tables function
--Matches the output of the contained SELECT query
CREATE TYPE public.list_tables_return AS (
   "Name" INFORMATION_SCHEMA.SQL_IDENTIFIER,
   "Type" INFORMATION_SCHEMA.CHARACTER_DATA
);

--Prototype of a row that will be returned by the public.describe function
--Matches the output of the contained SELECT query
CREATE TYPE public.describe_retrun AS (
   "Table Name" INFORMATION_SCHEMA.SQL_IDENTIFIER,
   "Column Name" INFORMATION_SCHEMA.SQL_IDENTIFIER,
   "Data Type" INFORMATION_SCHEMA.CHARACTER_DATA,
   "Maximum Length" INFORMATION_SCHEMA.CARDINAL_NUMBER
);

--Returns a list of tables and views in the current user's schema
--Assumes a schema named <username>
CREATE OR REPLACE FUNCTION public.list_tables()
RETURNS SETOF public.list_tables_return
AS $$
   SELECT table_name, table_type
   FROM INFORMATION_SCHEMA.TABLES
   WHERE table_schema = current_user;
$$
LANGUAGE SQL;

--Returns a list of tables and views in the specified schema
CREATE OR REPLACE FUNCTION public.list_tables(TEXT)
RETURNS SETOF public.list_tables_return
AS $$
   SELECT table_name, table_type
   FROM INFORMATION_SCHEMA.TABLES
   WHERE table_schema = $1;
$$
LANGUAGE SQL;

--Returns a list of columns in the specified table or view
--Will only work on tables in the user's search_path
CREATE OR REPLACE FUNCTION public.describe(TEXT)
RETURNS SETOF public.describe_retrun
AS $$
   SELECT table_name, column_name, data_type, character_maximum_length 
   FROM INFORMATION_SCHEMA.COLUMNS 
   WHERE table_name = $1
   AND table_schema =  current_user;
$$
LANGUAGE SQL;

--Returns a list of columns in the specified table or view in the specified schema
CREATE OR REPLACE FUNCTION public.describe(TEXT, TEXT)
RETURNS SETOF public.describe_retrun
AS $$
   SELECT table_name, column_name, data_type, character_maximum_length 
   FROM INFORMATION_SCHEMA.COLUMNS 
   WHERE table_name = $2
   AND table_schema = $1;
$$
LANGUAGE SQL;