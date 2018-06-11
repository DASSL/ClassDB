--addConnectionActivityLoggingReco.sql - ClassDB

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
-- system.  It provides the ClassDB.importLog () function to import
-- the Postgres connection logs and record student connection data.


START TRANSACTION;

--Check for superuser
DO
$$
BEGIN
   IF NOT (SELECT ClassDB.isSuperUser()) THEN
      RAISE EXCEPTION 'Insufficient privileges for script: must be run as a superuser';
   END IF;
END
$$;

--Suppress NOTICE messages for this script only, this will not apply to functions
-- defined within. This hides messages that are unimportant, but possibly confusing
SET LOCAL client_min_messages TO WARNING;


--Helper function to check if log_connections is set to 'on' or 'off'.
CREATE OR REPLACE FUNCTION ClassDB.isConnectionLoggingEnabled()
   RETURNS BOOLEAN AS
$$
   --This query returns 'on' or 'off', which can be cast to a boolean
   SELECT COALESCE(setting::BOOLEAN, FALSE)
   FROM pg_settings
   WHERE name = 'log_connections';
$$ LANGUAGE sql
   SECURITY DEFINER;

ALTER FUNCTION ClassDB.isConnectionLoggingEnabled() OWNER TO ClassDB;

REVOKE ALL ON FUNCTION ClassDB.isConnectionLoggingEnabled()
   FROM PUBLIC;

GRANT EXECUTE ON FUNCTION classdb.isConnectionLoggingEnabled()
   TO ClassDB_Instructor, ClassDB_DBManager;


--Helper function to check if logging_collector is set to 'on' or 'off'.
CREATE OR REPLACE FUNCTION ClassDB.isLoggingCollectorEnabled()
   RETURNS BOOLEAN AS
$$
   --This query returns 'on' or 'off', which can be cast to a boolean
   SELECT COALESCE(setting::BOOLEAN, FALSE)
   FROM pg_settings
   WHERE name = 'logging_collector';
$$ LANGUAGE sql
   SECURITY DEFINER;

ALTER FUNCTION ClassDB.isLoggingCollectorEnabled() OWNER TO ClassDB;

REVOKE ALL ON FUNCTION ClassDB.isLoggingCollectorEnabled()
   FROM PUBLIC;

GRANT EXECUTE ON FUNCTION classdb.isLoggingCollectorEnabled()
   TO ClassDB_Instructor, ClassDB_DBManager;

--Function to import all log files between a starting date and the current date
-- and update student connection information.
-- The latest connection in the student table supplied the assumed last import date,
-- so logs later than this date are imported.  If this value is null, logs are parsed,
-- starting with the supplied date (startDate)
-- For each line containing connection information, the matching student's
-- connection info is updated
CREATE OR REPLACE FUNCTION ClassDB.importConnectionLog(startDate DATE DEFAULT NULL)
   RETURNS TABLE
   (
      logDate DATE,
      connectionsLogged INT,
      info VARCHAR
   ) AS
$$
DECLARE
   logPath VARCHAR(4096); --Max file path length on Linux, > max length on Windows
   lastConTimestampUTC TIMESTAMP; --Hold the latest time (UTC) a connection was logged
   lastConDateLocal DATE; --Hold the latest date (local time) a connection was logged
BEGIN
   --Warn the user if any server connection logging parameters are disabled
   IF NOT(ClassDB.isLoggingCollectorEnabled()) THEN
      RAISE WARNING  'Connection log might be missing/incomplete because log collection is off'
      USING DETAIL = '"logging_collector" SET TO "off"',
            HINT   = 'See "Managing Log Files" for more information';
   END IF;

   IF NOT(ClassDB.isConnectionLoggingEnabled()) THEN
      RAISE WARNING  'Connection log might be missing/incomplete because connection logging is off'
      USING DETAIL = '"log_connections" SET TO "off"',
            HINT   = 'See "Managing Log Files" for more information';
   END IF;

   --Temporary staging table for data imported from the logs.
   -- This table format suggested by the Postgres documentation for use with the
   -- COPY statement
   -- https://www.postgresql.org/docs/9.6/static/runtime-config-logging.html
   -- We only use the log_time and message columns for the log import process
   CREATE TEMPORARY TABLE ImportedLogData
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
      message TEXT, --States if the log row is a connection event, or something else
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

   --Temporary table that will store the status of each import
   -- ON COMMIT DROP drops the table at the end of the current transaction (ie.
   -- end of this function)
   CREATE TEMPORARY TABLE ImportResult
   (
      logDate DATE,
      connectionsLogged INT,
      info VARCHAR
   );

   --Get the timestamp (at UTC) of the latest connection activity entry. Then
   -- convert the timestamp to local time to get a 'best-guess' of the last log
   -- file data that was imported
   lastConTimestampUTC = (SELECT MAX(AcceptedAtUTC)
                          FROM ClassDB.ConnectionActivity);

   lastConDateLocal = date(ClassDB.ChangeTimeZone(lastConTimeStampUTC));

	--Set the date of last logged connection. We prefer the user-supplied parameter, but
   -- defer to our 'best-guess' and finally, the current date if preceding values are null
	lastConDateLocal = COALESCE(startDate, lastConDateLocal, CURRENT_DATE);

	--We want to import all logs between the lastConDate and current date
	WHILE lastConDateLocal <= CURRENT_DATE LOOP
	   --Get the full path to the log, assumes a log file name of postgresql-%m.%d.csv
	   -- the log_directory setting holds the log path
      logPath := (SELECT setting FROM pg_settings WHERE "name" = 'log_directory') ||
         '/postgresql-' || to_char(lastConDateLocal, 'MM.DD') || '.csv';

      --Import entries from the day's server log into our log table
      BEGIN
         EXECUTE format('COPY ImportedLogData FROM ''%s'' WITH csv', logPath);
         INSERT INTO ImportResult VALUES (lastConDateLocal, 0, NULL);
      EXCEPTION WHEN undefined_file THEN
         --If an expected log file is missing, skip importing that log and
         -- try the next log file. Store the error in the result table
         RAISE WARNING 'Log file for % not found, skipping.', lastConDateLocal;
         INSERT INTO ImportResult VALUES (lastConDateLocal, 0, SQLERRM);
      END;

      lastConDateLocal := lastConDateLocal + 1; --Check the next day
   END LOOP;

   --Update the connection activity table based on the temp log table
   -- We only want to insert new activity records that are newer than the current
   -- latest connection, and are by ClassDB users to the current DB
   WITH LogInsertedCount AS
   (
      INSERT INTO ClassDB.ConnectionActivity
         SELECT user_name, log_time AT TIME ZONE 'utc'
         FROM ImportedLogData
         WHERE ClassDB.isUser(user_name) --Check the connection is from a ClassDB user
         AND (log_time AT TIME ZONE 'utc') > --Check that the entry is new
            COALESCE(lastConTimeStampUTC, to_timestamp(0))
         AND message LIKE 'connection%' --Only pick connection-related entries
         AND database_name = CURRENT_DATABASE() --Only pick entries from current DB
      RETURNING ClassDB.changeTimeZone(AcceptedAtUTC)::DATE AS logDate
   )
   UPDATE ImportResult lr --Next, update the totals in the result table
   SET connectionsLogged = COALESCE((SELECT COUNT(*)
                                     FROM LogInsertedCount ic
                                     WHERE ic.logDate = lr.logDate
                                     GROUP BY ic.logDate), 0);

    --Return the result table
    RETURN QUERY SELECT * FROM ImportResult;

   --Drop the temp tables - running this function twice inside a transactions will
   -- otherwise result in an error
   DROP TABLE pg_temp.ImportedLogData;
   DROP TABLE pg_temp.ImportResult;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;

--The COPY statement requires importConnectionLog() to be run as a superuser, with
-- SECURITY DEFINER. Thus importConnectionLog() is not given to ClassDB.
REVOKE ALL ON FUNCTION ClassDB.importConnectionLog(DATE) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION ClassDB.importConnectionLog(DATE)
   TO ClassDB_Instructor, ClassDB_DBManager, ClassDB;

COMMIT;
