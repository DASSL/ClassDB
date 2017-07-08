--addHelpers.sql - ClassDB

--Sean Murthy
--Data Science & Systems Lab (DASSL), Western Connecticut State University (WCSU)

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.


--This script requires the current user to be a superuser

--This script should be run in every database to which ClassDB is to be added
-- it should be run after running initializeDB.sql

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


--Define a function to replicate PostgreSQL's folding behavior for SQL IDs
-- If identifier is quoted, then the same value is returned with quotes removed
-- If it is not, then identifier is returned, but made lowercase
CREATE OR REPLACE FUNCTION
   classdb.foldPgID(identifier VARCHAR(65))
   RETURNS VARCHAR(63) AS
$$
SELECT CASE WHEN SUBSTRING($1 from 1 for 1) = '"' AND
                 SUBSTRING($1 from LENGTH($1) for 1) = '"'
            THEN
                 SUBSTRING($1 from 2 for LENGTH($1) - 2)
            ELSE
                 LOWER($1)
       END;
$$ LANGUAGE sql;

ALTER FUNCTION
   classdb.foldPgID(identifier VARCHAR(65))
   OWNER TO ClassDB;


--Define a function to test if a role is "defined"
-- a role is defined if a pg_catalog.pg_roles row exists for the supplied name
-- use this function to test if a string represents the name of a server role
CREATE OR REPLACE FUNCTION
   classdb.isRoleDefined(roleName VARCHAR(63))
   RETURNS BOOLEAN AS
$$
BEGIN
   IF EXISTS (SELECT * FROM pg_catalog.pg_roles
              WHERE rolname = classdb.foldPgID($1)) THEN
      RETURN TRUE;
   ELSE
      RETURN FALSE;
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
              WHERE rolname = classdb.foldPgID($1) AND rolsuper = TRUE
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
              WHERE rolname = classdb.foldPgID($1) AND rolcreaterole = TRUE
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
              WHERE rolname = classdb.foldPgID($1) AND rolcreatedb = TRUE
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
              WHERE rolname = classdb.foldPgID($1) AND rolcanlogin = TRUE
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

--Define a function to list all  objects owned by some role.  This query
-- uses pg_class, which lists all objects Postgres considers relations, such as
-- tables, views, and type.  We UNION with pg_proc, which contains a list of all functions.
-- The Postgres views are used because they contain the owner of each object, which
CREATE OR REPLACE FUNCTION classdb.listOwnedObjects(roleName VARCHAR(63) DEFAULT current_user)
RETURNS TABLE
(
   object VARCHAR(63),
   schema VARCHAR(63),
   kind VARCHAR(20) --These are constant strings, max needed length is <20
) AS
$$
   SELECT c.relname::VARCHAR(63), n.nspname::VARCHAR(63),
   CASE --Output the full name of each relation type from the char code
      WHEN c.relkind = 'r' THEN 'Table'
      WHEN c.relkind = 'i' THEN 'Index'
      WHEN c.relkind = 's' THEN 'Sequence'
      WHEN c.relkind = 'v' THEN 'View'
      WHEN c.relkind = 'm' THEN 'Materialized View'
      WHEN c.relkind = 'c' THEN 'Type'
      WHEN c.relkind = 't' THEN 'TOAST'
      WHEN c.relkind = 'f' THEN 'Foreign Table'
      ELSE NULL
   END objectType
   FROM pg_class c --Join pg_roles and pg_namespace to get the names of the role and schema
   JOIN pg_roles r ON r.oid = c.relowner
   JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE r.rolname = $1
   UNION ALL
   SELECT p.proname::VARCHAR(63), n.nspname::VARCHAR(63), 'Function'
   FROM pg_proc p
   JOIN pg_roles r ON r.oid = p.proowner
   JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE r.rolname = $1;
$$ LANGUAGE sql;

ALTER FUNCTION
   classdb.listOwnedObjects(userName VARCHAR(63))
   OWNER TO ClassDB;

REVOKE ALL ON FUNCTION
   classdb.listOwnedObjects(userName VARCHAR(63))
   FROM PUBLIC;

GRANT EXECUTE ON FUNCTION
   classdb.listOwnedObjects(userName VARCHAR(63))
   TO ClassDB_Instructor, ClassDB_DBManager;

--Define a function to list all 'orphan' objects owned by ClassDB_Instructor and
-- ClassDB_DBManager. This will list all objects that were owned by a dropped instructor
-- or dbmanager outside of their schema, which were then reassigned. By default, it
-- will list all objects from both roles. If a parameter starting with i or I is passed,
-- it will list only Instructor objects, If a Parameter starting with d or D is passed,
-- it will list only DBManager objects.
CREATE OR REPLACE FUNCTION classdb.listOrphanObjects(classDBRole VARCHAR(63) DEFAULT NULL)
RETURNS TABLE
(
   owner VARCHAR(63),
   object VARCHAR(63),
   schema VARCHAR(63),
   kind VARCHAR(20) --These are constant strings, max needed length is <20
) AS
$$
   IF $1 ILIKE 'i%' THEN
      SELECT 'ClassDB_Instructor', object, schema, kind
      FROM classdb.listOwnedObjects('classdb_instructor');
   ELSIF $1 ILIKE 'd%' THEN
      SELECT 'ClassDB_DBManager', object, schema, kind
      FROM classdb.listOwnedObjects('classdb_dbmanager');
   ELSE
      SELECT 'ClassDB_Instructor', object, schema, kind
      FROM classdb.listOwnedObjects('classdb_instructor')
      UNION ALL
      SELECT 'ClassDB_DBManager', object, schema, kind
      FROM classdb.listOwnedObjects('classdb_dbmanager');
   END IF;
$$ LANGUAGE sql;

ALTER FUNCTION
   classdb.listOrphans()
   OWNER TO ClassDB;

REVOKE ALL ON FUNCTION
   classdb.listOrphans()
   FROM PUBLIC;

GRANT EXECUTE ON FUNCTION
   classdb.listOrphans()
   TO ClassDB_Instructor, ClassDB_DBManager;


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
