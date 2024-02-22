If Object_ID ('Tempdb.dbo.#One') IS NOT NULL DROP TABLE #One
Select 
   FACILITY_ID
   ,SERVICE_AREA_ID
   ,REV_LOC_ID
   ,Department_ID
   ,Prov_ID
   ,USER_ID
 ,[Provider Name]
, Department
, Date
, SERVICE_DATE
, [Patient Name]
, MRN
, [Visit Type]
, PAT_ENC_CSN_ID
, STUFF ( ( SELECT ', ' +CPT_CODE
        From  CLARITY.DBO.ARPB_TRANSACTIONS
		   Where CLARITY.DBO.ARPB_TRANSACTIONS.Pat_ENC_CSN_ID=Subquery.PAT_ENC_CSN_ID
		   GROUP BY CPT_CODE FOR XML PATH ( '' ) ) , 1 , 1 , '' ) [CPT Codes Within The Visit]
INTO #One
From
(

Select DISTINCT  
  Ser.PROV_NAME [Provider Name]
-- ,TRANSACTIONS.SERV_PROVIDER_ID
 , CONVERT(VARCHAR(10), Transactions.SERVICE_DATE, 101) Date
 ,TRANSACTIONS.Service_Date 
 ,Dep.DEPARTMENT_NAME Department
 ,Dep.DEPARTMENT_ID
 ,PATIENT.PAT_NAME [Patient Name]
, Patient.PAT_MRN_ID MRN
--,TRANSACTIONS.Patient_ID
,TRANSACTIONS.PAT_ENC_CSN_ID

,TRANSACTIONS.Service_Area_ID
,TRANSACTIONS.FACILITY_ID
 ,EncounterType.NAME [Visit Type]
 , DEP.REV_LOC_ID
 ,TRANSACTIONS.SERV_PROVIDER_ID [Prov_ID]
,TRANSACTIONS.USER_ID
--,TRANSACTIONS.BILLING_PROV_ID
--,TRANSACTIONS.Void_Date
----,TRANSACTIONS.PROC_ID 
,TRANSACTIONS.CPT_CODE
--, EAP.Proc_ID
--, EAP.Proc_Name
--, EAP.Proc_Code
--, EAP.RPT_GRP_SEVEN
--, EAP.Is_Active_YN
--, EAP.Proc_Cat_ID
--, EAP.Bill_Desc
From Clarity_EAP EAP
Inner join CLARITY.DBO.ARPB_TRANSACTIONS  TRANSACTIONS ON EAP.PROC_ID=TRANSACTIONS.PROC_ID
Inner Join PATIENT ON Patient.PAT_ID=TRANSACTIONS.PATIENT_ID
Inner Join PAT_ENC Encounter ON Encounter.PAT_ENC_CSN_ID=TRANSACTIONS.PAT_ENC_CSN_ID
Inner Join CLARITY_SER Ser ON Ser.PROV_ID=TRANSACTIONS.SERV_PROVIDER_ID
Inner Join CLARITY_DEP DEP on DEP.DEPARTMENT_ID =TRANSACTIONS.Department_ID
inner Join ZC_DISP_ENC_TYPE EncounterType On EncounterType.DISP_ENC_TYPE_C=Encounter.ENC_TYPE_C
Inner Join VALID_PATIENT Valid ON Valid.PAT_ID=PATIENT.PAT_ID
Where IS_ACTIVE_YN='Y'
And EAP.RPT_GRP_SEVEN = '100001'--TALK TO THE DEPARTMENT, WHERE IT IS AT IN EPIC. 
And VOID_DATE IS NULL
And TRANSACTIONS.SERVICE_AREA_ID = '10'
AND Valid.IS_VALID_PAT_YN='Y'
AND     RIGHT(TRANSACTIONS.CPT_CODE,2) <> 'wP'
        and (Transactions.MODIFIER_ONE <> 'WP' or TRANSACTIONS.Modifier_ONE is null)
		and (TRANSACTIONS.MODIFIER_TWO <> 'WP' or TRANSACTIONS.modifier_Two is null)
		and (TRANSACTIONS.MODIFIER_THREE <> 'WP' or TRANSACTIONS.Modifier_Three is null)
		and (TRANSACTIONS.MODIFIER_FOUR <> 'WP' or TRANSACTIONS.MODIFIER_FOUR is null)



) Subquery


Select
      {{DETAIL_FIELD [[1]] [[ [Provider Name] ]] }}
    , {{DETAIL_FIELD [[2]] [[Department]] }}
    , {{DETAIL_FIELD [[3]] [[ Date ]] }}
    , {{DETAIL_FIELD [[4]] [[ [Patient Name] ]] }}
    , {{DETAIL_FIELD [[5]] [[ MRN ]] }}
    , {{DETAIL_FIELD [[6]] [[ [Visit Type] ]] }}
    , {{DETAIL_FIELD [[7]] [[ PAT_ENC_CSN_ID ]] }}
    , {{DETAIL_FIELD [[8]] [[ [CPT Codes Within The Visit] ]] }}
FROM
    #One
Where
            {{IN_TARGET_FILTER [[1]] [[SERV_AREA_ID]] }}
    AND 	{{IN_TARGET_FILTER [[2]] [[REV_LOC_ID]] }}
    AND 	{{IN_TARGET_FILTER [[3]] [[DEPARTMENT_ID]] }}
    AND 	{{IN_TARGET_FILTER [[4]] [[Prov_ID]] }}
    AND 	{{IN_TARGET_FILTER [[5]] [[User_ID]] }}
    AND     {{IN_REPORT_DT_RANGE [[ Service_Date ]] }}






