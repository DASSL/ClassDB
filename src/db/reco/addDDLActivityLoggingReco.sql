--addDDLActivityLoggingReco.sql - ClassDB

--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab (DASSL)
--https://dassl.github.io/

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.

--This script must be run as superuser.
--This script should be run in every database in which DDL activity monitoring is required
-- it should be run after running addUserMgmtCore.sql

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

--This function requires CREATE OR REPLACE for this function because it can't be
-- dropped if the event triggers already exist.  For example, when re-runing this script
CREATE OR REPLACE FUNCTION ClassDB.logDDLActivity()
RETURNS event_trigger AS
$$
DECLARE
   --Name of the db object that was targeted by the triggering statement
   objId VARCHAR(256);
BEGIN
   --We only want log DDL activity from ClassDB users
   IF ClassDB.isUser(SESSION_USER::ClassDB.IDNameDomain) THEN
      --Check if the calling event is sql_drop or ddl_command_end
      IF TG_EVENT = 'ddl_command_end' THEN
         --Function pg_event_trigger_ddl_commands was introduced in pg9.5.
         -- Remove the test for server version when support for pg9.4 ends
         IF ClassDB.isServerVersionBefore('9.5') THEN
            objId = 'N/A';
         ELSE
            SELECT object_identity --Get the statement target object
            INTO objId
            FROM pg_event_trigger_ddl_commands() --can only be called on non-DROP ops
            WHERE object_identity IS NOT NULL
            ORDER BY object_identity;
         END IF;
      --In pg9.4 'ddl_command_end' causes a log to be created with objId of N/A
      -- to be inserted for a drop. Since there is already a log for drop this
      -- TG_EVENT should be ignored in version 9.4 to avoid duplicate logs.
      -- Remove test for server version when support for pg9.4 ends
      ELSIF TG_EVENT = 'sql_drop' AND ClassDB.isServerVersionAfter('9.4') THEN
         SELECT object_identity --Same thing, but for drop statements
         INTO objId
         FROM pg_event_trigger_dropped_objects() --can only be called on DROP ops
         WHERE object_identity IS NOT NULL
         ORDER BY object_identity;
      END IF;

      --Note: DROP statements cause this trigger to be executed twice,
      -- see https://www.postgresql.org/docs/9.6/static/event-trigger-matrix.html
      -- ddl_command_end is triggered on all DDL statements. However,
      -- pg_event_trigger_ddl_commands().object_identity is NULL for DROP statements
      -- Since ddl_command_end is sent after sql_drop, we don't update if objId
      -- IS NULL, because that is the ddl_command_end event after sql_drop,
      -- and we would log a duplicate DDL event with a NULL object ID
      IF objId IS NOT NULL THEN
         --Insert a new row into the DDL activity log, containing the user name,
         -- DDL statement starting time stamp, DDL statement performed, and object
         -- affected by the statement
         INSERT INTO ClassDB.DDLActivity VALUES
         (SESSION_USER, statement_timestamp() AT TIME ZONE 'utc', TG_TAG, objId,
            ClassDB.getSessionID());
      END IF;
   END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;

ALTER FUNCTION ClassDB.logDDLActivity() OWNER TO ClassDB;
REVOKE ALL ON FUNCTION ClassDB.logDDLActivity() FROM PUBLIC;


--Event triggers to update user last activity time on DDL events
-- the 'Drop' trigger is fired during the sql_drop event, which occurs when
-- DROP statements are executed. The 'DDL' trigger is executed on ddl_command_end
-- which is fired when any DDL statement finishes executing. Both triggers are
-- needed to log all DDL statements, as not all information about DROP statements
-- is provided by the ddl_command_end event
DROP EVENT TRIGGER IF EXISTS triggerDDLCommandSqlDrop;
CREATE EVENT TRIGGER triggerDDLCommandSqlDrop
ON sql_drop
EXECUTE PROCEDURE ClassDB.logDDLActivity();

DROP EVENT TRIGGER IF EXISTS triggerDDLCommandEnd;
CREATE EVENT TRIGGER triggerDDLCommandEnd
ON ddl_command_end
EXECUTE PROCEDURE ClassDB.logDDLActivity();


--The functions ClassDB.enableDDLActivityLogging() and ClassDB.disableDDLActivityLogging()
-- enable and disable the DDL monitoring feature by creating and removing DDL triggers.
-- These triggers insert rows into ClassDB.DDLActivity any time a classDB user performs
-- a DDL statement.
--These functions must be owned by the superuser running this script, because only
-- superusers have the permissions to create, drop or alter event triggers
CREATE OR REPLACE FUNCTION ClassDB.enableDDLActivityLogging()
RETURNS VOID AS
$$
BEGIN
   ALTER EVENT TRIGGER triggerDDLCommandSqlDrop ENABLE;
   ALTER EVENT TRIGGER triggerDDLCommandEnd ENABLE;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;

--We don't grant these functions to ClassDB because they must be run with superuser
-- permissions
REVOKE ALL ON FUNCTION ClassDB.enableDDLActivityLogging() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ClassDB.enableDDLActivityLogging()
   TO ClassDB_Instructor, ClassDB_DBManager, ClassDB;

CREATE OR REPLACE FUNCTION ClassDB.disableDDLActivityLogging()
RETURNS VOID AS
$$
BEGIN
   ALTER EVENT TRIGGER triggerDDLCommandSqlDrop DISABLE;
   ALTER EVENT TRIGGER triggerDDLCommandEnd DISABLE;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;

REVOKE ALL ON FUNCTION ClassDB.disableDDLActivityLogging() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ClassDB.disableDDLActivityLogging()
   TO ClassDB_Instructor, ClassDB_DBManager, ClassDB;

COMMIT;
