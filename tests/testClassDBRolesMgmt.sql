--testClassDBRolesMgmt.sql - ClassDB

--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab (DASSL)
--https://dassl.github.io/

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
              WHERE nspname = ClassDB.foldpgID($1)) THEN
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
   IF NOT ClassDB.isSuperUser() THEN
      RAISE EXCEPTION 'Insufficient privileges: script must be run as a superuser';
   END IF;
END
$$;


CREATE OR REPLACE FUNCTION ClassDB.createUserTest() RETURNS TEXT AS
$$
BEGIN
   PERFORM ClassDB.createUser('testlc', 'password');
   PERFORM ClassDB.createUser('testUC', 'password');
   PERFORM ClassDB.createUser('"testQUC"', 'password');

   --Check that all 3 roles exist
   IF NOT (ClassDB.isServerRoleDefined('testlc') AND ClassDB.isServerRoleDefined('testUC')
      AND ClassDB.isServerRoleDefined('"testQUC"')) THEN
      RETURN 'FAIL: Code 1';
   END IF;

   --Check that all 3 schemas were created
   IF NOT (pg_temp.isSchemaDefined('testlc') AND pg_temp.isSchemaDefined('testUC')
      AND pg_temp.isSchemaDefined('"testQUC"')) THEN
      RETURN 'FAIL: Code 2';
   END IF;

   --Remove users that were created
   DROP SCHEMA testlc;
   DROP ROLE testlc;
   DROP SCHEMA testUC;
   DROP ROLE testUC;
   DROP SCHEMA "testQUC";
   DROP ROLE "testQUC";

   --Check that all 3 roles no longer exist
   IF ClassDB.isServerRoleDefined('testlc') OR ClassDB.isServerRoleDefined('testUC')
      OR ClassDB.isServerRoleDefined('"testQUC"') THEN
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


CREATE OR REPLACE FUNCTION ClassDB.createStudentTest() RETURNS TEXT AS
$$
BEGIN
   --Minimal test: Password should be set to username
   PERFORM ClassDB.createStudent('testStu0', 'Yvette Alexander');
   --SchoolID given: Password should still be set to username, ID should be stored
   PERFORM ClassDB.createStudent('testStu1', 'Edwin Morrison', '101');
   --initialPassword given: Password should be set to 'testpass'
   PERFORM ClassDB.createStudent('testStu2', 'Ramon Harrington', '102', 'testpass');
   --initialPassword given with no schoolID
   PERFORM ClassDB.createStudent('testStu3', 'Cathy Young', NULL, 'testpass2');

   --Multi-role: NOTICE is suppressed; password should not change
   PERFORM ClassDB.createStudent('testStuDBM0', 'Edwin Morrison', NULL, 'testpass3');
   SET LOCAL client_min_messages TO WARNING;
   PERFORM ClassDB.createDBManager('testStuDBM0', 'notPass');
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


CREATE OR REPLACE FUNCTION ClassDB.createInstructorTest() RETURNS TEXT AS
$$
BEGIN
   --Minimal test: Password should be set to username
   PERFORM ClassDB.createInstructor('testIns0', 'Dave Paul');
   --initialPassword given: Password should be set to 'testpass4'
   PERFORM ClassDB.createInstructor('testIns1', 'Dianna Wilson', 'testpass4');

   --Multi-role: NOTICE is suppressed; password should not change
   PERFORM ClassDB.createInstructor('testStuIns1', 'Rosalie Flowers', 'testpass5');
   SET LOCAL client_min_messages TO WARNING;
   PERFORM ClassDB.createStudent('testStuIns1', 'Rosalie Flowers', '106', 'notPass');
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


CREATE OR REPLACE FUNCTION ClassDB.createDBManagerTest() RETURNS TEXT AS
$$
BEGIN
   --Minimal test: Password should be set to username
   PERFORM ClassDB.createDBmanager('testDBM0');
   --initialPassword used: Password should be set to 'testpass6'
   PERFORM ClassDB.createDBManager('testDBM1', 'testpass6');

   --Multi-role: NOTICE is suppressed; password should not change
   PERFORM ClassDB.createDBManager('testInsMg0', 'testpass7');
   SET LOCAL client_min_messages TO WARNING;
   PERFORM ClassDB.createInstructor('testInsMg0', 'Shawn Nash');
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


CREATE OR REPLACE FUNCTION ClassDB.dropStudentTest() RETURNS TEXT AS
$$
BEGIN
   --"Normal" case, Regular student: Role and schema should be dropped
   PERFORM ClassDB.createStudent('testStu4', 'Ramon Harrington', '102', 'testpass');
   PERFORM ClassDB.dropStudent('testStu4');

   --Check for existence of role
   IF ClassDB.isServerRoleDefined('testStu4') THEN
      RETURN 'FAIL: Code 1';
   END IF;

   --Check for existence of schema
   IF pg_temp.isSchemaDefined('testStu4') THEN
      RETURN 'FAIL: Code 2';
   END IF;

   --Multi-role case: schema and role should still exist after dropStudent
   PERFORM ClassDB.createStudent('testStuIns2', 'Roland Baker');
   SET LOCAL client_min_messages TO WARNING;
   PERFORM ClassDB.createInstructor('testStuIns2', 'Roland Baker');
   PERFORM ClassDB.dropStudent('testStuIns2');
   RESET client_min_messages;

   IF ClassDB.isServerRoleDefined('testStuIns2') THEN
      IF pg_temp.isSchemaDefined('testStuIns2') THEN
         PERFORM ClassDB.dropInstructor('testStuIns2');
      ELSE
         RETURN 'FAIL: Code 4'; --schema was not defined
      END IF;
   ELSE
      RETURN 'FAIL: Code 3'; --role was not defined
   END IF;

   RETURN 'PASS';
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION ClassDB.dropInstructorTest() RETURNS TEXT AS
$$
BEGIN
   --"Normal" case, Regular Instructor: Role and schema should be dropped
   PERFORM ClassDB.createInstructor('testIns2', 'Wayne Bates', 'testpass');
   PERFORM ClassDB.dropInstructor('testIns2');

   --Check for existence of role
   IF ClassDB.isServerRoleDefined('testIns2') THEN
      RETURN 'FAIL: Code 1';
   END IF;

   --Check for existence of schema
   IF pg_temp.isSchemaDefined('testIns2') THEN
      RETURN 'FAIL: Code 2';
   END IF;

   --Multi-role case: schema and role should still exist after dropInstructor
   PERFORM ClassDB.createInstructor('testStuIns3', 'Julius Patton');
   SET LOCAL client_min_messages TO WARNING;
   PERFORM ClassDB.createStudent('testStuIns3', 'Julius Paton');
   PERFORM ClassDB.dropInstructor('testStuIns3');
   RESET client_min_messages;

   IF ClassDB.isServerRoleDefined('testStuIns3') THEN
      IF pg_temp.isSchemaDefined('testStuIns3') THEN
         PERFORM ClassDB.dropStudent('testStuIns3');
      ELSE
         RETURN 'FAIL: Code 4'; --schema was not defined
      END IF;
   ELSE
      RETURN 'FAIL: Code 3'; --role was not defined
   END IF;

   RETURN 'PASS';
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION ClassDB.dropDBManagerTest() RETURNS TEXT AS
$$
BEGIN
   --"Normal" case, Regular DBManager: Role and schema should be dropped
   PERFORM ClassDB.createDBManager('testDBM2', 'testpass');
   PERFORM ClassDB.dropDBManager('testDBM2');

   --Check for existence of role
   IF ClassDB.isServerRoleDefined('testDBM2') THEN
      RETURN 'FAIL: Code 1';
   END IF;

   --Check for existence of schema
   IF pg_temp.isSchemaDefined('testDBM2') THEN
      RETURN 'FAIL: Code 2';
   END IF;

   --Multi-role case: schema and role should still exist after dropDBManager
   PERFORM ClassDB.createDBManager('testInsMg2');
   SET LOCAL client_min_messages TO WARNING;
   PERFORM ClassDB.createInstructor('testInsMg2', 'Alice West');
   PERFORM ClassDB.dropDBManager('testInsMg2');
   RESET client_min_messages;

   IF ClassDB.isServerRoleDefined('testInsMg2') THEN
      IF pg_temp.isSchemaDefined('testInsMg2') THEN
         PERFORM ClassDB.dropInstructor('testInsMg2');
      ELSE
         RETURN 'FAIL: Code 4'; --schema was not defined
      END IF;
   ELSE
      RETURN 'FAIL: Code 3'; --role was not defined
   END IF;

   RETURN 'PASS';
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION ClassDB.prepareClassDBTest() RETURNS VOID AS
$$
BEGIN
   RAISE INFO '%   createUserTest()', ClassDB.createUserTest();
   RAISE INFO '%   createStudentTest()', ClassDB.createStudentTest();
   RAISE INFO '%   createInstructorTest()', ClassDB.createInstructorTest();
   RAISE INFO '%   createDBManagerTest()', ClassDB.createDBManagerTest();
   RAISE INFO '%   dropStudentTest()', ClassDB.dropStudentTest();
   RAISE INFO '%   dropInstructorTest()', ClassDB.dropInstructorTest();
   RAISE INFO '%   dropDBManagerTest()', ClassDB.dropDBManagerTest();
END
$$  LANGUAGE plpgsql;


SELECT ClassDB.prepareClassDBTest();


COMMIT;
