--Creation of Database
USE master;
GO
CREATE DATABASE CrimeProfiler

--Creation of Schema's
CREATE SCHEMA Crimes;

--Table Creation

--1. Creation of GreaterManchester's crime table
SELECT *
INTO Crimes.GreaterManchester
FROM (SELECT * FROM [dbo].[2017-01-greater-manchester]
UNION ALL SELECT * FROM [dbo].[2017-02-greater-manchester] 
UNION ALL SELECT * FROM [dbo].[2017-03-greater-manchester]
UNION ALL SELECT * FROM [dbo].[2017-04-greater-manchester]
UNION ALL SELECT * FROM [dbo].[2017-05-greater-manchester]
UNION ALL SELECT * FROM [dbo].[2017-06-greater-manchester]
UNION ALL SELECT * FROM [dbo].[2017-07-greater-manchester]
UNION ALL SELECT * FROM [dbo].[2017-08-greater-manchester]
UNION ALL SELECT * FROM [dbo].[2017-09-greater-manchester]
UNION ALL SELECT * FROM [dbo].[2017-10-greater-manchester]
UNION ALL SELECT * FROM [dbo].[2017-11-greater-manchester]
UNION ALL SELECT * FROM [dbo].[2017-12-greater-manchester]
UNION ALL SELECT * FROM [dbo].[2018-01-greater-manchester]
UNION ALL SELECT * FROM [dbo].[2018-02-greater-manchester]
UNION ALL SELECT * FROM [dbo].[2018-03-greater-manchester]
UNION ALL SELECT * FROM [dbo].[2018-04-greater-manchester]
UNION ALL SELECT * FROM [dbo].[2018-05-greater-manchester]
UNION ALL SELECT * FROM [dbo].[2018-06-greater-manchester]
UNION ALL SELECT * FROM [dbo].[2018-07-greater-manchester]
UNION ALL SELECT * FROM [dbo].[2018-08-greater-manchester]
UNION ALL SELECT * FROM [dbo].[2018-09-greater-manchester]
UNION ALL SELECT * FROM [dbo].[2018-10-greater-manchester]
UNION ALL SELECT * FROM [dbo].[2018-11-greater-manchester]
UNION ALL SELECT * FROM [dbo].[2018-12-greater-manchester]) as Tmp


--2. Creation of LSOA population table
SELECT [Area Codes],[LSOA] AS 'Area Name',[All Ages] AS 'Population'
INTO Crimes.LSAO_Population
FROM [dbo].[LSOA];


--3. Creation of crime data, Greater Manchesster Profiler by joining the Greater Manchester crime table and the LSAO population table
SELECT * 
INTO Crimes.GreaterManchesterProfiler
FROM Crimes.GreaterManchester GM LEFT JOIN Crimes.LSAO_Population LP ON GM.[LSOA code]=LP.[Area Codes]


--Adding a Primary key column to Crimes.GreaterManchester table
ALTER TABLE Crimes.GreaterManchesterProfiler
ADD ID INT IDENTITY;

ALTER TABLE Crimes.GreaterManchesterProfiler
ADD CONSTRAINT PK_Id PRIMARY KEY NONCLUSTERED (ID);
GO

--Adding a new column where we will store the geography points

ALTER TABLE Crimes.GreaterManchesterProfiler
ADD [GeoLocation] GEOGRAPHY


--Creating a geography POINT using Latitude and Longitude columns

UPDATE Crimes.GreaterManchesterProfiler
SET [GeoLocation] = geography::Point(Latitude, Longitude, 4326)
WHERE [Longitude] IS NOT NULL
AND [Latitude] IS NOT NULL
AND CAST(Latitude AS decimal(10, 6)) BETWEEN -90 AND 90
AND CAST(Longitude AS decimal(10, 6)) BETWEEN -90 AND 90


--Creation of Reports with Views

--1a. Grouping crimes by LSOA Names for comparison
CREATE VIEW Crimes.LSOAPopulationCrimeReview
AS
SELECT DISTINCT substring([lsoa Name],1, (len([lsoa name])-5)) LSOA_Name, [Population], COUNT([Crime ID]) [Number of Crimes]
FROM Crimes.GreaterManchesterProfiler
GROUP BY substring([lsoa Name],1, (len([lsoa name])-5)),[Population];

--1b. Comparing the rate of crime with population in each LSOA areas
CREATE VIEW Crimes.CompareCrimesandPopulation
AS
SELECT [lsoa_name], SUM([Population]) [Population],SUM([Number of Crimes]) [Number of Crimes]
FROM Crimes.LSOAPopulationCrimeReview
WHERE [lsoa_name] IS NOT NULL AND [lsoa_name] NOT LIKE 'WIGAN%%'
GROUP BY[LSOA_Name]



--2. A view that contains other information used for the Greater Manchester wise report
CREATE VIEW Crimes.GreaterManchesterCrimeProfilerReport
AS
SELECT SUBSTRING([LSOA name],1, (len([LSOA name])-5)) [LSOA name],[Crime type], [Last outcome category], COUNT([Crime type]) Total, SUM ([Population]) [Population]
FROM Crimes.GreaterManchesterProfiler
WHERE [Crime type] IS NOT NULL
GROUP BY SUBSTRING([LSOA name],1, (len([LSOA name])-5)),[Crime type], [Last outcome category];

--3. A report on the frequency of each crime type in Greater Manchester
CREATE VIEW Crimes.AllCrimeTypes
AS
SELECT DISTINCT [Crime type], SUM([Total]) 'Total'
FROM Crimes.GreaterManchesterCrimeProfilerReport
GROUP BY [Crime type]


--4. Comparing the crimes that the offender's were sent to prison with regards to Area Names and Population
CREATE VIEW Crimes.CompareOffenderImprisoned
AS
SELECT [LSOA name], sum([Total]) [Occurences]
FROM Crimes.GreaterManchesterCrimeProfilerReport
WHERE [Last outcome category] = 'Offender sent to prison'
GROUP BY [LSOA name]

--5. Comparing the Burglary and Criminal damage and arson crimes in Greater Manchester
CREATE VIEW Crimes.BulgaryandCriminalDamage
AS
SELECT [LSOA name], [Crime type], sum([Total]) Total
FROM Crimes.GreaterManchesterCrimeProfilerReport
WHERE [Crime type]  = 'burglary' OR [Crime type]  = 'Criminal damage and arson'
GROUP BY [LSOA name], [Crime type] 


--6. Reported Crimes that were not dealt with
CREATE VIEW Crimes.NegativeOutcomes
AS
SELECT [Last outcome category],COUNT(*) Total
FROM Crimes.GreaterManchesterCrimeProfilerReport
WHERE [Last outcome category] IS NULL OR [Last outcome category] ='Unable to prosecute suspect' OR[Last outcome category]='Further investigation is not in the public interest' OR [Last outcome category]='Court case unable to proceed' OR [Last outcome category]='Status update unavailable' OR [Last outcome category]='Investigation complete; no suspect identified' OR [Last outcome category]='Formal action is not in the public interest' OR [Last outcome category]='Formal action is not in the public interest'
GROUP BY [Last outcome category];


--7. Vehicle Crimes View: A view that shows the Vehicle Crimes in Greater Manchester
CREATE VIEW Crimes.VehicleCrimes
AS
SELECT *
FROM Crimes.GreaterManchesterProfiler
WHERE [Crime type] = 'Vehicle crime'
AND GeoLocation IS NOT NULL;


--8. Anti-Social Behavior Crimes in Salford View: A view that shows the Anti-Social Behavior Crimes in Salford  
CREATE VIEW Crimes.Salford_Anti_Social_Behaviour
AS
SELECT *
FROM Crimes.GreaterManchesterProfiler
WHERE [Crime type] = 'Anti-social behaviour' AND [LSOA name] LIKE '%salford%' AND GeoLocation IS NOT NULL;


--9.Public Order Crimes in Rochdale View: A view that shows the public order crime in Rochdale  
CREATE VIEW Crimes.[Rochdale_PublicOrder]
AS
SELECT *
FROM Crimes.GreaterManchesterProfiler
WHERE [Crime type] = 'Public order' AND [LSOA name] LIKE '%Rochdale%' AND GeoLocation IS NOT NULL;

--10.Violence and sexual offences Crimes in Oldham View: A view that shows the Violence and sexual offences Crimes in Oldham  
CREATE VIEW Crimes.[Oldham_Violence_and_sexual_offences]
AS
SELECT *
FROM Crimes.GreaterManchesterProfiler
WHERE [Crime type] = 'Violence and sexual offences' AND [LSOA name] LIKE '%Oldham%' AND GeoLocation IS NOT NULL;


--STORED PROCEDURE

--A Stored Procedure that reveals the frequency of outcome category for any Crime Type in ascending order
CREATE PROC Crimes.Type_OutcomeFrequency @crimetype NVARCHAR(50)
AS
SELECT [Last outcome category],COUNT(*) Frequency
FROM Crimes.GreaterManchesterProfiler
WHERE [Crime type] LIKE @crimetype
GROUP BY [Last outcome category]
ORDER BY Frequency ASC;


--Excecuting the created stored procedure Crimes.Type_OutcomeFrequency for the vehicle crime
EXEC Crimes.Type_OutcomeFrequency [vehicle crime]

--FUNCTION

--A Table Function that shows the grouped outcome frequency breakdown for any LSOA Area Name
CREATE FUNCTION Crimes.LSOA_CrimeOutcome_Area (@LSOA NVARCHAR(200))
RETURNS TABLE AS
RETURN(
SELECT [Crime type],[Last outcome category], count(*) 'Total'
FROM Crimes.GreaterManchesterProfiler
WHERE substring([lsoa Name],1, (len([lsoa name])-5)) = @LSOA
GROUP BY [Crime type], [Last outcome category]);


 --TRIGGER

--Making a Trigger that prevents deletion of row from the Greater Manchester Profiler Table
CREATE TRIGGER Crimes.Prevent_Delete ON [Crimes].[GreaterManchesterProfiler]
INSTEAD OF DELETE
AS
IF EXISTS (SELECT * FROM [Crimes].[GreaterManchesterProfiler])
DECLARE @ErrorMessage NVARCHAR(200)
SELECT	@ErrorMessage = 'A primary key is in this table'
BEGIN
RAISERROR( @ErrorMessage, 16, 1 )
ROLLBACK TRANSACTION
END;
GO


