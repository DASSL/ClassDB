--addHelpers.sql - ClassDB

--Sean Murthy, Andrew Figueroa, Steven Rollo
--Data Science & Systems Lab (DASSL)
--https://dassl.github.io/

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.


--This script requires the current user to be a superuser

--This script should be run in every database to which ClassDB is to be added
-- it should be run after running initializeDB.sql

--This script creates some helper functions for ClassDB operations
-- makes ClassDB role the owner of all functions so only that role can drop or
--  replace the functions
-- permits any role to execute these functions, but defines the functions in the
--  ClassDB schema so uninstall scripts can easily remove the functions

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


--Create a custom domain to represent "identifier names"
-- role names, user names, schema names, and other such names are ID names
-- create the domain only if it does not already exist
--  must query info schema because there is no "CREATE DOMAIN IF NOT EXISTS"
-- from as far back Postgres 8.1 and as of Postgres 10.1, 63 is the default max
--  length of an ID name default distribution; the length can be changed by
--  changing the DBMS source code
--  see: https://www.postgresql.org/docs/10/static/sql-syntax-lexical.html
DO
$$
BEGIN
   IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.DOMAINS
                  WHERE domain_schema = 'classdb' AND domain_name = 'idnamedomain'
                 )
   THEN
      CREATE DOMAIN ClassDB.IDNameDomain VARCHAR(63);
   END IF;
END;
$$;

--Notes on type conversion between ClassDB.IDNameDomain and VARCHAR
-- DBMS coerces among VARCHAR, TEXT, and ClassDB.IDNameDomain, but
--  functions which return type ClassDB.IDNameDomain must explicitly cast
--  VARCHAR or TEXT
-- an exception is raised if a string longer than 63 characters is assigned to
--  a variable of type ClassDB.IDNameDomain


--Define a function to replicate PostgreSQL's folding behavior for SQL IDs
-- If identifier is quoted, then the same value is returned with quotes removed
-- If it is not, then identifier is returned, but made lowercase
-- The return type is intentionally left as VARCHAR (instead of ClassDB.IDName)
--  due to how this function is used
CREATE OR REPLACE FUNCTION
   ClassDB.foldPgID(identifier VARCHAR(65))
   RETURNS VARCHAR(63) AS
$$
   SELECT
      CASE WHEN SUBSTRING($1 from 1 for 1) = '"' AND
                SUBSTRING($1 from LENGTH($1) for 1) = '"'
            THEN
               SUBSTRING($1 from 2 for LENGTH($1) - 2)
            ELSE
               LOWER($1)
      END;
$$ LANGUAGE sql;

ALTER FUNCTION ClassDB.foldPgID(VARCHAR(65)) OWNER TO ClassDB;


--Define a function to test if a role name is a ClassDB role name
-- tests if the name supplied is one of the following strings:
--  'classdb_student', 'classdb_instructor', 'classdb_manager'
CREATE OR REPLACE FUNCTION
   ClassDB.isClassDBRoleName(roleName ClassDB.IDNameDomain)
   RETURNS BOOLEAN AS
$$
   SELECT ClassDB.foldPgID($1)
          IN ('classdb_student', 'classdb_instructor', 'classdb_manager');
$$ LANGUAGE sql;

ALTER FUNCTION ClassDB.isClassDBRoleName(ClassDB.IDNameDomain) OWNER TO ClassDB;


--Define a function to test if a role is "defined" in the DBMS
-- a role is defined if a pg_catalog.pg_roles row exists for the supplied name
-- use this function to test if a string represents the name of a server role
CREATE OR REPLACE FUNCTION
   ClassDB.isServerRoleDefined(roleName ClassDB.IDNameDomain)
   RETURNS BOOLEAN AS
$$
   SELECT EXISTS (SELECT * FROM pg_catalog.pg_roles
                  WHERE rolname = ClassDB.foldPgID($1)
                 );
$$ LANGUAGE sql;

ALTER FUNCTION ClassDB.isServerRoleDefined(ClassDB.IDNameDomain) OWNER TO ClassDB;


--Define a function to test if a user is a member of a role
-- parameter userName can name any server role, yet it is called "userName" for
--  consistency with Postgres function pg_catalog.pg_has_role (see Postgres docs)
CREATE OR REPLACE FUNCTION
   ClassDB.isMember(userName ClassDB.IDNameDomain, roleName ClassDB.IDNameDomain)
   RETURNS BOOLEAN AS
$$
   SELECT
      EXISTS
      (
         SELECT * FROM pg_catalog.pg_roles
         WHERE pg_catalog.pg_has_role(ClassDB.foldPgID($1), oid, 'member')
               AND rolname = ClassDB.foldPgID($2)
      );
$$ LANGUAGE sql;

ALTER FUNCTION
   ClassDB.isMember(ClassDB.IDNameDomain, ClassDB.IDNameDomain)
   OWNER TO ClassDB;


--Define a function to test if a user is a member of a ClassDB role
CREATE OR REPLACE FUNCTION ClassDB.hasClassDBRole(userName ClassDB.IDNameDomain)
   RETURNS BOOLEAN AS
$$
   SELECT
      EXISTS
      (
         SELECT * FROM pg_catalog.pg_roles
         WHERE pg_catalog.pg_has_role(ClassDB.foldPgID($1), oid, 'member')
               AND
               rolname IN
               ('classdb_student', 'classdb_instructor', 'classdb_manager')
      );
$$ LANGUAGE sql;

ALTER FUNCTION ClassDB.hasClassDBRole(ClassDB.IDNameDomain) OWNER TO ClassDB;


--Define a function to test if a user is a superuser
-- test current user if no user name is supplied
CREATE OR REPLACE FUNCTION
   ClassDB.isSuperUser(roleName ClassDB.IDNameDomain DEFAULT current_user)
   RETURNS BOOLEAN AS
$$
BEGIN
   IF EXISTS (SELECT * FROM pg_catalog.pg_roles
              WHERE rolname = ClassDB.foldPgID($1) AND rolsuper = TRUE
             ) THEN
      RETURN TRUE;
   ELSE
      RETURN FALSE;
   END IF;
END;
$$ LANGUAGE plpgsql;

--Make ClassDB the function owner so only that role can drop/replace the function
ALTER FUNCTION ClassDB.isSuperUser(ClassDB.IDNameDomain) OWNER TO ClassDB;


--Define a function to test if a user has CREATEROLE privilege
-- test current user if no user name is supplied
CREATE OR REPLACE FUNCTION
   ClassDB.hasCreateRole(roleName ClassDB.IDNameDomain DEFAULT current_user)
   RETURNS BOOLEAN AS
$$
BEGIN
   IF EXISTS (SELECT * FROM pg_catalog.pg_roles
              WHERE rolname = ClassDB.foldPgID($1) AND rolcreaterole = TRUE
             ) THEN
      RETURN TRUE;
   ELSE
      RETURN FALSE;
   END IF;
END;
$$ LANGUAGE plpgsql;

ALTER FUNCTION ClassDB.hasCreateRole(ClassDB.IDNameDomain) OWNER TO ClassDB;


--Define a function to test if a user has CREATEDB privilege
-- test current user if no user name is supplied
CREATE OR REPLACE FUNCTION
   ClassDB.canCreateDatabase(roleName ClassDB.IDNameDomain DEFAULT current_user)
   RETURNS BOOLEAN AS
$$
BEGIN
   IF EXISTS (SELECT * FROM pg_catalog.pg_roles
              WHERE rolname = ClassDB.foldPgID($1) AND rolcreatedb = TRUE
             ) THEN
      RETURN TRUE;
   ELSE
      RETURN FALSE;
   END IF;
END;
$$ LANGUAGE plpgsql;

ALTER FUNCTION ClassDB.canCreateDatabase(ClassDB.IDNameDomain) OWNER TO ClassDB;


--Define a function to test if a role can log in
-- test current user if no user name is supplied
CREATE OR REPLACE FUNCTION
   ClassDB.canLogin(roleName ClassDB.IDNameDomain DEFAULT current_user)
   RETURNS BOOLEAN AS
$$
BEGIN
   IF EXISTS (SELECT * FROM pg_catalog.pg_roles
              WHERE rolname = ClassDB.foldPgID($1) AND rolcanlogin = TRUE
             ) THEN
      RETURN TRUE;
   ELSE
      RETURN FALSE;
   END IF;
END;
$$ LANGUAGE plpgsql;

ALTER FUNCTION ClassDB.canLogin(ClassDB.IDNameDomain) OWNER TO ClassDB;


--Define a function to list all  objects owned by some role.  This query
-- uses pg_class, which lists all objects Postgres considers relations, such as
-- tables, views, and type. We UNION with pg_proc, which contains a list of all functions.
-- The Postgres views are used because they contain the owner of each object, which
CREATE OR REPLACE FUNCTION
   ClassDB.listOwnedObjects(roleName ClassDB.IDNameDomain DEFAULT current_user)
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
   END
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

ALTER FUNCTION ClassDB.listOwnedObjects(ClassDB.IDNameDomain) OWNER TO ClassDB;

REVOKE ALL ON FUNCTION ClassDB.listOwnedObjects(ClassDB.IDNameDomain) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION ClassDB.listOwnedObjects(ClassDB.IDNameDomain)
      TO ClassDB_Instructor, ClassDB_DBManager;


--Define a function to list all 'orphan' objects owned by ClassDB_Instructor and
-- ClassDB_DBManager. This will list all objects that were owned by a dropped instructor
-- or dbmanager outside of their schema, which were then reassigned. By default, it
-- will list all objects from both roles. If a parameter starting with i or I is passed,
-- it will list only Instructor objects, If a Parameter starting with d or D is passed,
-- it will list only DBManager objects.
CREATE OR REPLACE FUNCTION
   ClassDB.listOrphanObjects(classDBRole ClassDB.IDNameDomain DEFAULT NULL)
RETURNS TABLE
(
   owner VARCHAR(63),
   object VARCHAR(63),
   schema VARCHAR(63),
   kind VARCHAR(20) --These are constant strings, max needed length is <20
) AS
$$
BEGIN
   IF $1 ILIKE 'i%' THEN
      RETURN QUERY
      SELECT 'ClassDB_Instructor'::VARCHAR(63), loo.object, loo.schema, loo.kind
      FROM ClassDB.listOwnedObjects('classdb_instructor') loo;
   ELSIF $1 ILIKE 'd%' THEN
      RETURN QUERY
      SELECT 'ClassDB_DBManager'::VARCHAR(63), loo.object, loo.schema, loo.kind
      FROM ClassDB.listOwnedObjects('classdb_dbmanager') loo;
   ELSE
      RETURN QUERY
      SELECT 'ClassDB_Instructor'::VARCHAR(63), loo.object, loo.schema, loo.kind
      FROM ClassDB.listOwnedObjects('classdb_instructor') loo
      UNION ALL
      SELECT 'ClassDB_DBManager'::VARCHAR(63), loo.object, loo.schema, loo.kind
      FROM ClassDB.listOwnedObjects('classdb_dbmanager') loo;
   END IF;
END;
$$ LANGUAGE plpgsql;

ALTER FUNCTION ClassDB.listOwnedObjects(ClassDB.IDNameDomain) OWNER TO ClassDB;

REVOKE ALL ON FUNCTION ClassDB.listOwnedObjects(ClassDB.IDNameDomain) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION ClassDB.listOwnedObjects(ClassDB.IDNameDomain)
      TO ClassDB_Instructor, ClassDB_DBManager;


--Define a function to retrieve specific capabilities a user has
-- use this function to get status of different capabilities in one call

--Commenting out the function because a unit test is yet to be developed
--CREATE OR REPLACE FUNCTION
--   ClassDB.getRoleCapabilities(roleName ClassDB.IDNameDomain,
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
--   ClassDB.getRoleCapabilities(roleName ClassDB.IDNameDomain,
--                               OUT isSuperUser BOOLEAN,
--                               OUT hasCreateRole BOOLEAN,
--                               OUT canCreateDatabase BOOLEAN)
--   OWNER TO ClassDB;


COMMIT;
