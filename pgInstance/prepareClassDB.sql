--Andrew Figueroa, Steven Rollo, Sean Murthy
--
--Data Science & Systems Lab at Western Connecticut State University (dassl@WCSU)
--(C) 2017 DASSL CC 4.0 BY-SA-NC https://creativecommons.org/licenses/by-nc-sa/4.0/
--
--prepareClassDB.sql - ClassDB


--This script should be run as a user with createrole privileges

--This script first prevents student roles from modiying the public schema, and then creates a
-- classdb schema. Following that, a stored procedure for creating any type of user is defined,
-- along with procedures for creating and dropping students and instructors. Finally,
-- procedures for resetting a users password are created. This script also creates Student and
-- Instructor tables in the classdb schema, and an event trigger that records the timestamp of
-- the last ddl statement issued by each student.


START TRANSACTION;

--Tests for createrole privilege on current_user
DO
$$
BEGIN
   IF NOT EXISTS(SELECT * FROM pg_catalog.pg_roles WHERE rolname = current_user 
    AND rolcreaterole = TRUE) THEN
      RAISE EXCEPTION 'Insufficient privileges: script must be run as a user with createrole privileges';
   END IF;
END
$$;

--Grants appropriate privileges to the current database
DO
$$
DECLARE
   currentDB VARCHAR(128);
BEGIN
   currentDB := current_database();
   --Postgres grants CONNECT to public by default
   EXECUTE format('REVOKE CONNECT ON DATABASE %I FROM PUBLIC', currentDB);
   EXECUTE format('GRANT CONNECT ON DATABASE %I TO Instructor', currentDB);
   EXECUTE format('GRANT CONNECT ON DATABASE %I TO DBManager', currentDB);
   EXECUTE format('GRANT CONNECT ON DATABASE %I TO Student', currentDB);
   --Allows ClassDB to create schemas on the current database
   EXECUTE format('GRANT CREATE ON DATABASE %I TO ClassDB', currentDB);
END
$$;


--Removes the ability for students to modify the "public" schema for the current database
REVOKE CREATE ON SCHEMA public FROM Student;


--Creates a schema for holding administrative information and assigns privileges
CREATE SCHEMA IF NOT EXISTS classdb;
GRANT ALL ON SCHEMA classdb to ClassDB;
GRANT ALL ON SCHEMA classdb TO Instructor;
GRANT ALL ON SCHEMA classdb TO DBManager;



--The following procedure creates a user, given a username and password. It also creates a
-- schema for the new user and gives them appropriate permissions for that schema.
CREATE OR REPLACE FUNCTION classdb.createUser(userName VARCHAR(50), initialPassword VARCHAR(128)) RETURNS VOID AS
$$
BEGIN
   IF EXISTS(SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = $1) THEN
      RAISE NOTICE 'User "%" already exists, password not modified', $1;
   ELSE
      EXECUTE format('CREATE USER %I ENCRYPTED PASSWORD %L', $1, $2);
   END IF;

   IF EXISTS(SELECT * FROM pg_catalog.pg_namespace WHERE nspname = $1) THEN
      RAISE NOTICE 'Schema "%" already exists', $1;
   ELSE
      EXECUTE format('CREATE SCHEMA %I', $1);
      EXECUTE format('GRANT ALL PRIVILEGES ON SCHEMA %I TO %I', $1, $1);
   END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;

REVOKE ALL ON FUNCTION classdb.createUser(userName VARCHAR(50), initialPassword VARCHAR(128))
   FROM PUBLIC;
GRANT EXECUTE ON FUNCTION classdb.createUser(userName VARCHAR(50), initialPassword VARCHAR(128))
   TO Instructor;
GRANT EXECUTE ON FUNCTION classdb.createUser(userName VARCHAR(50), initialPassword VARCHAR(128))
   TO DBManager;
ALTER FUNCTION classdb.createUser(userName VARCHAR(50), initialPassword VARCHAR(128))
   OWNER TO ClassDB;


--Creates a role for a student and assigns them to the Student role, given a username, name,
-- and optional schoolID and password. This proceedure also gives Instructors read access
-- (USAGE) to the new student's schema.
CREATE OR REPLACE FUNCTION classdb.createStudent(userName VARCHAR(50), studentName VARCHAR(100),
   schoolID VARCHAR(20) DEFAULT NULL, initialPassword VARCHAR(128) DEFAULT NULL) RETURNS VOID AS
$$
BEGIN
   IF initialPassword IS NOT NULL THEN
      PERFORM classdb.createUser(userName, initialPassword);
   ELSE
      PERFORM classdb.createUser(userName, userName);
   END IF;
   EXECUTE format('GRANT Student TO %I', $1);
   EXECUTE format('GRANT USAGE ON SCHEMA %I TO Instructor', $1);
   EXECUTE format('ALTER ROLE %I CONNECTION LIMIT 5', $1);
   EXECUTE format('ALTER ROLE %I SET statement_timeout = 2000', $1);
   INSERT INTO classdb.Student VALUES($1, $2, $3) ON CONFLICT DO NOTHING;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;

REVOKE ALL ON FUNCTION classdb.createStudent(userName VARCHAR(50), studentName VARCHAR(100),
   schoolID VARCHAR(20), initialPassword VARCHAR(128)) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION classdb.createStudent(userName VARCHAR(50), studentName VARCHAR(100),
   schoolID VARCHAR(20), initialPassword VARCHAR(128)) TO Instructor;
GRANT EXECUTE ON FUNCTION classdb.createStudent(userName VARCHAR(50), studentName VARCHAR(100),
   schoolID VARCHAR(20), initialPassword VARCHAR(128)) TO DBManager;
ALTER FUNCTION classdb.createStudent(userName VARCHAR(50), studentName VARCHAR(100),
   schoolID VARCHAR(20), initialPassword VARCHAR(128)) OWNER TO ClassDB;



--Creates a role for an instructor given a username, name, and optional password.
-- The procedure also gives appropriate permission to the instructor.
CREATE OR REPLACE FUNCTION classdb.createInstructor(userName VARCHAR(50), instructorName VARCHAR(100),
   initialPassword VARCHAR(128) DEFAULT NULL) RETURNS VOID AS
$$
BEGIN
   IF initialPassword IS NOT NULL THEN
      PERFORM classdb.createUser(userName, initialPassword);
   ELSE
      PERFORM classdb.createUser(userName, userName);
   END IF;
   EXECUTE format('GRANT Instructor TO %I', $1);
   INSERT INTO classdb.Instructor VALUES($1, $2) ON CONFLICT DO NOTHING;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;

REVOKE ALL ON FUNCTION classdb.createInstructor(userName VARCHAR(50), instructorName VARCHAR(100),
   initialPassword VARCHAR(128)) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION classdb.createInstructor(userName VARCHAR(50), instructorName VARCHAR(100),
   initialPassword VARCHAR(128)) TO Instructor;
GRANT EXECUTE ON FUNCTION classdb.createInstructor(userName VARCHAR(50), instructorName VARCHAR(100),
   initialPassword VARCHAR(128)) TO DBManager;
ALTER FUNCTION classdb.createInstructor(userName VARCHAR(50), instructorName VARCHAR(100),
   initialPassword VARCHAR(128)) OWNER TO ClassDB;


--Creates a role for a DBManager given a username, name, and optional password.
-- The procedure also gives appropriate permission to the DBManager.
CREATE OR REPLACE FUNCTION classdb.createDBManager(userName VARCHAR(50), managerName VARCHAR(100),
   initialPassword VARCHAR(128) DEFAULT NULL) RETURNS VOID AS
$$
BEGIN
   IF initialPassword IS NOT NULL THEN
      PERFORM classdb.createUser(userName, initialPassword);
   ELSE
      PERFORM classdb.createUser(userName, userName);
   END IF;
   EXECUTE format('GRANT DBManager TO %I', $1);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;

REVOKE ALL ON FUNCTION classdb.createDBManager(userName VARCHAR(50), managerName VARCHAR(100),
   initialPassword VARCHAR(128)) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION classdb.createDBManager(userName VARCHAR(50), managerName VARCHAR(100),
   initialPassword VARCHAR(128)) TO Instructor;
GRANT EXECUTE ON FUNCTION classdb.createDBManager(userName VARCHAR(50), managerName VARCHAR(100),
   initialPassword VARCHAR(128)) TO DBManager;
ALTER FUNCTION classdb.createDBManager(userName VARCHAR(50), managerName VARCHAR(100),
   initialPassword VARCHAR(128)) OWNER TO ClassDB;


--The folowing procedure revokes the Student role from a student, along with their entry in the
-- classdb.Student table. If the Student role was the only role that the student was a member
-- of, the student's schema, and the objects contained within, are removed along with the the
-- role representing the student.
CREATE OR REPLACE FUNCTION classdb.dropStudent(userName VARCHAR(50)) RETURNS VOID AS
$$
BEGIN
   IF
      EXISTS(SELECT * FROM pg_catalog.pg_roles WHERE rolname = $1) AND
      pg_catalog.pg_has_role($1, 'student', 'member')
   THEN
      EXECUTE format('REVOKE Student FROM %I', $1);
      DELETE FROM classdb.Student S WHERE S.userName = $1;

      IF EXISTS(SELECT * FROM pg_catalog.pg_roles WHERE pg_catalog.pg_has_role($1, oid, 'member')
       AND rolname != $1) THEN
         RAISE NOTICE 'User "%" remains a member of one or more additional roles', $1;
      ELSE
         EXECUTE format('DROP SCHEMA %I CASCADE', $1);
         EXECUTE format('DROP ROLE %I', $1);
      END IF;
   ELSE
      RAISE NOTICE 'User "%" is not a registered student', $1;
   END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;

REVOKE ALL ON FUNCTION classdb.dropStudent(userName VARCHAR(50)) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION classdb.dropStudent(userName VARCHAR(50)) TO Instructor;
GRANT EXECUTE ON FUNCTION classdb.dropStudent(userName VARCHAR(50)) TO DBManager;
ALTER FUNCTION classdb.dropStudent(userName VARCHAR(50)) OWNER TO ClassDB;


--The folowing procedure drops all students registered in the classdb.Student table created below.
-- Only Students registered in that table will be dropped. If a user is a member of one or more
-- additional roles, they will not be dropped, but will no longer be a member of the Student role,
-- or be registered in the classdb.Student table.
CREATE OR REPLACE FUNCTION dropAllStudents() RETURNS VOID AS
$$
BEGIN
   SELECT classdb.dropStudent(S.userName) FROM classdb.Student S;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;
   
REVOKE ALL ON FUNCTION dropAllStudents() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION dropAllStudents() TO Instructor;
GRANT EXECUTE ON FUNCTION dropAllStudents() TO DBManager;
ALTER FUNCTION dropAllStudents() OWNER TO ClassDB;


--The folowing procedure revokes the Instructor role from an Instructor, along with their entry
-- in the classdb.Instructor table. If the Instructor role was the only role that the
-- instructor was a member of, the instructor's schema, and the objects contained within, are
-- removed along with the the role representing the instructor.
CREATE OR REPLACE FUNCTION classdb.dropInstructor(userName VARCHAR(50)) RETURNS VOID AS
$$
BEGIN
   IF
      EXISTS(SELECT * FROM pg_catalog.pg_roles WHERE rolname = $1) AND
      pg_catalog.pg_has_role($1, 'instructor', 'member')
   THEN
      EXECUTE format('REVOKE Instructor FROM %I', $1);
      DELETE FROM classdb.Instructor S WHERE S.userName = $1;
      IF EXISTS(SELECT * FROM pg_catalog.pg_roles WHERE pg_catalog.pg_has_role($1, oid, 'member')
       AND rolname != $1) THEN
         RAISE NOTICE 'User "%" remains a member of one or more additional roles', $1;
      ELSE
         EXECUTE format('DROP SCHEMA %I CASCADE', $1);
         EXECUTE format('DROP ROLE %I', $1);
      END IF;
   ELSE
      RAISE NOTICE 'User "%" is not a registered instructor', $1;
   END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;

REVOKE ALL ON FUNCTION classdb.dropInstructor(userName VARCHAR(50)) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION classdb.dropInstructor(userName VARCHAR(50)) TO Instructor;
GRANT EXECUTE ON FUNCTION classdb.dropInstructor(userName VARCHAR(50)) TO DBManager;
ALTER FUNCTION classdb.dropInstructor(userName VARCHAR(50)) OWNER TO ClassDB;


--The folowing procedure revokes the DBManager role from a DBManager. If the DBManager role was
-- the only role that they were a member of, the manager's schema, and the objects contained
-- within, are removed along with the the role representing the DBManager.
CREATE OR REPLACE FUNCTION classdb.dropDBManager(userName VARCHAR(50)) RETURNS VOID AS
$$
BEGIN
   IF
      EXISTS(SELECT * FROM pg_catalog.pg_roles WHERE rolname = $1) AND
      pg_catalog.pg_has_role($1, 'dbmanager', 'member')
   THEN
      EXECUTE format('REVOKE dbmanager FROM %I', userName);
      IF EXISTS(SELECT * FROM pg_catalog.pg_roles WHERE pg_catalog.pg_has_role($1, oid, 'member')
          AND rolname != $1) THEN
         RAISE NOTICE 'User "%" remains a member of one or more additional roles', $1;
      ELSE
         EXECUTE format('DROP SCHEMA %I CASCADE', $1);
         EXECUTE format('DROP ROLE %I', $1);
      END IF;
   ELSE
      RAISE NOTICE 'User "%" is not a registered DBManager', $1;
   END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;

REVOKE ALL ON FUNCTION classdb.dropDBManager(userName VARCHAR(50)) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION classdb.dropDBManager(userName VARCHAR(50)) TO Instructor;
GRANT EXECUTE ON FUNCTION classdb.dropDBManager(userName VARCHAR(50)) TO DBManager;
ALTER FUNCTION classdb.dropDBManager(userName VARCHAR(50)) OWNER TO ClassDB;


--The following procedure drops a user regardless of their role memberships. This will also
-- drop the user's schema and the objects contained within, if the schema exists. Currently,
-- it also drops the value from the Student table if the user was a member of the Student role,
-- and from the Instructor table if they were an instructor.
CREATE OR REPLACE FUNCTION classdb.dropUser(userName VARCHAR(50)) RETURNS VOID AS
$$
BEGIN
   IF EXISTS(SELECT * FROM pg_catalog.pg_roles WHERE rolname = $1) THEN
      IF pg_catalog.pg_has_role($1, 'student', 'member') THEN
        DELETE FROM classdb.Student WHERE userName = $1;
      END IF;

      IF pg_catalog.pg_has_role($1, 'instructor', 'member') THEN
         DELETE FROM classdb.Instructor WHERE userName = $1;
      END IF;

      EXECUTE format('DROP SCHEMA %I CASCADE', $1);
      EXECUTE format('DROP ROLE %I', $1);
   ELSE
      RAISE NOTICE 'User "%" is not a registered user', $1;
   END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;

REVOKE ALL ON FUNCTION classdb.dropUser(userName VARCHAR(50)) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION classdb.dropUser(userName VARCHAR(50)) TO Instructor;
GRANT EXECUTE ON FUNCTION classdb.dropUser(userName VARCHAR(50)) TO DBManager;
ALTER FUNCTION classdb.dropUser(userName VARCHAR(50)) OWNER TO ClassDB;

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
ALTER FUNCTION classdb.changeUserPassword(userName VARCHAR(50), password VARCHAR(128)) OWNER TO ClassDB;


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
GRANT EXECUTE ON FUNCTION classdb.resetUserPassword(userName VARCHAR(50)) TO Instructor;
GRANT EXECUTE ON FUNCTION classdb.resetUserPassword(userName VARCHAR(50)) TO DBManager;
ALTER FUNCTION classdb.resetUserPassword(userName VARCHAR(50)) OWNER TO ClassDB;

CREATE TABLE IF NOT EXISTS classdb.Student
(
   userName VARCHAR(50) NOT NULL PRIMARY KEY,
   studentName VARCHAR(100),
   schoolID VARCHAR(20),
   lastDDLActivity TIMESTAMP, --Timestamp of last DDL Query
   lastDDLOperation TEXT,
   lastDDLObject TEXT,
   DDLCount INT DEFAULT 0,
   lastConnection TIMESTAMP, --Timestamp of last connection
   connectionCount INT DEFAULT 0
);

GRANT SELECT ON classdb.Student TO DBManager;
GRANT UPDATE (studentName, schoolID) ON classdb.Student TO DBManager;
GRANT SELECT ON classdb.Student TO Instructor;
GRANT UPDATE (studentName, schoolID) ON classdb.Student TO Instructor;
ALTER TABLE classdb.Student OWNER TO ClassDB;


CREATE TABLE IF NOT EXISTS classdb.Instructor
(
   userName VARCHAR(50) NOT NULL PRIMARY KEY,
   instructorName VARCHAR(100)
);

GRANT SELECT ON classdb.Instructor TO DBManager;
GRANT UPDATE (instructorName) ON classdb.Instructor TO DBManager;
GRANT SELECT ON classdb.Student TO Instructor;
GRANT UPDATE (instructorName) ON classdb.Instructor TO Instructor;
ALTER TABLE classdb.Instructor OWNER TO ClassDB;

COMMIT;