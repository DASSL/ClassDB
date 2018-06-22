--addHelpersCore.sql - ClassDB

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
-- helper functions instead of repeating code



START TRANSACTION;

--Make sure the current user has sufficient privilege to run this script
-- privilege required: superuser
DO
$$
BEGIN
   IF NOT EXISTS (SELECT * FROM pg_catalog.pg_roles
                  WHERE rolname = CURRENT_USER AND rolsuper = TRUE
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
      ALTER DOMAIN ClassDB.IDNameDomain OWNER TO ClassDB;
   END IF;
END;
$$;

--Notes on type conversion between ClassDB.IDNameDomain and VARCHAR
--DBMS coerces among VARCHAR, TEXT, and ClassDB.IDNameDomain on assignment, but
-- functions which return type ClassDB.IDNameDomain must explicitly cast
-- a VARCHAR or TEXT they wish to return as ClassDB.IDNameDomain
--an exception is raised if a string longer than 63 characters is assigned to
-- a variable of type ClassDB.IDNameDomain
--Data of type NAME must be explicitly cast to ClassDB.IDNameDomain (or to
-- VARCHAR or TEXT) for assignment though Postgres docs say such casting is auto
-- Example: use CURRENT_USER::ClassDB.IDNameDomain when passing as parameter
--Postgres does not support custom casts involving domains because conversion is
-- automatic via the underlying type, but that does not work from NAME to
-- ClassDB.IDNameDomain
-- See: https://www.postgresql.org/docs/9.6/static/sql-createcast.html



--Define a function to replicate PostgreSQL's folding behavior for SQL IDs
-- if identifier is quoted, it is returned as is but without the quotes
-- if unquoted, the identifier is returned in lower case
--The return type is intentionally left as VARCHAR (instead of ClassDB.IDName)
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
$$ LANGUAGE sql
   IMMUTABLE
   RETURNS NULL ON NULL INPUT;

ALTER FUNCTION ClassDB.foldPgID(VARCHAR(65)) OWNER TO ClassDB;



--Define a function to get the name of the owner of a schema
-- returns NULL if schema is not found
CREATE OR REPLACE FUNCTION
   ClassDB.getSchemaOwnerName(schemaName ClassDB.IDNameDomain)
   RETURNS ClassDB.IDNameDomain AS
$$
   --this query generally works but was observed as failing in one circumstance
   --yet keeping it because unit tests pass and usage in addRoleBaseMgmt.sql works
   --use the pg_catalog workaround shown below if necessary
   SELECT schema_owner::ClassDB.IDNameDomain
   FROM information_schema.schemata
   WHERE schema_name = ClassDB.foldPgID($1);

   --system pg_catalog instead of information_schema as a work around to any
   --issue with using INFORMATION_SCHEMA
   --SELECT r.rolname::ClassDB.IDNameDomain
   --FROM pg_catalog.pg_namespace ns
   --     JOIN pg_catalog.pg_roles r ON ns.nspowner = r.oid
   --WHERE nspname = ClassDB.foldPgID($1);

$$ LANGUAGE sql
   STABLE
   RETURNS NULL ON NULL INPUT;

ALTER FUNCTION ClassDB.getSchemaOwnerName(ClassDB.IDNameDomain) OWNER TO ClassDB;



--Define a function to test if a role name is a ClassDB role name
-- tests if the name supplied is one of the following strings:
--  'classdb_student', 'classdb_instructor', 'classdb_manager', 'classdb_team'
CREATE OR REPLACE FUNCTION
   ClassDB.isClassDBRoleName(roleName ClassDB.IDNameDomain)
   RETURNS BOOLEAN AS
$$
   SELECT ClassDB.foldPgID($1)
          IN ('classdb_instructor', 'classdb_student',
              'classdb_dbmanager', 'classdb_team');
$$ LANGUAGE sql
   IMMUTABLE
   RETURNS NULL ON NULL INPUT;

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
$$ LANGUAGE sql
   STABLE
   RETURNS NULL ON NULL INPUT;

ALTER FUNCTION ClassDB.isServerRoleDefined(ClassDB.IDNameDomain) OWNER TO ClassDB;


--Define a function to test if a user is a member of a role
-- parameter userName can name any server role, yet it is called "userName" for
-- consistency with Postgres function pg_catalog.pg_has_role (see Postgres docs)
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
$$ LANGUAGE sql
   STABLE
   RETURNS NULL ON NULL INPUT;

ALTER FUNCTION ClassDB.isMember(ClassDB.IDNameDomain, ClassDB.IDNameDomain)
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
               ClassDB.isClassDBRoleName(rolname::ClassDB.IDNameDomain)
      );
$$ LANGUAGE sql
   STABLE
   RETURNS NULL ON NULL INPUT;

ALTER FUNCTION ClassDB.hasClassDBRole(ClassDB.IDNameDomain) OWNER TO ClassDB;


--Define a function to test if a user is a superuser
-- test current user if no user name is supplied
CREATE OR REPLACE FUNCTION
   ClassDB.isSuperUser(roleName ClassDB.IDNameDomain DEFAULT CURRENT_USER)
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
$$ LANGUAGE plpgsql
   STABLE
   RETURNS NULL ON NULL INPUT;

ALTER FUNCTION ClassDB.isSuperUser(ClassDB.IDNameDomain) OWNER TO ClassDB;


--Define a function to test if a user has CREATEROLE privilege
-- test current user if no user name is supplied
CREATE OR REPLACE FUNCTION
   ClassDB.hasCreateRole(roleName ClassDB.IDNameDomain DEFAULT CURRENT_USER)
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
$$ LANGUAGE plpgsql
   STABLE
   RETURNS NULL ON NULL INPUT;

ALTER FUNCTION ClassDB.hasCreateRole(ClassDB.IDNameDomain) OWNER TO ClassDB;


--Define a function to test if a user has CREATEDB privilege
-- test current user if no user name is supplied
CREATE OR REPLACE FUNCTION
   ClassDB.canCreateDatabase(roleName ClassDB.IDNameDomain DEFAULT CURRENT_USER)
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
$$ LANGUAGE plpgsql
   STABLE
   RETURNS NULL ON NULL INPUT;

ALTER FUNCTION ClassDB.canCreateDatabase(ClassDB.IDNameDomain) OWNER TO ClassDB;


--Define a function to test if a role can log in
-- test current user if no user name is supplied
CREATE OR REPLACE FUNCTION
   ClassDB.canLogin(roleName ClassDB.IDNameDomain DEFAULT CURRENT_USER)
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
$$ LANGUAGE plpgsql
   STABLE
   RETURNS NULL ON NULL INPUT;

ALTER FUNCTION ClassDB.canLogin(ClassDB.IDNameDomain) OWNER TO ClassDB;



--Define a function to grant a role ("role") to another role ("receiver")
-- current user is the default receiver
-- grants role to receiver only if receiver is not already a member of the role
-- raises a custom exception if grant fails due to insufficient privilege and
-- includes the original error message as a hint
-- re-raises all other exceptions
-- this function must be VOLATILE; marking it STABLE raises the following exception
--    ERROR: GRANT ROLE is not allowed in a non-volatile function
--    SQL state: 0A000
CREATE OR REPLACE FUNCTION
   ClassDB.grantRole(roleName ClassDB.IDNameDomain,
                     receiverName ClassDB.IDNameDomain DEFAULT CURRENT_USER
                    )
   RETURNS VOID AS
$$
BEGIN
   IF NOT ClassDB.isMember($2, $1) THEN
      EXECUTE FORMAT('GRANT %s TO %s', $1, $2);
   END IF;
EXCEPTION
   WHEN insufficient_privilege THEN
      RAISE EXCEPTION 'Insufficient privilege: Executing user % '
                      'cannot grant role % to role %', CURRENT_USER, $1, $2
                      USING HINT = SQLERRM;
   WHEN OTHERS THEN
      RAISE;
END;
$$ LANGUAGE plpgsql
  RETURNS NULL ON NULL INPUT;

ALTER FUNCTION ClassDB.grantRole(ClassDB.IDNameDomain, ClassDB.IDNameDomain)
   OWNER TO ClassDB;


--Define a function to list all objects owned by a role. This query uses
-- pg_class which lists all objects Postgres considers relations (tables, views,
-- and types) and UNIONs with pg_proc include functions
--Postgres views are used because they contain the owner of each object
CREATE OR REPLACE FUNCTION
   ClassDB.listOwnedObjects(roleName ClassDB.IDNameDomain DEFAULT CURRENT_USER)
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
      WHEN c.relkind = 'S' THEN 'Sequence'
      WHEN c.relkind = 'v' THEN 'View'
      WHEN c.relkind = 'm' THEN 'Materialized View'
      WHEN c.relkind = 'c' THEN 'Type'
      WHEN c.relkind = 't' THEN 'TOAST'
      WHEN c.relkind = 'f' THEN 'Foreign Table'
      ELSE NULL
   END
   FROM pg_catalog.pg_class c
   JOIN pg_catalog.pg_roles r ON r.oid = c.relowner
   JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
   WHERE r.rolname = ClassDB.foldPgID($1)
   UNION ALL
   SELECT p.proname::VARCHAR(63), n.nspname::VARCHAR(63), 'Function'
   FROM pg_catalog.pg_proc p
   JOIN pg_catalog.pg_roles r ON r.oid = p.proowner
   JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
   WHERE r.rolname = ClassDB.foldPgID($1);
$$ LANGUAGE sql
   STABLE
   RETURNS NULL ON NULL INPUT;

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
$$ LANGUAGE plpgsql
   STABLE
   RETURNS NULL ON NULL INPUT;

ALTER FUNCTION ClassDB.listOrphanObjects(ClassDB.IDNameDomain) OWNER TO ClassDB;

REVOKE ALL ON FUNCTION ClassDB.listOrphanObjects(ClassDB.IDNameDomain) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION ClassDB.listOrphanObjects(ClassDB.IDNameDomain)
   TO ClassDB_Instructor, ClassDB_DBManager;


--Define a function to reassign ownership of an object. The executing user must
-- have appropriate privileges to run statements that alter the object's 
-- ownership. This includes privileges for the object, schema, and new owner
--objectType must be one of the types that are identified by
-- ClassDB.listOwnedObjects() NOTE: Foreign tables are not currently supported
--Note that reassignment of TOAST tables and indexes is not necessary, nor
-- possible. They are automatically handled via the ownership of their
-- corresponding table
--Descendant tables of reassigned tables do not have their ownership changed
--objectName must be an object in the current db, schema qualified if necessary
--newOwner must be a valid server role
--okIfNotExists determines whether exceptions are raised if the object does not
-- exist (if true, notices are raised if the object does not exist)
CREATE OR REPLACE FUNCTION
   ClassDB.reassignObjectOwnership(objectType VARCHAR(20),
                                   objectName VARCHAR(63),
                                   newOwner ClassDB.IDNameDomain
                                    DEFAULT CURRENT_USER,
                                   okIfNotExists BOOLEAN DEFAULT FALSE
                                  )
   RETURNS VOID AS
$$
BEGIN
   
   --stop if objectType matches TOAST table
   $1 = LOWER(TRIM($1));
   IF $1 = 'toast' THEN
      RAISE WARNING 'ownership of a TOAST tables is managed through ownership' 
                    ' of its user table';
      RETURN;
   END IF;
   
   --stop if objectType matches Index
   IF $1 = 'index' THEN
      RAISE WARNING 'ownership of an index is managed though ownership of its'
                    ' underlying table';
      RETURN;
   END IF;

   --stop if objectType matches Foreign table (not tested)
   IF $1 = 'foreign table' THEN
      RAISE EXCEPTION 'transferring ownership of foreign tables is not currently'
                       ' supported'
            USING DETAIL  = 'foreign table name: "%"; requested new owner: "%"',
                              $2, $3
            USING HINT = 'manually transfer ownership using ALTER FOREIGN TABLE';
   END IF;
   
   --match value of objectType to objects types that can be reassigned
   IF $1 = 'table' THEN $1 = 'TABLE';
   ELSEIF $1 = 'sequence' THEN $1 = 'SEQUENCE';
   ELSEIF $1 = 'view' THEN $1 = 'VIEW';
   ELSEIF OR $1 = 'materialized view' THEN $1 = 'MATERIALIZED VIEW';
   ELSEIF OR $1 = 'type' THEN $1 = 'TYPE';
   ELSEIF $1 = 'function' THEN $1 = 'FUNCTION';
   ELSE
      --invalid type provided
      RAISE EXCEPTION 'objectType "%" is not a valid object type for'
                      ' ownership reassignment', $1;
   END IF;
   
   --execute command to reassign ownership. A separate statement is used for
   -- tables to avoid reassigning descendant tables
   IF $1 = 'TABLE' THEN
      IF $4 THEN
         EXECUTE FORMAT('ALTER TABLE IF EXISTS ONLY %s OWNER TO %s', $2, $3);
      ELSE
         EXECUTE FORMAT('ALTER TABLE ONLY %s OWNER TO %s', $2, $3);
      END IF;
   ELSEIF $4 THEN
      EXECUTE FORMAT('ALTER %s IF EXISTS %s OWNER TO %s', $1, $2, $3);
   ELSE
      EXECUTE FORMAT('ALTER %s %s OWNER TO $s', $1, $2, $3);
   END IF;
END;
$$ LANGUAGE plpgsql
   RETURNS NULL ON NULL INPUT;

ALTER FUNCTION ClassDB.reassignObjectOwnership(VARCHAR, VARCHAR,
                                               ClassDB.IDNameDomain, BOOLEAN)
   OWNER TO ClassDB;


--Define a function to reassign ownership of objects within a specific schema
-- that are owned by a specific role
--schemaName must be an existing schema in the current database
--oldOwner and newOwner must be existing server roles
--Executes with the privileges of the executing user, meaning that the current
-- security context must allow transferring the owned objects in question
CREATE OR REPLACE FUNCTION
   ClassDB.reassignOwnedInSchema(schemaName ClassDB.IDNameDomain,
                                 oldOwner ClassDB.IDNameDomain,
                                 newOwner ClassDB.IDNameDomain
                                  DEFAULT CURRENT_USER
                                )
   RETURNS VOID AS
$$
BEGIN
   --reassign ownership of each owned object in the specified schema
   SELECT ClassDB.reassignObjectOwnership(lob.kind, $1 || '.' || lob.object, $3)
   FROM ClassDB.listOwnedObjects($2) lob
   WHERE lob.schema = ClassDB.foldPgID($1) AND lob.kind NOT IN('Index', 'TOAST');
END;
$$ LANGUAGE plpgsql
   RETURNS NULL ON NULL INPUT;

ALTER FUNCTION
   ClassDB.reassignOwnedInSchema(ClassDB.IDNameDomain, ClassDB.IDNameDomain,
                                 ClassDB.IDNameDomain)
   OWNER TO ClassDB;


--Changes a timestamp in fromTimeZone to toTimeZone
CREATE OR REPLACE FUNCTION
   ClassDB.changeTimeZone
   (ts TIMESTAMP,
    toTimeZone VARCHAR DEFAULT TO_CHAR(CURRENT_TIMESTAMP, 'TZ'),
    fromTimeZone VARCHAR DEFAULT 'UTC'
   )
RETURNS TIMESTAMP AS
$$
   SELECT (ts AT TIME ZONE COALESCE(fromTimeZone, 'UTC')) AT TIME ZONE
      COALESCE(toTimeZone, TO_CHAR(CURRENT_TIMESTAMP, 'TZ'));
$$ LANGUAGE sql
   SECURITY DEFINER;

ALTER FUNCTION
   ClassDB.ChangeTimeZone(ts TIMESTAMP, toTimeZone VARCHAR, fromTimeZone VARCHAR)
   OWNER TO ClassDB;
 


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
