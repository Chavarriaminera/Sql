
/*Midwife, OBGYN, OT, PT, BH all have different blocks and have different specialities*/

--3rd Next available

IF OBJECT_ID ( 'tempdb.dbo.#First' ) IS NOT NULL DROP TABLE #First
Select 
Clarity_Ser.PROV_NAME
,ACCESS_PROV.PROV_ID
,CLARITY_Dep.DEPARTMENT_NAME
,CLARITY_Dep.SPECIALTY
,CLARITY_Dep.DEPARTMENT_ID
,CLARITY_SER.Prov_Type
,Max(ACCESS_PROV.SEARCH_DATE) [Search Date]
,ACCESS_PROV.DAYS_WAIT [Established Patient Days Wait]
INTO #First
FROM ACCESS_PROV
Left join CLARITY_SER On CLARITY_SER.PROV_ID=ACCESS_PROV.PROV_ID
Left Join CLARITY_DEP ON CLARITY_DEP.DEPARTMENT_ID=ACCESS_PROV.DEPARTMENT_ID
Where CONFIG_ID='1170002201' 
--and ACCESS_PROV.PROV_ID='325'
 AND Convert(Date, ACCESS_PROV.SEARCH_DATE) =Convert(Date, Dateadd(DAY, -1, Getdate()))
And CLARITY_SER.Prov_Type IN ( 'Physician', 'Nurse Practitioner', 'Physician Assistant')
AND CLARITY_SER.REFERRAL_SRCE_TYPE = 'Provider'
and CLARITY_DEP.SERV_AREA_ID= '10'
Group By ACCESS_PROV.PROV_ID
,ACCESS_PROV.DEPARTMENT_ID
,ACCESS_PROV.DAYS_WAIT
,Clarity_Ser.PROV_NAME
,CLARITY_Dep.DEPARTMENT_NAME
,CLARITY_SER.Prov_Type
,CLARITY_Dep.DEPARTMENT_ID
,CLARITY_Dep.SPECIALTY

Select *
From #First
Order by PROV_NAME

--Only For medical providers
--1st Available, the min the first new patient comes up we are selecting that first one. 

IF OBJECT_ID ( 'tempdb.dbo.#Second' ) IS NOT NULL DROP TABLE #Second
Select 
Clarity_Ser.PROV_NAME
,ACCESS_PROV.PROV_ID
,CLARITY_Dep.DEPARTMENT_NAME
,CLARITY_Dep.SPECIALTY
,CLARITY_Dep.DEPARTMENT_ID
,CLARITY_SER.Prov_Type
,Max(ACCESS_PROV.SEARCH_DATE) [Search Date New Patient]
,ACCESS_PROV.DAYS_WAIT [New Patient Days Wait]
INTO #Second
FROM ACCESS_PROV
Left join CLARITY_SER On CLARITY_SER.PROV_ID=ACCESS_PROV.PROV_ID
Left Join CLARITY_DEP ON CLARITY_DEP.DEPARTMENT_ID=ACCESS_PROV.DEPARTMENT_ID
Where CONFIG_ID='1170002203' 
--and ACCESS_PROV.PROV_ID='325'
 AND Convert(Date, ACCESS_PROV.SEARCH_DATE) =Convert(Date, Dateadd(DAY, -1, Getdate()))
And CLARITY_SER.Prov_Type IN ( 'Physician', 'Nurse Practitioner','Physician Assistant')
AND CLARITY_SER.REFERRAL_SRCE_TYPE = 'Provider'
and CLARITY_DEP.SERV_AREA_ID= '10'
Group By ACCESS_PROV.PROV_ID
,ACCESS_PROV.DEPARTMENT_ID
,ACCESS_PROV.DAYS_WAIT
,Clarity_Ser.PROV_NAME
,CLARITY_Dep.DEPARTMENT_NAME
,CLARITY_SER.Prov_Type
,CLARITY_Dep.DEPARTMENT_ID
,CLARITY_Dep.SPECIALTY

Select *
From #Second

Select 
 #First.PROV_NAME
,#First.DEPARTMENT_NAME
,#First.SPECIALTY
,#First.PROV_TYPE
,#First.[Search Date]
,#First.[Established Patient Days Wait]
,#Second.[New Patient Days Wait]
From #First
Inner Join #Second On #Second.PROV_ID =#First.PROV_ID And #Second.DEPARTMENT_ID =#First.DEPARTMENT_ID
Where #First.DEPARTMENT_NAME NOT like '%Behavioral%' 
and #First.DEPARTMENT_NAME NOT like'%MidWifery%'
and #First.DEPARTMENT_NAME NOT like'%OB/GYN%'
and #First.DEPARTMENT_NAME NOT like'%Lactation%'
Order By #First.PROV_NAME
