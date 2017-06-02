--Andrew Figueroa
--
--shelterCreate.sql
--
--Schemas for CS205; Created: 2017-05-31; Modified 2017-06-01

--The following script should be run as the role desired to be the owner of the shelter schema.

--This script creates a schema for the Shelter senario, along with creating the senario's
-- tables and poplating them.

CREATE SCHEMA shelter;
GRANT USAGE ON SCHEMA shelter TO instructor;
GRANT USAGE ON SCHEMA shelter TO student;
GRANT USAGE ON SCHEMA shelter TO admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA shelter GRANT SELECT ON TABLES TO instructor;
ALTER DEFAULT PRIVILEGES IN SCHEMA shelter GRANT SELECT ON TABLES TO student;
ALTER DEFAULT PRIVILEGES IN SCHEMA shelter GRANT SELECT ON TABLES TO admin;


--This shelter schema was originally created by Dr. Gancho Ganchev and Julie Gordon as a part
-- of a workbook to introduce SQL*Plus. This schema was originally implemented for Oracle as
-- a part of a term project by Julie Gordon, a Student at Western Connecticut State University
-- for a Data Modeling and Database Design class in 2003/2004.

--This schema has been ported to pgSQL for implementation in Postgres 9.6 while making the
-- fewest changes possible.

CREATE TABLE shelter.dog
(
  dog_id        CHAR(3) NOT NULL,
  name          VARCHAR(15),
  arrival_date  DATE,
  breed         VARCHAR(20),
  date_of_birth DATE,
  weight        NUMERIC(3),
  PRIMARY KEY(dog_id)
);

CREATE TABLE shelter.adopter
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

CREATE TABLE shelter.volunteer
(
  vol_id CHAR(3),
  fname  VARCHAR(10),
  lname  VARCHAR(10) NOT NULL,
  phone  CHAR(13),
  email  VARCHAR(15),
  PRIMARY KEY(vol_id)
);

CREATE TABLE shelter.responsibility
(
  title VARCHAR(20),
  PRIMARY KEY(title)
);

CREATE TABLE shelter.vet
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

CREATE TABLE shelter.adoption
(
  dog_id        CHAR(3),
  adopter_id    CHAR(3),
  vol_id        CHAR(3),
  adoption_date DATE,
  adoption_fee  NUMERIC(5, 2),
  FOREIGN KEY(dog_id) REFERENCES shelter.dog(dog_id),
  FOREIGN KEY(adopter_id) REFERENCES shelter.adopter(adopter_id),
  FOREIGN KEY(vol_id) REFERENCES shelter.volunteer(vol_id),
  PRIMARY KEY(dog_id, adopter_id, vol_id)
);

CREATE TABLE shelter.treatment
(
  treatment_id   CHAR(3),
  vet_id         CHAR(1),
  dog_id         CHAR(3),
  treatment_date DATE,
  description    VARCHAR(20),
  fee            NUMERIC(5, 2),
  discount_rate  NUMERIC(4, 2),
  FOREIGN KEY(vet_id) REFERENCES shelter.vet(vet_id),
  FOREIGN KEY(dog_id) REFERENCES shelter.dog(dog_id),
  PRIMARY KEY(treatment_id)
);

CREATE TABLE shelter.return
(
  dog_id      CHAR(3),
  adopter_id  CHAR(3),
  return_date DATE,
  reason      VARCHAR(30),
  FOREIGN KEY(dog_id) REFERENCES shelter.dog(dog_id),
  FOREIGN KEY(adopter_id) REFERENCES shelter.adopter(adopter_id),
  PRIMARY KEY(dog_id, adopter_id)
);

CREATE TABLE shelter.assignment
(
  vol_id         CHAR(3),
  responsibility VARCHAR(20),
  FOREIGN KEY(vol_id) REFERENCES shelter.volunteer(vol_id),
  FOREIGN KEY(responsibility) REFERENCES shelter.responsibility(title),
  PRIMARY KEY(vol_id, responsibility)
);
