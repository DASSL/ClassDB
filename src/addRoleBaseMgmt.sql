--addRoleBaseMgmt.sql - ClassDB

--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab (DASSL)
--https://dassl.github.io/

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.

--This script requires the current user to be a superuser

--This script should be run after addHelpers.sql

--This script creates the basic tables and procedures to manage ClassDB users

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


--Define a table of users and teams recorded (made known) for this DB
-- each user/team has their own DBMS role
-- a "user" is a DBMS role who can log in and represents a human user
-- a "team" is a DBMS role who cannot login but represents a set of "users"
-- the table is named RoleBase because it is sort of "base class" for both
-- users and teams
-- No primary key is defined because uniqueness depends on case folding
--  thus, uniquess is enforced using an index on an expression
CREATE TABLE IF NOT EXISTS ClassDB.RoleBase
(
  RoleName VARCHAR(63) NOT NULL --server role name
   CHECK(TRIM(RoleName) <> '' AND NOT ClassDB.isClassDBRoleName(RoleName)),
  FullName VARCHAR NOT NULL CHECK(TRIM(FullName) <> ''), --role's given name
  IsTeam BOOLEAN NOT NULL DEFAULT FALSE, --is the role a team or a user?
  SchemaName VARCHAR(63) NOT NULL --name of role-specific schema
   CHECK(TRIM(SchemaName) <> ''),
  ExtraInfo VARCHAR --any additional information instructors wish to maintain
);

--Define a unique index on the folded version of role name
-- this approach to uniqueness makes RoleName compatible w/ Postgres role names
CREATE UNIQUE INDEX IF NOT EXISTS idx_Unique_FoldedRoleName
ON ClassDB.RoleBase(ClassDB.foldPgID(RoleName));

--Change table's owner so ClassDB can perform any operation on it
ALTER TABLE ClassDB.RoleBase OWNER TO ClassDB;

--Prevent everyone else from doing anything with the table
REVOKE ALL PRIVILEGES ON ClassDB.RoleBase FROM PUBLIC;

--Permit instructors and DB managers to read rows and to update only some columns
-- RoleName should not be edited because it must match a DBMS role
-- FullName and ExtraInfo are safe to edit after a record is created
-- inserts and deletes are performed only in functions which run as ClassDB
GRANT SELECT ON ClassDB.RoleBase
   TO ClassDB_Instructor, ClassDB_DBManager;

GRANT UPDATE (FullName, ExtraInfo) ON ClassDB.RoleBase
   TO ClassDB_Instructor, ClassDB_DBManager;


--Define a function to create a DBMS role
-- create a DBMS role using roleName
---- create a "user" (can login) if isTeam is false; else create a "role"
---- exception if role exists and okIfRoleExists is FALSE
-- create a role-specific schema and give the role all rights to that schema
---- exception if schema exists and okIfSchemaExists is FALSE
-- set roleName as initial password if pwd supplied is NULL
---- initial pwd is set only if role is created; it is set even for teams
-- add a record to ClassDB.RoleBase
---- update FullName and ExtraInfo if record already exists
CREATE OR REPLACE FUNCTION
   ClassDB.createRole(roleName ClassDB.RoleBase.RoleName%TYPE,
                      fullName ClassDB.RoleBase.FullName%Type,
                      isTeam ClassDB.RoleBase.IsTeam%Type,
                      schemaName ClassDB.RoleBase.SchemaName%Type DEFAULT NULL,
                      extraInfo ClassDB.RoleBase.ExtraInfo%Type DEFAULT NULL,
                      okIfRoleExists BOOLEAN DEFAULT TRUE,
                      okIfSchemaExists BOOLEAN DEFAULT TRUE,
                      initialPwd VARCHAR(128) DEFAULT NULL)
   RETURNS VOID AS
$$
DECLARE currentSchemaOwnerName ClassDB.RoleBase.RoleName%TYPE;
BEGIN

   --validate inputs:
   -- neither roleName nor fullName may be empty or NULL
   -- isTeam may not be NULL
   -- schemaName may not be empty

   $1 = TRIM($1);
   IF ($1 = '' OR $1 IS NULL) THEN
      RAISE EXCEPTION 'Invalid argument: roleName is NULL or empty';
   END IF;

   $2 = TRIM($2);
   IF ($2 = '' OR $2 IS NULL) THEN
      RAISE EXCEPTION 'Invalid argument: fullName is NULL or empty';
   END IF;

   IF ($3 IS NULL) THEN
      RAISE EXCEPTION 'Invalid argument: isTeam is NULL';
   END IF;

   $4 = TRIM($4);
   IF ($4 = '') THEN
      RAISE EXCEPTION 'Invalid argument: schemaName is empty';
   END IF;

   --create a server role
   IF ClassDB.isServerRoleDefined($1) THEN
      IF $6 THEN
         RAISE NOTICE 'Server role "%" already exists, password not modified', $1;
      ELSE
         RAISE EXCEPTION 'Invalid argument: server role "%" already exists', $1;
      END IF;
   ELSE
      --create a role (no login) or a user (role with login) based on isTeam
      EXECUTE FORMAT('CREATE %s %s ENCRYPTED PASSWORD %L',
                     CASE WHEN isTeam THEN 'ROLE' ELSE 'USER' END,
                     $1,
                     COALESCE($8, $1)
                    );
   END IF;

   IF NOT ClassDB.isMember(CURRENT_USER::VARCHAR, $1) THEN
      EXECUTE FORMAT('GRANT %s TO CURRENT_USER', $1);
   END IF;

   IF NOT ClassDB.isMember('classdb', $1) THEN
      EXECUTE FORMAT('GRANT %s TO classdb', $1);
   END IF;

   --get role-spefic schema's name: role name is the default schema name
   $4 = COALESCE($4, $1);

   --find the current owner of the schema, if the schema already exists
   -- NULL is stored in currentSchemaOwnerName if schema does not exist
   SELECT schema_owner INTO currentSchemaOwnerName
   FROM information_schema.schemata
   WHERE schema_name = ClassDB.foldPgID($4);

   --if schema does not exist, create it and give ownership to role in question
   --if schema exists, accept only if it is owned by role in question, and even
   -- then only if okIfSchemaExists is TRUE
   IF currentSchemaOwnerName IS NULL THEN
      EXECUTE FORMAT('CREATE SCHEMA %s AUTHORIZATION %s', $4, $1);
   ELSIF $7 THEN
      --if schema already exists, make sure its owner is the role in question
      IF (ClassDB.foldPgID(currentSchemaOwnerName) = ClassDB.foldPgID($1)) THEN
         RAISE NOTICE
            'Schema "%" already exists and is owned by role "%"', $4, $1;
      ELSE
         RAISE EXCEPTION
            'Schema "%" already exists and is owned by (another) role "%"',
            $4, currentSchemaOwnerName;
      END IF;
   ELSE
      RAISE EXCEPTION 'Invalid argument: Schema "%" already exists', $4;
   END IF;

   --record the role
   -- if role is already known, set full name and extra info to new values
   -- cannot change value of IsTeam and SchemaName for known roles
   -- cannot use ON CONFLICT because table has no PK or constraint
   --  seems the unique index can't be used despite the example in Postgres docs
   --  for ON CONFLICT ON CONSTRAINT: see the last-but-one example at
   --  https://www.postgresql.org/docs/9.6/static/sql-insert.html
   IF ClassDB.isRoleKnown($1) THEN
      UPDATE ClassDB.RoleBase SET FullName = $2, ExtraInfo = $5;
   ELSE
      INSERT INTO ClassDB.RoleBase
      VALUES(ClassDB.foldPgID($1), $2, $3, ClassDB.foldPgID($4), $5);
   END IF;

END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;


--Make ClassDB the function owner so function runs with that role's privileges
ALTER FUNCTION
   ClassDB.createRole(ClassDB.RoleBase.RoleName%TYPE,
                      ClassDB.RoleBase.FullName%Type,
                      ClassDB.RoleBase.IsTeam%Type,
                      ClassDB.RoleBase.SchemaName%Type,
                      ClassDB.RoleBase.ExtraInfo%Type,
                      BOOLEAN,
                      BOOLEAN,
                      VARCHAR(128))
   OWNER TO ClassDB;

--Prevent everyone else from executing the function
REVOKE ALL ON FUNCTION
   ClassDB.createRole(ClassDB.RoleBase.RoleName%TYPE,
                      ClassDB.RoleBase.FullName%Type,
                      ClassDB.RoleBase.IsTeam%Type,
                      ClassDB.RoleBase.SchemaName%Type,
                      ClassDB.RoleBase.ExtraInfo%Type,
                      BOOLEAN,
                      BOOLEAN,
                      VARCHAR(128))
   FROM PUBLIC;


--Define a function to test if a role is "known"
-- a role is known if a row exists for the role name in table ClassDB.RoleBase
-- an "unknown role" could still be defined in the server
CREATE OR REPLACE FUNCTION
   ClassDB.isRoleKnown(roleName ClassDB.RoleBase.RoleName%TYPE)
   RETURNS BOOLEAN AS
$$
   SELECT EXISTS (SELECT * FROM ClassDB.RoleBase
                  WHERE RoleName = ClassDB.foldPgID($1)
                 );
$$ LANGUAGE sql;

ALTER FUNCTION ClassDB.isRoleKnown(ClassDB.RoleBase.RoleName%TYPE)
   OWNER TO ClassDB;


--Define a function to test if a role is a "known user"
-- a role is a known user if role is known and IsTeam is FALSE
CREATE OR REPLACE FUNCTION
   ClassDB.isUserKnown(userName ClassDB.RoleBase.RoleName%TYPE)
   RETURNS BOOLEAN AS
$$
   SELECT EXISTS (SELECT * FROM ClassDB.RoleBase
                  WHERE RoleName = ClassDB.foldPgID($1) AND NOT IsTeam
                 );
$$ LANGUAGE sql;

ALTER FUNCTION ClassDB.isUserKnown(ClassDB.RoleBase.RoleName%TYPE)
   OWNER TO ClassDB;

GRANT EXECUTE ON FUNCTION ClassDB.isUserKnown(ClassDB.RoleBase.RoleName%TYPE)
   TO ClassDB_Instructor, ClassDB_DBManager;


--Define a function to test if a role is a "known team"
-- a role is known user if role is known and IsTeam is TRUE
CREATE OR REPLACE FUNCTION
   ClassDB.isTeamKnown(teamName ClassDB.RoleBase.RoleName%TYPE)
   RETURNS BOOLEAN AS
$$
   SELECT EXISTS (SELECT * FROM ClassDB.RoleBase
                  WHERE RoleName = ClassDB.foldPgID($1) AND IsTeam
                 );
$$ LANGUAGE sql;

ALTER FUNCTION ClassDB.isTeamKnown(ClassDB.RoleBase.RoleName%TYPE)
   OWNER TO ClassDB;

GRANT EXECUTE ON FUNCTION ClassDB.isTeamKnown(ClassDB.RoleBase.RoleName%TYPE)
   TO ClassDB_Instructor, ClassDB_DBManager;


--Define a function to revoke a ClassDB role from a known user
CREATE OR REPLACE FUNCTION
   ClassDB.revokeClassDBRole(userName ClassDB.RoleBase.RoleName%TYPE,
                             classdbRoleName VARCHAR(63))
   RETURNS VOID AS
$$
BEGIN

   --test if a ClassDB role is supplied
   -- raise an exception (not a notice) because the role name must be correct
   IF NOT ClassDB.isClassDBRoleName($2) THEN
      RAISE EXCEPTION 'Invalid argument: role name "%" not expected', $2;
      RETURN;
   END IF;

   --test if server has a role with the given name
   IF NOT ClassDB.isServerRoleDefined($1) THEN
      RAISE NOTICE 'User "%" is not defined in the server', $1;
      RETURN;
   END IF;

   --test if user is known
   IF NOT ClassDB.isUserKnown($1) THEN
      RAISE NOTICE 'User "%" is not known', $1;
      RETURN;
   END IF;

   --test if user is a member of the specified role
   IF NOT ClassDB.isMember($1, $2) THEN
      RAISE NOTICE 'User "%" is not a member of role "%"', $1, $2;
      RETURN;
   END IF;

   --revoke the specified ClassDB role from the user
   EXECUTE FORMAT('REVOKE %s FROM %s', $2, $1);

   --test if user continues to be a member of other ClassDB roles
   -- only for informational purpose
   IF ClassDB.hasClassDBRole($1, $2) THEN
      RAISE NOTICE
         'User "%" remains a member of one or more additional ClassDB roles', $1;
   END IF;

END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;

--Change function ownership and set execution permissions
ALTER FUNCTION
   ClassDB.revokeClassDBRole(ClassDB.RoleBase.RoleName%TYPE, VARCHAR(63))
   OWNER TO ClassDB;

REVOKE ALL ON FUNCTION
   ClassDB.revokeClassDBRole(ClassDB.RoleBase.RoleName%TYPE, VARCHAR(63))
   FROM PUBLIC;



--The folowing procedure revokes the Instructor role from an Instructor, along
-- with their entry in the ClassDB.Instructor table. If the Instructor role was
-- the only role that the instructor was a member of, the instructor's schema,
-- and the objects contained within, are removed along with the the role
-- representing the instructor.
CREATE OR REPLACE FUNCTION
   ClassDB.dropRole(roleName ClassDB.RoleBase.RoleName%TYPE,
                    okIfClassDBRoleMember BOOLEAN DEFAULT FALSE,
                    objectsDisposition VARCHAR DEFAULT 'assign_i',
                    newObjectsOwnerName VARCHAR(63) DEFAULT NULL
                   )
   RETURNS VOID AS
$$
BEGIN

   --test if role exists in the server
   IF NOT ClassDB.isServerRoleDefined($1) THEN
      RAISE NOTICE 'Role "%" is not defined', $1;
      RETURN;
   END IF;

   --test if role is known
   -- raise exception because dropping a role can have a lot of adverse effect
   -- limiting drops only to known roles reduces the chance of inadvertent drops
   IF NOT ClassDB.isRoleKnown($1) THEN
      RAISE EXCEPTION 'Role "%" is not known', $1;
   END IF;

   IF ClassDB.hasClassDBRole($1) THEN
      IF $2 THEN
         RAISE NOTICE 'Role "%" is a member of one or more ClassDB roles', $1;
      ELSE
         RAISE EXCEPTION 'Role "%" is a member of one or more ClassDB roles', $1;
      END IF;
   END IF;

   --determine the disposition for objects the role owns and carry out the choice
   -- the default disposition is to assign ownership to role ClassDB_Instructor
   $3 = COALESCE(LOWER($3), 'assign_i');

   IF ($3 = 'drop' OR $3 = 'drop_c') THEN
      EXECUTE
         FORMAT( 'DROP OWNED BY %s %s',
                 $1,
                 CASE $3 WHEN 'drop_c' THEN 'CASCADE' ELSE 'RESTRICT' END
               );
   ELSE
      $4 =  CASE LOWER($3)
               WHEN 'assign_i' THEN 'classdb_instructor'
               WHEN 'assign_m' THEN 'classdb_dbmanager'
               ELSE TRIM($4)
            END;

      --determine if new owner is valid
      IF ($4 = '' OR $4 IS NULL) THEN
         RAISE EXCEPTION 'Invalid argument: new owner''s name is empty or NULL';
      END IF;

      --test if new owner exists in the server
      IF NOT ClassDB.isServerRoleDefined($4) THEN
         RAISE EXCEPTION 'New owner role "%" is not defined', $4;
      END IF;

      --xfer ownership of objects owned by the role in question to the new owner
      EXECUTE FORMAT('REASSIGN OWNED BY %s TO %s', $1, $4);

      --remove all privileges associated with the role to be dropped
      -- the role may have access to objects it does not own and those accesses
      -- should be revoked before dropping the role
      -- see: https://www.postgresql.org/docs/9.6/static/role-removal.html
      EXECUTE FORMAT( 'DROP OWNED BY %s', $1);
   END IF;

   --drop the role and remove it from the record
   EXECUTE FORMAT('DROP ROLE %s', $1);
   DELETE FROM ClassDB.RoleBase R WHERE R.RoleName = ClassDB.foldPgID($1);

   RAISE NOTICE 'Role "%" is dropped', $1;

END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;

--Change function ownership and set execution permissions
ALTER FUNCTION
   ClassDB.dropRole(ClassDB.RoleBase.RoleName%TYPE,BOOLEAN,VARCHAR,VARCHAR(63))
OWNER TO ClassDB;

REVOKE ALL ON FUNCTION
   ClassDB.dropRole(ClassDB.RoleBase.RoleName%TYPE,BOOLEAN,VARCHAR,VARCHAR(63))
   FROM PUBLIC;


--Define a function to reset a role's password to a default value
-- default password is the role's name': it is not necessarily the same as the
--  initial password used at role creation
-- this function resets password for any server role; not just for known roles
-- this function is named "resetPassword" instead of "resetRolePassword" to make
--  it easier to use: experience shows instructors have to use this function many
--  times in a term
CREATE OR REPLACE FUNCTION
   ClassDB.resetPassword(roleName ClassDB.RoleBase.RoleName%TYPE)
   RETURNS VOID AS
$$
BEGIN
   IF ClassDB.isServerRoleDefined($1) THEN
      EXECUTE FORMAT('ALTER ROLE %s ENCRYPTED PASSWORD %L', $1, $1);
   ELSE
      RAISE NOTICE 'Server role "%" is not defined', $1;
   END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;

--Change function ownership and set execution permissions
ALTER FUNCTION ClassDB.resetPassword(ClassDB.RoleBase.RoleName%TYPE)
   OWNER TO ClassDB;

REVOKE ALL ON FUNCTION ClassDB.resetPassword(ClassDB.RoleBase.RoleName%TYPE)
   FROM PUBLIC;

GRANT EXECUTE ON FUNCTION
   ClassDB.resetPassword(ClassDB.RoleBase.RoleName%TYPE)
   TO ClassDB_Instructor, ClassDB_DBManager;



COMMIT;
