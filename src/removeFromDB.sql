--removeFromDB.sql - ClassDB

--Sean Murthy, Steven Rollo
--Data Science & Systems Lab (DASSL), Western Connecticut State University (WCSU)

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.


--This script undoes the changes ClassDB installation scripts made to current DB
-- not all changes can be undone
-- this script lists the changes an appropriate user has to perform separately

--This script will NOT drop user roles
-- BEFORE running this script: run appropriate classDB.dropXYZ functions in each
-- database where ClassDB is installed

--This script should be run by a superuser


START TRANSACTION;

--Make sure the current user has sufficient privilege to run this script
-- privileges required: superuser
DO
$$
BEGIN
   IF NOT EXISTS (SELECT * FROM pg_catalog.pg_roles
                  WHERE rolname = current_user AND rolsuper = TRUE
                 ) THEN
      RAISE EXCEPTION 'Insufficient privileges: script must be run as a user with'
                      ' superuser privileges';
   END IF;
END
$$;


--REVOKE permissions on the current database from each ClassDB role
DO
$$
BEGIN
   EXECUTE format('REVOKE CONNECT ON DATABASE %I FROM classdb_instructor;', current_database());
   EXECUTE format('REVOKE CONNECT ON DATABASE %I FROM classdb_dbmanager;', current_database());
   EXECUTE format('REVOKE CONNECT ON DATABASE %I FROM classdb_student;', current_database());
   EXECUTE format('REVOKE CREATE ON DATABASE %I FROM classdb;', current_database());
END
$$;


--Dynamically create a query to reassign all user schemas owned by classdb to
-- be owned by themselves, instead of ClassDB
-- One ALTER SCHEMA statement is generated per schema classdb owns
DO
$$
DECLARE
   queryText TEXT; --This will hold the dynamic ALTER SYSTEM statements
BEGIN
   --The query on pg_roles and pg_auth_members returns all users that belong to
   -- a classdb user role (Instructor, DBManager, or Student)
      SELECT string_agg
      (
         format
         (
            'ALTER SCHEMA %I OWNER TO %I;',
            r1.rolname,
            r1.rolname
         ), ' '
      )
      FROM pg_auth_members am
      JOIN pg_roles r1 ON am.member = r1.oid
      JOIN pg_roles r2 ON am.roleid = r2.oid
      --This join allows us to check that a schema matching the user's name exists,
      -- and that it is owned by ClassDB
      JOIN INFORMATION_SCHEMA.SCHEMATA iss ON iss.schema_name = r1.rolname
      WHERE r2.rolname IN ('classdb_instructor', 'classdb_dbmanager', 'classdb_student')
      AND iss.schema_owner = 'classdb'
      INTO queryText;

      --If there are no schemas to reassign, queryText will be NULL, so we just RAISE INFO
      IF  queryText IS NOT NULL THEN
         EXECUTE queryText;
      ELSE
         RAISE INFO 'No schemas are owned by ClassDB - skipping reassignment';
      END IF;
END
$$;


--Drop all remaining ClassDB objects/permissions in this database.
DROP OWNED BY ClassDB_Instructor;
DROP OWNED BY ClassDB_DBManager;
DROP OWNED BY ClassDB_Student;


--Suppress NOTICE messages for this script only, this will not apply to functions
-- defined within. This hides messages that are unimportant, but possibly confusing
SET LOCAL client_min_messages TO WARNING;

--event triggers
DROP EVENT TRIGGER IF EXISTS updateStudentActivityTriggerDDL;
DROP EVENT TRIGGER IF EXISTS updateStudentActivityTriggerDrop;

--Drop the metaFunctions from public, if they exist
DROP FUNCTION IF EXISTS public.describe(VARCHAR(63), VARCHAR(63));
DROP FUNCTION IF EXISTS public.listTables(VARCHAR(63));

--Delete the entire classdb schema in the current database
-- no need to drop individual objects created in that schema
DROP SCHEMA IF EXISTS ClassDB CASCADE;

--We now want to show our NOTICES, so switch display level back to default
RESET client_min_messages;


--create a list of things users have to do on their own
-- commenting out the RAISE NOTICE statements because they cause syntax error
DO
$$
BEGIN
   RAISE NOTICE 'Drop user roles or adjust their privileges';
   RAISE NOTICE 'Drop user schemas or adjust their privilege';
   RAISE NOTICE 'Adjust privileges on PUBLIC schema if appropriate';
   RAISE NOTICE 'Run DROP DATABASE statement to remove the database if appropriate';
   RAISE NOTICE 'Run prepareClassServer.sql after removing ClassDB '
                'from other databases';
END
$$;

COMMIT;
