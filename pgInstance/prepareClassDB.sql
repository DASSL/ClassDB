--prepareClassDB.sql - ClassDB

--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab (DASSL), Western Connecticut State University (WCSU)

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.

--This script has been recently updated to always quote role names, but has not been tested.
-- There is a significant probablility of it not working correctly.

--This script should be run as a user with createrole privileges

--This script should be run after running the script "prepareClassServer.sql"

--This script first prevents student roles from modiying the public schema, and then creates a
-- classdb schema. Following that, a stored procedure for creating any type of user is defined,
-- along with procedures for creating and dropping students and instructors. Finally,
-- procedures for resetting a users password are created. This script also creates Student and
-- Instructor tables in the classdb schema, and an event trigger that records the timestamp of
-- the last ddl statement issued by each student.


START TRANSACTION;

--Make sure the current user has sufficient privilege to run this script
-- privileges required: CREATEROLE
DO
$$
BEGIN
   IF NOT EXISTS (SELECT * FROM pg_catalog.pg_roles
                  WHERE rolname = current_user AND rolcreaterole = TRUE
                 ) THEN
      RAISE EXCEPTION
         'Insufficient privileges: script must be run as a user with createrole privileges';
   END IF;
END
$$;


--Make sure the expected app-specific roles are already defined:
-- roles expected: ClassDB, Student, Instructor, DBManager
DO
$$
BEGIN
   IF NOT EXISTS (SELECT * FROM pg_catalog.pg_roles
                  WHERE rolname IN ('ClassDB', 'Instructor', 'DBManager', 'Student')
                 ) THEN
      RAISE EXCEPTION
         'Missing group roles: one or more expected group roles are undefined';
   END IF;
END
$$;


--Grant appropriate privileges to different roles to the current database
DO
$$
DECLARE
   currentDB VARCHAR(128);
BEGIN
   currentDB := current_database();

   --Disallow DB connection to all users
   -- Postgres grants CONNECT to all by default
   EXECUTE format('REVOKE CONNECT ON DATABASE %I FROM PUBLIC', currentDB);

   --Let only app-specific roles connect to the DB
   -- no need for ClassDB to connect to the DB
   EXECUTE
      format('GRANT CONNECT ON DATABASE %I TO "Student", "Instructor", "DBManager"', currentDB);

   --Allow ClassDB to create schemas on the current database
   -- all schema-creation operations are done only by this role in this app
   EXECUTE format('GRANT CREATE ON DATABASE %I TO "ClassDB"', currentDB);
END
$$;

--Prevent students from modifying the public schema
-- public schema contains objects and functions students can read
REVOKE CREATE ON SCHEMA public FROM "Student";

--Create a schema to hold app's admin info and assign privileges on that schema
CREATE SCHEMA IF NOT EXISTS classdb;
GRANT ALL PRIVILEGES ON SCHEMA classdb TO "ClassDB", "Instructor", "DBManager";

--Grant ClassDB to the current user (the one runnning the script)
-- This allows altering of objected even after they are owned by ClassDB
GRANT "ClassDB" TO current_user;


--Define a function to create a user with the name and password supplied
-- set user name as the initial password if pwd supplied is NULL
-- also create a user-specific schema and give them all rights on their schema
-- exceptions: a user/schema already exists w/ same name as the user name supplied
CREATE OR REPLACE FUNCTION
   classdb.createUser(userName VARCHAR(50), initialPwd VARCHAR(128)) RETURNS VOID AS
$$
BEGIN
   IF EXISTS(SELECT * FROM pg_catalog.pg_roles WHERE rolname = $1) THEN
      RAISE NOTICE 'User "%" already exists, password not modified', $1;
   ELSE
      EXECUTE
         format('CREATE USER %I ENCRYPTED PASSWORD %L', $1, COALESCE($2, $1));
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


--Make ClassDB the function owner so it runs with that role's privileges
ALTER FUNCTION
   classdb.createUser(userName VARCHAR(50), initialPwd VARCHAR(128))
   OWNER TO "ClassDB";

--Prevent everyone from executing the function
REVOKE ALL ON FUNCTION
   classdb.createUser(userName VARCHAR(50), initialPwd VARCHAR(128))
   FROM PUBLIC;

--Allow only instructors and db managers to execute the function
GRANT EXECUTE ON FUNCTION
   classdb.createUser(userName VARCHAR(50), initialPwd VARCHAR(128))
   TO "Instructor", "DBManager";


--Define a table to track student users: each student gets their own login role
CREATE TABLE IF NOT EXISTS classdb.Student
(
   userName VARCHAR(50) NOT NULL PRIMARY KEY, --student-specific server role
   studentName VARCHAR(100) NOT NULL, --student's given name
   schoolID VARCHAR(20), --a school-issued ID
   lastDDLActivity TIMESTAMP, --UTC date and time of the last DDL operation
   lastDDLOperation VARCHAR(64), --the last DDL operation the student performed
   lastDDLObject VARCHAR(256), --the name of the object of the DDL operation
   DDLCount INT DEFAULT 0, --number of DDL operations the student has made so far
   lastConnection TIMESTAMP, --UTC date and time of the last connection
   connectionCount INT DEFAULT 0 --number of connections (ever) so far
);


--Change table's owner so ClassDB can perform any operation on it
ALTER TABLE classdb.Student OWNER TO "ClassDB";

--Prevent everyone from doing anything with the table
REVOKE ALL PRIVILEGES ON classdb.Student FROM PUBLIC;

--Permit instructors and DB managers to read rows and to update only some columns
-- username cannot be edited by anyone because its value must match a login role
-- inserts and deletes are performed only in functions which run as ClassDB
GRANT SELECT ON classdb.Student TO "Instructor", "DBManager";
GRANT UPDATE (studentName, schoolID) ON classdb.Student TO "Instructor", "DBManager";


--Define a function to register a student user and associate w/ group role Student
-- schoolID and initialPwd are optional
-- give Instructors read access to the student-specific schema
-- limit number of concurrent connections and set time-out period for each query
-- record the user name in the Student table
CREATE OR REPLACE FUNCTION
   classdb.createStudent(studentUserName VARCHAR(50), studentName VARCHAR(100),
                         schoolID VARCHAR(20) DEFAULT NULL,
						 initialPwd VARCHAR(128) DEFAULT NULL) RETURNS VOID AS
$$
BEGIN
   PERFORM classdb.createUser(studentUserName, initialPwd);
   EXECUTE format('GRANT "Student" TO %I', $1);
   EXECUTE format('GRANT USAGE ON SCHEMA %I TO "Instructor"', $1);
   EXECUTE format('ALTER ROLE %I CONNECTION LIMIT 5', $1);
   EXECUTE format('ALTER ROLE %I SET statement_timeout = 2000', $1);

   --Change studentname to match the given value if username is already stored
   INSERT INTO classdb.Student VALUES($1, $2, $3)
          ON CONFLICT (username) DO UPDATE SET studentname = $2;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;

--Make ClassDB the function owner so the function runs w/ that role's privileges
ALTER FUNCTION
   classdb.createStudent(studentUserName VARCHAR(50), studentName VARCHAR(100),
                         schoolID VARCHAR(20), initialPwd VARCHAR(128))
   OWNER TO "ClassDB";

--Prevent everyone from executing the function
REVOKE ALL ON FUNCTION
   classdb.createStudent(studentUserName VARCHAR(50), studentName VARCHAR(100),
                         schoolID VARCHAR(20), initialPwd VARCHAR(128))
   FROM PUBLIC;

--allow only instructors and db managers to execute the function
GRANT EXECUTE ON FUNCTION
   classdb.createStudent(studentUserName VARCHAR(50), studentName VARCHAR(100),
                         schoolID VARCHAR(20), initialPwd VARCHAR(128))
   TO "Instructor", "DBManager";


--Define a table to track instructors who use DB: each instr. gets a login role
CREATE TABLE IF NOT EXISTS classdb.Instructor
(
   userName VARCHAR(50) NOT NULL PRIMARY KEY, --instructor's login role
   instructorName VARCHAR(100) NOT NULL --instructor's given name
);

--change table ownership to ClassDB
ALTER TABLE classdb.Instructor OWNER TO "ClassDB";

--limit operations on rows and columns
REVOKE ALL PRIVILEGES ON classdb.Student FROM PUBLIC;
GRANT SELECT ON classdb.Student TO "Instructor", "DBManager";
GRANT UPDATE (instructorName) ON classdb.Instructor TO "Instructor", "DBManager";


--Define a function to register an instructor user and associate w/ Instructor role
-- initial password is optional
-- record the user name in the Instructor table
CREATE OR REPLACE FUNCTION
   classdb.createInstructor(instructorUserName VARCHAR(50), instructorName VARCHAR(100),
                            initialPwd VARCHAR(128) DEFAULT NULL) RETURNS VOID AS
$$
BEGIN
   PERFORM classdb.createUser(instructorUserName, initialPwd);
   EXECUTE format('GRANT "Instructor" TO %I', $1);
   INSERT INTO classdb.Instructor VALUES($1, $2)
          ON CONFLICT (username) DO UPDATE SET instructorName = $2;

END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;

--Change function ownership and set execution permissions
ALTER FUNCTION
   classdb.createInstructor(instructorUserName VARCHAR(50), instructorName VARCHAR(100),
                            initialPwd VARCHAR(128))
   OWNER TO "ClassDB";

REVOKE ALL ON FUNCTION
   classdb.createInstructor(instructorUserName VARCHAR(50), instructorName VARCHAR(100),
                            initialPwd VARCHAR(128))
   FROM PUBLIC;

GRANT EXECUTE ON FUNCTION
   classdb.createInstructor(instructorUserName VARCHAR(50), instructorName VARCHAR(100),
                            initialPwd VARCHAR(128))
   TO "Instructor", "DBManager";


--Define a function to register a user in DBManager role
--initial password is optional
CREATE OR REPLACE FUNCTION
   classdb.createDBManager(managerUserName VARCHAR(50), managerName VARCHAR(100),
                           initialPwd VARCHAR(128) DEFAULT NULL) RETURNS VOID AS
$$
BEGIN
   PERFORM classdb.createUser(managerUserName, initialPwd);
   EXECUTE format('GRANT "DBManager" TO %I', $1);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;

--Change function ownership and set execution permissions
ALTER FUNCTION
   classdb.createDBManager(managerUserName VARCHAR(50), managerName VARCHAR(100),
                           initialPwd VARCHAR(128)) OWNER TO "ClassDB";

REVOKE ALL ON FUNCTION
   classdb.createDBManager(managerUserName VARCHAR(50), managerName VARCHAR(100),
                           initialPwd VARCHAR(128)) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION
   classdb.createDBManager(managerUserName VARCHAR(50), managerName VARCHAR(100),
                           initialPwd VARCHAR(128)) TO "Instructor", "DBManager";


--Define a function to revoke Student role from a user
-- remove the entry for user from table classdb.Student
-- remove user's schema and contained objects if Student role was user's only role
CREATE OR REPLACE FUNCTION classdb.dropStudent(userName VARCHAR(50)) RETURNS VOID AS
$$
BEGIN
   IF EXISTS(SELECT * FROM pg_catalog.pg_roles WHERE rolname = $1) AND
      pg_catalog.pg_has_role($1, 'Student', 'member')
   THEN
      EXECUTE format('REVOKE "Student" FROM %I', $1);
      DELETE FROM classdb.Student S WHERE S.userName = $1;

      IF EXISTS(SELECT * FROM pg_catalog.pg_roles 
	            WHERE pg_catalog.pg_has_role($1, oid, 'member') AND rolname != $1 
			   ) THEN
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

--Change function ownership and set execution permissions
ALTER FUNCTION classdb.dropStudent(userName VARCHAR(50)) OWNER TO "ClassDB";
REVOKE ALL ON FUNCTION classdb.dropStudent(userName VARCHAR(50)) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION
   classdb.dropStudent(userName VARCHAR(50))
   TO "Instructor", "DBManager";


--Define a function to drop all students presently registered
-- simply call function dropStudent for each row in classdb.Student
CREATE OR REPLACE FUNCTION dropAllStudents() RETURNS VOID AS
$$
BEGIN
   SELECT classdb.dropStudent(S.userName) FROM classdb.Student S;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;

--Change function ownership and set execution permissions
ALTER FUNCTION dropAllStudents() OWNER TO "ClassDB";
REVOKE ALL ON FUNCTION dropAllStudents() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION dropAllStudents() TO "Instructor", "DBManager";


--The folowing procedure revokes the Instructor role from an Instructor, along with their entry
-- in the classdb.Instructor table. If the Instructor role was the only role that the
-- instructor was a member of, the instructor's schema, and the objects contained within, are
-- removed along with the the role representing the instructor.
CREATE OR REPLACE FUNCTION classdb.dropInstructor(userName VARCHAR(50)) RETURNS VOID AS
$$
BEGIN
   IF
      EXISTS(SELECT * FROM pg_catalog.pg_roles WHERE rolname = $1) AND
      pg_catalog.pg_has_role($1, 'Instructor', 'member')
   THEN
      EXECUTE format('REVOKE "Instructor" FROM %I', $1);
      DELETE FROM classdb.Instructor S WHERE S.userName = $1;
      IF EXISTS(SELECT * FROM pg_catalog.pg_roles
                WHERE pg_catalog.pg_has_role($1, oid, 'member') AND rolname != $1
				) THEN
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

--Change function ownership and set execution permissions
ALTER FUNCTION classdb.dropInstructor(userName VARCHAR(50)) OWNER TO "ClassDB";
REVOKE ALL ON FUNCTION classdb.dropInstructor(userName VARCHAR(50)) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION
   classdb.dropInstructor(userName VARCHAR(50)) TO "Instructor", "DBManager";


--The folowing procedure revokes the DBManager role from a DBManager. If the DBManager role was
-- the only role that they were a member of, the manager's schema, and the objects contained
-- within, are removed along with the the role representing the DBManager.
CREATE OR REPLACE FUNCTION classdb.dropDBManager(userName VARCHAR(50)) RETURNS VOID AS
$$
BEGIN
   IF
      EXISTS(SELECT * FROM pg_catalog.pg_roles WHERE rolname = $1) AND
      pg_catalog.pg_has_role($1, 'DBManager', 'member')
   THEN
      EXECUTE format('REVOKE dbmanager FROM %I', userName);
      IF EXISTS(SELECT * FROM pg_catalog.pg_roles
                WHERE pg_catalog.pg_has_role($1, oid, 'member') AND rolname != $1
               ) THEN
         RAISE NOTICE 'User "%" remains a member of one or more additional roles', $1;
      ELSE
         EXECUTE format('DROP SCHEMA %I CASCADE', $1);
         EXECUTE format('DROP ROLE %I', $1);
      END IF;
   ELSE
      RAISE NOTICE 'User "%" is not a registered "DBManager"', $1;
   END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;

--Change function ownership and set execution permissions
ALTER FUNCTION classdb.dropDBManager(userName VARCHAR(50)) OWNER TO "ClassDB";
REVOKE ALL ON FUNCTION classdb.dropDBManager(userName VARCHAR(50)) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION
   classdb.dropDBManager(userName VARCHAR(50)) TO "Instructor", "DBManager";


--The following procedure drops a user regardless of their role memberships. This will also
-- drop the user's schema and the objects contained within, if the schema exists. Currently,
-- it also drops the value from the Student table if the user was a member of the Student role,
-- and from the Instructor table if they were an instructor.
CREATE OR REPLACE FUNCTION classdb.dropUser(userName VARCHAR(50)) RETURNS VOID AS
$$
BEGIN
   IF EXISTS(SELECT * FROM pg_catalog.pg_roles WHERE rolname = $1) THEN
      IF pg_catalog.pg_has_role($1, 'Student', 'member') THEN
        DELETE FROM classdb.Student WHERE userName = $1;
      END IF;

      IF pg_catalog.pg_has_role($1, 'Instructor', 'member') THEN
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

--Change function ownership and set execution permissions
ALTER FUNCTION classdb.dropUser(userName VARCHAR(50)) OWNER TO "ClassDB";
REVOKE ALL ON FUNCTION classdb.dropUser(userName VARCHAR(50)) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION classdb.dropUser(userName VARCHAR(50)) TO "Instructor", "DBManager";


--The following procedure allows changing the password for a given username, given both the
-- username and password. NOTICEs are raised if the user does not exist or if the password
-- does not meet the requirements.
--Current password requirements:
-- - Must be 4 or more characters
-- - Must contain at least one numerical digit (0-9)

CREATE OR REPLACE FUNCTION
   classdb.changeUserPassword(userName VARCHAR(50), password VARCHAR(128)) RETURNS VOID AS
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

--Change function ownership and set execution permissions
ALTER FUNCTION
   classdb.changeUserPassword(userName VARCHAR(50), password VARCHAR(128))
   OWNER TO "ClassDB";
REVOKE ALL ON FUNCTION
   classdb.changeUserPassword(userName VARCHAR(50), password VARCHAR(128))
   FROM PUBLIC;
GRANT EXECUTE ON FUNCTION
   classdb.changeUserPassword(userName VARCHAR(50), password VARCHAR(128))
   TO "Instructor", "DBManager";


--Define a function to reset a user's password to a default value
-- default password is not the same as the initialPwd used at role creation
-- default password is always the username

CREATE OR REPLACE FUNCTION classdb.resetUserPassword(userName VARCHAR(50)) RETURNS VOID AS
$$
DECLARE
   studentID VARCHAR(128);
BEGIN
   IF
      pg_catalog.pg_has_role($1, 'Student', 'member')
   THEN
      SELECT ID FROM classdb.Student WHERE userName = $1 INTO studentID;
      IF studentID IS NULL THEN
         PERFORM classdb.changeUserPassword(userName, userName);
      ELSE
         PERFORM classdb.changeUserPassword(userName, studentID);
      END IF;
   ELSIF
      pg_catalog.pg_has_role(userName, 'Instructor', 'member')
   THEN
      PERFORM classdb.changeUserPassword(userName, userName);
   ELSE
      RAISE NOTICE 'User "%" not found among registered users', userName;
   END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;

--Change function ownership and set execution permissions
ALTER FUNCTION
   classdb.resetUserPassword(userName VARCHAR(50))
   OWNER TO "ClassDB";
REVOKE ALL ON FUNCTION
   classdb.resetUserPassword(userName VARCHAR(50))
   FROM PUBLIC;
GRANT EXECUTE ON FUNCTION
   classdb.resetUserPassword(userName VARCHAR(50))
   TO "Instructor", "DBManager";



COMMIT;
