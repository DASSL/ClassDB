--The following tests should be run as a superuser

CREATE OR REPLACE FUNCTION classdb.createGroupsTest() RETURNS TEXT AS
$$
DECLARE
    testFailed BOOLEAN := FALSE;
BEGIN
    --TODO: Test createUser
    --TODO: Test createStudent
    --TODO: Test createInstructor
    --TODO: Test dropStudent
    --TODO: Test dropInstructor
    --TODO: Test setCS205SearchPath
    IF testFailed THEN
        RETURN "ONE OR MORE TESTS FAILED: SEE WARNING(S)";
    ELSE
        RETURN "All tests passed";
END
$$  LANGUAGE plpgsql
    SECURITY DEFINER;


SELECT createGroupsTest();

DROP FUNCTION classdb.createGroupsTest();
