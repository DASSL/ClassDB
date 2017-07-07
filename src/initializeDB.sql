--initializeDB.sql - ClassDB

--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab (DASSL), Western Connecticut State University (WCSU)

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.


--This script requires the current user to be a superuser

--This script should be run in a database to which ClassDB is to be added
-- the database should have already been created

--This script should be the first to run as part of adding ClassDB to a database

--This script sets up appropriate access controls for the various ClassDB roles
-- it also creates a 'ClassDB' schema to store app-specific data and code


START TRANSACTION;


--Make sure the current user has sufficient privilege to run this script
-- privilege required: superuser
DO
$$
BEGIN
   IF NOT EXISTS (SELECT * FROM pg_catalog.pg_roles
                  WHERE rolname = current_user AND rolsuper = TRUE
                 ) THEN
      RAISE EXCEPTION 'Insufficient privileges: script must be run as a user '
                      'with superuser privileges';
   END IF;
END
$$;


--Make sure the expected app-specific roles are already defined:
-- four roles expected: ClassDB, Instructor, DBManager, Student
DO
$$
DECLARE
   classDBRoleCount NUMERIC(1);
BEGIN
   SELECT COUNT(*)
   FROM pg_catalog.pg_roles
   WHERE rolname IN ('classdb', 'classdb_instructor',
                     'classdb_dbmanager', 'classdb_student'
                    )
   INTO classDBRoleCount;

   IF classDBRoleCount <> 4 THEN
      RAISE EXCEPTION
         'Missing roles: one or more expected of the expected ClassDB roles '
         'are undefined';
   END IF;
END
$$;


--Grant appropriate privileges to different roles to the current database
DO
$$
DECLARE
   currentDB VARCHAR(128);
BEGIN
   currentDB := current_database();

   --Disallow DB connection to all users
   -- Postgres grants CONNECT to all by default
   EXECUTE format('REVOKE CONNECT ON DATABASE %I FROM PUBLIC', currentDB);

   --Let only app-specific roles connect to the DB
   -- no need for ClassDB to connect to the DB
   EXECUTE format('GRANT CONNECT ON DATABASE %I TO ClassDB_Instructor, '
                  'ClassDB_Student, ClassDB_DBManager', currentDB);

   --Allow ClassDB to create schemas on the current database
   -- all schema-creation operations are done only by this role in this app
   EXECUTE format('GRANT CREATE ON DATABASE %I TO ClassDB', currentDB);
END
$$;


--Prevent students from modifying the public schema
-- public schema contains objects and functions students can read
REVOKE CREATE ON SCHEMA public FROM ClassDB_Student;

--Create a schema to hold app's admin info and assign privileges on that schema
CREATE SCHEMA IF NOT EXISTS classdb;
GRANT ALL PRIVILEGES ON SCHEMA classdb
   TO ClassDB, ClassDB_Instructor, ClassDB_DBManager;


--Grant ClassDB to the current user
-- allows altering privilieges of objects, even after being owned by ClassDB
GRANT ClassDB TO current_user;


COMMIT;
