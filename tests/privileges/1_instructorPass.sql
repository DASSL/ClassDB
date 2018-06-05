--1_instructorPass.sql - ClassDB

--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab (DASSL)
--https://dassl.github.io/

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.

START TRANSACTION;


--Execute appropriate ClassDB functions (these tests do not verify correctness
-- of each function)
SELECT ClassDB.createStudent('teststu', 'noname');
SELECT ClassDB.resetPassword('teststu');
SELECT ClassDB.listUserConnections('teststu');
SELECT ClassDB.killUserConnections('teststu');
SELECT ClassDB.dropStudent('teststu', TRUE, TRUE, 'drop_c');

--ClassDB.dropAllStudents is not being tested here because it would drop the
-- test students that will later be used to connect to the DB
--SELECT ClassDB.dropAllStudents(TRUE, TRUE, 'drop_c');

SELECT ClassDB.createInstructor('testins', 'noname');
SELECT ClassDB.dropInstructor('testins', TRUE, TRUE, 'drop_c');

SELECT ClassDB.createDBManager('testman', 'noname');
SELECT ClassDB.dropDBManager('testman', TRUE, TRUE, 'drop_c');

SELECT ClassDB.importConnectionLog();


--CRUD on tables created by the instructor. This table should be placed in their
-- own schema and be accessed without needing to be fully schema qualified
--Create without schema qualification
CREATE TABLE Test
(
   Col1 VARCHAR(10)
);

--Insert with schema qualification - ensures test table was created in the
-- ptins0 schema
INSERT INTO ptins0.Test VALUES ('hello');

--Select
SELECT * FROM Test;

--Update
UPDATE Test
SET Col1 = 'goodbye';

--Delete
DELETE FROM Test;
DROP TABLE Test;


--CRUD on public schema
CREATE TABLE public.PublicTest
(
   Col1 VARCHAR(10)
);

INSERT INTO public.PublicTest VALUES ('hello');

SELECT * FROM public.PublicTest;

UPDATE public.PublicTest
SET Col1 = 'goodbye';

DELETE FROM public.PublicTest;
DROP TABLE public.PublicTest;


--Read from columns in RoleBase table
SELECT * FROM ClassDB.RoleBase;


--Read from columns in User, Student, Instructor, and DBManager views
SELECT * FROM ClassDB.User;
SELECT * FROM ClassDB.DBManager;
SELECT * FROM ClassDB.Student;
SELECT * FROM ClassDB.Instructor;


--Update FullName and ExtraInfo in RoleBase table
SELECT ClassDB.createStudent('updateInfoTest', 'Temp name', NULL, 'Temp info');

UPDATE ClassDB.RoleBase
SET FullName = 'Updated name', ExtraInfo = 'Updated info'
WHERE roleName = 'updateInfoTest';

SELECT ClassDB.dropStudent('updateInfoTest', TRUE, TRUE, 'drop_c');


--Create table in public schema to test read privileges for all users
CREATE TABLE public.TestInsPublic
(
   Col1 VARCHAR(20)
);

INSERT INTO public.testInsPublic VALUES ('Read by: anyone');

--Create table in $user schema to test non-access for other roles
CREATE TABLE TestInsUsr
(
   col1 VARCHAR(20)
);

INSERT INTO testInsUsr VALUES('Read by: ptins0');


COMMIT;
