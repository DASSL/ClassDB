--testAddHelperFunctions.sql - ClassDB

--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab (DASSL)
--https://dassl.github.io/

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.


--This script should be run as a superuser

--This script tests the helper functions


START TRANSACTION;

--Make sure the current user has sufficient privilege to run this script
-- privilege required: superuser
DO
$$
BEGIN
   IF NOT EXISTS(SELECT * FROM pg_catalog.pg_roles
                 WHERE rolname = current_user AND rolsuper = TRUE
                ) THEN
      RAISE EXCEPTION 'Insufficient privilege: script must be run as a superuser';
   END IF;
END
$$;


--Make sure the ClassDB role is already defined in the server
-- this test is not strictly necessary to test the helper functions, but making
-- sure this role is defined makes it easier to test and verify installation
DO
$$
BEGIN
   IF NOT EXISTS (SELECT * FROM pg_catalog.pg_roles
                  WHERE rolname = 'classdb'
                 ) THEN
      RAISE EXCEPTION
         'Missing group role: role ClassDB role is not defined';
   END IF;
END
$$;


--Define a temporary function to test the foldPgID() function
CREATE OR REPLACE FUNCTION pg_temp.testFoldPgID() RETURNS TEXT AS
$$
BEGIN
   IF ClassDB.foldPgID('test') <> 'test' THEN
      RETURN 'FAIL: Code 1';
   END IF;

   IF ClassDB.foldPgID('Test') <> 'test' THEN
      RETURN 'FAIL: Code 2';
   END IF;

   IF ClassDB.foldPgID('"test"') <> 'test' THEN
      RETURN 'FAIL: Code 3';
   END IF;

   IF ClassDB.foldPgID('"Test"') <> 'Test' THEN
      RETURN 'FAIL: Code 4';
   END IF;

   IF ClassDB.foldPgID('""Test""') <> '"Test"' THEN
      RETURN 'FAIL: Code 5';
   END IF;

   RETURN 'PASS';
END;
$$ LANGUAGE plpgsql;


--Define a temporary function to test capabilities of a given role name
CREATE OR REPLACE FUNCTION
   pg_temp.testRoleCapabilities(roleName ClassDB.IDNameDomain) RETURNS TEXT AS
$$
DECLARE retrievedIsSuperUser BOOLEAN;
DECLARE retrievedHasCreateRole BOOLEAN;
DECLARE retrievedCanCreateDatabase BOOLEAN;
DECLARE retrievedCanLogin BOOLEAN;
DECLARE queryFoundTheRole BOOLEAN;

BEGIN
   --find role capabilities on our own
   --query is guaranteed to return 0 or 1 row due to predicate on primary key
   SELECT rolsuper, rolcreaterole, rolcreatedb, rolcanlogin
   INTO retrievedIsSuperUser, retrievedHasCreateRole,
        retrievedCanCreateDatabase, retrievedCanLogin
   FROM pg_catalog.pg_roles
   WHERE rolname = ClassDB.foldPgID($1);

   --variable FOUND is set to true if the SELECT query above returned a row
   SELECT FOUND INTO queryFoundTheRole;

   --test result of each ClassDB function with what we know it should be
   IF queryFoundTheRole <> ClassDB.isServerRoleDefined(roleName) THEN
      RETURN 'FAIL: Code 1';
   END IF;

   IF retrievedIsSuperUser <> ClassDB.isSuperUser(roleName) THEN
      RETURN 'FAIL: Code 2';
   END IF;

   IF retrievedHasCreateRole <> ClassDB.hasCreateRole(roleName) THEN
      RETURN 'FAIL: Code 3';
   END IF;

   IF retrievedCanCreateDatabase <> ClassDB.canCreateDatabase(roleName) THEN
      RETURN 'FAIL: Code 4';
   END IF;

   IF retrievedCanLogin <> ClassDB.canLogin(roleName) THEN
      RETURN 'FAIL: Code 5';
   END IF;

   RETURN 'PASS';

END;
$$ LANGUAGE plpgsql;


--Define a temporary function to test membership-related functions
--Employs test users setup in testHelperFunctions
CREATE OR REPLACE FUNCTION pg_temp.testMembership() RETURNS TEXT AS
$$
BEGIN

   GRANT classdb_instructor, testUser2_NoLogin TO testUser1_Login;
   GRANT classdb_student TO testUser2_NoLogin;

   --test if the granted roles are recognized
   IF NOT (ClassDB.isMember('testUser1_Login', 'classdb_instructor')
           AND ClassDB.isMember('testUser1_Login', 'testUser2_NoLogin')
           AND ClassDB.isMember('testUser2_NoLogin', 'classdb_student')
          )
   THEN
      RETURN 'FAIL: Code 1';
   END IF;

   --test if roles not granted are not recognized
   IF (ClassDB.isMember('testUser2_NoLogin', 'classdb_instructor')
       OR ClassDB.isMember('testUser2_NoLogin', 'testUser1_Login')
      )
   THEN
      RETURN 'FAIL: Code 2';
   END IF;

   --test if classdb_instructor and classdb_student are recognized as ClassDB roles
   IF NOT (ClassDB.hasClassDBRole('testUser1_Login')
           AND ClassDB.hasClassDBRole('testUser2_NoLogin')
          )
   THEN
      RETURN 'FAIL: Code 3';
   END IF;

   --revoke ClassDB role and test if lack of ClassDB role membership is detected
   REVOKE classdb_student FROM testUser2_NoLogin;
   IF ClassDB.hasClassDBRole('testUser2_NoLogin') THEN
      RETURN 'FAIL: Code 4';
   END IF;

   --test if classdb_dbmanager is recognized as ClassDB role
   GRANT classdb_dbmanager TO testUser2_NoLogin;
   IF NOT ClassDB.hasClassDBRole('testUser2_NoLogin') THEN
      RETURN 'FAIL: Code 5';
   END IF;

   RETURN 'PASS';
END;
$$ LANGUAGE plpgsql;


--Define a temporary function to test miscellaneous functions
-- only one function to test as of now
CREATE OR REPLACE FUNCTION pg_temp.testMiscellany() RETURNS TEXT AS
$$
BEGIN

   --test if ClassDB role names are recognized
   IF NOT (ClassDB.isClassDBRoleName('classdb_instructor')
           AND ClassDB.isClassDBRoleName('classdb_student')
           AND ClassDB.isClassDBRoleName('classdb_dbmanager')
          )
   THEN
      RETURN 'FAIL: Code 1';
   END IF;

   --test if non-ClassDB role names are rejected
   IF ClassDB.isClassDBRoleName('not_classdb_role') THEN
      RETURN 'FAIL: Code 2';
   END IF;

   RETURN 'PASS';
END;
$$ LANGUAGE plpgsql;


--Define a driver function to test helper functions
CREATE OR REPLACE FUNCTION pg_temp.testHelperFunctions() RETURNS VOID AS
$$
BEGIN
   --test foldPgID
   RAISE INFO '%   foldPgID()', pg_temp.testFoldPgID();

   --test with current user (should be a superuser)
   RAISE INFO '%   testRoleCapabilities(current_user)',
      pg_temp.testRoleCapabilities(current_user::VARCHAR);

   --test with ClassDB roles
   RAISE INFO '%   testRoleCapabilities(''classdb'')',
      pg_temp.testRoleCapabilities('classdb');
   RAISE INFO '%   testRoleCapabilities(''classdb_instructor'')',
      pg_temp.testRoleCapabilities('classdb_instructor');
   RAISE INFO '%   testRoleCapabilities(''classdb_student'')',
      pg_temp.testRoleCapabilities('classdb_student');
   RAISE INFO '%   testRoleCapabilities(''classdb_dbmanager'')',
      pg_temp.testRoleCapabilities('classdb_dbmanager');

   --test with users created with specific capabilities
   CREATE USER testUser1_Login WITH LOGIN;
   RAISE INFO '%   testRoleCapabilities(''testUser1_Login'')',
      pg_temp.testRoleCapabilities('testUser1_Login');

   CREATE USER testUser2_NoLogin WITH NOLOGIN;
   RAISE INFO '%   testRoleCapabilities(''testUser2_NoLogin'')',
      pg_temp.testRoleCapabilities('testUser2_NoLogin');

   --test membership functions with test users
   RAISE INFO '%   testMembership',
      pg_temp.testMembership();

   DROP USER testUser1_Login;
   DROP USER testUser2_NoLogin;

   --test functions not tested so far
   RAISE INFO '%   Miscellany',
      pg_temp.testMiscellany();

END;
$$  LANGUAGE plpgsql;


SELECT pg_temp.testHelperFunctions();


COMMIT;
