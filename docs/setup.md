# ClassDB Setup

This document will explain how to install and configure ClassDB in an existing PostgreSQL (Postgres) instance.  

## Prerequisites
ClassDB requires an existing instance of Postgres to run on.  This documentation will not go into detail on how to install and configure a Posrtgres
instance, however it will detail some requirements for ClassDB to function correctly.  ClassDB has been primarily tested with the [BigSQL Postgres 9.6.3 distribution](https://www.bigsql.org/)
on Windows 10 and Ubuntu Server 16.04.

ClassDB currently requires a "fully owned instance" of Postgres to function correctly.  We define "fully owned instance" as one which you have full control 
over the host server.  This includes Postgres instances running on a local machine, a local virtual machine, or a virtual machine instance in a cloud service
such as Amazon EC2 or Azure VM.  ClassDB does not support platform as a service (PaaS) instances, such as Amazon RDS or Azure Database for PostgreSQL.

Additionally, your Postgres instance must be configured to accept connections from external clients.  Depening on the distribution used, your instance
may come pre-configured to accept external connections.  For example, the BigSQL distribution will accept connections from authorized database users
connecting with remote clients.  If your instance is not configured to accept incomming connections, please refer to the ```pg_hba.conf``` [documentation](https://www.postgresql.org/docs/9.6/static/auth-pg-hba-conf.html)
for information on how to allow connections from remote clients.