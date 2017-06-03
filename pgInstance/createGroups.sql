--Andrew Figueroa
--
--createGroups.sql
--
--Users and Roles for CS205; Created: 2017-05-29; Modified 2017-06-02

--This script should be run as a superuser or equivalent role, due to the functions being
-- declared SECURITY DEFINER, along with the need to properly set object ownership.

--This script creates roles for students, instructors, and database managers (administrators).
-- Then, sudents are prevented from modiying the public schema, and a classdb schema is created.
-- Following that, a stored procedure for creating any type of user is defined. Finally,
-- procedures for creating and dropping students and instructors are defined. Currently this
-- script also creates Student and Instructor tables in the classdb schema.

--TODO: Test for to see if current user is a superuser or equivalent; raise exception if not

--Group equivalent for managing permissions for students
CREATE ROLE Student;
--Removes the ability for students to modify the "public" schema for the current database
REVOKE CREATE ON SCHEMA public FROM Student;

--Group equivalent for managing permissions for instructors
CREATE ROLE Instructor;

--Group equivalent for managing permissions for users who manage the database
CREATE ROLE DBManager;
--Creates a schema for holding administrative information
CREATE SCHEMA classdb;

--Allows appropriate users to connect to the database
GRANT CONNECT ON DATABASE current_database() TO DBManager;
GRANT CONNECT ON DATABASE current_database() TO Instructor;
GRANT CONNECT ON DATABASE current_database() TO Student;

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
    --EXECUTE format('INSERT INTO classdb.Student VALUES(%L, %L, %L)', schoolID, userName, studentName);
END
$$  LANGUAGE plpgsql
    SECURITY DEFINER;

REVOKE ALL ON FUNCTION classdb.createStudent(userName NAME, studentName VARCHAR(100),
    schoolID VARCHAR(20) DEFAULT NULL, initialPassword TEXT DEFAULT NULL) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION classdb.createStudent(userName NAME, studentName VARCHAR(100),
    schoolID VARCHAR(20) DEFAULT NULL, initialPassword TEXT DEFAULT NULL) TO DBManager;
GRANT EXECUTE ON FUNCTION classdb.createStudent(userName NAME, studentName VARCHAR(100),
    schoolID VARCHAR(20) DEFAULT NULL, initialPassword TEXT DEFAULT NULL) TO Instructor;


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
    --EXECUTE format('INSERT INTO classdb.Instructor VALUES(%L, %L, %L)', ID, userName, name);
END
$$  LANGUAGE plpgsql
    SECURITY DEFINER;

REVOKE ALL ON FUNCTION classdb.createInstructor(userName NAME, instructorName VARCHAR(100),
    initialPassword TEXT DEFAULT NULL) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION classdb.createInstructor(userName NAME, instructorName VARCHAR(100),
    initialPassword TEXT DEFAULT NULL) TO DBManager;

--The folowing procedure removes a student. The student's schema, and the objects contained within
-- are removed, along with the the role representing the student, and the student's entry in
-- the Student table.
CREATE OR REPLACE FUNCTION dropStudent(userName VARCHAR(25)) RETURNS VOID AS
$$
DECLARE
    userExists BOOLEAN;
BEGIN
    EXECUTE format('SELECT 1 FROM pg_roles WHERE rolname = %L', userName) INTO userExists;
    IF
        userExists AND
        pg_has_role(userName, 'student', 'member')
    THEN
        EXECUTE format('DROP SCHEMA %I CASCADE', userName);
        EXECUTE format('DELETE FROM Student S WHERE S.userName = %L', userName);
        EXECUTE format('DROP ROLE %I', userName);
    ELSE
        RAISE EXCEPTION 'User: "%" is not a registered student', userName;
    END IF;
END
$$  LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = classdb, public, pg_catalog, pg_temp;
REVOKE ALL ON FUNCTION dropStudent(userName VARCHAR(25)) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION dropStudent(userName VARCHAR(25)) TO DBManager;
GRANT EXECUTE ON FUNCTION dropStudent(userName VARCHAR(25)) TO Instructor;

--The folowing procedure removes a instructor. The instructor's schema, and the objects contained
-- within are removed, along with the the role representing the instructor, and the instructor's
-- entry in the instructor table.
CREATE OR REPLACE FUNCTION dropInstructor(userName VARCHAR(25)) RETURNS VOID AS
$$
DECLARE
    userExists BOOLEAN;
BEGIN
    EXECUTE format('SELECT 1 FROM pg_roles WHERE rolname = %L', userName) INTO userExists;
    IF
        userExists AND
        pg_has_role(userName, 'instructor', 'member')
    THEN
        EXECUTE format('DROP SCHEMA %I CASCADE', userName);
        EXECUTE format('DELETE FROM Instructor S WHERE S.userName = %L', userName);
        EXECUTE format('DROP ROLE %I', userName);
    ELSE
        RAISE EXCEPTION 'User: "%" is not a registered instructor', userName;
    END IF;
END
$$  LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = classdb, public, pg_catalog, pg_temp;
REVOKE ALL ON FUNCTION dropStudent(userName VARCHAR(25)) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION dropStudent(userName VARCHAR(25)) TO DBManager;

--The following procedure sets a user's search_path to "$userName, shelter, pvfc, public". An
-- exception is raised if the user does not exist.
CREATE OR REPLACE FUNCTION setCS205SearchPath(userName VARCHAR(25)) RETURNS VOID AS
$$
DECLARE
    userExists BOOLEAN;
BEGIN
    EXECUTE format('SELECT 1 FROM pg_roles WHERE rolname = %L', userName) INTO userExists;
    IF
        userExists
    THEN
        EXECUTE format('ALTER USER %I SET search_path = %I, shelter, pvfc, public', userName, userName);
    ELSE
        RAISE EXCEPTION 'User: "%" does not exist', userName;
    END IF;
END
$$  LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = public, pg_catalog, pg_temp;
REVOKE ALL ON FUNCTION setCS205SearchPath(userName VARCHAR(25)) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION setCS205SearchPath(userName VARCHAR(25)) TO DBManager;
GRANT EXECUTE ON FUNCTION setCS205SearchPath(userName VARCHAR(25)) TO Instructor;


--The following tables hold the list of currently registered students and instructors
CREATE TABLE classdb.Student
(
	ID VARCHAR(20) PRIMARY KEY,
	UserName VARCHAR(25),
	Name VARCHAR(100)
);

CREATE TABLE classdb.Instructor
(
	ID VARCHAR(20) PRIMARY KEY,
	UserName VARCHAR(25),
	Name VARCHAR(100)
);


--Creates a sample student and instructor
--SELECT createStudent('Ramsey033', '50045123');
--SELECT createInstructor('WestP', '123999888');

--Note that in order to drop the roles, all objects beloging to the role must also be
-- dropped before doing so.
