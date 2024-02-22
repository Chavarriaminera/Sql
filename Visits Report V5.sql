---- Drop the temp table if it exists
IF OBJECT_ID('tempdb..#dates') IS NOT NULL DROP TABLE #dates;
 
-- Create a temporary table
CREATE TABLE #dates (
    start_date DATETime, 
    end_date  DATETime
);    
 
-- Populating the temporary table
INSERT INTO #dates (start_date, end_date)          
VALUES    
('2023-11-27 00:00:00.000', '2023-12-01 00:00:00.000'),        
('2023-12-04 00:00:00.000', '2023-12-08 00:00:00.000'),        
('2023-12-11 00:00:00.000', '2023-12-15 00:00:00.000'),        
('2024-01-02 00:00:00.000', '2024-01-05 00:00:00.000'),        
('2024-01-08 00:00:00.000', '2024-01-12 00:00:00.000'),        
('2024-01-15 00:00:00.000', '2024-01-19 00:00:00.000'),        
('2024-01-23 00:00:00.000', '2024-01-26 00:00:00.000'),        
('2024-01-29 00:00:00.000', '2024-02-02 00:00:00.000'),        
('2024-02-05 00:00:00.000', '2024-02-09 00:00:00.000');    
 
-- Prepare and execute the dynamic SQL
DECLARE @SQL NVARCHAR(MAX);    
SET @SQL = N'    

Select *
From (

SELECT  
    Subquery.Start_date as [Start Date],
	Subquery.PAT_ENC_CSN_ID,
	Subquery.End_date as [End Date],
    Subquery.[Revenue Location],  
    Subquery.[Department Name],
    Subquery.[Provider Name],    
    Subquery.Prov_Type,  
	Subquery.Week
    --Count (Distinct PAT_ENC_CSN_ID) AS [Total Encounters]  
	


FROM (    
    SELECT    
	 d.start_date ,
	 d.end_date,
	  CASE   
        WHEN d.start_date = ''2023-11-27'' AND d.end_date = ''2023-12-01'' THEN ''Week 1''  
        WHEN d.start_date = ''2023-12-04'' AND d.end_date = ''2023-12-08'' THEN ''Week 2''  
        WHEN d.start_date = ''2023-12-11'' AND d.end_date = ''2023-12-15'' THEN ''Week 3''  
        WHEN d.start_date = ''2024-01-02'' AND d.end_date = ''2024-01-05'' THEN ''Week 4''  
        WHEN d.start_date = ''2024-01-08'' AND d.end_date = ''2024-01-12'' THEN ''Week 5''  
        WHEN d.start_date = ''2024-01-15'' AND d.end_date = ''2024-01-19'' THEN ''Week 6''  
        WHEN d.start_date = ''2024-01-23'' AND d.end_date = ''2024-01-26'' THEN ''Week 7''  
        WHEN d.start_date = ''2024-01-29'' AND d.end_date = ''2024-02-02'' THEN ''Week 8''  
        WHEN d.start_date = ''2024-02-05'' AND d.end_date = ''2024-02-09'' THEN ''Week 9''  
    END AS Week, 
        CLARITY_DEP.REV_LOC_ID,    
        CLARITY_DEP.DEPARTMENT_NAME [Department Name],    
        CASE    
            WHEN REV_LOC_ID = ''100018'' THEN ''ELR Abrams''    
            WHEN REV_LOC_ID = ''100004'' THEN ''ELR Grant and Dodge''    
        END AS [Revenue Location],    
        F_SCHED_APPT.PAT_ENC_CSN_ID,    
       -- F_SCHED_APPT.PAT_ID,    
        CLARITY_SER.PROV_NAME [Provider Name],    
        CLARITY_SER.Prov_Type,    
        F_SCHED_APPT.Contact_date    
        --F_SCHED_APPT.APPT_DTTM    
        --ZC_APPT_STATUS.NAME    
From F_SCHED_APPT
Inner Join PAT_ENC ON F_SCHED_APPT.Pat_enc_csn_ID=PAT_ENC.PAT_ENC_CSN_ID
Inner Join CLARITY_DEP ON CLARITY_DEP.DEPARTMENT_ID = F_SCHED_APPT.DEPARTMENT_ID               --Categorical Department name
Inner Join CLARITY_SER_3 On F_SCHED_APPT.Prov_ID=Clarity_Ser_3.Prov_id 
Inner Join CLARITY_SER ON Clarity_Ser_3.Prov_id =Clarity_Ser.Prov_id 
Inner Join PATIENT ON Patient.PAT_ID= F_SCHED_APPT.PAT_ID
Left Join ARPB_VISITS on ARPB_VISITS.PAT_ID=F_SCHED_APPT.PAT_ID
Left Join ZC_DISP_ENC_TYPE  ON PAT_ENC.ENC_TYPE_C =ZC_DISP_ENC_TYPE.DISP_ENC_TYPE_C
Left Join ZC_APPT_STATUS ON F_SCHED_APPT.APPT_STATUS_C= ZC_APPT_STATUS.APPT_STATUS_C
left Join CLARITY_SER_DEPT	ON CLARITY_SER_DEPT.PROV_ID= F_SCHED_APPT.PROV_ID	
JOIN #dates d ON CONVERT(DATETIME, CONVERT(VARCHAR(20), F_SCHED_APPT.APPT_DTTM, 101)) >= d.start_date AND CONVERT(DATETIME, CONVERT(VARCHAR(20), F_SCHED_APPT.APPT_DTTM, 101)) <= d.end_date
WHERE
CLARITY_SER.Prov_Type IN (''Physician'', ''Nurse Practitioner'')
AND F_SCHED_APPT.Appt_Status_C = ''2''
AND CLARITY_SER.REFERRAL_SRCE_TYPE = ''Provider''
AND PRC_ID NOT IN (''1012'', ''2008'', ''237'', ''1015'', ''1023'', ''1999'', ''284'')
AND CLARITY_DEP.REV_LOC_ID IN (''100018'', ''100004'')
GROUP BY Prov_name,  REV_LOC_ID, Prov_Type, Department_Name, F_SCHED_APPT.PAT_ENC_CSN_ID,F_SCHED_APPT.Contact_date, d.start_date, D.End_Date,F_SCHED_APPT.PAT_ENC_CSN_ID
) Subquery

GROUP BY [Provider Name], [Revenue Location], Prov_Type, [Department Name], Subquery.Start_date, Subquery.end_date, Week,Subquery.PAT_ENC_CSN_ID
) SecondSubquery 
PIVOT ( count (SecondSubquery.PAT_ENC_CSN_ID) For SecondSubquery.Week IN ( [Week 1],[Week 2],[Week 3],[Week 4],[Week 5],[Week 6],[Week 7],[Week 8],[Week 9]) ) As PivotTable

--GROUP BY [Provider Name]
ORDER BY [Start Date], [Provider Name]
--, SecondSubquery.[Revenue Location], SecondSubquery.[Provider Name],SecondSubquery.start_date, SecondSubquery.end_date'
 
-- Execute the dynamic SQL
EXEC sp_executesql @SQL;