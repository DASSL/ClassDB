--addUserMgmtCore.sql - ClassDB

--Sean Murthy
--Data Science & Systems Lab (DASSL)
--https://dassl.github.io/

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.


--This script requires the current user to be a superuser

--This script should be run after addRoleBaseMgmt.sql

--This script creates the tables, views, and triggers specific to user management
-- (not for team management)

START TRANSACTION;

--Suppress NOTICE messages for this script: won't apply to functions created here
-- hides unimportant but possibly confusing msgs generated as the script executes
SET LOCAL client_min_messages TO WARNING;


--Make sure the current user has sufficient privilege to run this script
-- privileges required: superuser
DO
$$
BEGIN
   IF NOT ClassDB.isSuperUser() THEN
      RAISE EXCEPTION 'Insufficient privileges: script must be run as a user'
                      ' with superuser privileges';
   END IF;
END
$$;



--Define a table to record DDL activity of users
-- no primary key is defined because there are no viable key attributes, and
-- there is no benefit to having a primary key
-- UserName is not constrained to known users because DDL activity may be
-- maintained for users who are no longer known, but see trigger definitions
-- DDLOperation and DDLObject are unsized so they can contain arbitrary strings
CREATE TABLE IF NOT EXISTS ClassDB.DDLActivity
(
  UserName ClassDB.IDNameDomain NOT NULL, --session user performing the operation
  StatementStartedAtUTC TIMESTAMP NOT NULL, --time at which the DDL op began
  DDLOperation VARCHAR NOT NULL --the actual DDL op, e.g., "DROP TABLE"
   CHECK(TRIM(DDLOperation) <> ''),
  DDLObject VARCHAR NOT NULL --name of the object of the DDL operation
   CHECK(TRIM(DDLObject) <> '')
);

--Set table permissions
-- make ClassDB the owner so it can perform any operation on it
-- prevent everyone else from doing anything with the table, except permit
-- instructors and DB managers to read rows
-- this pattern of ownership and grant/revoke applies to all objects defined in
-- this script: for brevity, such code is not prefaced again with comments unless
-- the code does something significantly different
ALTER TABLE ClassDB.DDLActivity OWNER TO ClassDB;
REVOKE ALL PRIVILEGES ON ClassDB.DDLActivity FROM PUBLIC;
GRANT SELECT ON ClassDB.DDLActivity TO ClassDB_Instructor, ClassDB_DBManager;



--Define a table to record connection activity of users
-- SessionID and ActivityType form a composite PK. SessionID is unique per session
-- and each session has only one connection and one disconnection.
-- UserName is not constrained to known users because connection activity may be
-- maintained for users who are no longer known, but see trigger definitions
--
--We conditionally either ALTER and existing ClassDB.ConnectionActivity
-- or CREATE a new one
DO
$$
BEGIN
   --If ClassDB.ConnectionActivity is present, upgrade it rather
   -- than recreate it and lose existing data
   IF  ClassDB.isColumnDefined('ClassDB', 'ConnectionActivity', 'UserName')
   THEN
      --UPGRADE FROM 2.0 TO 2.1
      -- The following table alterations are needed to upgrade ClassDB from 2.0 to 2.1
      -- These can be removed in a future version of ClassDB
      --Three columns are added, one is renamed
      --A partial index is added instead of a PK because it relies on two new attributes
      -- that will not have unique values for existing rows

      --Rename AcceptedAtUTC to better reflect that disconnections are now captured
      -- No IF EXISTS for RENAME COLUMN, so we use a helper to check if the column needs
      -- to be renamed
      IF ClassDB.isColumnDefined('ClassDB', 'ConnectionActivity', 'AcceptedAtUTC')
      THEN
         ALTER TABLE ClassDB.ConnectionActivity
            RENAME COLUMN AcceptedAtUTC TO ActivityAtUTC;
      END IF;

      --ActivityType, SessionID, and ApplicationName are added to ConnectionActivity
      ALTER TABLE IF EXISTS ClassDB.ConnectionActivity
         ADD COLUMN IF NOT EXISTS ActivityType CHAR(1) NOT NULL DEFAULT 'C'
                                  CHECK(ActivityType IN ('C', 'D'));

      --SessionID enforced as not NULL because there is always a SessionID associated with
      -- connection activity. However, if rows exists, they will be NULL when the column
      -- is added (which is an error). We use a temporary default to get around this.
      --Set a temporary default to add a value to existing rows
      ALTER TABLE IF EXISTS ClassDB.ConnectionActivity
         ADD COLUMN IF NOT EXISTS SessionID VARCHAR(17) NOT NULL DEFAULT '00000000.00000000';

      --Drop the temporary default. DROP DEFAULT is idempotent
      ALTER TABLE IF EXISTS ClassDB.ConnectionActivity
         ALTER COLUMN SessionID DROP DEFAULT;

      ALTER TABLE IF EXISTS ClassDB.ConnectionActivity
         ADD COLUMN IF NOT EXISTS ApplicationName ClassDB.IDNameDomain;

      --We use a partial unique index instead of a PK because both columns used are
      -- new, and will not have unique values for existing rows
      CREATE UNIQUE INDEX IF NOT EXISTS idx_SessionID_ActivityType
      ON ClassDB.ConnectionActivity(SessionID, ActivityType)
      WHERE SessionID <> '00000000.00000000';

   ELSE
      --If ConnectionActivity does not exist or is empty, just recreate it with
      -- v2.1 features

      --First drop dependant views
      DROP VIEW IF EXISTS ClassDB.Student;
      DROP VIEW IF EXISTS ClassDB.Instructor;
      DROP VIEW IF EXISTS ClassDB.DBManager;
      DROP VIEW IF EXISTS ClassDB.User;

      DROP TABLE IF EXISTS ClassDB.ConnectionActivity;
      CREATE TABLE ClassDB.ConnectionActivity
      (
        UserName ClassDB.IDNameDomain NOT NULL, --session user creating the connection
        ActivityAtUTC TIMESTAMP NOT NULL, --time at which the server accepted connection
        ActivityType CHAR(1) NOT NULL DEFAULT 'C' CHECK(ActivityType IN ('C', 'D')),
        SessionID VARCHAR(17) NOT NULL,
        ApplicationName ClassDB.IDNameDomain, --We expect AppName to be NULL for all connections
        PRIMARY KEY(SessionID, ActivityType)  --Create a PK on the new table because
                                              -- are no existing rows to cause issues
      );

      ALTER TABLE ClassDB.ConnectionActivity OWNER TO ClassDB;
      REVOKE ALL PRIVILEGES ON ClassDB.ConnectionActivity FROM PUBLIC;
      GRANT SELECT ON ClassDB.ConnectionActivity TO ClassDB_Instructor, ClassDB_DBManager;
   END IF;
END;
$$;



--Define a trigger function to raise an exception that an operation is disallowed
-- used to prevent non-user inserts to, and any updates to, tables DDLActivity
-- and ConnectionActivity
-- trigger functions cannot accept parameters, but the 0-based array TG_ARGV will
-- contain the arguments specified in the corresponding trigger definition
-- OK to address non-existent entries in TG_ARGV: just returns NULL
-- be careful editing this function: it is highly customized for ClassDB's needs
CREATE OR REPLACE FUNCTION ClassDB.rejectOperation()
RETURNS TRIGGER AS
$$
BEGIN
   IF TG_ARGV[0] = 'INSERT' THEN
      RAISE EXCEPTION
         'Constraint violation: value of column %.UserName is not a known user',
         TG_ARGV[1];
   ELSIF TG_ARGV[0] = 'UPDATE' THEN
      RAISE EXCEPTION
         'Invalid operation: UPDATE operation is not permitted on table "%"',
         TG_ARGV[1];
   ELSE
      RAISE EXCEPTION 'Invalid use of trigger function';
   END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;

ALTER FUNCTION ClassDB.rejectOperation() OWNER TO ClassDB;

REVOKE ALL ON FUNCTION ClassDB.rejectOperation() FROM PUBLIC;



--Define triggers to prevent INSERT for non-user roles, and any UPDATE, to
-- tables DDLActivity and ConnectionActivity
-- drop triggers prior to creation because there is no CREATE OR REPLACE TRIGGER
DO
$$
BEGIN

   --reject non-user inserts into DDLActivity
   DROP TRIGGER IF EXISTS RejectNonUserDDLActivityInsert ON ClassDB.DDLActivity;

   CREATE TRIGGER RejectNonUserDDLActivityInsert
   BEFORE INSERT ON ClassDB.DDLActivity
   FOR EACH ROW
   WHEN (NOT ClassDB.isUser(NEW.UserName))
   EXECUTE PROCEDURE ClassDB.rejectOperation('INSERT', 'ClassDB.DDLActivity');


   --reject non-user inserts into ConnectionActivity
   DROP TRIGGER IF EXISTS RejectNonUserConnectionActivityInsert
   ON ClassDB.ConnectionActivity;

   CREATE TRIGGER RejectNonUserConnectionActivityInsert
   BEFORE INSERT ON ClassDB.ConnectionActivity
   FOR EACH ROW
   WHEN (NOT ClassDB.isUser(NEW.UserName))
   EXECUTE PROCEDURE
      ClassDB.rejectOperation('INSERT', 'ClassDB.ConnectionActivity');


   --reject all updates to DDLActivity
   DROP TRIGGER IF EXISTS RejectDDLActivityUpdate ON ClassDB.DDLActivity;

   CREATE TRIGGER RejectDDLActivityUpdate
   BEFORE UPDATE ON ClassDB.DDLActivity
   EXECUTE PROCEDURE ClassDB.rejectOperation('UPDATE', 'ClassDB.DDLActivity');


   --reject all updates to ConnectionActivity
   DROP TRIGGER IF EXISTS RejectConnectionActivityUpdate
   ON ClassDB.ConnectionActivity;

   CREATE TRIGGER RejectConnectionActivityUpdate
   BEFORE UPDATE ON ClassDB.ConnectionActivity
   EXECUTE PROCEDURE
      ClassDB.rejectOperation('UPDATE', 'ClassDB.ConnectionActivity');

END
$$;



COMMIT;
