--addRoleBaseMgmtProxy.sql - ClassDB

--Kevin Kelly
--Data Science & Systems Lab (DASSL)
--https://dassl.github.io/

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.

CREATE VIEW classdb.User AS
SELECT RoleName, FullName, SchemaName, ExtraInfo,
(SELECT CASE WHEN ClassDB.IsMember(User_t.RoleName , 'classdb_instructor') THEN TRUE ELSE FALSE END) AS IsInstructor, --True if user is instructor
(SELECT CASE WHEN ClassDB.IsMember(User_t.RoleName , 'classdb_student') THEN TRUE ELSE FALSE END) AS IsStudent, --True if user is student
(SELECT CASE WHEN ClassDB.IsMember(User_t.RoleName , 'classdb_dbmanager') THEN TRUE ELSE FALSE END) AS IsDBManager, --True if user is DBManager
(SELECT CASE WHEN IsInstructor OR IsStudent OR IsDBManager THEN TRUE ELSE FALSE END) AS HasClassDBRole, --True if user is instructor, student, or DBManager
(SELECT COUNT(*) FROM classdb.DDLActivity WHERE RoleName = User_t.RoleName) AS DDLCount, --The amount of DDLs the user has executed
(SELECT DDLObject FROM classdb.DDLActivity WHERE RoleName = User_t.RoleName ORDER BY StatementStartedAtUTC DESC LIMIT 1) AS LastDDLObject, --The object that the user last preformed the DDL activity on
(SELECT StatementStartedAtUTC FROM classdb.DDLActivity WHERE RoleName = User_t.RoleName ORDER BY StatementStartedAtUTC DESC LIMIT 1) AS LastDDLActivityAtUTC, --The TIMESTAMP of when the user last preformed a DDL activity
(SELECT COUNT(*) FROM classdb.ConnectionActivity WHERE RoleName = User_t.RoleName) AS connectionCount, --The total amout of times user has connected to ClassDB
(SELECT AcceptedAtUTC FROM classdb.ConnectionActivity WHERE RoleName = User_t.RoleName ORDER BY AcceptedAtUTC DESC LIMIT 1) AS LastConnectionAtUTC --A TIMESTAMP of the last connection the User had to ClassDB
FROM classdb.User_t;
