--addLogMgmt.sql - ClassDB

--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab (DASSL)
--https://dassl.github.io/

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.

--This script must be run as superuser.
--This script should be run in every database in which log management is required
-- it should be run after running enableServerLogging.sql for the server and after running
-- addUserMgmt.sql for the current database

--This script adds the connection logging portion of the ClassDB user monitoring
-- system.  It provides the classdb.importLog () function to import
-- to import the Postgres connection logs and record student connection data.


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
CREATE OR REPLACE FUNCTION classdb.importLog(startDate DATE DEFAULT NULL)
   RETURNS VOID AS
$$
DECLARE
   logPath VARCHAR(4096); --Max file path length on Linux, > max length on Windows

   lastConDate DATE;
BEGIN
   --Get a 'best-guess' last import date based on the connection activity logs
   --This is one of those places where you need double parens. One level for the function call,
   -- one for the sub-query
   lastConDate = date((SELECT ClassDB.ChangeTimeZone(MAX(AcceptedAtUTC))
                       FROM ClassDB.ConnectionActivity));

	--Set the date of last logged connection. We prefer the user-supplied parameter, but
   -- defer to our 'best-guess' and finally, the current date if preceeding values are null
	lastConDate := COALESCE(startDate, lastConDate, CURRENT_DATE);

	--We want to import all logs between the lastConDate and current date
	WHILE lastConDate <= CURRENT_DATE LOOP
	   --Get the full path to the log, assumes a log file name of postgresql-%m.%d.csv
	   -- the log_directory setting holds the log path
      logPath := (SELECT setting FROM pg_settings WHERE "name" = 'log_directory') ||
         '/postgresql-' || to_char(lastConDate, 'MM.DD') || '.csv';
      --Use copy to fill the temp import table
      EXECUTE format('COPY classdb.postgresLog FROM ''%s'' WITH csv', logPath);
      lastConDate := lastConDate + 1; --Check the next day
   END LOOP;

   --Update the connection activity table based on the temp log table
   INSERT INTO ClassDB.ConnectionActivity
   SELECT user_name, log_time AT TIME ZONE 'utc'
   FROM ClassDB.postgresLog
   WHERE ClassDB.isUser(user_name) --Check the connection is from a ClassDB user
   AND (log_time AT TIME ZONE 'utc') > COALESCE((SELECT MAX(AcceptedAtUTC) FROM ClassDB.ConnectionActivity), to_timestamp(0))
   AND message LIKE 'connection%' --Filter out extraneous log lines
   AND database_name = current_database() --Limit to log lines for current db only
   ORDER BY log_time;

   --Clear the log table
   TRUNCATE classdb.postgresLog;
END;
$$ LANGUAGE plpgsql
   VOLATILE
   SECURITY DEFINER;

--The COPY statement requires importLog() to be run as a superuser, with SECURITY
-- DEFINER. Thus importLog() is not given to ClassDB.
--Revoke permissions on classdb.importLog(startDate DATE) from PUBLIC, but allow
-- Instructors and DBManagers to use it
REVOKE ALL ON FUNCTION
   ClassDB.importLog(DATE)
   FROM PUBLIC;

GRANT EXECUTE ON FUNCTION
   ClassDB.importLog(DATE)
   TO ClassDB_Instructor, ClassDB_DBManager;

COMMIT;
