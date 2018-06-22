--8_cleanup.sql - ClassDB

--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab (DASSL)
--https://dassl.github.io/

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.


SELECT ClassDB.dropInstructor('ptins0', TRUE, TRUE, 'drop_c');
SELECT ClassDB.dropInstructor('ptins1', TRUE, TRUE, 'drop_c');
SELECT ClassDB.dropStudent('ptstu0', TRUE, TRUE, 'drop_c');
SELECT ClassDB.dropStudent('ptstu1', TRUE, TRUE, 'drop_c');
SELECT ClassDB.dropDBManager('ptdbm0', TRUE, TRUE, 'drop_c');
SELECT ClassDB.dropDBManager('ptdbm1', TRUE, TRUE, 'drop_c');
SELECT Classdb.dropTeam('ptteam0');
