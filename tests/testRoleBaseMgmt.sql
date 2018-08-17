--testRoleBaseMgmt.sql - ClassDB

--Sean Murthy
--Data Science & Systems Lab (DASSL)
--https://dassl.github.io/

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.


--This script should be run as a superuser

--This script tests the functionality in addRoleBaseMgmtCore.sql
-- only nominal tests are covered presently
-- need to plan a test for cases that should cause exceptions


START TRANSACTION;

--Tests for superuser privilege on current_user
DO
$$
BEGIN
   IF NOT ClassDB.isSuperUser() THEN
      RAISE EXCEPTION 'Insufficient privileges: script must be run as a superuser';
   END IF;
END
$$;


DO
$$
BEGIN

   --test creation of a user with the default schema name

   --u1 is not a known role
   RAISE INFO '%   isRoleKnown(u1: before createRole)',
   CASE ClassDB.isRoleKnown('u1') WHEN TRUE THEN 'FAIL: Code 1' ELSE 'PASS' END;

   --add a new user u1 with default schema name
   PERFORM ClassDB.createRole('u1', 'u1 name', FALSE);

   --test u1's row directly in the table
   RAISE INFO '%   createRole(u1, u1 name, FALSE)',
   CASE EXISTS(SELECT * FROM ClassDB.RoleBase
               WHERE RoleName = 'u1' AND FullName = 'u1 name'
               AND NOT IsTeam AND SchemaName = RoleName AND ExtraInfo IS NULL
              )
      WHEN TRUE THEN 'PASS'
      ELSE 'FAIL: Code 2'
   END;

   --test schema name via getSchemaName
   RAISE INFO '%   getSchemaName(u1)',
   CASE (SELECT SchemaName FROM ClassDB.RoleBase WHERE RoleName = 'u1')
      WHEN ClassDB.getSchemaName('u1') THEN 'PASS'
      ELSE 'FAIL: Code 3'
   END;

   --u1 is a known role
   RAISE INFO '%   isRoleKnown(u1: after createRole)',
   CASE ClassDB.isRoleKnown('u1') WHEN TRUE THEN 'PASS' ELSE 'FAIL: Code 4' END;

   --u1 is a known user
   RAISE INFO '%   isUser(u1)',
   CASE ClassDB.isUser('u1') WHEN TRUE THEN 'PASS' ELSE 'FAIL: Code 5' END;

   --u1 is not a known team
   RAISE INFO '%   isTeam(u1)',
   CASE ClassDB.isTeam('u1') WHEN TRUE THEN 'FAIL: Code 6' ELSE 'PASS' END;

   --change u1's full name and extraInfo via u1
   PERFORM ClassDB.createRole('u1', 'u1 modified name', FALSE, NULL, '5287');

   --test u1's row directly in the table
   RAISE INFO '%   createRole(u1, u1 modified name, FALSE)',
   CASE EXISTS(SELECT * FROM ClassDB.RoleBase
               WHERE RoleName = 'u1' AND FullName = 'u1 modified name'
               AND NOT IsTeam AND SchemaName = RoleName AND ExtraInfo = '5287'
              )
      WHEN TRUE THEN 'PASS'
      ELSE 'FAIL: Code 7'
   END;

--------------------------------------------------------------------------------

   --test creation of a team with a custom schema name

   --t1 is not a known role
   RAISE INFO '%   isRoleKnown(t1: before createRole)',
   CASE ClassDB.isRoleKnown('t1') WHEN TRUE THEN 'FAIL: Code 8' ELSE 'PASS' END;

   --add a new team t1 with a custom schema name
   --use 'T1' for team name, but that should be stored as 't1'
   PERFORM ClassDB.createRole('T1', 't1 name', TRUE, 't1_schema');

   --test t1's row directly in the table
   --lookup role using 't1' because that is what should be stored
   RAISE INFO '%   createRole(T1, t1 name, TRUE, t1_schema)',
   CASE EXISTS(SELECT * FROM ClassDB.RoleBase
               WHERE RoleName = 't1' AND FullName = 't1 name' AND IsTeam
               AND SchemaName = 't1_schema' AND ExtraInfo IS NULL
              )
      WHEN TRUE THEN 'PASS'
      ELSE 'FAIL: Code 9'
   END;

   --test schema name via getSchemaName
   RAISE INFO '%   getSchemaName(t1)',
   CASE (SELECT SchemaName FROM ClassDB.RoleBase WHERE RoleName = 't1')
      WHEN ClassDB.getSchemaName('t1') THEN 'PASS'
      ELSE 'FAIL: Code 10'
   END;

   --t1 is not a known user
   RAISE INFO '%   isUser(t1)',
   CASE ClassDB.isUser('t1') WHEN TRUE THEN 'FAIL: Code 11' ELSE 'PASS' END;

   --t1 is a known team
   RAISE INFO '%   isTeam(t1)',
   CASE ClassDB.isTeam('t1') WHEN TRUE THEN 'PASS' ELSE 'FAIL: Code 12' END;

--------------------------------------------------------------------------------

   --test creating a user for a NOLOGIN server role that already exists

   --s1 is not a server role
   RAISE INFO '%   isServerRoleDefined(s1: before CREATE USER)',
   CASE ClassDB.isServerRoleDefined('s1') WHEN TRUE THEN 'FAIL: Code 13' ELSE 'PASS' END;

   --create a server role with NOLOGIN directly, create a schema for the new role
   CREATE ROLE s1 NOLOGIN;
   PERFORM ClassDB.grantRole('s1');
   CREATE SCHEMA s1 AUTHORIZATION s1;

   --s1 has no LOGIN (should get LOGIN after createRole)
   RAISE INFO '%   canLogin(s1: before createRole)',
   CASE ClassDB.canLogin('s1') WHEN TRUE THEN 'FAIL: Code 14' ELSE 'PASS' END;

   --s1 is not a known role
   RAISE INFO '%   isRoleKnown(s1: before createRole)',
   CASE ClassDB.isRoleKnown('s1') WHEN TRUE THEN 'FAIL: Code 15' ELSE 'PASS' END;

   --create user s1
   PERFORM ClassDB.createRole('s1', 's1 name', FALSE);

   --test s1's row directly in the table
   RAISE INFO '%   createRole(s1, s1 name, FALSE)',
   CASE EXISTS(SELECT * FROM ClassDB.RoleBase
               WHERE RoleName = 's1' AND FullName = 's1 name'
               AND NOT IsTeam AND SchemaName = RoleName AND ExtraInfo IS NULL
              )
      WHEN TRUE THEN 'PASS'
      ELSE 'FAIL: Code 16'
   END;

   --s1 is now a known role
   RAISE INFO '%   isRoleKnown(s1)',
   CASE ClassDB.isRoleKnown('s1') WHEN TRUE THEN 'PASS' ELSE 'FAIL: Code 17' END;

   --s1 is now a known user
   RAISE INFO '%   isUser(s1)',
   CASE ClassDB.isUser('s1') WHEN TRUE THEN 'PASS' ELSE 'FAIL: Code 18' END;

   --s1 now has LOGIN
   RAISE INFO '%   canLogin(s1: after createRole)',
   CASE ClassDB.canLogin('s1') WHEN TRUE THEN 'PASS' ELSE 'FAIL: Code 19' END;

--------------------------------------------------------------------------------

   --test role revocation

   --u1 does not have a ClassDB role
   RAISE INFO '%   hasClassDBRole(u1: before GRANT)',
   CASE ClassDB.hasClassDBRole('u1') WHEN TRUE THEN 'FAIL: Code 20' ELSE 'PASS' END;

   --grant u1 the ClassDB_Student role
   GRANT ClassDB_Student TO u1;

   --u1 now has a ClassDB role
   RAISE INFO '%   hasClassDBRole(u1: before revokeClassDBRole)',
   CASE ClassDB.hasClassDBRole('u1') WHEN TRUE THEN 'PASS' ELSE 'FAIL: Code 21' END;

   --revoke role
   PERFORM ClassDB.revokeClassDBRole('u1', 'classdb_student');

   --u1 no longer has a ClassDB role
   RAISE INFO '%   hasClassDBRole(u1: after revokeClassDBRole)',
   CASE ClassDB.hasClassDBRole('u1') WHEN TRUE THEN 'FAIL: Code 22' ELSE 'PASS' END;

   --u1 is still a known role
   RAISE INFO '%   isRoleKnown(u1: after revokeClassDBRole)',
   CASE ClassDB.isRoleKnown('u1') WHEN TRUE THEN 'PASS' ELSE 'FAIL: Code 23' END;

--------------------------------------------------------------------------------

   --test dropping a role without dropping it from the server
   --also test object assignment to another user when ClassDB does not have the
   --same rights as both the role to be dropped and the new object owner

   --revoke u1 and s1 roles from ClassDB: dropRole should re-grant the roles
   REVOKE u1, s1 FROM ClassDB;

   --ClassDB does not have either role
   RAISE INFO '%   isMember(ClassDB, u1: before dropRole)',
   CASE ClassDB.isMember('classdb', 'u1') WHEN TRUE THEN 'FAIL: Code 24' ELSE 'PASS' END;

   RAISE INFO '%   isMember(ClassDB, s1: before dropRole)',
   CASE ClassDB.isMember('classdb', 's1') WHEN TRUE THEN 'FAIL: Code 25' ELSE 'PASS' END;

   --u1 is a known role
   RAISE INFO '%   isRoleKnown(u1: before dropRole)',
   CASE ClassDB.isRoleKnown('u1') WHEN TRUE THEN 'PASS' ELSE 'FAIL: Code 26' END;

   --drop u1 from record, but let it remain a server role; assign objects to s1
   PERFORM ClassDB.dropRole('u1', FALSE, FALSE, 'assign', 's1');

   --u1 is no longer a known role
   RAISE INFO '%   isRoleKnown(u1: after dropRole)',
   CASE ClassDB.isRoleKnown('u1') WHEN TRUE THEN 'FAIL: Code 27' ELSE 'PASS' END;

   --u1 is still a server role
   RAISE INFO '%   isServerRoleDefined(u1: after dropRole)',
   CASE ClassDB.isServerRoleDefined('u1') WHEN TRUE THEN 'PASS' ELSE 'FAIL: Code 28' END;

   --ClassDB should now have both u1 and s1 roles
   RAISE INFO '%   isMember(ClassDB, u1: after dropRole)',
   CASE ClassDB.isMember('classdb', 'u1') WHEN TRUE THEN 'PASS' ELSE 'FAIL: Code 29' END;

   RAISE INFO '%   isMember(ClassDB, s1: after dropRole)',
   CASE ClassDB.isMember('classdb', 's1') WHEN TRUE THEN 'PASS' ELSE 'FAIL: Code 30' END;

   --u1's schema exists but is now owned by s1
   RAISE INFO '%   dropRole(u1, FALSE, FALSE, assign, s1)',
   CASE EXISTS(SELECT * FROM information_schema.schemata
               WHERE schema_name = 'u1' AND schema_owner = 's1'
              )
      WHEN TRUE THEN 'PASS'
      ELSE 'FAIL: Code 31'
   END;

--------------------------------------------------------------------------------

   --test dropping a role while also dropping it from the server
   --also test object assignment to current user
   --give role u1 execution permission on dropRole and execute dropRole as u1
   -- cannot call dropRole as a superuser or any classdb group role

   --t1 is a known role
   RAISE INFO '%   isRoleKnown(t1: before dropRole)',
   CASE ClassDB.isRoleKnown('t1') WHEN TRUE THEN 'PASS' ELSE 'FAIL: Code 32' END;

   --let u1 execute function dropRole
   GRANT USAGE ON SCHEMA ClassDB TO u1;
   GRANT EXECUTE ON FUNCTION
      ClassDB.dropRole(ClassDB.IDNameDomain, BOOLEAN, BOOLEAN, VARCHAR,
                       ClassDB.IDNameDomain
                      )
   TO u1;

   --become u1
   SET SESSION AUTHORIZATION u1;

   --drop t1 from record and from the server; assign objects to current user (u1)
   PERFORM ClassDB.dropRole('t1', TRUE);

   --go back to being the orginal users
   RESET SESSION AUTHORIZATION;

   --u1 no longer needs access to function dropRole
   REVOKE USAGE ON SCHEMA ClassDB FROM u1;
   REVOKE EXECUTE ON FUNCTION
      ClassDB.dropRole(ClassDB.IDNameDomain, BOOLEAN, BOOLEAN, VARCHAR,
                       ClassDB.IDNameDomain
                      )
   FROM u1;

   --t1 is no longer a known role
   RAISE INFO '%   isRoleKnown(t1: after dropRole)',
   CASE ClassDB.isRoleKnown('t1') WHEN TRUE THEN 'FAIL: Code 33' ELSE 'PASS' END;

   --t1 is no longer a server role
   RAISE INFO '%   isServerRoleDefined(t1: after dropRole)',
   CASE ClassDB.isServerRoleDefined('t1') WHEN TRUE THEN 'FAIL: Code 34' ELSE 'PASS' END;

   --t1's schema exists but is owned by role 'u1' (t1's objects assigned to u1)
   RAISE INFO '%   dropRole(t1, TRUE)',
   CASE EXISTS(SELECT * FROM information_schema.schemata
               WHERE schema_name = 't1_schema' AND schema_owner = 'u1'
              )
      WHEN TRUE THEN 'PASS'
      ELSE 'FAIL: Code 35'
   END;



--------------------------------------------------------------------------------

   --test dropping a role while also dropping it from the server
   --also recursively drop all objects the role owns

   --s1 is a known role
   RAISE INFO '%   isRoleKnown(s1: before dropRole)',
   CASE ClassDB.isRoleKnown('s1') WHEN TRUE THEN 'PASS' ELSE 'FAIL: Code 36' END;

   --drop s1 from record and the server, and drop all objects it owns
   PERFORM ClassDB.dropRole('s1', TRUE, FALSE, 'drop_c');

   --s1 is no longer a known role
   RAISE INFO '%   isRoleKnown(s1: after dropRole)',
   CASE ClassDB.isRoleKnown('s1') WHEN TRUE THEN 'FAIL: Code 37' ELSE 'PASS' END;

   --s1 is no longer a server role
   RAISE INFO '%   isServerRoleDefined(s1: after dropRole)',
   CASE ClassDB.isServerRoleDefined('s1') WHEN TRUE THEN 'FAIL: Code 38' ELSE 'PASS' END;

   --s1's schema does not exist
   RAISE INFO '%   dropRole(s1, TRUE, FALSE, drop_c)',
   CASE EXISTS(SELECT * FROM information_schema.schemata
               WHERE schema_owner = 's1'
              )
      WHEN TRUE THEN 'FAIL: Code 39'
      ELSE 'PASS'
   END;

--------------------------------------------------------------------------------

END
$$;


ROLLBACK;
