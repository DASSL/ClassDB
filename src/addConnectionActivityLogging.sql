--addConnectionActivityLogging.sql - ClassDB

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


--ClassDB.PostgresLog is a staging table for data imported from the logs.
-- The data is then processed in classdb.importLog().
-- This table format suggested by the Postgres documentation for use with the
-- COPY statement
-- https://www.postgresql.org/docs/9.6/static/runtime-config-logging.html
-- We only use the log_time and message columns for the log import process
DROP TABLE IF EXISTS ClassDB.PostgresLog;
CREATE TABLE ClassDB.PostgresLog
(
   log_time TIMESTAMP(3) WITH TIME ZONE, --Holds the connection accepted timestamp
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
   message TEXT, --States if the log row is a connection event, or someting else
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


--Function to import all log files between a starting date and the current date
-- and update student connection information.
-- The latest connection in the student table supplied the assumed last import date,
-- so logs later than this date are imported.  If this value is null, logs are parsed,
-- starting with the supplied date (startDate)
-- For each line containing connection information, the matching student's
-- connection info is updated
CREATE OR REPLACE FUNCTION classdb.importConnectionLog(startDate DATE DEFAULT NULL)
   RETURNS VOID AS
$$
DECLARE
   logPath VARCHAR(4096); --Max file path length on Linux, > max length on Windows
   lastConTimestampUTC TIMESTAMP; --Hold the latest time (UTC) a connection was logged
   lastConDateLocal DATE; --Hold the latest date (local time) a connection was logged
BEGIN
   --Get the timestamp (at UTC) of the latest connection activity entry. Then
   -- convert the timestamp to local time to get a 'best-guess' of the last log
   -- file data that was imported
   lastConTimestampUTC = (SELECT MAX(AcceptedAtUTC)
                          FROM ClassDB.ConnectionActivity);

   lastConDateLocal = date(ClassDB.ChangeTimeZone(lastConTimeStampUTC));

	--Set the date of last logged connection. We prefer the user-supplied parameter, but
   -- defer to our 'best-guess' and finally, the current date if preceeding values are null
	lastConDateLocal = COALESCE(startDate, lastConDateLocal, CURRENT_DATE);

	--We want to import all logs between the lastConDate and current date
	WHILE lastConDateLocal <= CURRENT_DATE LOOP
	   --Get the full path to the log, assumes a log file name of postgresql-%m.%d.csv
	   -- the log_directory setting holds the log path
      logPath := (SELECT setting FROM pg_settings WHERE "name" = 'log_directory') ||
         '/postgresql-' || to_char(lastConDateLocal, 'MM.DD') || '.csv';
      --Import entries from the day's server log into our log table
      EXECUTE format('COPY classdb.postgresLog FROM ''%s'' WITH csv', logPath);
      lastConDateLocal := lastConDateLocal + 1; --Check the next day
   END LOOP;

   --Update the connection activity table based on the temp log table
   -- We only want to insert new activity records that are newer than the current
   -- latest connection, and are by ClassDB users to the current DB
   INSERT INTO ClassDB.ConnectionActivity
      SELECT user_name, log_time AT TIME ZONE 'utc'
      FROM ClassDB.postgresLog
      WHERE ClassDB.isUser(user_name) --Check the connection is from a ClassDB user
      AND (log_time AT TIME ZONE 'utc') > --Check that the entry is new
         COALESCE(lastConTimeStampUTC, to_timestamp(0))
      AND message LIKE 'connection%' --Only pick connection-related entries
      AND database_name = CURRENT_DATABASE(); --Only pick entries from current DB

   --Clear the log table
   TRUNCATE ClassDB.PostgresLog;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;

--The COPY statement requires importConnectionLog() to be run as a superuser, with
-- SECURITY DEFINER. Thus importConnectionLog() is not given to ClassDB.
REVOKE ALL ON FUNCTION ClassDB.importConnectionLog(DATE) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION ClassDB.importConnectionLog(DATE)
   TO ClassDB_Instructor, ClassDB_DBManager, ClassDB;

COMMIT;
