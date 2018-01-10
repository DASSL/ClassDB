--addDDLMonitors.sql - ClassDB

--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab (DASSL)
--https://dassl.github.io/

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.

--This script must be run as superuser.
--This script should be run in every database in which DDL activity monitoring is required
-- it should be run after running addUserMgmt.sql

--This script adds the ClassDB DDL statement monitoring system.  Two event triggers
-- log the last DDL statement executed for each student in the student table

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

--Set up DDL statement logging

--This function records information on DDL statements issued by students.
-- It is called by two event triggers, which are fired on DDL statements.  when
-- the function is executed, it gets the timestamp, statement, and target object
-- of the trigger DDL statement, and records those in the triggering student's
-- record in the student table. It also increments the student's total DDL
-- statement count

--We use CREATE OR REPLACE for this function because it can't be dropped if the
-- event triggers already exist.  For example, when re-runing this script
CREATE OR REPLACE FUNCTION ClassDB.logDDLActivity()
RETURNS event_trigger AS
$$
DECLARE
   --Name of the db object that was targeted by the triggering statement
   objId VARCHAR(256);
BEGIN
   --Check if the calling event is sql_drop or ddl_command_end
   IF TG_EVENT = 'ddl_command_end' THEN
      SELECT object_identity --Get the statement target object
      INTO objId
      FROM pg_event_trigger_ddl_commands() --can only be called on non-DROP statements
      WHERE object_identity IS NOT NULL
      ORDER BY object_identity;
   ELSIF TG_EVENT = 'sql_drop' THEN
      SELECT object_identity --Same thing, but for drop statements
      INTO objId
      FROM pg_event_trigger_dropped_objects() --can only be called on DROP statements
      WHERE object_identity IS NOT NULL
      ORDER BY object_identity;
   END IF;

   --Note: DROP statements cause this trigger to be executed twice,
   -- see https://www.postgresql.org/docs/9.6/static/event-trigger-matrix.html
   -- ddl_commend_end is triggered on all DDL statements. However,
   -- pg_event_trigger_ddl_commands().object_identity is NULL for DROP statements
   -- Since ddl_command_end is sent after sql_drop, we don't update if objId
   -- IS NULL, because that is the ddl_command_end event after sql_drop,
   -- and we would log a duplicate DDL event with a NULL object ID

   --Check if the triggering user is a ClassDB user
   IF ClassDB.isUser(SESSION_USER::ClassDB.IDNameDomain) AND objId IS NOT NULL THEN
      --Insert a new row into the DDL activity log, containing the user name,
      -- DDL statement starting time stamp, DDL statement performed, and object
      -- affected by the statement
      INSERT INTO ClassDB.DDLActivity VALUES
      (SESSION_USER, statement_timestamp() AT TIME ZONE 'utc', TG_TAG, objId);
   END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;

ALTER FUNCTION ClassDB.logDDLActivity() OWNER TO ClassDB;
REVOKE ALL ON FUNCTION ClassDB.disableDDLActivityLogging() FROM PUBLIC;


--Event triggers to update user last activity time on DDL events
-- the 'Drop' trigger is fired during the sql_drop event, which occurs when
-- DROP statements are executed. The 'DDL' trigger is executed on ddl_command_end
-- which is fired when any DDL statement finishes executing. Both triggers are
-- needed to log all DDL statements, as not all infomation about DROP statements
-- is provided by the ddl_command_end event
DO
$$
BEGIN
   --Only try and create the event triggers if they do not exist
   IF NOT ClassDB.isTriggerDefined('ClassDB', 'triggerDDLCommandSqlDrop') THEN
      CREATE EVENT TRIGGER triggerDDLCommandSqlDrop
      ON sql_drop
      EXECUTE PROCEDURE ClassDB.logDDLActivity();
   END IF;

   IF NOT ClassDB.isTriggerDefined('ClassDB', 'triggerDDLCommandEnd') THEN
      CREATE EVENT TRIGGER triggerDDLCommandEnd
      ON ddl_command_end
      EXECUTE PROCEDURE ClassDB.logDDLActivity();
   END IF;
END;
$$;


--The functions ClassDB.enableDDLActivityLogging() and ClassDB.disableDDLActivityLogging()
-- enable and disable the DDL monitoring feature by creating and removing DDL triggers.
-- These triggers insert rows into ClassDB.DDLActivity any time a classDB user performs
-- a DDL statement.
--These functions must be owned by the superuser running this script, because only
-- superusers have the permissions to create, drop or alter event triggers
CREATE OR REPLACE FUNCTION ClassDB.enableDDLActivityLogging()
RETURNS VOID AS
$$
   --Can only enable the trigger if it is defined, otherwise throw an exception
   IF ClassDB.isTriggerDefined('ClassDB', 'triggerDDLCommandSqlDrop') THEN
      ALTER EVENT TRIGGER triggerDDLCommandSqlDrop ENABLE;
   ELSE
      RAISE EXCEPTION 'Cannot enable triggerDDLCommandSqlDrop because it is undefined';
   END IF;

   IF ClassDB.isTriggerDefined('ClassDB', 'triggerDDLCommandSqlDrop') THEN
      ALTER EVENT TRIGGER triggerDDLCommandEnd ENABLE;
   ELSE
      RAISE EXCEPTION 'Cannot enable triggerDDLCommandEnd because it is undefined';
   END IF;
$$ LANGUAGE sql
   SECURITY DEFINER;

REVOKE ALL ON FUNCTION ClassDB.enableDDLActivityLogging() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ClassDB.enableDDLActivityLogging()
   TO ClassDB_Instructor, ClassDB_DBManager;


CREATE OR REPLACE FUNCTION ClassDB.disableDDLActivityLogging()
RETURNS VOID AS
$$
   IF ClassDB.isTriggerDefined('ClassDB', 'triggerDDLCommandSqlDrop') THEN
      ALTER EVENT TRIGGER triggerDDLCommandSqlDrop DISABLE;
   ELSE
      RAISE EXCEPTION 'Cannot enable triggerDDLCommandSqlDrop because it is undefined';
   END IF;

   IF ClassDB.isTriggerDefined('ClassDB', 'triggerDDLCommandSqlDrop') THEN
      ALTER EVENT TRIGGER triggerDDLCommandEnd DISABLE;
   ELSE
      RAISE EXCEPTION 'Cannot enable triggerDDLCommandEnd because it is undefined';
   END IF;
$$ LANGUAGE sql
   SECURITY DEFINER;

REVOKE ALL ON FUNCTION ClassDB.disableDDLActivityLogging() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ClassDB.disableDDLActivityLogging()
   TO ClassDB_Instructor, ClassDB_DBManager;

COMMIT;
