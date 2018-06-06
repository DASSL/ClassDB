--testDisallowSchemaDrop.sql - ClassDB

--Sean Murthy
--Data Science & Systems Lab (DASSL)
--https://dassl.github.io/

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.


--This script should be run as a superuser

--This script tests the functionality in addDisallowSchemaDropReco.sql
-- only nominal tests are covered presently
-- need to plan a test for cases that should cause exceptions


START TRANSACTION;

--tests superuser privilege on current_user
DO
$$
BEGIN
   IF NOT ClassDB.isSuperUser() THEN
      RAISE EXCEPTION 'Insufficient privileges: script must be run as a superuser';
   END IF;
END
$$;


DO
$$
BEGIN

   --student-initiated schema drop should be disallowed by default
   RAISE INFO '%   isSchemaDropAllowed',
   CASE ClassDB.isSchemaDropAllowed()
      WHEN TRUE THEN 'FAIL: Code 1' ELSE 'PASS'
   END;

   --test with a student user: should not be able to drop any schema
   BEGIN
      PERFORM ClassDB.createStudent('s1', 's1 name');
      SET SESSION AUTHORIZATION s1;
      DROP SCHEMA s1; --should cause exception
      RAISE INFO '%   drop schema by student disallowed', 'FAIL: Code 2';

      EXCEPTION
         WHEN OTHERS THEN
            RAISE INFO '%   drop schema by student disallowed', 'PASS';
   END;

   --revert to original user
   RESET SESSION AUTHORIZATION;

   --test with an instructor: should be able to drop any schema
   BEGIN
      PERFORM ClassDB.createInstructor('i1', 'i1 name');
      SET SESSION AUTHORIZATION i1;
      DROP SCHEMA i1; --should not cause exception
      RAISE INFO '%   drop schema by instructor', 'PASS';

      EXCEPTION
         WHEN OTHERS THEN
            RAISE INFO '%   drop schema by instructor', 'FAIL: Code 3'
                       USING HINT = SQLERRM;
   END;

   --revert to original user
   RESET SESSION AUTHORIZATION;

   --test with a DB manager: should be able to drop any schema
   BEGIN
      PERFORM ClassDB.createDBManager('d1', 'd1 name');
      SET SESSION AUTHORIZATION d1;
      DROP SCHEMA d1; --should not cause exception
      RAISE INFO '%   drop schema by DB manager', 'PASS';

      EXCEPTION
         WHEN OTHERS THEN
            RAISE INFO '%   drop schema by DB manager', 'FAIL: Code 4'
                       USING HINT = SQLERRM;
   END;

   --revert to original user
   RESET SESSION AUTHORIZATION;

   --test with a non-ClassDB user: should be able to drop any schema
   BEGIN
      CREATE USER u1;
      CREATE SCHEMA schema_u1 AUTHORIZATION u1;

      SET SESSION AUTHORIZATION u1;
      DROP SCHEMA schema_u1; --should not cause exception
      RAISE INFO '%   drop schema by non-ClassDB user', 'PASS';

      EXCEPTION
         WHEN OTHERS THEN
            RAISE INFO '%   drop schema by non-ClassDB user', 'FAIL: Code 5'
                       USING HINT = SQLERRM;
   END;


--------------------------------------------------------------------------------

   --revert to original user
   RESET SESSION AUTHORIZATION;

   --allow student-initiated schema drop
   PERFORM ClassDB.allowSchemaDrop();
   RAISE INFO '%   allowSchemaDrop',
      CASE ClassDB.isSchemaDropAllowed()
         WHEN TRUE THEN 'PASS' ELSE 'FAIL: Code 6'
      END;

   --student should be able to drop schema
   BEGIN
      PERFORM ClassDB.createStudent('s2', 's2 name');
      SET SESSION AUTHORIZATION s2;
      DROP SCHEMA s2; --should not cause exception
      RAISE INFO '%   drop schema by student allowed', 'PASS';

      EXCEPTION
         WHEN OTHERS THEN
            RAISE INFO '%   drop schema by student allowed', 'FAIL: Code 7'
                       USING HINT = SQLERRM;
   END;

--------------------------------------------------------------------------------

   --revert to original user
   RESET SESSION AUTHORIZATION;

   --disallow student-initiated schema drop
   PERFORM ClassDB.disallowSchemaDrop();
   RAISE INFO '%   disallowSchemaDrop',
      CASE ClassDB.isSchemaDropAllowed()
         WHEN TRUE THEN 'FAIL: Code 7' ELSE 'PASS'
      END;


END
$$;

ROLLBACK;
