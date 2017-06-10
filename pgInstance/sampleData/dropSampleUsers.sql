--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab at Western Connecticut State University (dassl@WCSU)
--
--dropSampleUsers.sql
--
--Class DB - Created: 2017-05-31; Modified 2017-06-02

--This script can only be run after createUsers.sql has been run.

--The following query executes the dropStudent procedure for every row in SampleStudent by using the
-- LATERAL keyword.

SELECT lat.msg
FROM SampleStudent S, LATERAL
    (SELECT 'Student role for "' || S.name || '" removed.' msg, dropStudent(S.userName)) lat;

--The following query executes the dropInstructor procedure for every row in SampleInstructor by
-- using the LATERAL keyword.
--This statement can only be run after the SampleInstructor table has been populated.
SELECT lat.msg
FROM SampleInstructor I, LATERAL
    (SELECT 'Instructor role for "' || I.name || '" removed.' msg, dropInstructor(I.userName)) lat;
