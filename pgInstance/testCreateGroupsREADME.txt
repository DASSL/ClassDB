Andrew Figueroa

testCreateGroupsREADME.txt

Users and Roles for CS205; Created: 2017-06-05; Modified 2017-06-05

---
Tests are run in the following order:
createUserTest()
createStudentTest()
createInstructorTest()
dropStudentTest()
dropInstructorTest()
setSearchPathTest()

---
PENDING Tests:

In order to properly test the login capabilities and password for the Student
and Instructor roles created, these have to be manually tested by logging in 
to the DBMS using the following usernames and passwords. Keep in mind that
usernames and passwords are CASE SENSITIVE. After testing, please run 
testCreateGroupsCleanup.sql


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

Run the following two queries:

SELECT * FROM classdb.Student;

SELECT * FROM classdb.Instructor;

The results should appear as so:


