--testAddDDLActivityLogging.sql - ClassDB

--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab (DASSL)
--https://dassl.github.io

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.


--The following test script should be run as a superuser



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



CREATE OR REPLACE FUNCTION pg_temp.checkDDLActivityTable()
RETURNS VARCHAR AS
$$
BEGIN
   --Check that no extra activity was logged. GROUP BY UserName and use HAVING COUNT(*)
   -- to check how many new activity rows have been added for each test user.
   -- If COUNT(*) > 1, then too many connection rows were added for that user.
   -- For PostgreSQL versions prior to 9.5 If COUNT(*) > 1, then too many
   -- connection rows were added for that user since N/A is filled in for blank rows
   --
   --Remove ClassDB.isServerVersionAfter('9.4') when support for pg versions before
   -- 9.5 is dropped
   IF ClassDB.isServerVersionAfter('9.4') THEN
     IF EXISTS (SELECT UserName
                FROM ClassDB.DDLActivity
                WHERE userName IN ('ddltu01', 'ddlins01', 'ddldbm01')
                GROUP BY UserName
                HAVING COUNT(*) > 1)
     THEN
        RETURN 'FAIL: Code 1';
     END IF;
   ELSE
     IF EXISTS (SELECT UserName
                FROM ClassDB.DDLActivity
                WHERE userName IN ('ddltu01', 'ddlins01', 'ddldbm01')
                GROUP BY UserName
                HAVING COUNT(*) > 3)
     THEN
        RETURN 'FAIL: Code 1';
     END IF;
   END IF;



   --Check that all test users have activity logged. This test will fail one or
   -- more users are missing associated rows.
   --Use regexp_split_to_table to generate a temp. table containing
   -- the test user names. The do the LEFT OUTER JOIN, and filter for rows that
   -- do not exist in ClassDB.DDLActivity (WHERE D.UserName) IS NULL
   --Use the stored test start time to filter out old connections.
   IF EXISTS
   (
      WITH ClassDBUser AS
      (
         SELECT *
         FROM regexp_split_to_table('ddlstu01 ddlins01 ddldbm01', E'\\s+') AS UserName
      )
      SELECT U.UserName
      FROM ClassDBUser U
      LEFT OUTER JOIN ClassDB.DDLActivity D ON U.UserName = D.UserName
      WHERE D.UserName IS NULL)
   THEN
      RETURN 'FAIL: Code 2';
   END IF;


   --Check that the non-ClassDB user does not have any associated activity rows
   -- added.
   IF EXISTS (SELECT UserName
              FROM ClassDB.DDLActivity
              WHERE UserName = 'unown01')
   THEN
      RETURN 'FAIL: Code 3';
   END IF;


   RETURN 'PASS';
END;
$$ LANGUAGE plpgsql;



DO
$$
BEGIN
   --Clear the DDL Activity log
   TRUNCATE ClassDB.DDLActivity;

   --Create ClassDB users to test DDL monitors
   PERFORM ClassDB.createStudent('ddlstu01', 'ddl test student 01');
   PERFORM ClassDB.createInstructor('ddlins01', 'ddl test instructor 01');
   PERFORM ClassDB.createDBManager('ddldbm01', 'ddl test db manager 01');

   --Create a non-ClassDB user. Their DDL operations should not be logged
   CREATE USER unown01;
   CREATE SCHEMA AUTHORIZATION unown01;



   --Perform DDL ops as student
   SET SESSION AUTHORIZATION ddlstu01;

   CREATE TABLE StudentTable(MyAttr INT);
   DROP TABLE StudentTable;

   RESET SESSION AUTHORIZATION;


   --Perform DDL ops as instructor
   SET SESSION AUTHORIZATION ddlins01;

   CREATE TABLE InstructorTable(ID INT);
   DROP TABLE InstructorTable;

   RESET SESSION AUTHORIZATION;


   ----Perform DDL ops as dbmanager
   SET SESSION AUTHORIZATION ddldbm01;

   CREATE TABLE DBManTable(MyAttr INT);
   DROP TABLE DBManTable;


   RESET SESSION AUTHORIZATION;


   --Perform DDL ops as a non-classdb user
   SET SESSION AUTHORIZATION unown01;

   CREATE TABLE unown01.NonClassDBTable(ID INT);
   DROP TABLE unown01.NonClassDBTable;

   RESET SESSION AUTHORIZATION;

   --grant temporary access to functions to compare versions so that above tests
   -- will work properly on pg versions prior to 9.5. Remove GRANTs once support
   -- for pg versions prior to 9.5 is dropped.
   GRANT EXECUTE ON FUNCTION ClassDB.isServerVersionAfter(VARCHAR, BOOLEAN)
      TO ClassDB_Instructor, ClassDB_DBManager;

   GRANT EXECUTE ON FUNCTION ClassDB.compareServerVersion(VARCHAR, BOOLEAN)
      TO ClassDB_Instructor, ClassDB_DBManager;

   GRANT EXECUTE ON FUNCTION ClassDB.compareServerVersion(VARCHAR, VARCHAR, BOOLEAN)
      TO ClassDB_Instructor, ClassDB_DBManager;

   RAISE INFO '%, checkDDLActivityTable() (superuser)', pg_temp.checkDDLActivityTable();

   SET SESSION AUTHORIZATION ddlins01;
   RAISE INFO '%, checkDDLActivityTable() (Instructor)', pg_temp.checkDDLActivityTable();

   SET SESSION AUTHORIZATION ddldbm01;
   RAISE INFO '%, checkDDLActivityTable() (DBManager)', pg_temp.checkDDLActivityTable();

   RESET SESSION AUTHORIZATION;
END;
$$;

ROLLBACK;
