--removeClassDBFromServer.sql - ClassDB

--Sean Murthy, Steven Rollo
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

--REVOKE permissions on the current database from each ClassDB role, since all
-- permissions must be removed from roles before they can be dropped
DO
$$
BEGIN
   EXECUTE format('REVOKE CONNECT ON DATABASE %I FROM instructor;', current_database());
   EXECUTE format('REVOKE CONNECT ON DATABASE %I FROM dbmanager;', current_database());
   EXECUTE format('REVOKE CONNECT ON DATABASE %I FROM student;', current_database());
   EXECUTE format('REVOKE CREATE ON DATABASE %I FROM classdb;', current_database());
END
$$;

--Drop app-specific roles
-- need to make sure that removeClassDBFromDB is complete
DROP ROLE IF EXISTS Instructor;
DROP ROLE IF EXISTS DBManager;
DROP ROLE IF EXISTS Student;
DROP ROLE IF EXISTS ClassDB;

--create a list of things users have to do on their own
DO
$$
BEGIN
   RAISE NOTICE 'Run ALTER SYSTEM statements to disable/modify logging';
END
$$;

COMMIT;
