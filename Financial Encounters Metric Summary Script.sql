/*
Metric: Finacial Encounters
By: Cindy Chavarria Minera
Made: 2/21/2024
*/

Select Grouping_ID(Subquery.FACILITY_ID,Subquery.SERVICE_AREA_ID,Subquery.REV_LOC_ID, Subquery.DEPARTMENT_ID,Subquery.USER_ID, Subquery.SERV_PROVIDER_ID)"Grouping_ID"
    , Subquery.FACILITY_ID "Target_0"
    , SubQuery.Service_Area_ID "TARGET_1"
	, SubQuery.REV_LOC_ID	"TARGET_2"
	, SubQuery.DEPARTMENT_ID "TARGET_3"
    , SubQuery.SERV_PROVIDER_ID "TARGET_4"
	, SubQuery.User_ID       "TARGET_5"
	, SubQuery.Date	 "INTERVAL_DT"
	, 1 "Financial Encounter"
	, COUNT(DISTINCT Subquery.PAT_ENC_CSN_ID) "VALUE_1"
From
(
Select DISTINCT  
  TRANSACTIONS.PAT_ENC_CSN_ID
--,TRANSACTIONS.Post_date 
, TRANSACTIONS.Service_Date [Date]
,TRANSACTIONS.Department_ID
,TRANSACTIONS.Service_Area_ID
,TRANSACTIONS.FACILITY_ID
, Department.REV_LOC_ID
,TRANSACTIONS.USER_ID
--,TRANSACTIONS.BILLING_PROV_ID
,TRANSACTIONS.SERV_PROVIDER_ID
, TRANSACTIONS.VOID_DATE
, EAP.RPT_GRP_SEVEN
From Clarity_EAP EAP
Inner join CLARITY.DBO.ARPB_TRANSACTIONS  TRANSACTIONS ON EAP.PROC_ID=TRANSACTIONS.PROC_ID
Inner Join PATIENT ON Patient.PAT_ID=TRANSACTIONS.PATIENT_ID
Inner Join PAT_ENC Encounter ON Encounter.PAT_ENC_CSN_ID=TRANSACTIONS.PAT_ENC_CSN_ID
inner Join ZC_DISP_ENC_TYPE EncounterType On EncounterType.DISP_ENC_TYPE_C=Encounter.ENC_TYPE_C
Inner Join CLARITY_DEP Department ON Department.DEPARTMENT_ID=TRANSACTIONS.DEPARTMENT_ID
Inner Join VALID_PATIENT Valid ON Valid.PAT_ID=PATIENT.PAT_ID
Where IS_ACTIVE_YN='Y'
And EAP.RPT_GRP_SEVEN = '100001'
And VOID_DATE IS NULL
And TRANSACTIONS.SERVICE_AREA_ID = '10'
AND Valid.IS_VALID_PAT_YN='Y'
AND     RIGHT(TRANSACTIONS.CPT_CODE,2) <> 'wP'
        and (Transactions.MODIFIER_ONE <> 'WP' or TRANSACTIONS.Modifier_ONE is null)
		and (TRANSACTIONS.MODIFIER_TWO <> 'WP' or TRANSACTIONS.modifier_Two is null)
		and (TRANSACTIONS.MODIFIER_THREE <> 'WP' or TRANSACTIONS.Modifier_Three is null)
		and (TRANSACTIONS.MODIFIER_FOUR <> 'WP' or TRANSACTIONS.MODIFIER_FOUR is null)
) Subquery
GROUP BY GROUPING SETS (
	  Subquery.FACILITY_ID			-- Facility
	, SubQuery.Service_Area_ID		-- Service Area 1
	, SubQuery.REV_LOC_ID	        -- Location  2
	, SubQuery.DEPARTMENT_ID	    -- Department 3
    , SubQuery.User_ID                 
    , SubQuery.SERV_PROVIDER_ID               
    , (SubQuery.DEPARTMENT_ID, SubQuery.SERV_PROVIDER_ID) 
    ), SubQuery.Date