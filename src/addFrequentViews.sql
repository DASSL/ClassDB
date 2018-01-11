--addFrequentViews.sql - ClassDB

--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab (DASSL)
--https://dassl.github.io/

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


BEGIN TRANSACTION;

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
CREATE OR REPLACE VIEW ClassDB.StudentActivityAll AS
(
  SELECT UserName, DDLCount, LastDDLObject,
         ClassDB.changeTimeZone(LastDDLActivityAtUTC) LastDDLActivityAt,
         ConnectionCount, ClassDB.changeTimeZone(LastConnectionAtUTC) LastConnectionAt
  FROM ClassDB.Student
  ORDER BY UserName
);

REVOKE ALL PRIVILEGES ON ClassDB.StudentActivityAll FROM PUBLIC;
ALTER VIEW ClassDB.studentActivityAll OWNER TO ClassDB;
GRANT SELECT ON ClassDB.StudentActivityAll TO ClassDB_Instructor;

--This view shows the activity of all students in the student table, ommiting any
-- user-identifiable information. This view is only usable by instructors
CREATE OR REPLACE VIEW ClassDB.StudentActivityAnon AS
(
   SELECT DDLCount, LastDDLObject, LastDDLActivityAt,
          ConnectionCount, LastConnectionAt
   FROM ClassDB.StudentActivityAll
   ORDER BY ConnectionCount
);

REVOKE ALL PRIVILEGES ON ClassDB.StudentActivityAnon FROM PUBLIC;
ALTER VIEW ClassDB.studentActivityAnon OWNER TO ClassDB;
GRANT SELECT ON ClassDB.StudentActivityAnon TO ClassDB_Instructor;

--This view shows all tables and views currently owned by by students. Note that
-- this is accomplished by listing all tables/views in student schemas. This view is
-- only accessible by instructors.
CREATE OR REPLACE VIEW ClassDB.StudentTable AS
(
  SELECT table_schema, table_name, table_type
  FROM information_schema.tables
  JOIN ClassDB.Student ON table_schema = ClassDB.getSchemaName(UserName)
  ORDER BY table_schema
);

REVOKE ALL PRIVILEGES ON ClassDB.StudentTable FROM PUBLIC;
ALTER VIEW ClassDB.StudentTable OWNER TO ClassDB;
GRANT SELECT ON ClassDB.StudentTable TO ClassDB_Instructor;

--This view lists the current number of tables and views owned by each student. This
-- view is only accessible by instructors.
CREATE OR REPLACE VIEW ClassDB.StudentTableCount AS
(
  SELECT table_schema, COUNT(*)
  FROM information_schema.tables
  JOIN ClassDB.Student ON table_schema = ClassDB.getSchemaName(UserName)
  GROUP BY table_schema
  ORDER BY table_schema
);

REVOKE ALL PRIVILEGES ON ClassDB.StudentTableCount FROM PUBLIC;
ALTER VIEW ClassDB.StudentTableCount OWNER TO ClassDB;
GRANT SELECT ON ClassDB.StudentTableCount TO ClassDB_Instructor;


--This function gets the user activity summary for a given user. This includes their latest
-- DDL and connection activity, as well as their total number of DDL and Connection events
CREATE OR REPLACE FUNCTION ClassDB.getUserActivitySummary(userName ClassDB.IDNameDomain
   DEFAULT SESSION_USER::ClassDB.IDNameDomain)
RETURNS TABLE
(
   DDLCount BIGINT, LastDDLObject VARCHAR(256),
   LastDDLActivityAt TIMESTAMP, ConnectionCount BIGINT, LastConnectionAt TIMESTAMP
) AS
$$
   SELECT ddlcount, lastddlobject, LastDDLActivityAt,
          connectioncount, LastConnectionAt
   FROM ClassDB.StudentActivityAll
   WHERE username = ClassDB.foldPgID($1);
$$ LANGUAGE sql
   STABLE
   SECURITY DEFINER;

REVOKE ALL ON FUNCTION ClassDB.getUserActivitySummary(ClassDB.IDNameDomain) FROM PUBLIC;
ALTER FUNCTION ClassDB.getUserActivitySummary(ClassDB.IDNameDomain) OWNER TO ClassDB;
GRANT EXECUTE ON FUNCTION ClassDB.getUserActivitySummary(ClassDB.IDNameDomain) TO ClassDB_Instructor;

--This function lists the most recent activity of the executing user. This view is accessible
-- by both students and instructors, which requires that it be placed in the public schema.
-- Additionally, it is implemented as a function so that students are able to indirectly
-- access ClassDB.User.
CREATE OR REPLACE FUNCTION public.getMyActivitySummary()
RETURNS TABLE
(
   DDLCount BIGINT, LastDDLObject VARCHAR(256),
   LastDDLActivityAt TIMESTAMP, ConnectionCount BIGINT, LastConnectionAt TIMESTAMP
) AS
$$
   SELECT ddlcount, lastddlobject,  lastddlactivityat,
          connectioncount, LastConnectionAt
   FROM ClassDB.getUserActivitySummary();
$$ LANGUAGE sql
   STABLE
   SECURITY DEFINER;

ALTER FUNCTION public.getMyActivitySummary() OWNER TO ClassDB;

--Proxy view for public.getMyActivitySummary(). Designed to make access easier for students
CREATE OR REPLACE VIEW public.MyActivitySummary AS
(
   SELECT ddlcount, lastddlobject,  lastddlactivityat,
          connectioncount, lastconnectionat
   FROM public.getMyActivitySummary()
);

ALTER VIEW public.MyActivitySummary OWNER TO ClassDB;
GRANT SELECT ON public.MyActivitySummary TO PUBLIC;


--This function returns all DDL activity for a specified user
CREATE OR REPLACE FUNCTION ClassDB.getUserDDLActivity(userName ClassDB.IDNameDomain
   DEFAULT SESSION_USER::ClassDB.IDNameDomain)
RETURNS TABLE
(
   StatementStartedAt TIMESTAMP, DDLOperation VARCHAR, DDLObject VARCHAR(256)
) AS
$$
   SELECT ClassDB.changeTimeZone(StatementStartedAtUTC), DDLOperation, DDLObject
   FROM ClassDB.DDLActivity
   WHERE username = ClassDB.foldPgID($1);
$$ LANGUAGE sql
   STABLE
   SECURITY DEFINER;

REVOKE ALL ON FUNCTION ClassDB.getUserDDLActivity(ClassDB.IDNameDomain) FROM PUBLIC;
ALTER FUNCTION ClassDB.getUserDDLActivity(ClassDB.IDNameDomain) OWNER TO ClassDB;
GRANT EXECUTE ON FUNCTION ClassDB.getUserDDLActivity(ClassDB.IDNameDomain) TO ClassDB_Instructor;

--This function returns all DDL activity for the current user
CREATE OR REPLACE FUNCTION public.getMyDDLActivity()
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

ALTER FUNCTION public.getMyDDLActivity() OWNER TO ClassDB;

--This view wraps getMyDDLActivity() for easier student access
CREATE OR REPLACE VIEW public.MyDDLActivity AS
(
   SELECT StatementStartedAt, DDLOperation, DDLObject
   FROM public.getMyDDLActivity()
);

ALTER VIEW public.MyDDLActivity OWNER TO ClassDB;
GRANT SELECT ON public.MyDDLActivity TO PUBLIC;


--This function returns all connection activity for a specified user
CREATE OR REPLACE FUNCTION ClassDB.getUserConnectionActivity(userName ClassDB.IDNameDomain
   DEFAULT SESSION_USER::ClassDB.IDNameDomain)
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

REVOKE ALL ON FUNCTION ClassDB.getUserConnectionActivity(ClassDB.IDNameDomain) FROM PUBLIC;
ALTER FUNCTION ClassDB.getUserConnectionActivity(ClassDB.IDNameDomain) OWNER TO ClassDB;
GRANT EXECUTE ON FUNCTION ClassDB.getUserConnectionActivity(ClassDB.IDNameDomain) TO ClassDB_Instructor;

--This function returns all connection activity for the current user
CREATE OR REPLACE FUNCTION public.getMyConnectionActivity()
RETURNS TABLE
(
   AcceptedAt TIMESTAMP
) AS
$$
   SELECT AcceptedAt
   FROM ClassDB.getUserConnectionActivity()
$$ LANGUAGE sql
   STABLE
   SECURITY DEFINER;

ALTER FUNCTION public.getMyConnectionActivity() OWNER TO ClassDB;

--This view wraps getMyConnectionActivity for easier student access
CREATE OR REPLACE VIEW public.MyConnectionActivity AS
(
   SELECT AcceptedAt
   FROM public.getMyConnectionActivity()
);

ALTER VIEW public.MyConnectionActivity OWNER TO ClassDB;
GRANT SELECT ON public.MyConnectionActivity TO PUBLIC;


--This function returns all activity for a specified user
CREATE OR REPLACE FUNCTION ClassDB.getUserActivity(userName ClassDB.IDNameDomain
   DEFAULT SESSION_USER::ClassDB.IDNameDomain)
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

REVOKE ALL ON FUNCTION ClassDB.getUserActivity(ClassDB.IDNameDomain) FROM PUBLIC;
ALTER FUNCTION ClassDB.getUserActivity(ClassDB.IDNameDomain) OWNER TO ClassDB;
GRANT EXECUTE ON FUNCTION ClassDB.getUserActivity(ClassDB.IDNameDomain) TO ClassDB_Instructor;

--This view returns all activity for the current user
CREATE OR REPLACE FUNCTION public.getMyActivity()
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

ALTER FUNCTION public.getMyActivity() OWNER TO ClassDB;

--This view wraps getMyActivity() for easier student access
CREATE OR REPLACE VIEW public.MyActivity AS
(
   SELECT ActivityAt, ActivityType, DDLOperation, DDLObject
   FROM public.getMyActivity()
);

ALTER VIEW public.MyActivity OWNER TO ClassDB;
GRANT SELECT ON public.MyActivity TO PUBLIC;

COMMIT;
