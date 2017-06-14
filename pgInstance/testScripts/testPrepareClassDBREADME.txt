Andrew Figueroa, Steven Rollo, Sean Murthy
Data Science & Systems Lab at Western Connecticut State University (dassl@WCSU)

testPrepareClassDBREADME.txt

ClassDB - Created: 2017-06-05; Modified 2017-06-13

---
Tests are run in the following order:
createUserTest()
createStudentTest()
createInstructorTest()
createDBManagerTest()
dropStudentTest()
dropInstructorTest()
dropDBManagerTest()

---
PENDING Tests:

In order to properly test the login capabilities and password for the Student
and Instructor roles created, these have to be manually tested by logging in
to the DBMS using the following usernames and passwords. Keep in mind that
usernames and passwords are CASE SENSITIVE. After testing, please log back in
as a superuser and run testPrepareClassDBCleanup.sql


Students:

UserName: testStudent0
Password: testStudent0

UserName: testStudent1
Password: 101

UserName: testStudent2
Password: testpass

UserName: testStudent3
Password: testpass2


Instructors:

UserName: testInstructor0
Password: testInstructor0

UserName: testInstructor1
Password: testpass4

Multi-role users:

UserName: testStuInst0
Password: testpass3

UserName: testStuInst1
Password: testpass5


DBManagers:

UserName: testDBManager0
Password: testDBManager0

UserName: testDBManager1
Password: testpass6

UserName: testInstManage0
Password: testpass7


Run the following two queries:

SELECT * FROM classdb.Student;

SELECT * FROM classdb.Instructor;

The results should appear as so:

SELECT * FROM classdb.Student;
   username   |   studentname    | schoolid
--------------+------------------+---------
 testStudent0 | Yvette Alexander |
 testStudent1 | Edwin Morrison   | 101
 testStudent2 | Ramon Harrington | 102
 testStudent3 | Cathy Young      |
 testStuInst0 | Edwin Morrison   | 102
 testStuInst1 | Rosalie Flowers  | 106
(6 rows)


SELECT * FROM classdb.Instructor;
    username     | instructorname
-----------------+-----------------
 testStuInst0    | Edwin Morrison
 testInstructor0 | Dave Paul
 testInstructor1 | Dianna Wilson
 testStuInst1    | Rosalie Flowers
 testInstManage0 | Shawn Nash
(5 rows)
