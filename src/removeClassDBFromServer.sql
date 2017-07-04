--removeClassDBFromServer.sql - ClassDB

--Sean Murthy
--Data Science & Systems Lab (DASSL), Western Connecticut State University (WCSU)

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.


--This script undoes the changes the ClassDB installation scripts make to the server
-- not all changes can be undone
-- this script lists the changes an appropriate user has to perform separately

--This script must be run AFTER running removeClassDBFromDB.sql on all databases
-- where ClassDB is installed

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

--Drop app-specific roles
-- need to make sure that removeClassDBFromDB is complete

--DROP ROLE IF EXISTS ClassDB_Instructor;
--DROP ROLE IF EXISTS ClassDB_DBManager;
--DROP ROLE IF EXISTS ClassDB_Student;
--DROP ROLE IF EXISTS ClassDB;

--create a list of things users have to do on their own
-- commenting out the RAISE NOTICE statement because it causes syntax error

--RAISE NOTICE 'Run ALTER SYSTEM statements to disable/modify logging';

COMMIT;
