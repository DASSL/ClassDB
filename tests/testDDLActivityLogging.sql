--testAddDDLActivityLogging.sql - ClassDB

--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab (DASSL)
--https://dassl.github.io

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.


--The following test script should be run as a superuser, otherwise tests will fail

--***WARNING*** - This script truncates ClassDB.DDLActivity

--The following tests are performed. An error code of ERROR X.Y indicates that test
-- y in section x failed

--A) Checks as super-user
-- 1) Check that all student DDL statements are logged
-- 2) Check that DDL Operation names are logged correctly
-- 3) Check that DDL Objects names are logged correctly

--B) Checks as instructor
-- 1) Check that all student DDL statements are logged
-- 2) Check that DDL Operation names are logged correctly
-- 3) Check that DDL Objects names are logged correctly
-- 4) Check that instructor DDL operations are logged

--C) Checks for operations from multiple users
-- 1) Check that all ClassDB user types have DDL operations logged, and non-ClassDB
--     users are omitted
-- 2) Check that CREATE TABLE statements are logged
-- 3) Check that ALTER TABLE statements are logged
-- 4) Check that CREATE VIEW statements are logged
-- 5) Check that ALTER VIEW statements are logged
-- 6) Check that DROP VIEW statements are logged
-- 7) Check that DROP TABLE statements are logged

START TRANSACTION;

--Tests for superuser privilege on current_user
DO
$$
BEGIN
   IF NOT classdb.isSuperUser() THEN
      RAISE EXCEPTION 'Insufficient privileges: script must be run as a superuser';
   END IF;
END
$$;

DO
$$
BEGIN

   RAISE NOTICE 'Begining test of DDL Monitors';

   --Clear the DDL Activity log
   TRUNCATE ClassDB.DDLActivity;

   --Create ClassDB users to test DDL monitors
   RAISE NOTICE 'Creating test users';
   PERFORM ClassDB.createStudent('ddlStudent01', 'ddl test student 01');
   PERFORM ClassDB.createStudent('ddlStudent02', 'ddl test student 02');
   PERFORM ClassDB.createInstructor('ddlInstructor01', 'ddl test instructor 01');
   PERFORM ClassDB.createDBManager('ddlDBManager01', 'ddl test db manager 01');

   --Create a non-ClassDB user. Their DDL operations should not be logged
   CREATE USER ddlNonClassDBUser;
   CREATE SCHEMA AUTHORIZATION ddlNonClassDBUser;

   --Perform actions as student 1
   SET SESSION AUTHORIZATION ddlStudent01;
   RAISE NOTICE 'Performing DDL operations as a student';

   CREATE TABLE MyTable(MyAttr INT);
   DROP TABLE MyTable;

   RESET SESSION AUTHORIZATION;


   --Check that all DDL activities have been logged
   RAISE NOTICE 'Checking student DDL operations were logged';
   IF (SELECT COUNT(*) FROM ClassDB.DDLActivity) <> 2 THEN
      RAISE EXCEPTION 'ERROR CODE A.1';
   END IF;

   --Check that the right ops were logged
   IF NOT EXISTS(SELECT * FROM ClassDB.DDLActivity
                 WHERE DDLOperation = 'DROP TABLE')
   OR NOT EXISTS(SELECT * FROM ClassDB.DDLActivity
                 WHERE DDLOperation = 'CREATE TABLE') THEN
      RAISE EXCEPTION 'ERROR CODE A.2';
   END IF;

   --Check that the right object name was logged
   IF (SELECT COUNT(*) FROM ClassDB.DDLActivity
       WHERE DDLObject = 'ddlstudent01.mytable') <> 2 THEN
      RAISE EXCEPTION 'ERROR CODE A.3';
   END IF;


   --Check if the instructor can read the DDLActivity table
   SET SESSION AUTHORIZATION ddlInstructor01;
   RAISE NOTICE 'Checking instructor can read ClassDB.DDLActivity';

   --Check that all DDL activities have been logged
   IF (SELECT COUNT(*) FROM ClassDB.DDLActivity) <> 2 THEN
      RAISE EXCEPTION 'ERROR CODE B.1';
   END IF;

   --Check that the right ops were logged
   IF NOT EXISTS(SELECT * FROM ClassDB.DDLActivity
                 WHERE DDLOperation = 'CREATE TABLE')
   OR NOT EXISTS(SELECT * FROM ClassDB.DDLActivity
                 WHERE DDLOperation = 'DROP TABLE') THEN
      RAISE EXCEPTION 'ERROR CODE B.2';
   END IF;

   --Check that the right object name was logged
   IF (SELECT COUNT(*) FROM ClassDB.DDLActivity
       WHERE DDLObject = 'ddlstudent01.mytable') <> 2 THEN
      RAISE EXCEPTION 'ERROR CODE B.3';
   END IF;

   --Test DDL operations as instructor
   RAISE NOTICE 'Performing DDL operations as instructor';

   CREATE TABLE InstructorTable(ID INT);
   DROP TABLE InstructorTable;

   --Check that instructor operations were logged
   RAISE NOTICE 'Checking instructor DDL operations were logged';
   IF (SELECT COUNT(*) FROM ClassDB.DDLActivity) <> 4 THEN
      RAISE EXCEPTION 'ERROR CODE B.4';
   END IF;


   --Perform DDL operations as second student
   SET SESSION AUTHORIZATION ddlStudent02;
   RAISE NOTICE 'Performing DDL operations as a second student';

   CREATE TABLE MyTable(MyAttr INT);
   ALTER TABLE MyTable ADD COLUMN NewCol VARCHAR;

   CREATE VIEW MyView AS
   SELECT *
   FROM MyTable;
   ALTER VIEW MyView RENAME TO MyNewView;

   DROP VIEW MyNewView;
   DROP TABLE MyTable;


   --Test performing operations as DBManager
   SET SESSION AUTHORIZATION ddlDBManager01;
   RAISE NOTICE 'Performing DDL operations as DBManager';

   CREATE TABLE MyTable(MyAttr INT);
   ALTER TABLE MyTable ADD COLUMN NewCol VARCHAR;
   DROP TABLE MyTable;


   --Test performing operations as a non-ClassDB user
   SET SESSION AUTHORIZATION ddlNonClassDBUser;
   RAISE NOTICE 'Performing DDL operations as a non-ClassDB user';

   CREATE TABLE ddlNonClassDBUser.MyTable(ID INT);
   DROP TABLE ddlNonClassDBUser.MyTable;


   --Check that all DDL operation types have been logged
   SET SESSION AUTHORIZATION ddlInstructor01;
   RAISE NOTICE 'Checking that DDL oprations from all ClassDB user types have been logged';

   IF (SELECT COUNT(*) FROM ClassDB.DDLActivity) <> 13 THEN
      RAISE EXCEPTION 'ERROR CODE C.1';
   END IF;

   --Check that the right ops were logged
   IF NOT EXISTS(SELECT * FROM ClassDB.DDLActivity
                 WHERE DDLOperation = 'CREATE TABLE') THEN
      RAISE EXCEPTION 'ERROR CODE C.2';
   ELSEIF NOT EXISTS(SELECT * FROM ClassDB.DDLActivity
                     WHERE DDLOperation = 'ALTER TABLE') THEN
      RAISE EXCEPTION 'ERROR CODE C.3';
   ELSEIF NOT EXISTS(SELECT * FROM ClassDB.DDLActivity
                     WHERE DDLOperation = 'CREATE VIEW') THEN
      RAISE EXCEPTION 'ERROR CODE C.4';
   ELSEIF NOT EXISTS(SELECT * FROM ClassDB.DDLActivity
                     WHERE DDLOperation = 'ALTER VIEW') THEN
      RAISE EXCEPTION 'ERROR CODE C.5';
   ELSEIF NOT EXISTS(SELECT * FROM ClassDB.DDLActivity
                     WHERE DDLOperation = 'DROP VIEW') THEN
      RAISE EXCEPTION 'ERROR CODE C.6';
   ELSEIF NOT EXISTS(SELECT * FROM ClassDB.DDLActivity
                     WHERE DDLOperation = 'DROP TABLE') THEN
      RAISE EXCEPTION 'ERROR CODE C.7';
   END IF;

   RESET SESSION AUTHORIZATION;

   RAISE NOTICE 'Success!';
   RAISE NOTICE 'Displaying final contents of ClassDB.DDLActivity:';
END;
$$;

SELECT *
FROM ClassDB.DDLActivity;

ROLLBACK;
