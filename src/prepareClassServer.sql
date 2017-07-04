--prepareClassServer.sql - ClassDB

--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab (DASSL), Western Connecticut State University (WCSU)

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.


--This script should be run as a user with CREATEROLE privileges

--This script creates app-specific roles: ClassDB, Student, Instructor, DBManager

START TRANSACTION;


--Make sure current user has sufficient privilege (CREATEROLE) to run the script
DO
$$
BEGIN
   IF NOT EXISTS(SELECT * FROM pg_catalog.pg_roles
                 WHERE rolname = current_user AND rolcreaterole = TRUE
                ) THEN
      RAISE EXCEPTION 'Insufficient privileges: script must be run as a user '
                      'with createrole privileges';
   END IF;
END
$$;


DROP FUNCTION IF EXISTS pg_temp.createGroupRole(roleName VARCHAR(63));
--Define a convenient ephemeral function to create a role with the given name
-- create the role only if it does not already exist
-- this function will be automatically dropped when the current session ends
CREATE FUNCTION pg_temp.createGroupRole(roleName VARCHAR(63)) RETURNS VOID AS
$$
BEGIN
   IF NOT EXISTS (SELECT * FROM pg_catalog.pg_roles
                  WHERE rolname = $1
                 ) THEN
      EXECUTE format('CREATE ROLE %s', $1);
   END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;

--Create app-specific roles
-- also give the ClassDB role the ability to create roles and databases
DO
$$
BEGIN
   PERFORM pg_temp.createGroupRole('ClassDB');

   ALTER ROLE ClassDB CREATEROLE CREATEDB;
   GRANT pg_signal_backend TO ClassDB;

   PERFORM pg_temp.createGroupRole('ClassDB_Student');
   PERFORM pg_temp.createGroupRole('ClassDB_Instructor');
   PERFORM pg_temp.createGroupRole('ClassDB_DBManager');
END
$$;


COMMIT;
