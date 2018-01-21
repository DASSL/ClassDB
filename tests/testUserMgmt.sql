--testUserMgmt.sql - ClassDB

--Sean Murthy
--Data Science & Systems Lab (DASSL)
--https://dassl.github.io/

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.


--This script should be run as a superuser

--This script tests the functionality in addUserMgmt.sql
-- only nominal tests are covered presently
-- need to plan a test for cases that should cause exceptions


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


DO
$$
BEGIN

   --make sure the activity tables are empty
   RAISE INFO '%   EXISTS(ClassDB.DDLActivity)',
      CASE EXISTS(SELECT * FROM ClassDB.DDLActivity)
         WHEN TRUE THEN 'FAIL: Code 1'
         ELSE 'PASS'
      END;

   RAISE INFO '%   EXISTS(ClassDB.ConnectionActivity)',
      CASE EXISTS(SELECT * FROM ClassDB.ConnectionActivity)
         WHEN TRUE THEN 'FAIL: Code 2'
         ELSE 'PASS'
      END;

   --create a new user: activities can only be inserted for known users
   PERFORM ClassDB.createRole('u1', 'u1 name', FALSE);

   --directly insert a row into DDLActivity
   INSERT INTO ClassDB.DDLActivity
   VALUES ('u1', CURRENT_TIMESTAMP, 'DROP TABLE', 'pg_temp.sample');

   --DDLActivity should have one row
   RAISE INFO '%   COUNT(ClassDB.DDLActivity)',
      CASE (SELECT COUNT(*) FROM ClassDB.DDLActivity)
         WHEN 1 THEN 'PASS'
         ELSE 'FAIL: Code 3'
      END;

   --directly insert a row into ConnectionActivity
   INSERT INTO ClassDB.ConnectionActivity
   VALUES ('u1', CURRENT_TIMESTAMP);

   --ConnectionActivity should have one row
   RAISE INFO '%   COUNT(ClassDB.ConnectionActivity)',
      CASE (SELECT COUNT(*) FROM ClassDB.ConnectionActivity)
         WHEN 1 THEN 'PASS'
         ELSE 'FAIL: Code 3'
      END;

END
$$;


--ignore all test data
ROLLBACK;
