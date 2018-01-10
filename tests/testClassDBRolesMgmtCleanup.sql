--testClassDBRolesMgmtCleanup.sql - ClassDB

--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab (DASSL)
--https://dassl.github.io/

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.


DROP SCHEMA testStu0;
DROP ROLE testStu0;
DELETE FROM ClassDB.RoleBase WHERE roleName = 'teststu0';

DROP SCHEMA testStu1;
DROP ROLE testStu1;
DELETE FROM ClassDB.RoleBase WHERE roleName = 'teststu1';

DROP SCHEMA testStu2;
DROP ROLE testStu2;
DELETE FROM ClassDB.RoleBase WHERE roleName = 'teststu2';

DROP SCHEMA testStu3;
DROP ROLE testStu3;
DELETE FROM ClassDB.RoleBase WHERE roleName = 'teststu3';

DROP SCHEMA testStu4;
DROP SCHEMA newTestStu4;
DROP ROLE testStu4;
DELETE FROM ClassDB.RoleBase WHERE roleName = 'teststu4';

--Test(s) that create these users are not currently run as they have not been
--updated to match the new RoleBase version of the functions they test
/*
DROP SCHEMA testIns0;
DROP OWNED BY testIns0;
DROP ROLE testIns0;
DELETE FROM ClassDB.RoleBase WHERE roleName = 'testins0';

DROP SCHEMA testIns1;
DROP OWNED BY testIns1;
DROP ROLE testIns1;
DELETE FROM ClassDB.RoleBase WHERE roleName = 'testins1';
*/

DROP SCHEMA testStuDBM0;
DROP ROLE testStuDBM0;
DELETE FROM ClassDB.RoleBase WHERE roleName = 'teststudbm0';

--Test(s) that create these users are not currently run as they have not been
--updated to match the new RoleBase version of the functions they test
/*
DROP SCHEMA testStuIns1;
DROP OWNED BY testStuIns1;
DROP ROLE testStuIns1;
DELETE FROM ClassDB.RoleBase WHERE roleName = 'teststuins1';

DROP SCHEMA testDBM0;
DROP ROLE testDBM0;

DROP SCHEMA testDBM1;
DROP ROLE testDBM1;

DROP SCHEMA testInsMg0;
DROP OWNED BY testInsMg0;
DROP ROLE testInsMg0;
DELETE FROM ClassDB.RoleBase WHERE roleName = 'testinsmg0';
*/


DROP FUNCTION ClassDB.prepareClassDBTest();
DROP FUNCTION ClassDB.createStudentTest();
DROP FUNCTION ClassDB.createInstructorTest();
DROP FUNCTION ClassDB.createDBManagerTest();
DROP FUNCTION ClassDB.dropStudentTest();
DROP FUNCTION ClassDB.dropInstructorTest();
DROP FUNCTION ClassDB.dropDBManagerTest();
