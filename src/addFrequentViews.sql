--addFrequentViews.sql - ClassDB

--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab (DASSL), dassl.github.io

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.

--This script should be run as either a superuser or a user with write access
-- to the ClassDB and PUBLIC schemas

--This script should be run in every database to which ClassDB is to be added
-- it should be run after running addUserMgmt.sql

--This script creates several objects (we colletively refer to them as views) to
-- display summary data related to student activity in the current ClassDB database.
-- Views that are accessible to students and require access to ClassDB.User are
-- implmemted as functions. This allows the views to access the ClassDB schema
-- though students cannot directly access the schema.
-- These views pull data from both the ClassDB student table and info schema.

--Make sure the current user has sufficient privilege to run this script
-- privileges required: superuser
DO
$$
BEGIN
   IF NOT ClassDB.isSuperUser() THEN
      RAISE EXCEPTION 'Insufficient privileges: script must be run as a user with'
                      ' superuser privileges';
   END IF;
END
$$;


--This view shows the activity summary of all students in the User table. This view
-- is only usable by instructors
DROP VIEW IF EXISTS ClassDB.StudentActivityAll;
CREATE VIEW ClassDB.StudentActivityAll AS
(
  SELECT UserName, ClassDB.changeTimeZone(LastDDLActivityAt), LastDDLOperation, LastDDLObject,
         DDLCount, ClassDB.changeTimeZone(LastConnectionAt), ConnectionCount
  FROM ClassDB.User
  ORDER BY UserName
);

REVOKE ALL PRIVILEGES
  ON ClassDB.StudentActivityAll
  FROM PUBLIC;

ALTER VIEW
   ClassDB.studentActivityAll
   OWNER TO ClassDB;

GRANT SELECT ON
   ClassDB.StudentActivityAll
   TO ClassDB_Instructor;

--This view shows the activity of all students in the student table, ommiting any
-- user-identifiable information. This view is only usable by instructors
DROP VIEW IF EXISTS ClassDB.StudentActivityAnon;
CREATE VIEW ClassDB.StudentActivityAnon AS
(
   SELECT ClassDB.changeTimeZone(LastDDLActivityAt), LastDDLOperation, LastDDLObject,
          DDLCount, ClassDB.changeTimeZone(LastConnectionAt), ConnectionCount
   FROM ClassDB.User
   ORDER BY ConnectionCount
);

REVOKE ALL PRIVILEGES
  ON ClassDB.StudentActivityAnon
  FROM PUBLIC;

ALTER VIEW
   ClassDB.studentActivityAnon
   OWNER TO ClassDB;

GRANT SELECT ON
   ClassDB.StudentActivityAnon
   TO ClassDB_Instructor;

--This view shows all tables and views currently owned by by students. Note that
-- this is accomplished by listing all tables/views in student schemas. This view is
-- only accessible by instructors.
DROP VIEW IF EXISTS ClassDB.StudentTable;
CREATE VIEW ClassDB.StudentTable AS
(
  SELECT table_schema, table_name, table_type
  FROM information_schema.tables JOIN ClassDB.User ON table_schema = UserName
  ORDER BY table_schema
);

REVOKE ALL PRIVILEGES
  ON ClassDB.StudentTable
  FROM PUBLIC;

ALTER VIEW
   ClassDB.StudentTable
   OWNER TO ClassDB;

GRANT SELECT ON
   ClassDB.StudentTable
   TO ClassDB_Instructor;

--This view lists the current number of tables and views owned by each student. This
-- view is only accessible by instructors.
DROP VIEW IF EXISTS ClassDB.StudentTableCount;
CREATE VIEW ClassDB.StudentTableCount AS
(
  SELECT table_schema, COUNT(*)
  FROM information_schema.tables JOIN ClassDB.User ON table_schema = UserName
  GROUP BY table_schema
  ORDER BY table_schema
);

REVOKE ALL PRIVILEGES
  ON ClassDB.StudentTableCount
  FROM PUBLIC;

ALTER VIEW
   ClassDB.StudentTableCount
   OWNER TO ClassDB;

GRANT SELECT ON
   ClassDB.StudentTableCount
   TO ClassDB_Instructor;


CREATE OR REPLACE FUNCTION ClassDB.getUserActivitySummary(userName VARCHAR(63) DEFAULT session_user)
RETURNS TABLE
(
   LastDDLActivityAt TIMESTAMP, LastDDLOperation VARCHAR(64), LastDDLObject VARCHAR(256),
   DDLCount INT, LastConnection TIMESTAMP, ConnectionCount INT
) AS
$$
   SELECT ClassDB.changeTimeZone(LastDDLActivityAtUTC), lastddloperation, lastddlobject, ddlcount,
          ClassDB.changeTimeZone(LastConnectionAtUTC), connectioncount
   FROM ClassDB.StudentActivityAll
   WHERE username = ClassDB.foldPgID($1);
$$ LANGUAGE sql
   STABLE
   SECURITY DEFINER;

REVOKE ALL ON FUNCTION
   ClassDB.getUserActivitySummary(VARCHAR(63))
   FROM PUBLIC;

ALTER FUNCTION
   ClassDB.getUserActivitySummary(VARCHAR(63))
   OWNER TO ClassDB;

GRANT EXECUTE ON FUNCTION
   ClassDB.getUserActivitySummary(VARCHAR(63))
TO ClassDB_Instructor;

--This function lists the most recent activity of the executing user. This view is accessible
-- by both students and instructors, which requires that it be placed in the public schema.
-- Additionally, it is implemented as a function so that students are able to indirectly
-- access ClassDB.User.
CREATE OR REPLACE FUNCTION Public.getMyActivitySummary()
RETURNS TABLE
(
   LastDDLActivity TIMESTAMP, LastDDLOperation VARCHAR(64), LastDDLObject VARCHAR(256),
   DDLCount INT, LastConnection TIMESTAMP, ConnectionCount INT
) AS
$$
   SELECT lastddlactivity, lastddloperation, lastddlobject, ddlcount,
          lastconnection, connectioncount
   FROM ClassDB.getUserActivitySummary();
$$ LANGUAGE sql
   STABLE
   SECURITY DEFINER;

REVOKE ALL ON FUNCTION
   Public.getMyActivitySummary()
   FROM PUBLIC;

ALTER FUNCTION
   Public.getMyActivitySummary()
   OWNER TO ClassDB;

GRANT EXECUTE ON FUNCTION
   Public.getMyActivitySummary()
TO ClassDB_Instructor, ClassDB_DBManager, ClassDB_Student;

CREATE VIEW Public.MyActivitySummary AS
(
   SELECT lastddlactivity, lastddloperation, lastddlobject, ddlcount, lastconnection,
          connectioncount
   FROM Public.getMyActivitySummary()
);

REVOKE ALL PRIVILEGES
   Public.MyActivitySummary
   FROM Public;

ALTER VIEW
   Public.MyActivitySummary
   OWNER TO ClassDB;

GRANT SELECT ON
   Public.MyActivitySummary
   TO Public;


--This function returns all DDL activity for a specified user
CREATE OR REPLACE FUNCTION ClassDB.getUserDDLActivity(userName VARCHAR(63) DEFAULT session_user)
RETURNS TABLE
(
   StatementStartedAt TIMESTAMP, DDLOperation VARCHAR(64), DDLObject VARCHAR(256)
) AS
$$
   SELECT ClassDB.changeTimeZone(StatementStartedAtUTC), DDLOperation, DDLObject
   FROM ClassDB.DDLActivity
   WHERE username = ClassDB.foldPgID($1);
$$ LANGUAGE sql
   STABLE
   SECURITY DEFINER;

REVOKE ALL ON FUNCTION
   ClassDB.getUserDDLActivity(VARCHAR(63))
   FROM PUBLIC;

ALTER FUNCTION
   ClassDB.getUserDDLActivity(VARCHAR(63))
   OWNER TO ClassDB;

GRANT EXECUTE ON FUNCTION
   ClassDB.getUserDDLActivity(VARCHAR(63))
TO ClassDB_Instructor;

--
CREATE OR REPLACE FUNCTION Public.getMyDDLActivity()
RETURNS TABLE
(
   StatementStartedAt TIMESTAMP, DDLOperation VARCHAR(64), DDLObject VARCHAR(256)
) AS
$$
   SELECT StatementStartedAt, DDLOperation, DDLObject
   FROM ClassDB.getUserDDLActivity();
$$ LANGUAGE sql
   STABLE
   SECURITY DEFINER;

REVOKE ALL ON FUNCTION
   Public.getMyDDLActivity()
   FROM PUBLIC;

ALTER FUNCTION
   Public.getMyDDLActivity()
   OWNER TO ClassDB;

GRANT EXECUTE ON FUNCTION
   Public.getMyDDLActivity()
TO ClassDB_Instructor, ClassDB_DBManager, ClassDB_Student;

CREATE VIEW Public.MyDDLActivity AS
(
   SELECT StatementStartedAt, DDLOperation, DDLObject
   FROM Public.getMyDDLActivity()
);

REVOKE ALL PRIVILEGES
   Public.MyDDLActivity
   FROM Public;

ALTER VIEW
   Public.MyDDLActivity
   OWNER TO ClassDB;

GRANT SELECT ON
   Public.MyDDLActivity
   TO Public;


--This function returns all connection activity for a specified user
CREATE OR REPLACE FUNCTION ClassDB.getUserConnectionActivity(userName VARCHAR(63) DEFAULT session_user)
RETURNS TABLE
(
   AcceptedAt TIMESTAMP
) AS
$$
   SELECT ClassDB.changeTimeZone(AcceptedAtUTC)
   FROM ClassDB.ConnectionActivity
   WHERE username = ClassDB.foldPgID($1);
$$ LANGUAGE sql
   STABLE
   SECURITY DEFINER;

REVOKE ALL ON FUNCTION
   ClassDB.getUserConnectionActivity(VARCHAR(63))
   FROM PUBLIC;

ALTER FUNCTION
   ClassDB.getUserConnectionActivity(VARCHAR(63))
   OWNER TO ClassDB;

GRANT EXECUTE ON FUNCTION
   ClassDB.getUserConnectionActivity(VARCHAR(63))
TO ClassDB_Instructor;

--
CREATE OR REPLACE FUNCTION Public.getMyConnectionActivity()
RETURNS TABLE
(
   AcceptedAt TIMESTAMP
) AS
$$
   SELECT ClassDB.changeTimeZone(AcceptedAtUTC)
   FROM ClassDB.getUserConnectionActivity()
$$ LANGUAGE sql
   STABLE
   SECURITY DEFINER;

REVOKE ALL ON FUNCTION
   Public.getMyConnectionActivity()
   FROM PUBLIC;

ALTER FUNCTION
   Public.getMyConnectionActivity()
   OWNER TO ClassDB;

GRANT EXECUTE ON FUNCTION
   Public.getMyConnectionActivity()
TO ClassDB_Instructor, ClassDB_DBManager, ClassDB_Student;

CREATE VIEW Public.MyConnectionActivity AS
(
   SELECT AcceptedAt
   FROM Public.getMyConnectionActivity()
);

REVOKE ALL PRIVILEGES
   Public.MyConnectionActivity
   FROM Public;

ALTER VIEW
   Public.MyConnectionActivity
   OWNER TO ClassDB;

GRANT SELECT ON
   Public.MyConnectionActivity
   TO Public;

--This function returns all activity for a specified user
CREATE OR REPLACE FUNCTION ClassDB.getUserActivity(userName VARCHAR(63) DEFAULT session_user)
RETURNS TABLE
(
   ActivityAt TIMESTAMP, ActivityType VARCHAR(10), DDLOperation VARCHAR(64), DDLObject VARCHAR(256)
) AS
$$
   SELECT StatementStartedAt, 'DDL', DDLOperation, DDLObject
   FROM ClassDB.getUserDDLActivity($1)
   UNION ALL
   SELECT AcceptedAt, 'Connection', NULL, NULL
   FROM ClassDB.getUserConnectionActivity($1)
$$ LANGUAGE sql
   STABLE
   SECURITY DEFINER;

REVOKE ALL ON FUNCTION
   ClassDB.getUserActivity(VARCHAR(63))
   FROM PUBLIC;

ALTER FUNCTION
   ClassDB.getUserActivity(VARCHAR(63))
   OWNER TO ClassDB;

GRANT EXECUTE ON FUNCTION
   ClassDB.getUserActivity(VARCHAR(63))
TO ClassDB_Instructor;

--
CREATE OR REPLACE FUNCTION Public.getMyActivity()
RETURNS TABLE
(
   ActivityAt TIMESTAMP, ActivityType VARCHAR(10), DDLOperation VARCHAR(64), DDLObject VARCHAR(256)
) AS
$$
   SELECT ActivityAt, ActivityType, DDLOperation, DDLObject
   FROM ClassDB.getUserActivity();
$$ LANGUAGE sql
   STABLE
   SECURITY DEFINER;

REVOKE ALL ON FUNCTION
   Public.getMyActivity()
   FROM PUBLIC;

ALTER FUNCTION
   Public.getMyActivity()
   OWNER TO ClassDB;

GRANT EXECUTE ON FUNCTION
   Public.getMyActivity()
TO ClassDB_Instructor, ClassDB_DBManager, ClassDB_Student;

CREATE VIEW Public.MyActivity AS
(
   SELECT ActivityAt, ActivityType, DDLOperation, DDLObject
   FROM ClassDB.getUserActivity();
);

REVOKE ALL PRIVILEGES
   Public.MyActivity
   FROM Public;

ALTER VIEW
   Public.MyActivity
   OWNER TO ClassDB;

GRANT SELECT ON
   Public.MyActivity
   TO Public;
