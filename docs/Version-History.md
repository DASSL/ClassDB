[ClassDB Home](Home) \| [Table of Contents](Table-of-Contents)

---
# Version History

This page lists the key changes in each version of ClassDB.

## [v2.2.0](https://github.com/DASSL/ClassDB/releases/tag/v2.2.0) (8/17/2018)
- Add compatibility with PostgreSQL Version 9.3 and up
- Prevent deletion of rows in activity tables
- See list of [enhancements made](https://github.com/DASSL/ClassDB/issues?utf8=%E2%9C%93&q=is%3Aissue+sort%3Aupdated-desc+is%3Aclosed+milestone%3A%22M4+%28V+2.2%29%22+label%3Aenhancement+-label%3Aepic) and [defects fixed](https://github.com/DASSL/ClassDB/issues?q=is%3Aissue+sort%3Aupdated-desc+milestone%3A%22M4+%28V+2.2%29%22+-label%3Aenhancement+-label%3Aepic+is%3Aclosed).

## [v2.1.0](https://github.com/DASSL/ClassDB/releases/tag/v2.1.0) (6/22/2018)
- Resolved many outstanding issues. See [here](https://github.com/DASSL/ClassDB/issues?q=is%3Aissue+milestone%3A%22M3+%28V+2.1%29%22+is%3Aclosed) for a full list
- Added support for [teams](Teams)
- Any user may now create any number of schema objects
- Disconnections are now logged
- Activity logging now records user session IDs

## [v2.0.0](https://github.com/DASSL/ClassDB/releases/tag/v2.0.0) (1/20/2018)
- Resolved many outstanding issues. See [here](https://github.com/DASSL/ClassDB/issues?utf8=%E2%9C%93&q=is%3Aissue+milestone%3A%22M2+%28V+2.0.0%29%22+) for a full list
- Changed ClassDB role management API - changes are incompatible with v1.0.0
- All ClassDB roles are now based on `RoleBase`
- All instances of ClassDB roles are stored within the same table, reducing code duplication
- Views have been added to display either all ClassDB users or only users of a certain type
- Many frequent user views have been added allowing ClassDB users to view their activity within the database
- Several frequent user views have been added to display summaries of student activity to instructors
- Most user activity views now return activity time stamps at the server's local time
- ClassDB can now record all instances of DDL and Connection activity from all users
- The uninstall scripts no longer forcefully remove user objects that may depend on ClassDB objects
- The `src` directory has been reorganized to clarify script usage


## [v1.0.0](https://github.com/DASSL/ClassDB/releases/tag/v1.0.0) (7/10/2017)
- First release of ClassDB
