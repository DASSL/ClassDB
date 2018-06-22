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
-- it should be run after running enableConnectionActivityLogging.psql for the
-- server and after running addUserMgmtCore.sql for the current database

--This script adds the connection logging portion of the ClassDB user monitoring
-- system.  It provides the ClassDB.importConnectionLog() function to import
-- the Postgres connection logs and record student connection data.
-- Additionally, this file provides helper functions to check the status of
-- logging settings on the server


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


--UPGRADE FROM 2.0 to 2.1
-- These statements are needed when upgrading ClassDB from 2.0 to 2.1, and can
-- be removed in a future version
DROP TABLE IF EXISTS ClassDB.PostgresLog; --Now a temp table in importConnectionLog
DROP FUNCTION IF EXISTS ClassDB.importConnectionLog(DATE); --Return type changed


--Helper function to check if server parameter log_connections is set to 'on' or 'off'.
CREATE OR REPLACE FUNCTION ClassDB.isConnectionLoggingEnabled()
   RETURNS BOOLEAN AS
$$
   --This query returns 'on' or 'off', which can be cast to a boolean
   SELECT COALESCE(setting::BOOLEAN, FALSE)
   FROM pg_catalog.pg_settings
   WHERE name = 'log_connections';
$$ LANGUAGE sql
   SECURITY DEFINER;

ALTER FUNCTION ClassDB.isConnectionLoggingEnabled() OWNER TO ClassDB;

REVOKE ALL ON FUNCTION ClassDB.isConnectionLoggingEnabled()
   FROM PUBLIC;

GRANT EXECUTE ON FUNCTION ClassDB.isConnectionLoggingEnabled()
   TO ClassDB_Instructor, ClassDB_DBManager;


--Helper function to check if server parameter logging_collector is set to 'on' or 'off'.
CREATE OR REPLACE FUNCTION ClassDB.isLoggingCollectorEnabled()
   RETURNS BOOLEAN AS
$$
   --This query returns 'on' or 'off', which can be cast to a boolean
   SELECT COALESCE(setting::BOOLEAN, FALSE)
   FROM pg_catalog.pg_settings
   WHERE name = 'logging_collector';
$$ LANGUAGE sql
   SECURITY DEFINER;

ALTER FUNCTION ClassDB.isLoggingCollectorEnabled() OWNER TO ClassDB;

REVOKE ALL ON FUNCTION ClassDB.isLoggingCollectorEnabled()
   FROM PUBLIC;

GRANT EXECUTE ON FUNCTION ClassDB.isLoggingCollectorEnabled()
   TO ClassDB_Instructor, ClassDB_DBManager;


--Function to import log files between a starting date and the current date
-- and update ClassDB.ConnectionActivity.
--For each log entry containing connection information about a ClassDB user,
-- a new record is added to ClassDB.ConnectionActivity.
--By default, this function imports all log files between the last imported log
-- and today's log. If logs have never been imported, only today's log will be imported.
--This behavior can be overridden by supplying a date parameter. All logs between
-- the supplied date and today's will then be imported.
--Note that connection activity records will not be added for any connections prior
-- to the latest connection in ClassDB.ConnectionActivity.
CREATE OR REPLACE FUNCTION ClassDB.importConnectionLog(startDate DATE DEFAULT NULL)
   RETURNS TABLE
   (
      logDate DATE,
      numConnections INTEGER, --Returns the # of new connections/disconnections
      numDisconnections INTEGER,
      info VARCHAR
   ) AS
$$
DECLARE
   logPath VARCHAR(4096); --Max file path length on Linux, > max length on Windows
   lastConTimestampUTC TIMESTAMP; --Hold the latest time (UTC) a connection was logged
   lastConDateLocal DATE; --Hold the latest date (local time) a connection was logged
   disabledLogSettings VARCHAR(100); --Holds any disabled log settings for warning output
BEGIN
   --Get a string containing the setting names of any disabled log settings
   SELECT INTO disabledLogSettings string_agg(name, ', ')
   FROM pg_catalog.pg_settings
   WHERE name IN ('logging_collector', 'log_connections', 'log_disconnections')
   AND setting = 'off';

   --Warn the user if any server connection logging parameters are disabled
   IF (disabledLogSettings IS NOT NULL) THEN
      RAISE WARNING  'log files might be missing or incomplete'
      USING DETAIL = 'The following server parameters are currently off: ' || disabledLogSettings,
            HINT   = 'Consult the ClassDB documentation for details on setting logging-related parameters.';
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

   --Temporary table that stores a summary of the data imported from each log
   CREATE TEMPORARY TABLE ImportResult
   (
      logDate DATE,
      numConnections INTEGER,
      numDisconnections INTEGER,
      info VARCHAR
   );

   --Get the timestamp (at UTC) of the latest connection activity entry. Then
   -- convert the timestamp to local time to get a 'best-guess' of the last log
   -- file data that was imported
   lastConTimestampUTC = (SELECT MAX(ActivityAtUTC)
                          FROM ClassDB.ConnectionActivity);

   lastConDateLocal = date(ClassDB.ChangeTimeZone(lastConTimeStampUTC));

   --Set the date of last logged connection. We prefer the user-supplied parameter, but
   -- defer to our 'best-guess' and finally, the current date if preceding values are null
   lastConDateLocal = COALESCE(startDate, lastConDateLocal, CURRENT_DATE);

   --We want to import all logs between the lastConDateLocal and current date
   WHILE lastConDateLocal <= CURRENT_DATE LOOP
      --Get the full path to the log, assumes a log file name of postgresql-%m.%d.csv
      -- the log_directory setting holds the log path
      logPath := (SELECT setting FROM pg_catalog.pg_settings WHERE "name" = 'log_directory') ||
         '/postgresql-' || to_char(lastConDateLocal, 'MM.DD') || '.csv';

      --Import entries from the day's server log into our log table
      BEGIN
         EXECUTE format('COPY pg_temp.ImportedLogData FROM ''%s'' WITH csv', logPath);
         INSERT INTO pg_temp.ImportResult VALUES (lastConDateLocal, 0, 0, NULL);
      EXCEPTION
         WHEN undefined_file THEN
            --If an expected log file is missing, skip importing that log and
            -- try the next log file. Store the error in the result table
            RAISE WARNING 'log file for % not found, skipping.', lastConDateLocal;
            INSERT INTO pg_temp.ImportResult VALUES (lastConDateLocal, 0, 0, SQLERRM);
         WHEN OTHERS THEN
            RAISE WARNING 'importing log file for %s failed', lastConDateLocal
            USING DETAIL = SQLERRM;
            INSERT INTO pg_temp.ImportResult VALUES (lastConDateLocal, 0, 0, SQLERRM);
      END;

      lastConDateLocal := lastConDateLocal + 1; --Check the next day
   END LOOP;

   --Update ClassDB.ConnectionActivity based on the imported data
   -- We only want to insert activity records that are newer than the current
   -- latest activity record, and are by ClassDB users to the current DB
   WITH LogInsertedCount AS
   (
      INSERT INTO ClassDB.ConnectionActivity
         SELECT user_name, log_time AT TIME ZONE 'utc',
            CASE WHEN message LIKE 'connection authorized%' THEN 'C' ELSE 'D' END,
            session_id, application_name
         FROM pg_temp.ImportedLogData
         WHERE ClassDB.isUser(user_name) --Check the connection is from a ClassDB user
         AND (log_time AT TIME ZONE 'utc') > --Check that the entry is new
            COALESCE(lastConTimeStampUTC, to_timestamp(0))
         AND database_name = CURRENT_DATABASE() --Only pick entries from current DB
         AND (message LIKE 'connection authorized%'
         OR   message LIKE 'disconnection%') --Only pick (dis)connection-related entries
      RETURNING ClassDB.changeTimeZone(ActivityAtUTC)::DATE AS logDate, ActivityType
   )
   UPDATE pg_temp.ImportResult ir --Next, update the totals in the result table
   SET numConnections = COALESCE((SELECT COUNT(*)
                                  FROM LogInsertedCount ic
                                  WHERE ic.logDate = ir.logDate
                                  AND ActivityType = 'C'
                                  GROUP BY ic.logDate), 0),
       numDisconnections = COALESCE((SELECT COUNT(*)
                                      FROM LogInsertedCount ic
                                      WHERE ic.logDate = ir.logDate
                                      AND ActivityType = 'D'
                                      GROUP BY ic.logDate), 0);

    --Set output of this query as the return table. Note that the function does
    -- not terminate here
    -- (https://www.postgresql.org/docs/current/static/plpgsql-control-structures.html)
    RETURN QUERY SELECT * FROM pg_temp.ImportResult;

   --Drop the temp tables - running this function twice inside a transactions will
   -- otherwise result in an error
   --ImportResult must be dropped after the RETURN QUERY, since its data is used
   -- for the return value
   DROP TABLE pg_temp.ImportedLogData;
   DROP TABLE pg_temp.ImportResult;

   --Explicitly return to clarify the RETURN QUERY usage
   RETURN;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;

--The COPY statement requires importConnectionLog() to be run as a superuser, with
-- SECURITY DEFINER. Thus importConnectionLog() is not given to ClassDB.
REVOKE ALL ON FUNCTION ClassDB.importConnectionLog(DATE) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION ClassDB.importConnectionLog(DATE)
   TO ClassDB_Instructor, ClassDB_DBManager, ClassDB;

COMMIT;
