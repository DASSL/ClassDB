--testAddLogMgmtCleanup.sql - ClassDB

--Steven Rollo, Sean Murthy
--Data Science & Systems Lab (DASSL)
--https://dassl.github.io

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.


--The following test script should be run as a superuser, otherwise tests will fail

--This script cleans up a failed or aborted run of testAddLogMgmt.psql. Since
-- the log management test script must switch connections several times, the test
-- failing will result in the test users remaining on the server. This script removes
-- those users.





--Tests for superuser privilege on current_user
DO
$$
BEGIN
   IF NOT classdb.isSuperUser() THEN
      RAISE EXCEPTION 'Insufficient privileges: script must be run as a superuser';
   END IF;


   --Remove orpahned users
   PERFORM ClassDB.dropStudent('conStudent01', true);
   PERFORM ClassDB.dropStudent('conStudent02', true);
   PERFORM ClassDB.dropInstructor('conInstructor01', true);
   PERFORM ClassDB.dropDBManager('conDBManager01', true);

   DROP SCHEMA conStudent01 CASCADE;
   DROP SCHEMA conStudent02 CASCADE;
   DROP SCHEMA conInstructor01 CASCADE;
   DROP SCHEMA conDBManager01 CASCADE;

   DROP OWNED BY conNonClassDB;
   DROP USER conNonClassDB;
END
$$;
