/*
 Report Requester: Vanessa Seaney & Cynthia Gonzales
 Scope of Ask: Delivery of substance use disorder services. They want the number of encounters for the following CPT and HCPC codes 
 which align with the diagnosis codes for patients diagnosed with substance use disorder. Specifically, how many patients with the diagnosis codes 
 listed had services delivered in 2022 per the CPT and HCPC codes listed.

CPT Codes
90832
90834
90837

HCPC Codes
H0004
H0015

Diagnosis Codes 
Alcohol use disorder—F10.90
Stimulant use disorder—F15.90
Opioid use disorder—F11.90
Sedative/hypnotic use disorder (severe, dependence)—F13.20 

*/


IF OBJECT_ID('tempdb.dbo.#EncounterTable') IS NOT NULL Drop Table #EncounterTable
Select 
  Distinct EncounterTable.PAT_ENC_CSN_ID  EncounterID
, Patient.PAT_NAME AS PatientName
, EncounterTable.CONTACT_DATE
, Diagnosis.DX_ID
, DiagnosisName.DIAGNOSIS_CODE
, DiagnosisName.DIAGNOSIS_DISPLAY_NAME
, CPT_Table.CPT_Code
INTO #EncounterTable
From PAT_ENC AS EncounterTable
INNER JOIN Patient on Patient.Pat_ID=EncounterTable.Pat_ID
INNER JOIN V_DIAGNOSIS_INFO	AS Diagnosis on Diagnosis.Pat_ID=EncounterTable.Pat_ID
INNER JOIN  V_CUBE_D_DIAGNOSIS AS DiagnosisName on DiagnosisName.DIAGNOSIS_ID=Diagnosis.DX_ID
INNER JOIN ARPB_TRANSACTIONS AS CPT_Table ON CPT_Table.PATIENT_ID=EncounterTable.Pat_id
Where DiagnosisName.DIAGNOSIS_CODE IN ('F10.90','F15.90','F11.90','F13.20')
AND CPT_Code IN('H0004','H0015','90832','90834','90837')
AND EncounterTable.CONTACT_DATE Between '01/04/2022' and '01/01/2023'
Order By Patient.PAT_NAME

/*
What is am doing is using a case statment to check if the CPT code matches and if it does it returnd the encounterID. Now, since I put the count
function in the front it counts the number of non-null values returned by the case statement, which reporesents the number of encounter for that
specific CPT code.
*/
SELECT  
  COUNT(CASE WHEN CPT_Code = 'H0004' THEN EncounterID END) AS H0004,  
  COUNT(CASE WHEN CPT_Code = 'H0015' THEN EncounterID END) AS H0015,  
  COUNT(CASE WHEN CPT_Code = '90832' THEN EncounterID END) AS [90832],  
  COUNT(CASE WHEN CPT_Code = '90834' THEN EncounterID END) AS [90834],  
  COUNT(CASE WHEN CPT_Code = '90837' THEN EncounterID END) AS [90837]  
FROM #EncounterTable;  

Select *
From #EncounterTable