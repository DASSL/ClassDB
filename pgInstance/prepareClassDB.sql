--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab at Western Connecticut State University (dassl@WCSU)
--
--prepareClassDB.sql
--
--ClassDB - Created: 2017-05-29; Modified 2017-06-14


--This script should be run as a user with superuser privileges, due to the functions being
-- declared SECURITY DEFINER, along with the need to properly set object ownership and define
-- event triggers.


--This script first prevents student roles from modiying the public schema, and then creates a
-- classdb schema. Following that, a stored procedure for creating any type of user is defined.
-- Finally, procedures for creating and dropping students and instructors are defined. This script
-- also creates Student and Instructor tables in the classdb schema, and an event trigger that
-- records the timestamp of the last ddl statement issued by each student.

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


--Allows appropriate users to connect to the database
DO
$$
DECLARE
   currentDB VARCHAR(128);
BEGIN
   currentDB := current_database();
   --Postgres grants CONNECT to public by default
   EXECUTE format('REVOKE CONNECT ON DATABASE %I FROM PUBLIC', currentDB);
   EXECUTE format('GRANT CONNECT ON DATABASE %I TO DBManager', currentDB);
   EXECUTE format('GRANT CONNECT ON DATABASE %I TO Instructor', currentDB);
   EXECUTE format('GRANT CONNECT ON DATABASE %I TO Student', currentDB);
END
$$;


--Removes the ability for students to modify the "public" schema for the current database
REVOKE CREATE ON SCHEMA public FROM Student;


--Creates a schema for holding administrative information
CREATE SCHEMA IF NOT EXISTS classdb;


--The following procedure creates a user, given a username and password. It also creates a
-- schema for the new user and gives them appropriate permissions for that schema.
CREATE OR REPLACE FUNCTION classdb.createUser(userName VARCHAR(50), initialPassword VARCHAR(128)) RETURNS VOID AS
$$
DECLARE
   valueExists BOOLEAN;
BEGIN
   SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = $1 INTO valueExists;
   IF valueExists THEN
      RAISE NOTICE 'User "%" already exists, password not modified', $1;
   ELSE
      EXECUTE format('CREATE USER %I ENCRYPTED PASSWORD %L', $1, $2);
   END IF;

   SELECT 1 FROM pg_catalog.pg_namespace WHERE nspname = $1 INTO valueExists;
   IF valueExists THEN
      RAISE NOTICE 'Schema "%" already exists', $1;
   ELSE
      EXECUTE format('CREATE SCHEMA %I', $1);
      EXECUTE format('GRANT ALL PRIVILEGES ON SCHEMA %I TO %I', $1, $1);
   END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;

REVOKE ALL ON FUNCTION classdb.createUser(userName VARCHAR(50), initialPassword VARCHAR(128)) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION classdb.createUser(userName VARCHAR(50), initialPassword VARCHAR(128)) TO DBManager;


--Creates a role for a student and assigns them to the Student role, given a username, name,
-- and optional schoolID and password. This proceedure also gives Instructors read access
-- (USAGE) to the new student's schema.
CREATE OR REPLACE FUNCTION classdb.createStudent(userName VARCHAR(50), studentName VARCHAR(100),
   schoolID VARCHAR(20) DEFAULT NULL, initialPassword VARCHAR(128) DEFAULT NULL) RETURNS VOID AS
$$
BEGIN
   IF initialPassword IS NOT NULL THEN
      PERFORM classdb.createUser(userName, initialPassword);
   ELSIF schoolID IS NOT NULL THEN
      PERFORM classdb.createUser(userName, schoolID);
   ELSE
      PERFORM classdb.createUser(userName, userName::VARCHAR(128));
   END IF;
   EXECUTE format('GRANT Student TO %I', $1);
   EXECUTE format('GRANT USAGE ON SCHEMA %I TO Instructor', $1);
   INSERT INTO classdb.Student VALUES($1, $2, $3);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;

REVOKE ALL ON FUNCTION classdb.createStudent(userName VARCHAR(50), studentName VARCHAR(100),
   schoolID VARCHAR(20), initialPassword VARCHAR(128)) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION classdb.createStudent(userName VARCHAR(50), studentName VARCHAR(100),
   schoolID VARCHAR(20), initialPassword VARCHAR(128)) TO DBManager;
GRANT EXECUTE ON FUNCTION classdb.createStudent(userName VARCHAR(50), studentName VARCHAR(100),
   schoolID VARCHAR(20), initialPassword VARCHAR(128)) TO Instructor;


--Creates a role for an instructor given a username, name, and optional password.
-- The procedure also gives appropriate permission to the instructor.
CREATE OR REPLACE FUNCTION classdb.createInstructor(userName VARCHAR(50), instructorName VARCHAR(100),
   initialPassword VARCHAR(128) DEFAULT NULL) RETURNS VOID AS
$$
BEGIN
   IF initialPassword IS NOT NULL THEN
      PERFORM classdb.createUser(userName, initialPassword);
   ELSE
      PERFORM classdb.createUser(userName, userName::VARCHAR(128));
   END IF;
   EXECUTE format('GRANT Instructor TO %I', $1);
   INSERT INTO classdb.Instructor VALUES($1, $2);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;

REVOKE ALL ON FUNCTION classdb.createInstructor(userName VARCHAR(50), instructorName VARCHAR(100),
   initialPassword VARCHAR(128)) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION classdb.createInstructor(userName VARCHAR(50), instructorName VARCHAR(100),
   initialPassword VARCHAR(128)) TO DBManager;


--Creates a role for a DBManager given a username, name, and optional password.
-- The procedure also gives appropriate permission to the DBManager.
CREATE OR REPLACE FUNCTION classdb.createDBManager(userName VARCHAR(50), managerName VARCHAR(100),
   initialPassword VARCHAR(128) DEFAULT NULL) RETURNS VOID AS
$$
BEGIN
   IF initialPassword IS NOT NULL THEN
      PERFORM classdb.createUser(userName, initialPassword);
   ELSE
      PERFORM classdb.createUser(userName, userName::VARCHAR(128));
   END IF;
   EXECUTE format('GRANT DBManager TO %I', $1);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;

REVOKE ALL ON FUNCTION classdb.createDBManager(userName VARCHAR(50), managerName VARCHAR(100),
   initialPassword VARCHAR(128)) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION classdb.createDBManager(userName VARCHAR(50), managerName VARCHAR(100),
   initialPassword VARCHAR(128)) TO DBManager;


--The folowing procedure revokes the Student role from a student, along with their entry in the
-- classdb.Student table. If the Student role was the only role that the student was a member
-- of, the student's schema, and the objects contained within, are removed along with the the
-- role representing the student.
CREATE OR REPLACE FUNCTION classdb.dropStudent(userName VARCHAR(50)) RETURNS VOID AS
$$
DECLARE
   userExists BOOLEAN;
   hasOtherRoles BOOLEAN;
BEGIN
   SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = $1 INTO userExists;
   IF
      userExists AND
      pg_catalog.pg_has_role($1, 'student', 'member')
   THEN
      EXECUTE format('REVOKE Student FROM %I', $1);
      DELETE FROM classdb.Student S WHERE S.userName = $1;
      SELECT 1 FROM pg_catalog.pg_roles WHERE pg_catalog.pg_has_role($1, oid, 'member')
         AND rolname != $1 INTO hasOtherRoles;
      IF hasOtherRoles THEN
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
GRANT EXECUTE ON FUNCTION classdb.dropStudent(userName VARCHAR(50)) TO DBManager;
GRANT EXECUTE ON FUNCTION classdb.dropStudent(userName VARCHAR(50)) TO Instructor;


--The folowing procedure revokes the Instructor role from an Instructor, along with their entry
-- in the classdb.Instructor table. If the Instructor role was the only role that the
-- instructor was a member of, the instructor's schema, and the objects contained within, are
-- removed along with the the role representing the instructor.
CREATE OR REPLACE FUNCTION classdb.dropInstructor(userName VARCHAR(50)) RETURNS VOID AS
$$
DECLARE
   userExists BOOLEAN;
   hasOtherRoles BOOLEAN;
BEGIN
   SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = $1 INTO userExists;
   IF
      userExists AND
      pg_catalog.pg_has_role($1, 'instructor', 'member')
   THEN
      EXECUTE format('REVOKE Instructor FROM %I', $1);
      DELETE FROM classdb.Instructor S WHERE S.userName = $1;
      SELECT 1 FROM pg_catalog.pg_roles WHERE pg_catalog.pg_has_role($1, oid, 'member')
          AND rolname != $1 INTO hasOtherRoles;
      IF hasOtherRoles THEN
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
GRANT EXECUTE ON FUNCTION classdb.dropInstructor(userName VARCHAR(50)) TO DBManager;


--The folowing procedure revokes the DBManager role from a DBManager. If the DBManager role was
-- the only role that they were a member of, the manager's schema, and the objects contained
-- within, are removed along with the the role representing the DBManager.
CREATE OR REPLACE FUNCTION classdb.dropDBManager(userName VARCHAR(50)) RETURNS VOID AS
$$
DECLARE
   userExists BOOLEAN;
   hasOtherRoles BOOLEAN;
BEGIN
   SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = $1 INTO userExists;
   IF
      userExists AND
      pg_catalog.pg_has_role($1, 'dbmanager', 'member')
   THEN
      EXECUTE format('REVOKE dbmanager FROM %I', userName);
      SELECT 1 FROM pg_catalog.pg_roles WHERE pg_catalog.pg_has_role($1, oid, 'member')
          AND rolname != $1 INTO hasOtherRoles;
      IF hasOtherRoles THEN
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
GRANT EXECUTE ON FUNCTION classdb.dropDBManager(userName VARCHAR(50)) TO DBManager;


--The following procedure drops a user regardless of their role memberships. This will also
-- drop the user's schema and the objects contained within, if the schema exists. Currently,
-- it also drops the value from the Student table if the user was a member of the Student role,
-- and from the Instructor table if they were an instructor.
CREATE OR REPLACE FUNCTION classdb.dropUser(userName VARCHAR(50)) RETURNS VOID AS
$$
DECLARE
   userExists BOOLEAN;
BEGIN
   SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = $1 INTO userExists;
   IF userExists THEN
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
GRANT EXECUTE ON FUNCTION classdb.dropUser(userName VARCHAR(50)) TO DBManager;


CREATE TABLE IF NOT EXISTS classdb.Student
(
   userName VARCHAR(50) NOT NULL PRIMARY KEY,
   studentName VARCHAR(100),
   schoolID VARCHAR(20),
   lastActivity TIMESTAMP --holds timestamp of the last ddl command issued by the student in UTC
);

CREATE TABLE IF NOT EXISTS classdb.Instructor
(
   userName VARCHAR(50) NOT NULL PRIMARY KEY,
   instructorName VARCHAR(100)
);

--This function updates the LastActivity field for a given student
CREATE OR REPLACE FUNCTION classdb.updateStudentActivity() RETURNS event_trigger AS
$$
BEGIN
   UPDATE classdb.Student
   SET lastActivity = (SELECT statement_timestamp() AT TIME ZONE 'utc')
   WHERE userName = session_user;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;


--Event trigger to update user last activity time on DDL events
DROP EVENT TRIGGER IF EXISTS updateStudentActivityTrigger;

CREATE EVENT TRIGGER updateStudentActivityTrigger
ON ddl_command_start
EXECUTE PROCEDURE classdb.updateStudentActivity();

COMMIT;
