--prepareUserLogging.sql - ClassDB

--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab (DASSL), Western Connecticut State University (WCSU)

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.

--This script must be run as superuser.  The ALTER SYSTEM statements cannot
-- be placed in the primary transaction, but they will also fail if executed
-- by a non-superuser

--This script should be run last during the setup procedure

--This script sets up the ClassDB student logging and monitoring system.
-- There are two parts to this system:
-- Connection Logging: The Postgres server log is configured to log connections
-- and a function is provided to import these logs and record student connection data
-- DDL Logging: Two event triggers log the last DDL statement executed for each student
-- in the student table


--Use ALTER SYSTEM statements to change the Postgres server log settings for
-- the connection logging system. These statements must be run as superuser, but
-- can't be run inside a TRANSACTION block, however they will still fail if they
-- are run with insufficient permissions.

--The following changes are made:
-- log_connections TO 'on' causes user connections to the DBMS to be reported in
-- the log file
--log_destination TO 'csvlog' cause the logs to be recorded in a csv format,
-- making it possible to use the COPY statement on them
--log_filename sets the log file name. %m and %d are placeholders for month and
-- day respectively, ie. the log file name on June 10th would be postgresql-06.10.
ALTER SYSTEM SET log_connections TO 'on';
ALTER SYSTEM SET log_destination TO 'csvlog';
ALTER SYSTEM SET log_filename TO 'postgresql-%m.%d.log';


START TRANSACTION;

--Check for superuser. This check can't be performed earlier, since the ALTER SYSTEM
-- statements can't be placed in a transaction.  Since the check throws an exception,
-- and the exception only aborts the current transaction, it would have no effect
-- on the ALTER SYSTEM statements
DO
$$
BEGIN
   IF NOT EXISTS(SELECT * FROM pg_catalog.pg_roles WHERE rolname = current_user
                                                    AND rolsuper = 't') THEN
      RAISE EXCEPTION 'Insufficient privileges for script: must be run as a superuser';
   END IF;
END
$$;


--pg_reload_conf() reloads the postgres setting so the changes from ALTER SYSTEM
-- statements apply without having to restart the server
SELECT pg_reload_conf();


--classdb.postgresLog is a temporary staging table for data imported from the logs.
-- The data is then processed in classdb.importLog()
-- This table format suggested by the Postgres documentation for use with the
-- COPY statement
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

--Change owner of the import staging table to ClassDB
ALTER TABLE classdb.postgresLog OWNER TO ClassDB;
REVOKE ALL PRIVILEGES ON classdb.postgresLog FROM PUBLIC;

--Function to import a given day's log file, and update student connection information
-- The latest connection in the student table supplied the assumed last import date,
-- so logs later than this date are imported.  If this value is null, logs are parsed,
-- starting with the supplied date (startDate)
-- For each line containing connection information, the matching student's
-- connection info is updated
DROP FUNCTION IF EXISTS classdb.importLog(startDate DATE);
CREATE FUNCTION classdb.importLog(startDate DATE DEFAULT current_date)
   RETURNS VOID AS
$$
DECLARE
   logPath VARCHAR(4096); --Max file path length on Linux, > max length on Windows
   lastConDate DATE;
BEGIN
	--Set the date of last logged connection to either the latest connection in
	-- classdb.student, or startDate if that is NULL
	lastConDate := COALESCE(date((SELECT MAX(lastConnection) FROM classdb.student)), startDate);

	--We want to import all logs between the lastConDate and current date
	WHILE lastConDate <= current_date LOOP
	   --Get the full path to the log, assumes a log file name of postgresql-%m.%d.csv
	   -- the log_directory setting holds the log path
      logPath := (SELECT setting FROM pg_settings WHERE "name" = 'log_directory') ||
         '/postgresql-' || to_char(lastConDate, 'MM.DD') || '.csv';
      --Use copy to fill the temp import table
      EXECUTE format('COPY classdb.postgresLog FROM ''%s'' WITH csv', logPath);
      lastConDate := lastConDate + 1; --Check the next day
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
      AND (pg.log_time AT TIME ZONE 'utc') > COALESCE(lastConnection, to_timestamp(0))
      AND message LIKE 'connection%' --Filter out extraneous log lines
      AND database_name = current_database() --Limit to log lines for current db only
   ),
   --Find the latest connection date in the logs
   lastConnection = COALESCE(
      (
         SELECT MAX(log_time AT TIME ZONE 'utc')
         FROM classdb.postgresLog pg
         WHERE pg.user_name = userName
         AND (pg.log_time AT TIME ZONE 'utc') > COALESCE(lastConnection, to_timestamp(0))
         AND message LIKE 'connection%' --conn log messages start w/ 'connection'
         AND database_name = current_database()
      ), lastConnection);
   --Clear the log table
   TRUNCATE classdb.postgresLog;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;

--The COPY statement requires importLog() to be run as a superuser, with SECURITY
-- DEFINER
--Revoke permissions on classdb.importLog(startDate DATE) from PUBLIC, but allow
-- Instructors and DBManagers to use it
REVOKE ALL ON FUNCTION
   classdb.importLog(startDate DATE)
   FROM PUBLIC;
GRANT EXECUTE ON FUNCTION
   classdb.importLog(startDate DATE)
   TO ClassDB_Instructor, ClassDB_DBManager;

--SET up DDL command logging

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
