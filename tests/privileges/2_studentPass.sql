--2_studentPass.sql - ClassDB

--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab (DASSL)
--https://dassl.github.io/

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.

START TRANSACTION;

--Test catalog functions
--Create table in student's schema
CREATE TABLE Test
(
   col1 VARCHAR(10)
);

SELECT listTables();
SELECT describe('test');

DROP TABLE test;


--Read from public frequent views
SELECT * FROM public.myActivitySummary;
SELECT * FROM public.MyDDLActivity;
SELECT * FROM public.MyConnectionActivity;
SELECT * FROM public.myActivity;


--CRUD on tables created by the student. This table should be placed in their own schema
-- and be accessed without needing to be fully schema qualified
--Create without schema qualification
CREATE TABLE test
(
   col1 VARCHAR(10)
);

--Insert with schema qualification - ensures Test was created in ptstu0 schema
INSERT INTO ptstu0.test VALUES ('hello');

SELECT * FROM test;

UPDATE test
SET col1 = 'goodbye'
WHERE TRUE;

DELETE FROM test;
DROP TABLE test;

--Create (but not drop) schema
CREATE SCHEMA ptstu0schema;

--CRUD on tables owned by student in team schema
CREATE TABLE ptteam0.SharedTable
(
   col1 VARCHAR(10)
);

INSERT INTO ptteam0.SharedTable VALUES ('test');

SELECT * FROM ptteam0.SharedTable;

UPDATE ptteam0.SharedTable
SET col1 = 'TEST'
WHERE col1 = 'test';

DELETE FROM ptteam0.SharedTable;
DROP TABLE ptteam0.SharedTable;


--CRUD on tables owned by team in team schema
CREATE TABLE ptteam0.FirstTeamTable
(
   col1 VARCHAR(10)
);
INSERT INTO ptteam0.FirstTeamTable VALUES('test');

SELECT * FROM ptteam0.FirstTeamTable;

UPDATE ptteam0.FirstTeamTable
SET col1 = 'TEST'
WHERE col1 = 'test';

DELETE FROM ptTeam0.FirstTeamTable;

DROP TABLE ptTeam0.FirstTeamTable;


--Create table in team schema to test read by instructor, CRUD by other member
CREATE TABLE ptteam0.SharedTable
(
   col1 VARCHAR(20)
);

INSERT INTO ptteam0.SharedTable VALUES ('In Team''s scheama');


--Read on tables in the public schema created by Instructor
SELECT * FROM testInsPublic;


--Create table in $user schema to test read privileges for Instructors and non-
-- access for DBManagers and other students
CREATE TABLE testStuUsr
(
   col1 VARCHAR(20)
);

INSERT INTO testStuUsr VALUES ('Read by: Instructor');


COMMIT;
