[ClassDB Home](Home) \| [Table of Contents](Table-of-Contents)

---
# Teams

_Author: Andrew Figueroa_

ClassDB allows the creation of "teams". These teams allow students to easily 
collaborate with one another through the use of shared spaces. Students can be 
added to a team, at which point they will have full access to data within the 
team's shared space. There is no limit to the number of teams that can be 
created, nor is there a limit on the number of members a team may have. Any 
student may also be a member of multiple teams.

Only instructors have read access on all teams within an instance of ClassDB. 
Instructors and DB managers, but not students, can manage team memberships. See 
[ClassDB's Roles page](Roles) for more information on the privileges that each 
type of user has in an instance of ClassDB.

The `ClassDB.Team` view provides a listing of known teams in the current 
database. A count of the number of team members in each team is also provided.

Parameter data types of functions listed below have been modified from their 
internal referential representation to their effective types.

## Creating a Team

The following function allows for the creation of a ClassDB team.

```
ClassDB.createTeam(teamName VARCHAR(63),
                   schemaName VARCHAR(63) DEFAULT NULL,
                   extraInfo VARCHAR DEFAULT NULL,
                   okIfRoleExists BOOLEAN DEFAULT TRUE,
                   okIfSchemaExists BOOLEAN DEFAULT TRUE)
```
The following is a description of the parameters that are used during the 
creation of a team:

| Parameter Name and Effective Data Type | Default Value | Notes |
|----------------------------------------|------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `teamName`: `VARCHAR(63)` | None - **required parameter** | The name of the team. This same value will be used to maintain records on the server instance (the _server role_). This value should follow the rules for [SQL Identifiers in Postgres](https://www.postgresql.org/docs/9.6/static/sql-syntax-lexical.html#SQL-SYNTAX-IDENTIFIERS).<br/><br/>If no server role matches `teamName`, then a server role is created with this name.<br/><br/>If a server role matching `teamName` does exist on the server, then if `okIfRoleExists` is false, an EXCEPTION is raised. Otherwise, if `okIfRoleExists`, the function will raise a NOTICE, but continue creating the team.<br/><br/>Regardless of the value of `okIfRoleExists`, if the role already exists on the server, the password for the role (if any) is not changed.<br/><br/>An EXCEPTION will also be raised if a user with the same name was already known to ClassDB |
| `fullName`:`VARCHAR` | `NULL` | The team's full or "display" name, or some other identifying information that should be stored for later reference. |
| `schemaName`: `VARCHAR(63)` | `NULL` | The name of the schema that should be assigned to the team being created. This value should follow the rules for [SQL Identifiers in Postgres](https://www.postgresql.org/docs/9.6/static/sql-syntax-lexical.html#SQL-SYNTAX-IDENTIFIERS). If `NULL`, the default value, then `teamName` is used as the schema name.<br/><br/>If a schema matching `schemaName` does not exists in the database ClassDB is installed in, it is created and ownership of the schema is assigned to the role matching `teamName`.<br/><br/>If a schema matching `schemaName` does exist in the database, then if `okIfSchemaExists` is false, an EXCEPTION is raised. Otherwise, if `okifSchemaExists` is true, then it is verified that the team being created has ownership of that schema. If they do not, an EXCEPTION is raised. |
| `extraInfo`: `VARCHAR` | `NULL` | Any additional information that is desired to be stored, such as a full name or description for the team |
| `okIfRoleExists`: `BOOLEAN` | `TRUE` | If `TRUE`, then no EXCEPTION is raised by the function if a role matching `teamName` already exists on the server. |
| `okIfSchemaExists`: `BOOLEAN` | `TRUE` | If `TRUE`, then no EXCEPTION is raised by the function if a schema matching `schemaName` already exists on the server AND the role matching `teamName` is the owner of the schema. |


## Managing Team Membership

Becoming a member of a team allows a student to access and add new objects to the team's shared schema. When a student is removed from a team, ownership of objects that the student had created in the team's schema will be transferred to the team role. This allows other team members to continue using these objects even after the student is removed from the server.

The `ClassDB.TeamMember` view provides a listing of all team memberships in the current database.

### Adding a student

The following function adds a student to a team.

```
ClassDB.addToTeam(studentName VARCHAR(63),
                  teamName VARCHAR(63))
```

### Removing a student

The following function removes a student from a team.

```
ClassDB.removeFromTeam(studentName VARCHAR(63),
                       teamName VARCHAR(63))
```

## Revoking a Team

The following function revokes the team designation from a role.

```
ClassDB.revokeTeam(teamName VARCHAR(63))
```

## Dropping a Team

The following function drops a team from an instance of ClassDB. The behavior of these parameters matches that of the functions for [dropping users](removing-Users).
```
ClassDB.dropTeam(teamName VARCHAR(63),
                 dropFromServer BOOLEAN DEFAULT FALSE,
                 okIfRemainsClassDBRoleMember BOOLEAN DEFAULT TRUE,
                 objectsDisposition VARCHAR DEFAULT 'assign',
                 newObjectsOwnerName VARCHAR(63) DEFAULT NULL)
```
---