--assertAlterSystemAvailability.sql - ClassDB

--Andrew Figueroa
--Data Science & Systems Lab (DASSL)
--https://dassl.github.io/

--(C) 2018- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.

--This script does not need to be run individually for an installation of
-- ClassDB and does not modify the server or any database. It is called by
-- other installation scripts when it is needed

--This script asserts that the ALTER SYSTEM command is available for use by
-- verifying that the current server version is not <9.4

--Any configuration options that are set by ALTER SYSTEM must be set manually in
-- postgresql.conf in pg9.3 or below. This script and any invocations of this
-- script should be removed when support for pg9.3 is dropped.

DO
$$
BEGIN
   --Since this is a server script, ClassDB's server version comparers are not
   --available. The following conditional reproduces the effect of calling
   -- ClassDB.isServerVersionBefore('9.4')
   IF 90400 > (SELECT setting::integer FROM pg_catalog.pg_settings
               WHERE name = 'server_version_num')
   THEN
      RAISE EXCEPTION USING
         MESSAGE = 'could not set logging-related settings',
         DETAIL = 'Logging-related settings must be set manually in Postgres'
                  ' 9.3 and earlier.',
         HINT = 'Consult ClassDB documentation for more information.';
   END IF;
END;
$$;
