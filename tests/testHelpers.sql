--testHelpers.sql - ClassDB

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

   --test if schema owner's name is retrieved
   CREATE SCHEMA tset_amehcs_iierr8;
   IF ClassDB.getSchemaOwnerName('tset_amehcs_iierr8') <> CURRENT_USER THEN
      DROP SCHEMA tset_amehcs_iierr8;
      RETURN 'FAIL: Code 3';
   END IF;
   DROP SCHEMA tset_amehcs_iierr8;


   RETURN 'PASS';
END;
$$ LANGUAGE plpgsql;


--Define a temporary function to test two functions related to object
--reassignment: ClassDB.reassignObjectOwnership and ClassDB.reassignOwnedInSchema
CREATE OR REPLACE FUNCTION pg_temp.testOwnershipReassignment() RETURNS TEXT AS
$$
DECLARE
   user0OID oid; --internal OID of user 0
   user1OID oid; --internal OID of user 1
   sharedSchemaOID oid; --internal OID of shared schema
   publicSchemaOID oid; --internal OID of public schema
BEGIN
--------------------------------------------------------------------------------
--Test expected fundamental behavior of DB and ClassDB.reassignObjectOwnership
   
   --create two users for testing
   CREATE USER user0_testOwnership;
   CREATE USER user1_testOwnership;

   --create schema for use by user 1
   CREATE SCHEMA user1_testOwnership AUTHORIZATION user1_testOwnership;

   --grant privileges on public schema to both users for testing purposes
   GRANT CREATE ON SCHEMA public TO user0_testOwnership, user1_testOwnership;

   --create table in public schema as user 0
   SET SESSION AUTHORIZATION user0_testOwnership;
   CREATE TABLE public.publicTestTable(col1 VARCHAR);
   RESET SESSION AUTHORIZATION;

   --create table in private schema as user 1
   SET SESSION AUTHORIZATION user1_testOwnership;
   CREATE TABLE user1_testOwnership.privateTestTable(col1 VARCHAR);
   RESET SESSION AUTHORIZATION;

   --verify that user 0 can insert into public table and is owner, while user 1
   -- cannot read public table
   IF NOT(pg_catalog.has_table_privilege(ClassDB.foldPgID('user0_testOwnership'),
               ClassDB.foldPgID('public.publicTestTable'), 'insert')
      AND EXISTS(
                  SELECT * FROM pg_catalog.pg_tables
                  WHERE schemaName = 'public' AND tableName = 'publictesttable'
                        AND tableOwner = 'user0_testownership'
                )
      AND NOT pg_catalog.has_table_privilege(ClassDB.foldPgID('user1_testOwnership'),
               ClassDB.foldPgID('public.publicTestTable'), 'select'))
   THEN
      RETURN 'FAIL: Code 1';
   END IF;

   --verify that user 1 can can read and is owner of private table, and user 0
   -- cannot read private table and cannot access schema
   IF NOT(pg_catalog.has_table_privilege(ClassDB.foldPgID('user1_testOwnership'),
             ClassDB.foldPgID('user1_testOwnership.privateTestTable'), 'insert')
      AND EXISTS(
                  SELECT * FROM pg_catalog.pg_tables
                  WHERE schemaName = 'user1_testownership'
                        AND tableName = 'privatetesttable'
                        AND tableOwner = 'user1_testownership'
                )
      AND NOT pg_catalog.has_table_privilege(ClassDB.foldPgID('user0_testOwnership'),
                 ClassDB.foldPgId('user1_testOwnership.privateTestTable'), 'select')
      AND NOT pg_catalog.has_schema_privilege(ClassDB.foldPgID('user0_testOwnership'),
                 ClassDB.foldPgID('user1_testOwnership'), 'usage'))
   THEN
      RETURN 'FAIL: Code 2';
   END IF;

   --create third user to perform the reassignment. Both roles are granted to
   -- this user since this is a requirement for reassigning ownership
   --classdb_instructor is granted to call the function being tested
   CREATE USER user2_testOwnership;
   GRANT user0_testOwnership, user1_testOwnership TO user2_testOwnership;
   GRANT ClassDB_Instructor TO user2_testOwnership;

   --reassign public object from user 0 to user 1
   SET SESSION AUTHORIZATION user2_testOwnership;
   PERFORM ClassDB.reassignObjectOwnership('Table', 'public.publicTestTable',
                                           'user1_testOwnership');
   RESET SESSION AUTHORIZATION;

   --verify object reassignment
   IF NOT(pg_catalog.has_table_privilege(ClassDB.foldPgID('user1_testOwnership'),
               ClassDB.foldPgID('public.publicTestTable'), 'insert')
      AND EXISTS(
                  SELECT * FROM pg_catalog.pg_tables
                  WHERE schemaName = 'public' AND tableName = 'publictesttable'
                        AND tableOwner = 'user1_testownership'
                )
      AND NOT pg_catalog.has_table_privilege(ClassDB.foldPgID('user0_testOwnership'),
               ClassDB.foldPgID('public.publicTestTable'), 'select'))
   THEN
      RETURN 'FAIL: Code 3';
   END IF;

   --reassign private object from user 1 to user 2
   SET SESSION AUTHORIZATION user2_testOwnership;
   PERFORM ClassDB.reassignObjectOwnership('Table',
                                           'user1_testOwnership.privateTestTable',
                                           'user2_testOwnership');
   RESET SESSION AUTHORIZATION;

   --verify object reassignment
   IF NOT(pg_catalog.has_table_privilege(ClassDB.foldPgID('user2_testOwnership'),
               ClassDB.foldPgID('user1_testOwnership.privateTestTable'), 'insert')
      AND EXISTS(
                  SELECT * FROM pg_catalog.pg_tables
                  WHERE schemaName = 'user1_testownership'
                        AND tableName = 'privatetesttable'
                        AND tableOwner = 'user2_testownership'
                )
      AND NOT pg_catalog.has_table_privilege(ClassDB.foldPgID('user1_testOwnership'),
               ClassDB.foldPgID('user1_testOwnership.privateTestTable'), 'select')
      AND NOT pg_catalog.has_table_privilege(ClassDB.foldPgID('user0_testOwnership'),
               ClassDB.foldPgID('user1_testOwnership.privateTestTable'), 'select'))
   THEN
      RETURN 'FAIL: Code 4';
   END IF;

   --cleanup before next set of tests
   DROP TABLE public.publicTestTable;
   DROP TABLE user1_testOwnership.privateTestTable;

--------------------------------------------------------------------------------
--Test fundamental behavior of ClassDB.reassignOwnedInSchema. Also tests
-- reassigning ownership of all valid types in ClassDB.reassignObjectOwnership

   --create shared schema, granting access to user 0 and user 1
   CREATE SCHEMA shared_testOwnership;
   GRANT CREATE, USAGE ON SCHEMA shared_testOwnership
      TO user0_testOwnership, user1_testOwnership;

   --create test object of each type as user 1 in shared and public schema
   --NOTE: Foreign tables are not tested
   SET SESSION AUTHORIZATION user1_testOwnership;

   CREATE TABLE shared_testOwnership.sharedTestTable(col1 VARCHAR);
   CREATE INDEX sharedTestIndex ON shared_testOwnership.sharedTestTable (col1);
   CREATE SEQUENCE shared_testOwnership.sharedTestSequence;
   CREATE VIEW shared_testOwnership.sharedTestView AS
      (SELECT * FROM shared_testOwnership.sharedTestTable);
   CREATE MATERIALIZED VIEW shared_testOwnership.sharedTestMatView AS
      (SELECT * FROM shared_testOwnership.sharedTestTable);
   CREATE TYPE shared_testOwnership.sharedTestType AS (testType VARCHAR);
   CREATE FUNCTION shared_testOwnership.sharedTestFunction()
      RETURNS VOID AS '' LANGUAGE SQL;

   CREATE TABLE public.publicTestTable(col1 VARCHAR);
   CREATE INDEX publicTestIndex ON public.publicTestTable (col1);
   CREATE SEQUENCE public.publicTestSequence;
   CREATE VIEW public.publicTestView AS
      (SELECT * FROM public.publicTestTable);
   CREATE MATERIALIZED VIEW public.publicTestMatView AS
      (SELECT * FROM public.publicTestTable);
   CREATE TYPE public.publicTestType AS (testType VARCHAR);
   CREATE FUNCTION public.publicTestFunction()
      RETURNS VOID AS '' LANGUAGE SQL;

   RESET SESSION AUTHORIZATION;
   
   --get OIDs for easier identification of object owners and schema
   user0OID = (SELECT oid FROM pg_catalog.pg_roles
               WHERE rolname = ClassDB.foldPgID('user0_testOwnership'));
   user1OID = (SELECT oid FROM pg_catalog.pg_roles
               WHERE rolname = ClassDB.foldPgID('user1_testOwnership'));
   sharedSchemaOID = (SELECT oid FROM pg_catalog.pg_namespace
                      WHERE nspName = ClassDB.foldPgID('shared_testOwnership'));
   publicSchemaOID = (SELECT oid FROM pg_catalog.pg_namespace
                      WHERE nspName = 'public');
   
   --verify user 1 owns the 7 objects in shared schema
   IF NOT(6 = (SELECT COUNT(*) FROM pg_catalog.pg_class --6 objects in pg_class
               WHERE relName IN (ClassDB.foldPgID('sharedTestTable'),
                                 ClassDB.foldPgID('sharedTestIndex'),
                                 ClassDB.foldPgID('sharedTestSequence'),
                                 ClassDB.foldPgID('sharedTestView'),
                                 ClassDB.foldPgID('sharedTestMatView'),
                                 ClassDB.foldPgID('sharedTestType'))
                AND relOwner = user1OID AND relNamespace = sharedSchemaOID
               )
      AND EXISTS(SELECT * FROM pg_catalog.pg_proc --1 object in pg_proc
                 WHERE proname = ClassDB.foldPgID('sharedTestFunction')
                       AND proOwner = user1OID AND proNamespace = sharedSchemaOID
                )
         )
   THEN
      RETURN 'FAIL: Code 5';
   END IF;
   
   --verify user 0 does not own the objects in public schema
   IF NOT(NOT EXISTS(SELECT * FROM pg_catalog.pg_class
               WHERE relName IN (ClassDB.foldPgID('publicTestTable'),
                                 ClassDB.foldPgID('publicTestIndex'),
                                 ClassDB.foldPgID('publicTestSequence'),
                                 ClassDB.foldPgID('publicTestView'),
                                 ClassDB.foldPgID('publicTestMatView'),
                                 ClassDB.foldPgID('publicTestType'))
                AND relOwner = user0OID AND relNamespace = publicSchemaOID
               )
      AND NOT EXISTS(SELECT * FROM pg_catalog.pg_proc
                  WHERE proName = ClassDB.foldPgID('publicTestFunction')
                  AND proOwner = user0OID
                  AND proNamespace = publicSchemaOID)
         )
   THEN
      RETURN 'FAIL: Code 6';
   END IF;

   --reassign objects owned by user 1 in shared schema to user 0, objects that
   -- were in public schema should remain owned by user 1
   PERFORM ClassDB.reassignOwnedInSchema('shared_testOwnership',
      'user1_testOwnership', 'user0_testOwnership');
      
   RAISE INFO 'BLAH: %', (SELECT COUNT(*) FROM pg_catalog.pg_class --6 objects in pg_class
               WHERE relName IN (ClassDB.foldPgID('sharedTestTable'),
                                 ClassDB.foldPgID('sharedTestIndex'),
                                 ClassDB.foldPgID('sharedTestSequence'),
                                 ClassDB.foldPgID('sharedTestView'),
                                 ClassDB.foldPgID('sharedTestMatView'),
                                 ClassDB.foldPgID('sharedTestType'))
                AND relOwner = user0OID AND relNamespace = sharedSchemaOID
               );

   --verify that user 0 now owns the 7 objects in the shared schema
   IF NOT((FALSE OR 6 = (SELECT COUNT(*) FROM pg_catalog.pg_class --6 objects in pg_class
               WHERE relName IN (ClassDB.foldPgID('sharedTestTable'),
                                 ClassDB.foldPgID('sharedTestIndex'),
                                 ClassDB.foldPgID('sharedTestSequence'),
                                 ClassDB.foldPgID('sharedTestView'),
                                 ClassDB.foldPgID('sharedTestMatView'),
                                 ClassDB.foldPgID('sharedTestType'))
                AND relOwner = user0OID AND relNamespace = sharedSchemaOID
               ))
      AND (TRUE OR EXISTS(SELECT * FROM pg_catalog.pg_proc --1 object in pg_proc
                 WHERE proname = ClassDB.foldPgID('sharedTestFunction')
                       AND proOwner = user0OID AND proNamespace = sharedSchemaOID
                ))
         )
   THEN
      RETURN 'FAIL: Code 7';
   END IF;

   --verify that user 1 still owns objects in public schema
   IF NOT(6 = (SELECT COUNT(*) FROM pg_catalog.pg_class
               WHERE relName IN (ClassDB.foldPgID('publicTestTable'),
                                 ClassDB.foldPgID('publicTestIndex'),
                                 ClassDB.foldPgID('publicTestSequence'),
                                 ClassDB.foldPgID('publicTestView'),
                                 ClassDB.foldPgID('publicTestMatView'),
                                 ClassDB.foldPgID('publicTestType'))
                AND relOwner = user1OID AND relNamespace = publicSchemaOID
               )
      AND EXISTS(SELECT COUNT(*) FROM pg_catalog.pg_proc
                  WHERE proName = ClassDB.foldPgID('publicTestFunction')
                  AND proOwner = user1OID
                  AND proNamespace = publicSchemaOID)
         )
   THEN
      RETURN 'FAIL: Code 8';
   END IF;
   
   RETURN 'PARTIAL PASS - not all functionalty tested';
--------------------------------------------------------------------------------
--Test additional functionality, including default role (CURRENT_USER) and 
-- allowing of non-existent objects


--------------------------------------------------------------------------------
--Misc. edge cases: different capitalizations, no objects in schema


--------------------------------------------------------------------------------
--Expected rejections/exceptions


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

   --test certain miscellaneous functions
   RAISE INFO '%   Miscellany',
      pg_temp.testMiscellany();

   --test ownership reassignment
   RAISE INFO '%   OwnershipReassignment',
      pg_temp.testOwnershipReassignment();
END;
$$  LANGUAGE plpgsql;


SELECT pg_temp.testHelperFunctions();


ROLLBACK;
