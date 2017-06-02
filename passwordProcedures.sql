--Andrew Figueroa
--
--passwordProcedures.sql
--
--Users and Roles for CS205; Created: 2017-05-30; Modified 2017-05-31

--This script should be run as an Admin, due to the functions being declared SECURITY DEFINER

--The following procedure allows changing the password for a given username, given both the
-- username and password. Exceptions are raised if the user does not exist or if the password
-- does not meet the requirements.

--Current password requirements:
-- - Must be 6 or more characters
-- - Must contain at least one numerical digit (0-9)

CREATE OR REPLACE FUNCTION changeUserPassword(userName VARCHAR(63), password VARCHAR(128)) RETURNS VOID AS
$$
DECLARE
    userExists BOOLEAN;
BEGIN
    EXECUTE format('SELECT 1 FROM pg_roles WHERE rolname = %L', userName) INTO userExists;
    IF userExists THEN
        IF
            LENGTH(password) > 5 AND
            SUBSTRING(password from '[0-9]') IS NOT NULL
        THEN
            EXECUTE format('ALTER ROLE %I ENCRYPTED PASSWORD %L', username, password);
        ELSE
            RAISE EXCEPTION 'Password does not meet requirements. Must be 6 or more characters and contain at least 1 number';
        END IF;
    ELSE
        RAISE EXCEPTION 'User: "%" does not exist', userName;
    END IF;
END
$$  LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = public, pg_catalog, pg_temp;
REVOKE ALL ON FUNCTION changeUserPassword(userName VARCHAR(63), password VARCHAR(128)) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION changeUserPassword(userName VARCHAR(63), password VARCHAR(128)) TO Admin;

--The following procedure resets a users password to the default password given a username

CREATE OR REPLACE FUNCTION resetUserPassword(userName VARCHAR(63)) RETURNS VOID AS
$$
DECLARE
    defaultPass VARCHAR(128);
BEGIN
    IF
        pg_has_role(userName, 'Student', 'member')
    THEN
        EXECUTE format('SELECT ID FROM Student S WHERE S.userName = %L', userName) INTO defaultPass;
        PERFORM changeUserPassword(userName, defaultPass);
    ELSIF
        pg_has_role(userName, 'Instructor', 'member')
    THEN
        EXECUTE format('SELECT ID FROM Instructor I WHERE I.userName = %L', userName) INTO defaultPass;
        PERFORM changeUserPassword(userName, defaultPass);
    ELSE
        RAISE EXCEPTION 'User: "%" not found among registered users', userName;
    END IF;
END
$$  LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = admin, public, pg_catalog, pg_temp;
REVOKE ALL ON FUNCTION resetUserPassword(userName VARCHAR(63)) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION resetUserPassword(userName VARCHAR(63)) TO Admin;


--The folowing procedure allows a user to change their password to a specified one

CREATE OR REPLACE FUNCTION changeMyPassword(newPass VARCHAR(128)) RETURNS VARCHAR(100) AS
$$
BEGIN
    PERFORM changeUserPassword(session_user, newPass);
    RETURN 'Password successfully changed';
END
$$  LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = public, pg_catalog, pg_temp;
