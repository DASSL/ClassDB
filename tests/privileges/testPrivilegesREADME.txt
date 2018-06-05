testPrivilegesREADME.txt - ClassDB

Andrew Figueroa, Steven Rollo, Sean Murthy
Data Science & Systems Lab (DASSL)
https://dassl.github.io/

(C) 2017- DASSL. ALL RIGHTS RESERVED.
Licensed to others under CC 4.0 BY-SA-NC
https://creativecommons.org/licenses/by-nc-sa/4.0/

PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.


The files in this folder test the effective privileges of each role in ClassDB.
Scripts that contain "Pass" in their file name are intended to run without issues,
those that contain "Fail" should run only with issues (every statement should 
fail). These tests are only intended to examine the privileges of each role, and
not the functionality of any of ClassDB's facilities.

The files will be run in the order listed below, however, it is necessary to
switch users between the execution of each script.

Prior to running the 0_setup.sql script, it is recommended to use a full, but
otherwise unmodified setup of ClassDB.It may be possible to test with
only some or no reco or opt portions installed, or with the system having been,
used but the outputs from running these tests will need to be interpreted
differently, since different messages may be displayed.

A script, runAllPrivilegeTests.psql, is included in the same directory as this
README file that performs the necessary steps for testing in an automated
manner. This script must be run with psql client. Additionally, the script
assumes that the script is started by a user with the name postgres. If this is
not true, the role name can be modified within that script. 

---

Steps for testing privileges:

The 0_setup.sql script will create six users, two for each type of role. The 
password for each of these test roles is the same as their user name.

ptins0, ptins1 - Instructor
ptstu0, ptstu1 - Student
ptdbm0, ptdbm1 - DBManager


Run setup as a superuser, stay connected
Execute: 0_setup.sql

Switch to ptins0
Execute: 1_instructorPass.sql

Switch to ptstu0
Execute: 2_studentPass.sql

Switch to ptdbm0
Execute: 3_dbmanagerPass.sql

Switch to ptins1
Execute: 4_instructorPass2.sql
Execute: 5_instructorFail.sql

Switch to ptstu1
Execute: 6_studentFail.sql

Switch to ptdbm1
Execute: 7_dbmanagerFail.sql

Switch back to superuser
Execute: 8_cleanup.sql
