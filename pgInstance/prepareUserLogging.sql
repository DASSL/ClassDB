--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab at Western Connecticut State University (dassl@WCSU)
--
--prepareUserLogging.sql
--
--ClassDB - Created: 2017-06-14; Modified 2017-06-14

--Need to be superuser for ALTER SYSTEM, however the ALTER SYSTEMS can't be placed in the same transaction
ALTER SYSTEM SET log_connections TO 'on';
ALTER SYSTEM SET log_destination TO 'csvlog'; --This outputs the log in a csv format, which allows COPY...FROM to read it
ALTER SYSTEM SET log_filename TO 'postgresql-%d.log';
--Set the log file name.  Using the date/time vars can help with log rotation.  Right now, the file name
--is postgresql-<daynum>, ie. postgresql-10.  The log rotates every day, so at most 31 log files are kept at a time
--The log import reads the file called postgresql-<daynum-1>, ie. yesterday's log

SELECT pg_reload_conf();

START TRANSACTION;
--Check for superuser
DO
$$
DECLARE
   isSuper BOOLEAN;
BEGIN
   EXECUTE 'SELECT COALESCE(rolsuper, FALSE) FROM pg_catalog.pg_roles WHERE rolname = current_user' INTO isSuper;
   IF NOT isSuper THEN
      RAISE EXCEPTION 'Insufficient privileges for script: must be run as a superuser';
   END IF;
END
$$;
--Drop the event triggers now so we can drop tables without error
DROP EVENT TRIGGER IF EXISTS updateStudentActivityTriggerDDL;
DROP EVENT TRIGGER IF EXISTS updateStudentActivityTriggerDrop;

--This table format suggested by the Postgres documentation for use with the COPY statement
--https://www.postgresql.org/docs/9.6/static/runtime-config-logging.html
DROP TABLE IF EXISTS classdb.postgresLog;
CREATE TABLE classdb.postgresLog
(
   log_time timestamp(3) with time zone,
   user_name text,
   database_name text,
   process_id integer,
   connection_from text,
   session_id text,
   session_line_num bigint,
   command_tag text,
   session_start_time timestamp with time zone,
   virtual_transaction_id text,
   transaction_id bigint,
   error_severity text,
   sql_state_code text,
   message text,
   detail text,
   hint text,
   internal_query text,
   internal_query_pos integer,
   context text,
   query text,
   query_pos integer,
   location text,
   application_name text,
   PRIMARY KEY (session_id, session_line_num)   
);

--Function to import a given day's log to a table
CREATE OR REPLACE FUNCTION classdb.importLog(INT) 
RETURNS VOID AS
$$
DECLARE
   logPath TEXT;
BEGIN 
	--Get the log path, but assumes a log file name of postgresql-%d.csv
   logPath := (SELECT setting FROM pg_settings WHERE "name" = 'log_directory') || '/postgresql-' || $1 || '.csv';
   EXECUTE format('COPY classdb.postgresLog FROM ''%s'' WITH csv', logPath);
   --Update the student table based on the temp log table
   UPDATE classdb.student 
   SET lastConnection = (pg.log_time AT TIME ZONE 'utc'),
   connectionCount = connectionCount + 1
   FROM classdb.postgresLog pg
   WHERE userName = pg.user_name; --The connection should only be updated if it is newer
   --Clear the log table
   TRUNCATE classdb.postgresLog;
END;
$$ LANGUAGE plpgsql;

--Function to import yesterday's log
CREATE OR REPLACE FUNCTION classdb.importLog() 
RETURNS VOID AS
$$
DECLARE
   logPath TEXT;
BEGIN
   PERFORM classdb.importLog((SELECT EXTRACT(DAY FROM current_date - 1)));
END;
$$ LANGUAGE plpgsql;

--SET up DDL command logging
--This function updates the LastActivity field for a given student
CREATE OR REPLACE FUNCTION classdb.updateStudentActivity() RETURNS event_trigger AS
$$
DECLARE
   objId TEXT;
BEGIN
	IF TG_EVENT = 'ddl_command_end' THEN
      SELECT object_identity 
      FROM pg_event_trigger_ddl_commands()
      INTO objId;
   END IF;
   IF TG_EVENT = 'sql_drop' THEN --Check if the calling event is sql_drop or ddl_command_end
      SELECT object_identity
      FROM pg_event_trigger_dropped_objects() --Each of these functions can only be called for the appropriate event type
      INTO objId;
   END IF;
   
   UPDATE classdb.Student
   SET lastDDLActivity = (SELECT current_timestamp AT TIME ZONE 'utc'),
   DDLCount = DDLCount + 1,
   lastDDLOperation = TG_TAG,
   lastDDLObject = objId
   WHERE userName = session_user; --Update info for the appropriate user
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;

--Event triggers to update user last activity time on DDL events
CREATE EVENT TRIGGER updateStudentActivityTriggerDDL
ON ddl_command_end
EXECUTE PROCEDURE classdb.updateStudentActivity();

CREATE EVENT TRIGGER updateStudentActivityTriggerDrop
ON sql_drop
EXECUTE PROCEDURE classdb.updateStudentActivity();

COMMIT;