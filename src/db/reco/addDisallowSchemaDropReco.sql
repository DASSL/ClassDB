--addDisallowSchemaDropReco.sql - ClassDB

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

--This script adds an event trigger and a corresponding handler to prevent
-- students from executing DROP SCHEMA and DROP OWNED BY

START TRANSACTION;

--make sure current user is superuser
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



--Define a function to raise an exception if it is called for a student user
--Called by the event trigger defined to prevent student-initiated schema drop
CREATE OR REPLACE FUNCTION ClassDB.handleDropSchemaDDLStart()
RETURNS event_trigger AS
$$
BEGIN
   IF ClassDB.isStudent(SESSION_USER::ClassDB.IDNameDomain) THEN
      RAISE EXCEPTION 'invalid operation: student users may not perform '
                         'operation "%"', TG_TAG;
   END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;


ALTER FUNCTION ClassDB.handleDropSchemaDDLStart() OWNER TO ClassDB;
REVOKE ALL ON FUNCTION ClassDB.handleDropSchemaDDLStart() FROM PUBLIC;



--Event trigger to handle start of any DDL stmt that leads to dropping a schema
-- limited only to stmts DROP SCHEMA and DROP OWNED
--CAUTION: change the function isSchemaDropAllowed if the name or the event of
-- this trigger changes
DROP EVENT TRIGGER IF EXISTS triggerDropSchemaDDLStart;
CREATE EVENT TRIGGER triggerDropSchemaDDLStart
ON ddl_command_start
WHEN TAG IN ('drop schema', 'drop owned')
EXECUTE PROCEDURE ClassDB.handleDropSchemaDDLStart();



--Functions ClassDB.disallowSchemaDrop() and ClassDB.allowSchemaDrop()
-- respectively enable and disable event triggers that prevent student-initiated
-- schema drops
--These functions must be owned by a superuser, because only superusers can alter
-- event triggers
CREATE OR REPLACE FUNCTION ClassDB.disallowSchemaDrop()
RETURNS VOID AS
$$
   ALTER EVENT TRIGGER triggerDropSchemaDDLStart ENABLE;
$$ LANGUAGE sql
   SECURITY DEFINER;

REVOKE ALL ON FUNCTION ClassDB.disallowSchemaDrop() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ClassDB.disallowSchemaDrop()
   TO ClassDB_Instructor, ClassDB_DBManager, ClassDB;



CREATE OR REPLACE FUNCTION ClassDB.allowSchemaDrop()
RETURNS VOID AS
$$
   ALTER EVENT TRIGGER triggerDropSchemaDDLStart DISABLE;
$$ LANGUAGE sql
   SECURITY DEFINER;

REVOKE ALL ON FUNCTION ClassDB.allowSchemaDrop() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ClassDB.allowSchemaDrop()
   TO ClassDB_Instructor, ClassDB_DBManager, ClassDB;



--Define a function to test if student-initiated schema drop is allowed
--Uses pg catalog to determine the presence and state of a specific trigger
-- https://www.postgresql.org/docs/9.6/static/catalog-pg-event-trigger.html
CREATE OR REPLACE FUNCTION ClassDB.isSchemaDropAllowed()
RETURNS BOOLEAN AS
$$
   --query returns a row only if the event trigger is defined and is not disabled
   --NOT EXISTS returns true if event trigger is not defined, or if trigger is
   -- defined but is disabled
   --Values used to test attributes evtname and evtevent must match trigger name
   -- and event name
   SELECT NOT EXISTS
   (
      SELECT evtenabled FROM pg_event_trigger
      WHERE evtname = 'triggerdropschemaddlstart'
            AND evtevent = 'ddl_command_start'
            AND evtenabled <> 'D' --D means the trigger is disabled
   );
$$ LANGUAGE sql
   SECURITY DEFINER;

ALTER FUNCTION ClassDB.isSchemaDropAllowed() OWNER TO ClassDB;
REVOKE ALL ON FUNCTION ClassDB.isSchemaDropAllowed() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ClassDB.isSchemaDropAllowed()
   TO ClassDB_Instructor, ClassDB_DBManager;


COMMIT;
