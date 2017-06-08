--Andrew Figueroa
--
--shelterDrop.sql
--
--Schemas for CS205; Created: 2017-05-31; Modified 2017-06-07

--This script must be run under the role that is the owner of the shelter schema.

--This script drops the tables and views from the shelter scenario. Not all tables or views may
-- exist, depending on the queries the user has run.

DROP VIEW IF EXISTS dog_treatment;
DROP VIEW IF EXISTS treatment_view;
DROP VIEW IF EXISTS nvl_example;
DROP TABLE IF EXISTS phone_list;
DROP TABLE IF EXISTS adoption;
DROP TABLE IF EXISTS return;
DROP TABLE IF EXISTS treatment;
DROP TABLE IF EXISTS assignment;
DROP TABLE IF EXISTS volunteer;
DROP TABLE IF EXISTS adopter;
DROP TABLE IF EXISTS dog;
DROP TABLE IF EXISTS vet;
DROP TABLE IF EXISTS responsibility;
