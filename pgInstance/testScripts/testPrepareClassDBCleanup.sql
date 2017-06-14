--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab at Western Connecticut State University (dassl@WCSU)
--
--testPrepareClassDBCleanup.sql
--
--ClassDB - Created: 2017-06-05; Modified 2017-06-13


DROP SCHEMA "testStudent0";
DROP ROLE "testStudent0";
DELETE FROM classdb.Student WHERE userName = 'testStudent0';

DROP SCHEMA "testStudent1";
DROP ROLE "testStudent1";
DELETE FROM classdb.Student WHERE userName = 'testStudent1';

DROP SCHEMA "testStudent2";
DROP ROLE "testStudent2";
DELETE FROM classdb.Student WHERE userName = 'testStudent2';

DROP SCHEMA "testStudent3";
DROP ROLE "testStudent3";
DELETE FROM classdb.Student WHERE userName = 'testStudent3';

DROP SCHEMA "testInstructor0";
DROP ROLE "testInstructor0";
DELETE FROM classdb.Instructor WHERE userName = 'testInstructor0';

DROP SCHEMA "testInstructor1";
DROP ROLE "testInstructor1";
DELETE FROM classdb.Instructor WHERE userName = 'testInstructor1';

DROP SCHEMA "testStuInst0";
DROP ROLE "testStuInst0";
DELETE FROM classdb.Student WHERE userName = 'testStuInst0';
DELETE FROM classdb.Instructor WHERE userName = 'testStuInst0';

DROP SCHEMA "testStuInst1";
DROP ROLE "testStuInst1";
DELETE FROM classdb.Student WHERE userName = 'testStuInst1';
DELETE FROM classdb.Instructor WHERE userName = 'testStuInst1';

DROP SCHEMA "testDBManager0";
DROP ROLE "testDBManager0";

DROP SCHEMA "testDBManager1";
DROP ROLE "testDBManager1";

DROP SCHEMA "testInstManage0";
DROP ROLE "testInstManage0";
DELETE FROM classdb.Instructor WHERE userName = 'testInstManage0';



DROP FUNCTION classdb.prepareClassDBTest();
DROP FUNCTION classdb.createUserTest();
DROP FUNCTION classdb.createInstructorTest();
DROP FUNCTION classdb.createDBManagerTest();
DROP FUNCTION classdb.dropStudentTest();
DROP FUNCTION classdb.dropInstructorTest();
DROP FUNCTION classdb.dropDBManagerTest();
