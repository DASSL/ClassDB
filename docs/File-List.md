# File List
This document lists the files located in the ClassDB repository. Each section lists the files in the corresponding folder.

## Root (./)
Contains the README and LICENSE files, as well as each ClassDB sub-folder.
- LICENSE.md
- README.md

## examples (./examples)
Contains script files for the shelter example schema. More information can be found on the [[Scripts]] page.
- createShelterSchema.sql
- dropShelterSchema.sql
- populateShelterSchema.sql

## src (./src)
Contains the source code for ClassDB. All files need to install ClassDB are in this folder. More information can be found on the [[Scripts]] page.
- addCatalogMgmt.sql
- addConnectionMgmt.sql
- addDDLMonitors.sql
- addHelpers.sql
- addLogMgmt.sql
- addUserMgmt.sql
- enableServerLogging.sql
- initializeDB.sql
- prepareDB.psql
- prepareServer.sql
- removeFromDB.sql
- removeFromServer.sql

## tests (./tests)
This folder contains scripts to test the functionality of ClassDB, along with the privileges sub-folder
- testAddHelperFunctions.sql
- testAddUserMgmt.sql
- testAddUserMgmtCleanup.sql
- testAddUserMgmtREADME.txt

### privileges (./tests/privileges)
This folder contains a sequence of scripts to test the functionality of ClassDB's privilege management
- 0_setup.sql
- 1_instructorPass.sql
- 2_studentPass.sql
- 3_dbmanagerPass.sql
- 4_instructorPass2.sql
- 5_instructorFail.sql
- 6_studentFail.sql
- 7_dbmanagerFail.sql
- 8_cleanup.sql
- testPrivilegesREADME.txt

---
Steven Rollo  
Data Science & Systems Lab (DASSL), Western Connecticut State University (WCSU)

(C) 2017- DASSL. ALL RIGHTS RESERVED.
Licensed to others under CC 4.0 BY-SA-NC: https://creativecommons.org/licenses/by-nc-sa/4.0/

PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.