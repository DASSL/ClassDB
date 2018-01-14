--addClassDBRolesViewsCore.sql - ClassDB

--Andrew Figueroa, Kevin Kelly, Steven Rollo, Sean Murthy
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
CREATE OR REPLACE VIEW ClassDB.User AS
  SELECT RoleName AS UserName, FullName, SchemaName, ExtraInfo,
  ClassDB.IsInstructor(RoleName) AS IsInstructor, --True if user is instructor
  ClassDB.IsStudent(RoleName) AS IsStudent, --True if user is student
  ClassDB.IsDBManager(RoleName) AS IsDBManager, --True if user is DBManager
  ClassDB.isUser(RoleName) AS HasClassDBRole, --True if user is any ClassDB role
  COALESCE(DDLCount, 0) AS DDLCount, LastDDLActivityAtUTC,
  LastDDLOperation, LastDDLObject,
  COALESCE(ConnectionCount, 0) AS ConnectionCount, LastConnectionAtUTC
FROM ClassDB.RoleBase
LEFT OUTER JOIN (
  SELECT UserName,
  COUNT(*) AS DDLCount, --The amount of DDLs the user has executed
  MAX(StatementStartedAtUTC) AS LastDDLActivityAtUTC --TIMESTAMP of user's last DDL op
  FROM ClassDB.DDLActivity
  GROUP BY UserName) AS DDLActivityAggregate on RoleName = DDLActivityAggregate.UserName
LEFT OUTER JOIN (
  SELECT UserName,
  COUNT(*) AS ConnectionCount, --Total amount of times user has connected to this DB
  MAX(AcceptedAtUTC) AS LastConnectionAtUTC --TIMESTAMP of the last connection user made
  FROM ClassDB.ConnectionActivity
  GROUP BY UserName) AS ConnectionActivity on RoleName = ConnectionActivity.UserName
LEFT OUTER JOIN (
  SELECT Distinct on (UserName) UserName,
  DDLOperation AS LastDDLOperation, --The operation that the user last performed
  DDLObject AS LastDDLObject  --The object that the user last performed the DDL activity on
  FROM ClassDB.DDLActivity
  ORDER BY UserName, StatementStartedAtUTC DESC) AS DDLActOB on Rolename = DDLActOB.UserName
WHERE NOT IsTeam;

ALTER VIEW ClassDB.User OWNER TO ClassDB;
REVOKE ALL PRIVILEGES ON ClassDB.User FROM PUBLIC;
GRANT SELECT ON ClassDB.User TO ClassDB_Instructor, ClassDB_DBManager;



--Define views to obtain info on known instructors, students, and DB managers
-- these views obtain information from the previously defined ClassDB.User view
CREATE OR REPLACE VIEW ClassDB.Instructor AS
   SELECT UserName, FullName, SchemaName, ExtraInfo, IsStudent, IsDBManager,
          DDLCount, LastDDLOperation, LastDDLObject, LastDDLActivityAtUTC,
          ConnectionCount, LastConnectionAtUTC
   FROM ClassDB.User
   WHERE IsInstructor;

ALTER VIEW ClassDB.Instructor OWNER TO ClassDB;
REVOKE ALL PRIVILEGES ON ClassDB.Instructor FROM PUBLIC;
GRANT SELECT ON ClassDB.Instructor TO ClassDB_Instructor, ClassDB_DBManager;



CREATE OR REPLACE VIEW ClassDB.Student AS
   SELECT UserName, FullName, SchemaName, ExtraInfo, IsInstructor, IsDBManager,
          DDLCount, LastDDLOperation, LastDDLObject, LastDDLActivityAtUTC,
          ConnectionCount, LastConnectionAtUTC
   FROM ClassDB.User
   WHERE IsStudent;

ALTER VIEW ClassDB.Student OWNER TO ClassDB;
REVOKE ALL PRIVILEGES ON ClassDB.Student FROM PUBLIC;
GRANT SELECT ON ClassDB.Student TO ClassDB_Instructor, ClassDB_DBManager;



CREATE OR REPLACE VIEW ClassDB.DBManager AS
   SELECT UserName, FullName, SchemaName, ExtraInfo, IsInstructor, IsStudent,
          DDLCount, LastDDLOperation, LastDDLObject, LastDDLActivityAtUTC,
          ConnectionCount, LastConnectionAtUTC
   FROM ClassDB.User
   WHERE IsDBManager;

ALTER VIEW ClassDB.DBManager OWNER TO ClassDB;
REVOKE ALL PRIVILEGES ON ClassDB.DBManager FROM PUBLIC;
GRANT SELECT ON ClassDB.DBManager TO ClassDB_Instructor, ClassDB_DBManager;


COMMIT;
