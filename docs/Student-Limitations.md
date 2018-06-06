[ClassDB Home](Home) \| [Table of Contents](Table-of-Contents)

---
# Limitations on Student Users

_Author: Andrew Figueroa_

In order to reduce the impact that any one student has on a server that is running an instance of ClassDB, students may have a limit on the number of connections they have open, and on the amount of time that a query can run. These limitations are enabled by default, but can be changed or disabled if desired. Currently, these values are set in `addUserMgmt.sql`, in the `createStudent()` function.

## Number of Connections

Whenever a user connects to the database, a new connection is opened on the server. Each connection takes up a certain amount of resources on the server. Certain platforms may also be limited in the number of connections that the server can have open at one time. Therefore, it is ideal to keep the number of connections open at a minimum. This is particularly an issue with Student users. This is because in most situations, they are the largest proportion of users, and they have the most unpredictable use of the database.

Typically, each Student will only be interacting with the database in one or two contexts at a time. However, certain clients, such as [pgAdmin](https://www.pgadmin.org/), may open additional background connections for other tasks, such as displaying server information, or managing multiple input windows. Therefore, it is not usually recommended set the limit of number of connections to a values less than 3. The default value is 5 connections, which is a reasonable value in most situations. Refer to [Link]() for information on setting the default connection limit for Students

Sometimes, connections are not automatically closed by a client, and need to be closed manually. Refer to [Managing User Connections](https://github.com/DASSL/ClassDB/wiki/Managing-User-Connections) for information on viewing currently open connections and killing unused idle connections.

This value can be set by modifying the number the following line in the `createStudent()` function in `addUserMgmt.sql`:

```sql
EXECUTE format('ALTER ROLE %s CONNECTION LIMIT 5', $1);
```
More information on the `CONNECTION LIMIT` setting can be found in [Postgres' documentation](https://www.postgresql.org/docs/9.6/static/sql-createrole.html).

## Query timeout

Another action performed by Students that can unnecessarily consume server resources are long running queries. A query that takes too long to compute uses up processor time and may be difficult to cancel depending on the client used. This is particularly an issue with Student users as they are more likely to run improperly formatted queries.

By default, the query timeout for students is set to 2 seconds. The majority of queries that Students are likely to perform will take significantly shorter that that. However, certain workloads may lead to this value being too low.

This value can be set by modifying the following line in the `createStudent()` function in `addUserMgmt.sql`:

```sql
EXECUTE format('ALTER ROLE %s SET statement_timeout = 2000', $1);
```

More information on the `statement_timeout` setting can be found in [Postgres' documentation](https://www.postgresql.org/docs/9.6/static/runtime-config-client.html).

***
