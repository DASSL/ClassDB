--2_studentPass.sql - ClassDB

--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab (DASSL), Western Connecticut State University (WCSU)

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.


-- Execute meta functions
CREATE TABLE test
(
   col1 VARCHAR(10)
);

SELECT listTables();
SELECT describe('test');


--CRUD on tables created by the student. This table should be placed in their own schema
-- and be accessed without needing to be fully schema qualified
--Create without schema qualification
CREATE TABLE test
(
   col1 VARCHAR(10)
);

--Insert with schema qualification - ensures test was created in the stu0 schema
INSERT INTO stu0.test VALUES ('hello');

SELECT * FROM test;

UPDATE test
SET col1 = 'goodbye'
WHERE TRUE;

DELETE FROM test;

DROP TABLE test;


--Read on tables in the public schema created by Instructor (should return 1 row)
SELECT * FROM testInsTab;


--Create table in $user schema to test read privileges for Instructors
CREATE TABLE insStuTest
(
   col1 VARCHAR(20)
);

INSERT INTO testStuTab VALUES ('Hello instructor');
