-- ===========================
-- DROP EXISTING TABLES
-- ===========================
DROP TABLE Release_Record CASCADE CONSTRAINTS;
DROP TABLE Enrichment_Log CASCADE CONSTRAINTS;
DROP TABLE Feedback_Log CASCADE CONSTRAINTS;
DROP TABLE Health_Check CASCADE CONSTRAINTS;
DROP TABLE Staff_Habitat CASCADE CONSTRAINTS;
DROP TABLE Volunteer CASCADE CONSTRAINTS;
DROP TABLE Animal CASCADE CONSTRAINTS;
DROP TABLE Staff CASCADE CONSTRAINTS;
DROP TABLE Habitat_Zone CASCADE CONSTRAINTS;

-- ===========================
-- TABLE DEFINITIONS
-- ===========================
CREATE TABLE Habitat_Zone (
    Zone_ID INT PRIMARY KEY,
    Zone_Name VARCHAR2(100) NOT NULL,
    Zone_Type VARCHAR2(100) NOT NULL
);

CREATE TABLE Staff (
    Staff_ID INT PRIMARY KEY,
    Name VARCHAR2(100) NOT NULL,
    Role VARCHAR2(50) NOT NULL,
    Contact VARCHAR2(15) NOT NULL,
    Shift VARCHAR2(20) NOT NULL CHECK (Shift IN ('Morning', 'Afternoon', 'Evening', 'Night', 'Day')) 
);

CREATE TABLE Animal (
    Animal_ID INT PRIMARY KEY,
    Species VARCHAR2(100) NOT NULL,
    Gender VARCHAR2(10) NOT NULL CHECK (Gender IN ('Male', 'Female')),
    Origin VARCHAR2(20) NOT NULL,
    Status VARCHAR2(20) NOT NULL,
    Arrival_Date DATE NOT NULL,
    Zone_ID INT NOT NULL,
    FOREIGN KEY (Zone_ID) REFERENCES Habitat_Zone(Zone_ID)
);

CREATE TABLE Volunteer (
    Volunteer_ID INT PRIMARY KEY,
    Name VARCHAR2(100) NOT NULL,
    Contact VARCHAR2(15) NOT NULL CHECK (REGEXP_LIKE(Contact, '^\d{3}-\d{7,8}$')),
    Institution VARCHAR2(100) NOT NULL,
    Assigned_Zone INT,
    FOREIGN KEY (Assigned_Zone) REFERENCES Habitat_Zone(Zone_ID)
);

CREATE TABLE Health_Check (
    Check_ID INT PRIMARY KEY,
    Animal_ID INT NOT NULL,
    Check_Date DATE NOT NULL,
    Score INT NOT NULL CHECK (Score BETWEEN 1 AND 5),
    Weight NUMBER(7,2) NOT NULL,
    Temperature NUMBER(4,1) NOT NULL CHECK (Temperature BETWEEN 36.0 AND 39.0),
    Notes VARCHAR2(255),
    FOREIGN KEY (Animal_ID) REFERENCES Animal(Animal_ID)
);

CREATE TABLE Feedback_Log (
    Feed_ID INT PRIMARY KEY,
    Animal_ID INT NOT NULL,
    Staff_ID INT NOT NULL,
    Feed_Date DATE NOT NULL,
    Food_Type VARCHAR2(100) NOT NULL,
    Quantity VARCHAR2(20) NOT NULL CHECK (
        REGEXP_LIKE(Quantity, '^[0-9]+(\.[0-9]+)?\s?(kg|g|ml|L)$') AND
        TO_NUMBER(REGEXP_SUBSTR(Quantity, '^[0-9]+(\.[0-9]+)?')) > 0
    ),
    FOREIGN KEY (Animal_ID) REFERENCES Animal(Animal_ID),
    FOREIGN KEY (Staff_ID) REFERENCES Staff(Staff_ID)
);

CREATE TABLE Enrichment_Log (
    Activity_ID INT PRIMARY KEY,
    Animal_ID INT NOT NULL,
    Staff_ID INT NOT NULL,
    Activity_Date DATE NOT NULL,
    Activity_Type VARCHAR2(100) NOT NULL,
    Notes VARCHAR2(255),
    FOREIGN KEY (Animal_ID) REFERENCES Animal(Animal_ID),
    FOREIGN KEY (Staff_ID) REFERENCES Staff(Staff_ID)
);

CREATE TABLE Release_Record (
    Release_ID INT PRIMARY KEY,
    Animal_ID INT NOT NULL UNIQUE,
    Release_Date DATE NOT NULL,
    GPS_Coordinates VARCHAR2(50) NOT NULL,
    Tracking_Category VARCHAR2(50),
    Released_By INT NOT NULL,
    FOREIGN KEY (Animal_ID) REFERENCES Animal(Animal_ID),
    FOREIGN KEY (Released_By) REFERENCES Staff(Staff_ID)
);

CREATE TABLE Staff_Habitat (
    Staff_ID INT NOT NULL,
    Zone_ID INT NOT NULL,
    Assignment_Date DATE NOT NULL,
    PRIMARY KEY (Staff_ID, Zone_ID),
    FOREIGN KEY (Staff_ID) REFERENCES Staff(Staff_ID),
    FOREIGN KEY (Zone_ID) REFERENCES Habitat_Zone(Zone_ID)
);

-- ===========================
-- TRIGGERS (BUSINESS RULES)
-- ===========================

-- Trigger 1: Animal must have health score >= 3 to be released
CREATE OR REPLACE TRIGGER trg_check_release_health
BEFORE INSERT ON Release_Record
FOR EACH ROW
DECLARE
    v_score INT;
BEGIN
    SELECT Score INTO v_score
    FROM Health_Check
    WHERE Animal_ID = :NEW.Animal_ID
    AND Check_Date = (
        SELECT MAX(Check_Date)
        FROM Health_Check
        WHERE Animal_ID = :NEW.Animal_ID
    );

    IF v_score < 3 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Animal health score too low for release.');
    END IF;
END;
/

-- Trigger 2: Staff can only be assigned to max 2 habitat zones
CREATE OR REPLACE TRIGGER trg_limit_staff_assignment
BEFORE INSERT ON Staff_Habitat
FOR EACH ROW
DECLARE
    v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM Staff_Habitat
    WHERE Staff_ID = :NEW.Staff_ID;

    IF v_count >= 2 THEN
        RAISE_APPLICATION_ERROR(-20002, 'Staff cannot be assigned to more than 2 zones.');
    END IF;
END;
/

-- Trigger 3: Enrichment must be logged every 7 days for animals under rehabilitation
CREATE OR REPLACE TRIGGER trg_enrichment_frequency
BEFORE INSERT ON Enrichment_Log
FOR EACH ROW
DECLARE
    v_status VARCHAR2(20);
    v_last_activity DATE;
BEGIN
    SELECT Status INTO v_status FROM Animal WHERE Animal_ID = :NEW.Animal_ID;

    IF v_status = 'Rehabilitation' THEN
        SELECT MAX(Activity_Date) INTO v_last_activity
        FROM Enrichment_Log
        WHERE Animal_ID = :NEW.Animal_ID;

        IF v_last_activity IS NOT NULL AND :NEW.Activity_Date - v_last_activity > 7 THEN
            RAISE_APPLICATION_ERROR(-20003, 'Enrichment log overdue for rehabilitation animal.');
        END IF;
    END IF;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        NULL; -- allow if it's the first enrichment log
END;
/

-- Trigger 4: Feed logs must be recorded within 1 hour of the feeding time
CREATE OR REPLACE TRIGGER trg_check_feed_timing
BEFORE INSERT ON Feedback_Log
FOR EACH ROW
BEGIN
    IF TRUNC(:NEW.Feed_Date) = TRUNC(SYSDATE) THEN
        IF ABS(:NEW.Feed_Date - SYSDATE) * 24 > 1 THEN
            RAISE_APPLICATION_ERROR(-20004, 'Feed log must be recorded within 1 hour of feeding time.');
        END IF;
    END IF;
END;
/

-- ===========================
-- INSERT DATA STARTS HERE
-- ===========================
INSERT INTO Habitat_Zone VALUES (1, 'Wetland Habitat', 'Aquatic');
INSERT INTO Habitat_Zone VALUES (2, 'Forest Canopy', 'Arboreal');
INSERT INTO Habitat_Zone VALUES (3, 'Quarantine Unit A', 'Medical');
INSERT INTO Habitat_Zone VALUES (4, 'Quarantine Unit B', 'Medical');
INSERT INTO Habitat_Zone VALUES (5, 'Grassland Enclosure', 'Terrestrial');
INSERT INTO Habitat_Zone VALUES (6, 'Nocturnal House', 'Specialized');
INSERT INTO Habitat_Zone VALUES (7, 'Primate Sanctuary', 'Arboreal');
INSERT INTO Habitat_Zone VALUES (8, 'Aviary', 'Bird Habitat');

INSERT INTO Staff VALUES (101, 'Ahmad bin Ismail', 'Veterinarian', '011-12345678', 'Morning');
INSERT INTO Staff VALUES (102, 'Mei Ling', 'Senior Keeper', '012-23456789', 'Evening');
INSERT INTO Staff VALUES (103, 'Rajesh Kumar', 'Keeper', '013-34567890', 'Morning');
INSERT INTO Staff VALUES (104, 'Sarah Johnson', 'Veterinarian', '014-45678901', 'Night');
INSERT INTO Staff VALUES (105, 'Mohd Ali', 'Keeper', '015-56789012', 'Evening');
INSERT INTO Staff VALUES (106, 'Chen Wei', 'Administrator', '016-67890123', 'Day');
INSERT INTO Staff VALUES (107, 'Fatimah Yusof', 'Senior Keeper', '017-78901234', 'Morning');
INSERT INTO Staff VALUES (108, 'David Smith', 'Veterinarian', '018-89012345', 'Evening');

INSERT INTO Animal VALUES (1001, 'Clouded Leopard', 'Female', 'Wild', 'Rehabilitation', TO_DATE('2023-01-01', 'YYYY-MM-DD'), 2);
INSERT INTO Animal VALUES (1002, 'Proboscis Monkey', 'Male', 'Captive', 'Permanent', TO_DATE('2023-05-20', 'YYYY-MM-DD'), 7);
INSERT INTO Animal VALUES (1003, 'Orangutan', 'Male', 'Wild', 'Observation', TO_DATE('2025-03-10', 'YYYY-MM-DD'), 7);
INSERT INTO Animal VALUES (1004, 'Pangolin', 'Female', 'Wild', 'Rehabilitation', TO_DATE('2025-05-22', 'YYYY-MM-DD'), 5);
INSERT INTO Animal VALUES (1005, 'Sun Bear', 'Male', 'Wild', 'Ready for Release', TO_DATE('2024-09-05', 'YYYY-MM-DD'), 2);
INSERT INTO Animal VALUES (1006, 'Hornbill', 'Female', 'Wild', 'Rehabilitation', TO_DATE('2025-02-18', 'YYYY-MM-DD'), 8);
INSERT INTO Animal VALUES (1007, 'Slow Loris', 'Male', 'Captive', 'Permanent', TO_DATE('2024-07-30', 'YYYY-MM-DD'), 6);
INSERT INTO Animal VALUES (1008, 'Civet', 'Female', 'Wild', 'Observation', TO_DATE('2025-04-12', 'YYYY-MM-DD'), 6);
INSERT INTO Animal VALUES (1009, 'Bornean Gibbon', 'Male', 'Wild', 'Released', TO_DATE('2024-10-15', 'YYYY-MM-DD'), 7);
INSERT INTO Animal VALUES (1010, 'Pygmy Elephant', 'Female', 'Wild', 'Released', TO_DATE('2024-08-20', 'YYYY-MM-DD'), 5);

INSERT INTO Volunteer VALUES (201, 'Lim Jia Yen', '019-90123456', 'University of Sabah', 2);
INSERT INTO Volunteer VALUES (202, 'Amirul Hakim', '010-01234567', 'Sabah Wildlife Department', 5);
INSERT INTO Volunteer VALUES (203, 'Priya Devi', '011-11223344', 'WWF Malaysia', 7);
INSERT INTO Volunteer VALUES (204, 'Wong Ken Min', '012-22334455', 'Kota Kinabalu College', 8);
INSERT INTO Volunteer VALUES (205, 'Norhayati', '013-33445566', 'Sabah Forestry Department', 2);
INSERT INTO Volunteer VALUES (206, 'James Robert', '014-44556677', 'International Volunteer Org', 3);
INSERT INTO Volunteer VALUES (207, 'Siti Aishah', '015-55667788', 'University of Malaya', 6);
INSERT INTO Volunteer VALUES (208, 'Tanaka Hiroshi', '016-66778899', 'Japanese Conservation Soc.', 4);

INSERT INTO Health_Check VALUES (5001, 1001, TO_DATE('2025-01-15 10:30:00', 'YYYY-MM-DD HH24:MI:SS'), 4, 12.5, 38.2, 'Dehydrated, minor injuries');
INSERT INTO Health_Check VALUES (5002, 1002, TO_DATE('2024-11-21 09:15:00', 'YYYY-MM-DD HH24:MI:SS'), 4, 8.2, 37.8, 'Good condition');
INSERT INTO Health_Check VALUES (5003, 1003, TO_DATE('2025-03-11 14:20:00', 'YYYY-MM-DD HH24:MI:SS'), 3, 45.0, 37.5, 'Recovering well');
INSERT INTO Health_Check VALUES (5004, 1004, TO_DATE('2025-05-23 11:45:00', 'YYYY-MM-DD HH24:MI:SS'), 5, 3.1, 39.0, 'Fully recovered, excellent condition');
INSERT INTO Health_Check VALUES (5005, 1005, TO_DATE('2024-09-06 10:00:00', 'YYYY-MM-DD HH24:MI:SS'), 5, 65.0, 37.0, 'Excellent, ready for release');
INSERT INTO Health_Check VALUES (5006, 1006, TO_DATE('2025-02-19 13:30:00', 'YYYY-MM-DD HH24:MI:SS'), 4, 1.8, 38.5, 'Wing healed, flying well');
INSERT INTO Health_Check VALUES (5007, 1007, TO_DATE('2024-07-31 15:45:00', 'YYYY-MM-DD HH24:MI:SS'), 4, 1.2, 37.2, 'Stable');
INSERT INTO Health_Check VALUES (5008, 1008, TO_DATE('2025-04-13 16:20:00', 'YYYY-MM-DD HH24:MI:SS'), 3, 3.5, 37.8, 'Under observation');
INSERT INTO Health_Check VALUES (5009, 1009, TO_DATE('2025-03-14 10:00:00', 'YYYY-MM-DD HH24:MI:SS'), 4, 8.5, 37.8, 'Healthy for release');
INSERT INTO Health_Check VALUES (5010, 1010, TO_DATE('2025-01-09 09:30:00', 'YYYY-MM-DD HH24:MI:SS'), 5, 15000.0, 37.5, 'Very healthy');

INSERT INTO Feedback_Log VALUES (6001, 1001, 102, TO_DATE('2025-06-01 08:00:00', 'YYYY-MM-DD HH24:MI:SS'), 'Raw Chicken', '1.5 kg');
INSERT INTO Feedback_Log VALUES (6002, 1002, 103, TO_DATE('2025-06-01 09:30:00', 'YYYY-MM-DD HH24:MI:SS'), 'Fruits', '2.0 kg');
INSERT INTO Feedback_Log VALUES (6003, 1003, 101, TO_DATE('2025-06-01 10:15:00', 'YYYY-MM-DD HH24:MI:SS'), 'Vegetables', '3.0 kg');
INSERT INTO Feedback_Log VALUES (6004, 1004, 104, TO_DATE('2025-06-02 11:00:00', 'YYYY-MM-DD HH24:MI:SS'), 'Ants/Termites', '0.5 kg');
INSERT INTO Feedback_Log VALUES (6005, 1005, 105, TO_DATE('2025-06-02 12:30:00', 'YYYY-MM-DD HH24:MI:SS'), 'Mixed Meat', '2.5 kg');
INSERT INTO Feedback_Log VALUES (6006, 1006, 101, TO_DATE('2025-06-02 13:45:00', 'YYYY-MM-DD HH24:MI:SS'), 'Fruits', '0.3 kg');
INSERT INTO Feedback_Log VALUES (6007, 1007, 107, TO_DATE('2025-06-03 14:15:00', 'YYYY-MM-DD HH24:MI:SS'), 'Insects', '0.2 kg');
INSERT INTO Feedback_Log VALUES (6008, 1008, 108, TO_DATE('2025-06-03 15:30:00', 'YYYY-MM-DD HH24:MI:SS'), 'Cat Food', '0.4 kg');

INSERT INTO Enrichment_Log VALUES (7001, 1001, 102, TO_DATE('2025-06-01 16:00:00', 'YYYY-MM-DD HH24:MI:SS'), 'Climbing Training', 'Responding well');
INSERT INTO Enrichment_Log VALUES (7002, 1002, 107, TO_DATE('2025-06-01 10:30:00', 'YYYY-MM-DD HH24:MI:SS'), 'Foraging Puzzle', 'Completed successfully');
INSERT INTO Enrichment_Log VALUES (7003, 1003, 107, TO_DATE('2025-06-02 11:45:00', 'YYYY-MM-DD HH24:MI:SS'), 'Nest Building', 'Showed interest');
INSERT INTO Enrichment_Log VALUES (7004, 1004, 105, TO_DATE('2025-06-03 09:15:00', 'YYYY-MM-DD HH24:MI:SS'), 'Burrow Simulation', 'Needs practice');
INSERT INTO Enrichment_Log VALUES (7005, 1005, 102, TO_DATE('2025-06-03 14:30:00', 'YYYY-MM-DD HH24:MI:SS'), 'Hunting Simulation', 'Excellent performance');
INSERT INTO Enrichment_Log VALUES (7006, 1006, 104, TO_DATE('2025-06-04 10:00:00', 'YYYY-MM-DD HH24:MI:SS'), 'Flight Training', 'Short flights achieved');
INSERT INTO Enrichment_Log VALUES (7007, 1007, 107, TO_DATE('2025-06-04 20:15:00', 'YYYY-MM-DD HH24:MI:SS'), 'Nocturnal Foraging', 'Active participation');
INSERT INTO Enrichment_Log VALUES (7008, 1008, 105, TO_DATE('2025-06-05 15:45:00', 'YYYY-MM-DD HH24:MI:SS'), 'Scent Tracking', 'Followed trail successfully');

INSERT INTO Release_Record VALUES (8001, 1005, TO_DATE('2025-06-20', 'YYYY-MM-DD'), '5.9806° N, 116.0735° E', 'Satellite Tag', 101);
INSERT INTO Release_Record VALUES (8002, 1009, TO_DATE('2025-03-15', 'YYYY-MM-DD'), '5.8765° N, 116.1123° E', 'Radio Collar', 104);
INSERT INTO Release_Record VALUES (8003, 1010, TO_DATE('2025-01-10', 'YYYY-MM-DD'), '6.1234° N, 116.2345° E', 'Satellite Tag', 102);
INSERT INTO Release_Record VALUES (8004, 1001, TO_DATE('2025-07-01', 'YYYY-MM-DD'), '5.7654° N, 116.0567° E', 'Radio Collar', 101);
INSERT INTO Release_Record VALUES (8005, 1003, TO_DATE('2025-04-05', 'YYYY-MM-DD'), '6.0345° N, 116.1789° E', 'Satellite Tag', 102);
INSERT INTO Release_Record VALUES (8006, 1006, TO_DATE('2025-03-01', 'YYYY-MM-DD'), '5.9876° N, 116.1456° E', 'Radio Collar', 104);
INSERT INTO Release_Record VALUES (8007, 1008, TO_DATE('2025-05-15', 'YYYY-MM-DD'), '6.1123° N, 116.0678° E', 'Satellite Tag', 108);
INSERT INTO Release_Record VALUES (8008, 1004, TO_DATE('2025-06-10', 'YYYY-MM-DD'), '5.8567° N, 116.1234° E', 'Radio Collar', 101);

INSERT INTO Staff_Habitat VALUES (101, 1, TO_DATE('2020-01-15', 'YYYY-MM-DD'));
INSERT INTO Staff_Habitat VALUES (101, 3, TO_DATE('2020-01-15', 'YYYY-MM-DD'));
INSERT INTO Staff_Habitat VALUES (102, 2, TO_DATE('2019-05-20', 'YYYY-MM-DD'));
INSERT INTO Staff_Habitat VALUES (102, 7, TO_DATE('2019-05-20', 'YYYY-MM-DD'));
INSERT INTO Staff_Habitat VALUES (103, 3, TO_DATE('2021-03-10', 'YYYY-MM-DD'));
INSERT INTO Staff_Habitat VALUES (103, 5, TO_DATE('2021-03-10', 'YYYY-MM-DD'));
INSERT INTO Staff_Habitat VALUES (104, 4, TO_DATE('2020-11-05', 'YYYY-MM-DD'));
INSERT INTO Staff_Habitat VALUES (104, 8, TO_DATE('2020-11-05', 'YYYY-MM-DD'));
INSERT INTO Staff_Habitat VALUES (105, 5, TO_DATE('2022-02-18', 'YYYY-MM-DD'));
INSERT INTO Staff_Habitat VALUES (105, 2, TO_DATE('2022-02-18', 'YYYY-MM-DD'));
INSERT INTO Staff_Habitat VALUES (106, 6, TO_DATE('2021-07-30', 'YYYY-MM-DD'));
INSERT INTO Staff_Habitat VALUES (106, 1, TO_DATE('2021-07-30', 'YYYY-MM-DD'));
INSERT INTO Staff_Habitat VALUES (107, 7, TO_DATE('2020-09-12', 'YYYY-MM-DD'));
INSERT INTO Staff_Habitat VALUES (107, 3, TO_DATE('2020-09-12', 'YYYY-MM-DD'));
INSERT INTO Staff_Habitat VALUES (108, 8, TO_DATE('2021-04-25', 'YYYY-MM-DD'));
INSERT INTO Staff_Habitat VALUES (108, 4, TO_DATE('2021-04-25', 'YYYY-MM-DD'));

-- View all tables
SELECT * FROM Habitat_Zone;
SELECT * FROM Staff;
SELECT * FROM Animal;
SELECT * FROM Volunteer;
SELECT * FROM Health_Check;
SELECT * FROM Feedback_Log;
SELECT * FROM Enrichment_Log;
SELECT * FROM Release_Record;
SELECT * FROM Staff_Habitat;


-- ===========================
-- 6 USEFUL QUERIES
-- ===========================
--a.Outer‑join query. Purpose & value: Lists every habitat zone and shows which volunteer (if any) is currently assigned, helping management spot unstaffed areas.
SELECT hz.Zone_ID,
       hz.Zone_Name,
       v.Volunteer_ID,
       v.Name AS Volunteer_Name
FROM   Habitat_Zone hz
LEFT JOIN Volunteer v ON hz.Zone_ID = v.Assigned_Zone
ORDER BY hz.Zone_ID;

--b. 4‑table join + GROUP BY. Purpose & value: Shows how often each staff member fed animals in each zone—useful for workload balancing and KPI reviews.
SELECT hz.Zone_Name,
       s.Name AS Staff_Name,
       COUNT(f.Feed_ID) AS Feed_Count
FROM   Feedback_Log f
JOIN   Animal a ON f.Animal_ID = a.Animal_ID
JOIN   Habitat_Zone hz ON a.Zone_ID = hz.Zone_ID
JOIN   Staff s ON f.Staff_ID = s.Staff_ID
GROUP BY hz.Zone_Name, s.Name
ORDER BY hz.Zone_Name, Feed_Count DESC;

--c. String‑pattern + date‑function query. Purpose & value: Finds permanent animals whose species name contains “monkey” and calculates how long (in months) they have been in the sanctuary—helping plan long‑term welfare.
SELECT a.Animal_ID,
       a.Species,
       a.Arrival_Date,
       FLOOR(MONTHS_BETWEEN(SYSDATE, a.Arrival_Date) / 12) AS Years_In_Sanctuary,
       FLOOR(MOD(MONTHS_BETWEEN(SYSDATE, a.Arrival_Date), 12)) AS Months_In_Sanctuary
FROM   Animal a
WHERE  LOWER(a.Species) LIKE '%monkey%'
  AND  a.Status = 'Permanent';

--d. Query using both OR and AND. Purpose & value: Retrieves all feedings where the food was Fruits or Vegetables and the quantity exceeded 1 kg, so nutritionists can review large plant‑based feedings.
SELECT f.Feed_ID,
       a.Species,
       f.Food_Type,
       f.Quantity,
       f.Feed_Date
FROM   Feedback_Log f
JOIN   Animal a ON a.Animal_ID = f.Animal_ID
WHERE (f.Food_Type = 'Fruits' OR f.Food_Type = 'Vegetables')
  AND  TO_NUMBER(REGEXP_SUBSTR(f.Quantity, '^[0-9]+(\.[0-9]+)?')) > 1
ORDER BY f.Feed_Date;

--e. Query with ≥ 2 subqueries. Purpose & value: Identifies animals whose most recent weight is higher than the overall average, helping staff detect individuals needing specialized diets, larger habitats, or health attention.
SELECT a.Animal_ID,
       a.Species,
       hc_latest.Weight AS Latest_Weight_kg
FROM   Animal a
JOIN   (
        SELECT hc1.Animal_ID,
               hc1.Weight
        FROM   Health_Check hc1
        WHERE  hc1.Check_Date = (
                 SELECT MAX(hc2.Check_Date)
                 FROM   Health_Check hc2
                 WHERE  hc2.Animal_ID = hc1.Animal_ID
               )
      ) hc_latest ON hc_latest.Animal_ID = a.Animal_ID
WHERE  hc_latest.Weight >
       (SELECT AVG(Weight) FROM Health_Check);     

--f. Scenario-specific query
--Chosen scenario: “Animals > 1 year with highest number of positive (score ≥ 4) health checks”
--Why useful: Pinpoints long‑term success stories for health studies & release planning.
WITH positive_counts AS (
  SELECT a.Animal_ID,
         a.Species,
         SUM(CASE WHEN h.Score >= 4 THEN 1 ELSE 0 END) AS Pos_Scores
  FROM   Animal a
  JOIN   Health_Check h ON h.Animal_ID = a.Animal_ID
  WHERE  a.Arrival_Date <= ADD_MONTHS(SYSDATE, -12)  -- > 1 year
  GROUP  BY a.Animal_ID, a.Species
), max_pos AS (
  SELECT MAX(Pos_Scores) AS Top_Score
  FROM   positive_counts
)
SELECT pc.Animal_ID,
       pc.Species,
       pc.Pos_Scores
FROM   positive_counts pc
JOIN   max_pos mp ON pc.Pos_Scores = mp.Top_Score
ORDER  BY pc.Pos_Scores DESC;
