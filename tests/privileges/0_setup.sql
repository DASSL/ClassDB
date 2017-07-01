--0_setup.sql - ClassDB

--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab (DASSL), Western Connecticut State University (WCSU)

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.


--Create Instructor, Student, and DBManager to login for testing purposes.
-- The password for these users will be the same as their username
SELECT classdb.createInstructor('ins0', 'NoName');

SELECT classdb.createStudent('stu0', 'NoName');

SELECT classdb.createDBManager('dbm0', 'NoName');
