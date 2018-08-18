--testUserMgmt.sql - ClassDB

--Sean Murthy
--Data Science & Systems Lab (DASSL)
--https://dassl.github.io/

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.


--This script should be run as a superuser

--This script tests the functionality in addUserMgmtCore.sql


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

   --a total of six triggers with the given names should be defined
   IF 6 = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.triggers
              WHERE trigger_schema = 'classdb'
                    AND trigger_name IN('rejectnonuserddlactivityinsert',
                                        'rejectnonuserconnectionactivityinsert',
                                        'rejectddlactivityupdate',
                                        'rejectconnectionactivityupdate',
                                        'rejectddlactivitydelete',
                                        'rejectconnectionactivitydelete'
                                       )
             )
   THEN
      RAISE INFO '%   triggers', 'PASS';
   ELSE
      RAISE INFO '%   triggers', 'FAIL: Code 1';
   END IF;


   --table DDLActivity should reject rows for non-Classdb users
   BEGIN
      INSERT INTO ClassDB.DDLActivity
      VALUES ('nosuchuser', CURRENT_TIMESTAMP,
              'test_DDL_op', 'test_DDL_object', ClassDB.getSessionID()
             );

      RAISE INFO '%   DDLActivity reject non-user insert', 'FAIL; Code 2';
   EXCEPTION
      WHEN raise_exception THEN
         RAISE INFO '%   DDLActivity reject non-user insert', 'PASS';
      WHEN OTHERS THEN
         RAISE INFO '%   DDLActivity reject non-user insert', 'FAIL; Code 2'
                    USING DETAIL = SQLERRM;
   END;


   --table ConnectionActivity should reject rows for non-Classdb users
   BEGIN
      INSERT INTO ClassDB.ConnectionActivity
      VALUES ('nosuchuser', CURRENT_TIMESTAMP, 'C', ClassDB.getSessionID(), '');

      RAISE INFO '%   ConnectionActivity reject non-user insert', 'FAIL; Code 3';
   EXCEPTION
      WHEN raise_exception THEN
         RAISE INFO '%   ConnectionActivity reject non-user insert', 'PASS';
      WHEN OTHERS THEN
         RAISE INFO '%   ConnectionActivity reject non-user insert',
                    'FAIL; Code 3'
                    USING DETAIL = SQLERRM;
   END;


   --table DDLActivity should permit rows for known ClassDB users
   PERFORM ClassDB.createStudent('s1', 's1 name');

   BEGIN
      INSERT INTO ClassDB.DDLActivity
      VALUES ('s1', CURRENT_TIMESTAMP,
              'test_DDL_op', 'test_DDL_object', ClassDB.getSessionID()
             );

      RAISE INFO '%   DDLActivity accept user insert', 'PASS';
   EXCEPTION
      WHEN raise_exception THEN
         RAISE INFO '%   DDLActivity accept user insert', 'FAIL; Code 4';
      WHEN OTHERS THEN
         RAISE INFO '%   DDLActivity accept user insert', 'FAIL; Code 4'
                    USING DETAIL = SQLERRM;
   END;


   --table ConnectionActivity should permit rows for known ClassDB users
   BEGIN
      INSERT INTO ClassDB.ConnectionActivity
      VALUES ('s1', CURRENT_TIMESTAMP, 'C', ClassDB.getSessionID(), '');

      RAISE INFO '%   ConnectionActivity accept user insert', 'PASS';
   EXCEPTION
      WHEN raise_exception THEN
         RAISE INFO '%   ConnectionActivity accept user insert',
                    'FAIL; Code 5';
      WHEN OTHERS THEN
         RAISE INFO '%   ConnectionActivity accept user insert',
                    'FAIL; Code 5'
                    USING DETAIL = SQLERRM;
   END;


   --table DDLActivity should not permit update
   BEGIN
      UPDATE ClassDB.DDLActivity SET UserName = CURRENT_USER;
      RAISE INFO '%   DDLActivity reject update', 'FAIL; Code 6';
   EXCEPTION
      WHEN raise_exception THEN
         RAISE INFO '%   DDLActivity reject update', 'PASS';
      WHEN OTHERS THEN
         RAISE INFO '%   DDLActivity reject update', 'FAIL; Code 6'
                    USING DETAIL = SQLERRM;
   END;

   --table DDLActivity should not permit delete
   BEGIN
      DELETE FROM ClassDB.DDLActivity;
      RAISE INFO '%   DDLActivity reject delete', 'FAIL; Code 7';
   EXCEPTION
      WHEN raise_exception THEN
         RAISE INFO '%   DDLActivity reject delete', 'PASS';
      WHEN OTHERS THEN
         RAISE INFO '%   DDLActivity reject delete', 'FAIL; Code 7'
                    USING DETAIL = SQLERRM;
   END;

   --table ConnectionActivity should not permit update
   BEGIN
      UPDATE ClassDB.ConnectionActivity SET UserName = CURRENT_USER;
      RAISE INFO '%   ConnectionActivity reject update', 'FAIL; Code 8';
   EXCEPTION
      WHEN raise_exception THEN
         RAISE INFO '%   ConnectionActivity reject update', 'PASS';
      WHEN OTHERS THEN
         RAISE INFO '%   ConnectionActivity reject update', 'FAIL; Code 8'
                    USING DETAIL = SQLERRM;
   END;

   --table ConnectionActivity should not permit delete
   BEGIN
      DELETE FROM ClassDB.ConnectionActivity;
      RAISE INFO '%   ConnectionActivity reject delete', 'FAIL; Code 9';
   EXCEPTION
      WHEN raise_exception THEN
         RAISE INFO '%   ConnectionActivity reject delete', 'PASS';
      WHEN OTHERS THEN
         RAISE INFO '%   ConnectionActivity reject delete', 'FAIL; Code 9'
                    USING DETAIL = SQLERRM;
   END;

END
$$;


--ignore all test data
ROLLBACK;
