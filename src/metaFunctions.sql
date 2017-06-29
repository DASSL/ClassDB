--metaFunctions.sql - ClassDB

--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab (DASSL), Western Connecticut State University (WCSU)

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.


--Drop old functions and return types if they exist
DROP FUNCTION IF EXISTS public.listTables(VARCHAR(63));
DROP FUNCTION IF EXISTS public.describe(VARCHAR(63), VARCHAR(63));

--Returns a list of tables and views in the specified schema
--Defaults to current_user, as each student (the intended users of this function)
--will primarily use a schema named <current_user>
CREATE OR REPLACE FUNCTION public.listTables(schemaName VARCHAR(63) DEFAULT current_user)
   RETURNS TABLE
(  --Since these functions access the INFORMATION_SCHEMA, we use the standard
   --info schema types for the return table
   "Name" INFORMATION_SCHEMA.SQL_IDENTIFIER,
   "Type" INFORMATION_SCHEMA.CHARACTER_DATA
)
AS $$
   SELECT table_name, table_type
   FROM INFORMATION_SCHEMA.TABLES
   WHERE table_schema = $1;
$$
LANGUAGE sql;

ALTER FUNCTION public.listTables(VARCHAR(63)) OWNER TO ClassDB;
GRANT EXECUTE ON FUNCTION public.listTables(VARCHAR(63)) TO PUBLIC;


--Returns a list of columns in the specified table or view in the specified schema
--schemaName also defaults to current_user, for the same reasons as above
CREATE OR REPLACE FUNCTION public.describe(tableName VARCHAR(63),
   schemaName VARCHAR(63) DEFAULT current_user)
RETURNS TABLE
(
   "Table Name" INFORMATION_SCHEMA.SQL_IDENTIFIER,
   "Column Name" INFORMATION_SCHEMA.SQL_IDENTIFIER,
   "Data Type" INFORMATION_SCHEMA.CHARACTER_DATA,
   "Maximum Length" INFORMATION_SCHEMA.CARDINAL_NUMBER
) 
AS $$
   SELECT table_name, column_name, data_type, character_maximum_length
   FROM INFORMATION_SCHEMA.COLUMNS
   WHERE table_name = $1
   AND table_schema = $2;
$$
LANGUAGE sql;

ALTER FUNCTION public.describe(VARCHAR(63), VARCHAR(63)) OWNER TO ClassDB;
GRANT EXECUTE ON FUNCTION public.describe(VARCHAR(63), VARCHAR(63)) TO PUBLIC;
