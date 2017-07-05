--shelterDrop.sql - Schemas for CS205

--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab (DASSL), Western Connecticut State University (WCSU)

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.


--This script must be run under the role that is the owner of the shelter schema.

--This script drops the tables and views from the shelter scenario. Not all tables
-- or views may exist, depending on the queries the user has run.

DROP VIEW IF EXISTS shelter.dog_treatment;
DROP VIEW IF EXISTS shelter.treatment_view;
DROP VIEW IF EXISTS shelter.nvl_example;
DROP TABLE IF EXISTS shelter.phone_list;
DROP TABLE IF EXISTS shelter.adoption;
DROP TABLE IF EXISTS shelter.return;
DROP TABLE IF EXISTS shelter.treatment;
DROP TABLE IF EXISTS shelter.assignment;
DROP TABLE IF EXISTS shelter.volunteer;
DROP TABLE IF EXISTS shelter.adopter;
DROP TABLE IF EXISTS shelter.dog;
DROP TABLE IF EXISTS shelter.vet;
DROP TABLE IF EXISTS shelter.responsibility;

DROP SCHEMA IF EXISTS shelter;
