--Andrew Figueroa
--
--createGroups.sql
--
--Users and Roles for CS205; Created: 2017-05-29; Modified 2017-06-01

--This script should be run as a superuser or equivalent role, due to the functions being
-- declared SECURITY DEFINER, along with the need to properly set object ownership.

--This script creates roles for students, instructors, and admins. Then, sudents are prevented
-- from modiying the public schema, and an admin schema is created. Following that, a stored
-- procedure for creating any type of user is defined. Finally, procedures for creating and
-- dropping students and instructors are defined. Currently this script also creates Student
-- and Instructor tables in the admin schema.

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
CREATE SCHEMA admin;

--Allows appropriate users to connect to the database
GRANT CONNECT ON DATABASE current_database() TO DBManager;
GRANT CONNECT ON DATABASE current_database() TO Instructor;
GRANT CONNECT ON DATABASE current_database() TO Student;

--The following procedure creates a user, given a username and password. It also creates a
-- schema for the new user and gives them appropriate permissions for that schema.
CREATE OR REPLACE FUNCTION createUser(userName VARCHAR(25), password VARCHAR(128)) RETURNS VOID AS
$$
DECLARE
    userExists BOOLEAN;
BEGIN
    EXECUTE format('SELECT 1 FROM pg_roles WHERE rolname = %L', userName) INTO userExists;
    IF userExists THEN
        RAISE EXCEPTION 'User: "%" already exists', userName;
    ELSE
        userName := lower(userName);
        EXECUTE format('CREATE USER %I ENCRYPTED PASSWORD %L', userName, password);
        EXECUTE format('CREATE SCHEMA %I', userName);
        EXECUTE format('GRANT ALL PRIVILEGES ON SCHEMA %I TO %I', userName, userName);
        EXECUTE format('ALTER USER %I SET search_path = %I', userName, userName);
    END IF;
END
$$ LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = public, pg_catalog, pg_temp;
REVOKE ALL ON FUNCTION createUser(userName VARCHAR(25), password VARCHAR(128)) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION createUser(userName VARCHAR(25), password VARCHAR(128)) TO Admin;


--Creates a role for a student given a username and password. This procedure gives both the
-- student and Instructors appropriate privilages.
CREATE OR REPLACE FUNCTION createStudent(ID VARCHAR(20), userName VARCHAR(25), name VARCHAR(100)) RETURNS VOID AS
$$
BEGIN
  PERFORM createUser(userName, ID);
  EXECUTE format('GRANT Student TO %I', lower(userName));
  EXECUTE format('GRANT USAGE ON SCHEMA %I TO Instructor', userName);
  EXECUTE format('INSERT INTO Student VALUES(%L, %L, %L)', ID, lower(userName), name);
END
$$  LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = admin, public, pg_catalog, pg_temp;
REVOKE ALL ON FUNCTION createStudent(ID VARCHAR(20), userName VARCHAR(25), name VARCHAR(100)) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION createStudent(ID VARCHAR(20), userName VARCHAR(25), name VARCHAR(100)) TO Admin;
GRANT EXECUTE ON FUNCTION createStudent(ID VARCHAR(20), userName VARCHAR(25), name VARCHAR(100)) TO Instructor;


--Creates a role for an instructor given a username and password. The procedure also
-- adds this new instuctor to the appropriate group, but does not create any schemas.
CREATE OR REPLACE FUNCTION createInstructor(ID VARCHAR(20), userName VARCHAR(25), name VARCHAR(100)) RETURNS VOID AS
$$
BEGIN
  PERFORM createUser(userName, ID);
  EXECUTE format('GRANT Instructor TO %I', lower(userName));
  EXECUTE format('INSERT INTO Instructor VALUES(%L, %L, %L)', ID, lower(userName), name);
END
$$  LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = admin, public, pg_catalog, pg_temp;
REVOKE ALL ON FUNCTION createInstructor(ID VARCHAR(20), userName VARCHAR(25), name VARCHAR(100)) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION createInstructor(ID VARCHAR(20), userName VARCHAR(25), name VARCHAR(100)) TO Admin;

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
    SET search_path = admin, public, pg_catalog, pg_temp;
REVOKE ALL ON FUNCTION dropStudent(userName VARCHAR(25)) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION dropStudent(userName VARCHAR(25)) TO Admin;
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
    SET search_path = admin, public, pg_catalog, pg_temp;
REVOKE ALL ON FUNCTION dropStudent(userName VARCHAR(25)) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION dropStudent(userName VARCHAR(25)) TO Admin;

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
GRANT EXECUTE ON FUNCTION setCS205SearchPath(userName VARCHAR(25)) TO Admin;
GRANT EXECUTE ON FUNCTION setCS205SearchPath(userName VARCHAR(25)) TO Instructor;


--The following tables hold the list of currently registered students and instructors
CREATE TABLE admin.Student
(
	ID VARCHAR(20) PRIMARY KEY,
	UserName VARCHAR(25),
	Name VARCHAR(100)
);

CREATE TABLE admin.Instructor
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
