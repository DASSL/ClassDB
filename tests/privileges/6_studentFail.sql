--6_studentFail.sql - ClassDB

--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab (DASSL)
--https://dassl.github.io/

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.


--Not read tables in other users' schemas
SELECT * FROM ptins0.testInsUsr;
SELECT * FROM ptstu0.testStuUsr;
SELECT * FROM ptdbm0.testDbmUsr;


--Not CUD on public schema
INSERT INTO public.testInsPublic VALUES ('Hello student');

UPDATE public.testInsPublic
SET col1 = 'Hello';

DELETE FROM public.testInsPublic;

--Not read from team's table
SELECT * FROM ptteam0.SharedTable;

--Not create on team's schema
CREATE TABLE ptteam0.StudentTestTable(col1 VARCHAR);

--Not drop own schema
DROP SCHEMA ptstu1;

--Not access any objects in classdb schema, should be prevented by not having
-- USAGE on the classdb schema anyway
SELECT ClassDB.createStudent('teststu_pt', 'testname');
SELECT ClassDB.resetPassword('teststu_pt');
SELECT ClassDB.listUserConnections('teststu_pt');
SELECT ClassDB.killUserConnections('teststu_pt');
SELECT ClassDB.createTeam('testteam_pt');
SELECT ClassDB.addToTeam('teststu_pt', 'testteam_pt');
SELECT ClassDB.removeFromTeam('teststu_pt', 'testteam_pt');
SELECT ClassDB.revokeTeam('testteam_pt');
SELECT ClassDB.dropTeam('testteam_pt');
SELECT ClassDB.revokeStudent('teststu_pt');
SELECT ClassDB.dropStudent('teststu_pt', TRUE, TRUE, 'drop_c');

SELECT ClassDB.createInstructor('testins_pt', 'testname');
SELECT ClassDB.revokeInstructor('testins_pt');
SELECT ClassDB.dropInstructor('testins_pt', TRUE, TRUE, 'drop_c');

SELECT ClassDB.createDBManager('testman_pt', 'noname');
SELECT ClassDB.revokeDBManager('testman_pt');
SELECT ClassDB.dropDBManager('testman_pt', TRUE, TRUE, 'drop_c');

SELECT ClassDB.importConnectionLog();



--Not read Student or Instructor tables (non-access to classdb schema should also prevent this)
SELECT * FROM ClassDB.Student;
SELECT * FROM ClassDB.Instructor;
