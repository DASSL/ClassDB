--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab at Western Connecticut State University (dassl@WCSU)
--
--cs205Script.sql
--
--Schemas for CS205; Created: 2017-06-06; Modified 2017-06-06

--The following procedure sets a user's search_path to a new specified search_path. An
-- notice is raised if the user does not exist.
CREATE OR REPLACE FUNCTION classdb.setCS205SearchPath(userName NAME) RETURNS VOID AS
$$
DECLARE
   userExists BOOLEAN;
BEGIN
   EXECUTE format('SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = %L', userName) INTO userExists;
   IF
      userExists
   THEN
      EXECUTE format('ALTER USER %I SET search_path TO "$user", public, _shelter, _pvfc', userName);
   ELSE
      RAISE NOTICE 'User "%" does not exist', userName;
   END IF;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER;

REVOKE ALL ON FUNCTION classdb.setCS205SearchPath(userName NAME) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION classdb.setCS205SearchPath(userName NAME) TO DBManager;
GRANT EXECUTE ON FUNCTION classdb.setCS205SearchPath(userName NAME) TO Instructor;
