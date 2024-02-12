-----------------------------------------------CREATE NECESSARY TABLES-----------------------------------------


CREATE TABLE DimEmployee (
    EmployeeID INT PRIMARY KEY,
    FirstName VARCHAR(50),
    LastName VARCHAR(50),
    Gender CHAR(1),
    DOB DATE,
    DOJ DATE,
    Address VARCHAR(255),
    Phone VARCHAR(20)
);



INSERT INTO DimEmployee
VALUES
    (1, 'John', 'Doe', 'M', '1990-05-15', '2021-01-10', '123 Main St, Cityville', '555-1234'),
    (2, 'Jane', 'Smith', 'F', '1985-08-22', '2020-03-05', '456 Oak St, Townsville', '555-5678'),
    (3, 'Tom', 'Johnson', 'M', '1992-11-30', '2022-02-20', '789 Pine St, Villageland', '555-9876'),
    (4, 'Alice', 'Brown', 'F', '1988-04-18', '2019-07-15', '101 Cedar St, Hamletville', '555-4321'),
    (5, 'Bob', 'White', 'M', '1995-06-25', '2023-04-01', '202 Maple St, Countryside', '555-8765');




CREATE TABLE StagingEmployee (
    EmployeeID INT PRIMARY KEY,
    FirstName VARCHAR(50),
    LastName VARCHAR(50),
    Gender CHAR(1),
    DOB DATE,
    DOJ DATE,
    Address VARCHAR(255),
    Phone VARCHAR(20)
);




INSERT INTO StagingEmployee (EmployeeID, FirstName, LastName, Gender, DOB, DOJ, Address, Phone)
VALUES
    (3, 'Tom', 'Johnson', 'M', '1992-11-30', '2022-02-20', '456 Pine St, Villageland', '555-9876'),
    (4, 'Alice', 'Brown', 'F', '1988-04-18', '2019-07-15', '102 Cedar St, Hamletville', '555-4321'),
    (6, 'Eva', 'Davis', 'F', '1998-09-12', '2023-10-15', '303 Elm St, Suburbia', '555-2468');




CREATE TABLE EmployeeDesignation (
    employee_id INT,
    designation VARCHAR(100),
    start_date DATE,
    end_date DATE
);



INSERT INTO EmployeeDesignation 
VALUES
    (1, 'SQL Developer', '2021-04-01', '2022-04-30'),
    (1, 'Data Analyst', '2022-05-01', '9999-12-31'), 
    (2, 'BI Developer', '2021-02-15', '2022-03-31'),
    (2, 'BI Consultant', '2022-04-01', '9999-12-31'), 
    (3, 'Data Analyst', '2023-03-10', '2023-09-30'),
    (3, 'Data Engineer', '2023-10-01', '9999-12-31');



CREATE TABLE EmployeeDesignationStaging
 (
    employee_id INT,
    designation VARCHAR(100),
    start_date DATE,
    end_date DATE
);



INSERT INTO EmployeeDesignationStaging 
VALUES
    (2, 'Big Data Engineer', '2024-01-01', '9999-12-31'),
    (4, 'Data Analyst', '2024-01-01', '9999-12-31'),
    (1, 'Azure Data Engineer', '2024-01-01', '9999-12-31');



--------------------------------------------IMPLEMENTATION------------------------------------------------------

-------***********SCD TYPE 1*********---------------


--Implemenation Of SCD Type 1
--Code is written in MSFT SQL Server
/*First Approach 
1.Update 
2.Insert new records
*/
--Update the changes for existing employee
UPDATE DimEmployee
SET Address = s.Address
FROM StagingEmployee s
WHERE DimEmployee.EmployeeID = s.EmployeeID;

-- INSERT the new employee
-- `NOT EXISTS` clause ensures that only those records are inserted 
-- which are not present in DimEmployee
INSERT INTO DimEmployee
SELECT *
FROM StagingEmployee s
WHERE NOT EXISTS (
    SELECT *
    FROM DimEmployee c
    WHERE c.EmployeeID = s.EmployeeID
);

/*
Second Approach 
Use MERGE to perform tha update and insert at same time . 
*/

MERGE DimEmployee AS tgt
USING (SELECT * FROM StagingEmployee) AS src
ON tgt.EmployeeID = src.EmployeeID
WHEN MATCHED THEN
    UPDATE SET
        tgt.Address = src.Address      

WHEN NOT MATCHED THEN
    INSERT VALUES
        (src.EmployeeID,
         src.FirstName,
         src.LastName,
         src.Gender,
   src.DOB,
   src.DOJ,
   src.Address,
   src.Phone);

/*
MERGE is more efficient than the first approach because it combines
both operations into a single transaction.
The MERGE statement ensures that both update and insert operations are
either fully completed or fully rolled back, maintaining data integrity
throughout the process. This makes MERGE a more robust and reliable choice
for managing Slowly Changing Dimensions (SCD) Type 1 scenarios.

In the first approach, the UPDATE and INSERT operations are executed in
two separate transactions. This can lead to potential inconsistencies if,
for any reason, the second operation fails after the first one has already
been committed.
*/


-------**********SCD TYPE 2*************------------


--UPDATE the end_date to mark the existing row as older version.
--A higher end_date like '9999-12-31' represents the current version.
UPDATE ed
SET end_date = DATEADD(DAY, -1, eds.start_date)
FROM EmployeeDesignation ed
INNER JOIN EmployeeDesignationStaging eds ON ed.employee_id = eds.employee_id
WHERE ed.end_date = '9999-12-31';

--Insert new designations from staging
INSERT INTO EmployeeDesignation 
SELECT * FROM EmployeeDesignationStaging;

--Let's create a Stored Procedure and encapsulate both UPDATE and INSERT
--in it.
--The stored procedure will ensure that both statments are executed as a whole
--and not as a individual transaction.

CREATE PROCEDURE sp_SCD_Type_2_Implementation
AS
BEGIN
    -- Update existing designations
    UPDATE ed
    SET end_date = DATEADD(DAY, -1, eds.start_date)
    FROM EmployeeDesignation ed
    INNER JOIN EmployeeDesignationStaging eds ON ed.employee_id = eds.employee_id
    WHERE ed.end_date = '9999-12-31';

    -- Insert new designations from staging
    INSERT INTO EmployeeDesignation 
    SELECT * FROM EmployeeDesignationStaging;
END;
