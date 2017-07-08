Andrew Figueroa, Steven Rollo, Sean Murthy
Data Science & Systems Lab (DASSL), Western Connecticut State University (WCSU)

(C) 2017- DASSL. ALL RIGHTS RESERVED.
Licensed to others under CC 4.0 BY-SA-NC:
https://creativecommons.org/licenses/by-nc-sa/4.0/

PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.

--------------------------------------------------------------------------------

Tests are run in the following order:
createDropUserTest()
createStudentTest()
createInstructorTest()
createDBManagerTest()
dropStudentTest()
dropInstructorTest()
dropDBManagerTest()

---
PENDING Tests:

In order to properly test the login capabilities and password for the users that 
were created, the users have to be manually tested by connecting to the DBMS 
through a client, using the following usernames and passwords. Keep in mind that
usernames and passwords are CASE SENSITIVE. After testing, login as a superuser,
run the final two queries, and then run testAddUserMgmtCleanup.sql


Students:

UserName: teststu0
Password: testStu0

UserName: teststu1
Password: testStu1

UserName: teststu2
Password: testpass

UserName: teststu3
Password: testpass2

Instructors:

UserName: testins0
Password: testIns0

UserName: testins1
Password: testpass4

Multi-role users:

UserName: teststudbm0
Password: testpass3

UserName: teststuins1
Password: testpass5

UserName: testinsmg0
Password: testpass7

DBManagers:

UserName: testdbm0
Password: testDBM0

UserName: testdbm1
Password: testpass6


Log back in as a superuser and run the following two queries:

SELECT * FROM classdb.Student;

SELECT * FROM classdb.Instructor;

The results should appear as so:

SELECT * FROM classdb.Student;
  username   |   studentname    | schoolid | lastddlactivity | lastddloperation | lastddlobject | ddlcount | lastconnection | connectioncount
-------------+------------------+----------+-----------------+------------------+---------------+----------+----------------+-----------------
 teststu0    | Yvette Alexander |          |                 |                  |               |        0 |                |               0
 teststu1    | Edwin Morrison   | 101      |                 |                  |               |        0 |                |               0
 teststu2    | Ramon Harrington | 102      |                 |                  |               |        0 |                |               0
 teststu3    | Cathy Young      |          |                 |                  |               |        0 |                |               0
 teststudbm0 | Edwin Morrison   |          |                 |                  |               |        0 |                |               0
 teststuins1 | Rosalie Flowers  | 106      |                 |                  |               |        0 |                |               0
(6 rows)


SELECT * FROM classdb.Instructor;
  username   | instructorname
-------------+-----------------
 testins0    | Dave Paul
 testins1    | Dianna Wilson
 teststuins1 | Rosalie Flowers
 testinsmg0  | Shawn Nash
(4 rows)
