--6_studentFail.sql - ClassDB

--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab (DASSL), Western Connecticut State University (WCSU)

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.


--Not read tables in other users' schemas
--TODO: Tests Pending

--Not CUD on public schema
INSERT INTO public.testInsTab VALUES ('Hello student');

UPDATE public.testInsTab
SET col1 = 'Hello'
WHERE TRUE;

DELETE FROM public.testInstTab;


--Not execute any classdb functions
SELECT classdb.createUser('testuser', 'password');
SELECT classdb.dropUser('testuser');

SELECT classdb.createStudent('teststu', 'noname');
SELECT classdb.resetUserPassword('teststu');
SELECT classdb.listUserConnections('teststu');
SELECT classdb.killUserConnections('teststu');
SELECT classdb.dropStudent('teststu');

SELECT classdb.createInstructor('testins', 'noname');
SELECT classdb.dropInstructor('testins');

SELECT classdb.createDBManager('testman', 'noname');
SELECT classdb.dropDBManager('testman');

SELECT classdb.dropAllStudents();


--Not read Student or Instructor tables (non-access to class schema should also prevent this)
SELECT * FROM classdb.Student;
SELECT * FROM classdb.Instructor;
