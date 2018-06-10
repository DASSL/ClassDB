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

   --test if student-initiated schema drop is disallowed by default
   RAISE INFO '%   isSchemaDropAllowed',
   CASE ClassDB.isSchemaDropAllowed()
      WHEN TRUE THEN 'FAIL: Code 1' ELSE 'PASS'
   END;

--------------------------------------------------------------------------------

   --test with a student: should be able to drop tables but not a schema

   PERFORM ClassDB.createStudent('s1', 's1 name');
   SET SESSION AUTHORIZATION s1;

   --table create and drop: should not cause exception
   BEGIN
      CREATE TABLE t1(a integer);
      DROP TABLE t1;
      RAISE INFO '%   drop table by student', 'PASS';

   EXCEPTION
      WHEN OTHERS THEN
         RAISE INFO '%   drop table by student', 'FAIL: Code 2'
                    USING HINT = SQLERRM;
   END;

   --schema create: should not cause exception
   BEGIN
      CREATE SCHEMA schema_created_by_s1;
      RAISE INFO '%   create schema by student', 'PASS';

   EXCEPTION
      WHEN OTHERS THEN
         RAISE INFO '%   create schema by student', 'FAIL: Code 3'
                    USING HINT = SQLERRM;
   END;

   --schema drop (schema created by student): should cause exception
   BEGIN
      DROP scHema schema_created_by_s1; --spelling 'scHema' intentional
      RAISE INFO '%   drop schema created by student disallowed', 'FAIL: Code 4';

   EXCEPTION
      WHEN OTHERS THEN
         RAISE INFO '%   drop schema created by student disallowed', 'PASS';
   END;

   --schema drop (schema assigned to student): should cause exception
   BEGIN
      DROP SCHEMA s1;
      RAISE INFO '%   drop schema assigned to student disallowed', 'FAIL: Code 5';

   EXCEPTION
      WHEN OTHERS THEN
         RAISE INFO '%   drop schema assigned to student disallowed', 'PASS';
   END;

   --drop owned objects: should cause exception
   BEGIN
      DrOP oWNeD BY CURRENT_USER; --spelling 'DrOP oWNeD' intentional
      RAISE INFO '%   drop owned by student disallowed', 'FAIL: Code 6';

   EXCEPTION
      WHEN OTHERS THEN
         RAISE INFO '%   drop owned by student disallowed', 'PASS';
   END;

--------------------------------------------------------------------------------

   --test with an instructor: should be able to drop any object

   RESET SESSION AUTHORIZATION;
   PERFORM ClassDB.createInstructor('i1', 'i1 name');
   SET SESSION AUTHORIZATION i1;

   --schema drop: should not cause exception
   BEGIN
      DROP SCHEMA i1;
      RAISE INFO '%   drop schema by instructor', 'PASS';

   EXCEPTION
      WHEN OTHERS THEN
         RAISE INFO '%   drop schema by instructor', 'FAIL: Code 7'
                    USING HINT = SQLERRM;
   END;

   --drop owned objects: should not cause exception
   BEGIN
      DROP OWNED BY CURRENT_USER;
      RAISE INFO '%   drop owned by instructor', 'PASS';

   EXCEPTION
      WHEN OTHERS THEN
         RAISE INFO '%   drop owned by instructor', 'FAIL: Code 8'
                    USING HINT = SQLERRM;
   END;

--------------------------------------------------------------------------------

   --test with a DB manager: should be able to drop any object

   RESET SESSION AUTHORIZATION;
   PERFORM ClassDB.createDBManager('d1', 'd1 name');
   SET SESSION AUTHORIZATION d1;

   --schema drop: should not cause exception
   BEGIN
      DROP SCHEMA d1;
      RAISE INFO '%   drop schema by DB manager', 'PASS';

   EXCEPTION
      WHEN OTHERS THEN
         RAISE INFO '%   drop schema by DB manager', 'FAIL: Code 9'
                    USING HINT = SQLERRM;
   END;

   --drop owned objects: should not cause exception
   BEGIN
      DROP OWNED BY CURRENT_USER;
      RAISE INFO '%   drop owned by DB manager', 'PASS';

   EXCEPTION
      WHEN OTHERS THEN
         RAISE INFO '%   drop owned by DB manager', 'FAIL: Code 10'
                    USING HINT = SQLERRM;
   END;

--------------------------------------------------------------------------------

   --test with a non-ClassDB user: should be able to drop any schema/object

   RESET SESSION AUTHORIZATION;
   CREATE USER u1;
   CREATE SCHEMA schema_u1 AUTHORIZATION u1;
   SET SESSION AUTHORIZATION u1;

   --schema drop: should not cause exception
   BEGIN
      DROP SCHEMA schema_u1;
      RAISE INFO '%   drop schema by non-ClassDB user', 'PASS';

   EXCEPTION
      WHEN OTHERS THEN
         RAISE INFO '%   drop schema by non-ClassDB user', 'FAIL: Code 10'
                    USING HINT = SQLERRM;
   END;

   --drop owned objects: should not cause exception
   BEGIN
      DROP OWNED BY CURRENT_USER;
      RAISE INFO '%   drop owned by non-ClassDB user', 'PASS';

   EXCEPTION
      WHEN OTHERS THEN
         RAISE INFO '%   drop owned by non-ClassDB user', 'FAIL: Code 11'
                    USING HINT = SQLERRM;
   END;

--------------------------------------------------------------------------------

   --test allowing student-initiated schema drop

   --allow student-initiated schema drop as an instructor
   RESET SESSION AUTHORIZATION;
   SET SESSION AUTHORIZATION i1;

   PERFORM ClassDB.allowSchemaDrop();
   RAISE INFO '%   allowSchemaDrop',
      CASE ClassDB.isSchemaDropAllowed()
         WHEN TRUE THEN 'PASS' ELSE 'FAIL: Code 12'
      END;

   --test schema drop with a student: should be able to drop any object
   RESET SESSION AUTHORIZATION;
   SET SESSION AUTHORIZATION s1;

   --schema drop: should not cause exception
   BEGIN
      DROP SCHEMA s1;
      RAISE INFO '%   drop schema by student allowed', 'PASS';

   EXCEPTION
      WHEN OTHERS THEN
         RAISE INFO '%   drop schema by student allowed', 'FAIL: Code 13'
                    USING HINT = SQLERRM;
   END;

   --drop owned objects: should not cause exception
   BEGIN
      DROP OWNED BY CURRENT_USER;
      RAISE INFO '%   drop owned by student allowed', 'PASS';

   EXCEPTION
      WHEN OTHERS THEN
         RAISE INFO '%   drop owned by student allowed', 'FAIL: Code 14'
                    USING HINT = SQLERRM;
   END;

--------------------------------------------------------------------------------

   --test changing back to disallowing student-initiated schema drop

   --disallow as an instructor
   RESET SESSION AUTHORIZATION;
   SET SESSION AUTHORIZATION i1;

   PERFORM ClassDB.disallowSchemaDrop();
   RAISE INFO '%   disallowSchemaDrop',
      CASE ClassDB.isSchemaDropAllowed()
         WHEN TRUE THEN 'FAIL: Code 15' ELSE 'PASS'
      END;


END
$$;

ROLLBACK;
