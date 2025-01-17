 /*********************************************************************************************************** 
    Developer: Cindy Chavarria Minera
	Metric
*****************/


Select 
      {{DETAIL_FIELD [[1]] [[ [Employee Type] ]] }}
    , {{DETAIL_FIELD [[2]] [[ Employee ]] }}
    , {{DETAIL_FIELD [[3]] [[ [User ID] ]] }}
    , {{DETAIL_FIELD [[4]] [[ [Patient Name] ]] }}
    , {{DETAIL_FIELD [[5]] [[ MRN ]] }}
    , {{DETAIL_FIELD [[6]] [[ PAT_ENC_CSN_ID  ]] }}
    , {{DETAIL_FIELD [[7]] [[ Date ]] }}
    , {{DETAIL_FIELD [[8]] [[ [Department] ]] }}
    , {{DETAIL_FIELD [[9]] [[ [Provider Name] ]] }}
    , {{DETAIL_FIELD [[10]] [[ [Revenue Location] ]] }}
    , {{DETAIL_FIELD [[11]] [[ [Height Measurment] ]] }}
    , {{DETAIL_FIELD [[12]] [[ Totals ]] }}
From (
Select 
  MA_Audit.EmpType [Employee Type]
, MA_Audit.Employee
, MA_Audit.FM_Entry_User_ID [User ID]
, MA_Audit.PAT_NAME [Patient Name]
, MA_Audit.PAT_MRN_ID [MRN]
, MA_Audit.PAT_ENC_CSN_ID 
, MA_Audit.CONTACT_DATE [Date]
, MA_Audit.DEPARTMENT_NAME [Department]
, Ser.PROV_NAME [Provider Name]
, MA_Audit.Visit_Prov_ID 
, MA_Audit.LOC_NAME [Revenue Location]
, Department.SERV_AREA_ID
, MA_Audit.Rev_Loc_ID
, MA_Audit.Department_ID
, Case when HT_NUM = 1 Then 'Met' when HT_Num = 0 then 'Not Met' End AS [Height Measurment Captured]
, HT_NUM  as [Totals]
From elrio.MA_Audit
Inner Join PAT_ENC Encounter  ON Encounter.PAT_ID = MA_Audit.PAT_ID AND Encounter.PAT_ENC_CSN_ID=MA_Audit.PAT_ENC_CSN_ID
Inner Join CLARITY_DEP Department On Department.Department_ID=Ma_Audit.Department_ID And Department.Rev_Loc_ID=Ma_Audit.Rev_Loc_ID
Inner Join CLARITY_SER Ser ON Ser.PROV_ID=MA_Audit.VISIT_PROV_ID
) Subquery
Where
            {{IN_TARGET_FILTER [[1]] [[SERV_AREA_ID]] }}
    AND 	{{IN_TARGET_FILTER [[2]] [[REV_LOC_ID]] }}
    AND 	{{IN_TARGET_FILTER [[3]] [[DEPARTMENT_ID]] }}
    AND 	{{IN_TARGET_FILTER [[4]] [[Visit_Prov_ID ]] }}
    AND 	{{IN_TARGET_FILTER [[5]] [[User_ID]] }}
    AND     {{IN_REPORT_DT_RANGE [[ Date ]] }}