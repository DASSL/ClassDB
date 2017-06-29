--prepareClassServer.sql - ClassDB

--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab (DASSL), Western Connecticut State University (WCSU)

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.


--This script should be run as a user with createrole privileges

--This script creates app-specific rolse: ClassDB, Student, Instructor, DBManager

START TRANSACTION;

--Make sure current user has sufficient privilege ("createrole") to run the script
DO
$$
BEGIN
   IF NOT EXISTS(SELECT * FROM pg_catalog.pg_roles
                 WHERE rolname = current_user AND rolcreaterole = TRUE
                ) THEN
      RAISE EXCEPTION 'Insufficient privileges: script must be run as a user with createrole privileges';
   END IF;
END
$$;

--Define a convenient ephemeral function to create a role with the given name
-- create the role only if it does not already exist
-- this function will be automatically dropped when the current session ends
CREATE OR REPLACE FUNCTION pg_temp.createGroupRole(roleName VARCHAR(50)) RETURNS VOID AS
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

   PERFORM pg_temp.createGroupRole('Student');
   PERFORM pg_temp.createGroupRole('Instructor');
   PERFORM pg_temp.createGroupRole('DBManager');
END
$$;

COMMIT;
