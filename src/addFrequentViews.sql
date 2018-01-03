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
-- Views that are accessible to students and require access to ClassDB.student are
-- implmemted as functions. This allows the views to access the ClassDB schema Steven
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

DROP FUNCTION IF EXISTS ClassDB.getUserActivitySummary(targetUserName VARCHAR(63));
CREATE FUNCTION ClassDB.getUserActivitySummary(targetUserName VARCHAR(63) DEFAULT session_user)
RETURNS TABLE
(
   UserName VARCHAR(63), LastDDLActivity TIMESTAMP, LastDDLOperation VARCHAR(64),
   LastDDLObject VARCHAR(256), DDLCount INT, LastConnection TIMESTAMP, ConnectionCount INT
) AS
$$
   SELECT username, lastddlactivity, lastddloperation, lastddlobject, ddlcount,
          lastconnection, connectioncount
   FROM classdb.StudentActivityAll
   WHERE username = targetUserName;
$$ LANGUAGE sql
   SECURITY DEFINER;

REVOKE ALL ON FUNCTION
   ClassDB.getUserActivitySummary()
   FROM PUBLIC;

ALTER FUNCTION
   ClassDB.getUserActivitySummary()
   OWNER TO ClassDB;

GRANT EXECUTE ON FUNCTION
   ClassDB.getUserActivitySummary()
TO ClassDB_Instructor;


--This function lists the most recent activity of the executing user. This view is accessible
-- by both students and instructors, which requires that it be placed in the public schema.
-- Additionally, it is implemented as a function so that students are able to indirectly
-- access ClassDB.student.
DROP FUNCTION IF EXISTS public.getMyActivitySummary();
CREATE FUNCTION public.getMyActivitySummary()
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
   SECURITY DEFINER;

REVOKE ALL ON FUNCTION
   public.getMyActivitySummary()
   FROM PUBLIC;

ALTER FUNCTION
   public.getMyActivitySummary()
   OWNER TO ClassDB;

GRANT EXECUTE ON FUNCTION
   public.getMyActivitySummary()
TO ClassDB_Instructor, ClassDB_DBManager, ClassDB_Student;


DROP VIEW IF EXISTS Public.MyActivitySummary;
CREATE VIEW Public.MyActivitySummary AS
(
   SELECT lastddlactivity, lastddloperation, lastddlobject, ddlcount, lastconnection,
          connectioncount
   FROM Public.getMyActivitySummary();
);

--This view shows the activity of all students in the student table. This view
-- is only usable by instructors
DROP VIEW IF EXISTS ClassDB.StudentActivityAll;
CREATE VIEW ClassDB.StudentActivityAll AS
(
  SELECT username, lastddlactivity, lastddloperation, lastddlobject, ddlcount,
         lastconnection, connectioncount
  FROM ClassDB.student
  ORDER BY username
);

REVOKE ALL PRIVILEGES
  ON ClassDB.StudentActivityAll
  FROM PUBLIC;

ALTER VIEW ClassDB.studentActivityAll
  OWNER TO ClassDB;

GRANT SELECT ON ClassDB.StudentActivityAll
  TO ClassDB_Instructor;

--This view shows the activity of all students in the student table, ommiting any
-- user-identifiable information. This view is only usable by instructors
DROP VIEW IF EXISTS ClassDB.StudentActivityAnon;
CREATE VIEW ClassDB.StudentActivityAnon AS
(
  SELECT lastddlactivity, lastddloperation, SUBSTRING(lastddlobject, POSITION('.' IN lastddlobject)+1)
         lastddlobject, ddlcount, lastconnection, connectioncount
  FROM ClassDB.student
  ORDER BY connectioncount
);

REVOKE ALL PRIVILEGES
  ON ClassDB.StudentActivityAnon
  FROM PUBLIC;

ALTER VIEW ClassDB.studentActivityAnon
  OWNER TO ClassDB;

GRANT SELECT ON ClassDB.StudentActivityAnon
  TO ClassDB_Instructor;

--This view shows all tables and views currently owned by by students. Note that
-- this is accomplished by listing all tables/views in student schemas. This view is
-- only accessible by instructors.
DROP VIEW IF EXISTS ClassDB.StudentTable;
CREATE VIEW ClassDB.StudentTable AS
(
  SELECT table_schema, table_name, table_type
  FROM information_schema.tables JOIN ClassDB.student ON table_schema = username
  ORDER BY table_schema
);

REVOKE ALL PRIVILEGES
  ON ClassDB.StudentTable
  FROM PUBLIC;

ALTER VIEW ClassDB.StudentTable
  OWNER TO ClassDB;

GRANT SELECT ON ClassDB.StudentTable
  TO ClassDB_Instructor;

--This view lists the current number of tables and views owned by each student. This
-- view is only accessible by instructors.
DROP VIEW IF EXISTS ClassDB.StudentTableCount;
CREATE VIEW ClassDB.StudentTableCount AS
(
  SELECT table_schema, COUNT(*)
  FROM information_schema.tables JOIN ClassDB.student ON table_schema = username
  GROUP BY table_schema
  ORDER BY table_schema
);

REVOKE ALL PRIVILEGES
  ON ClassDB.StudentTableCount
  FROM PUBLIC;

ALTER VIEW ClassDB.StudentTableCount
  OWNER TO ClassDB;

GRANT SELECT ON ClassDB.StudentTableCount
  TO ClassDB_Instructor;
