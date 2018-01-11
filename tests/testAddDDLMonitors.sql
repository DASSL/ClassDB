--testAddUserMgmt.sql - ClassDB

--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab (DASSL)
--dassl.github.io

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.


--The following test script should be run as a superuser, otherwise tests will fail

--***WARNING*** - This script truncates ClassDB.DDLActivity

--The following tests are performed. An error code of ERROR X.Y indicates that test
-- y in section x failed

--A) Checks as super-user
--1) Check that all student DDL statements are logged
--2) Check that DDL Operation names are logged correctly
--3) Check that DDL Objects names are logged correctly

--B) Checks as instructor

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
   --Clear the DDL Activity log
   TRUNCATE ClassDB.DDLActivity;

   --Create users to test DDL monitors
   PERFORM ClassDB.createStudent('ddlStudent01', 'ddl test student 01');
   PERFORM ClassDB.createStudent('ddlStudent02', 'ddl test student 02');
   PERFORM ClassDB.createInstructor('ddlInstructor01', 'ddl test instructor 01');
   PERFORM ClassDB.createDBManager('ddlDBManager01', 'ddl test db manager 01');

   --Perform actions as student 1
   SET SESSION AUTHORIZATION ddlStudent01;

   CREATE TABLE MyTable
   (
      MyAttr INT
   );

   DROP TABLE MyTable;

   END IF;

   RESET SESSION AUTHORIZATION;

   --Check that all DDL activities have been logged
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

   --Check that all DDL activities have been logged
   IF (SELECT COUNT(*) FROM ClassDB.DDLActivity) <> 2 THEN
      RAISE EXCEPTION 'ERROR CODE B.1';
   END IF;

   --Check that the right ops were logged
   IF NOT EXISTS(SELECT * FROM ClassDB.DDLActivity
                 WHERE DDLOperation = 'DROP TABLE')
   OR NOT EXISTS(SELECT * FROM ClassDB.DDLActivity
                 WHERE DDLOperation = 'CREATE TABLE') THEN
      RAISE EXCEPTION 'ERROR CODE B.2';
   END IF;

   --Check that the right object name was logged
   IF (SELECT COUNT(*) FROM ClassDB.DDLActivity
       WHERE DDLObject = 'ddlstudent01.mytable') <> 2 THEN
      RAISE EXCEPTION 'ERROR CODE B.3';
   END IF;

   RESET SESSION AUTHORIZATION;

   --Drop users & related objects
   --PERFORM ClassDB.dropStudent('ddlStudent01', true);
   --PERFORM ClassDB.dropStudent('ddlStudent02', true);
   --PERFORM ClassDB.dropInstructor('ddlInstructor01', true);
   --PERFORM ClassDB.dropDBManager('ddlDBManager01', true);

   RAISE NOTICE 'Success!';
END;
$$;
