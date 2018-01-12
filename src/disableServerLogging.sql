--disableServerLogging.sql - ClassDB

--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab (DASSL)
--https://dassl.github.io/

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.

--This script must be run as superuser.
--This script only needs to be run once per server to disable connection logging.

--Additonally, this script must be run using a client that will send each statement
-- individually, such as psql.  Some clients, like pgAdmin 4, cannot run this script
-- because they pack each statement into a single command string.  This causes
-- ALTER SYSTEM statements to fail.

--This script uses ALTER SYSTEM statements to change the Postgres server log settings to
-- disable the connection logging system. This script only stops connections from being
-- logged. It does not revert log_destination and log_filname to the original settings
-- prior to running enableServerLogging.sql.

--The following changes are made:
-- log_connections TO 'off' stops user connections from being recorded in the server log
ALTER SYSTEM SET log_connections TO 'off';

--pg_reload_conf() reloads the postgres setting so the changes from ALTER SYSTEM
-- statements apply without having to restart the server
SELECT pg_reload_conf();
