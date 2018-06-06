--addRoleBaseMgmtCore.sql - ClassDB

--Sean Murthy
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
--  instead, uniqueness is enforced using an index on an expression
CREATE TABLE IF NOT EXISTS ClassDB.RoleBase
(
  RoleName ClassDB.IDNameDomain NOT NULL --server role name
   CHECK(TRIM(RoleName) <> '' AND NOT ClassDB.isClassDBRoleName(RoleName)),
  FullName VARCHAR NOT NULL CHECK(TRIM(FullName) <> ''), --role's given name
  IsTeam BOOLEAN NOT NULL DEFAULT FALSE, --is the role a team or a user?
  SchemaName ClassDB.IDNameDomain NOT NULL --name of the role-specific schema
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



--Define a function to retrieve the schema for a known role
-- returns NULL if the role is not known
CREATE OR REPLACE FUNCTION ClassDB.getSchemaName(roleName ClassDB.IDNameDomain)
   RETURNS ClassDB.IDNameDomain AS
$$
   SELECT SchemaName::ClassDB.IDNameDomain FROM ClassDB.RoleBase R
   WHERE R.RoleName = ClassDB.foldPgID($1);
$$ LANGUAGE sql
   STABLE
   RETURNS NULL ON NULL INPUT;

--Make ClassDB the fn. owner, let only instructors and managers execute the fn.
-- this pattern of ownership and grant/revoke applies to all functions in this
-- script: for brevity, such code is not prefaced ain with comments unless
-- the code does something significantly different
ALTER FUNCTION ClassDB.getSchemaName(ClassDB.IDNameDomain)
   OWNER TO ClassDB;

REVOKE ALL ON FUNCTION ClassDB.getSchemaName(ClassDB.IDNameDomain)
   FROM PUBLIC;

GRANT EXECUTE ON FUNCTION ClassDB.getSchemaName(ClassDB.IDNameDomain)
   TO ClassDB_Instructor, ClassDB_DBManager;



--Define a function to test if a role is "known"
-- a role is known if a row exists for the role name in table ClassDB.RoleBase
-- an "unknown role" could still be defined in the server
CREATE OR REPLACE FUNCTION ClassDB.isRoleKnown(roleName ClassDB.IDNameDomain)
   RETURNS BOOLEAN AS
$$
   SELECT EXISTS (SELECT * FROM ClassDB.RoleBase R
                  WHERE R.RoleName = ClassDB.foldPgID($1)
                 );
$$ LANGUAGE sql
   STABLE
   RETURNS NULL ON NULL INPUT;

ALTER FUNCTION ClassDB.isRoleKnown(ClassDB.IDNameDomain) OWNER TO ClassDB;

REVOKE ALL ON FUNCTION ClassDB.isRoleKnown(ClassDB.IDNameDomain)
   FROM PUBLIC;

GRANT EXECUTE ON FUNCTION ClassDB.isRoleKnown(ClassDB.IDNameDomain)
   TO ClassDB_Instructor, ClassDB_DBManager;



--Define a function to test if a known role is a "user"
-- a known role is a user if IsTeam is FALSE
CREATE OR REPLACE FUNCTION ClassDB.isUser(userName ClassDB.IDNameDomain)
   RETURNS BOOLEAN AS
$$
   SELECT EXISTS (SELECT * FROM ClassDB.RoleBase
                  WHERE RoleName = ClassDB.foldPgID($1) AND NOT IsTeam
                 );
$$ LANGUAGE sql
   STABLE
   RETURNS NULL ON NULL INPUT;

ALTER FUNCTION ClassDB.isUser(ClassDB.IDNameDomain) OWNER TO ClassDB;

REVOKE ALL ON FUNCTION ClassDB.isUser(ClassDB.IDNameDomain) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION ClassDB.isUser(ClassDB.IDNameDomain)
   TO ClassDB_Instructor, ClassDB_DBManager;



--Define a function to test if a known role is a "team"
-- a known role is a team if IsTeam is TRUE
CREATE OR REPLACE FUNCTION ClassDB.isTeam(teamName ClassDB.IDNameDomain)
   RETURNS BOOLEAN AS
$$
   SELECT EXISTS (SELECT * FROM ClassDB.RoleBase
                  WHERE RoleName = ClassDB.foldPgID($1) AND IsTeam
                 );
$$ LANGUAGE sql
   STABLE
   RETURNS NULL ON NULL INPUT;

ALTER FUNCTION ClassDB.isTeam(ClassDB.IDNameDomain) OWNER TO ClassDB;

REVOKE ALL ON FUNCTION ClassDB.isTeam(ClassDB.IDNameDomain)
   FROM PUBLIC;

GRANT EXECUTE ON FUNCTION ClassDB.isTeam(ClassDB.IDNameDomain)
   TO ClassDB_Instructor, ClassDB_DBManager;



--Define a function to record a server role, optionally creating the server role
-- create a server role using roleName
---- create a "user" (can login) if isTeam is false; else create a "role"
---- exception if role exists and okIfRoleExists is FALSE
-- create a role-specific schema and give the role all rights to that schema
---- exception if schema exists and okIfSchemaExists is FALSE
-- set roleName as initial password if pwd supplied is NULL
---- initial pwd is set only if role is created; it is set even for teams
-- add a record to ClassDB.RoleBase
---- update FullName and ExtraInfo if record already exists
CREATE OR REPLACE FUNCTION
   ClassDB.createRole(roleName ClassDB.IDNameDomain,
                      fullName ClassDB.RoleBase.FullName%Type,
                      isTeam ClassDB.RoleBase.IsTeam%Type,
                      schemaName ClassDB.IDNameDomain DEFAULT NULL,
                      extraInfo ClassDB.RoleBase.ExtraInfo%Type DEFAULT NULL,
                      okIfRoleExists BOOLEAN DEFAULT TRUE,
                      okIfSchemaExists BOOLEAN DEFAULT TRUE,
                      initialPwd VARCHAR(128) DEFAULT NULL)
   RETURNS VOID AS
$$
DECLARE
   isTeamStored BOOLEAN;
   schemaNameStored ClassDB.IDNameDomain;
   currentSchemaOwnerName ClassDB.IDNameDomain;
BEGIN

   --validate inputs:
   -- neither roleName nor fullName may be empty or NULL
   -- isTeam may not be NULL
   -- schemaName may not be empty
   -- stored and new values of isTeam and schemaName should match for known roles

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

   --if known role, get the stored and values for isTeam and schemaName
   -- the local variables will have NULL if role is not known
   SELECT R.IsTeam, R.SchemaName INTO isTeamStored, schemaNameStored
   FROM ClassDB.RoleBase R
   WHERE R.RoleName = ClassDB.foldPgID($1);

   --validate isTeam
   IF isTeamStored <> $3 THEN
      RAISE EXCEPTION
         'Invalid argument: role "%" is known to be a %; it cannot be changed to a %',
         $1,
         CASE WHEN isTeamStored THEN 'team' ELSE 'user' END,
         CASE WHEN $3 THEN 'team' ELSE 'user' END;
   END IF;

   --validate schema
   -- first get the intended name of role-specific schema: role name is the default
   $4 = COALESCE($4, $1);
   IF schemaNameStored <> ClassDB.foldPgID($4) THEN
      RAISE EXCEPTION
         'Invalid argument: role "%" is known to have schema "%"; '
         'it cannot be changed to "%"',
         $1, schemaNameStored, $4;
   END IF;


   -------- server role management --------------------------------------

   --create a server role if necessary
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
                     COALESCE($8, ClassDB.foldPgID($1))
                    );
   END IF;

   --give the server role LOGIN capability if it is a user
   --do not remove LOGIN for a team, because instructors may have their reasons
   -- to make a LOGIN server role a team
   IF NOT($3 OR ClassDB.canLogin($1)) THEN
      EXECUTE FORMAT('ALTER ROLE %s LOGIN', $1);
   END IF;


   -------- schema management --------------------------------------

   --give the executing user (should be 'classdb') same rights as role in question
   -- this grant is needed to make the role the owner of its own schema, as well
   -- as to reassign and drop objects later in function dropRole
   -- this grant is also required in case the role was created outside ClassDB
   IF NOT ClassDB.isMember(CURRENT_USER::ClassDB.IDNameDomain, $1) THEN
      EXECUTE FORMAT('GRANT %s TO CURRENT_USER', $1);
   END IF;

   --find the current owner of the schema, if the schema already exists
   -- value will be NULL if and only if the schema does not exist
   -- the return value will already be case-folded
   currentSchemaOwnerName = ClassDB.getSchemaOwnerName($4);

   --if schema does not exist, create it and give ownership to role in question
   --if schema exists, accept only if it is owned by role in question, and even
   -- then only if okIfSchemaExists is TRUE
   IF currentSchemaOwnerName IS NULL THEN
      EXECUTE FORMAT('CREATE SCHEMA %s AUTHORIZATION %s', $4, $1);
   ELSIF $7 THEN
      IF (currentSchemaOwnerName <> ClassDB.foldPgID($1)) THEN
         RAISE EXCEPTION
            'Schema "%" already exists, but is owned by (another) role "%"',
            $4, currentSchemaOwnerName;
      END IF;
   ELSE
      RAISE EXCEPTION 'Invalid argument: Schema "%" already exists', $4;
   END IF;


   -------- record management --------------------------------------

   --record the role
   -- if role is already known, set full name and extra info to new values
   -- cannot use ON CONFLICT because table has no PK or constraint
   --  seems the unique index can't be used despite the example in Postgres docs
   --  for ON CONFLICT ON CONSTRAINT: see the last-but-one example at
   --  https://www.postgresql.org/docs/9.6/static/sql-insert.html
   IF ClassDB.isRoleKnown($1) THEN
      UPDATE ClassDB.RoleBase R
      SET FullName = $2, ExtraInfo = $5
      WHERE R.RoleName = ClassDB.foldPgID($1);
   ELSE
      INSERT INTO ClassDB.RoleBase
      VALUES(ClassDB.foldPgID($1), $2, $3, ClassDB.foldPgID($4), $5);
   END IF;

END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;

ALTER FUNCTION
   ClassDB.createRole(ClassDB.IDNameDomain, ClassDB.RoleBase.FullName%Type,
                      ClassDB.RoleBase.IsTeam%Type, ClassDB.IDNameDomain,
                      ClassDB.RoleBase.ExtraInfo%Type,
                      BOOLEAN, BOOLEAN, VARCHAR(128)
                     )
   OWNER TO ClassDB;

REVOKE ALL ON FUNCTION
   ClassDB.createRole(ClassDB.IDNameDomain, ClassDB.RoleBase.FullName%Type,
                      ClassDB.RoleBase.IsTeam%Type, ClassDB.IDNameDomain,
                      ClassDB.RoleBase.ExtraInfo%Type,
                      BOOLEAN, BOOLEAN, VARCHAR(128)
                     )
   FROM PUBLIC;



--Define a function to revoke a ClassDB role from a known user
CREATE OR REPLACE FUNCTION
   ClassDB.revokeClassDBRole(userName ClassDB.IDNameDomain,
                             classdbRoleName ClassDB.IDNameDomain)
   RETURNS VOID AS
$$
BEGIN

   --revoke only a ClassDB role
   -- raise an exception (not a notice) because the role name must be correct
   IF NOT ClassDB.isClassDBRoleName($2) THEN
      RAISE EXCEPTION 'Invalid argument: role name "%" not expected', $2;
   END IF;

   --should be a server role
   IF NOT ClassDB.isServerRoleDefined($1) THEN
      RAISE NOTICE 'User "%" is not defined in the server', $1;
      RETURN;
   END IF;

   --should be a known user
   IF NOT ClassDB.isUser($1) THEN
      RAISE NOTICE 'User "%" is not known', $1;
      RETURN;
   END IF;

   --user should already have the role to revoke
   IF NOT ClassDB.isMember($1, $2) THEN
      RAISE NOTICE 'User "%" is not a member of role "%"', $1, $2;
      RETURN;
   END IF;

   --revoke the specified ClassDB role from the user
   EXECUTE FORMAT('REVOKE %s FROM %s', $2, $1);

   --inform if user continues to be a member of other ClassDB roles
   IF ClassDB.hasClassDBRole($1) THEN
      RAISE NOTICE
         'User "%" remains a member of one or more additional ClassDB roles', $1;
   END IF;

END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;

ALTER FUNCTION
   ClassDB.revokeClassDBRole(ClassDB.IDNameDomain, ClassDB.IDNameDomain)
   OWNER TO ClassDB;

REVOKE ALL ON FUNCTION
   ClassDB.revokeClassDBRole(ClassDB.IDNameDomain, ClassDB.IDNameDomain)
   FROM PUBLIC;



--Define a function to unrecord a role, and optionally from the server
-- the role to unrecord does not have to be a server role
-- if server role, can leave its objects as is, drop, or reassign to another role
-- parameter objectsDisposition decides the action taken. possible values are:
--  'as_is', 'drop', 'drop_c' (drop cascade), 'assign', 'assign_i', 'assign_m'
--  underscore (_) may be replaced with a dash (-)
--  the text/prefix 'assign' may be replaced with 'xfer'
-- 'as_is' or 'drop' cannot be used if dropFromServer is TRUE
-- parameter newObjectsOwnerName is used if objectsDisposition is 'assign'
CREATE OR REPLACE FUNCTION
   ClassDB.dropRole(roleName ClassDB.IDNameDomain,
                    dropFromServer BOOLEAN DEFAULT FALSE,
                    okIfClassDBRoleMember BOOLEAN DEFAULT TRUE,
                    objectsDisposition VARCHAR DEFAULT 'assign_i',
                    newObjectsOwnerName ClassDB.IDNameDomain DEFAULT NULL
                   )
   RETURNS VOID AS
$$
BEGIN

   --permit dropping only known roles
   IF NOT ClassDB.isRoleKnown($1) THEN
      RAISE EXCEPTION 'Role "%" is not known', $1;
   END IF;

   --if server role does not exist, just unrecord the role and exit
   IF NOT ClassDB.isServerRoleDefined($1) THEN
      DELETE FROM ClassDB.RoleBase R WHERE R.RoleName = ClassDB.foldPgID($1);
      RETURN;
   END IF;


   -- the rest of the code in this function applies only to server roles


   --test if role has a ClassDB role
   IF (ClassDB.hasClassDBRole($1) AND NOT $3) THEN
      RAISE EXCEPTION 'Role "%" is a member of one or more ClassDB roles', $1;
   END IF;

   --determine the disposition for objects the role owns
   -- the default disposition is to assign ownership to role ClassDB_Instructor
   -- trim spaces, replace dash (-) with an underscore (_) to ease later testing
   $4 = COALESCE(LOWER(REPLACE(TRIM($4), '-', '_')), 'assign_i');

   --objects cannot be left "as is" or just dropped if role is dropped from server
   -- only drop-cascade and assignment guarantee the role no longer owns any object
   IF ($2 AND $4 IN('as_is', 'drop')) THEN
      RAISE EXCEPTION
         'Invalid argument: disposition cannot be "%" if role dropped from server', $4;
   END IF;

   --enforce the disposition choice
   IF ($4 <> 'as_is') THEN

      --give the executing user (should be 'classdb') same rights as role to drop
      -- this grant is needed to reassign and drop objects
      -- this grant is also required in case the role was created outside ClassDB
      -- a similar grant is also required for the new object owner, and that is
      -- done later just before reassignment
      IF NOT ClassDB.isMember(CURRENT_USER::ClassDB.IDNameDomain, $1) THEN
         EXECUTE FORMAT('GRANT %s TO CURRENT_USER', $1);
      END IF;

      IF $4 IN ('drop', 'drop_c') THEN
         EXECUTE
            FORMAT( 'DROP OWNED BY %s %s',
                    $1,
                    CASE $4 WHEN 'drop' THEN 'RESTRICT' ELSE 'CASCADE' END
                  );
      ELSE
         --reassign ownership: determine the name of the new owner of objects
         $5 = CASE
               WHEN $4 IN ('assign', 'xfer') THEN TRIM($5)
               WHEN $4 IN ('assign_m', 'xfer_m') THEN 'classdb_dbmanager'
               ELSE 'classdb_instructor'
              END;

         --determine if the new owner's name is valid
         IF ($5 = '' OR $5 IS NULL) THEN
            RAISE EXCEPTION 'Invalid argument: new owner''s name is empty or NULL';
         END IF;

         --test if the new owner exists in the server
         IF NOT ClassDB.isServerRoleDefined($5) THEN
            RAISE EXCEPTION 'New owner role "%" is not defined', $5;
         END IF;

         IF NOT ClassDB.isMember(CURRENT_USER::ClassDB.IDNameDomain, $1) THEN
            EXECUTE FORMAT('GRANT %s TO CURRENT_USER', $1);
         END IF;

         --xfer ownership of objects owned by role in question to the new owner
         -- grant the executing user the same rights as new owner prior to xfer
         IF NOT ClassDB.isMember(CURRENT_USER::ClassDB.IDNameDomain, $5) THEN
            EXECUTE FORMAT('GRANT %s TO CURRENT_USER', $5);
         END IF;
         EXECUTE FORMAT('REASSIGN OWNED BY %s TO %s', $1, $5);
      END IF;

   END IF; --end of object disposition

   --drop the role from the server if asked to do so
   --before dropping, remove all privileges the role has
   -- the role may have access to objects it does not own and those accesses
   -- should be revoked before dropping the role
   -- see: https://www.postgresql.org/docs/9.6/static/role-removal.html
   IF $2 THEN
      EXECUTE FORMAT('DROP OWNED BY %s', $1);
      EXECUTE FORMAT('DROP ROLE %s', $1);
   END IF;

   --remove the role from the record
   DELETE FROM ClassDB.RoleBase R WHERE R.RoleName = ClassDB.foldPgID($1);

END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;

ALTER FUNCTION
   ClassDB.dropRole(ClassDB.IDNameDomain, BOOLEAN, BOOLEAN, VARCHAR,
                    ClassDB.IDNameDomain
                   )
   OWNER TO ClassDB;

REVOKE ALL ON FUNCTION
   ClassDB.dropRole(ClassDB.IDNameDomain, BOOLEAN, BOOLEAN, VARCHAR,
                    ClassDB.IDNameDomain
                   )
   FROM PUBLIC;



--Define a function to reset a role's password to a default value
-- default password is the role's name': it is not necessarily the same as the
--  initial password used at role creation
-- this function resets password for any server role; not just for known roles
-- this function is named "resetPassword" instead of "resetRolePassword" to make
--  it easier to use: experience shows instructors have to use this function many
--  times in a term
CREATE OR REPLACE FUNCTION ClassDB.resetPassword(roleName ClassDB.IDNameDomain)
   RETURNS VOID AS
$$
BEGIN
   IF ClassDB.isServerRoleDefined($1) THEN
      EXECUTE FORMAT('ALTER ROLE %s ENCRYPTED PASSWORD %L',
                     ClassDB.foldPgID($1), ClassDB.foldPgID($1)
                    );
   ELSE
      RAISE NOTICE 'Server role "%" is not defined', $1;
   END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;

ALTER FUNCTION ClassDB.resetPassword(ClassDB.IDNameDomain) OWNER TO ClassDB;

REVOKE ALL ON FUNCTION ClassDB.resetPassword(ClassDB.IDNameDomain)
   FROM PUBLIC;

GRANT EXECUTE ON FUNCTION ClassDB.resetPassword(ClassDB.IDNameDomain)
   TO ClassDB_Instructor, ClassDB_DBManager;


COMMIT;
