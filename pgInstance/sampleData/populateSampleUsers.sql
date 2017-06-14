--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab at Western Connecticut State University (dassl@WCSU)
--
--populateSampleUsers.sql
--
--Class DB - Created: 2017-05-29; Modified 2017-06-02


--The following query executes the createStudent procedure for every row in SampleStudent by using the
-- LATERAL keyword.
--This statement can only be run after the SampleStudent table has been populated.
SELECT lat.msg
FROM SampleStudent S, LATERAL
   (SELECT 'Student role for "' || S.name || '" created.' msg, createStudent(S.ID, S.userName, S.name)) lat;

--Calling the setCS205SearchPath procedure sets a student's search path to "%user%, shelter,
-- pvfc, public".
SELECT lat.msg
FROM SampleStudent S, LATERAL
   (SELECT 'Search path for "' || S.userName || '" changed.' msg, setCS205SearchPath(S.userName)) lat;

--The following query executes the createInstructor procedure for every row in SampleInstructor by
-- using the LATERAL keyword.
--This statement can only be run after the Sam msg, pleInstructor table has been populated.
SELECT lat.msg
FROM SampleInstructor I, LATERAL
   (SELECT 'Instructor role for "' || I.name || '" created.' msg, createInstructor(I.ID, I.userName, I.name)) lat;

--TODO: Remove the following lines once roles have been finalized
GRANT Admin TO parkst;
GRANT Admin TO quinnm;
