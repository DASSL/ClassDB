--addUserMgmt.sql - ClassDB

--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab (DASSL), Western Connecticut State University (WCSU)

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.

--This script requires the current user to be a superuser

--This script should be run after initializeDB.sql

--This script will create all procedures used to manage ClassDB users

START TRANSACTION;


--Make sure the current user has sufficient privilege to run this script
-- privileges required: superuser
DO
$$
BEGIN
   IF NOT classdb.isSuperUser() THEN
      RAISE EXCEPTION 'Insufficient privileges: script must be run as a user with'
                        ' superuser privileges';
   END IF;
END
$$;


--Suppress NOTICE messages for this script only, this will not apply to functions
-- defined within. This hides messages that are unimportant, but possibly confusing
SET LOCAL client_min_messages TO WARNING;


DROP FUNCTION IF EXISTS classdb.createUser(userName VARCHAR(63), initialPwd VARCHAR(128));
--Define a function to create a user with the name and password supplied
-- set user name as the initial password if pwd supplied is NULL
-- also create a user-specific schema and give them all rights on their schema
-- exceptions: a user/schema already exists w/ same name as the user name supplied
CREATE FUNCTION
   classdb.createUser(userName VARCHAR(63), initialPwd VARCHAR(128)) RETURNS VOID AS
$$
BEGIN
   IF classdb.isRoleDefined($1) THEN
      RAISE NOTICE 'User "%" already exists, password not modified', $1;
   ELSE
      EXECUTE
         format('CREATE USER %s ENCRYPTED PASSWORD %L', $1, COALESCE($2, $1));
   END IF;

   IF EXISTS(SELECT * FROM pg_catalog.pg_namespace WHERE nspname = classdb.foldPgID($1))
      THEN
      RAISE NOTICE 'Schema "%" already exists', $1;
   ELSE
      EXECUTE format('CREATE SCHEMA %s', $1);
      EXECUTE format('GRANT ALL PRIVILEGES ON SCHEMA %s TO %s', $1, $1);
   END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;


--Make ClassDB the function owner so it runs with that role's privileges
ALTER FUNCTION
   classdb.createUser(userName VARCHAR(63), initialPwd VARCHAR(128))
   OWNER TO ClassDB;

--Prevent everyone from executing the function
REVOKE ALL ON FUNCTION
   classdb.createUser(userName VARCHAR(63), initialPwd VARCHAR(128))
   FROM PUBLIC;



--Define a table to track student users: each student gets their own login role
CREATE TABLE IF NOT EXISTS classdb.Student
(
   userName VARCHAR(63) NOT NULL PRIMARY KEY, --student-specific server role
   studentName VARCHAR(100) NOT NULL, --student's given name
   schoolID VARCHAR(20), --a school-issued ID
   lastDDLActivity TIMESTAMP, --UTC date and time of the last DDL operation
   lastDDLOperation VARCHAR(64), --last DDL operation the student performed
   lastDDLObject VARCHAR(256), --name of the object of the DDL operation
   DDLCount INT DEFAULT 0, --number of DDL operations the student has made
   lastConnection TIMESTAMP, --UTC date and time of the last connection
   connectionCount INT DEFAULT 0 --number of connections (ever) so far
);

--Change table's owner so ClassDB can perform any operation on it
ALTER TABLE classdb.Student OWNER TO ClassDB;

--Prevent everyone from doing anything with the table
REVOKE ALL PRIVILEGES ON classdb.Student FROM PUBLIC;

--Permit instructors and DB managers to read rows and to update only some columns
-- username cannot be edited by anyone because its value must match a login role
-- inserts and deletes are performed only in functions which run as ClassDB
GRANT SELECT ON classdb.Student
   TO ClassDB_Instructor, ClassDB_DBManager;

GRANT UPDATE (studentName, schoolID) ON classdb.Student
   TO ClassDB_Instructor, ClassDB_DBManager;


DROP FUNCTION IF EXISTS classdb.createStudent(studentUserName VARCHAR(63),
                        studentName VARCHAR(100), schoolID VARCHAR(20),
                        initialPwd VARCHAR(128));
--Define a function to register a student user and associate w/ group role Student
-- schoolID and initialPwd are optional
-- give Instructors read access to the student-specific schema
-- limit number of concurrent connections and set time-out period for each query
-- record the user name in the Student table
CREATE FUNCTION
   classdb.createStudent(studentUserName VARCHAR(63), studentName VARCHAR(100),
                         schoolID VARCHAR(20) DEFAULT NULL,
                         initialPwd VARCHAR(128) DEFAULT NULL) RETURNS VOID AS
$$
BEGIN
   PERFORM classdb.createUser(studentUserName, initialPwd);
   EXECUTE format('GRANT ClassDB_Student TO %s', $1);
   EXECUTE format('GRANT USAGE ON SCHEMA %s TO ClassDB_Instructor', $1);
   EXECUTE format('GRANT %s TO ClassDB', $1);
   EXECUTE format('ALTER DEFAULT PRIVILEGES FOR ROLE %s IN SCHEMA %s GRANT SELECT'
                   || ' ON TABLES TO ClassDB_Instructor', $1, $1);
   EXECUTE format('ALTER ROLE %s CONNECTION LIMIT 5', $1);
   EXECUTE format('ALTER ROLE %s SET statement_timeout = 2000', $1);

   --Change studentname to match the given value if username is already stored
   INSERT INTO classdb.Student VALUES(classdb.foldPgID($1), $2, $3)
          ON CONFLICT (username) DO UPDATE SET studentname = $2;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;

--Make ClassDB the function owner so the function runs w/ that role's privileges
ALTER FUNCTION
   classdb.createStudent(studentUserName VARCHAR(63), studentName VARCHAR(100),
                         schoolID VARCHAR(20), initialPwd VARCHAR(128))
   OWNER TO ClassDB;

--Prevent everyone from executing the function
REVOKE ALL ON FUNCTION
   classdb.createStudent(studentUserName VARCHAR(63), studentName VARCHAR(100),
                         schoolID VARCHAR(20), initialPwd VARCHAR(128))
   FROM PUBLIC;

--Allow only instructors and db managers to execute the function
GRANT EXECUTE ON FUNCTION
   classdb.createStudent(studentUserName VARCHAR(63), studentName VARCHAR(100),
                         schoolID VARCHAR(20), initialPwd VARCHAR(128))
   TO ClassDB_Instructor, ClassDB_DBManager;


--Define a table to track instructors who use DB: each instr. gets a login role
CREATE TABLE IF NOT EXISTS classdb.Instructor
(
   userName VARCHAR(63) NOT NULL PRIMARY KEY, --instructor's login role
   instructorName VARCHAR(100) NOT NULL --instructor's given name
);

--Change table ownership to ClassDB
ALTER TABLE classdb.Instructor OWNER TO ClassDB;

--Limit operations on rows and columns
REVOKE ALL PRIVILEGES ON classdb.Instructor FROM PUBLIC;

GRANT SELECT ON classdb.Instructor
   TO ClassDB_Instructor, ClassDB_DBManager;

GRANT UPDATE (instructorName) ON classdb.Instructor
   TO ClassDB_Instructor, ClassDB_DBManager;


DROP FUNCTION IF EXISTS classdb.createInstructor(instructorUserName VARCHAR(63),
                        instructorName VARCHAR(100), initialPwd VARCHAR(128));
--Define a function to register an instructor user and associate w/ Instructor role
-- initial password is optional
-- record the user name in the Instructor table
CREATE FUNCTION
   classdb.createInstructor(instructorUserName VARCHAR(63),
                            instructorName VARCHAR(100),
                            initialPwd VARCHAR(128) DEFAULT NULL) RETURNS VOID AS
$$
BEGIN
   PERFORM classdb.createUser(instructorUserName, initialPwd);
   EXECUTE format('GRANT ClassDB_Instructor TO %s', $1);
   EXECUTE format('GRANT %s TO ClassDB', $1);
   EXECUTE format('ALTER DEFAULT PRIVILEGES FOR ROLE %s IN SCHEMA public GRANT SELECT'
                   || ' ON TABLES TO PUBLIC', $1);
   INSERT INTO classdb.Instructor VALUES(classdb.foldPgID($1), $2)
          ON CONFLICT (username) DO UPDATE SET instructorName = $2;

END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;

--Change function ownership and set execution permissions
ALTER FUNCTION
   classdb.createInstructor(instructorUserName VARCHAR(63),
                            instructorName VARCHAR(100), initialPwd VARCHAR(128))
   OWNER TO ClassDB;

REVOKE ALL ON FUNCTION
   classdb.createInstructor(instructorUserName VARCHAR(63),
                            instructorName VARCHAR(100), initialPwd VARCHAR(128))
   FROM PUBLIC;

GRANT EXECUTE ON FUNCTION
   classdb.createInstructor(instructorUserName VARCHAR(63),
                            instructorName VARCHAR(100), initialPwd VARCHAR(128))
   TO ClassDB_Instructor, ClassDB_DBManager;


DROP FUNCTION IF EXISTS classdb.createDBManager(managerUserName VARCHAR(63),
                        initialPwd VARCHAR(128));
--Define a function to register a user in the DBManager role
-- initial password is optional
CREATE FUNCTION
   classdb.createDBManager(managerUserName VARCHAR(63),
                           initialPwd VARCHAR(128) DEFAULT NULL) RETURNS VOID AS
$$
BEGIN
   PERFORM classdb.createUser(managerUserName, initialPwd);
   EXECUTE format('GRANT ClassDB_DBManager TO %s', $1);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;

--Change function ownership and set execution permissions
ALTER FUNCTION
   classdb.createDBManager(managerUserName VARCHAR(63), initialPwd VARCHAR(128))
   OWNER TO ClassDB;

REVOKE ALL ON FUNCTION
   classdb.createDBManager(managerUserName VARCHAR(63), initialPwd VARCHAR(128))
   FROM PUBLIC;

GRANT EXECUTE ON FUNCTION
   classdb.createDBManager(managerUserName VARCHAR(63), initialPwd VARCHAR(128))
   TO ClassDB_Instructor, ClassDB_DBManager;


DROP FUNCTION IF EXISTS classdb.dropStudent(userName VARCHAR(63));
--Define a function to revoke Student role from a user
-- remove the entry for user from table classdb.Student
-- remove user's schema and contained objects if Student role was user's only role
CREATE FUNCTION classdb.dropStudent(userName VARCHAR(63)) RETURNS VOID AS
$$
BEGIN
   IF classdb.isRoleDefined($1) AND
      pg_catalog.pg_has_role(classdb.foldPgID($1), 'classdb_student', 'member')
   THEN
      EXECUTE format('REVOKE ClassDB_Student FROM %s', $1);
      DELETE FROM classdb.Student S WHERE S.userName = classdb.foldPgID($1);

      IF EXISTS(SELECT * FROM pg_catalog.pg_roles
                WHERE pg_catalog.pg_has_role(classdb.foldPgID($1), oid, 'member') AND
                      rolname != classdb.foldPgID($1)
               ) THEN
         RAISE NOTICE 'User "%" remains a member of one or more additional roles', $1;
      ELSE
         EXECUTE format('DROP SCHEMA %s CASCADE', $1);
         EXECUTE format('DROP ROLE %s', $1);
      END IF;
   ELSE
      RAISE NOTICE 'User "%" is not a registered student', $1;
   END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;

--Change function ownership and set execution permissions
ALTER FUNCTION classdb.dropStudent(userName VARCHAR(63)) OWNER TO ClassDB;
REVOKE ALL ON FUNCTION classdb.dropStudent(userName VARCHAR(63)) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION classdb.dropStudent(userName VARCHAR(63))
   TO ClassDB_Instructor, ClassDB_DBManager;


DROP FUNCTION IF EXISTS classdb.dropAllStudents();
--Define a function to drop all students presently registered
-- simply call function dropStudent for each row in classdb.Student
CREATE FUNCTION classdb.dropAllStudents() RETURNS VOID AS
$$
BEGIN
   PERFORM classdb.dropStudent(S.userName) FROM classdb.Student S;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;

--Change function ownership and set execution permissions
ALTER FUNCTION classdb.dropAllStudents() OWNER TO ClassDB;
REVOKE ALL ON FUNCTION classdb.dropAllStudents() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION classdb.dropAllStudents()
   TO ClassDB_Instructor, ClassDB_DBManager;


DROP FUNCTION IF EXISTS classdb.dropInstructor(userName VARCHAR(63));
--The folowing procedure revokes the Instructor role from an Instructor, along
-- with their entry in the classdb.Instructor table. If the Instructor role was
-- the only role that the instructor was a member of, the instructor's schema,
-- and the objects contained within, are removed along with the the role
-- representing the instructor.
CREATE FUNCTION classdb.dropInstructor(userName VARCHAR(63)) RETURNS VOID AS
$$
BEGIN
   IF classdb.isRoleDefined($1) AND
      pg_catalog.pg_has_role(classdb.foldPgID($1), 'classdb_instructor', 'member')
   THEN
      EXECUTE format('REVOKE ClassDB_Instructor FROM %s', $1);
      DELETE FROM classdb.Instructor S WHERE S.userName = classdb.foldPgID($1);
      IF EXISTS(SELECT * FROM pg_catalog.pg_roles
                WHERE pg_catalog.pg_has_role(classdb.foldPgID($1), oid, 'member') AND
                      rolname != classdb.foldPgID($1)
               ) THEN
         RAISE NOTICE 'User "%" remains a member of one or more additional roles', $1;
      ELSE
         EXECUTE format('ALTER DEFAULT PRIVILEGES FOR ROLE %s IN SCHEMA public'
                 ||' REVOKE SELECT ON TABLES FROM PUBLIC;', $1);
         EXECUTE format('DROP SCHEMA %s CASCADE', $1);
         EXECUTE format('DROP ROLE %s', $1);
      END IF;
   ELSE
      RAISE NOTICE 'User "%" is not a registered instructor', $1;
   END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;

--Change function ownership and set execution permissions
ALTER FUNCTION classdb.dropInstructor(userName VARCHAR(63)) OWNER TO ClassDB;
REVOKE ALL ON FUNCTION classdb.dropInstructor(userName VARCHAR(63)) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION classdb.dropInstructor(userName VARCHAR(63))
   TO ClassDB_Instructor, ClassDB_DBManager;


DROP FUNCTION IF EXISTS classdb.dropDBManager(userName VARCHAR(63));
--The folowing procedure revokes the DBManager role from a DBManager. If the
-- DBManager role was the only role that they were a member of, the manager's
-- schema, and the objects contained within, are removed along with the the role
-- representing the DBManager.
CREATE FUNCTION classdb.dropDBManager(userName VARCHAR(63)) RETURNS VOID AS
$$
BEGIN
   IF classdb.isRoleDefined($1) AND
      pg_catalog.pg_has_role(classdb.foldPgID($1), 'classdb_dbmanager', 'member')
   THEN
      EXECUTE format('REVOKE ClassDB_DBManager FROM %s', userName);
      IF EXISTS(SELECT * FROM pg_catalog.pg_roles
                WHERE pg_catalog.pg_has_role(classdb.foldPgID($1), oid, 'member') AND
                      rolname != classdb.foldPgID($1)
               ) THEN
         RAISE NOTICE 'User "%" remains a member of one or more additional roles', $1;
      ELSE
         EXECUTE format('DROP SCHEMA %s CASCADE', $1);
         EXECUTE format('DROP ROLE %s', $1);
      END IF;
   ELSE
      RAISE NOTICE 'User "%" is not a registered DBManager', $1;
   END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;

--Change function ownership and set execution permissions
ALTER FUNCTION classdb.dropDBManager(userName VARCHAR(63)) OWNER TO ClassDB;
REVOKE ALL ON FUNCTION classdb.dropDBManager(userName VARCHAR(63)) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION classdb.dropDBManager(userName VARCHAR(63))
   TO ClassDB_Instructor, ClassDB_DBManager;



--Define a function to reset a user's password to a default value
-- default password is the username: it is not necessarily the same as the
-- initial password used at role creation
DROP FUNCTION IF EXISTS classdb.resetUserPassword(userName VARCHAR(63));
CREATE FUNCTION classdb.resetUserPassword(userName VARCHAR(63))
   RETURNS VOID AS
$$
BEGIN
   IF classdb.isRoleDefined($1) THEN
      EXECUTE format('ALTER ROLE %s ENCRYPTED PASSWORD %L', userName, userName);
   ELSE
      RAISE NOTICE 'User "%" not found among registered users', userName;
   END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;

--Change function ownership and set execution permissions
ALTER FUNCTION
   classdb.resetUserPassword(userName VARCHAR(63))
   OWNER TO ClassDB;

REVOKE ALL ON FUNCTION
   classdb.resetUserPassword(userName VARCHAR(63))
   FROM PUBLIC;

GRANT EXECUTE ON FUNCTION
   classdb.resetUserPassword(userName VARCHAR(63))
   TO ClassDB_Instructor, ClassDB_DBManager;


COMMIT;