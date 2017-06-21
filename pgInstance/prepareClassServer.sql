--prepareClassServer.sql - ClassDB

--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab (DASSL), Western Connecticut State University (WCSU)

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC: https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.


--This script should be run as a user with createrole privileges

--This script creates a role for the internal operations of ClassDB, followed by roles for 
-- instructors, DBManagers, and students.

START TRANSACTION;

--Tests for createrole privilege on current_user
DO
$$
DECLARE
   canCreateRole BOOLEAN;
BEGIN
   SELECT rolcreaterole FROM pg_catalog.pg_roles WHERE rolname = current_user INTO canCreateRole;
   IF NOT canCreateRole THEN
      RAISE EXCEPTION 'Insufficient privileges: the script must be run by a user with "createrole" privileges';
   END IF;
END
$$;

--Group equivalents for managing permissions for students, instructors, and managers of the DB
DO
$$
BEGIN
   IF NOT EXISTS (SELECT * FROM pg_catalog.pg_roles WHERE rolname = 'classdb') THEN
      CREATE ROLE ClassDB;
   END IF;
   ALTER ROLE ClassDB createrole;
   
   IF NOT EXISTS (SELECT * FROM pg_catalog.pg_roles WHERE rolname = 'instructor') THEN
      CREATE ROLE Instructor;
   END IF;
   
   IF NOT EXISTS (SELECT * FROM pg_catalog.pg_roles WHERE rolname = 'dbmanager') THEN
      CREATE ROLE DBManager;
   END IF;

   IF NOT EXISTS (SELECT * FROM pg_catalog.pg_roles WHERE rolname = 'student') THEN
      CREATE ROLE Student;
   END IF;
END
$$;

COMMIT;
