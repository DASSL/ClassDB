--1_instructorPass.sql - ClassDB

--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab (DASSL), Western Connecticut State University (WCSU)

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.


--Execute appropriate ClassDB functions (this is not inteded to test correctness of the
-- each function).

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


--CRUD on tables created by the instructor. This table should be placed in their own schema
-- and be accessed without needing to be fully schema qualified

--Create without schema qualification
CREATE TABLE test
(
   col1 VARCHAR(10)
);

--Insert with schema qualification - ensures test was created in the ins0 schema
INSERT INTO ins0.test VALUES ('hello');

--Select
SELECT * FROM test;

--Update
UPDATE test
SET col1 = 'goodbye'
WHERE TRUE;

--Delete
DELETE FROM test;

DROP TABLE test;


--CRUD on public schema
CREATE TABLE public.pubTest
(
   col1 VARCHAR(10)
)

INSERT INTO public.pubTest VALUES ('hello');

SELECT * FROM public.pubTest;

UPDATE public.pubTest
SET col1 = 'goodbye'
WHERE TRUE;

DELETE FROM public.pubTest;

DROP TABLE public.pubTest;


--Read from columns in Student and Instructor tables
SELECT * FROM classdb.Student;
SELECT * FROM classdb.Instructor;


--Update name and schoolID in Student table
SELECT classdb.createStudent('teststu', 'Nonme', '50124');

UPDATE classdb.Student
SET studentName = 'NoName', schoolID = '50125'
WHERE userName = 'teststu';

SELECT classdb.dropStudent('teststu');


--Create table in public schema to test read privileges for Students and DBManagers
CREATE TABLE public.testInsPub
(
   col1 VARCHAR(20)
);

INSERT INTO public.testInsTab VALUES ('Read by: anyone');

--Create table in $user schema to test non-access for other roles
CREATE TABLE testInsUsr
(
   col1 VARCHAR(20)
)

INSERT INTO testInsUsr VALUES('Read by: no one');
