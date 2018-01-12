--addClassDBRolesViewsCore.sql - ClassDB

--Andrew Figueroa, Kevin Kelly, Steven Rollo Sean Murthy
--Data Science & Systems Lab (DASSL)
--https://dassl.github.io/

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.


--This script requires the current user to be a superuser

--This script should be run in every database to which ClassDB is to be added
-- it should be run after running addClassDBRolesMgmt.sql

--This script creates views for User, Student, Instructor, and DBManager
-- views add derived attributes to the base data in the associated tables


START TRANSACTION;

--Suppress NOTICE messages for this script
-- hides unimportant but possibly confusing msgs generated as the script executes
SET LOCAL client_min_messages TO WARNING;

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


--Define a view to return known users
-- the fields marked TBD are yet to be filled in: they are commented out so
-- the view definition can be replaced later
CREATE OR REPLACE VIEW ClassDB.User AS
SELECT
   RoleName AS UserName, FullName, SchemaName, ExtraInfo,
   ClassDB.IsInstructor(RoleName) AS IsInstructor,
   ClassDB.IsStudent(RoleName) AS IsStudent,
   ClassDB.IsDBManager(RoleName) AS IsDBManager,
   (ClassDB.IsInstructor(RoleName) OR ClassDB.IsStudent(RoleName) OR
     ClassDB.IsDBManager(RoleName)) AS HasClassDBRole
   --0 AS DDLCount,              --TBD
   --NULL AS LastDDLObject,      --TBD
   --NULL AS LastDDLActivityAt,  --TBD
   --0 AS ConnectionCount,       --TBD
   --NULL AS LastConnectionAtUTC --TBD
FROM ClassDB.RoleBase
WHERE NOT IsTeam;

ALTER VIEW ClassDB.User OWNER TO ClassDB;
REVOKE ALL PRIVILEGES ON ClassDB.User FROM PUBLIC;
GRANT SELECT ON ClassDB.User TO ClassDB_Instructor, ClassDB_DBManager;



--Define views to obtain info on known instructors, students, and DB managers
-- these views obtain information from the previously defined ClassDB.User view
CREATE OR REPLACE VIEW ClassDB.Instructor AS
   SELECT UserName, FullName, SchemaName, ExtraInfo, IsStudent, IsDBManager
--TBD:    DDLCount, LastDDLOperation, LastDDLObject, LastDDLActivityAtUTC,
--TBD:    ConnectionCount, LastConnectionAtUTC
   FROM ClassDB.User
   WHERE IsInstructor;

ALTER VIEW ClassDB.Instructor OWNER TO ClassDB;
REVOKE ALL PRIVILEGES ON ClassDB.Instructor FROM PUBLIC;
GRANT SELECT ON ClassDB.Instructor TO ClassDB_Instructor, ClassDB_DBManager;



CREATE OR REPLACE VIEW ClassDB.Student AS
   SELECT UserName, FullName, SchemaName, ExtraInfo, IsInstructor, IsDBManager
--TBD:    DDLCount, LastDDLOperation, LastDDLObject, LastDDLActivityAtUTC,
--TBD:    ConnectionCount, LastConnectionAtUTC
   FROM ClassDB.User
   WHERE IsStudent;

ALTER VIEW ClassDB.Student OWNER TO ClassDB;
REVOKE ALL PRIVILEGES ON ClassDB.Student FROM PUBLIC;
GRANT SELECT ON ClassDB.Student TO ClassDB_Instructor, ClassDB_DBManager;



CREATE OR REPLACE VIEW ClassDB.DBManager AS
   SELECT UserName, FullName, SchemaName, ExtraInfo, IsInstructor, IsStudent
--TBD:    DDLCount, LastDDLOperation, LastDDLObject, LastDDLActivityAtUTC,
--TBD:    ConnectionCount, LastConnectionAtUTC
   FROM ClassDB.User
   WHERE IsDBManager;

ALTER VIEW ClassDB.DBManager OWNER TO ClassDB;
REVOKE ALL PRIVILEGES ON ClassDB.DBManager FROM PUBLIC;
GRANT SELECT ON ClassDB.DBManager TO ClassDB_Instructor, ClassDB_DBManager;


COMMIT;
