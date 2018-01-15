--addFrequentViewsReco.sql - ClassDB

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

--This script creates several objects (we collectively refer to them as views) to
-- display summary data related to student activity in the current database.
-- Views that are accessible to students and require access to ClassDB.User are
-- implemented as functions. This allows the views to access the ClassDB schema
-- though students cannot directly access the schema.


START TRANSACTION;

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


--This view returns all tables and views owned by student users
-- uses pg_catalog instead of INFORMATION_SCHEMA because the latter does not
-- support the case where a table owner and the containing schema's owner are
-- different.
-- does not use view ClassDB.Student for efficiency: that view computes many
-- things not required here, and using that would require a join
-- this view is accessible only to instructors.
CREATE OR REPLACE VIEW ClassDB.StudentTable AS
(
  SELECT tableowner UserName, schemaname SchemaName,
         tablename TableName, 'TABLE' TableType
  FROM pg_catalog.pg_tables
  WHERE ClassDB.isStudent(tableowner::ClassDB.IDNameDomain)

  UNION

  SELECT viewowner, schemaname, viewname, 'VIEW'
  FROM pg_catalog.pg_views
  WHERE ClassDB.isStudent(viewowner::ClassDB.IDNameDomain)
);

ALTER VIEW ClassDB.StudentTable OWNER TO ClassDB;
REVOKE ALL PRIVILEGES ON ClassDB.StudentTable FROM PUBLIC;
GRANT SELECT ON ClassDB.StudentTable TO ClassDB_Instructor;



--This view returns the number of tables and views each student user owns
-- this view is accessible only to instructors.
CREATE OR REPLACE VIEW ClassDB.StudentTableCount AS
(
  SELECT UserName, COUNT(*) TableCount
  FROM ClassDB.StudentTable
  GROUP BY UserName
  ORDER BY UserName
);

ALTER VIEW ClassDB.StudentTableCount OWNER TO ClassDB;
REVOKE ALL PRIVILEGES ON ClassDB.StudentTableCount FROM PUBLIC;
GRANT SELECT ON ClassDB.StudentTableCount TO ClassDB_Instructor;



--This function gets the user activity summary for a given user. A value of NULL will
-- return activity summaries for all ClassDB users. This includes their latest
-- DDL and connection activity, as well as their total number of DDL and Connection events
CREATE OR REPLACE FUNCTION ClassDB.getUserActivitySummary(userName ClassDB.IDNameDomain
   DEFAULT NULL)
RETURNS TABLE
(
   UserName ClassDB.IDNameDomain, DDLCount BIGINT, LastDDLOperation VARCHAR,
   LastDDLObject VARCHAR, LastDDLActivityAt TIMESTAMP, ConnectionCount BIGINT,
   LastConnectionAt TIMESTAMP
) AS
$$
   --We COALESCE the input user name with '%' so that the function will either match
   -- a single user name, or all user names
   SELECT UserName, ddlcount, LastDDLOperation, lastddlobject,
          ClassDB.changeTimeZone(LastDDLActivityAtUTC),
          connectioncount, ClassDB.changeTimeZone(LastConnectionAtUTC)
   FROM ClassDB.User
   WHERE username LIKE COALESCE(ClassDB.foldPgID($1), '%');
$$ LANGUAGE sql
   STABLE
   SECURITY DEFINER;

ALTER FUNCTION ClassDB.getUserActivitySummary(ClassDB.IDNameDomain) OWNER TO ClassDB;
REVOKE ALL ON FUNCTION ClassDB.getUserActivitySummary(ClassDB.IDNameDomain) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ClassDB.getUserActivitySummary(ClassDB.IDNameDomain) TO ClassDB_Instructor;



--This function gets the user activity summary for a given student. A value of NULL will
-- return activity summaries for all students. This includes their latest
-- DDL and connection activity, as well as their total number of DDL and Connection events
CREATE OR REPLACE FUNCTION ClassDB.getStudentActivitySummary(userName ClassDB.IDNameDomain
   DEFAULT NULL)
RETURNS TABLE
(
   UserName ClassDB.IDNameDomain, DDLCount BIGINT, LastDDLOperation VARCHAR,
   LastDDLObject VARCHAR, LastDDLActivityAt TIMESTAMP, ConnectionCount BIGINT,
   LastConnectionAt TIMESTAMP
) AS
$$
   SELECT UserName, DDLCount, LastDDLOperation, LastDDLObject, LastDDLActivityAt,
          ConnectionCount, LastConnectionAt
   FROM ClassDB.getUserActivitySummary($1)
   WHERE ClassDB.isStudent(UserName);
$$ LANGUAGE sql
   STABLE
   SECURITY DEFINER;

ALTER FUNCTION ClassDB.getStudentActivitySummary(ClassDB.IDNameDomain) OWNER TO ClassDB;
REVOKE ALL ON FUNCTION ClassDB.getStudentActivitySummary(ClassDB.IDNameDomain) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ClassDB.getStudentActivitySummary(ClassDB.IDNameDomain) TO ClassDB_Instructor;



--A view that wraps getStudentActivitySummary() for easier access
CREATE OR REPLACE VIEW ClassDB.StudentActivitySummary AS
(
   SELECT UserName, DDLCount, LastDDLOperation, LastDDLObject, LastDDLActivityAt,
          ConnectionCount, LastConnectionAt
   FROM   ClassDB.getStudentActivitySummary()
);

ALTER VIEW ClassDB.StudentActivitySummary OWNER TO ClassDB;
REVOKE ALL PRIVILEGES ON ClassDB.StudentActivitySummary FROM PUBLIC;
GRANT SELECT ON ClassDB.StudentActivitySummary TO ClassDB_Instructor;



-- return activity summaries for all students. This includes their latest
-- DDL and connection activity, as well as their total number of DDL and
-- Connection events
CREATE OR REPLACE FUNCTION ClassDB.getStudentActivitySummaryAnon(
   userName ClassDB.IDNameDomain DEFAULT NULL)
RETURNS TABLE
(
   DDLCount BIGINT, LastDDLOperation VARCHAR,
   LastDDLObject VARCHAR, LastDDLActivityAt TIMESTAMP, ConnectionCount BIGINT,
   LastConnectionAt TIMESTAMP
) AS
$$
   SELECT DDLCount, LastDDLOperation,
          SUBSTRING(LastDDLObject, POSITION('.' IN lastddlobject)+1)  LastDDLObject,
          LastDDLActivityAt, ConnectionCount, LastConnectionAt
   FROM ClassDB.getStudentActivitySummary($1)
$$ LANGUAGE sql
   STABLE
   SECURITY DEFINER;

ALTER FUNCTION ClassDB.getStudentActivitySummaryAnon(ClassDB.IDNameDomain) OWNER TO ClassDB;
REVOKE ALL ON FUNCTION ClassDB.getStudentActivitySummaryAnon(ClassDB.IDNameDomain) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ClassDB.getStudentActivitySummaryAnon(ClassDB.IDNameDomain) TO ClassDB_Instructor;



--A view that wraps getStudentActivitySummaryAnon() for easier access
CREATE OR REPLACE VIEW ClassDB.StudentActivitySummaryAnon AS
(
   SELECT DDLCount, LastDDLOperation, LastDDLObject, LastDDLActivityAt,
          ConnectionCount, LastConnectionAt
   FROM   ClassDB.getStudentActivitySummary()
);

ALTER VIEW ClassDB.StudentActivitySummaryAnon OWNER TO ClassDB;
REVOKE ALL PRIVILEGES ON ClassDB.StudentActivitySummaryAnon FROM PUBLIC;
GRANT SELECT ON ClassDB.StudentActivitySummaryAnon TO ClassDB_Instructor;



--This function lists the most recent activity of the executing user. This view is accessible
-- by both students and instructors, which requires that it be placed in the public schema.
-- Additionally, it is implemented as a function so that students are able to indirectly
-- access ClassDB.User.
CREATE OR REPLACE FUNCTION public.getMyActivitySummary()
RETURNS TABLE
(
   DDLCount BIGINT, LastDDLOperation VARCHAR, LastDDLObject VARCHAR,
   LastDDLActivityAt TIMESTAMP, ConnectionCount BIGINT, LastConnectionAt TIMESTAMP
) AS
$$
   SELECT ddlcount, LastDDLOperation, lastddlobject,  lastddlactivityat,
          connectioncount, LastConnectionAt
   FROM ClassDB.getUserActivitySummary(SESSION_USER::ClassDB.IDNameDomain);
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

ALTER FUNCTION ClassDB.getUserDDLActivity(ClassDB.IDNameDomain) OWNER TO ClassDB;
REVOKE ALL ON FUNCTION ClassDB.getUserDDLActivity(ClassDB.IDNameDomain) FROM PUBLIC;
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

ALTER FUNCTION ClassDB.getUserConnectionActivity(ClassDB.IDNameDomain) OWNER TO ClassDB;
REVOKE ALL ON FUNCTION ClassDB.getUserConnectionActivity(ClassDB.IDNameDomain) FROM PUBLIC;
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

ALTER FUNCTION ClassDB.getUserActivity(ClassDB.IDNameDomain) OWNER TO ClassDB;
REVOKE ALL ON FUNCTION ClassDB.getUserActivity(ClassDB.IDNameDomain) FROM PUBLIC;
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
