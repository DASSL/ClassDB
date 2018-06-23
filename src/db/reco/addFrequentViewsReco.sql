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
-- it should be run after running addUserMgmtCore.sql

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



--UPGRADE FROM 2.0 TO 2.1
-- These statements are needed when upgrading ClassDB from 2.0 to 2.1
-- These can be removed in a future version of ClassDB

--Remove functions which have had their return types changed and their dependents
-- We avoid using DROP...CASACDE in case users have created custom objects based on
-- ClassDB objects
DROP VIEW IF EXISTS public.MyActivity;
DROP FUNCTION IF EXISTS public.getMyActivity();

DROP VIEW IF EXISTS ClassDB.StudentActivityAnon;
DROP FUNCTION IF EXISTS ClassDB.getStudentActivityAnon(ClassDB.IDNameDomain);

DROP VIEW IF EXISTS ClassDB.StudentActivity;
DROP FUNCTION IF EXISTS ClassDB.getStudentActivity(ClassDB.IDNameDomain);
DROP FUNCTION IF EXISTS ClassDB.getUserActivity(ClassDB.IDNameDomain);

DROP VIEW IF EXISTS public.MyConnectionActivity;
DROP FUNCTION IF EXISTS public.getMyConnectionActivity();
DROP FUNCTION IF EXISTS ClassDB.getUserConnectionActivity(ClassDB.IDNameDomain);

DROP VIEW IF EXISTS public.MyDDLActivity;
DROP FUNCTION IF EXISTS public.getMyDDLActivity();
DROP FUNCTION IF EXISTS ClassDB.getUserDDLActivity(ClassDB.IDNameDomain);



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

  SELECT ViewOwner, SchemaName, ViewName, 'VIEW'
  FROM pg_catalog.pg_views
  WHERE ClassDB.isStudent(viewowner::ClassDB.IDNameDomain)
  ORDER BY UserName, SchemaName, TableName
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



--This function gets the user activity summary for a given user. A value of NULL
-- will return activity summaries for all ClassDB users. This includes their
-- latest DDL and connection activity, as well as their total number of DDL and
-- Connection events
CREATE OR REPLACE FUNCTION ClassDB.getUserActivitySummary(
   userName ClassDB.IDNameDomain DEFAULT NULL)
RETURNS TABLE
(
   UserName ClassDB.IDNameDomain, DDLCount BIGINT, LastDDLOperation VARCHAR,
   LastDDLObject VARCHAR, LastDDLActivityAt TIMESTAMP, ConnectionCount BIGINT,
   LastConnectionAt TIMESTAMP
) AS
$$
   --We COALESCE the input user name with '%' so that the function will either
   -- match a single user name, or all user names
   SELECT UserName, DDLCount, LastDDLOperation, LastDDLObject,
          ClassDB.changeTimeZone(LastDDLActivityAtUTC) LastDDLActivityAt,
          ConnectionCount, ClassDB.changeTimeZone(LastConnectionAtUTC) LastConnectionAt
   FROM ClassDB.User
   WHERE UserName LIKE COALESCE(ClassDB.foldPgID($1), '%')
   ORDER BY UserName;
$$ LANGUAGE sql
   STABLE
   SECURITY DEFINER;

ALTER FUNCTION ClassDB.getUserActivitySummary(ClassDB.IDNameDomain)
   OWNER TO ClassDB;
REVOKE ALL ON FUNCTION ClassDB.getUserActivitySummary(ClassDB.IDNameDomain)
   FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ClassDB.getUserActivitySummary(ClassDB.IDNameDomain)
   TO ClassDB_Instructor;



--This function gets the user activity summary for a given student. A value of
-- NULL will return activity summaries for all students. This includes their
-- latest DDL and connection activity, as well as their total number of DDL and
-- Connection events
CREATE OR REPLACE FUNCTION ClassDB.getStudentActivitySummary(
   userName ClassDB.IDNameDomain DEFAULT NULL)
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

ALTER FUNCTION ClassDB.getStudentActivitySummary(ClassDB.IDNameDomain)
   OWNER TO ClassDB;
REVOKE ALL ON FUNCTION ClassDB.getStudentActivitySummary(ClassDB.IDNameDomain)
   FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ClassDB.getStudentActivitySummary(ClassDB.IDNameDomain)
   TO ClassDB_Instructor;



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



--Return activity summaries for all students. This includes their latest
-- DDL and connection activity, as well as their total number of DDL and
-- Connection events
CREATE OR REPLACE FUNCTION ClassDB.getStudentActivitySummaryAnon(
   userName ClassDB.IDNameDomain DEFAULT NULL)
RETURNS TABLE
(
   DDLCount BIGINT, LastDDLOperation VARCHAR, LastDDLObject VARCHAR,
   LastDDLActivityAt TIMESTAMP, ConnectionCount BIGINT, LastConnectionAt TIMESTAMP
) AS
$$
   SELECT DDLCount, LastDDLOperation,
          SUBSTRING(LastDDLObject, POSITION('.' IN lastddlobject)+1)  LastDDLObject,
          LastDDLActivityAt, ConnectionCount, LastConnectionAt
   FROM ClassDB.getStudentActivitySummary($1)
$$ LANGUAGE sql
   STABLE
   SECURITY DEFINER;

ALTER FUNCTION ClassDB.getStudentActivitySummaryAnon(ClassDB.IDNameDomain)
   OWNER TO ClassDB;
REVOKE ALL ON FUNCTION ClassDB.getStudentActivitySummaryAnon(ClassDB.IDNameDomain)
   FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ClassDB.getStudentActivitySummaryAnon(ClassDB.IDNameDomain)
   TO ClassDB_Instructor;



--A view that wraps getStudentActivitySummaryAnon() for easier access
CREATE OR REPLACE VIEW ClassDB.StudentActivitySummaryAnon AS
(
   SELECT DDLCount, LastDDLOperation, LastDDLObject, LastDDLActivityAt,
          ConnectionCount, LastConnectionAt
   FROM   ClassDB.getStudentActivitySummaryAnon()
);

ALTER VIEW ClassDB.StudentActivitySummaryAnon OWNER TO ClassDB;
REVOKE ALL PRIVILEGES ON ClassDB.StudentActivitySummaryAnon FROM PUBLIC;
GRANT SELECT ON ClassDB.StudentActivitySummaryAnon TO ClassDB_Instructor;



--This function lists the most recent activity of the executing user. This view
-- is accessible by both students and instructors, which requires that it be
-- placed in the public schema. Additionally, it is implemented as a function
-- so that students are able to indirectly access ClassDB.User.
CREATE OR REPLACE FUNCTION public.getMyActivitySummary()
RETURNS TABLE
(
   DDLCount BIGINT, LastDDLOperation VARCHAR, LastDDLObject VARCHAR,
   LastDDLActivityAt TIMESTAMP, ConnectionCount BIGINT, LastConnectionAt TIMESTAMP
) AS
$$
   SELECT DDLCount, LastDDLOperation, LastDDLOperation,  LastDDLActivityAt,
          ConnectionCount, LastConnectionAt
   FROM ClassDB.getUserActivitySummary(SESSION_USER::ClassDB.IDNameDomain);
$$ LANGUAGE sql
   STABLE
   SECURITY DEFINER;

ALTER FUNCTION public.getMyActivitySummary() OWNER TO ClassDB;



--Proxy view for public.getMyActivitySummary(). Designed to make access easier
-- for students
CREATE OR REPLACE VIEW public.MyActivitySummary AS
(
   SELECT DDLCount, LastDDLObject, LastDDLActivityAt,
          ConnectionCount, LastConnectionAt
   FROM public.getMyActivitySummary()
);

ALTER VIEW public.MyActivitySummary OWNER TO ClassDB;
GRANT SELECT ON public.MyActivitySummary TO PUBLIC;



--This function returns all DDL activity for a specified user. Passing NULL
-- returns data for all users
CREATE OR REPLACE FUNCTION ClassDB.getUserDDLActivity(
   userName ClassDB.IDNameDomain DEFAULT NULL)
RETURNS TABLE
(
   UserName ClassDB.IDNameDomain, StatementStartedAt TIMESTAMP, SessionID VARCHAR(17),
   DDLOperation VARCHAR, DDLObject VARCHAR
) AS
$$
   SELECT UserName, ClassDB.changeTimeZone(StatementStartedAtUTC) StatementStartedAt,
          SessionID, DDLOperation, DDLObject
   FROM ClassDB.DDLActivity
   WHERE UserName LIKE COALESCE(ClassDB.foldPgID($1), '%')
   ORDER BY UserName, StatementStartedAt DESC;
$$ LANGUAGE sql
   STABLE
   SECURITY DEFINER;

ALTER FUNCTION ClassDB.getUserDDLActivity(ClassDB.IDNameDomain)
   OWNER TO ClassDB;
REVOKE ALL ON FUNCTION ClassDB.getUserDDLActivity(ClassDB.IDNameDomain)
   FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ClassDB.getUserDDLActivity(ClassDB.IDNameDomain)
   TO ClassDB_Instructor;



--This function returns all DDL activity for the current user
CREATE OR REPLACE FUNCTION public.getMyDDLActivity()
RETURNS TABLE
(
   StatementStartedAt TIMESTAMP, SessionID VARCHAR(17), DDLOperation VARCHAR,
   DDLObject VARCHAR
) AS
$$
   SELECT StatementStartedAt, SessionID, DDLOperation, DDLObject
   FROM ClassDB.getUserDDLActivity(SESSION_USER::ClassDB.IDNameDomain);
$$ LANGUAGE sql
   STABLE
   SECURITY DEFINER;

ALTER FUNCTION public.getMyDDLActivity() OWNER TO ClassDB;



--This view wraps getMyDDLActivity() for easier student access
CREATE OR REPLACE VIEW public.MyDDLActivity AS
(
   SELECT StatementStartedAt, SessionID, DDLOperation, DDLObject
   FROM public.getMyDDLActivity()
);

ALTER VIEW public.MyDDLActivity OWNER TO ClassDB;
GRANT SELECT ON public.MyDDLActivity TO PUBLIC;



--This function returns all connection activity for a specified user. This includes
-- all connections and disconnections. Passing NULL returns data for all users
CREATE OR REPLACE FUNCTION ClassDB.getUserConnectionActivity(
   userName ClassDB.IDNameDomain DEFAULT NULL)
RETURNS TABLE
(
   UserName ClassDB.IDNameDomain, ActivityAt TIMESTAMP, ActivityType VARCHAR,
   SessionID VARCHAR(17), ApplicationName ClassDB.IDNameDomain
) AS
$$
   SELECT UserName, ClassDB.changeTimeZone(ActivityAtUTC) ActivityAt,
          CASE WHEN ActivityType = 'C' THEN 'Connection'
          ELSE 'Disconnection' END ActivityType,
          SessionID, ApplicationName
   FROM ClassDB.ConnectionActivity
   WHERE UserName LIKE COALESCE(ClassDB.foldPgID($1), '%')
   ORDER BY UserName, ActivityAt DESC;
$$ LANGUAGE sql
   STABLE
   SECURITY DEFINER;

ALTER FUNCTION ClassDB.getUserConnectionActivity(ClassDB.IDNameDomain)
   OWNER TO ClassDB;
REVOKE ALL ON FUNCTION ClassDB.getUserConnectionActivity(ClassDB.IDNameDomain)
   FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ClassDB.getUserConnectionActivity(ClassDB.IDNameDomain)
   TO ClassDB_Instructor;



--This function returns all connection activity for the current user
CREATE OR REPLACE FUNCTION public.getMyConnectionActivity()
RETURNS TABLE
(
   ActivityAt TIMESTAMP, ActivityType VARCHAR, SessionID VARCHAR(17),
   ApplicationName ClassDB.IDNameDomain
) AS
$$
   SELECT ActivityAt, ActivityType, SessionID, ApplicationName
   FROM ClassDB.getUserConnectionActivity(SESSION_USER::ClassDB.IDNameDomain);
$$ LANGUAGE sql
   STABLE
   SECURITY DEFINER;

ALTER FUNCTION public.getMyConnectionActivity() OWNER TO ClassDB;



--This view wraps getMyConnectionActivity for easier student access
CREATE OR REPLACE VIEW public.MyConnectionActivity AS
(
   SELECT ActivityAt, ActivityType, SessionID, ApplicationName
   FROM public.getMyConnectionActivity()
);

ALTER VIEW public.MyConnectionActivity OWNER TO ClassDB;
GRANT SELECT ON public.MyConnectionActivity TO PUBLIC;



--This function returns all activity for a specified user. Passing NULL provides
-- data for all users. This function returns both connection and DDL activity.
-- The ActivityType column specifies this, either 'Connection', 'Disconnection',
-- or 'DDL Query'. For connection activity rows, the DDLOperation and DDLObject columns
-- are not applicable, will be NULL. Likewise, SessionID and ApplicationID are
-- not applicable to DDL activity.
CREATE OR REPLACE FUNCTION ClassDB.getUserActivity(userName ClassDB.IDNameDomain
   DEFAULT NULL)
RETURNS TABLE
(
   UserName ClassDB.IDNameDomain, ActivityAt TIMESTAMP, ActivityType VARCHAR,
   SessionID VARCHAR(17), ApplicationName ClassDB.IDNameDomain, DDLOperation VARCHAR,
   DDLObject VARCHAR
) AS
$$
   --Postgres requires casting NULL to IDNameDomain, it will not do this coercion
   SELECT UserName, StatementStartedAt AS ActivityAt, 'DDL Query', SessionID,
          NULL::ClassDB.IDNameDomain, DDLOperation, DDLObject
   FROM ClassDB.getUserDDLActivity(COALESCE($1, '%'))
   UNION ALL
   SELECT UserName, ActivityAt, ActivityType, SessionID, ApplicationName, NULL, NULL
   FROM ClassDB.getUserConnectionActivity(COALESCE($1, '%'))
   ORDER BY UserName, ActivityAt DESC;
$$ LANGUAGE sql
   STABLE
   SECURITY DEFINER;

ALTER FUNCTION ClassDB.getUserActivity(ClassDB.IDNameDomain) OWNER TO ClassDB;
REVOKE ALL ON FUNCTION ClassDB.getUserActivity(ClassDB.IDNameDomain) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ClassDB.getUserActivity(ClassDB.IDNameDomain)
   TO ClassDB_Instructor;



--This function returns all activity for a specified student. Passing NULL provides
-- data for all students
CREATE OR REPLACE FUNCTION ClassDB.getStudentActivity(userName ClassDB.IDNameDomain
   DEFAULT NULL)
RETURNS TABLE
(
   UserName ClassDB.IDNameDomain, ActivityAt TIMESTAMP, ActivityType VARCHAR,
   SessionID VARCHAR(17), ApplicationName ClassDB.IDNameDomain, DDLOperation VARCHAR,
   DDLObject VARCHAR
) AS
$$
   SELECT UserName, ActivityAt, ActivityType, SessionID, ApplicationName, DDLOperation, DDLObject
   FROM ClassDB.getUserActivity(COALESCE($1, '%'))
   WHERE ClassDB.isStudent(UserName);
$$ LANGUAGE sql
   STABLE
   SECURITY DEFINER;

ALTER FUNCTION ClassDB.getStudentActivity(ClassDB.IDNameDomain) OWNER TO ClassDB;
REVOKE ALL ON FUNCTION ClassDB.getStudentActivity(ClassDB.IDNameDomain) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ClassDB.getStudentActivity(ClassDB.IDNameDomain)
   TO ClassDB_Instructor;



--A view that wraps getStudentActivity() for easier access
CREATE OR REPLACE VIEW ClassDB.StudentActivity AS
(
   SELECT UserName, ActivityAt, ActivityType, SessionID, ApplicationName, DDLOperation, DDLObject
   FROM   ClassDB.getStudentActivity()
);

ALTER VIEW ClassDB.StudentActivity OWNER TO ClassDB;
REVOKE ALL PRIVILEGES ON ClassDB.StudentActivity FROM PUBLIC;
GRANT SELECT ON ClassDB.StudentActivity TO ClassDB_Instructor;



--This function returns all activity for a specified student. Returns
-- anonymized data. Passing NULL provides data for all students
CREATE OR REPLACE FUNCTION ClassDB.getStudentActivityAnon(
   userName ClassDB.IDNameDomain DEFAULT NULL)
RETURNS TABLE
(
   ActivityAt TIMESTAMP, ActivityType VARCHAR, SessionID VARCHAR(17),
   ApplicationName ClassDB.IDNameDomain, DDLOperation VARCHAR, DDLObject VARCHAR
) AS
$$
   SELECT ActivityAt, ActivityType, SessionID, ApplicationName, DDLOperation,
          SUBSTRING(DDLObject, POSITION('.' IN DDLObject)+1) DDLObject
   FROM ClassDB.getStudentActivity(COALESCE($1, '%'));
$$ LANGUAGE sql
   STABLE
   SECURITY DEFINER;

ALTER FUNCTION ClassDB.getStudentActivityAnon(ClassDB.IDNameDomain)
   OWNER TO ClassDB;
REVOKE ALL ON FUNCTION ClassDB.getStudentActivityAnon(ClassDB.IDNameDomain)
   FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ClassDB.getStudentActivityAnon(ClassDB.IDNameDomain)
   TO ClassDB_Instructor;



--A view that wraps getStudentActivityAnon() for easier access
CREATE OR REPLACE VIEW ClassDB.StudentActivityAnon AS
(
   SELECT ActivityAt, ActivityType, SessionID, ApplicationName, DDLOperation, DDLObject
   FROM   ClassDB.getStudentActivityAnon()
);

ALTER VIEW ClassDB.StudentActivityAnon OWNER TO ClassDB;
REVOKE ALL PRIVILEGES ON ClassDB.StudentActivityAnon FROM PUBLIC;
GRANT SELECT ON ClassDB.StudentActivityAnon TO ClassDB_Instructor;



--This view returns all activity for the current user
CREATE OR REPLACE FUNCTION public.getMyActivity()
RETURNS TABLE
(
   ActivityAt TIMESTAMP, ActivityType VARCHAR, SessionID VARCHAR(17),
   ApplicationName ClassDB.IDNameDomain, DDLOperation VARCHAR, DDLObject VARCHAR
) AS
$$
   SELECT ActivityAt, ActivityType, SessionID, ApplicationName, DDLOperation, DDLObject
   FROM ClassDB.getUserActivity(SESSION_USER::ClassDB.IDNameDomain);
$$ LANGUAGE sql
   STABLE
   SECURITY DEFINER;

ALTER FUNCTION public.getMyActivity() OWNER TO ClassDB;



--This view wraps getMyActivity() for easier student access
CREATE OR REPLACE VIEW public.MyActivity AS
(
   SELECT ActivityAt, ActivityType, SessionID, ApplicationName, DDLOperation, DDLObject
   FROM public.getMyActivity()
);

ALTER VIEW public.MyActivity OWNER TO ClassDB;
GRANT SELECT ON public.MyActivity TO PUBLIC;


COMMIT;
