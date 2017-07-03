--7_dbmanagerFail.sql - ClassDB

--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab (DASSL), Western Connecticut State University (WCSU)

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.


--Not read Student's $user schemas
SELECT * FROM stu0.insStuTest;


--Not read other instructors or dbmanagers tables
--TODO: Some of these tests are pending
SELECT * FROM ins0.testInsUsr;


--Not drop classdb functions (also covers ALTER and REPLACE)
DROP FUNCTION IF EXISTS classdb.createUser(userName VARCHAR(63), initialPwd VARCHAR(128));
DROP FUNCTION IF EXISTS classdb.createStudent(studentUserName VARCHAR(63),
                        studentName VARCHAR(100), schoolID VARCHAR(20),
                        initialPwd VARCHAR(128));
DROP FUNCTION IF EXISTS classdb.createInstructor(instructorUserName VARCHAR(63),
                        instructorName VARCHAR(100), initialPwd VARCHAR(128));
DROP FUNCTION IF EXISTS classdb.createDBManager(managerUserName VARCHAR(63), managerName VARCHAR(100),
                        initialPwd VARCHAR(128));
DROP FUNCTION IF EXISTS classdb.dropStudent(userName VARCHAR(63));
DROP FUNCTION IF EXISTS classdb.dropAllStudents();
DROP FUNCTION IF EXISTS classdb.dropInstructor(userName VARCHAR(63));
DROP FUNCTION IF EXISTS classdb.dropDBManager(userName VARCHAR(63));
DROP FUNCTION IF EXISTS classdb.dropUser(userName VARCHAR(63));
DROP FUNCTION IF EXISTS classdb.changeUserPassword(userName VARCHAR(63), 
                                                   password VARCHAR(128));
DROP FUNCTION IF EXISTS classdb.resetUserPassword(userName VARCHAR(63));
DROP FUNCTION IF EXISTS classdb.listUserConnections(VARCHAR(63));
DROP FUNCTION IF EXISTS classdb.killUserConnections(VARCHAR(63));
DROP FUNCTION IF EXISTS classdb.killConnection(INT);


--Not drop meta functions (also covers ALTER and REPLACE)
DROP FUNCTION IF EXISTS public.listTables(VARCHAR(63));
DROP FUNCTION IF EXISTS public.describe(VARCHAR(63), VARCHAR(63));
