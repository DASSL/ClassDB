--testAddHelperFunctions.sql - ClassDB

--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab (DASSL), Western Connecticut State University (WCSU)

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
-- sure this role is defined makes it easier to test and verifies installation
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


--Define a temporary function to test capabilities of a given role name
CREATE OR REPLACE FUNCTION pg_temp.testRoleCapabilities(roleName VARCHAR(63))
RETURNS TEXT AS
$$
DECLARE retrievedIsSuperUser BOOLEAN;
DECLARE retrievedHasCreateRole BOOLEAN;
DECLARE retrievedCanCreateDatabase BOOLEAN;
DECLARE retrievedCanLogin BOOLEAN;
DECLARE queryFoundTheRole BOOLEAN;

BEGIN
   --find role capabilities our own
   --query is guaranteed to return 0 or 1 row due to predicate on primary key
   SELECT rolsuper, rolcreaterole, rolcreatedb, rolcanlogin
   INTO retrievedIsSuperUser, retrievedHasCreateRole,
        retrievedCanCreateDatabase, retrievedCanLogin
   FROM pg_catalog.pg_roles
   WHERE rolname = $1;

   --variable FOUND is set to true if the SELECT query above returned a row
   SELECT FOUND INTO queryFoundTheRole;

   --test result of each ClassDB function with what we know it should be
   IF queryFoundTheRole <> ClassDB.isRoleDefined(roleName) THEN
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


CREATE OR REPLACE FUNCTION pg_temp.testFoldPgID() RETURNS TEXT AS
$$
BEGIN
   IF classdb.foldPgID('test') <> 'test' THEN
      RETURN 'FAIL: Code 1';
   END IF;

   IF classdb.foldPgID('Test') <> 'test' THEN
      RETURN 'FAIL: Code 2';
   END IF;

   IF classdb.foldPgID('"test"') <> 'test' THEN
      RETURN 'FAIL: Code 3';
   END IF;

   IF classdb.foldPgID('"Test"') <> 'Test' THEN
      RETURN 'FAIL: Code 4';
   END IF;

   IF classdb.foldPgID('""Test""') <> '"Test"' THEN
      RETURN 'FAIL: Code 5';
   END IF;

   RETURN 'PASS';
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION pg_temp.testHelperFunctions() RETURNS VOID AS
$$
BEGIN

   --test with current user (should be a superuser)
   RAISE INFO '%   current_user',
      pg_temp.testRoleCapabilities(current_user::VARCHAR);

   --test with ClassDB roles
   RAISE INFO '%   ClassDB', pg_temp.testRoleCapabilities('ClassDB');
   RAISE INFO '%   Instructor', pg_temp.testRoleCapabilities('Instructor');
   RAISE INFO '%   Student', pg_temp.testRoleCapabilities('Student');
   RAISE INFO '%   DBManager', pg_temp.testRoleCapabilities('DBManager');

   --test with users created with specific capabilities
   CREATE USER testUser1_Login WITH LOGIN;
   RAISE INFO '%   testUser1_Login',
      pg_temp.testRoleCapabilities('testUser1_Login');
   DROP USER testUser1_Login;

   CREATE USER testUser2_NoLogin WITH NOLOGIN;
   RAISE INFO '%   testUser2_NoLogin',
      pg_temp.testRoleCapabilities('testUser2_NoLogin');
   DROP USER testUser2_NoLogin;

   --test foldPgID
   RAISE INFO '%   foldPgID()', pg_temp.testFoldPgID();
   
END;
$$  LANGUAGE plpgsql;


SELECT pg_temp.testHelperFunctions();


COMMIT;
