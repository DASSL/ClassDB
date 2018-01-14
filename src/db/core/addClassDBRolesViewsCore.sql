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
-- IsXYZ fields denote if user is a member of the appropriate ClassDB role
-- HasClassDBRole is TRUE if any of the IsXYZ fields is TRUE
-- creates derived tables w/ user-specific aggregates over tables DDLActivity
-- and ConnectionActivity
-- DISTINCT ON (RoleName) limits output to just one row per role: required
-- because the join to get last DDL op and object can technically return
-- more than one row for a user because DDLActivity does not have a PK
CREATE OR REPLACE VIEW ClassDB.User AS
  SELECT DISTINCT ON (RoleName) RoleName AS UserName,
  FullName, SchemaName, ExtraInfo,
  ClassDB.IsInstructor(RoleName) AS IsInstructor,
  ClassDB.IsStudent(RoleName) AS IsStudent,
  ClassDB.IsDBManager(RoleName) AS IsDBManager,
  ClassDB.IsInstructor(RoleName)
  OR ClassDB.IsStudent(RoleName)
  OR ClassDB.IsDBManager(RoleName) AS HasClassDBRole,
  COALESCE(DDLCount, 0) AS DDLCount, LastDDLActivityAtUTC,
  D2.DDLOperation AS LastDDLOperation, D2.DDLObject AS LastDDLObject,
  COALESCE(ConnectionCount, 0) AS ConnectionCount, LastConnectionAtUTC
FROM ClassDB.RoleBase
LEFT OUTER JOIN
(
  SELECT UserName,
  COUNT(*) AS DDLCount, --# of DDL ops by user
  MAX(StatementStartedAtUTC) AS LastDDLActivityAtUTC --time of user's last DDL op
  FROM ClassDB.DDLActivity
  GROUP BY UserName
) AS D1 ON D1.UserName = RoleName
LEFT OUTER JOIN --can return more than one row because DDLActivity has no PK
  ClassDB.DDLActivity D2 ON D2.UserName = Rolename AND D2.UserName = D1.UserName
                            AND D2.StatementStartedAtUTC = D1.LastDDLActivityAtUTC
LEFT OUTER JOIN
(
  SELECT UserName,
  COUNT(*) AS ConnectionCount, --# of connections by user
  MAX(AcceptedAtUTC) AS LastConnectionAtUTC --time of user's last connection
  FROM ClassDB.ConnectionActivity
  GROUP BY UserName
) AS C ON C.UserName = RoleName
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
