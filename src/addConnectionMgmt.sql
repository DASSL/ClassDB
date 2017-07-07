--addConnectionMgmt.sql - ClassDB

--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab (DASSL), Western Connecticut State University (WCSU)

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.

--This script requires the current user to be a superuser

--This script should be run after initializeDB.sql

--This script will create procedures used to manage user connections.


START TRANSACTION;


--Make sure the current user has sufficient privilege to run this script
-- privileges required: superuser
DO
$$
BEGIN
   IF NOT classdb.isSuperUser() THEN
      RAISE EXCEPTION 'Insufficient privileges: script must be run as a user with'
                      ' superuser privileges';
   END IF;
END
$$;

--Suppress NOTICE messages for this script only, this will not apply to functions
-- defined within. This hides messages that are unimportant, but possibly confusing
SET LOCAL client_min_messages TO WARNING;


--Need to drop the function prior to the return type
DROP FUNCTION IF EXISTS classdb.listUserConnections(VARCHAR(63));

--List all connections for a specific user. Gets information from pg_stat_activity
CREATE FUNCTION classdb.listUserConnections(userName VARCHAR(63))
   RETURNS TABLE
(
   userName VARCHAR(63), --VARCHAR(63) used as NAME replacement
   pid INT,
   applicationName VARCHAR(63),
   clientAddress INET, --holds client ip address
   connectionStartTime TIMESTAMPTZ, --provided by backend_start in pg_stat_activity
   lastQueryStartTime TIMESTAMPTZ   --provided by query_start in pg_stat_activity
)
AS $$
   SELECT usename::VARCHAR(63), pid, application_name, client_addr, backend_start, query_start
   FROM pg_stat_activity
   WHERE usename = classdb.foldPgID($1);
$$ LANGUAGE sql
   SECURITY DEFINER;

--Set execution permissions
--The function remains owned by the creating user (a "superuser"):
-- This allows instructors and db managers unrestricted access to pg_stat_activity
--Otherwise, they cannot see info like ip address and timestamps of other users
REVOKE ALL ON FUNCTION
   classdb.listUserConnections(VARCHAR(63))
   FROM PUBLIC;
GRANT EXECUTE ON FUNCTION
   classdb.listUserConnections(VARCHAR(63))
   TO ClassDB_Instructor, ClassDB_DBManager;


DROP FUNCTION IF EXISTS classdb.killConnection(INT);
--Kills a specific connection given a pid INT4
-- pg_terminate_backend takes pid as INT4
CREATE FUNCTION classdb.killConnection(pid INT)
RETURNS BOOLEAN AS $$
   SELECT pg_terminate_backend($1);
$$ LANGUAGE sql
   SECURITY DEFINER;

--Change function ownership and set execution permissions
ALTER FUNCTION
   classdb.killConnection(INT)
   OWNER TO ClassDB;
REVOKE ALL ON FUNCTION
   classdb.killConnection(INT)
   FROM PUBLIC;
GRANT EXECUTE ON FUNCTION
   classdb.killConnection(INT)
   TO ClassDB_Instructor, ClassDB_DBManager;


DROP FUNCTION IF EXISTS classdb.killUserConnections(VARCHAR(63));
--Kills all open connections for a specific user
CREATE FUNCTION classdb.killUserConnections(userName VARCHAR(63))
RETURNS TABLE
(
   pid INT,
   Success BOOLEAN
)
AS $$
   SELECT pid, classdb.killConnection(pid)
   FROM pg_stat_activity
   WHERE usename = classdb.foldPgID($1);
$$ LANGUAGE sql
   SECURITY DEFINER;

--Change function ownership and set execution permissions
-- We can change the owner of this to ClassDB because it is a member of
-- pg_signal_backend
ALTER FUNCTION
   classdb.killUserConnections(VARCHAR(63))
   OWNER TO ClassDB;
REVOKE ALL ON FUNCTION
   classdb.killUserConnections(VARCHAR(63))
   FROM PUBLIC;
GRANT EXECUTE ON FUNCTION
   classdb.killUserConnections(VARCHAR(63))
   TO ClassDB_Instructor, ClassDB_DBManager;


COMMIT;
