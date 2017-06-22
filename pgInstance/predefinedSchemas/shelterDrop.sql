--shelterDrop.sql - Schemas for CS205

--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab (DASSL), Western Connecticut State University (WCSU)

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC: https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.

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
