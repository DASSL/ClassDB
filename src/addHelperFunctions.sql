--addHelperFunctions.sql - ClassDB

--Sean Murthy
--Data Science & Systems Lab (DASSL), Western Connecticut State University (WCSU)

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.


--This script requires the current user to be a superuser

--This script should be run after running prepareClassServer.sql

--This script should be the first to run in every database to which ClassDB is
-- is to be added

--This script creates some helper functions for ClassDB operations
-- makes ClassDB role the owner of all functions so only that role can drop or
-- replace the functions
-- permits any role to execute these functions, but defines the functions in the
-- ClassDB schema so uninstall scripts can easily remove the functions

--All ClassDB scripts executing in the context of a database should use these
-- helper functions instead of repating code



START TRANSACTION;

--Make sure the current user has sufficient privilege to run this script
-- privilege required: superuser
DO
$$
BEGIN
   IF NOT EXISTS (SELECT * FROM pg_catalog.pg_roles
                  WHERE rolname = current_user AND rolsuper = TRUE
                 ) THEN
      RAISE EXCEPTION 'Insufficient privilege: script must be run as a superuser';
   END IF;
END
$$;


--Make sure the ClassDB role is already defined in the server
DO
$$
BEGIN
   IF NOT EXISTS (SELECT * FROM pg_catalog.pg_roles
                  WHERE rolname = 'classdb'
                 ) THEN
      RAISE EXCEPTION
         'Missing group role: role ClassDB role is not defined';
   END IF;
END
$$;

--Define a function to test if a role is "defined"
-- a role is defined if a pg_catalog.pg_roles row exists for the supplied name
-- use this function to test if a string represents the name of a server role
CREATE OR REPLACE FUNCTION
   classdb.isRoleDefined(roleName VARCHAR(63))
   RETURNS BOOLEAN AS
$$
BEGIN
   IF EXISTS (SELECT * FROM pg_catalog.pg_roles WHERE rolname = $1) THEN
      RETURN TRUE;
   ELSE
      return FALSE;
   END IF;
END;
$$ LANGUAGE plpgsql;

ALTER FUNCTION
   classdb.isRoleDefined(roleName VARCHAR(63))
   OWNER TO ClassDB;


--Define a function to test if a user is a superuser
-- test current user if no user name is supplied
CREATE OR REPLACE FUNCTION
   classdb.isSuperUser(roleName VARCHAR(63) DEFAULT current_user)
   RETURNS BOOLEAN AS
$$
BEGIN
   IF EXISTS (SELECT * FROM pg_catalog.pg_roles
              WHERE rolname = $1 AND rolsuper = TRUE
             ) THEN
      RETURN TRUE;
   ELSE
      RETURN FALSE;
   END IF;
END;
$$ LANGUAGE plpgsql;

--Make ClassDB the function owner so only that role can drop/replace the function
ALTER FUNCTION
   classdb.isSuperUser(roleName VARCHAR(63))
   OWNER TO ClassDB;


--Define a function to test if a user has CREATEROLE privilege
-- test current user if no user name is supplied
CREATE OR REPLACE FUNCTION
   classdb.hasCreateRole(roleName VARCHAR(63) DEFAULT current_user)
   RETURNS BOOLEAN AS
$$
BEGIN
   IF EXISTS (SELECT * FROM pg_catalog.pg_roles
              WHERE rolname = $1 AND rolcreaterole = TRUE
             ) THEN
      RETURN TRUE;
   ELSE
      RETURN FALSE;
   END IF;
END;
$$ LANGUAGE plpgsql;

ALTER FUNCTION
   classdb.hasCreateRole(roleName VARCHAR(63))
   OWNER TO ClassDB;


--Define a function to test if a user has CREATEDB privilege
-- test current user if no user name is supplied
CREATE OR REPLACE FUNCTION
   classdb.canCreateDatabase(roleName VARCHAR(63) DEFAULT current_user)
   RETURNS BOOLEAN AS
$$
BEGIN
   IF EXISTS (SELECT * FROM pg_catalog.pg_roles
              WHERE rolname = $1 AND rolcreatedb = TRUE
             ) THEN
      RETURN TRUE;
   ELSE
      RETURN FALSE;
   END IF;
END;
$$ LANGUAGE plpgsql;

ALTER FUNCTION
   classdb.canCreateDatabase(roleName VARCHAR(63))
   OWNER TO ClassDB;


--Define a function to test if a role can log in
-- test current user if no user name is supplied
CREATE OR REPLACE FUNCTION
   classdb.canLogin(roleName VARCHAR(63) DEFAULT current_user)
   RETURNS BOOLEAN AS
$$
BEGIN
   IF EXISTS (SELECT * FROM pg_catalog.pg_roles
              WHERE rolname = $1 AND rolcanlogin = TRUE
             ) THEN
      RETURN TRUE;
   ELSE
      RETURN FALSE;
   END IF;
END;
$$ LANGUAGE plpgsql;

ALTER FUNCTION
   classdb.canLogin(roleName VARCHAR(63))
   OWNER TO ClassDB;


--Define a function to retrieve specific capabilities a user has
-- use this function to get status of different capabilities in one call

--Commenting out the function because a unit test is yet to be developed
--CREATE OR REPLACE FUNCTION
--   classdb.getRoleCapabilities(roleName VARCHAR(63),
--                               OUT isSuperUser BOOLEAN,
--                               OUT hasCreateRole BOOLEAN,
--                               OUT canCreateDatabase BOOLEAN)
--   AS
--$$
--BEGIN
--   SELECT rolsuper, rolcreaterole, rolcreatedb FROM pg_catalog.pg_roles
--   WHERE rolname = $1;
--END;
--$$ LANGUAGE plpgsql;

--ALTER FUNCTION
--   classdb.getRoleCapabilities(roleName VARCHAR(63),
--                               OUT isSuperUser BOOLEAN,
--                               OUT hasCreateRole BOOLEAN,
--                               OUT canCreateDatabase BOOLEAN)
--   OWNER TO ClassDB;


COMMIT;
