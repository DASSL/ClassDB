--0_setup.sql - ClassDB

--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab (DASSL)
--https://dassl.github.io/

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.


START TRANSACTION;


--Create Instructor, Student, and DBManager to login for testing purposes.
-- The password for these users will be the same as their username
SELECT ClassDB.createInstructor('ptins0', 'Instructor 0');
SELECT ClassDB.createInstructor('ptins1', 'Instructor 1');

SELECT ClassDB.createStudent('ptstu0', 'Student 0');
SELECT ClassDB.createStudent('ptstu1', 'Student 1');

SELECT ClassDB.createDBManager('ptdbm0', 'DB Manager 0');
SELECT ClassDB.createDBManager('ptdbm1', 'DB Manager 1');

COMMIT;
