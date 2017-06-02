--Andrew Figueroa
--
--shelterDrop.sql
--
--Schemas for CS205; Created: 2017-05-31; Modified 2017-05-31

--This script must be run under the role that is the owner of the shelter schema.

--This script drops the shelter schema, with the CASCADE option. This option drops all objects
-- in the schema (e.g. tables, view, functions, etc.), also with the CASCADE option. This means
-- that all objects dependent on objects in the schema will also be dropped.

DROP SCHEMA shelter CASCADE;
