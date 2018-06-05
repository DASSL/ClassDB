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
-- it should be run after running addClassDBRolesMgmtCore.sql

--This script adds event triggers and corresponding handlers for DDL statements
-- presently only DROP SCHEMA and DROP OWNED are handled

START TRANSACTION;

--Check for superuser
DO
$$
BEGIN
   IF NOT ClassDB.isSuperUser() THEN
      RAISE EXCEPTION 'Insufficient privileges for script: '
                      'must be run as a superuser';
   END IF;
END
$$;

--Suppress NOTICE messages for this script only, this will not apply to functions
-- defined within. This hides messages that are unimportant, but possibly confusing
SET LOCAL client_min_messages TO WARNING;



--Define a function to handle all ddl_command_start events
-- presently handles only DROP SCHEMA and DROP OWNED commands
-- prevents DROP SCHEMA and DROP OWNED by students
CREATE OR REPLACE FUNCTION ClassDB.handleRoleBaseDDLStart()
RETURNS event_trigger AS
$$
DECLARE
   sessionUserName ClassDB.IDNameDomain;
   commandName VARCHAR;
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

   --peform command-specific tasks: only two commands handled presently
   commandName = LOWER(TG_TAG);
   IF (commandName IN ('drop schema', 'drop owned')) THEN
      --prevent students users from performing this op
      IF(ClassDB.isStudent(sessionUserName)) THEN
         RAISE EXCEPTION 'Invalid operation: student users may not perform '
                         'operation "%"', TG_TAG;
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
