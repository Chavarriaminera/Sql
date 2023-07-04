
--Inital Dem
IF OBJECT_ID ( 'tempdb.dbo.#EncounterPopulation' ) IS NOT NULL DROP TABLE #EncounterPopulation
SELECT DISTINCT
ENCOUNTERS.PAT_ID Patient_ID
, ENCOUNTERS.PAT_ENC_CSN_ID Encounter_ID
, ENCOUNTERS.CONTACT_DATE

, CPT_Table.CPT_CODE First_Appointment_CPT
, CPT_Table.SERVICE_DATE D0140D0150_SERVICEDATE
, CPT_Table.SERV_PROVIDER_ID  AS Provider_Who_Performed_Service --	The internal identifier of the provider who performed the medical services on the patient.
, CPT_Table.BILLING_PROV_ID AS  Billing_Provider --	The billing provider associated with the transaction.
, All_Dental.SERVICE_DATE Any_Dental_Service_Date
, All_Dental.CPT_CODE
INTO #EncounterPopulation
FROM 
 PAT_ENC ENCOUNTERS        
 JOIN [CLARITY].[dbo].[ARPB_TRANSACTIONS] CPT_Table ON CPT_Table.PAT_ENC_CSN_ID = ENCOUNTERS.PAT_ENC_CSN_ID  
             AND CPT_Table.CPT_CODE IN ('D0140', 'D0150') AND CPT_Table.VOID_DATE IS NULL
 left join [CLARITY].[dbo].[ARPB_TRANSACTIONS] All_Dental on All_Dental.PATIENT_ID = ENCOUNTERS.PAT_ID 
             AND All_Dental.CPT_CODE LIKE 'D%' and All_Dental.VOID_DATE IS NULL
 where All_Dental.SERVICE_DATE between ENCOUNTERS.CONTACT_DATE + 1 AND ENCOUNTERS.contact_date + 30
order by ENCOUNTERS.PAT_ENC_CSN_ID 

Select Count(Distinct Patient_ID) 
From #EncounterPopulation

Select Count(Distinct Encounter_ID) 
From #EncounterPopulation

IF OBJECT_ID ( 'tempdb.dbo.#PaintAssessment' ) IS NOT NULL DROP TABLE #PaintAssessment
SELECT DISTINCT 
  PATIENT.PAT_ID Patient_ID
,  EncounterTable.PAT_ENC_CSN_ID Encounter_ID
INTO #PaintAssessment
From CLARITY.dbo.PAT_ENC AS EncounterTable
INNER JOIN CLARITY.dbo.PATIENT ON PATIENT.PAT_ID=EncounterTable.PAT_ID  
INNER JOIN CLARITY.dbo.IP_FLWSHT_REC AS LinkingInfoWithFlowSheetRecordsTable ON LinkingInfoWithFlowSheetRecordsTable.INPATIENT_DATA_ID= EncounterTable.INPATIENT_DATA_ID --Linking the flow sheet record with the encounter table record. 
INNER JOIN CLARITY.dbo.IP_FLWSHT_MEAS AS PatientSpecificMeasurementsFromFlowsheetsTable ON PatientSpecificMeasurementsFromFlowsheetsTable.FSD_ID = LinkingInfoWithFlowSheetRecordsTable.FSD_ID --linking the the flowsheet records table with patient speciic measurents
INNER JOIN CLARITY.dbo.IP_FLO_GP_DATA AS InformationAboutFlowsheetGroupsOrRowsTable ON InformationAboutFlowsheetGroupsOrRowsTable.FLO_MEAS_ID = PatientSpecificMeasurementsFromFlowsheetsTable.FLO_MEAS_ID --lINKING THE GROUPS WITH PATIENT RECORDS FROM FLOWSHEET TABLE 
LEFT OUTER JOIN CLARITY.dbo.ALL_CATEGORIES AS CategoriesTable ON InformationAboutFlowsheetGroupsOrRowsTable.CAT_INI = CategoriesTable.INI and InformationAboutFlowsheetGroupsOrRowsTable.CAT_ITEM = CategoriesTable.ITEM --!!!! NO Idea !!!
LEFT OUTER JOIN CLARITY.dbo.IP_FLT_DATA AS InformationRelatedToDefinedFlowsheetTemplatesTable  on InformationAboutFlowsheetGroupsOrRowsTable.FLO_MEAS_ID = InformationRelatedToDefinedFlowsheetTemplatesTable.TEMPLATE_ID --!!!! NO Idea !!!
LEFT OUTER JOIN CLARITY.dbo.CLARITY_EMP AS EmployeeTable on EmployeeTable.USER_ID = PatientSpecificMeasurementsFromFlowsheetsTable.TAKEN_USER_ID --linking the emplyee table on the person  who took the assessment table
LEFT OUTER JOIN CLARITY.dbo.CLARITY_SER AS ProviderRecordsTable on ProviderRecordsTable.USER_ID=EmployeeTable.USER_ID --linking the providerrecords to the emplyee table
LEFT OUTER JOIN clarity.dbo.ZC_NOTE_SER AS ProviderTypeCategory on ProviderTypeCategory.SERVICE_TYPE_C =	ProviderRecordsTable.PROVIDER_TYPE_C
--LEFT OUTER JOIN clarity.dbo.ZC_PROV_TYPE AS ProviderTypeCategory on ProviderTypeCategory.PROV_TYPE_C =	ProviderRecordsTable.PROVIDER_TYPE_C -- This just in case the above gets deleted

Where  InformationAboutFlowsheetGroupsOrRowsTable.FLO_MEAS_NAME  IN ('R PAIN SCORE', 'PAIN SCORE (CATEGORY LIST)') --This gives me the flow sheet for the pain score

	   AND PATIENT.PAT_ID IN (SELECT ENCOUNTERS1.PAT_ID Patient_ID 
FROM PAT_ENC ENCOUNTERS1        
 JOIN [CLARITY].[dbo].[ARPB_TRANSACTIONS] a ON a.PAT_ENC_CSN_ID = ENCOUNTERS1.PAT_ENC_CSN_ID  and a.CPT_CODE IN ('D0140', 'D0150') AND a.VOID_DATE IS NULL
 left join [CLARITY].[dbo].[ARPB_TRANSACTIONS] alldental on alldental.PATIENT_ID = ENCOUNTERS1.PAT_ID and alldental.CPT_CODE like 'D%' and alldental.VOID_DATE is null
 where alldental.SERVICE_DATE between ENCOUNTERS1.CONTACT_DATE + 1 and encounters1.contact_date + 30)
 ORDER BY PATIENT.PAT_ID


 Select Count(Distinct Patient_ID) 
From #PaintAssessment

