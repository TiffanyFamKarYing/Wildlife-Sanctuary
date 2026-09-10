# Rainforest Sabah Haven Wildlife Sanctuary Database

SEG1201: Database Fundamentals — Group Coursework (Group 2_3)
BSc (Hons) Information Technology / Computer Science / Software Engineering / Information Systems (Data Analytics) / Computer Networking and Security
Sunway University, School of Engineering and Technology, Year 1, Academic Session April 2025

## Overview

This project designs and implements a relational database for the **Rainforest Sabah Haven Wildlife Sanctuary**, a fictional wildlife rehabilitation and rescue sanctuary near Kota Kinabalu, Sabah. The sanctuary cares for injured and endangered animals native to Borneo (e.g. clouded leopards, proboscis monkeys, orangutans, pangolins, sun bears, hornbills) from arrival through health monitoring, feeding, enrichment, habitat assignment, and eventual release.

The database tracks the full lifecycle of each animal — rescue, health checks, feeding, enrichment activities, staff and volunteer assignments, and release — enforcing the sanctuary's operational business rules through constraints and triggers.

## Project Structure

| File | Description |
|---|---|
| `2_3_Rainforest_Sabah_Haven_Wildlife_Sanctuary_SEG1201.pdf` | Full coursework report: case scenario, business rules, ERD, constraints, SQL queries with results and justifications, demonstration plan |
| `2_3_Script.sql` | Complete SQL script — table creation, triggers, sample data inserts, and the 6 required queries |

## Database Design

### Entities (9)

| Entity | Purpose |
|---|---|
| `Animal` | Core record of each rescued animal (species, gender, origin, status, arrival date, zone) |
| `Health_Check` | Periodic health assessments (score, weight, temperature, notes) |
| `Staff` | Sanctuary employees (name, role, contact, shift) |
| `Volunteer` | Trained volunteers assigned to a habitat zone |
| `Feedback_Log` | Feeding records (food type, quantity, staff responsible) |
| `Enrichment_Log` | Enrichment activities (foraging, climbing training, etc.) |
| `Release_Record` | Release details for animals returned to the wild |
| `Habitat_Zone` | Sanctuary zones (Wetland Habitat, Forest Canopy, Quarantine Units, Grassland Enclosure, etc.) |
| `Staff_Habitat` | Junction table linking staff to their assigned zone(s) |

### Key Relationships

- One `Animal` → many `Health_Check`, `Feedback_Log`, `Enrichment_Log` records
- One `Animal` → zero or one `Release_Record`
- One `Habitat_Zone` → many `Animal`, `Volunteer`, and `Staff_Habitat` records
- `Staff_Habitat` is a composite-key junction table resolving the many-to-many relationship between `Staff` and `Habitat_Zone`

Full attribute lists, keys (PK/FK/composite), and cardinalities are detailed in the ERD design table in the report.

## Business Rules

1. Every rescued animal must have a health check within 24 hours of arrival.
2. Animals with a health score below 3 cannot be released.
3. A staff member can be assigned to a maximum of 2 habitat zones at a time.
4. Enrichment activities for animals in rehabilitation must be logged at least once every 7 days.
5. Each feeding (`Feedback_Log`) must be recorded within 1 hour of the feeding period.
6. Each volunteer belongs to exactly one habitat zone.
7. Released animals must have GPS coordinates and a responsible staff ID recorded.
8. Animals marked "Released" must have a matching `Release_Record`.
9. Recorded body temperature during health checks must be between 36°C and 39°C.
10. Animals must remain in a medical (quarantine) zone for a minimum of 48 hours.

## Constraints Implemented

- **CHECK constraints**: gender validation, health score range (1–5), temperature range (36–39°C), feed quantity format (numeric + unit), volunteer contact number format, staff shift options
- **UNIQUE constraint**: one release record per animal
- **Triggers** (business logic beyond standard CHECK): release blocked if latest health score < 3, staff limited to 2 zone assignments, enrichment log overdue alert for rehabilitation animals

## SQL Queries

The script implements and documents six required queries:

| Query | Description |
|---|---|
| a. Outer join | Lists all habitat zones with their assigned volunteer (if any), via `LEFT JOIN` |
| b. 4-table join + `GROUP BY` | Feeding log count per staff member per habitat zone |
| c. String pattern + date function | Permanent-status animals with "monkey" in their species name, with time in sanctuary via `MONTHS_BETWEEN` |
| d. `OR` and `AND` | Feeding records where food type is Fruits or Vegetables and quantity exceeds 1 kg |
| e. Subqueries (≥2) | Animals whose latest recorded weight exceeds the average weight across all health checks |
| f. Scenario query | Animals in care over 1 year with the highest number of positive (score ≥ 4) health checks |

## How to Run

1. Open the SQL script in an Oracle SQL environment (e.g. Oracle SQL Developer, Oracle Live SQL, or APEX SQL Commands).
2. Run `2_3_Script.sql` in full — it will:
   - Drop existing tables (if present) to allow a clean re-run
   - Create all 9 tables with constraints
   - Create the 3 business-rule triggers
   - Insert sample data
   - Run `SELECT * FROM ...` statements to view all tables
   - Run the 6 required queries (a–f)
3. Review query results against the justifications in the report.

## Video Presentation

Demonstration video: [https://youtu.be/XWhqQ7aFHv4](https://youtu.be/XWhqQ7aFHv4)

## Group Members

| Student ID | Name |
|---|---|
| 23052301 | Tiffany Fam Kar Ying |
| 23094709 | Tan Wei Ting |
| 23093495 | Tan Wen Xi |
| 23021355 | Angelyn Yek Yin Yin |
| 23094378 | Tang Jia Hui |
| 23056674 | Rachel Tan En Thong |

## Academic Honesty

This project was completed entirely by the group members listed above, in accordance with Sunway University's academic honesty policy, as acknowledged in the submitted report.
