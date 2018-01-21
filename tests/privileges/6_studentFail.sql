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


--Not access any objects in classdb schema, should be prevented by not having
-- USAGE on the classdb schema anyway
SELECT ClassDB.createUser('testuser', 'password');
SELECT ClassDB.dropUser('testuser');

SELECT ClassDB.createStudent('teststu', 'noname');
SELECT ClassDB.resetUserPassword('teststu');
SELECT ClassDB.listUserConnections('teststu');
SELECT ClassDB.killUserConnections('teststu');
SELECT ClassDB.dropStudent('teststu');

SELECT ClassDB.createInstructor('testins', 'noname');
SELECT ClassDB.dropInstructor('testins');

SELECT ClassDB.createDBManager('testman', 'noname');
SELECT ClassDB.dropDBManager('testman');

SELECT ClassDB.dropAllStudents();


--Not read Student or Instructor tables (non-access to classdb schema should also prevent this)
SELECT * FROM ClassDB.Student;
SELECT * FROM ClassDB.Instructor;
