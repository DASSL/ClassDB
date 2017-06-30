--shelterCreate.sql - Schemas for CS205

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

--The following lines populate the shelter schema with the data from the shelter
-- scenario


INSERT INTO dog VALUES('101', 'Amanda', '01-JAN-03', 'shepherd', '01-JAN-02', 70);
INSERT INTO dog VALUES('102', 'Frida', '22-JAN-03', 'spaniel', '09-NOV-01', 35);
INSERT INTO dog VALUES('103', 'Alice', '30-JAN-03', 'dachshund', '01-FEB-01', 30);
INSERT INTO dog VALUES('104', 'Jake', '06-FEB-03', 'terrier', '11-OCT-01', 30);
INSERT INTO dog VALUES('105', 'Jessica', '10-FEB-03', 'boxer', '15-APR-00', 60);
INSERT INTO dog VALUES('106', 'Florence', '11-FEB-03', 'retriever', '15-NOV-00', 70);
INSERT INTO dog VALUES('107', 'Venus', '22-FEB-03', 'poodle', '09-SEP-00', 20);
INSERT INTO dog VALUES('108', 'Prince', '22-FEB-03', 'boxer', '30-JUL-00', 65);
INSERT INTO dog VALUES('109', 'Max', '05-MAR-03', 'collie', '20-MAY-01', 40);
INSERT INTO dog VALUES('110', 'Spike', '05-MAR-03', 'terrier', '14-JUN-00', 25);
INSERT INTO dog VALUES('111', 'Sebastian', '14-MAR-03', 'dalmatian', '01-JAN-01', 70);
INSERT INTO dog VALUES('112', 'Tex', '27-MAR-03', 'shepherd', '22-JUN-01', 80);
INSERT INTO dog VALUES('113', 'Ralph', '01-APR-03', 'rottweiller', '15-MAR-00', 110);
INSERT INTO dog VALUES('114', 'Duke', '07-APR-03', 'shepherd', '13-SEP-01', 70);
INSERT INTO dog VALUES('115', 'Ginny', '18-APR-03', 'spaniel', '15-MAR-01', 40);
INSERT INTO dog VALUES('116', 'Chuck', '19-APR-03', 'chihuahua', '12-OCT-00', 10);
INSERT INTO dog VALUES('117', 'Rocky', '20-APR-03', 'hound', '10-AUG-02', 35);
INSERT INTO dog VALUES('118', 'Susie', '05-MAY-03', 'retriever', '15-DEC-01', 75);
INSERT INTO dog VALUES('119', 'Wendell', '05-MAY-03', 'retriever', '22-JAN-02', 85);
INSERT INTO dog VALUES('120', 'Dexter', '31-MAY-03', 'retriever', '22-SEP-99', 50);
INSERT INTO dog VALUES('121', 'Hailey', '07-JUN-03', 'pointer', '30-APR-02', 45);
INSERT INTO dog VALUES('122', 'Rosie', '15-JUN-03', 'retriever', '08-NOV-02', 65);
INSERT INTO dog VALUES('123', 'Bernie', '12-JUL-03', 'beagle', '22-JAN-00', 35);
INSERT INTO dog VALUES('124', 'Ziggy', '14-AUG-03', 'dalmatian', '30-MAY-01', 70);
INSERT INTO dog VALUES('125', 'Murphy', '18-SEP-03', 'shepherd', '20-FEB-01', 75);


INSERT INTO adopter VALUES('A01', 'George', 'White', '1 Maple Street', 'Danbury', 'CT', '06810', '(203)792-4653');
INSERT INTO adopter VALUES('A02', 'Amy', 'Hill', '2 School Street', 'Danbury', 'CT', '06810', '(203)743-7456');
INSERT INTO adopter VALUES('A03', 'Roger', 'Grant', '3 Rose Street', 'Bethel', 'CT', '06801', '(203)748-2357');
INSERT INTO adopter VALUES('A04', 'Peter', 'Cook', '4 Birch Drive', 'Ridgefield', 'CT', '06877', '(203)438-9767');
INSERT INTO adopter VALUES('A05', 'Alice', 'French', '5 Autumn Lane', 'Newtown', 'CT', '06460', '(203)426-2853');
INSERT INTO adopter VALUES('A06', 'Grace', 'Brown', '12 Tulip Drive', 'Danbury', 'CT', '06810', '(203)778-5243');
INSERT INTO adopter VALUES('A07', 'Fred', 'Grand', '22 Deer Trail', 'Bethel', 'CT', '06801', '(203)748-9345');
INSERT INTO adopter VALUES('A08', 'Bill', 'Flynn', '5 Autumn Lane', 'Newtown', 'CT', '06460', '(203)426-9887');
INSERT INTO adopter VALUES('A09', 'Dan', 'Burke', '44 Sky Lane', 'Ridgefield', 'CT', '06877', '(203)438-0658');
INSERT INTO adopter VALUES('A10', 'Ron', 'Best', '64 Robin Lane', 'Danbury', 'CT', '06810', '(203)744-4563');
INSERT INTO adopter VALUES('A11', 'Steve', 'Green', '12 Cedar Trail', 'Danbury', 'CT', '06810', '(203)744-0634');
INSERT INTO adopter VALUES('A12', 'June', 'Main', '77 Pine Street', 'Bethel', 'CT', '06801', '(203)792-9830');
INSERT INTO adopter VALUES('A13', 'April', 'Wade', '89 First Street', 'Newtown', 'CT', '06470', '(203)426-2350');
INSERT INTO adopter VALUES('A14', 'Harry', 'Mead', '10 White Street', 'Danbury', 'CT', '06810', '(203)792-4306');
INSERT INTO adopter VALUES('A15', 'Joe', 'Pratt', '22 Poplar Drive', 'Bethel', 'CT', '06801', '(203)748-0532');


INSERT INTO volunteer VALUES('V01', 'Fern', 'Amos', '(203)792-7624', 'fa@aol.com');
INSERT INTO volunteer VALUES('V02', 'Judd', 'Finch', '(203)743-7536', 'jf@msn.com');
INSERT INTO volunteer VALUES('V03', 'Esther', 'Boone', '(203)748-1246', 'er@snet.net');
INSERT INTO volunteer VALUES('V04', 'Stella', 'Curtis', '(203)438-1247', 'sc@aol.com');
INSERT INTO volunteer VALUES('V05', 'Stan', 'Holmes', '(203)426-8654', 'sh@rcn.com');
INSERT INTO volunteer VALUES('V06', 'Gail', 'Smart', '(203)775-2353', 'gs@aol.com');
INSERT INTO volunteer VALUES('V07', 'Al', 'Royal', '(203)743-6013', 'ar@msn.com');
INSERT INTO volunteer VALUES('V08', 'Sarah', 'Gold', '(203)730-6439', 'sg@snet.net');
INSERT INTO volunteer VALUES('V09', 'Gene', 'Baker', '(203)792-6542', 'gb@rcn.com');
INSERT INTO volunteer VALUES('V10', 'Barbara', 'Cook', '(203)438-5245', 'bc@aol.com');


INSERT INTO responsibility VALUES('feeding');
INSERT INTO responsibility VALUES('walking');
INSERT INTO responsibility VALUES('grooming');
INSERT INTO responsibility VALUES('fund-raising');
INSERT INTO responsibility VALUES('publicity');
INSERT INTO responsibility VALUES('training');
INSERT INTO responsibility VALUES('events');
INSERT INTO responsibility VALUES('transportation');
INSERT INTO responsibility VALUES('maintenance');
INSERT INTO responsibility VALUES('website');


INSERT INTO vet VALUES('1', 'Mary', 'Smith', '1 Main Street', 'Danbury', 'CT', '06810', '(203)792-1234');
INSERT INTO vet VALUES('2', 'Joan', 'Green', '2 Elm Street', 'Danbury', 'CT', '06810', '(203)743-1234');
INSERT INTO vet VALUES('3', 'Arthur', 'Jones', '3 Spring Street', 'Bethel', 'CT', '06801', '(203)748-1234');
INSERT INTO vet VALUES('4', 'Bill', 'Stern', '4 Terrace Drive', 'Ridgefield', 'CT', '06877', '(203)438-1234');
INSERT INTO vet VALUES('5', 'Rhoda', 'Williams', '5 Oak Lane', 'Newtown', 'CT', '06460', '(203)426-1234');


INSERT INTO adoption VALUES('111', 'A09', 'V01', '18-MAR-03', 100.00);
INSERT INTO adoption VALUES('112', 'A15', 'V03', '01-APR-03', 100.00);
INSERT INTO adoption VALUES('111', 'A12', 'V10', '22-MAY-03', 100.00);
INSERT INTO adoption VALUES('121', 'A01', 'V04', '14-JUN-03', 100.00);
INSERT INTO adoption VALUES('122', 'A02', 'V06', '25-JUL-03', 150.00);
INSERT INTO adoption VALUES('123', 'A04', 'V07', '01-AUG-03', 150.00);
INSERT INTO adoption VALUES('118', 'A06', 'V04', '20-AUG-03', 125.00);
INSERT INTO adoption VALUES('102', 'A02', 'V03', '23-AUG-03', 150.00);
INSERT INTO adoption VALUES('119', 'A11', 'V03', '25-AUG-03', 125.00);
INSERT INTO adoption VALUES('117', 'A14', 'V02', '30-AUG-03', 150.00);
INSERT INTO adoption VALUES('108', 'A07', 'V02', '01-SEP-03', 125.00);
INSERT INTO adoption VALUES('106', 'A10', 'V04', '02-SEP-03', 150.00);
INSERT INTO adoption VALUES('114', 'A11', 'V04', '05-SEP-03', 125.00);
INSERT INTO adoption VALUES('110', 'A08', 'V03', '08-SEP-03', 125.00);
INSERT INTO adoption VALUES('101', 'A03', 'V05', '10-SEP-03', 100.00);
INSERT INTO adoption VALUES('107', 'A03', 'V04', '10-SEP-03', 100.00);
INSERT INTO adoption VALUES('116', 'A13', 'V01', '10-SEP-03', 125.00);
INSERT INTO adoption VALUES('103', 'A01', 'V02', '15-SEP-03', 150.00);
INSERT INTO adoption VALUES('115', 'A12', 'V05', '15-SEP-03', 150.00);
INSERT INTO adoption VALUES('104', 'A05', 'V01', '17-SEP-03', 200.00);
INSERT INTO adoption VALUES('105', 'A04', 'V01', '18-SEP-03', 150.00);
INSERT INTO adoption VALUES('114', 'A15', 'V02', '30-SEP-03', 125.00);
INSERT INTO adoption VALUES('113', 'A10', 'V02', '01-OCT-03', 150.00);
INSERT INTO adoption VALUES('117', 'A13', 'V08', '01-OCT-03', 150.00);
INSERT INTO adoption VALUES('125', 'A15', 'V09', '05-OCT-03', 150.00);
INSERT INTO adoption VALUES('124', 'A07', 'V08', '08-OCT-03', 125.00);
INSERT INTO adoption VALUES('107', 'A10', 'V07', '10-OCT-03', 100.00);
INSERT INTO adoption VALUES('103', 'A04', 'V06', '15-OCT-03', 150.00);
INSERT INTO adoption VALUES('120', 'A03', 'V02', '25-OCT-03', 125.00);
INSERT INTO adoption VALUES('109', 'A06', 'V01', '26-OCT-03', 150.00);


INSERT INTO treatment VALUES('T01', '2', '101', '07-JAN-03', 'neuter', 25.00, 0.1);
INSERT INTO treatment VALUES('T02', '2', '101', '13-FEB-03', 'neuter', 25.00, 0.1);
INSERT INTO treatment VALUES('T03', '3', '110', '07-MAR-03', 'neuter', 25.00, 0);
INSERT INTO treatment VALUES('T04', '5', '111', '16-MAR-03', 'neuter', 25.00, 0.05);
INSERT INTO treatment VALUES('T05', '5', '112', '28-MAR-03', 'neuter', 25.00, 0.2);
INSERT INTO treatment VALUES('T06', '2', '113', '03-APR-03', 'neuter', 25.00, 0.05);
INSERT INTO treatment VALUES('T07', '1', '114', '08-APR-03', 'neuter', 25.00, 0.05);
INSERT INTO treatment VALUES('T08', '1', '115', '24-APR-03', 'neuter', 25.00, 0.05);
INSERT INTO treatment VALUES('T09', '3', '119', '07-MAY-03', 'neuter', 25.00, 0.1);
INSERT INTO treatment VALUES('T10', '1', '107', '01-JUN-03', 'worms', 50.00, 0.05);
INSERT INTO treatment VALUES('T11', '1', '104', '05-JUN-03', 'kennel cough', 25.00, 0.1);
INSERT INTO treatment VALUES('T12', '2', '121', '09-JUN-03', 'neuter', 25.00, 0.2);
INSERT INTO treatment VALUES('T13', '1', '122', '15-JUN-03', 'infection', 60.00, 0.05);
INSERT INTO treatment VALUES('T14', '2', '105', '20-JUN-03', 'laceration', 40.00, 0.05);
INSERT INTO treatment VALUES('T15', '4', '102', '06-JUL-03', 'lyme disease', 50.00, 0.1);
INSERT INTO treatment VALUES('T16', '3', '123', '14-JUL-03', 'neuter', 25.00, 0.2);
INSERT INTO treatment VALUES('T17', '4', '122', '15-JUL-03', 'vaccination', 15.00, 0.05);
INSERT INTO treatment VALUES('T18', '1', '105', '09-AUG-03', 'kennel cough', 25.00, 0);
INSERT INTO treatment VALUES('T19', '3', '107', '09-AUG-03', 'fracture', 60.00, 0.05);
INSERT INTO treatment VALUES('T20', '2', '107', '15-AUG-03', 'mange', 80.00, 0.05);
INSERT INTO treatment VALUES('T21', '4', '124', '15-AUG-03', 'kennel cough', 45.00, 0.1);
INSERT INTO treatment VALUES('T22', '5', '118', '16-AUG-03', 'worms', 50.00, 0);
INSERT INTO treatment VALUES('T23', '4', '119', '21-AUG-03', 'vaccination', 15.00, 0);
INSERT INTO treatment VALUES('T24', '2', '110', '24-AUG-03', 'infection', 65.00, 0.05);
INSERT INTO treatment VALUES('T25', '1', '116', '26-AUG-03', 'vaccination', 15.00, 0.2);
INSERT INTO treatment VALUES('T26', '1', '117', '26-AUG-03', 'laceration', 30.00, 0.05);
INSERT INTO treatment VALUES('T27', '2', '114', '30-AUG-03', 'vaccination', 15.00, 0.1);
INSERT INTO treatment VALUES('T28', '2', '101', '01-SEP-03', 'vaccination', 15.00, 0);
INSERT INTO treatment VALUES('T29', '4', '101', '01-SEP-03', 'worms', 35.00, 0);
INSERT INTO treatment VALUES('T30', '4', '107', '01-SEP-03', 'kennel cough', 30.00, 0.1);
INSERT INTO treatment VALUES('T31', '3', '113', '01-SEP-03', 'vaccination', 15.00, 0);
INSERT INTO treatment VALUES('T32', '5', '107', '05-SEP-03', 'fracture', 25.00, 0.05);
INSERT INTO treatment VALUES('T33', '2', '104', '05-SEP-03', 'infection', 50.00, 0.05);
INSERT INTO treatment VALUES('T34', '3', '115', '06-SEP-03', 'vaccination', 15.00, 0.05);
INSERT INTO treatment VALUES('T35', '3', '125', '20-SEP-03', 'neuter', 25.00, 0.1);
INSERT INTO treatment VALUES('T36', '4', '109', '30-SEP-03', 'infection', 30.00, 0);
INSERT INTO treatment VALUES('T37', '5', '124', '30-SEP-03', 'vaccination', 15.00, 0.05);
INSERT INTO treatment VALUES('T38', '3', '120', '20-OCT-03', 'kennel cough', 45.00, 0.05);


INSERT INTO return VALUES('111', 'A09', '15-APR-03', 'separation anxiety');
INSERT INTO return VALUES('114', 'A11', '10-SEP-03', 'aggression');
INSERT INTO return VALUES('117', 'A14', '15-SEP-03', 'not housebroken');
INSERT INTO return VALUES('107', 'A03', '25-SEP-03', 'issues with other dog');
INSERT INTO return VALUES('103', 'A09', '02-OCT-03', 'chased cat');


INSERT INTO assignment VALUES('V01', 'feeding');
INSERT INTO assignment VALUES('V01', 'walking');
INSERT INTO assignment VALUES('V02', 'feeding');
INSERT INTO assignment VALUES('V02', 'walking');
INSERT INTO assignment VALUES('V03', 'grooming');
INSERT INTO assignment VALUES('V03', 'training');
INSERT INTO assignment VALUES('V04', 'fund-raising');
INSERT INTO assignment VALUES('V05', 'publicity');
INSERT INTO assignment VALUES('V06', 'feeding');
INSERT INTO assignment VALUES('V06', 'walking');
INSERT INTO assignment VALUES('V07', 'feeding');
INSERT INTO assignment VALUES('V07', 'walking');
INSERT INTO assignment VALUES('V08', 'grooming');
INSERT INTO assignment VALUES('V08', 'training');
INSERT INTO assignment VALUES('V09', 'maintenance');
INSERT INTO assignment VALUES('V10', 'feeding');
INSERT INTO assignment VALUES('V10', 'walking');
