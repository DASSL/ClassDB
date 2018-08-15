--initalizeServerCore.sql - ClassDB

--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab (DASSL)
--https://dassl.github.io/

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.


--This script should be run as a user with CREATEROLE privileges

--This script should be run once on the server to which ClassDB is to be added
-- it should be the first script to run in the ClassDB installation process

--This script creates app-specific roles: ClassDB, Student, Instructor, DBManager

START TRANSACTION;


--Make sure current user has sufficient privilege (CREATEROLE) to run the script
-- privileges required: superuser
DO
$$
BEGIN
   IF NOT EXISTS (SELECT * FROM pg_catalog.pg_roles
                  WHERE rolname = CURRENT_USER AND rolsuper
                 ) THEN
      RAISE EXCEPTION 'Insufficient privileges: script must be run as a user with'
                      ' superuser privileges';
   END IF;
END
$$;


--Suppress NOTICE messages for this script only, this will not apply to functions
-- defined within. This hides messages that are unimportant, but possibly confusing
SET LOCAL client_min_messages TO WARNING;

--Define a convenient ephemeral function to create a role with the given name
-- create the role only if it does not already exist
-- this function will be automatically dropped when the current session ends
CREATE OR REPLACE FUNCTION pg_temp.createGroupRole(roleName VARCHAR(63)) RETURNS VOID AS
$$
BEGIN
   IF NOT EXISTS (SELECT * FROM pg_catalog.pg_roles
                  WHERE rolname = $1
                 ) THEN
      EXECUTE FORMAT('CREATE ROLE %s', $1);
   END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;



--Create app-specific roles and give ClassDB role the following capabilities:
-- create roles and databases, cancel queries and terminate,
-- and do all the things students, instructors, and DB managers can do
DO
$$
BEGIN
   PERFORM pg_temp.createGroupRole('classdb');

   ALTER ROLE ClassDB CREATEROLE CREATEDB;

   --server role pg_signal_backend was introduced in pg9.6
   -- remove this check when pg9.5 is no longer supported
   --The setting server_version_num returns an integer form of version number
   -- e.g., 90603 for version 9.6.3; 90500 for 9.5.0
   -- https://www.postgresql.org/docs/10/static/runtime-config-preset.html
   --Query setting directly because helpers fns are unavailable in this script
   IF 90600 <= (SELECT setting::integer FROM pg_catalog.pg_settings
              WHERE name = 'server_version_num'
             ) THEN
      GRANT pg_signal_backend TO ClassDB;
   END IF;

   PERFORM pg_temp.createGroupRole('classdb_student');
   PERFORM pg_temp.createGroupRole('classdb_instructor');
   PERFORM pg_temp.createGroupRole('classdb_dbmanager');
   PERFORM pg_temp.createGroupRole('classdb_team');

   GRANT ClassDB_Student, ClassDB_Instructor, ClassDB_DBManager, ClassDB_Team
   TO ClassDB;
END
$$;


COMMIT;
