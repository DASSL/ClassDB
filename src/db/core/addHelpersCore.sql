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
      WHEN c.relkind = 's' THEN 'Sequence'
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



--Define a function to get the value of any server setting
--Queries the catalog view pg_settings to avoid exceptions if the setting name
-- supplied is not found
--Returns NULL if the setting name supplied is not found
CREATE OR REPLACE FUNCTION
   ClassDB.getServerSetting(settingName VARCHAR)
   RETURNS VARCHAR AS
$$
   SELECT setting FROM pg_catalog.pg_settings
   WHERE name = $1;
$$ LANGUAGE sql
   RETURNS NULL ON NULL INPUT;

ALTER FUNCTION ClassDB.getServerSetting(VARCHAR) OWNER TO ClassDB;



--Define a function to get the server's version number
--Removes additional info a distro may have suffixed to the version number
-- e.g., Ubuntu's distro is known to return '10.3 (Ubuntu 10.3-1)', whereas
-- a Postgres distro returns just '10.3'
CREATE OR REPLACE FUNCTION ClassDB.getServerVersion()
   RETURNS VARCHAR AS
$$
   --get value of setting 'server_version' and remove any distro-added suffix
   SELECT TRIM(split_part(ClassDB.getServerSetting('server_version'), '(', 1));
$$ LANGUAGE sql
   RETURNS NULL ON NULL INPUT;

ALTER FUNCTION ClassDB.getServerVersion() OWNER TO ClassDB;



--Define a function to compare any two Postgres server version numbers
--Compatible with Postgres versioning policy
-- https://www.postgresql.org/support/versioning
--Optionally ignores the second part in a version number, e.g.: '6' in '9.6'
--Always ignores third part of a version number, e.g., ignores the 3 in "9.6.3"
--Return value:
-- simply returns the integer difference between corresponding parts of version#
-- negative number if version1 precedes version2
-- positive number if version1 succeeds version2
-- zero if the two versions are the same
CREATE OR REPLACE FUNCTION
   ClassDB.compareServerVersion(version1 VARCHAR, version2 VARCHAR,
                                testPart2 BOOLEAN DEFAULT TRUE
                               )
   RETURNS INTEGER AS
$$
DECLARE
   verson1Parts VARCHAR ARRAY;
   verson2Parts VARCHAR ARRAY;
   major1 INTEGER;
   major2 INTEGER;
BEGIN

   $1 = TRIM($1);
   IF ($1 = '') THEN
      RAISE EXCEPTION 'invalid argument: version1 is empty';
   END IF;

   $2 = TRIM($2);
   IF ($2 = '') THEN
      RAISE EXCEPTION 'invalid argument: version2 is empty';
   END IF;

   --remove any distro-specific suffix from the version number
   -- see function getServerVersion for details
   $1 = TRIM(split_part($1, '(', 1));
   $2 = TRIM(split_part($2, '(', 1));

   --adjust version numbers to always have two parts so later code is easier
   -- e.g., change '10' to '10.0'
   IF (POSITION('.' IN $1) = 0) THEN
      $1 = $1 || '.0';
   END IF;

   IF (POSITION('.' IN $2) = 0) THEN
      $2 = $2 || '.0';
   END IF;

   --convert each version number to an array for ease of comparison
   verson1Parts = string_to_array($1, '.');
   verson2Parts = string_to_array($2, '.');

   --cast the major version number (e.g., '9' in '9.6') to a number
   -- causes exception if input is not really numeric
   major1 = TRIM(verson1Parts[1])::INTEGER;
   major2 = TRIM(verson2Parts[1])::INTEGER;

   IF (major1 <> major2) THEN
      RETURN major1 - major2;
   ELSIF $3 THEN
      RETURN TRIM(verson1Parts[2])::INTEGER - TRIM(verson2Parts[2])::INTEGER;
   ELSE
      RETURN 0;
   END IF;

END;
$$ LANGUAGE plpgsql
   RETURNS NULL ON NULL INPUT;

ALTER FUNCTION
   ClassDB.compareServerVersion(VARCHAR, VARCHAR, BOOLEAN) OWNER TO ClassDB;

--Limit to ClassDB to prevent exceptions due to incorrect args
-- too much development effort to prevent all possible exceptions
REVOKE ALL ON FUNCTION
   ClassDB.compareServerVersion(VARCHAR, VARCHAR, BOOLEAN) FROM PUBLIC;


--Define a function to compare some Postgres server version number to this server's
--See version of this fn that compares any two server version numbers for details
CREATE OR REPLACE FUNCTION
   ClassDB.compareServerVersion(version1 VARCHAR,
                                testPart2 BOOLEAN DEFAULT TRUE
                               )
   RETURNS INTEGER AS
$$
   SELECT ClassDB.compareServerVersion($1, ClassDB.getServerVersion(), $2);
$$ LANGUAGE sql
   RETURNS NULL ON NULL INPUT;

ALTER FUNCTION ClassDB.compareServerVersion(VARCHAR, BOOLEAN) OWNER TO ClassDB;

REVOKE ALL ON FUNCTION
   ClassDB.compareServerVersion(VARCHAR, BOOLEAN) FROM PUBLIC;



--Define a shortcut fn to test if the server's version precedes the given version
CREATE OR REPLACE FUNCTION
   ClassDB.isServerVersionBefore(version VARCHAR, testPart2 BOOLEAN DEFAULT TRUE)
   RETURNS BOOLEAN AS
$$
   SELECT ClassDB.compareServerVersion($1, $2) > 0;
$$ LANGUAGE sql
   RETURNS NULL ON NULL INPUT;

ALTER FUNCTION ClassDB.isServerVersionBefore(VARCHAR, BOOLEAN) OWNER TO ClassDB;

REVOKE ALL ON FUNCTION
   ClassDB.isServerVersionBefore(VARCHAR, BOOLEAN) FROM PUBLIC;



--Define a shortcut fn to test if the server's version succeeds the given version
CREATE OR REPLACE FUNCTION
   ClassDB.isServerVersionAfter(version VARCHAR, testPart2 BOOLEAN DEFAULT TRUE)
   RETURNS BOOLEAN AS
$$
   SELECT ClassDB.compareServerVersion($1, $2) < 0;
$$ LANGUAGE sql
   RETURNS NULL ON NULL INPUT;

ALTER FUNCTION ClassDB.isServerVersionAfter(VARCHAR, BOOLEAN) OWNER TO ClassDB;

REVOKE ALL ON FUNCTION
   ClassDB.isServerVersionAfter(VARCHAR, BOOLEAN) FROM PUBLIC;



--Define a shortcut fn to test if the server's version matches the given version
CREATE OR REPLACE FUNCTION
   ClassDB.isServerVersion(version VARCHAR, testPart2 BOOLEAN DEFAULT TRUE)
   RETURNS BOOLEAN AS
$$
   SELECT ClassDB.compareServerVersion($1, $2) = 0;
$$ LANGUAGE sql
   RETURNS NULL ON NULL INPUT;

ALTER FUNCTION ClassDB.isServerVersion(VARCHAR, BOOLEAN) OWNER TO ClassDB;

REVOKE ALL ON FUNCTION
   ClassDB.isServerVersion(VARCHAR, BOOLEAN) FROM PUBLIC;



--Returns TRUE if columnName in schemaName.tableName exists
CREATE OR REPLACE FUNCTION ClassDB.isColumnDefined(schemaName ClassDB.IDNameDomain,
   tableName ClassDB.IDNameDomain, columnName ClassDB.IDNameDomain)
   RETURNS BOOLEAN AS
$$
BEGIN
    RETURN EXISTS (SELECT *
                   FROM INFORMATION_SCHEMA.COLUMNS
                   WHERE table_schema = ClassDB.foldPgID(schemaName)
                   AND   table_name   = ClassDB.foldPgID(tableName)
                   AND   column_Name  = ClassDB.foldPgID(columnName));
END
$$ LANGUAGE plpgsql
   STABLE;

ALTER FUNCTION ClassDB.isColumnDefined(ClassDB.IDNameDomain,
   ClassDB.IDNameDomain, ClassDB.IDNameDomain)
   OWNER TO ClassDB;

COMMIT;
