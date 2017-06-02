--Andrew Figueroa
--
--pvfcCreate.sql
--
--Schemas for CS205; Created: 2017-05-31; Modified 2017-06-01

--The following script should be run as the role desired to be the owner of the pvfc schema.

--This script creates and populated a schema for the Pine Valley Furniture Company (PVFC)
-- senario from the textbook "Modern Database Management (12th Edition)" written by Jeffrey A.
-- Hoffer, V. Ramesh, and Heikki Topi.


CREATE SCHEMA pvfc;
GRANT USAGE ON SCHEMA pvfc TO instructor;
GRANT USAGE ON SCHEMA pvfc TO student;
GRANT USAGE ON SCHEMA pvfc TO admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA pvfc GRANT SELECT ON TABLES TO instructor;
ALTER DEFAULT PRIVILEGES IN SCHEMA pvfc GRANT SELECT ON TABLES TO student;
ALTER DEFAULT PRIVILEGES IN SCHEMA pvfc GRANT SELECT ON TABLES TO admin;



--TODO: Create and populate objects for this schema, once it has been ported to pgSQL.
