
/* 


MAIN QUESTION:Are BH patients using El rio's other services? 
      BH wants to know who is coming back for visits. 

First Question: Did anyone come back that day or the next day for services?
Second: Did anyone come back 30 days after the visit?
Third: Did anyone come back 60 days? (Later on for the metric)
Forth: Did anyone come back 90 days after the vist (Later on for the metric)

*/


/* This is my population. This population is everyone in the BH Registry after Epic implimentation till now*/

Declare 
@Startdate Date =  DATEADD(MONTH, -12, DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()), 0)),
@EndDate Date = EOMONTH(getdate(), -1)

--SET @Startdate = DATEADD(year, -1, @EndDate)
--SET @EndDate =  EOMONTH(getdate(), -1)

--SELECT DATEADD(m,-1,DATEADD(mm, DATEDIFF(m,0,GETDATE()), 0))


IF OBJECT_ID ('tempdb.dbo.#ThePopulation') IS NOT NULL DROP TABLE #ThePopulation
SELECT DISTINCT 
  ENCOUNTERS.PAT_ID Patient_ID
, ENCOUNTERS.PAT_ENC_CSN_ID Encounter_ID
, ENCOUNTERS.APPT_TIME AS TIME_Date
, format(convert(date, ENCOUNTERS.CONTACT_DATE),'MM/dd/yyyy') Date
, Encounters.PAT_ENC_DATE_REAL
--, ENCOUNTERS.ENC_TYPE_C 
, ZC_DISP_ENC_TYPE.NAME Visit_Type
, ZC_APPT_STATUS.Name ResultOfAppointment
, Patient.PAT_MRN_ID
, Patient.PAT_NAME
, REGISTRY_CONFIG.REGISTRY_NAME
, CPT_Table.CPT_CODE 
--, CPT_Table.SERVICE_DATE D0140D0150_SERVICEDATE
--, CPT_Table.SERV_PROVIDER_ID AS Provider_Who_Performed_Service /* The internal identifier of the provider who performed the medical services on the patient.*/
, Prov.PROV_NAME
, Prov.CLINICIAN_TITLE
, CPT_Table.BILLING_PROV_ID AS Billing_Provider /* The billing provider associated with the transaction.*/
--, ALL_Encounters.CONTACT_DATE ReturningDate
--, ALL_Encounters.CPT_CODE
--,ALL_Encounters.ENC_TYPE_C SecoundAppointment_VisitType
--,All_Cat.NAME
INTO #ThePopulation
FROM PAT_ENC ENCOUNTERS
 Left Join Patient ON Patient.pat_ID=ENCOUNTERS.PAT_ID AND ENCOUNTERS.CONTACT_DATE Between @StartDate AND @EndDate
 Left join PAT_ACTIVE_REG ON PAT_ACTIVE_REG.Pat_ID =Patient.PAT_ID
 Left Join REGISTRY_CONFIG ON REGISTRY_CONFIG.REGISTRY_ID=PAT_ACTIVE_REG.REGISTRY_ID
 --Sep
  Left join ZC_DISP_ENC_TYPE ON ZC_DISP_ENC_TYPE.DISP_ENC_TYPE_C = Encounters.ENC_TYPE_C 
 left jOIN [CLARITY].[dbo].[ARPB_TRANSACTIONS] CPT_Table ON CPT_Table.PAT_ENC_CSN_ID = ENCOUNTERS.PAT_ENC_CSN_ID 
 LEFT OUTER JOIN CLARITY.dbo.CLARITY_SER AS Prov on Prov.PROV_ID=CPT_Table.SERV_PROVIDER_ID
 --World
 Left join PAT_ENC ALL_Encounters On ALL_Encounters.PAT_ID=ENCOUNTERS.PAT_ID
  Left join ZC_DISP_ENC_TYPE All_Cat ON All_Cat.DISP_ENC_TYPE_C = ALL_Encounters.ENC_TYPE_C 

--NOt sure if needed 
 Left join ZC_APPT_STATUS ON ZC_APPT_STATUS.APPT_STATUS_C =ENCOUNTERS.APPT_STATUS_C
 left join PAT_ENC_APPT ON PAT_ENC_APPT.PAT_ENC_CSN_ID=ENCOUNTERS.PAT_ENC_CSN_ID
 where REGISTRY_CONFIG.REGISTRY_NAME like '%ELR BEHAVIORAL HEALTH%'
 And ZC_APPT_STATUS.Name Not In ('No Show', 'CANCELED','Erroneous Encounter')
--AND ALL_Encounters.CONTACT_DATE between ENCOUNTERS.CONTACT_DATE + 1 AND ENCOUNTERS.contact_date + 1
order by Patient.PAT_MRN_ID, Date,   ENCOUNTERS.PAT_ENC_CSN_ID 




/* I am cleaning this so there will not be any duplicates and I am also gathering all the CPT's for that specific encounter*/
IF OBJECT_ID ('tempdb.dbo.#ThePopulationCleaning') IS NOT NULL DROP TABLE #ThePopulationCleaning 
SELECT *, 
    ROW_NUMBER () Over(Partition by #ThePopulation.Encounter_ID,  #ThePopulation.PAT_MRN_ID Order BY #ThePopulation.time_date desc) Ranking  --using time_date because I want the earliest first
    ,STUFF((SELECT ', ' + CPT_CODE  
           FROM #ThePopulation AS t2  
           WHERE t2.PAT_MRN_ID = #ThePopulation.PAT_MRN_ID  AND T2.Encounter_ID=#ThePopulation.Encounter_ID
           FOR XML PATH('')), 1, 2, '') AS ALLCPTS  
INTO #ThePopulationCleaning
FROM #ThePopulation  
ORDER BY PAT_MRN_ID, Date DESC;  

--Select *
--From #ThePopulationCleaning
--ORder by PAT_MRN_ID, TIME_Date


--I am cleaning the table to get rid of any duplicates
IF OBJECT_ID ('tempdb.dbo.#TheWorld') IS NOT NULL DROP TABLE #TheWorld
Select 
 Patient_ID
,Encounter_ID
,TIME_Date
,Date
,PAT_ENC_DATE_REAL
,Visit_Type
,ResultOfAppointment
,PAT_MRN_ID	
,PAT_NAME
,REGISTRY_NAME
,PROV_NAME
,CLINICIAN_TITLE
,Billing_Provider
, ALLCPTS
,Ranking
INTO #TheWorld
From #ThePopulationCleaning
Where Ranking<2
ORDER BY PAT_MRN_ID, Date DESC; 


--This is a table with all the correct encounters for the population. This is the whole population.
IF OBJECT_ID ('tempdb.dbo.#ServicesTheSameDayCleaning') IS NOT NULL DROP TABLE #ServicesTheSameDayCleaning
SELECT 
 Patient_ID
,Encounter_ID
,TIME_Date
,Date
,PAT_ENC_DATE_REAL
,Visit_Type
,ResultOfAppointment
,PAT_MRN_ID
,PAT_NAME
,REGISTRY_NAME
,PROV_NAME
,CLINICIAN_TITLE
,Billing_Provider
,Ranking
,ALLCPTS
,ROW_NUMBER() OVER(PARTITION BY Date,Pat_MRN_ID  ORDER BY Date,PAT_MRN_Id) as ORGANIZE --I am trying to flag if the patient has came back the same day or not. I just want the groups 
INTO #ServicesTheSameDayCleaning
FROM #TheWorld  
Order by Pat_MRN_ID, Date DESC

--Select *
--From #ServicesTheSameDayCleaning
--Order by Pat_MRN_ID, Date DESC

--Select count (Distinct Encounter_ID)
--From #ServicesTheSameDayCleaning


/*Here I am just wanting the same day appointsment and the group ones. I do not want the single appointments. So that is where I do the inner query
I am flaging them if they are or are not. Then I am doing the outer query to only catpure the same day. Is the the population of people who came back for the same day This is for CPT */
IF OBJECT_ID ('tempdb.dbo.#ServicesTheSameDay') IS NOT NULL DROP TABLE #ServicesTheSameDay
Select *
INTO #ServicesTheSameDay
From 
(
SELECT *,   
  CASE WHEN (    
    SELECT COUNT(*)     
    FROM #ServicesTheSameDayCleaning     
    WHERE Pat_MRN_ID = t.Pat_MRN_ID AND Date = t.Date    
  ) > 1 THEN 'Yes'    
  ELSE 'Not Same Day Service'    
  END AS SameDayService 
FROM #ServicesTheSameDayCleaning t
) Cleaning 
Where SameDayService ='Yes'
Order BY PAT_MRN_ID, TIME_Date,  PAT_ENC_DATE_REAL asc
 

 --Select top 30 *
 --From #ServicesTheSameDay
 --Order BY PAT_MRN_ID, TIME_Date, ORGANIZE, PAT_ENC_DATE_REAL asc

 --Here I am gathering all the visits for the same day and putting them in a group. 
IF OBJECT_ID ('tempdb.dbo.#List') IS NOT NULL DROP TABLE #List
 Select *
 , STUFF ((SELECT ', ' + Visit_Type 
          From #ServicesTheSameDay AS T2
		  Where T2.PAT_MRN_ID=#ServicesTheSameDay.PAT_MRN_ID AND T2.Date=#ServicesTheSameDay.Date
		  FOR XML Path ('')), 1,2, '') AS ALL_Visits
INTO #List
From #ServicesTheSameDay 
Order by Pat_MRN_ID, TIME_Date 


--Select* 
--From #List
--Where PAT_MRN_ID='000000001100'
--Order by Pat_MRN_ID, TIME_Date 



/*Here I just want the All-Visits variable. For example,i only want the first one in the group and not the detailed version. I just want to show the date and all the visits they had. 
This is why I used the inner query to show the duplicates. See they are not duplicate visits the visits did happen but this is a more granular view. I just want it 
to summarize the date of the enoutner and the visits that happened that day. This is where I use the inner query to flag the dups and use the otter query to get rid of those. */
IF OBJECT_ID ('tempdb.dbo.#Visits') IS NOT NULL DROP TABLE #Visits;  
SELECT *  
INTO #Visits  
FROM   
(  
  SELECT *,  
    CASE   
      WHEN (  
        SELECT COUNT(*)       
        FROM #List      
        WHERE Pat_MRN_ID = t.Pat_MRN_ID AND Date = t.Date      
      ) > 1 THEN 'Yes'      
      ELSE 'Not Duplicate'      
    END AS DuplicateVisits      
  FROM #List t  
) AS CV  
WHERE SameDayService ='Yes'  
AND Organize =1
ORDER BY PAT_MRN_ID, TIME_Date, PAT_ENC_DATE_REAL ASC;  

 
--Select *
--From #Visits
--Where PAT_MRN_ID='000000001100'
--ORDER BY PAT_MRN_ID, TIME_Date
 
-- Select *
-- From  #Visits
-- ORDER BY PAT_MRN_ID, TIME_Date 

 ------------------------------------------Analysis------------------------------------------

 --Total Encounters
Select count (Distinct Encounter_ID) AS Total_Encounters
From #ServicesTheSameDayCleaning


--Total Encounters Same Day
Select count (Distinct Encounter_ID) AS Total_Encounters_Same_Day
From #ServicesTheSameDay

--Total Patients
Select count (Distinct PAT_MRN_ID) AS Total_Patients
From #ServicesTheSameDayCleaning

--Total Patients Same Day
Select count (Distinct  PAT_MRN_ID)  AS Total_Patients_Same_Day
From #ServicesTheSameDay


----Total Visite Type Counts
 Select Visit_type, Count(Visit_type) AS Totals
From #ServicesTheSameDay
Group by Visit_Type
Order By Totals desc

--Top Visit Combinations
Select TOP 26
All_Visits,
Count(All_visits) AS Totals
From #List
Group by All_Visits With Rollup
Order By Totals desc


-------------------------------------Excel Tables


--Visits Table Detailed List
 Select Pat_name
 ,PAT_MRN_ID
 ,Encounter_ID
 ,Date
 ,TIME_Date
 ,Visit_Type
 ,ResultOfAppointment
 ,PROV_NAME
 ,CLINICIAN_TITLE
From #List
 ORDER BY PAT_MRN_ID, TIME_Date 

 --Visits Table 
 Select Pat_name AS 'Patient Name'
 ,PAT_MRN_ID   
 ,Date
,ALL_Visits
From #Visits
 ORDER BY PAT_MRN_ID, TIME_Date











--LEFT JOIN #TheWorld CameBack   
--    ON CameBack.PAT_MRN_ID = #TheWorld.PAT_MRN_ID  
--    AND CameBack.Date BETWEEN DATEADD(day, -1, #TheWorld.Date) AND DATEADD(day, 1, #TheWorld.Date) 

--IF OBJECT_ID ('tempdb.dbo.#CameBackTheNextDay') IS NOT NULL DROP TABLE #CameBackTheNextDay
--SELECT DISTINCT 
--  ENCOUNTERS.PAT_ID Patient_ID
--, ENCOUNTERS.PAT_ENC_CSN_ID Encounter_ID
--, format(convert(date, ENCOUNTERS.CONTACT_DATE),'MM/dd/yyyy') FirstAppointment
--, Encounters.PAT_ENC_DATE_REAL
----, ENCOUNTERS.Appt_prc_id
----, ENCOUNTERS.APPT_STATUS_C
--, ENCOUNTERS.ENC_TYPE_C 
--, ZC_DISP_ENC_TYPE.NAME FirstAppointment_VisitType
--, ZC_APPT_STATUS.Name ResultOfAppointment
--, Patient.PAT_MRN_ID
--, Patient.PAT_NAME
--, REGISTRY_CONFIG.REGISTRY_NAME
----, CPT_Table.CPT_CODE First_Appointment_CPT
----, CPT_Table.SERVICE_DATE D0140D0150_SERVICEDATE
----, CPT_Table.SERV_PROVIDER_ID AS Provider_Who_Performed_Service /* The internal identifier of the provider who performed the medical services on the patient.*/
--, Prov.PROV_NAME
--, CPT_Table.BILLING_PROV_ID AS Billing_Provider /* The billing provider associated with the transaction.*/
--, ALL_Encounters.CONTACT_DATE ReturningDate
----, ALL_Encounters.CPT_CODE
--,ALL_Encounters.ENC_TYPE_C SecoundAppointment_VisitType
--,All_Cat.NAME
--INTO #CameBackTheNextDay
--FROM PAT_ENC ENCOUNTERS
-- Left Join Patient ON Patient.pat_ID=ENCOUNTERS.PAT_ID AND ENCOUNTERS.CONTACT_DATE >'2021/11/01'
-- Left join PAT_ACTIVE_REG ON PAT_ACTIVE_REG.Pat_ID =Patient.PAT_ID
-- Left Join REGISTRY_CONFIG ON REGISTRY_CONFIG.REGISTRY_ID=PAT_ACTIVE_REG.REGISTRY_ID

--  Left join ZC_DISP_ENC_TYPE ON ZC_DISP_ENC_TYPE.DISP_ENC_TYPE_C = Encounters.ENC_TYPE_C 
-- left jOIN [CLARITY].[dbo].[ARPB_TRANSACTIONS] CPT_Table ON CPT_Table.PAT_ENC_CSN_ID = ENCOUNTERS.PAT_ENC_CSN_ID 
-- LEFT OUTER JOIN CLARITY.dbo.CLARITY_SER AS Prov on Prov.PROV_ID=CPT_Table.SERV_PROVIDER_ID
-- --World
-- Left join PAT_ENC ALL_Encounters On ALL_Encounters.PAT_ID=ENCOUNTERS.PAT_ID
--  Left join ZC_DISP_ENC_TYPE All_Cat ON All_Cat.DISP_ENC_TYPE_C = ALL_Encounters.ENC_TYPE_C 

----NOt sure if needed 
-- Left join ZC_APPT_STATUS ON ZC_APPT_STATUS.APPT_STATUS_C =ENCOUNTERS.APPT_STATUS_C
-- left join PAT_ENC_APPT ON PAT_ENC_APPT.PAT_ENC_CSN_ID=ENCOUNTERS.PAT_ENC_CSN_ID
-- where REGISTRY_CONFIG.REGISTRY_NAME like '%ELR BEHAVIORAL HEALTH%'
-- And ZC_APPT_STATUS.Name Not In ('No Show', 'CANCELED','Erroneous Encounter')
--AND ALL_Encounters.CONTACT_DATE between ENCOUNTERS.CONTACT_DATE + 1 AND ENCOUNTERS.contact_date + 1
--order by Patient.PAT_MRN_ID,Encounters.PAT_ENC_DATE_REAL desc, FirstAppointment,   ENCOUNTERS.PAT_ENC_CSN_ID 

--Select  *
--From #CameBackTheNextDay