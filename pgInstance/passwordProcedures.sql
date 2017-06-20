--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab at Western Connecticut State University (dassl@WCSU)
--
--passwordProcedures.sql
--
--ClassDB - Created: 2017-05-30; Modified 2017-06-14

--This script should be run as a superuser, or a user with the createrole privilege, due to the
-- functions being declared SECURITY DEFINER.

START TRANSACTION;

--Tests for superuser privilege on current_user
DO
$$
DECLARE
   isSuper BOOLEAN;
BEGIN
   SELECT COALESCE(rolsuper, FALSE) FROM pg_catalog.pg_roles WHERE rolname = current_user INTO isSuper;
   IF NOT isSuper THEN
      RAISE EXCEPTION 'Insufficient privileges for script: must be run as a superuser';
   END IF;
END
$$;

--The following procedure allows changing the password for a given username, given both the
-- username and password. NOTICEs are raised if the user does not exist or if the password
-- does not meet the requirements.
--Current password requirements:
-- - Must be 4 or more characters
-- - Must contain at least one numerical digit (0-9)

CREATE OR REPLACE FUNCTION classdb.changeUserPassword(userName VARCHAR(50), password VARCHAR(128)) RETURNS VOID AS
$$
DECLARE
   userExists BOOLEAN;
BEGIN
   SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = $1 INTO userExists;
   IF userExists THEN
      IF
         LENGTH(password) > 3 AND
         SUBSTRING(password from '[0-9]') IS NOT NULL
      THEN
         EXECUTE format('ALTER ROLE %I ENCRYPTED PASSWORD %L', userName, password);
      ELSE
         RAISE NOTICE 'Password does not meet requirements. Must be 6 or more characters and contain at least 1 number';
      END IF;
   ELSE
      RAISE NOTICE 'User: "%" does not exist', userName;
   END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;

REVOKE ALL ON FUNCTION classdb.changeUserPassword(userName VARCHAR(50), password VARCHAR(128)) FROM PUBLIC;
ALTER FUNCTION classdb.changeUserPassword(userName VARCHAR(50), password VARCHAR(128)) OWNER TO DBManager;


--The following procedure resets a users password to the default password given a username.
-- NOTE: The default password is not the same as the initialpassword that may have been given
-- at the time of role creation. It is either the ID or username for a student and the username
-- for an instructor.

CREATE OR REPLACE FUNCTION classdb.resetUserPassword(userName VARCHAR(50)) RETURNS VOID AS
$$
DECLARE
   studentID VARCHAR(128);
BEGIN
   IF
      pg_catalog.pg_has_role($1, 'student', 'member')
   THEN
      SELECT ID FROM classdb.Student WHERE userName = $1 INTO studentID;
      IF studentID IS NULL THEN
         PERFORM classdb.changeUserPassword(userName, userName);
      ELSE
         PERFORM classdb.changeUserPassword(userName, studentID);
      END IF;
   ELSIF
      pg_catalog.pg_has_role(userName, 'instructor', 'member')
   THEN
      PERFORM classdb.changeUserPassword(userName, userName);
   ELSE
      RAISE NOTICE 'User "%" not found among registered users', userName;
   END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;

REVOKE ALL ON FUNCTION classdb.resetUserPassword(userName VARCHAR(50)) FROM PUBLIC;
ALTER FUNCTION classdb.resetUserPassword(userName VARCHAR(50)) OWNER TO DBManager;
GRANT EXECUTE ON FUNCTION classdb.resetUserPassword(userName VARCHAR(50)) TO Instructor;

COMMIT;
