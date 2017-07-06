--removeClassDBFromDB.sql - ClassDB

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

--event triggers
DROP EVENT TRIGGER IF EXISTS updateStudentActivityTriggerDDL;
DROP EVENT TRIGGER IF EXISTS updateStudentActivityTriggerDrop;

--Drop the metaFunctions from public, if they exist
DROP FUNCTION IF EXISTS public.describe(VARCHAR(63), VARCHAR(63));
DROP FUNCTION IF EXISTS public.listTables(VARCHAR(63));

--remove membership of students, instructors, and db managers
-- TBD

--Delete the entire classdb schema in the current database
-- no need to drop individual objects created in that schema
DROP SCHEMA IF EXISTS ClassDB CASCADE;

--change ownership of the current DB to current user so they can delete the DB
-- TBD

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
