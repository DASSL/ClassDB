[ClassDB Home](Home) \| [Table of Contents](Table-of-Contents)

---
# Version History

_Author: Steven Rollo_

This page lists the key changes in each version of ClassDB.

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