--Andrew Figueroa
--
--createGroups.sql
--
--Users and Roles for CS205; Created: 2017-05-29; Modified 2017-06-03

--This script should be run as a superuser or equivalent role, due to the functions being
-- declared SECURITY DEFINER, along with the need to properly set object ownership.

--This script creates roles for students, instructors, and database managers (administrators).
-- Then, sudents are prevented from modiying the public schema, and a classdb schema is created.
-- Following that, a stored procedure for creating any type of user is defined. Finally,
-- procedures for creating and dropping students and instructors are defined. Currently this
-- script also creates Student and Instructor tables in the classdb schema.

--TODO: Test for to see if current user is a superuser or equivalent; raise exception if not

--Group equivalents for managing permissions for students, instructors, and managers of the DB
CREATE ROLE Student;
CREATE ROLE Instructor;
CREATE ROLE DBManager;


--Allows appropriate users to connect to the database
GRANT CONNECT ON DATABASE current_database() TO DBManager;
GRANT CONNECT ON DATABASE current_database() TO Instructor;
GRANT CONNECT ON DATABASE current_database() TO Student;

--Removes the ability for students to modify the "public" schema for the current database
REVOKE CREATE ON SCHEMA public FROM Student;


--Creates a schema for holding administrative information
CREATE SCHEMA classdb;


--The following procedure creates a user, given a username and password. It also creates a
-- schema for the new user and gives them appropriate permissions for that schema.
CREATE OR REPLACE FUNCTION classdb.createUser(userName NAME, initialPassword TEXT) RETURNS VOID AS
$$
DECLARE
    valueExists BOOLEAN;
BEGIN
    EXECUTE format('SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = %L', userName) INTO valueExists;
    IF valueExists THEN
        RAISE NOTICE 'User "%" already exists', userName;
    ELSE
        EXECUTE format('CREATE USER %I ENCRYPTED PASSWORD %L', userName, initialPassword);
    END IF;

    EXECUTE format('SELECT 1 FROM pg_catalog.pg_namespace WHERE nspname = %L', userName) INTO valueExists;
    IF valueExists THEN
        RAISE NOTICE 'Schema "%" already exists', userName;
    ELSE
        EXECUTE format('CREATE SCHEMA %I', userName);
    END IF;

    EXECUTE format('GRANT ALL PRIVILEGES ON SCHEMA %I TO %I', userName, userName);
END
$$  LANGUAGE plpgsql
    SECURITY DEFINER;

REVOKE ALL ON FUNCTION createUser(userName name, initialPassword text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION createUser(userName name, initialPassword text) TO DBManager;


--Creates a role for a student and assigns them to the Student role, given a username, name,
-- and optional schoolID and password. This proceedure also gives Instructors read access
-- (USAGE) to the new student's schema.
CREATE OR REPLACE FUNCTION classdb.createStudent(userName NAME, studentName VARCHAR(100),
    schoolID VARCHAR(20) DEFAULT NULL, initialPassword TEXT DEFAULT NULL) RETURNS VOID AS
$$
BEGIN
    IF initialPassword IS NOT NULL THEN
        PERFORM classdb.createUser(userName, initialPassword);
    ELSIF schoolID IS NOT NULL THEN
        PERFORM classdb.createUser(userName, schoolID);
    ELSE
        PERFORM classdb.createUser(userName, userName::TEXT);
    END IF;
    EXECUTE format('GRANT Student TO %I', userName);
    EXECUTE format('GRANT USAGE ON SCHEMA %I TO Instructor', userName);
    EXECUTE format('INSERT INTO classdb.Student VALUES(%L, %L, %L)', userName, studentName, schoolID);
END
$$  LANGUAGE plpgsql
    SECURITY DEFINER;

REVOKE ALL ON FUNCTION classdb.createStudent(userName NAME, studentName VARCHAR(100),
    schoolID VARCHAR(20), initialPassword TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION classdb.createStudent(userName NAME, studentName VARCHAR(100),
    schoolID VARCHAR(20), initialPassword TEXT) TO DBManager;
GRANT EXECUTE ON FUNCTION classdb.createStudent(userName NAME, studentName VARCHAR(100),
    schoolID VARCHAR(20), initialPassword TEXT) TO Instructor;


--Creates a role for an instructor given a username, name, and optional password.
-- The procedure also gives appropriate permission to the instructor.
CREATE OR REPLACE FUNCTION classdb.createInstructor(userName NAME, instructorName VARCHAR(100),
    initialPassword TEXT DEFAULT NULL) RETURNS VOID AS
$$
BEGIN
    IF initialPassword IS NOT NULL THEN
        PERFORM classdb.createUser(userName, initialPassword);
    ELSE
        PERFORM classdb.createUser(userName, userName::TEXT);
    END IF;
    EXECUTE format('GRANT Instructor TO %I', userName);
    EXECUTE format('INSERT INTO classdb.Instructor VALUES(%L, %L)', userName, instructorName);
END
$$  LANGUAGE plpgsql
    SECURITY DEFINER;

REVOKE ALL ON FUNCTION classdb.createInstructor(userName NAME, instructorName VARCHAR(100),
    initialPassword TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION classdb.createInstructor(userName NAME, instructorName VARCHAR(100),
    initialPassword TEXT) TO DBManager;


--The folowing procedure revokes the Student role from a student, along with their entry in the
-- classdb.Student table. If the Student role was the only role that the student was a member
-- of, the student's schema, and the objects contained within, are removed along with the the
-- role representing the student.
CREATE OR REPLACE FUNCTION classdb.dropStudent(userName NAME) RETURNS VOID AS
$$
DECLARE
    userExists BOOLEAN;
    hasOtherRoles BOOLEAN;
BEGIN
    EXECUTE format('SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = %L', userName) INTO userExists;
    IF
        userExists AND
        pg_has_role(userName, 'student', 'member')
    THEN
        EXECUTE format('REVOKE Student FROM %I', userName);
        EXECUTE format('DELETE FROM classdb.Student S WHERE S.userName = %L', userName);
        EXECUTE format('SELECT 1 FROM pg_catalog.pg_roles WHERE pg_has_role(%L, oid, ''member'')'
            || 'AND rolname != %L', userName, userName) INTO hasOtherRoles;
        IF hasOtherRoles THEN
            RAISE NOTICE 'User "%" is a member of one or more additional roles', userName;
        ELSE
            EXECUTE format('DROP SCHEMA %I CASCADE', userName);
            EXECUTE format('DROP ROLE %I', userName);
        END IF;
    ELSE
        RAISE NOTICE 'User "%" is not a registered student', userName;
    END IF;
END
$$  LANGUAGE plpgsql
    SECURITY DEFINER;

REVOKE ALL ON FUNCTION classdb.dropStudent(userName NAME) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION classdb.dropStudent(userName NAME) TO DBManager;
GRANT EXECUTE ON FUNCTION classdb.dropStudent(userName NAME) TO Instructor;


--The folowing procedure revokes the Instructor role from an Instructor, along with their entry
-- in the classdb.Instructor table. If the Instructor role was the only role that the
-- instructor was a member of, the instructor's schema, and the objects contained within, are
-- removed along with the the role representing the instructor.
CREATE OR REPLACE FUNCTION classdb.dropInstructor(userName NAME) RETURNS VOID AS
$$
DECLARE
    userExists BOOLEAN;
    hasOtherRoles BOOLEAN;
BEGIN
    EXECUTE format('SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = %L', userName) INTO userExists;
    IF
        userExists AND
        pg_has_role(userName, 'instructor', 'member')
    THEN
        EXECUTE format('REVOKE Instructor FROM %I', userName);
        EXECUTE format('DELETE FROM classdb.Instructor S WHERE S.userName = %L', userName);
        EXECUTE format('SELECT 1 FROM pg_catalog.pg_roles WHERE pg_has_role(%L, oid, ''member'')'
            || 'AND rolname != %L', userName, userName) INTO hasOtherRoles;
        IF hasOtherRoles THEN
            RAISE NOTICE 'User "%" remains a member of one or more additional roles', userName;
        ELSE
            EXECUTE format('DROP SCHEMA %I CASCADE', userName);
            EXECUTE format('DROP ROLE %I', userName);
        END IF;
    ELSE
        RAISE NOTICE 'User "%" is not a registered instructor', userName;
    END IF;
END
$$  LANGUAGE plpgsql
    SECURITY DEFINER;

REVOKE ALL ON FUNCTION classdb.dropStudent(userName NAME) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION classdb.dropStudent(userName NAME) TO DBManager;


--The following procedure sets a user's search_path to a new specified search_path. An
-- notice is raised if the user does not exist.
CREATE OR REPLACE FUNCTION classdb.setSearchPath(userName NAME, newPath TEXT) RETURNS VOID AS
$$
DECLARE
    userExists BOOLEAN;
BEGIN
    EXECUTE format('SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = %L', userName) INTO userExists;
    IF
        userExists
    THEN
        EXECUTE format('ALTER USER %I SET search_path = %L', userName, newPath);
    ELSE
        RAISE NOTICE 'User "%" does not exist', userName;
    END IF;
END
$$  LANGUAGE plpgsql
    SECURITY DEFINER;

REVOKE ALL ON FUNCTION classdb.setSearchPath(userName NAME, newPath TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION classdb.setSearchPath(userName NAME, newPath TEXT) TO DBManager;
GRANT EXECUTE ON FUNCTION classdb.setSearchPath(userName NAME, newPath TEXT) TO Instructor;


--The following tables hold the list of currently registered students and instructors
CREATE TABLE classdb.Student
(
	userName NAME NOT NULL PRIMARY KEY,
	studentName VARCHAR(100),
    schoolID VARCHAR(20)
);

CREATE TABLE classdb.Instructor
(
	userName NAME NOT NULL PRIMARY KEY,
	instructorName VARCHAR(100)
);
