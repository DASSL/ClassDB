--testPrepareClassDB.sql - ClassDB

--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab (DASSL), Western Connecticut State University (WCSU)

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.


--The following test script should be run as a superuser, otherwise tests will fail

START TRANSACTION;


--Tests for superuser privilege on current_user
DO
$$
BEGIN
   IF NOT EXISTS(SELECT * FROM pg_catalog.pg_roles WHERE rolname = current_user
    AND rolsuper = TRUE) THEN
      RAISE EXCEPTION 'Insufficient privileges: script must be run as a superuser';
   END IF;
END
$$;

CREATE OR REPlACE FUNCTION classdb.createUserTest() RETURNS TEXT AS
$$
BEGIN
   --Test createUser
   PERFORM classdb.createUser('testUser0', 'password');
   PERFORM classdb.createUser('lowercaseuser', 'password');

   -- These users should not be able to connect to the database, and since passwords are
   --  encrypted, there is not a straightfoward way to test the passwords set. However,
   --  login abilities and passwords can be tested though the creation of User and user
   --  roles in the following functions.

   --If the above lines created the roles correctly, the following 4 lines should
   -- not result in an exception.
   PERFORM classdb.dropUser('testUser0');
   PERFORM classdb.dropUser('lowercaseuser');
   RETURN 'PASS';
END
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION classdb.createStudentTest() RETURNS TEXT AS
$$
DECLARE
   rowCount INTEGER;
BEGIN
   --UserName fallback: Password should be set to username
   PERFORM classdb.createStudent('testStudent0', 'Yvette Alexander');
   --SchoolID fallback: Password should be set to ID (101)
   PERFORM classdb.createStudent('testStudent1', 'Edwin Morrison', '101');
   --initialPassword used: Password should be set to 'testpass'
   PERFORM classdb.createStudent('testStudent2', 'Ramon Harrington', '102', 'testpass');
   --initialPassword with no schoolID: Password should be set to 'testPass2'
   PERFORM classdb.createStudent('testStudent3', 'Cathy Young', NULL, 'testpass2');
   --Multi-role: Should not result in an exception or error (NOTICE is expected),
   -- password should not change
   PERFORM classdb.createInstructor('testStuInst0', 'Edwin Morrison', 'testpass3');
   PERFORM classdb.createStudent('testStuInst0', 'Edwin Morrison', '102', 'notPass');

   --Test existance of all schemas
   PERFORM * FROM information_schema.schemata WHERE schema_name IN ('testStudent0',
      'testStudent1', 'testStudent2', 'testStudent3', 'testStuInst0');
   GET DIAGNOSTICS rowCount = ROW_COUNT;
   IF rowCount != 5 THEN
      RETURN 'FAIL: Code 1';
   END IF;

   --Test role membership
   IF pg_has_role('testStudent0', 'classdb_student', 'member') AND
      pg_has_role('testStudent1', 'classdb_student', 'member') AND
      pg_has_role('testStudent2', 'classdb_student', 'member') AND
      pg_has_role('testStudent3', 'classdb_student', 'member') AND
      pg_has_role('testStuInst0', 'classdb_student', 'member') AND
      pg_has_role('testStuInst0', 'classdb_instructor', 'member') THEN
      RETURN 'PENDING - see testPrepareClassDBREADME.txt';
   ELSE
      RETURN 'FAIL: Code 2';
   END IF;
END
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION classdb.createInstructorTest() RETURNS TEXT AS
$$
DECLARE
   rowCount INTEGER;
BEGIN
   --UserName fallback: Password should be set to userName
   PERFORM classdb.createInstructor('testInstructor0', 'Dave Paul');
   --initialPassword used: Password should be set to 'testpass4'
   PERFORM classdb.createInstructor('testInstructor1', 'Dianna Wilson', 'testpass4');
   --Multi-role: Should not result in an exception or error (NOTICE is expected),
   -- password should not change
   PERFORM classdb.createStudent('testStuInst1', 'Rosalie Flowers', '106', 'testpass5');
   PERFORM classdb.createInstructor('testStuInst1', 'Rosalie Flowers');

   --Test existance of all schemas
   PERFORM * FROM information_schema.schemata WHERE schema_name IN ('testInstructor0',
      'testInstructor1', 'testStuInst1');
   GET DIAGNOSTICS rowCount = ROW_COUNT;
   IF rowCount != 3 THEN
      RETURN 'FAIL: Code 1';
   END IF;

   IF pg_has_role('testInstructor0', 'classdb_instructor', 'member') AND
      pg_has_role('testInstructor1', 'classdb_instructor', 'member') THEN
      RETURN 'PENDING - see testPrepareClassDBREADME.txt';
   ELSE
      RETURN 'FAIL: Code 2';
   END IF;
END
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION classdb.createDBManagerTest() RETURNS TEXT AS
$$
DECLARE
   rowCount INTEGER;
BEGIN
   --UserName fallback: Password should be set to userName
   PERFORM classdb.createDBmanager('testDBManager0', 'Colin Cooper');
   --initialPassword used: Password should be set to 'testpass6'
   PERFORM classdb.createDBManager('testDBManager1', 'Dianna Wilson', 'testpass6');
   --Multi-role: Should not result in an exception or error (NOTICE is expected),
   -- password should not change
   PERFORM classdb.createDBManager('testInstManage0', 'Shawn Nash', 'testpass7');
   PERFORM classdb.createInstructor('testInstManage0', 'Shawn Nash');

   --Test existance of all schemas
   PERFORM * FROM information_schema.schemata WHERE schema_name IN ('testDBManager0',
      'testDBManager1', 'testInstManage0');
   GET DIAGNOSTICS rowCount = ROW_COUNT;
   IF rowCount != 3 THEN
      RETURN 'FAIL: Code 1';
   END IF;

   IF pg_has_role('testDBManager0', 'classdb_dbmanager', 'member') AND
      pg_has_role('testDBManager1', 'classdb_dbmanager', 'member') THEN
      RETURN 'PENDING - see testPrepareClassDBREADME.txt';
   ELSE
      RETURN 'FAIL: Code 2';
   END IF;
END
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION classdb.dropStudentTest() RETURNS TEXT AS
$$
DECLARE
   valueExists BOOLEAN;
BEGIN
   --"Normal" case, Regular student: Role and schema should be dropped
   PERFORM classdb.createStudent('testStudent4', 'Ramon Harrington', '102', 'testpass');
   PERFORM classdb.dropStudent('testStudent4');
   SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'testStudent4' INTO valueExists;
   IF valueExists THEN
      RETURN 'FAIL: Code 1';
   END IF;
   SELECT 1 FROM information_schema.schemata WHERE schema_name = 'testStudent4'
   INTO valueExists;
   IF valueExists THEN
      RETURN 'FAIL: Code 2';
   END IF;

   --Multi-role case, user is a member of both Student and Instructor roles: Schema and Role
   -- should still exist
   PERFORM classdb.createStudent('testStuInst2', 'Roland Baker');
   PERFORM classdb.createInstructor('testStuInst2', 'Roland Baker');
   PERFORM classdb.dropStudent('testStuInst2');

   SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'testStuInst2' INTO valueExists;
   IF valueExists THEN
      SELECT 1 FROM information_schema.schemata WHERE schema_name = 'testStuInst2'
      INTO valueExists;
      IF valueExists THEN
         PERFORM classdb.dropInstructor('testStuInst2');
      ELSE
         RETURN 'FAIL: Code 4';
      END IF;
   ELSE
      RETURN 'FAIL: Code 3';
   END IF;
   RETURN 'PASS';
END
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION classdb.dropInstructorTest() RETURNS TEXT AS
$$
DECLARE
   valueExists BOOLEAN;
BEGIN
   --"Normal" case, Regular Instructor: Role and schema should be dropped
   PERFORM classdb.createInstructor('testInstructor2', 'Wayne Bates', 'testpass');
   PERFORM classdb.dropInstructor('testInstructor2');
   SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'testInstructor2' INTO valueExists;
   IF valueExists THEN
      RETURN 'FAIL: Code 1';
   END IF;
   SELECT 1 FROM information_schema.schemata WHERE schema_name = 'testInstructor2'
   INTO valueExists;
   IF valueExists THEN
      RETURN 'FAIL: Code 2';
   END IF;

   --Multi-role case, user is a member of both Student and Instructor roles: Schema
   -- and Role should still exist
   PERFORM classdb.createInstructor('testStuInst3', 'Julius Patton');
   PERFORM classdb.createStudent('testStuInst3', 'Julius Paton');
   PERFORM classdb.dropInstructor('testStuInst3');

   SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'testStuInst3' INTO valueExists;
   IF valueExists THEN
      SELECT 1 FROM information_schema.schemata WHERE schema_name = 'testStuInst3'
      INTO valueExists;
      IF valueExists THEN
         PERFORM classdb.dropStudent('testStuInst3');
      ELSE
         RETURN 'FAIL: Code 4';
      END IF;
   ELSE
      RETURN 'FAIL: Code 3';
   END IF;
   RETURN 'PASS';
END
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION classdb.dropDBManagerTest() RETURNS TEXT AS
$$
DECLARE
   valueExists BOOLEAN;
BEGIN
   --"Normal" case, Regular DBManager: Role and schema should be dropped
   PERFORM classdb.createDBManager('testDBManager2', 'Tom Bryan', 'testpass');
   PERFORM classdb.dropDBManager('testDBManager2');

   SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'testDBManager2' INTO valueExists;
   IF valueExists THEN
      RETURN 'FAIL: Code 1';
   END IF;
   SELECT 1 FROM information_schema.schemata WHERE schema_name = 'testDBMangager2'
   INTO valueExists;
   IF valueExists THEN
      RETURN 'FAIL: Code 2';
   END IF;

   --Multi-role case, user is a member of both Student and Instructor roles: Schema
   -- and Role should still exist
   PERFORM classdb.createDBManager('testInstManage2', 'Alice West');
   PERFORM classdb.createInstructor('testInstManage2', 'Alice West');
   PERFORM classdb.dropDBManager('testInstManage2');

   SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'testInstManage2' INTO valueExists;
   IF valueExists THEN
      SELECT 1 FROM information_schema.schemata WHERE schema_name = 'testInstManage2'
      INTO valueExists;
      IF valueExists THEN
         PERFORM classdb.dropInstructor('testInstManage2');
      ELSE
         RETURN 'FAIL: Code 4';
      END IF;
   ELSE
      RETURN 'FAIL: Code 3';
   END IF;
   RETURN 'PASS';
END
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION classdb.prepareClassDBTest() RETURNS VOID AS
$$
BEGIN
   RAISE INFO '%   createUserTest()', classdb.createUserTest();
   RAISE INFO '%   createStudentTest()', classdb.createStudentTest();
   RAISE INFO '%   createInstructorTest()', classdb.createInstructorTest();
   RAISE INFO '%   createDBManagerTest()', classdb.createDBManagerTest();
   RAISE INFO '%   dropStudentTest()', classdb.dropStudentTest();
   RAISE INFO '%   dropInstructorTest()', classdb.dropInstructorTest();
   RAISE INFO '%   dropDBManagerTest()', classdb.dropDBManagerTest();
END
$$  LANGUAGE plpgsql;


SELECT classdb.prepareClassDBTest();


COMMIT;
