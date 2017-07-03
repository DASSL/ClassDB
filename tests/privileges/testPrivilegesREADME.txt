testPrivilegesREADME.txt - ClassDB

Andrew Figueroa, Steven Rollo, Sean Murthy
Data Science & Systems Lab (DASSL), Western Connecticut State University (WCSU)

(C) 2017- DASSL. ALL RIGHTS RESERVED.
Licensed to others under CC 4.0 BY-SA-NC
https://creativecommons.org/licenses/by-nc-sa/4.0/

PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.


The files in this folder test the effective privileges of each role in ClassDB.
Scripts that contain "Pass" in their file name are intended to run without issues,
those that contain "Fail" should run only with issues (every statement should fail).
These tests are only intended to examine the prvileges of each role, and not the
functionality of any of ClassDB's facilities. See testPrepareClassDB.sql for tests
which perform those tasks.

The files will be run in the order below, but it is necessary to switch users
between the execution of each script.

Prior to running the 0_setup.sql script, run the appropriate versions of 
prepareClassServer.sql and prepareClassDB.sql and stay connected to database.

The 0_setup.sql script will create three users, one for each type of role. The 
password for each of these test roles is the same as their user name.

ins0 - Instructor
stu0 - Student
dbm0 - DBManager


Run prepareClassServer.sql and prepareClassDB.sql as a superuser, stay connected
Execute: 0_setup.sql

Switch to ins0
Execute: 1_instructorPass.sql

Switch to stu0
Execute: 2_studentPass.sql

Switch to dbm0
Execute: 3_dbmanagerPass.sql

Switch to ins0
Execute: 4_instructorPass2.sql
Execute: 5_instructorFail.sql

Switch to stu0
Execute: 6_studentFail.sql

Switch to dbm0
Execute: 7_dbmanagerFail.sql

Switch back to superuser
Execute: 8_cleanup.sql
