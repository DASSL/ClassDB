--addServerVersionComparersCore.sql - ClassDB

--Sean Murthy
--Data Science & Systems Lab (DASSL)
--https://dassl.github.io/

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.


--This script requires the current user to be a superuser

--This script should be run in every database to which ClassDB is to be added
-- it should be run after running addHelpersCore.sql

--This script creates functions to get and compare server version number(s)


START TRANSACTION;

--Make sure the current user has sufficient privilege to run this script
-- privilege required: superuser
DO
$$
BEGIN
   IF NOT ClassDB.isSuperUser() THEN
      RAISE EXCEPTION 'Insufficient privilege: script must be run as a superuser';
   END IF;
END
$$;


--Define a function to convert an integer pg server version number to string
--https://www.postgresql.org/docs/10/static/libpq-status.html#LIBPQ-PQSERVERVERSION
CREATE OR REPLACE FUNCTION ClassDB.intServerVersionToString(v INT)
RETURNS VARCHAR AS
$$
BEGIN
   IF v >= 100000 THEN
      --pg10 or later has 2-part numbers such as 10.1 and 11.0, which are encoded
      -- as numbers with 6 or more digits such as 100001 and 110000
      RETURN CONCAT((v/10000)::VARCHAR, '.', (v%10000)::VARCHAR);
   ELSE
      --pre-pg10 versions are 3-part numbers which are encoded as 5-digit numbers
      -- with two digits used (0 filled) for each part
      -- e.g., 9.1.5 and 9.2.0 are encoded as 90105 and 90200 respectively
      RETURN CONCAT((v/10000)::VARCHAR, '.', (v%10000/100)::VARCHAR, '.',
                    (v%100)::VARCHAR
                   );
   END IF;
END;
$$ LANGUAGE plpgsql
   IMMUTABLE
   RETURNS NULL ON NULL INPUT;

ALTER FUNCTION ClassDB.intServerVersionToString(INT) OWNER TO ClassDB;



--Define a function to get the server's version number
--Retrieve a "machine-readable server version" which is an integer and convert
-- it to a human-friendly version-number string
-- the machine-readable number does not contain any distro-specific information
-- https://www.postgresql.org/docs/10/static/functions-info.html and
CREATE OR REPLACE FUNCTION ClassDB.getServerVersion() RETURNS VARCHAR AS
$$
DECLARE v INT;
BEGIN
   --get server version as a number and convert it to string
   v = ClassDB.getServerSetting('server_version_num')::INT;
   RETURN ClassDB.intServerVersionToString(v);
END;
$$ LANGUAGE plpgsql
   IMMUTABLE --server version cannot change unless the server is restarted
   RETURNS NULL ON NULL INPUT;

ALTER FUNCTION ClassDB.getServerVersion() OWNER TO ClassDB;


--The functions that follow compare a server version to another
-- the functions generally take one or more parameters which need to conform to
-- Postgres verion number format: https://www.postgresql.org/support/versioning.
--Execution is limited to the ClassDB role to prevent exceptions due to
-- non-conforming params: too much dev effort to prevent all possible exceptions


--Define a function to compare any two Postgres server version numbers
--Optionally ignores the second part in a version number, e.g.: '6' in '9.6'
--Always ignores third part of a version number, e.g., ignores the 3 in "9.6.3"
--Return value:
-- simply returns the integer difference between corresponding parts of version#
-- negative number if version1 precedes version2
-- positive number if version1 succeeds version2
-- zero if the two versions are the same
CREATE OR REPLACE FUNCTION
   ClassDB.compareServerVersion(version1 VARCHAR, version2 VARCHAR,
                                testPart2 BOOLEAN DEFAULT TRUE
                               )
   RETURNS INTEGER AS
$$
DECLARE
   verson1Parts VARCHAR ARRAY;
   verson2Parts VARCHAR ARRAY;
   major1 INTEGER;
   major2 INTEGER;
BEGIN

   $1 = TRIM($1);
   IF ($1 = '') THEN
      RAISE EXCEPTION 'invalid argument: version1 is empty';
   END IF;

   $2 = TRIM($2);
   IF ($2 = '') THEN
      RAISE EXCEPTION 'invalid argument: version2 is empty';
   END IF;

   --adjust version numbers to always have two parts so later code is easier
   -- e.g., change '10' to '10.0'
   IF (POSITION('.' IN $1) = 0) THEN
      $1 = $1 || '.0';
   END IF;

   IF (POSITION('.' IN $2) = 0) THEN
      $2 = $2 || '.0';
   END IF;

   --convert each version number to an array for ease of comparison
   verson1Parts = string_to_array($1, '.');
   verson2Parts = string_to_array($2, '.');

   --cast the major version number (e.g., '9' in '9.6') to a number
   -- causes exception if input is not really numeric
   major1 = TRIM(verson1Parts[1])::INTEGER;
   major2 = TRIM(verson2Parts[1])::INTEGER;

   IF (major1 <> major2) THEN
      RETURN major1 - major2;
   ELSIF $3 THEN
      RETURN TRIM(verson1Parts[2])::INTEGER - TRIM(verson2Parts[2])::INTEGER;
   ELSE
      RETURN 0;
   END IF;

END;
$$ LANGUAGE plpgsql
   IMMUTABLE
   RETURNS NULL ON NULL INPUT;

ALTER FUNCTION
   ClassDB.compareServerVersion(VARCHAR, VARCHAR, BOOLEAN) OWNER TO ClassDB;

REVOKE ALL ON FUNCTION
   ClassDB.compareServerVersion(VARCHAR, VARCHAR, BOOLEAN) FROM PUBLIC;


--Define a function to compare some Postgres server version number to this server's
--See version of this fn that compares any two server version numbers for details
CREATE OR REPLACE FUNCTION
   ClassDB.compareServerVersion(version1 VARCHAR,
                                testPart2 BOOLEAN DEFAULT TRUE
                               )
   RETURNS INTEGER AS
$$
   SELECT ClassDB.compareServerVersion($1, ClassDB.getServerVersion(), $2);
$$ LANGUAGE sql
   IMMUTABLE
   RETURNS NULL ON NULL INPUT;

ALTER FUNCTION ClassDB.compareServerVersion(VARCHAR, BOOLEAN) OWNER TO ClassDB;

REVOKE ALL ON FUNCTION
   ClassDB.compareServerVersion(VARCHAR, BOOLEAN) FROM PUBLIC;



--Define a shortcut fn to test if the server's version precedes the given version
CREATE OR REPLACE FUNCTION
   ClassDB.isServerVersionBefore(version VARCHAR, testPart2 BOOLEAN DEFAULT TRUE)
   RETURNS BOOLEAN AS
$$
   SELECT ClassDB.compareServerVersion($1, $2) > 0;
$$ LANGUAGE sql
   IMMUTABLE
   RETURNS NULL ON NULL INPUT;

ALTER FUNCTION ClassDB.isServerVersionBefore(VARCHAR, BOOLEAN) OWNER TO ClassDB;

REVOKE ALL ON FUNCTION
   ClassDB.isServerVersionBefore(VARCHAR, BOOLEAN) FROM PUBLIC;



--Define a shortcut fn to test if the server's version succeeds the given version
CREATE OR REPLACE FUNCTION
   ClassDB.isServerVersionAfter(version VARCHAR, testPart2 BOOLEAN DEFAULT TRUE)
   RETURNS BOOLEAN AS
$$
   SELECT ClassDB.compareServerVersion($1, $2) < 0;
$$ LANGUAGE sql
   IMMUTABLE
   RETURNS NULL ON NULL INPUT;

ALTER FUNCTION ClassDB.isServerVersionAfter(VARCHAR, BOOLEAN) OWNER TO ClassDB;

REVOKE ALL ON FUNCTION
   ClassDB.isServerVersionAfter(VARCHAR, BOOLEAN) FROM PUBLIC;



--Define a shortcut fn to test if the server's version matches the given version
CREATE OR REPLACE FUNCTION
   ClassDB.isServerVersion(version VARCHAR, testPart2 BOOLEAN DEFAULT TRUE)
   RETURNS BOOLEAN AS
$$
   SELECT ClassDB.compareServerVersion($1, $2) = 0;
$$ LANGUAGE sql
   IMMUTABLE
   RETURNS NULL ON NULL INPUT;

ALTER FUNCTION ClassDB.isServerVersion(VARCHAR, BOOLEAN) OWNER TO ClassDB;

REVOKE ALL ON FUNCTION
   ClassDB.isServerVersion(VARCHAR, BOOLEAN) FROM PUBLIC;



COMMIT;
