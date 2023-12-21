USE CLARITY

IF OBJECT_ID ('tempdb.dbo.#TheWorld') IS NOT NULL DROP TABLE #TheWorld
SELECT DISTINCT 
 ENCOUNTERS.PAT_ENC_CSN_ID Encounter_ID
, ENCOUNTERS.APPT_TIME AS TIME_Date
, ENCOUNTERS.CONTACT_DATE Date
, Encounters.PAT_ENC_DATE_REAL
, ZC_DISP_ENC_TYPE.NAME Visit_Type
, ZC_APPT_STATUS.Name ResultOfAppointment
, Patient.PAT_MRN_ID
, Patient.PAT_NAME
,CLARITY_DEP.SERV_AREA_ID
,CLARITY_DEP.REV_LOC_ID
,CLARITY_DEP.DEPARTMENT_NAME
, Encounters.DEPARTMENT_ID
, REGISTRY_CONFIG.REGISTRY_NAME
, Encounters.Visit_Prov_ID  AS Provider_ID
, Prov.PROV_NAME
, Prov.CLINICIAN_TITLE
INTO #TheWorld
FROM PAT_ENC ENCOUNTERS
 Left Join Patient ON Patient.pat_ID=ENCOUNTERS.PAT_ID 
 Left join PAT_ACTIVE_REG ON PAT_ACTIVE_REG.Pat_ID =Patient.PAT_ID
 Left Join REGISTRY_CONFIG ON REGISTRY_CONFIG.REGISTRY_ID=PAT_ACTIVE_REG.REGISTRY_ID       
  Left join ZC_DISP_ENC_TYPE ON ZC_DISP_ENC_TYPE.DISP_ENC_TYPE_C = Encounters.ENC_TYPE_C 
  Left Join CLARITY_DEP ON CLARITY_DEP.DEPARTMENT_ID=Encounters.DEPARTMENT_ID
 --left jOIN [CLARITY].[dbo].[ARPB_TRANSACTIONS] CPT_Table ON CPT_Table.PAT_ENC_CSN_ID = ENCOUNTERS.PAT_ENC_CSN_ID 
 LEFT OUTER JOIN CLARITY.dbo.CLARITY_SER AS Prov on Prov.PROV_ID=Encounters.Visit_Prov_ID
 Left join PAT_ENC ALL_Encounters On ALL_Encounters.PAT_ID=ENCOUNTERS.PAT_ID
 Left join ZC_DISP_ENC_TYPE All_Cat ON All_Cat.DISP_ENC_TYPE_C = ALL_Encounters.ENC_TYPE_C
 Left join ZC_APPT_STATUS ON ZC_APPT_STATUS.APPT_STATUS_C =ENCOUNTERS.APPT_STATUS_C 
Where ZC_DISP_ENC_TYPE.NAME NOT IN ('Documentation', 'Scanned Document','Travel','History','Wait List','Letter (Out)','Plan of Care Documentation','Patient Message','Orders Only','Clinical Documentation Only')
AND REGISTRY_CONFIG.REGISTRY_NAME like '%ELR BEHAVIORAL HEALTH%'
And CLARITY_DEP.SERV_AREA_ID= '10'
AND ENCOUNTERS.CONTACT_DATE Between '2023/01/01' and '2023/12/19'
   AND ZC_APPT_STATUS.Name NOT IN ('No Show')
	 And ZC_APPT_STATUS.Name  IN ('Completed')
	 And CLARITY_DEP.DEPARTMENT_ID IN ('10101120',
'10120128',
'10402014',
'10503102',
'70107102',
'100000001',
'100001001',
'100002001',
'100003001',
'100004001',
'100005000',
'100006000',
'100007001',
'100009000',
'100010001',
'100011001',
'100012001',
'100018002',
'100019002')
order by Patient.PAT_MRN_ID, Date,   ENCOUNTERS.PAT_ENC_CSN_ID 


Select DEPARTMENT_NAME
,count(Distinct Case when #TheWorld.Date Between '2023/01/01' and '2023/1/31'  then PAT_MRN_ID END) AS [January 2023]
,COUNT(Distinct Case when #TheWorld.Date Between '2023/02/01' and '2023/02/28' then PAT_MRN_ID END) AS [Febuary 2023]
,COUNT(Distinct Case when #TheWorld.Date Between '2023/03/01' and '2023/03/31' then PAT_MRN_ID END) AS [March 2023]
,COUNT(Distinct Case when #TheWorld.Date Between '2023/04/01' and '2023/04/30' then PAT_MRN_ID END) AS [April 2023]
,COUNT(Distinct Case when #TheWorld.Date Between '2023/05/01' and '2023/05/31' then PAT_MRN_ID END) AS [May 2023]
,COUNT(Distinct Case when #TheWorld.Date Between '2023/06/01' and '2023/06/30' then PAT_MRN_ID END) AS [June 2023]
,COUNT(Distinct Case when #TheWorld.Date Between '2023/07/01' and '2023/07/31' then PAT_MRN_ID END) AS [July 2023]
,COUNT(Distinct Case when #TheWorld.Date Between '2023/08/01' and '2023/08/31' then PAT_MRN_ID END) AS [Aug 2023]
,COUNT(Distinct Case when #TheWorld.Date Between '2023/09/01' and '2023/09/30' then PAT_MRN_ID END) AS [Sept 2023]
,COUNT(Distinct Case when #TheWorld.Date Between '2023/10/01' and '2023/10/31' then PAT_MRN_ID END) AS [Oct 2023]
,COUNT(Distinct Case when #TheWorld.Date Between '2023/11/01' and '2023/11/30' then PAT_MRN_ID END) AS [Nov 2023]
,COUNT(Distinct Case when #TheWorld.Date Between '2023/12/01' and '2023/12/31' then PAT_MRN_ID END) AS [Dec 2023]
From #TheWorld
Group by DEPARTMENT_NAME





Select *
From CLARITY_DEP
Where Department_Name Like '%Behavioral%'