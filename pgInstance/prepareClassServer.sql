--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab at Western Connecticut State University (dassl@WCSU)
--
--prepareClassServer.sql
--
--ClassDB - Created: 2017-06-09; Modified 2017-06-09

--This script should be run as a user with createrole privileges

--This script creates roles for students, instructors, and database managers (administrators).

START TRANSACTION;

--TODO: Can this just check for createrole?
--Tests for superuser privilege on current_user
DO
$$
DECLARE
   isSuper BOOLEAN;
BEGIN
   EXECUTE 'SELECT COALESCE(rolsuper, FALSE) FROM pg_catalog.pg_roles WHERE rolname = current_user' INTO isSuper;
   IF NOT isSuper THEN
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
   END IF;
END
$$;

COMMIT;