--5_instructorFail.sql - ClassDB

--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab (DASSL), Western Connecticut State University (WCSU)

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.


--Not modify username or logging columns in Student and instructor tables
UPDATE classdb.Student
SET userName = 'diffName'
WHERE userName = 'stu0';

UPDATE classdb.Student
SET lastddlactivity = '2017-06-30'
WHERE userName = 'stu0';

UPDATE classdb.Student
SET lastddloperation = 'CREATE TABLE'
WHERE userName = 'stu0';

UPDATE classdb.Student
SET lastddlobject = 'test'
WHERE userName = 'stu0';

UPDATE classdb.Student
SET ddlcount = 20
WHERE userName = 'stu0';

UPDATE classdb.Student
SET lastconnection = '2017-06-30'
WHERE userName = 'stu0';

UPDATE classdb.Student
SET connectioncount = 10
WHERE userName = 'stu0';

--Not read other instructor or dbmanager tables
SELECT * FROM ins0.testInsUsr;
SELECT * FROM dbm0.testDbmUsr;


--Not excute createUser function
SELECT classdb.createUser('testusr', 'password');


--Not drop classdb functions (also covers ALTER and REPLACE)
DROP FUNCTION IF EXISTS classdb.createUser(userName VARCHAR(63), initialPwd VARCHAR(128));
DROP FUNCTION IF EXISTS classdb.createStudent(studentUserName VARCHAR(63),
                        studentName VARCHAR(100), schoolID VARCHAR(20),
                        initialPwd VARCHAR(128));
DROP FUNCTION IF EXISTS classdb.createInstructor(instructorUserName VARCHAR(63),
                        instructorName VARCHAR(100), initialPwd VARCHAR(128));
DROP FUNCTION IF EXISTS classdb.createDBManager(managerUserName VARCHAR(63),
                        initialPwd VARCHAR(128));
DROP FUNCTION IF EXISTS classdb.dropStudent(userName VARCHAR(63));
DROP FUNCTION IF EXISTS classdb.dropAllStudents();
DROP FUNCTION IF EXISTS classdb.dropInstructor(userName VARCHAR(63));
DROP FUNCTION IF EXISTS classdb.dropDBManager(userName VARCHAR(63));
DROP FUNCTION IF EXISTS classdb.dropUser(userName VARCHAR(63));
DROP FUNCTION IF EXISTS classdb.resetUserPassword(userName VARCHAR(63));
DROP FUNCTION IF EXISTS classdb.listUserConnections(VARCHAR(63));
DROP FUNCTION IF EXISTS classdb.killUserConnections(VARCHAR(63));
DROP FUNCTION IF EXISTS classdb.killConnection(INT);


--Not drop meta functions (also covers ALTER and REPLACE)
DROP FUNCTION IF EXISTS public.listTables(VARCHAR(63));
DROP FUNCTION IF EXISTS public.describe(VARCHAR(63), VARCHAR(63));
