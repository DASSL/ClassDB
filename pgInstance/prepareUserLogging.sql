--prepareUserLogging.sql - ClassDB

--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab (DASSL), Western Connecticut State University (WCSU)

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC: https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.

--Need to be superuser for ALTER SYSTEM, however the ALTER SYSTEMS can't be placed in the same transaction
ALTER SYSTEM SET log_connections TO 'on';
ALTER SYSTEM SET log_destination TO 'csvlog'; --This outputs the log in a csv format, which allows COPY...FROM to read it
ALTER SYSTEM SET log_filename TO 'postgresql-%m.%d.log';
--Set the log file name.  Using the date/time vars can help with log rotation.  Right now, the file name
--is postgresql-<month>.<day>, ie. postgresql-06.10.  The log rotates daily.

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
   log_time TIMESTAMP(3) WITH TIME ZONE,
   user_name TEXT,
   database_name TEXT,
   process_id INTEGER,
   connection_from TEXT,
   session_id TEXT,
   session_line_num BIGINT,
   command_tag TEXT,
   session_start_time TIMESTAMP WITH TIME ZONE,
   virtual_transaction_id TEXT,
   transaction_id BIGINT,
   error_severity TEXT,
   sql_state_code TEXT,
   message TEXT,
   detail TEXT,
   hint TEXT,
   internal_query TEXT,
   internal_query_pos INTEGER,
   context TEXT,
   query TEXT,
   query_pos INTEGER,
   location TEXT,
   application_name TEXT,
   PRIMARY KEY (session_id, session_line_num)   
);

--Function to import a given day's log to a table, 
--The latest connection in the student table supplied the assumed last import date
--Logs since this date are imported.  If this value is null, logs are parsed, starting with the
--supplied date
CREATE OR REPLACE FUNCTION classdb.importLog(DATE) 
RETURNS VOID AS
$$
DECLARE
   logPath TEXT;
   lastConDate DATE;
BEGIN  
	 lastConDate := COALESCE(date((SELECT MAX(lastConnection) FROM classdb.student)), $1); --The double parens around the subquery seem to be required
	 WHILE lastConDate <= current_date LOOP
	  --Get the log path, but assumes a log file name of postgresql-%d.csv
      logPath := (SELECT setting FROM pg_settings WHERE "name" = 'log_directory') || '/postgresql-' || to_char(lastConDate, 'MM.DD') || '.csv';
      EXECUTE format('COPY classdb.postgresLog FROM ''%s'' WITH csv', logPath);
      lastConDate := lastConDate + 1;
   END LOOP;
   --Update the student table based on the temp log table
   UPDATE classdb.student
   --Get the total # of connections made in the imported log
   --Ignore connections from an earlier date than the lastConnections
   --These should already be counted
   SET connectionCount = connectionCount + (
      SELECT COUNT(user_name) 
      FROM classdb.postgresLog pg 
      WHERE pg.user_name = userName
      AND pg.log_time > COALESCE(lastConnection, to_timestamp(0))
      AND message LIKE 'connection%' --Filter out extraneous log lines
   ),
   --Find the latest connection date in the logs
   lastConnection = COALESCE(
      ( 
         SELECT MAX(log_time AT TIME ZONE 'utc') 
         FROM classdb.postgresLog pg 
         WHERE pg.user_name = userName
         AND pg.log_time > COALESCE(lastConnection, to_timestamp(0))
         AND message LIKE 'connection%'
      ), lastConnection);
   --Clear the log table
   TRUNCATE classdb.postgresLog;
END;
$$ LANGUAGE plpgsql;

--Override that supplies the current date in place of null
CREATE OR REPLACE FUNCTION classdb.importLog()
RETURNS VOID AS
$$
BEGIN
   PERFORM classdb.importLog(current_date);
END;
$$ LANGUAGE plpgsql;

--SET up DDL command logging
--This function updates the LastActivity field for a given student
CREATE OR REPLACE FUNCTION classdb.updateStudentActivity() 
RETURNS event_trigger AS
$$
DECLARE
   objId TEXT;
BEGIN
	--Check if the calling event is sql_drop or ddl_command_end
	IF TG_EVENT = 'ddl_command_end' THEN
      SELECT object_identity 
      FROM pg_event_trigger_ddl_commands() --Each of these functions can only be called for the appropriate event type
      WHERE object_identity IS NOT NULL
      ORDER BY object_identity LIMIT 1 
      INTO objId;
   ELSIF TG_EVENT = 'sql_drop' THEN
      SELECT object_identity
      FROM pg_event_trigger_dropped_objects() 
      WHERE object_identity IS NOT NULL
      ORDER BY object_identity LIMIT 1
      INTO objId;
   END IF;
   --Note: DROP statements cause this trigger to be executed twice,
   --so we don't update if objId IS NULL, because that is the
   --ddl_command_end event after sql_drop
   IF objId IS NOT NULL THEN 
      UPDATE classdb.Student
      SET lastDDLActivity = (SELECT statement_timestamp() AT TIME ZONE 'utc'),
      DDLCount = DDLCount + 1,
      lastDDLOperation = TG_TAG,
      lastDDLObject = objId
      WHERE userName = session_user; --Update info for the appropriate user
   END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;
   
--Event triggers to update user last activity time on DDL events
CREATE EVENT TRIGGER updateStudentActivityTriggerDrop
ON sql_drop
EXECUTE PROCEDURE classdb.updateStudentActivity();

CREATE EVENT TRIGGER updateStudentActivityTriggerDDL
ON ddl_command_end
EXECUTE PROCEDURE classdb.updateStudentActivity();

COMMIT;