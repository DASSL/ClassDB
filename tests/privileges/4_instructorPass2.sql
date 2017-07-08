--4_instructorPass2.sql - ClassDB

--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab (DASSL), Western Connecticut State University (WCSU)

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.


--Read the $user schema of a student (should return one row)
SELECT * FROM stu0.testStuUsr;

-- Execute meta functions
SELECT listTables();
SELECT listTables('stu0');

SELECT describe('testInsPub', 'public');
SELECT describe('testStuUsr', 'stu0');
