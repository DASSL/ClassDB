--addDDLMonitors.sql - ClassDB

--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab (DASSL), Western Connecticut State University (WCSU)

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.

--This script must be run as superuser.
--initalizeDB.sql must be run prior to this script

--This script adds the ClassDB DDL statement monitoring system.  Two event triggers
-- log the last DDL statement executed for each student in the student table

START TRANSACTION;

--Check for superuser
DO
$$
BEGIN
   IF NOT (SELECT classdb.isSuperUser()) THEN
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
CREATE OR REPLACE FUNCTION classdb.updateStudentActivity()
RETURNS event_trigger AS
$$
DECLARE
   --Name of the db object that was targeted by the triggering statement
   objId VARCHAR(256);
BEGIN
	--Check if the calling event is sql_drop or ddl_command_end
	IF TG_EVENT = 'ddl_command_end' THEN
      SELECT object_identity --Get the statement target object
      FROM pg_event_trigger_ddl_commands() --Each of these functions can only
                                           --be called for the appropriate event type
      WHERE object_identity IS NOT NULL
      ORDER BY object_identity LIMIT 1
      INTO objId;
   ELSIF TG_EVENT = 'sql_drop' THEN
      SELECT object_identity --Same thing, but for drop statements
      FROM pg_event_trigger_dropped_objects()
      WHERE object_identity IS NOT NULL
      ORDER BY object_identity LIMIT 1
      INTO objId;
   END IF;
   --Note: DROP statements cause this trigger to be executed twice,
   -- see https://www.postgresql.org/docs/9.6/static/event-trigger-matrix.html
   -- ddl_commend_end is triggered on all DDL statements. However,
   -- pg_event_trigger_ddl_commands().object_identity is NULL for DROP statements
   -- Since ddl_command_end is sent after sql_drop, we don't update if objId
   -- IS NULL, because that is the ddl_command_end event after sql_drop,
   -- and we would overwrite student.lastDDLObject with NULL
   IF objId IS NOT NULL THEN
      UPDATE classdb.Student
      SET lastDDLActivity = (SELECT statement_timestamp() AT TIME ZONE 'utc'),
      DDLCount = DDLCount + 1, --Increment the student's DDL statement count
      lastDDLOperation = TG_TAG,
      lastDDLObject = objId --Set the student's last DDL target object to the
                            --one we got from the correct event trigger function
      WHERE userName = session_user; --Update info for the appropriate user
   END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;


--Event triggers to update user last activity time on DDL events
-- the 'Drop' trigger is fired during the sql_drop event, which occurs when
-- DROP statements are executed. The 'DDL' trigger is executed on ddl_command_end
-- which is fired when any DDL statement finishes executing. Both triggers are
-- needed to log all DDL statements, as not all infomation about DROP statements
-- is provided by the ddl_command_end event
DROP EVENT TRIGGER IF EXISTS updateStudentActivityTriggerDrop;
CREATE EVENT TRIGGER updateStudentActivityTriggerDrop
ON sql_drop
EXECUTE PROCEDURE classdb.updateStudentActivity();

DROP EVENT TRIGGER IF EXISTS updateStudentActivityTriggerDDL;
CREATE EVENT TRIGGER updateStudentActivityTriggerDDL
ON ddl_command_end
EXECUTE PROCEDURE classdb.updateStudentActivity();

COMMIT;
