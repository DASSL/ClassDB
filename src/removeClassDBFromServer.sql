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
BEGIN
   EXECUTE
   (
      SELECT string_agg
      (
         format
         (
            'ALTER SCHEMA %I OWNER TO %I;',
            schema_name,
            --Check if there is a user matching the schema name, and try and assign the
            -- shcema to them.  Otherwise, give it to the executing user.
            COALESCE((SELECT rolname FROM pg_roles WHERE rolname = schema_name), current_user)
         ), ' '
      )
      FROM INFORMATION_SCHEMA.SCHEMATA
      WHERE schema_owner = 'classdb'
   );
END
$$;


--Drop all remaining objects/permissions owned by Instructor and DBManager.
-- At this point, this should only drop the SELECT permissions instructors have
-- on student schemas
DROP OWNED BY ClassDB_Instructor;
DROP OWNED BY ClassDB_DBManager;
DROP OWNED BY ClassDB_Student;


--Drop app-specific roles
-- need to make sure that removeClassDBFromDB is complete
DROP ROLE IF EXISTS ClassDB_Instructor;
DROP ROLE IF EXISTS ClassDB_DBManager;
DROP ROLE IF EXISTS ClassDB_Student;
DROP ROLE IF EXISTS ClassDB;

--create a list of things users have to do on their own
DO
$$
BEGIN
   RAISE NOTICE 'Run ALTER SYSTEM statements to disable/modify logging';
END
$$;

COMMIT;
