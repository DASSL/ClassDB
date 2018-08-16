--testServerVersionComparers.sql - ClassDB

--Sean Murthy
--Data Science & Systems Lab (DASSL)
--https://dassl.github.io/

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.


--This script should be run as a superuser

--This script tests functions that compare server version number(s)


--Make sure the current user has sufficient privilege to run this script
-- privilege required: superuser
DO
$$
BEGIN
   IF NOT ClassDB.isSuperUser() THEN
      RAISE EXCEPTION 'Insufficient privilege: script must be run as a superuser';
   END IF;
END
$$;



--Define a temporary function to test version comparers
CREATE OR REPLACE FUNCTION pg_temp.testServerVersionComparers() RETURNS TEXT AS
$$
BEGIN

   --test function to convert int server version to string
   IF ClassDB.intServerVersionToString(100001) <> '10.1'
      OR ClassDB.intServerVersionToString(110000) <> '11.0'
      OR ClassDB.intServerVersionToString(90105) <> '9.1.5'
      OR ClassDB.intServerVersionToString(90200) <> '9.2.0'
      OR ClassDB.intServerVersionToString(91201) <> '9.12.1'
      OR ClassDB.intServerVersionToString(91427) <> '9.14.27'
      OR ClassDB.intServerVersionToString(110046) <> '11.46'
   THEN
      RETURN 'FAIL: Code 1';
   END IF;

   --test function to return current server's version number
   --can't test equality because value from current_setting can have distro suffix
   -- instead, test if value from current_setting starts with server version
   IF POSITION(ClassDB.getServerVersion() IN current_setting('server_version')) <> 1
   THEN
      RETURN 'FAIL: Code 2';
   END IF;


   --test any two version numbers: test part 2
   IF ClassDB.compareServerVersion('9.6', '9.5') <= 0 THEN
      RETURN 'FAIL: Code 3';
   END IF;

   IF ClassDB.compareServerVersion('9.5', '9.6') >= 0 THEN
      RETURN 'FAIL: Code 4';
   END IF;

   IF ClassDB.compareServerVersion('8.5', '9.6') >= 0 THEN
      RETURN 'FAIL: Code 5';
   END IF;

   IF ClassDB.compareServerVersion('9.6', '8.5') <= 0 THEN
      RETURN 'FAIL: Code 6';
   END IF;


   --test any two version numbers: ignore part 2
   IF ClassDB.compareServerVersion('9.6', '9.6', FALSE) <> 0 THEN
      RETURN 'FAIL: Code 7';
   END IF;

   IF ClassDB.compareServerVersion('9.6', '9.5', FALSE) <> 0 THEN
      RETURN 'FAIL: Code 8';
   END IF;

   IF ClassDB.compareServerVersion('9.5', '9.6', FALSE) <> 0 THEN
      RETURN 'FAIL: Code 9';
   END IF;


   --test any two version numbers: single-part input
   IF ClassDB.compareServerVersion('10', '10', FALSE) <> 0 THEN
      RETURN 'FAIL: Code 10';
   END IF;

   IF ClassDB.compareServerVersion('10', '9.5', FALSE) <= 0 THEN
      RETURN 'FAIL: Code 11';
   END IF;

   IF ClassDB.compareServerVersion('9.5', '10', FALSE) >= 0 THEN
      RETURN 'FAIL: Code 12';
   END IF;


   --test some version number with server's version number
   IF ClassDB.compareServerVersion('9.5')
      <>
      ClassDB.compareServerVersion('9.5', ClassDB.getServerVersion())
   THEN
      RETURN 'FAIL: Code 13';
   END IF;


   --shortcut functions
   IF ClassDB.isServerVersionBefore('0') THEN
      RETURN 'FAIL: Code 14';
   END IF;

   IF ClassDB.isServerVersionBefore('0', FALSE) THEN
      RETURN 'FAIL: Code 15';
   END IF;

   IF NOT ClassDB.isServerVersionAfter('0') THEN
      RETURN 'FAIL: Code 16';
   END IF;

   IF NOT ClassDB.isServerVersionAfter('0', FALSE) THEN
      RETURN 'FAIL: Code 17';
   END IF;

   IF NOT ClassDB.isServerVersion(ClassDB.getServerVersion()) THEN
      RETURN 'FAIL: Code 18';
   END IF;

   IF ClassDB.isServerVersion('0.8') THEN
      RETURN 'FAIL: Code 19';
   END IF;

   --the following tests fail when Postgres version reaches 100000.8
   -- just change the argument at that point, or rewrite the tests
   IF NOT ClassDB.isServerVersionBefore('100000.8') THEN
      RETURN 'FAIL: Code 20';
   END IF;

   IF ClassDB.isServerVersionAfter('100000.8') THEN
      RETURN 'FAIL: Code 21';
   END IF;

   RETURN 'PASS';
END;
$$ LANGUAGE plpgsql;


--initiate test and announce result
DO
$$
BEGIN
   RAISE INFO '%   testServerVersionComparers',
              pg_temp.testServerVersionComparers();
END
$$;
