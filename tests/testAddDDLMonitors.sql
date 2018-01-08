--testAddUserMgmt.sql - ClassDB

--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab (DASSL)
--dassl.github.io

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.


--The following test script should be run as a superuser, otherwise tests will fail


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
--Create users to test DDL monitors


SET SESSION AUTHORIZATION ddlStudent;

CREATE TABLE MyTable
(
   MyAttr INT
);

DELETE TABLE MyTable;

RESET SESSION AUTHORIZATION;

IF SELECT COUNT(*) FROM ClassDB.DDLActivity <> 2 THEN
   RAISE EXCEPTION 'ERROR CODE 1';
END IF;



END;
$$ LANGUAGE plpgsql;
