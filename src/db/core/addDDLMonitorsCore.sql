--addDDLMonitorsCore.sql - ClassDB

--Sean Murthy, Steven Rollo
--Data Science & Systems Lab (DASSL)
--https://dassl.github.io/

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.

--This script must be run as superuser.
--This script should be run in each database to which ClassDB is to be added
-- it should be run after running addRoleBaseMgmt.sql

--This script adds event triggers and corresponding handlers for DDL statements
-- presently only DROP SCHEMA and DROP OWNED are handled

START TRANSACTION;

--Check for superuser
DO
$$
BEGIN
   IF NOT ClassDB.isSuperUser() THEN
      RAISE EXCEPTION 'Insufficient privileges for script: must be run as a superuser';
   END IF;
END
$$;

--Suppress NOTICE messages for this script only, this will not apply to functions
-- defined within. This hides messages that are unimportant, but possibly confusing
SET LOCAL client_min_messages TO WARNING;



--Define a function to handle all ddl_command_start events
-- presently handles only DROP SCHEMA and DROP OWNED commands
-- prevents from running DROP SCHEMA and DROP OWNED if they themselves own a
-- schema: a somewhat arbitrary rule, but c'est la vie
CREATE OR REPLACE FUNCTION ClassDB.handleRoleBaseDDLStart()
RETURNS event_trigger AS
$$
DECLARE
   sessionUserName ClassDB.IDNameDomain;
   commandName VARCHAR;
   ownsSomeSchema BOOLEAN;
BEGIN
   --save the session user in a form ready to use with ClassDB functions
   sessionUserName = SESSION_USER::ClassDB.IDNameDomain;

   --ddl commands presently handled apply only to known users w/ a ClassDB role
   IF NOT (ClassDB.isUser(sessionUserName)
           AND ClassDB.hasClassDBRole(sessionUserName)
          )
   THEN
      RETURN;
   END IF;

   --peform command-specific tasks
   commandName = LOWER(TG_TAG);
   IF (commandName IN ('drop schema', 'drop owned')) THEN

      --ideally like to test if session user owns the schema to be dropped, but
      --the schema name is unavailable at ddl_command_start
      -- test if session user owns some schema before deciding if op is OK
      ownsSomeSchema = EXISTS
                        (SELECT * FROM INFORMATION_SCHEMA.SCHEMATA
                         WHERE schema_owner = ClassDB.foldPgID(sessionUserName)
                        );

      --prevent students users who own a schema from performing this op
      IF(ownsSomeSchema AND ClassDB.IsStudent(sessionUserName)) THEN
         RAISE EXCEPTION 'Invalid operation: student users may not perform '
                         'operation "%" when they own their own schema', TG_TAG;
      END IF;

   END IF;

END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;


ALTER FUNCTION ClassDB.handleRoleBaseDDLStart() OWNER TO ClassDB;
REVOKE ALL ON FUNCTION ClassDB.handleRoleBaseDDLStart() FROM PUBLIC;



--Event trigger to handle start of a DDL command
DROP EVENT TRIGGER IF EXISTS triggerRoleBaseDDLStart;
CREATE EVENT TRIGGER triggerRoleBaseDDLStart
ON ddl_command_start
EXECUTE PROCEDURE ClassDB.handleRoleBaseDDLStart();



COMMIT;
