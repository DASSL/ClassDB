--testPrepareClassDB.sql - ClassDB

--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab (DASSL), Western Connecticut State University (WCSU)

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.


--The following test script should be run as a superuser, otherwise tests will fail

START TRANSACTION;

--Define a temporary function to test if a schema is "defined"
-- a schema is defined if a pg_catalog.pg_namespace row exists for schemaName
-- use to test if a string represents the name of a schema in the current db
CREATE OR REPLACE FUNCTION pg_temp.isSchemaDefined(schemaName VARCHAR(63))
   RETURNS BOOLEAN AS
$$
BEGIN
   IF EXISTS (SELECT * FROM pg_catalog.pg_namespace
              WHERE nspname = classdb.foldpgID($1)) THEN
      RETURN TRUE;
   ELSE
      RETURN FALSE;
   END IF;
END;
$$ LANGUAGE plpgsql;


--Tests for superuser privilege on current_user
DO
$$
BEGIN
   IF NOT classdb.isSuperUser() THEN
      RAISE EXCEPTION 'Insufficient privileges: script must be run as a superuser';
   END IF;
END
$$;


CREATE OR REPLACE FUNCTION classdb.createDropUserTest() RETURNS TEXT AS
$$
BEGIN
   PERFORM classdb.createUser('testlc', 'password');
   PERFORM classdb.createUser('testUC', 'password');
   PERFORM classdb.createUser('"testQUC"', 'password');

   --Check that all 3 roles exist
   IF NOT (classdb.isRoleDefined('testlc') AND classdb.isRoleDefined('testUC')
      AND classdb.isRoleDefined('"testQUC"')) THEN
      RETURN 'FAIL: Code 1';
   END IF;

   --Check that all 3 schemas were created
   IF NOT (pg_temp.isSchemaDefined('testlc') AND pg_temp.isSchemaDefined('testUC')
      AND pg_temp.isSchemaDefined('"testQUC"')) THEN
      RETURN 'FAIL: Code 2';
   END IF;

   PERFORM classdb.dropUser('testlc');
   PERFORM classdb.dropUser('testUC');
   PERFORM classdb.dropUser('"testQUC"');

   --Check that all 3 roles no longer exist
   IF classdb.isRoleDefined('testlc') OR classdb.isRoleDefined('testUC')
      OR classdb.isRoleDefined('"testQUC"') THEN
      RETURN 'FAIL: Code 3';
   END IF;

   --Check that all 3 schemas no longer exist
   IF pg_temp.isSchemaDefined('testlc') OR pg_temp.isSchemaDefined('testUC')
      OR pg_temp.isSchemaDefined('"testQUC"') THEN
      RETURN 'FAIL: Code 4';
   END IF;

   RETURN 'PASS';
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION classdb.createStudentTest() RETURNS TEXT AS
$$
BEGIN
   --Minimal test: Password should be set to username
   PERFORM classdb.createStudent('testStu0', 'Yvette Alexander');
   --SchoolID given: Password should still be set to username, ID should be stored
   PERFORM classdb.createStudent('testStu1', 'Edwin Morrison', '101');
   --initialPassword given: Password should be set to 'testpass'
   PERFORM classdb.createStudent('testStu2', 'Ramon Harrington', '102', 'testpass');
   --initialPassword given with no schoolID
   PERFORM classdb.createStudent('testStu3', 'Cathy Young', NULL, 'testpass2');

   --Multi-role: NOTICE is suppressed; password should not change
   PERFORM classdb.createStudent('testStuDBM0', 'Edwin Morrison', NULL, 'testpass3');
   SET LOCAL client_min_messages TO WARNING;
   PERFORM classdb.createDBManager('testStuDBM0', 'notPass');
   RESET client_min_messages;

   --Test existence of all schemas
   IF NOT(pg_temp.isSchemaDefined('testStu0') AND pg_temp.isSchemaDefined('testStu1')
      AND pg_temp.isSchemaDefined('testStu2') AND pg_temp.isSchemaDefined('testStu3')
      AND pg_temp.isSchemaDefined('testStuDBM0')) THEN
      RETURN 'FAIL: Code 1';
   END IF;

   --Test role membership (and existence)
   IF pg_has_role('teststu0', 'classdb_student', 'member') AND
      pg_has_role('teststu1', 'classdb_student', 'member') AND
      pg_has_role('teststu2', 'classdb_student', 'member') AND
      pg_has_role('teststu3', 'classdb_student', 'member') AND
      pg_has_role('teststudbm0', 'classdb_student', 'member') AND
      pg_has_role('teststudbm0', 'classdb_dbmanager', 'member') THEN
      RETURN 'PENDING - see testPrepareClassDBREADME.txt';
   ELSE
      RETURN 'FAIL: Code 2';
   END IF;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION classdb.createInstructorTest() RETURNS TEXT AS
$$
BEGIN
   --Minimal test: Password should be set to username
   PERFORM classdb.createInstructor('testIns0', 'Dave Paul');
   --initialPassword given: Password should be set to 'testpass4'
   PERFORM classdb.createInstructor('testIns1', 'Dianna Wilson', 'testpass4');

   --Multi-role: NOTICE is suppressed; password should not change
   PERFORM classdb.createInstructor('testStuIns1', 'Rosalie Flowers', 'testpass5');
   SET LOCAL client_min_messages TO WARNING;
   PERFORM classdb.createStudent('testStuIns1', 'Rosalie Flowers', '106', 'notPass');
   RESET client_min_messages;

   --Test existence of all schemas
   IF NOT(pg_temp.isSchemaDefined('testIns0') AND pg_temp.isSchemaDefined('testIns1')
      AND pg_temp.isSchemaDefined('testStuIns1')) THEN
      RETURN 'FAIL: Code 1';
   END IF;

   --Check role membership (and existence)
   IF pg_has_role('testins0', 'classdb_instructor', 'member') AND
      pg_has_role('testins1', 'classdb_instructor', 'member') THEN
      RETURN 'PENDING - see testPrepareClassDBREADME.txt';
   ELSE
      RETURN 'FAIL: Code 2';
   END IF;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION classdb.createDBManagerTest() RETURNS TEXT AS
$$
BEGIN
   --Minimal test: Password should be set to username
   PERFORM classdb.createDBmanager('testDBM0');
   --initialPassword used: Password should be set to 'testpass6'
   PERFORM classdb.createDBManager('testDBM1', 'testpass6');

   --Multi-role: NOTICE is suppressed; password should not change
   PERFORM classdb.createDBManager('testInsMg0', 'testpass7');
   SET LOCAL client_min_messages TO WARNING;
   PERFORM classdb.createInstructor('testInsMg0', 'Shawn Nash');
   RESET client_min_messages;

   --Test existence of all schemas
   IF NOT(pg_temp.isSchemaDefined('testDBM0') AND pg_temp.isSchemaDefined('testDBM1')
      AND pg_temp.isSchemaDefined('testInsMg0')) THEN
      RETURN 'FAIL: Code 1';
   END IF;

   --Check role membership (and existence)
   IF pg_has_role('testdbm0', 'classdb_dbmanager', 'member') AND
      pg_has_role('testdbm1', 'classdb_dbmanager', 'member') THEN
      RETURN 'PENDING - see testPrepareClassDBREADME.txt';
   ELSE
      RETURN 'FAIL: Code 2';
   END IF;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION classdb.dropStudentTest() RETURNS TEXT AS
$$
BEGIN
   --"Normal" case, Regular student: Role and schema should be dropped
   PERFORM classdb.createStudent('testStu4', 'Ramon Harrington', '102', 'testpass');
   PERFORM classdb.dropStudent('testStu4');

   --Check for existence of role
   IF classdb.isRoleDefined('testStu4') THEN
      RETURN 'FAIL: Code 1';
   END IF;

   --Check for existence of schema
   IF pg_temp.isSchemaDefined('testStu4') THEN
      RETURN 'FAIL: Code 2';
   END IF;

   --Multi-role case: schema and role should still exist after dropStudent
   PERFORM classdb.createStudent('testStuIns2', 'Roland Baker');
   SET LOCAL client_min_messages TO WARNING;
   PERFORM classdb.createInstructor('testStuIns2', 'Roland Baker');
   PERFORM classdb.dropStudent('testStuIns2');
   RESET client_min_messages;

   IF classdb.isRoleDefined('testStuIns2') THEN
      IF pg_temp.isSchemaDefined('testStuIns2') THEN
         PERFORM classdb.dropInstructor('testStuIns2');
      ELSE
         RETURN 'FAIL: Code 4'; --schema was not defined
      END IF;
   ELSE
      RETURN 'FAIL: Code 3'; --role was not defined
   END IF;

   RETURN 'PASS';
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION classdb.dropInstructorTest() RETURNS TEXT AS
$$
BEGIN
   --"Normal" case, Regular Instructor: Role and schema should be dropped
   PERFORM classdb.createInstructor('testIns2', 'Wayne Bates', 'testpass');
   PERFORM classdb.dropInstructor('testIns2');

   --Check for existence of role
   IF classdb.isRoleDefined('testIns2') THEN
      RETURN 'FAIL: Code 1';
   END IF;

   --Check for existence of schema
   IF pg_temp.isSchemaDefined('testIns2') THEN
      RETURN 'FAIL: Code 2';
   END IF;

   --Multi-role case: schema and role should still exist after dropInstructor
   PERFORM classdb.createInstructor('testStuIns3', 'Julius Patton');
   SET LOCAL client_min_messages TO WARNING;
   PERFORM classdb.createStudent('testStuIns3', 'Julius Paton');
   PERFORM classdb.dropInstructor('testStuIns3');
   RESET client_min_messages;

   IF classdb.isRoleDefined('testStuIns3') THEN
      IF pg_temp.isSchemaDefined('testStuIns3') THEN
         PERFORM classdb.dropStudent('testStuIns3');
      ELSE
         RETURN 'FAIL: Code 4'; --schema was not defined
      END IF;
   ELSE
      RETURN 'FAIL: Code 3'; --role was not defined
   END IF;

   RETURN 'PASS';
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION classdb.dropDBManagerTest() RETURNS TEXT AS
$$
BEGIN
   --"Normal" case, Regular DBManager: Role and schema should be dropped
   PERFORM classdb.createDBManager('testDBM2', 'testpass');
   PERFORM classdb.dropDBManager('testDBM2');

   --Check for existence of role
   IF classdb.isRoleDefined('testDBM2') THEN
      RETURN 'FAIL: Code 1';
   END IF;

   --Check for existence of schema
   IF pg_temp.isSchemaDefined('testDBM2') THEN
      RETURN 'FAIL: Code 2';
   END IF;

   --Multi-role case: schema and role should still exist after dropDBManager
   PERFORM classdb.createDBManager('testInsMg2');
   SET LOCAL client_min_messages TO WARNING;
   PERFORM classdb.createInstructor('testInsMg2', 'Alice West');
   PERFORM classdb.dropDBManager('testInsMg2');
   RESET client_min_messages;

   IF classdb.isRoleDefined('testInsMg2') THEN
      IF pg_temp.isSchemaDefined('testInsMg2') THEN
         PERFORM classdb.dropInstructor('testInsMg2');
      ELSE
         RETURN 'FAIL: Code 4'; --schema was not defined
      END IF;
   ELSE
      RETURN 'FAIL: Code 3'; --role was not defined
   END IF;

   RETURN 'PASS';
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION classdb.prepareClassDBTest() RETURNS VOID AS
$$
BEGIN
   RAISE INFO '%   createUserTest()', classdb.createDropUserTest();
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
