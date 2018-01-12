--removeFromDB.sql - ClassDB

--Sean Murthy, Steven Rollo
--Data Science & Systems Lab (DASSL)
--https://dassl.github.io

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.


--This script undoes the changes ClassDB installation scripts made to current DB
-- The changes made by this script cannot be undone
-- This script will inform the user if any manual actions need to be preformed
-- before ClassDB can be removed from the database
-- This script lists additional actions a user must take to completely remove
-- ClassDB from other databse and the server

--This script will NOT drop user roles
-- BEFORE running this script: run appropriate classDB.dropXYZ functions in each
-- database where ClassDB is installed

--This script should be run by a superuser


START TRANSACTION;

--Suppress NOTICE messages for this script only, this will not apply to functions
-- defined within. This hides messages that are unimportant, but possibly confusing
SET LOCAL client_min_messages TO WARNING;

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


--Check if there are any orphan objects from dropped instructors/DBManagers
-- that will prevent those roles from being dropped
DO
$$
BEGIN
   IF (SELECT COUNT(routine_name)
             FROM INFORMATION_SCHEMA.ROUTINES
             WHERE routine_name IN ('listorphanobjects', 'listownedobjects')
             AND specific_schema = 'classdb') = 2 THEN

      IF EXISTS(SELECT * FROM classdb.listOrphanObjects()) THEN
         RAISE EXCEPTION 'Orphan objects which belonged to Instructors or DBManagers still exist. '
                         'These must be reassigned or dropped before ClassDB can be removed '
                         'from the database. Execute classdb.listOrphans() to get a list of these '
                         'objects.';
      END IF;
   END IF;
END
$$;


--REVOKE permissions on the current database from each ClassDB role
DO
$$
BEGIN
   EXECUTE format('REVOKE CONNECT ON DATABASE %I FROM classdb_instructor;', current_database());
   EXECUTE format('REVOKE CONNECT ON DATABASE %I FROM classdb_dbmanager;', current_database());
   EXECUTE format('REVOKE CONNECT ON DATABASE %I FROM classdb_student;', current_database());
   EXECUTE format('REVOKE CREATE ON DATABASE %I FROM classdb;', current_database());
END
$$;

--Drop all remaining ClassDB objects/permissions in this database.
DROP OWNED BY ClassDB_Instructor;
DROP OWNED BY ClassDB_DBManager;
DROP OWNED BY ClassDB_Student;

--Remove event triggers
DROP EVENT TRIGGER IF EXISTS updateStudentActivityTriggerDDL;
DROP EVENT TRIGGER IF EXISTS updateStudentActivityTriggerDrop;

--Drop all ClassDB owned functions from public schema
DO
$$
BEGIN
   EXECUTE (SELECT string_agg('DROP FUNCTION ' || ns.nspname || '.' || p.proname
          || '(' || oidvectortypes(p.proargtypes) || ');', E'\n')
   FROM pg_proc p JOIN pg_namespace ns ON p.pronamespace = ns.oid
   WHERE ns.nspname = 'public');
END;
$$;

--Drop all ClassDB owned views from public
-- Note that this will drop any user objects that are derived from public ClassDB
-- objects, such as student owned views that that query MyActivity, MyActivitySummary, etc.
DO
$$
BEGIN
   EXECUTE (SELECT string_agg('DROP VIEW ' || "object" || ' CASCADE;', E'\n')
   FROM ClassDB.listOwnedObjects('classdb')
   WHERE "schema" = 'public'
   AND kind ILIKE 'v%');
END;
$$;


--Delete the entire classdb schema in the current database
-- no need to drop individual objects created in that schema
DROP SCHEMA IF EXISTS ClassDB CASCADE;


--We now want to show our NOTICES, so switch display level back to default
RESET client_min_messages;

--create a list of things users have to do on their own
-- commenting out the RAISE NOTICE statements because they cause syntax error
DO
$$
BEGIN
   RAISE NOTICE 'Drop user roles or adjust their privileges';
   RAISE NOTICE 'Drop user schemas or adjust their privilege';
   RAISE NOTICE 'Adjust privileges on PUBLIC schema if appropriate';
   RAISE NOTICE 'Run DROP DATABASE statement to remove the database if appropriate';
   RAISE NOTICE 'Run removeFromServer.sql after removing ClassDB '
                'from other databases';
END
$$;

COMMIT;
