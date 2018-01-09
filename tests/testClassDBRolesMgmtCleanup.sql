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
DELETE FROM ClassDB.Student WHERE userName = 'teststu0';

DROP SCHEMA testStu1;
DROP ROLE testStu1;
DELETE FROM ClassDB.Student WHERE userName = 'teststu1';

DROP SCHEMA testStu2;
DROP ROLE testStu2;
DELETE FROM ClassDB.Student WHERE userName = 'teststu2';

DROP SCHEMA testStu3;
DROP ROLE testStu3;
DELETE FROM ClassDB.Student WHERE userName = 'teststu3';

DROP SCHEMA testIns0;
DROP OWNED BY testIns0;
DROP ROLE testIns0;
DELETE FROM ClassDB.Instructor WHERE userName = 'testins0';

DROP SCHEMA testIns1;
DROP OWNED BY testIns1;
DROP ROLE testIns1;
DELETE FROM ClassDB.Instructor WHERE userName = 'testins1';

DROP SCHEMA testStuDBM0;
DROP ROLE testStuDBM0;
DELETE FROM ClassDB.Student WHERE userName = 'teststudbm0';
DELETE FROM ClassDB.Instructor WHERE userName = 'teststudbm0';

DROP SCHEMA testStuIns1;
DROP OWNED BY testStuIns1;
DROP ROLE testStuIns1;
DELETE FROM ClassDB.Student WHERE userName = 'teststuins1';
DELETE FROM ClassDB.Instructor WHERE userName = 'teststuins1';

DROP SCHEMA testDBM0;
DROP ROLE testDBM0;

DROP SCHEMA testDBM1;
DROP ROLE testDBM1;

DROP SCHEMA testInsMg0;
DROP OWNED BY testInsMg0;
DROP ROLE testInsMg0;
DELETE FROM ClassDB.Instructor WHERE userName = 'testinsmg0';


DROP FUNCTION ClassDB.prepareClassDBTest();
DROP FUNCTION ClassDB.createUserTest();
DROP FUNCTION ClassDB.createInstructorTest();
DROP FUNCTION ClassDB.createDBManagerTest();
DROP FUNCTION ClassDB.dropStudentTest();
DROP FUNCTION ClassDB.dropInstructorTest();
DROP FUNCTION ClassDB.dropDBManagerTest();
