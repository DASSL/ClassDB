--createShelterSchema.sql - Schemas for CS205

--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab (DASSL), Western Connecticut State University (WCSU)

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.

--This shelter schema was originally created by Dr. Gancho Ganchev and Julie
-- Gordon as a part of a workbook to introduce SQL*Plus. This schema was originally
-- implemented for Oracle as a part of a term project by Julie Gordon, a Student
-- at Western Connecticut State University for a Data Modeling and Database Design
-- class in 2003/2004.

--This schema has been ported to pgSQL for implementation in Postgres 9.6 while
-- making the fewest changes possible.

BEGIN TRANSACTION;

--Check for superuser
DO
$$
BEGIN
   IF NOT (SELECT classdb.isSuperUser()) THEN
      RAISE EXCEPTION 'This script must be run as a superuser';
   END IF;
END
$$;

--Create shelter schema to hold these tables
CREATE SCHEMA IF NOT EXISTS shelter;

--Create all objects in the shelter schema.  This can be replaced with another schema
-- name if desired
SET LOCAL SCHEMA 'shelter';

CREATE TABLE IF NOT EXISTS dog
(
   dog_id        CHAR(3) NOT NULL,
   name          VARCHAR(15),
   arrival_date  DATE,
   breed         VARCHAR(20),
   date_of_birth DATE,
   weight        NUMERIC(3),
   PRIMARY KEY(dog_id)
);

CREATE TABLE IF NOT EXISTS adopter
(
   adopter_id CHAR(3),
   fname      VARCHAR(10),
   lname      VARCHAR(10) NOT NULL,
   address    VARCHAR(20),
   city       VARCHAR(15),
   state      CHAR(2),
   zip        CHAR(5),
   phone      CHAR(13),
   PRIMARY KEY(adopter_id)
);

CREATE TABLE IF NOT EXISTS volunteer
(
   vol_id CHAR(3),
   fname  VARCHAR(10),
   lname  VARCHAR(10) NOT NULL,
   phone  CHAR(13),
   email  VARCHAR(15),
   PRIMARY KEY(vol_id)
);

CREATE TABLE IF NOT EXISTS responsibility
(
   title VARCHAR(20),
   PRIMARY KEY(title)
);

CREATE TABLE IF NOT EXISTS vet
(
   vet_id  CHAR(1),
   fname   VARCHAR(10),
   lname   VARCHAR(10) NOT NULL,
   address VARCHAR(20),
   city    VARCHAR(15),
   state   CHAR(2),
   zip     CHAR(5),
   phone   CHAR(13),
   PRIMARY KEY(vet_id)
);

CREATE TABLE IF NOT EXISTS adoption
(
   dog_id        CHAR(3),
   adopter_id    CHAR(3),
   vol_id        CHAR(3),
   adoption_date DATE,
   adoption_fee  NUMERIC(5, 2),
   FOREIGN KEY(dog_id) REFERENCES dog(dog_id),
   FOREIGN KEY(adopter_id) REFERENCES adopter(adopter_id),
   FOREIGN KEY(vol_id) REFERENCES volunteer(vol_id),
   PRIMARY KEY(dog_id, adopter_id, vol_id)
);

CREATE TABLE IF NOT EXISTS treatment
(
   treatment_id   CHAR(3),
   vet_id         CHAR(1),
   dog_id         CHAR(3),
   treatment_date DATE,
   description    VARCHAR(20),
   fee            NUMERIC(5, 2),
   discount_rate  NUMERIC(4, 2),
   FOREIGN KEY(vet_id) REFERENCES vet(vet_id),
   FOREIGN KEY(dog_id) REFERENCES dog(dog_id),
   PRIMARY KEY(treatment_id)
);

CREATE TABLE IF NOT EXISTS return
(
   dog_id      CHAR(3),
   adopter_id  CHAR(3),
   return_date DATE,
   reason      VARCHAR(30),
   FOREIGN KEY(dog_id) REFERENCES dog(dog_id),
   FOREIGN KEY(adopter_id) REFERENCES adopter(adopter_id),
   PRIMARY KEY(dog_id, adopter_id)
);

CREATE TABLE IF NOT EXISTS assignment
(
   vol_id         CHAR(3),
   responsibility VARCHAR(20),
   FOREIGN KEY(vol_id) REFERENCES volunteer(vol_id),
   FOREIGN KEY(responsibility) REFERENCES responsibility(title),
   PRIMARY KEY(vol_id, responsibility)
);

--Revoke all permission on shelter by default
REVOKE ALL ON SCHEMA shelter FROM PUBLIC;

--Allow instructors and dbmanagers full access to the schema
GRANT ALL ON SCHEMA shelter TO ClassDB_Instructor, ClassDB_DBManager;
GRANT ALL ON ALL TABLES IN SCHEMA shelter TO ClassDB_Instructor, ClassDB_DBManager;

--GRANT USAGE and SELECT to students.  Note, this does not give
-- any permissions to use the schema/contained objects themselves, however it
-- is necessary to have USAGE + the other needed permissions.  For example,
-- to select from dog, you need USAGE on shelter and SELECT on dog
GRANT USAGE ON SCHEMA shelter TO ClassDB_Student;
GRANT SELECT ON ALL TABLES IN SCHEMA shelter TO ClassDB_Student;

COMMIT;
