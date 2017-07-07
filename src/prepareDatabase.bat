@ECHO OFF
REM prepareDatabase.sql - ClassDB

REM Steven Rollo, Sean Murthy
REM Data Science & Systems Lab (DASSL), Western Connecticut State University (WCSU)

REM (C) 2017- DASSL. ALL RIGHTS RESERVED.
REM Licensed to others under CC 4.0 BY-SA-NC
REM https://creativecommons.org/licenses/by-nc-sa/4.0/

REM PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.

REM Easy installer for ClassDB databse components
REM Installs all required ClassDB components to a single database
REM USAGE: prepareDatabase.bat [place required psql options here]
REM The switches provided are directly passed to psql, so you can use any necessary
REM psql switches

SET error="\set ON_ERROR_STOP on"
SET scriptFiles="-f initalizeDB.sql -f addHelpers.sql -f prepareClassDB.sql"

psql %1 %2 %3 %4 %5 %6 %7 %8 %9 -c %error% %scriptFiles%

IF %return%==0 (
   ECHO "ClassDB installed successfuly."
)
IF ELSE (
   ECHO "There was an error during execution. Please check the script out for more details."
)

pause
