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


--Test frequent views access
SELECT * FROM MyActivitySummary;
SELECT * FROM MyDDLActivity;
SELECT * FROM MyConnectionActivity;


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
