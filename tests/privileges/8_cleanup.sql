--8_cleanup.sql - ClassDB

--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab (DASSL), Western Connecticut State University (WCSU)

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.


--This table was created to test read access for tables in the public schema by
-- students (1_instructorPass.sql)
DROP TABLE testInsPub;

--This table was created to test non-acces for tables in an Instructor's $user
-- schema by others (1_instructorPass.sql)
DROP TABLE testInsUsr;

--This table was created to test read access for tables in student's $user schemas
-- by instructors (2_studentPass.sql)
DROP TABLE testStuUsr;

--This table was created to test non-acces for tables in a DBManagers's $user
-- schema by others (3_dbmanagerPass.sql)
DROP TABLE testDbmUsr;
