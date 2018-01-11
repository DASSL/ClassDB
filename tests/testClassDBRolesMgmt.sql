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


--Tests for superuser privilege on current_user
DO
$$
BEGIN
   IF NOT ClassDB.isSuperUser() THEN
      RAISE EXCEPTION 'Insufficient privileges: script must be run as a superuser';
   END IF;
END
$$;


--Define a temporary function to test if a schema is "defined"
-- a schema is defined if a pg_catalog.pg_namespace row exists for schemaName
-- use to test if a string represents the name of a schema in the current db
CREATE OR REPLACE FUNCTION 
   pg_temp.isSchemaDefined(schemaName ClassDB.IDNameDomain)
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


--Define a temporary function to test an encrypted password set to a user
-- Encrypted passwords are MD5 hashes of the user's clear text password 
-- concatenated with their user name
--Calling with clearTextPwd set to NULL will check if user has no password
--See: https://www.postgresql.org/docs/9.6/static/catalog-pg-authid.html
CREATE OR REPLACE FUNCTION 
   pg_temp.checkEncryptedPwd(userName ClassDB.IDNameDomain,
                             clearTextPwd VARCHAR(128))
   RETURNS BOOLEAN AS
$$
BEGIN
   IF EXISTS (
      SELECT * FROM pg_catalog.pg_authid
      WHERE RolName = ClassDB.foldPgID($1) AND (
            RolPassword = 'md5' || pg_catalog.MD5($2 || ClassDB.foldPgID($1))
            OR (RolPassword IS NULL AND $2 IS NULL) )
      )
   THEN
      RETURN TRUE;
   ELSE
      RETURN FALSE;
   END IF;
END;
$$ LANGUAGE plpgsql;


--Suppress notices for the creation of the next function (due to type casting)
SET LOCAL client_min_messages TO WARNING;

--Define a temporary function to test the values of the extra info column in
-- the ClassDB.RoleBase table for a given user
CREATE OR REPLACE FUNCTION 
   pg_temp.checkRoleInfo(userName ClassDB.IDNameDomain,
                         fullName ClassDB.RoleBase.FullName%Type,
                         extraInfo ClassDB.RoleBase.ExtraInfo%Type)
   RETURNS BOOLEAN AS
$$
BEGIN
   IF EXISTS (
      SELECT * FROM ClassDB.RoleBase R
      WHERE R.RoleName = ClassDB.foldPgID($1)
            AND (R.FullName = $2 OR (R.FullName IS NULL AND $2 IS NULL))
            AND (R.ExtraInfo = $3 OR (R.ExtraInfo IS NULL AND $3 IS NULL))
             )
   THEN
      RETURN TRUE;
   ELSE
      RETURN FALSE;
   END IF;
END;
$$ LANGUAGE plpgsql;

RESET client_min_messages;



CREATE OR REPLACE FUNCTION pg_temp.createStudentTest() RETURNS TEXT AS
$$
BEGIN
   --Minimal test: Password and schema should be set to username
   PERFORM ClassDB.createStudent('testStu0', 'Test student 0');
   --Extra info given: Pwd and schema set to username, extrainfo should be stored
   PERFORM ClassDB.createStudent('testStu1', 'Test student 1', NULL, '101');
   --initialPassword given: Password should be set to 'testpass'
   PERFORM ClassDB.createStudent('testStu2', 'Test student 2', NULL, '102',
                                 FALSE, FALSE, 'testpass');
   --initialPassword with no extra info
   PERFORM ClassDB.createStudent('testStu3', 'Test student 3', NULL, NULL, FALSE,
                                 FALSE, 'testpass2');

   --Multi-role: NOTICE is suppressed; name should update, password should not change
   PERFORM ClassDB.createDBManager('testStuDBM0', 'Wrong Name', NULL, NULL,
                                   FALSE, FALSE, 'testpass3');
   SET LOCAL client_min_messages TO WARNING;
   PERFORM ClassDB.createStudent('testStuDBM0', 'Test student/DB manager 0', 
                                 NULL, NULL, TRUE, TRUE, 'notPass');
   RESET client_min_messages;
   
   --Updating with different schema: Create student, create schema, then update
   PERFORM ClassDB.createStudent('testStu4', 'Wrong Name');
   CREATE SCHEMA newTestStu4 AUTHORIZATION testStu4;
   SET LOCAL client_min_messages TO WARNING;
   PERFORM ClassDB.createStudent('testStu4', 'Test student 4', 'newTestStu4');
   RESET client_min_messages;

   --Test role membership (and existence)
   IF NOT(pg_has_role('teststu0', 'classdb_student', 'member')
      AND pg_has_role('teststu1', 'classdb_student', 'member') 
      AND pg_has_role('teststu2', 'classdb_student', 'member') 
      AND pg_has_role('teststu3', 'classdb_student', 'member') 
      AND pg_has_role('teststudbm0', 'classdb_student', 'member') 
      AND pg_has_role('teststudbm0', 'classdb_dbmanager', 'member') 
      AND pg_has_role('teststu4', 'classdb_student', 'member'))
   THEN
      RETURN 'FAIL: Code 1';
   END IF;
   
   --Test existence of all schemas
   IF NOT(pg_temp.isSchemaDefined('testStu0') AND pg_temp.isSchemaDefined('testStu1')
      AND pg_temp.isSchemaDefined('testStu2') AND pg_temp.isSchemaDefined('testStu3')
      AND pg_temp.isSchemaDefined('testStuDBM0') AND pg_temp.isSchemaDefined('testStu4')
      AND pg_temp.isSchemaDefined('newTestStu4'))
   THEN
      RETURN 'FAIL: Code 2';
   END IF;
   
   --Test password (hashes) set to students
   IF NOT(pg_temp.checkEncryptedPwd('testStu0', 'teststu0')
      AND pg_temp.checkEncryptedPwd('testStu1', 'teststu1')
      AND pg_temp.checkEncryptedPwd('testStu2', 'testpass')
      AND pg_temp.checkEncryptedPwd('testStu3', 'testpass2')
      AND pg_temp.checkEncryptedPwd('testStuDBM0', 'testpass3')
      AND pg_temp.checkEncryptedPwd('testStu4', 'teststu4'))
   THEN
      RETURN 'FAIL: Code 3';
   END IF;
   
   --Test role-schema correspondence with ClassDB function
   IF NOT(ClassDB.getSchemaName('testStu0') = 'teststu0'
      AND ClassDB.getSchemaName('testStu1') = 'teststu1'
      AND ClassDB.getSchemaName('testStu2') = 'teststu2'
      AND ClassDB.getSchemaName('testStu3') = 'teststu3'
      AND ClassDB.getSchemaName('testStuDBM0') = 'teststudbm0'
      AND ClassDB.getSchemaName('testStu4') = 'teststu4')
   THEN
      RETURN 'FAIL: Code 4';
   END IF;
   
   --Test extra info stored for each student
   IF NOT(pg_temp.checkRoleInfo('testStu0', 'Test student 0', NULL)
      AND pg_temp.checkRoleInfo('testStu1', 'Test student 1', '101')
      AND pg_temp.checkRoleInfo('testStu2', 'Test student 2', '102')
      AND pg_temp.checkRoleInfo('testStu3', 'Test student 3', NULL)
      AND pg_temp.checkRoleInfo('testStuDBM0', 'Test student/DB manager 0', NULL)
      AND pg_temp.checkRoleInfo('testStu4', 'Test student 4', NULL))
   THEN
      RETURN 'FAIL: Code 5';
   END IF;
   
   --Test connection limit, statement timeout, and login privileges
   IF EXISTS(
      SELECT * FROM pg_catalog.pg_roles
      WHERE RolName IN ('teststu0', 'teststu1', 'teststu2', 'teststu3',
                        'teststudbm0', 'teststu4')
            AND
               (NOT RolCanLogin OR RolConnLimit <> 5 OR 
                array_to_string(RolConfig, '') NOT LIKE '%statement_timeout=2000%')
            )
   THEN
      RETURN 'FAIL Code 6';
   END IF;
   
   --Cleanup
   DROP OWNED BY testStu0;
   DROP ROLE testStu0;
   DELETE FROM ClassDB.RoleBase WHERE roleName = 'teststu0';

   DROP OWNED BY testStu1;
   DROP ROLE testStu1;
   DELETE FROM ClassDB.RoleBase WHERE roleName = 'teststu1';

   DROP OWNED BY testStu2;
   DROP ROLE testStu2;
   DELETE FROM ClassDB.RoleBase WHERE roleName = 'teststu2';

   DROP OWNED BY testStu3;
   DROP ROLE testStu3;
   DELETE FROM ClassDB.RoleBase WHERE roleName = 'teststu3';

   DROP OWNED BY testStu4;
   DROP ROLE testStu4;
   DELETE FROM ClassDB.RoleBase WHERE roleName = 'teststu4';
   
   DROP OWNED BY testStuDBM0;
   DROP ROLE testStuDBM0;
   DELETE FROM ClassDB.RoleBase WHERE roleName = 'teststudbm0';
   
   RETURN 'PASS';
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION pg_temp.createInstructorTest() RETURNS TEXT AS
$$
BEGIN
   --Minimal test: Password and schema should be set to username
   PERFORM ClassDB.createInstructor('testIns0', 'Test instructor 0');
   --Extra info given: Pwd and schema set to username, extrainfo should be stored
   PERFORM ClassDB.createInstructor('testIns1', 'Test instructor 1', NULL, '101');
   --initialPassword given: Password should be set to 'testpass'
   PERFORM ClassDB.createInstructor('testIns2', 'Test instructor 2', NULL, '102',
                                 FALSE, FALSE, 'testpass');
   --initialPassword with no extra info
   PERFORM ClassDB.createInstructor('testIns3', 'Test instructor 3', NULL, NULL, FALSE,
                                 FALSE, 'testpass2');

   --Multi-role: NOTICE is suppressed; name should update, password should not change
   PERFORM ClassDB.createDBManager('testInsDBM0', 'Wrong Name', NULL, NULL,
                                   FALSE, FALSE, 'testpass3');
   SET LOCAL client_min_messages TO WARNING;
   PERFORM ClassDB.createInstructor('testInsDBM0', 'Test instructor/DB manager 0', 
                                 NULL, NULL, TRUE, TRUE, 'notPass');
   RESET client_min_messages;
   
   --Updating with different schema: Create instructor, create schema, then update
   PERFORM ClassDB.createInstructor('testIns4', 'Wrong Name');
   CREATE SCHEMA newTestIns4 AUTHORIZATION testIns4;
   SET LOCAL client_min_messages TO WARNING;
   PERFORM ClassDB.createInstructor('testIns4', 'Test instructor 4', 'newTestIns4');
   RESET client_min_messages;

   --Test role membership (and existence)
   IF NOT(pg_has_role('testins0', 'classdb_instructor', 'member')
      AND pg_has_role('testins1', 'classdb_instructor', 'member') 
      AND pg_has_role('testins2', 'classdb_instructor', 'member') 
      AND pg_has_role('testins3', 'classdb_instructor', 'member') 
      AND pg_has_role('testinsdbm0', 'classdb_instructor', 'member') 
      AND pg_has_role('testinsdbm0', 'classdb_dbmanager', 'member') 
      AND pg_has_role('testins4', 'classdb_instructor', 'member'))
   THEN
      RETURN 'FAIL: Code 1';
   END IF;
   
   --Test existence of all schemas
   IF NOT(pg_temp.isSchemaDefined('testIns0') AND pg_temp.isSchemaDefined('testIns1')
      AND pg_temp.isSchemaDefined('testIns2') AND pg_temp.isSchemaDefined('testIns3')
      AND pg_temp.isSchemaDefined('testInsDBM0') AND pg_temp.isSchemaDefined('testIns4')
      AND pg_temp.isSchemaDefined('newTestIns4'))
   THEN
      RETURN 'FAIL: Code 2';
   END IF;
   
   --Test password (hashes) set to instructors
   IF NOT(pg_temp.checkEncryptedPwd('testIns0', 'testins0')
      AND pg_temp.checkEncryptedPwd('testIns1', 'testins1')
      AND pg_temp.checkEncryptedPwd('testIns2', 'testpass')
      AND pg_temp.checkEncryptedPwd('testIns3', 'testpass2')
      AND pg_temp.checkEncryptedPwd('testInsDBM0', 'testpass3')
      AND pg_temp.checkEncryptedPwd('testIns4', 'testins4'))
   THEN
      RETURN 'FAIL: Code 3';
   END IF;
   
   --Test role-schema correspondence with ClassDB function
   IF NOT(ClassDB.getSchemaName('testIns0') = 'testins0'
      AND ClassDB.getSchemaName('testIns1') = 'testins1'
      AND ClassDB.getSchemaName('testIns2') = 'testins2'
      AND ClassDB.getSchemaName('testIns3') = 'testins3'
      AND ClassDB.getSchemaName('testInsDBM0') = 'testinsdbm0'
      AND ClassDB.getSchemaName('testIns4') = 'testins4')
   THEN
      RETURN 'FAIL: Code 4';
   END IF;
   
   --Test extra info stored for each instructor
   IF NOT(pg_temp.checkRoleInfo('testIns0', 'Test instructor 0', NULL)
      AND pg_temp.checkRoleInfo('testIns1', 'Test instructor 1', '101')
      AND pg_temp.checkRoleInfo('testIns2', 'Test instructor 2', '102')
      AND pg_temp.checkRoleInfo('testIns3', 'Test instructor 3', NULL)
      AND pg_temp.checkRoleInfo('testInsDBM0', 'Test instructor/DB manager 0', NULL)
      AND pg_temp.checkRoleInfo('testIns4', 'Test instructor 4', NULL))
   THEN
      RETURN 'FAIL: Code 5';
   END IF;
   
   --Test login privilege
   IF EXISTS(
      SELECT * FROM pg_catalog.pg_roles
      WHERE RolName IN ('testins0', 'testins1', 'testins2', 'testins3',
                        'testinsdbm0', 'testins4')
            AND NOT RolCanLogin
            )
   THEN
      RETURN 'FAIL Code 6';
   END IF;
   
   --Cleanup
   DROP OWNED BY testIns0;
   DROP ROLE testIns0;
   DELETE FROM ClassDB.RoleBase WHERE roleName = 'testins0';

   DROP OWNED BY testIns1;
   DROP ROLE testIns1;
   DELETE FROM ClassDB.RoleBase WHERE roleName = 'testins1';

   DROP OWNED BY testIns2;
   DROP ROLE testIns2;
   DELETE FROM ClassDB.RoleBase WHERE roleName = 'testins2';

   DROP OWNED BY testIns3;
   DROP ROLE testIns3;
   DELETE FROM ClassDB.RoleBase WHERE roleName = 'testins3';

   DROP OWNED BY testIns4;
   DROP ROLE testIns4;
   DELETE FROM ClassDB.RoleBase WHERE roleName = 'testins4';
   
   DROP OWNED BY testInsDBM0;
   DROP ROLE testInsDBM0;
   DELETE FROM ClassDB.RoleBase WHERE roleName = 'testinsdbm0';
   
   RETURN 'PASS';
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION pg_temp.createDBManagerTest() RETURNS TEXT AS
$$
BEGIN
   --Minimal test: Password and schema should be set to username
   PERFORM ClassDB.createDBManager('testDBM0', 'Test DB manager 0');
   --Extra info given: Pwd and schema set to username, extrainfo should be stored
   PERFORM ClassDB.createDBManager('testDBM1', 'Test DB manager 1', NULL, '101');
   --initialPassword given: Password should be set to 'testpass'
   PERFORM ClassDB.createDBManager('testDBM2', 'Test DB manager 2', NULL, '102',
                                 FALSE, FALSE, 'testpass');
   --initialPassword with no extra info
   PERFORM ClassDB.createDBManager('testDBM3', 'Test DB manager 3', NULL, NULL, FALSE,
                                 FALSE, 'testpass2');

   --Multi-role: NOTICE is suppressed; name should update, password should not change
   PERFORM ClassDB.createDBManager('testDBMStu0', 'Wrong Name', NULL, NULL,
                                   FALSE, FALSE, 'testpass3');
   SET LOCAL client_min_messages TO WARNING;
   PERFORM ClassDB.createStudent('testDBMStu0', 'Test DB manager/student 0', 
                                 NULL, NULL, TRUE, TRUE, 'notPass');
   RESET client_min_messages;
   
   --Updating with different schema: Create DB manager, create schema, then update
   PERFORM ClassDB.createDBManager('testDBM4', 'Wrong Name');
   CREATE SCHEMA newTestDBM4 AUTHORIZATION testDBM4;
   SET LOCAL client_min_messages TO WARNING;
   PERFORM ClassDB.createDBManager('testDBM4', 'Test DB manager 4', 'newTestDBM4');
   RESET client_min_messages;

   --Test role membership (and existence)
   IF NOT(pg_has_role('testdbm0', 'classdb_dbmanager', 'member')
      AND pg_has_role('testdbm1', 'classdb_dbmanager', 'member') 
      AND pg_has_role('testdbm2', 'classdb_dbmanager', 'member') 
      AND pg_has_role('testdbm3', 'classdb_dbmanager', 'member') 
      AND pg_has_role('testdbmstu0', 'classdb_dbmanager', 'member') 
      AND pg_has_role('testdbmstu0', 'classdb_student', 'member') 
      AND pg_has_role('testdbm4', 'classdb_dbmanager', 'member'))
   THEN
      RETURN 'FAIL: Code 1';
   END IF;
   
   --Test existence of all schemas
   IF NOT(pg_temp.isSchemaDefined('testDBM0') AND pg_temp.isSchemaDefined('testDBM1')
      AND pg_temp.isSchemaDefined('testDBM2') AND pg_temp.isSchemaDefined('testDBM3')
      AND pg_temp.isSchemaDefined('testDBMStu0') AND pg_temp.isSchemaDefined('testDBM4')
      AND pg_temp.isSchemaDefined('newTestDBM4'))
   THEN
      RETURN 'FAIL: Code 2';
   END IF;
   
   --Test password (hashes) set to DB managers
   IF NOT(pg_temp.checkEncryptedPwd('testDBM0', 'testdbm0')
      AND pg_temp.checkEncryptedPwd('testDBM1', 'testdbm1')
      AND pg_temp.checkEncryptedPwd('testDBM2', 'testpass')
      AND pg_temp.checkEncryptedPwd('testDBM3', 'testpass2')
      AND pg_temp.checkEncryptedPwd('testDBMStu0', 'testpass3')
      AND pg_temp.checkEncryptedPwd('testDBM4', 'testdbm4'))
   THEN
      RETURN 'FAIL: Code 3';
   END IF;
   
   --Test role-schema correspondence with ClassDB function
   IF NOT(ClassDB.getSchemaName('testDBM0') = 'testdbm0'
      AND ClassDB.getSchemaName('testDBM1') = 'testdbm1'
      AND ClassDB.getSchemaName('testDBM2') = 'testdbm2'
      AND ClassDB.getSchemaName('testDBM3') = 'testdbm3'
      AND ClassDB.getSchemaName('testDBMStu0') = 'testdbmstu0'
      AND ClassDB.getSchemaName('testDBM4') = 'testdbm4')
   THEN
      RETURN 'FAIL: Code 4';
   END IF;
   
   --Test extra info stored for each DB manager
   IF NOT(pg_temp.checkRoleInfo('testDBM0', 'Test DB manager 0', NULL)
      AND pg_temp.checkRoleInfo('testDBM1', 'Test DB manager 1', '101')
      AND pg_temp.checkRoleInfo('testDBM2', 'Test DB manager 2', '102')
      AND pg_temp.checkRoleInfo('testDBM3', 'Test DB manager 3', NULL)
      AND pg_temp.checkRoleInfo('testDBMStu0', 'Test DB manager/student 0', NULL)
      AND pg_temp.checkRoleInfo('testDBM4', 'Test DB manager 4', NULL))
   THEN
      RETURN 'FAIL: Code 5';
   END IF;
   
   --Test login privilege
   IF EXISTS(
      SELECT * FROM pg_catalog.pg_roles
      WHERE RolName IN ('testdbm0', 'testdbm1', 'testdbm2', 'testdbm3',
                        'testdbmdbm0', 'testdbm4')
            AND NOT RolCanLogin
            )
   THEN
      RETURN 'FAIL Code 6';
   END IF;
   
   --Cleanup
   DROP OWNED BY testDBM0;
   DROP ROLE testDBM0;
   DELETE FROM ClassDB.RoleBase WHERE roleName = 'testdbm0';

   DROP OWNED BY testDBM1;
   DROP ROLE testDBM1;
   DELETE FROM ClassDB.RoleBase WHERE roleName = 'testdbm1';

   DROP OWNED BY testDBM2;
   DROP ROLE testDBM2;
   DELETE FROM ClassDB.RoleBase WHERE roleName = 'testdbm2';

   DROP OWNED BY testDBM3;
   DROP ROLE testDBM3;
   DELETE FROM ClassDB.RoleBase WHERE roleName = 'testdbm3';

   DROP OWNED BY testDBM4;
   DROP ROLE testDBM4;
   DELETE FROM ClassDB.RoleBase WHERE roleName = 'testdbm4';
   
   DROP OWNED BY testDBMStu0;
   DROP ROLE testDBMStu0;
   DELETE FROM ClassDB.RoleBase WHERE roleName = 'testdbmstu0';
   
   RETURN 'PASS';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION pg_temp.revokeStudentTest() RETURNS TEXT AS
$$
BEGIN
   --Create basic student, then revoke
   PERFORM ClassDB.createStudent('testStu0', 'Test student 0');
   PERFORM ClassDB.revokeStudent('testStu0');
   
   --Create student/instructor, then revoke student
   PERFORM ClassDB.createInstructor('testInsStu0', 'Test instructor/student 0');
   SET LOCAL client_min_messages TO WARNING;
   PERFORM ClassDB.createStudent('testInsStu0', 'Test instructor/student 0');
   PERFORM ClassDB.revokeStudent('testInsStu0');
   RESET client_min_messages;
   
   --Test if roles still exists on server
   IF NOT (ClassDB.isServerRoleDefined('testStu0') 
      AND ClassDB.isServerRoleDefined('testInsStu0'))
   THEN
      RETURN 'FAIL: Code 1';
   END IF;
   
   --Test if their schemas still exist
   IF NOT(pg_temp.isSchemaDefined('testStu0')
      AND pg_temp.isSchemaDefined('testInsStu0'))
   THEN
      RETURN 'FAIL: Code 2';
   END IF;
   
   --Test if roles no longer have student role
   IF ClassDB.isMember('testStu0', 'ClassDB_Student') 
      OR ClassDB.isMember('testInsStu0', 'ClassDB_Student')
   THEN
      RETURN 'FAIL: Code 3';
   END IF;
   
   --Test if second user still has instructor role
   IF NOT ClassDB.isMember('testInsStu0', 'ClassDB_Instructor')
   THEN
      RETURN 'FAIL: Code 4';
   END IF;
   
   --Test that connection limit and statement timeout are reset, but login remains
   IF EXISTS(
      SELECT * FROM pg_catalog.pg_roles
      WHERE RolName IN ('teststu0', 'testinsstu0')
            AND
               (NOT RolCanLogin OR RolConnLimit <> -1 OR 
                array_to_string(RolConfig, '') LIKE '%statement_timeout=2000%')
            )
   THEN
      RETURN 'FAIL Code 5';
   END IF;
   
   --Cleanup
   DROP OWNED BY testStu0;
   DROP ROLE testStu0;
   DELETE FROM ClassDB.RoleBase WHERE roleName = 'teststu0';
   
   DROP OWNED BY testInsStu0;
   DROP ROLE testInsStu0;
   DELETE FROM ClassDB.RoleBase WHERE roleName = 'testinsStu0';
   
   RETURN 'PASS';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION pg_temp.revokeInstructorTest() RETURNS TEXT AS
$$
BEGIN
   --Create basic instructor, then revoke
   PERFORM ClassDB.createInstructor('testIns0', 'Test instructor 0');
   PERFORM ClassDB.revokeInstructor('testIns0');
   
   --Create DB manager/instructor, then revoke instructor
   PERFORM ClassDB.createDBManager('testDBMIns0', 'Test DB manager/instructor 0');
   SET LOCAL client_min_messages TO WARNING;
   PERFORM ClassDB.createInstructor('testDBMIns0', 'Test DB manager/instructor 0');
   PERFORM ClassDB.revokeInstructor('testDBMIns0');
   RESET client_min_messages;
   
   --Test if roles still exists on server
   IF NOT (ClassDB.isServerRoleDefined('testIns0') 
      AND ClassDB.isServerRoleDefined('testDBMIns0'))
   THEN
      RETURN 'FAIL: Code 1';
   END IF;
   
   --Test if their schemas still exist
   IF NOT(pg_temp.isSchemaDefined('testIns0')
      AND pg_temp.isSchemaDefined('testDBMIns0'))
   THEN
      RETURN 'FAIL: Code 2';
   END IF;
   
   --Test if roles no longer have instructor role
   IF ClassDB.isMember('testIns0', 'ClassDB_Instructor') 
      OR ClassDB.isMember('testDBMIns0', 'ClassDB_Instructor')
   THEN
      RETURN 'FAIL: Code 3';
   END IF;
   
   --Test if second user still has DBManager role
   IF NOT ClassDB.isMember('testDBMIns0', 'ClassDB_DBManager')
   THEN
      RETURN 'FAIL: Code 4';
   END IF;
   
   --Test that login privilege remains
   IF EXISTS(
      SELECT * FROM pg_catalog.pg_roles
      WHERE RolName IN ('testins0', 'testdbmins0')
            AND NOT RolCanLogin
            )
   THEN
      RETURN 'FAIL Code 5';
   END IF;
   
   --Cleanup
   DROP OWNED BY testIns0;
   DROP ROLE testIns0;
   DELETE FROM ClassDB.RoleBase WHERE roleName = 'testins0';
   
   DROP OWNED BY testDBMIns0;
   DROP ROLE testDBMIns0;
   DELETE FROM ClassDB.RoleBase WHERE roleName = 'testdbmins0';
   
   RETURN 'PASS';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION pg_temp.revokeDBManagerTest() RETURNS TEXT AS
$$
BEGIN
   --Create basic DB manager, then revoke
   PERFORM ClassDB.createDBManager('testDBM0', 'Test DB manager 0');
   PERFORM ClassDB.revokeDBManager('testDBM0');
   
   --Create DB manager/student, then revoke DB manager
   PERFORM ClassDB.createStudent('testStuDBM0', 'Test student/DB manager 0');
   SET LOCAL client_min_messages TO WARNING;
   PERFORM ClassDB.createDBManager('testStuDBM0', 'Test student/DB manager 0');
   PERFORM ClassDB.revokeDBManager('testStuDBM0');
   RESET client_min_messages;
   
   --Test if roles still exists on server
   IF NOT (ClassDB.isServerRoleDefined('testDBM0') 
      AND ClassDB.isServerRoleDefined('testStuDBM0'))
   THEN
      RETURN 'FAIL: Code 1';
   END IF;
   
   --Test if their schemas still exist
   IF NOT(pg_temp.isSchemaDefined('testDBM0')
      AND pg_temp.isSchemaDefined('testStuDBM0'))
   THEN
      RETURN 'FAIL: Code 2';
   END IF;
   
   --Test if roles no longer have DB manager role
   IF ClassDB.isMember('testDBM0', 'ClassDB_DBManager') 
      OR ClassDB.isMember('testStuDBM0', 'ClassDB_DBManager')
   THEN
      RETURN 'FAIL: Code 3';
   END IF;
   
   --Test if second user still has student role
   IF NOT ClassDB.isMember('testStuDBM0', 'ClassDB_Student')
   THEN
      RETURN 'FAIL: Code 4';
   END IF;
   
   --Test that login privilege remains
   IF EXISTS(
      SELECT * FROM pg_catalog.pg_roles
      WHERE RolName IN ('testdbm0', 'teststudbm0')
            AND NOT RolCanLogin
            )
   THEN
      RETURN 'FAIL Code 5';
   END IF;
   
   --Cleanup
   DROP OWNED BY testDBM0;
   DROP ROLE testDBM0;
   DELETE FROM ClassDB.RoleBase WHERE roleName = 'testdbm0';
   
   DROP OWNED BY testStuDBM0;
   DROP ROLE testStuDBM0;
   DELETE FROM ClassDB.RoleBase WHERE roleName = 'teststudbm0';
   
   RETURN 'PASS';
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION pg_temp.dropStudentTest() RETURNS TEXT AS
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


CREATE OR REPLACE FUNCTION pg_temp.dropInstructorTest() RETURNS TEXT AS
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


CREATE OR REPLACE FUNCTION pg_temp.dropDBManagerTest() RETURNS TEXT AS
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


CREATE OR REPLACE FUNCTION pg_temp.prepareClassDBTest() RETURNS VOID AS
$$
BEGIN
   RAISE INFO '%   createStudentTest()', pg_temp.createStudentTest();
   RAISE INFO '%   createInstructorTest()', pg_temp.createInstructorTest();
   RAISE INFO '%   createDBManagerTest()', pg_temp.createDBManagerTest();
   RAISE INFO '%   revokeStudentTest()', pg_temp.revokeStudentTest();
   RAISE INFO '%   revokeInstructorTest()', pg_temp.revokeInstructorTest();
   RAISE INFO '%   revokeDBManagerTest()', pg_temp.revokeDBManagerTest();
   --The following tests need to be updated to test the latest version of the
   --functions they test
   --RAISE INFO '%   dropStudentTest()', pg_temp.dropStudentTest();
   --RAISE INFO '%   dropInstructorTest()', pg_temp.dropInstructorTest();
   --RAISE INFO '%   dropDBManagerTest()', pg_temp.dropDBManagerTest();
   --RAISE INFO '%   dropAllStudentsTest()', pg_temp.dropAllStudentsTest();
END;
$$  LANGUAGE plpgsql;


SELECT pg_temp.prepareClassDBTest();


COMMIT;
