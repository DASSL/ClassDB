--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab at Western Connecticut State University (dassl@WCSU)
--
--prepareClassServer.sql
--
--ClassDB - Created: 2017-06-09; Modified 2017-06-20

--This script should be run as a user with createrole privileges

--This script creates roles for students, instructors, and database managers (administrators).

START TRANSACTION;

--Tests for createrole privilege on current_user
DO
$$
DECLARE
   canCreateRole BOOLEAN;
BEGIN
   SELECT rolcreaterole FROM pg_catalog.pg_roles WHERE rolname = current_user INTO canCreateRole;
   IF NOT canCreateRole THEN
      RAISE EXCEPTION 'Insufficient privileges for script: must be run as a superuser';
   END IF;
END
$$;

--Group equivalents for managing permissions for students, instructors, and managers of the DB
DO
$$
BEGIN
   IF NOT EXISTS (SELECT * FROM pg_catalog.pg_roles WHERE rolname = 'student') THEN
      CREATE ROLE Student;
   END IF;

   IF NOT EXISTS (SELECT * FROM pg_catalog.pg_roles WHERE rolname = 'instructor') THEN
      CREATE ROLE Instructor;
   END IF;

   IF NOT EXISTS (SELECT * FROM pg_catalog.pg_roles WHERE rolname = 'dbmanager') THEN
      CREATE ROLE DBManager;
      ALTER ROLE DBManager createrole;
   END IF;
END
$$;

COMMIT;
