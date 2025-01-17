USE [CLARITY]
GO

/****** Object:  StoredProcedure [ElRio].[csp_TitleX_AFHP_FPAR4]    Script Date: 7/30/2024 10:14:51 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [ElRio].[csp_TitleX_AFHP_FPAR4] ( @start DATE , @end DATE , @ExportFileOption VARCHAR(25) , @ShowDebug_Bitflag TINYINT ) AS
/******************************************************************************************************** 
   Object: PROCEDURE [ElRio].[csp_TitleX_AFHP_FPAR4] 
   Description:  Monthly report stored procedure for Title 
  

How to run:
exec [ElRio].[csp_TitleX_AFHP_FPAR4] @start = '06/01/2024' , @end = '06/30/2024' , @ExportFileOption = N'GRANT' , @ShowDebug_Bitflag = 1 
   -- a value of 1 in last parameter will give you debug mode
   exec [ElRio].[csp_TitleX_AFHP_FPAR4] @start = '05/01/2024' , @end = '05/31/2024' , @ExportFileOption = N'ENCOUNTERS' , @ShowDebug_Bitflag = 1   
   exec [ElRio].[csp_TitleX_AFHP_FPAR4] @start = '05/01/2024' , @end = '05/31/2024' , @ExportFileOption = N'VALIDATION' , @ShowDebug_Bitflag = 1 

   Modification History:
   VERSION 2020 PRE-EDW
   Developer: RE Create date: 10/30/2020
   Description: For title x AFHP grant. One month might take about 5 min to return results
   https://www.reproductiveaccess.org/wp-content/uploads/2014/12/vasectomy_coding_icd10.pdf
   Collecting the data: 1:40 (minutes) Creation of fpEncs table for last rows processing: 1 min
   
  
	
   VERSION 2021 CLARITY

    Description: The First Query for the Title X Extract * @ExportFileOption: 
          * Null or Empty String or 'GRANT' or any string besides the next two options = Grant File
          * ENCOUNTERS" = Encounters File * - "VALIDATION" = Encounters File

	VERSION 2022 CLARITY FPAR 2.0

    Create date: 03/28/2022
    Description:	Title X Extract fpar2.0 
    WHAT THIS WORK INVOLVES:
    I. Figuring out where the data lives.  
 	II. Creating tables, views to accomodate changes this time and in the future.
	III. Restructuing the stored procedure (SP), elminate redundant processing.
	IV. Modifying the code in the SP considering 3 datasets. 
	V. Changing the expected values in accordance to the lookup tables.
	VI. Changing the layout.
	VII. Test. 

	VERSION 2023 'AFFIRM' CLARITY sEE AFFIRM DATA MANUAL

	- WORKED ON RE-STRUCTURING THE VIEWS THAT SUPPORT THIS
	- REMOVED OBSOLETE LOGIC like breast exams and contraception madness and unnecessary temp tables
	- RE ORGANIZED THE CODE
	- fixed performance.. used to take 2 hours for a month now only 5 minutes per month
	- from flowsheet WE ARE NOW BRINGING NOT JUST THE BEFORE AND AFER METHODS BUT ALSO:
	  1.	BC_Counsel - Contraceptive counseling was provided 
      2.	Preg_Counsel -- Counseling to achieve pregnancy was provided New Fiel
      3.  Dispensed -- how was contraceptive method provided? 1 provided onsite 2 prescription 3 referral 4 not provided 


********************************************************************************************************/
 BEGIN
  SET NOCOUNT ON
  IF COALESCE ( @ExportFileOption , '' ) NOT IN ('GRANT' , 'ENCOUNTERS' , 'VALIDATION' )	
   SET @ExportFileOption = 'GRANT'
  IF @start is null SET @start = ( SELECT MONTH_BEGIN_DT FROM DATE_DIMENSION where CALENDAR_DT = DATEADD ( MONTH , -1 , GETDATE ( ) ) )
  IF @end is null SET @end = ( SELECT MONTH_END_DT FROM DATE_DIMENSION where CALENDAR_DT = DATEADD ( MONTH ,-1 , GETDATE ( ) ) )
  IF @ShowDebug_Bitflag IS NULL SET @ShowDebug_Bitflag = 0
  DECLARE @practiceCD CHAR ( 4 ) = '0002' -- assigned by ELRIO
  DECLARE @delegateID CHAR ( 2 ) = '26' -- assigned by AHFP
  DECLARE @siteHCIDNW CHAR ( 4 ) = '2601' -- assigned by AHFP
  DECLARE @siteHCIDEP CHAR ( 4 ) = '2602' -- assigned by AHFP
  DECLARE @siteHCIDCong CHAR ( 4 ) = '2603' -- assigned by AHFP
  
  IF OBJECT_ID ( 'tempdb.dbo.#titlex_encs' ) IS NOT NULL DROP TABLE #titlex_encs
  SELECT @practiceCD PracticeCd -- step 1.- Get encounter list: qualifications for an encounter to be sent are any one of the fields was yes for a service AND that client is not sterilized
   , v.personid PersonID -- comes from PAT_ID 
   , v.encid EncID --  comes from PAT_ENC_CSN_ID EncID -- this is numeric
   , v.visitgrp VisitGrp 
   , CAST ( v.encdate AS DATE ) EncDate -- comes from CONTACT_DATE EncDate CAST ( e.EncDate AS DATE ) 
   , v.finclass finclass 
   , v.providerid ProviderID 
   , v.LOC_NAME LocationName 
   , v.mrn MRN 
   , v.dateofbirth DateOfBirth
   , v.zip Zip 
   , v.sex Sex 
   , v.Ethnicity 
   , v.LEP 
   , v.ProviderID Rendering_Provider 
   , v.VisitType VisitType 
   , v.EncID EncNbr 
   , v.PersonID PersonNbr 
   , v.FirstName 
   , v.lastname LastName 
   , v.prov_name provider_name 
   , v.SYSTOLIC 
   , v.DIASTOLIC  
   , v.[WEIGHT] 
   , v.[Provider_desc] provider_numeric 
   , v.INPATIENT_DATA_ID
   , v.fin_class_c
   , v.payor_name
   , v.ENC_TYPE_C
   , v.account_id
   , v.DEPARTMENT_ID 
   , v.SPECIALTY
   , v.IsFPWorkflowEnc 
   , v.copay
   , eomonth ( CAST ( v.encdate AS DATE ) ) encDateMonth
  INTO  #titlex_encs
  FROM CLARITY.ElRio.v_TitleX_fpar2 V
  WHERE v.encdate BETWEEN @start AND @end
  IF @ShowDebug_Bitflag = 1 BEGIN SELECT 'SELECT * FROM #titlex_encs' SELECT * FROM #titlex_encs END 

  IF OBJECT_ID ( 'tempdb.dbo.#titlex_screening' ) IS NOT NULL DROP TABLE #titlex_screening
  SELECT e.VisitGrp VisitGrp /* Go through the procedures performed and charges dropped for STD screens/PAP */
   , e.PracticeCd PracticeCd 
   , e.PersonID PersonID
   , e.EncID EncID 
   , p.activity_date ActDate
   , TitleX_ProcCategory CategoryDesc
   , TitleX_ProcCategory ScreeningType
   , e.Rendering_Provider Rendering_Provider
   , e.VisitType 
   , e.EncNbr 
   , e.PersonNbr 
   , e.FirstName 
   , e.LastName
  INTO #titlex_screening
  FROM #titlex_encs e 
   inner hash JOIN ELRIO.v_TitleX_procs p ON p.procs_Pat_ID = e.PersonID AND p.activity_date BETWEEN @start AND @end
   inner hash JOIN ELRIO.v_TitleX_procs_cats C ON C.TitleX_PROC_ID = p.procs_PROC_ID
  IF @ShowDebug_Bitflag = 1 BEGIN SELECT 'SELECT * FROM #titlex_screening' SELECT * FROM #titlex_screening END 

  IF OBJECT_ID ( 'tempdb.dbo.#titlex_encs_SIMPLE' ) IS NOT NULL DROP TABLE #titlex_encs_SIMPLE
  SELECT f.PersonID , f.EncDate
  INTO #titlex_encs_SIMPLE
  FROM #titlex_encs F
  IF @ShowDebug_Bitflag = 1 
   BEGIN 
    SELECT 'SELECT * FROM #titlex_encs_SIMPLE' 
	SELECT * FROM #titlex_encs_SIMPLE 
   END 

  IF OBJECT_ID ( 'tempdb.dbo.#titlex_encs_main' ) IS NOT NULL DROP TABLE #titlex_encs_main
  SELECT f.VisitGrp , f.PracticeCd , f.PersonID , f.EncID , f.MRN , f.EncDate , f.encDateMonth
  INTO #titlex_encs_main
  FROM #titlex_encs f
  IF @ShowDebug_Bitflag = 1 
   BEGIN 
    SELECT 'SELECT * FROM #titlex_encs_main' 
	SELECT * FROM #titlex_encs_main 
   END 

  IF OBJECT_ID ( 'tempdb.dbo.#encs_with_orders' ) IS NOT NULL DROP TABLE #encs_with_orders
  SELECT e.VisitGrp , e.PracticeCd , e.PersonID , e.EncID , e.MRN , e.EncDate , OP.ORDER_PROC_ID
  INTO #encs_with_orders 
  FROM #titlex_encs_main e inner hash join [ElRio].[V_Labs_basic] OP on OP.ORDER_CSN = e.EncID -- where it is part of an encounter
  IF @ShowDebug_Bitflag = 1 
   BEGIN SELECT 'SELECT * FROM #encs_with_orders' SELECT * FROM #encs_with_orders END 

  IF OBJECT_ID ( 'tempdb.dbo.#encs_with_related_orders' ) IS NOT NULL DROP TABLE #encs_with_related_orders
  SELECT e.VisitGrp , e.PracticeCd , e.PersonID , e.EncID , e.MRN , e.EncDate , OP.ORDER_PROC_ID
  INTO #encs_with_related_orders 
  FROM #titlex_encs_main e inner hash join [ElRio].[V_Labs_basic] OP on OP.Patient_ID = e.PersonID 
   where --( 
   OP.PARENT_ORD_INST_DTTM = e.EncDate
		 or OP.Order_Date = e.EncDate
		 or ( OP.perform_by_date between e.EncDate and e.encDateMonth
		       and not exists ( select 1
                                from #titlex_encs_SIMPLE f
                                where f.PersonID = OP.Patient_ID 
				              and f.EncDate = OP.Order_Date
				              and f.EncDate > e.EncDate
				              and f.EncDate <= e.encDateMonth 
				            ) -- this is in case there is a future title x that also has labs
		 ) --	) 

  IF @ShowDebug_Bitflag = 1 
   BEGIN 
    SELECT 'SELECT * FROM #encs_with_related_orders' 
	SELECT * FROM #encs_with_related_orders 
   END 

  IF OBJECT_ID ( 'tempdb.dbo.#encs_all' ) IS NOT NULL DROP TABLE #encs_all
  select distinct a.VisitGrp 
   , a.PracticeCd 
   , a.PersonID 
   , a.EncID 
   , a.MRN 
   , a.EncDate 
   , a.Order_PROC_ID
  INTO #encs_all
  from ( SELECT VisitGrp , PracticeCd , PersonID , EncID , MRN , EncDate , o.Order_PROC_ID
         from #encs_with_orders o
         union all
         SELECT VisitGrp , PracticeCd , PersonID , EncID , MRN , EncDate , rel.Order_PROC_ID
		 from #encs_with_related_orders rel ) a
  IF @ShowDebug_Bitflag = 1 
   BEGIN 
    SELECT 'SELECT * FROM #encs_all' 
	SELECT * FROM #encs_all 
   END

 IF OBJECT_ID ( 'tempdb.dbo.#titlex_labs' ) IS NOT NULL DROP TABLE #titlex_labs /* Go through the lab results for every type of test we are looking for.*/
  SELECT e.VisitGrp VisitGrp 
   , e.PracticeCd 
   , e.PersonID 
   , e.EncID
   , e.MRN
   , e.EncDate 
   , PAP.pap_result pap_result
   , HPV.HPV_result hPV_result
   , chlam.chlam_result chlam_result 
   , GC.GC_RESULT gc_result
   , vdrl.VDRL_result vdrl_result
   , hiv.HIV_result hiv_result
   , PREG.PT_RESULT pt_result 
  INTO #titlex_labs 
  FROM #encs_all e 
   LEFT JOIN [ElRio].[V_TitleX_Chlam_results] chlam ON chlam.ORDER_PROC_ID = e.ORDER_PROC_ID 
   LEFT JOIN [ElRio].[V_TitleX_GC_results] GC ON GC.ORDER_PROC_ID = e.ORDER_PROC_ID
   LEFT JOIN [ElRio].V_TitleX_HPV_results HPV ON HPV.ORDER_PROC_ID = e.ORDER_PROC_ID
   LEFT JOIN ELRIO.V_TitleX_pap_results PAP ON PAP.ORDER_PROC_ID = e.ORDER_PROC_ID 
   LEFT JOIN ElRio.[V_TitleX_PREGNANCY_results] PREG ON PREG.ORDER_PROC_ID = e.ORDER_PROC_ID
   LEFT JOIN [ElRio].[V_TitleX_VDRL_results] vdrl ON vdrl.ORDER_PROC_ID = e.ORDER_PROC_ID
   LEFT JOIN ElRio.V_TitleX_HIV_Results hiv ON hiv.ORDER_PROC_ID = e.ORDER_PROC_ID
  IF @ShowDebug_Bitflag = 1 
   BEGIN 
    SELECT '#titlex_labs' 
    select * from #titlex_labs 
   END

  IF OBJECT_ID ( 'tempdb.dbo.#temp_noteencs' ) IS NOT NULL DROP TABLE #temp_noteencs
  SELECT HNO_INFO.PAT_ENC_CSN_ID , NOTE_ID , HNO_INFO.PAT_ID , NOTE_TYPE_NOADD_C , UNSIGNED_YN , e.EncDate /* This section is a deviation from the NextGen code. We troll the notes to find any reference to contraception/preg/reproductive cancers and "Education" */
  INTO #temp_noteencs 
  FROM HNO_INFO 
   inner hash JOIN #titlex_encs e on e.EncID = HNO_INFO.PAT_ENC_CSN_ID -- WHERE PAT_ENC.CONTACT_DATE BETWEEN @start AND @end and PAT_ENC.PAT_ID IN ( SELECT PERSONID FROM #titlex_encs ) 
  IF @ShowDebug_Bitflag = 1 
   BEGIN 
    SELECT '#temp_noteencs' 
    select * from #temp_noteencs 
   END

  IF OBJECT_ID ( 'tempdb.dbo.#notez' ) IS NOT NULL DROP TABLE #notez ;
  select HNO_INFO.PAT_ID , HNO_INFO.EncDate , NOTE_TEXT
  into #notez
  FROM #temp_noteencs HNO_INFO 
   inner hash JOIN HNO_NOTE_TEXT ON HNO_NOTE_TEXT.NOTE_ID = HNO_INFO.NOTE_ID
   LEFT JOIN ZC_NOTE_TYPE ON HNO_INFO.NOTE_TYPE_NOADD_C = ZC_NOTE_TYPE.NOTE_TYPE_C 
  WHERE UNSIGNED_YN IS NULL OR UNSIGNED_YN <> 'Y' ;
  IF @ShowDebug_Bitflag = 1 BEGIN SELECT '#notez' select * from #notez END ;

  IF OBJECT_ID ( 'tempdb.dbo.#titlex_education' ) IS NOT NULL DROP TABLE #titlex_education
  SELECT * 
  INTO #titlex_education
  FROM ( SELECT e.VisitGrp 
          , e.PracticeCd 
		  , e.PersonID 
		  , e.EncID 
		  , activitydate 
		  , EducationType 
		  , EducationType CategoryDetail 
		  , e.Rendering_Provider Rendering_Provider 
		  , e.VisitType 
		  , e.EncNbr 
		  , e.PersonNbr 
		  , e.FirstName 
		  , e.LastName
		 FROM #titlex_encs e JOIN ( 
		  SELECT PAT_ID , activitydate , EducationType -- beginning of notez sub query:
          FROM ( SELECT PAT_ID 
				  , MIN ( EncDate ) activitydate 
				  , MAX ( CASE WHEN ( NOTE_TEXT LIKE '%contracept%' OR -- Per Moira edit NOTE_TEXT LIKE '%sterile%' OR --Per Moira Remove 7.7.23 #CM7.7.23
                                      NOTE_TEXT LIKE '%depo prov%' OR 
                                      NOTE_TEXT LIKE '%condom%' OR 
                                      NOTE_TEXT LIKE '% iud %' OR 
                                      NOTE_TEXT LIKE '% Prevent Pregnancy %' OR --Per Moira add #CM7.7.23
                                      NOTE_TEXT LIKE '% Become Pregnant %' OR --Per Moira add #CM7.7.23
                                      NOTE_TEXT LIKE '%birth control %' OR 
                                      NOTE_TEXT LIKE '%family planning%' ) AND --Per Moira Modify 7.7.23 #CM7.7.23
                                    ( NOTE_TEXT LIKE '%discuss%' OR 
                                      NOTE_TEXT LIKE '%educat%' OR
                                      NOTE_TEXT LIKE '%Counsel%' ) --Per Moira add #CM7.7.23
                                THEN 'Contraception' ELSE NULL END ) EducationType
				 FROM #notez 
				 GROUP BY PAT_ID
				 UNION ALL
				 SELECT PAT_ID 
				  , MIN ( EncDate ) activitydate 
				  , MAX ( CASE WHEN ( NOTE_TEXT LIKE '%pregnan%' OR 
							          NOTE_TEXT LIKE '%conciev%' OR 
									  NOTE_TEXT LIKE '%infertil%' OR 
									  NOTE_TEXT LIKE '%concept%' ) AND 
									( NOTE_TEXT LIKE '%discuss%' OR NOTE_TEXT LIKE '%educat%' )
								THEN 'Pregnancy' ELSE NULL END ) EducationType
				 FROM #notez 
				 GROUP BY PAT_ID
				 UNION ALL
				 SELECT PAT_ID 
				  , MIN ( EncDate ) activitydate
				  , MAX ( CASE WHEN ( NOTE_TEXT LIKE '%cervi%' OR NOTE_TEXT LIKE '%breast cancer%' ) AND 
									( NOTE_TEXT LIKE '%discuss%' OR NOTE_TEXT LIKE '%educat%' ) 
								THEN 'Preventative' ELSE NULL END ) EducationType
				 FROM #notez 
				 GROUP BY PAT_ID
				 UNION ALL
				 SELECT PAT_ID 
				  , MIN ( EncDate ) activitydate 
				  , MAX ( CASE WHEN ( NOTE_TEXT LIKE 'std%' OR 
				                      NOTE_TEXT LIKE 'sti%' OR 
									  NOTE_TEXT LIKE 'hiv%' OR 
									  NOTE_TEXT LIKE 'aids%' OR 
									  NOTE_TEXT LIKE '%syphilis%' OR 
									  NOTE_TEXT LIKE '%vdrl%' OR
									  NOTE_TEXT LIKE '%gonor%' OR 
									  NOTE_TEXT LIKE '%chlam%' OR 
									  NOTE_TEXT LIKE 'pap%' ) AND 
								    ( NOTE_TEXT LIKE '%discuss%' OR NOTE_TEXT LIKE '%educat%' ) 
								THEN 'STI' ELSE NULL END ) EducationType
				 FROM #notez 
				 GROUP BY PAT_ID ) notez
          WHERE notez.EducationType IS NOT NULL ) edu ON edu.PAT_ID = e.PersonID ) noteshelper ;
	IF @ShowDebug_Bitflag = 1 BEGIN SELECT '#titlex_education' select * from #titlex_education END ;

    IF OBJECT_ID ( 'tempdb.dbo.#titlex_charges' ) IS NOT NULL DROP TABLE #titlex_charges
	SELECT e.VisitGrp VisitGrp 
	 , @practiceCD PracticeCd 
	 , e.PersonID PersonID 
	 , a.PAT_ENC_CSN_ID EncID
	 , a.CPT_CODE CptCd 
	 , e.EncDate EncDate
	 , CASE WHEN a.CPT_CODE = '81025' THEN 'Pregnancy test'
			WHEN a.CPT_CODE IN ( 'Q0091' , 'G0101' ) THEN 'PAP' 
			WHEN a.CPT_CODE IN ( '57452' , '57454' , '57455' , '57456' , '57460' , '57461' ) THEN 'Cervix screening'
			WHEN a.CPT_CODE IN ( '57170' , '58300' , '58301' , '11976' , '11981' , '11982' , '11983' , 'J7297' , 'J7298' , 'J1055'
					         , 'J7300' , 'J7301' , 'J7302' , 'J7303' , 'J7304' , 'J7307' , 'J0696' , 'J1050' , 'S4993' ) THEN 'Contraception'
			WHEN a.CPT_CODE IN ( '90649' , '90650' ) THEN 'STI prevention' END ServiceType
	 , e.Rendering_Provider Rendering_Provider , e.VisitType , e.EncNbr , e.PersonNbr , e.FirstName , e.LastName
	INTO #titlex_charges
	FROM #titlex_encs e 
	 inner hash JOIN ARPB_TRANSACTIONS a ON a.PAT_ENC_CSN_ID = e.EncID
	WHERE a.CPT_CODE IN ( '57452' , '57454' , '57455' , '57456' , '57460' , '57461' , '57170' , '58300' , '58301' , '11976' , '11981' , '11982' , '11983' 
	 , 'J7297' , 'J7298' , 'J1055' , 'J7300' , 'J7301' , 'J7302' , 'J7303' , 'J7304' , 'J7307' , 'J0696' , 'J1050' , 'S4993' , '81025' , '90649' , '90650' 
	 , 'Q0091' , 'G0101' ) ;
	 IF @ShowDebug_Bitflag = 1 BEGIN SELECT '#titlex_charges' select * from #titlex_charges END

   IF OBJECT_ID ( 'tempdb.dbo.#titlex_primaryCharge' ) IS NOT NULL DROP TABLE #titlex_primaryCharge
   SELECT e.VisitGrp VisitGrp , @practiceCD PracticeCd , e.PersonID PersonID , MIN ( a.CPT_CODE ) PrimaryCharge , e.Rendering_Provider Rendering_Provider  
	 , e.VisitType , e.EncNbr , e.PersonNbr , e.FirstName , e.LastName
	INTO #titlex_primaryCharge
	FROM #titlex_encs e 
	 inner hash JOIN ARPB_TRANSACTIONS a ON a.PAT_ENC_CSN_ID = E.EncID 
	WHERE a.VOID_DATE IS NULL AND a.TX_TYPE_C = 1 AND a.CPT_CODE IN ( '99201' 
	 , '99202' , '99203' , '99204' , '99205' , '99211' , '99212' , '99213' , '99214' , '99215' , '99241' , '99242' , '99243' , '99244' 
	 , '99245' , '99381' , '99382' , '99383' , '99384' , '99385' , '99386' , '99387' , '99391' , '99392' , '99393' , '99394' , '99395' 
	 , '99396' , '99397' , '99401' , '99402' , '99403' , '99404' , '99204' , '59425' , '59426' ) 
	GROUP BY e.VisitGrp , e.PersonID , e.Rendering_Provider , e.VisitType , e.EncNbr , e.PersonNbr , e.FirstName , e.LastName 
	 IF @ShowDebug_Bitflag = 1 
BEGIN 
    SELECT '#titlex_primaryCharge' 
    select * from #titlex_primaryCharge 
   END

	IF OBJECT_ID ( 'tempdb.dbo.#titlex_primaryCharge_backup' ) IS NOT NULL DROP TABLE #titlex_primaryCharge_backup
	SELECT * /* get the real charges in case we didnt get one last time */
	INTO #titlex_primaryCharge_backup 
	FROM ( SELECT e.VisitGrp VisitGrp , @practiceCD PracticeCd , e.PersonID PersonID , a.CPT_CODE PrimaryCharge 
			, a.VISIT_NUMBER SeqNbr , ROW_NUMBER ( ) OVER ( PARTITION BY e.VisitGrp , e.PersonID ORDER BY a.VISIT_NUMBER ASC ) Ranking
			, e.VisitType , e.EncNbr , e.PersonNbr , e.FirstName , e.LastName
		   FROM #titlex_encs e 
		    inner hash JOIN ARPB_TRANSACTIONS a ON a.PAT_ENC_CSN_ID = e.EncID 
		   WHERE LEN ( a.CPT_CODE ) = 5 AND a.VOID_DATE IS NULL AND a.TX_TYPE_C = 1 ) X
	WHERE Ranking = 1 ;
	 IF @ShowDebug_Bitflag = 1 
BEGIN 
    SELECT '#titlex_primaryCharge_backup' 
    select * from #titlex_primaryCharge_backup 
   END

	IF OBJECT_ID ( 'tempdb.dbo.#titlex_diagnosis' ) IS NOT NULL DROP TABLE #titlex_diagnosis
	SELECT e.VisitGrp VisitGrp , @practiceCD PracticeCd , e.PersonID PersonID , e.EncID EncID , icd10.CODE DiagCd , e.EncDate EncDate
	 , CASE WHEN icd10.CODE IN ( 'z11.8' ) THEN 'Chlamydia Test'
		WHEN icd10.CODE IN ( 'z11.3' ) THEN 'Gonorrhea Chlamydia Test'
		WHEN icd10.CODE IN ( 'z01.411' , 'z01.419') THEN 'Gyn Exam'
		WHEN icd10.CODE IN ( 'z71.7' ) THEN 'HIV Counseling'
		WHEN icd10.CODE IN ( 'z11.4' , 'z11.51' ) THEN 'HIV Test'
		WHEN icd10.CODE IN ( 'z01.42' , 'z12.4' ) OR icd10.CODE LIKE 'z08%' THEN 'Pap'
		WHEN icd10.CODE IN ( 'z32.00' , 'z32.01' , 'z32.02' ) THEN 'Pregnancy test'
		WHEN icd10.CODE IN ( 'z11.59' ) THEN 'STI Test' END ServiceType
		, e.Rendering_Provider Rendering_Provider , e.VisitType , e.EncNbr , e.PersonNbr , e.FirstName , e.LastName
	INTO #titlex_diagnosis
	FROM #titlex_encs e 
	 inner hash JOIN PAT_ENC_DX ON PAT_ENC_DX.PAT_ENC_CSN_ID = e.EncID JOIN EDG_CURRENT_ICD10 icd10 ON icd10.DX_ID = PAT_ENC_DX.DX_ID
	WHERE icd10.CODE IN ( 'T83.31' , 't83.32' , 't83.39' , 't83.49' , 't83.59' 
	 , 'z01.411' , 'z01.419' , 'z01.42' , 'z11.3' , 'z11.4' , 'z11.51' , 'z11.59' , 'z11.8' , 'z12.4' , 'z12.39' , 'z30.011' 
	 , 'z30.012' , 'z30.013' , 'z30.014' , 'z30.018' , 'z30.019' , 'z30.40' , 'z30.41' , 'z30.42' , 'z30.430' , 'z30.431' , 'z30.432' 
	 , 'z30.433' , 'z30.49' , 'z30.8' , 'z30.9' , 'z32.00' , 'z32.01'  , 'z31.41' , 'z31.430' , 'z31.438' , 'z31.440' , 'z31.338' , 'z31.5' 
	 , 'z31.61' , 'z31.69' , 'z31.81' , 'z31.82' , 'z31.89' , 'z31.9' , 'z71.7' -- CM -- CONTRACEPTIVE COUNSELING IS:  z30.0 , z30.02 , z30.09 : , 'Z30.02' , 'z30.09' , 'z30.0' -- PROCREATION COUNSELING - PREGNANCY COUNSELING IS Z31.6 : , 'z31.61' , 'z31.69' 
	 )  
	 or icd10.CODE LIKE 'Z08%' 
	 OR icd10.CODE LIKE 'T83.6%' ;
	 IF @ShowDebug_Bitflag = 1 
BEGIN 
    SELECT '#titlex_diagnosis' 
    select * from #titlex_diagnosis 
   END ;

	IF OBJECT_ID ( 'tempdb.dbo.#titlex_insurance' ) IS NOT NULL DROP TABLE #titlex_insurance
	SELECT practicecd , personid , visitgrp -- Affirm version says: If the Self-Pay field is coded as ‘Y’, then all other payment sources should be coded as ‘N’ and  If the Other Payment Source field is coded as ‘Y’, then all other payment sources should be coded as ‘N’
	 , TitleX , PublicIns , PrivateIns , SelfPay , TitleV , Other , PAT_ENC_CSN_ID 
	INTO #titlex_insurance /* Basically... Self Pay and "Other pay" cannot have anything else selected. */
	FROM ( SELECT practicecd , personid , VisitGrp 
	        , -- case when MAX ( Other ) = 'Y' then 'N' ELSE 
			MAX ( SelfPay ) -- END 
			SelfPay

			, CASE WHEN MAX ( SelfPay ) = 'Y' OR MAX ( Other ) = 'Y' OR 
			            /* Per Moira 4/4/2023
						   Medicaid (or AHCCCS) cannot be combined with Title X. 
						   This is because when Medicaid is an expected payer on the visit it will cover the entire cost of the visit and Title X will not be used. 
						   Forms of public insurance that do not cover the entire cost of the visit could be combined with Title X (Tricare for example). */
			            MAX ( PublicIns ) = 1 THEN 'N' ELSE MAX ( TitleX ) END TitleX 
			, CASE WHEN MAX ( SelfPay ) = 'Y' OR MAX ( Other ) = 'Y' THEN 0  ELSE MAX ( PublicIns  ) END PublicIns 
			, CASE WHEN MAX ( SelfPay ) = 'Y' OR MAX ( Other ) = 'Y' THEN 0  ELSE MAX ( PrivateIns ) END PrivateIns
			, CASE WHEN MAX ( SelfPay ) = 'Y' OR MAX ( Other ) = 'Y' THEN 0  ELSE MAX ( TitleV     ) END TitleV 
			, MAX ( Other ) Other 
			, PAT_ENC_CSN_ID
		   FROM ( SELECT x.practicecd , x.personid , x.VisitGrp -- , p.payor_name PayerName , p.FIN_CLASS_NAME PayerFinClass
		           /*, CASE 
				      WHEN 
					    p.payor_name like '%ahcccs%' or p.FIN_CLASS_NAME like '%ahcccs%' or p.payor_name like '%medicaid%' or p.FIN_CLASS_NAME like '%medicaid%' 
					   then 'Y' ELSE 'N' end medicaid_ind*/
					    c
					   				   , CASE WHEN -- p.PAYOR_NAME IS NULL OR P.FIN_CLASS_NAME IS NULL OR p.FIN_CLASS_NAME = 'Other' -- #20230424 SUSAN SAMPSON TIP
				    --  COVERAGE.COVERAGE_ID IS NULL 
					P.COVERAGE_ID IS NULL or epm.PAYOR_NAME is null
				   THEN 'Y' ELSE 'N' END SelfPay -- IF WE CAN'T FIND THE PAYER OR FIN CLASS THEN IT IS SELF PAY


				   , CASE WHEN Has_TitleX_bitflag = 1 THEN 'Y' ELSE 'N' END TitleX
				   , CASE WHEN p.FIN_CLASS_NAME LIKE '%medicaid%' OR 
				               p.FIN_CLASS_NAME LIKE '%medicare%' OR 
							   p.FIN_CLASS_NAME LIKE '%kidscare%' THEN 1 ELSE 0 END PublicIns
				   , CASE WHEN ( p.FIN_CLASS_NAME LIKE '%commercial%' or p.FIN_CLASS_NAME LIKE '%Blue Cross%' ) AND p.payor_name NOT LIKE '%Yoeme%' THEN 1 ELSE 0 END PrivateIns
				   , CASE WHEN p.payor_name LIKE '%title v%' THEN 1 ELSE 0 END TitleV
				   , CASE WHEN p.payor_name NOT LIKE '%title%' AND 
				               p.payor_name NOT LIKE '%ahcccs%' AND 
							   p.payor_name NOT LIKE '%medicaid%' AND 
							   p.payor_name NOT LIKE '%medicare%' AND ( 
							   p.FIN_CLASS_NAME = 'Other' OR P.FIN_CLASS_NAME = 'Tricare' ) THEN 'Y' ELSE 'N' END Other /* Per Moira on 02/24/32 Tricare is "public insurance" (both in expected payer source and "insured") THAT IS WHAT MOIRA SAID BUT THE SPEC SAYS:
							  6. Other Payment Source - A ‘Y’ indicates that a payment source other than any of the ones listed 
                                 above (e.g., Indian Health Service, Tricare) is expected to cover all the costs associated with 
                                 the visit. If the Other Payment Source field is coded as ‘Y’, then all other payment sources should be coded as ‘N’ */
				   , pat_enc.PAT_ENC_CSN_ID
			      FROM ( SELECT practicecd , personid , encID , VisitGrp FROM #titlex_encs UNION
				         SELECT practicecd , personid , encID , VisitGrp FROM #titlex_charges UNION
				         SELECT practicecd , personid , encID , VisitGrp FROM #titlex_screening UNION
				         SELECT practicecd , personid , encID , VisitGrp FROM #titlex_education UNION
				         SELECT practicecd , personid , encID , VisitGrp FROM #titlex_diagnosis UNION
				         SELECT practicecd , personid , encID , VisitGrp FROM #titlex_labs ) x 
				inner hash JOIN PAT_ENC ON -- PAT_ENC.PAT_ID = x.PersonID and CONTACT_DATE BETWEEN @start and @END
			  PAT_ENC.PAT_ENC_CSN_ID = x.EncID
			 LEFT JOIN V_COVERAGE_PAYOR_PLAN p ON p.COVERAGE_ID = PAT_ENC.COVERAGE_ID
			left join clarity.dbo.CLARITY_EPM epm on epm.PAYOR_ID=p.PAYOR_ID
			 LEFT JOIN ( SELECT PAT_ENC_CSN_ID , COUNT ( DISTINCT CASE WHEN SLIDSCALE_OVERTIME.SPECIAL_HANDLING_C = 1 THEN PAT_ENC_CSN_ID 
											                           ELSE NULL END ) Has_TitleX_bitflag
				         FROM ARPB_TRANSACTIONS LEFT JOIN ARPB_TX_SST ON ARPB_TRANSACTIONS.TX_ID = ARPB_TX_SST.TX_ID
				          LEFT JOIN SLIDSCALE_OVERTIME ON SLIDSCALE_OVERTIME.TABLE_ID = ARPB_TX_SST.SST_USED_ID
				         WHERE VOID_DATE IS NULL AND TX_TYPE_C = 1
				         GROUP BY PAT_ENC_CSN_ID ) ARPB_TitleX ON ARPB_TitleX.PAT_ENC_CSN_ID = PAT_ENC.PAT_ENC_CSN_ID 
			) Y
		GROUP BY practicecd , personid , VisitGrp , PAT_ENC_CSN_ID ) Z
	WHERE VisitGrp IS NOT NULL ;
	IF @ShowDebug_Bitflag = 1 BEGIN SELECT '#titlex_insurance' select * from #titlex_insurance END ;

	IF OBJECT_ID ( 'tempdb.dbo.#titlex_fpEncs' ) IS NOT NULL DROP TABLE #titlex_fpEncs
	SELECT e.PracticeCd , e.PersonID , e.EncID , e.VisitGrp , e.EncDate 
	 , CASE WHEN ( e.fin_class_c = '4' OR COALESCE ( e.PAYOR_NAME , 'Self-Pay' ) LIKE '%SELF%' ) AND coalesce ( fpl.fpl_percentage , 0 ) < 251
             THEN 'Title X' ELSE COALESCE ( e.PAYOR_NAME , 'Self-Pay' ) END payer1
	 , e.finclass 
	 , e.ProviderID 
	 , e.LocationName
	 , e.DateOfBirth
	 , e.MRN
	 , e.Zip
	 , ZC_SEX.ABBR Sex
	 , COALESCE ( so.sexual_orientation , 0 ) sexo
	 , CASE WHEN e.Ethnicity = 1 -- Not Hispanic, Latino/a, or Spanish origin
	      THEN 2 -- 2 = Not Hispanic or Latino 
	     WHEN COALESCE ( e.Ethnicity , 9 ) IN ( 3 , 4 , 9 ) -- 3 = Unknown  4 = Decline to Answer 9 = Unreported/Refused
	      THEN 0 -- 0 = Unknown/Not Reported
	     ELSE 1 -- hISPANIC OR LATINO  
		END Ethnicity -- , #titlex_encs.UdsRaceDesc
	 , COALESCE ( e.LEP , 'N' ) LEP 
	 , COALESCE ( #titlex_primaryCharge.PrimaryCharge , #titlex_primaryCharge_backup.PrimaryCharge ) PrimaryCharge 
	 , #titlex_charges.EncID ChargeEncID
	 , #titlex_charges.CptCd ChargeCpt
	 , #titlex_charges.ServiceType ChargeType
	 , #titlex_screening.EncID ScreenEncID
	 , #titlex_screening.ScreeningTYpe ScreenType
	 , #titlex_education.EncID EducationEncID
	 , #titlex_education.CategoryDetail CategoryDetail
	 , #titlex_education.EducationType EducationType
	 , #titlex_diagnosis.EncID DiagnosisEncID
	 , #titlex_diagnosis.DiagCd DiagnosisDiagCd
	 , #titlex_diagnosis.ServiceType DiagnosisType
	 , #titlex_labs.EncID LabEncID 
	 , e.Rendering_Provider Rendering_Provider
	 , e.VisitType
	 , e.EncNbr
	 , e.PersonNbr
	 , e.FirstName
	 , e.LastName 
	 , #titlex_labs.pap_result
	 , #titlex_labs.HPV_result
     , #titlex_labs.chlam_result
	 , #titlex_labs.gc_result
	 , #titlex_labs.hiv_result
	 , #titlex_labs.vdrl_result
	 , COALESCE ( #titlex_labs.pt_result , 0 ) pt_result 
	 , e.provider_name -- #CM
	 , CASE WHEN ZC_DISP_ENC_TYPE.NAME LIKE '%TELE%' OR e.VisitType LIKE '%TELE%' THEN 1 ELSE 2 END Telehealth
	 , COALESCE ( e.SYSTOLIC , 0 ) SYSTOLIC
	 , COALESCE ( e.DIASTOLIC , 0 ) DIASTOLIC
	 , coalesce ( ElRio.TitleX_getMaxHeight ( e.PersonID ) , '0' ) HEIGHT
	 , COALESCE ( e.[WEIGHT] * 0.0625 , 0 ) [WEIGHT]
	 , COALESCE ( T.TOBACCO , 0 ) TOBACCO

	 /*
	Per Moira, Gender and sexual orientation was coming in wrong. #CM7.9.2024
	This was the previous code. 
	 , CASE WHEN COALESCE ( patient_4.GENDER_IDENTITY_C , 6 ) = 6 THEN 0
	        WHEN patient_4.GENDER_IDENTITY_C = 5 THEN 6 ELSE patient_4.GENDER_IDENTITY_C END gender
	*/
	 , CASE WHEN COALESCE ( patient_4.GENDER_IDENTITY_C , 6 ) = 6 THEN 0
	       WHEN patient_4.GENDER_IDENTITY_C = 5 AND G.SMRTDTA_ELEM_VALUE Like '%Non%binary%' THEN 5 
		   WHEN patient_4.GENDER_IDENTITY_C = 5 AND G.SMRTDTA_ELEM_VALUE <> '%Non%binary%' THEN 6 
	       WHEN patient_4.GENDER_IDENTITY_C = 5 AND G.SMRTDTA_ELEM_VALUE IS NULL THEN 6       
			ELSE patient_4.GENDER_IDENTITY_C END Gender

	 , CASE when e.provider_numeric = 'Physician' then 1
		WHEN e.provider_numeric = 'Midwife' then 2
		when e.provider_numeric = 'Physician Assistant' then 3 
		when e.provider_numeric = 'Nurse Practitioner' then 4
		when e.provider_numeric In ( 'Registered Nurse' , 'Licensed Nurse' , 'Nurse Specialist' ) then 5 else 6 end provider_numeric
	 , COALESCE ( ser2.npi , '0' ) NPI 
	 , case when 3 IN ( SELECT V.PATIENT_RACE_C FROM PATIENT_RACE V where V.pat_id = e.PersonID ) THEN 'Y' ELSE 'N' END AI -- Am Indian
     , case WHEN 14 IN ( SELECT V.PATIENT_RACE_C FROM PATIENT_RACE V where V.pat_id = e.PersonID ) OR 
	      9  in ( SELECT V.PATIENT_RACE_C FROM PATIENT_RACE V where V.pat_id = e.PersonID ) OR
          20 in ( SELECT V.PATIENT_RACE_C FROM PATIENT_RACE V where V.pat_id = e.PersonID ) OR
          11 in ( select V.PATIENT_RACE_C from PATIENT_RACE V where V.pat_id = e.PersonID ) OR
          21 in ( select V.PATIENT_RACE_C from PATIENT_RACE V where V.pat_id = e.PersonID ) OR
          12 in ( select V.PATIENT_RACE_C from PATIENT_RACE V where V.pat_id = e.PersonID ) OR
          23 in ( select V.PATIENT_RACE_C from PATIENT_RACE V where V.pat_id = e.PersonID ) OR
          4 in  ( select V.PATIENT_RACE_C from PATIENT_RACE V where V.pat_id = e.PersonID ) OR
          13 in ( select V.PATIENT_RACE_C from PATIENT_RACE V where V.pat_id = e.PersonID ) THEN 'Y' ELSE 'N' END Asian
  , case when 2 IN ( SELECT V.PATIENT_RACE_C FROM PATIENT_RACE V where V.pat_id = e.PersonID ) THEN 'Y' ELSE 'N' END AA -- Black
  , case when 10 in ( select V.PATIENT_RACE_C from PATIENT_RACE V where V.pat_id = e.PersonID ) OR
           22 in ( select V.PATIENT_RACE_C from PATIENT_RACE V where V.pat_id = e.PersonID ) OR
		   15 in ( select V.PATIENT_RACE_C from PATIENT_RACE V where V.pat_id = e.PersonID ) OR
		   18 in ( select V.PATIENT_RACE_C from PATIENT_RACE V where V.pat_id = e.PersonID ) OR
		   5 in ( select V.PATIENT_RACE_C from PATIENT_RACE V where V.pat_id = e.PersonID ) THEN 'Y' ELSE 'N' END NH
  , CASE WHEN 1 IN ( SELECT V.PATIENT_RACE_C 
                     FROM PATIENT_RACE V where V.pat_id = e.PersonID ) THEN 'Y' ELSE 'N' END [White] 
  , COALESCE ( pregintent.Preg_Intent , 0 ) preg_intent -- 31
  , #titlex_diagnosis.ServiceType ServiceType
,  COALESCE ( fpl.fpl_income , -1 )  Income -- #20230331 PER mOIRA 
    -- If there is no income reported, enter 0 for both income and household size. If income reported is 0, do not change household size

	/*this statement is checking if there is a valid value for the household size and income level. If there is no value for the income, 
	then the household size cannot be determined and is set to 0.
	If there is a value for the income, then the household size is set to the value in fpl_family_size, or 0 if it is NULL.*/
 -- , CASE 
 --    WHEN fpl.fpl_income IS NULL 
	--  THEN 0
 --    ELSE
 --     COALESCE ( fpl.fpl_family_size , 0 ) --#Made the change from 1 to 0
	--END Household_Size
  ,coalesce(fpl.fpl_family_size , 0) Household_Size
 , coalesce ( fpl.fpl_percentage , 0 ) percent_fpl
  , e.INPATIENT_DATA_ID
  , e.DEPARTMENT_ID
  , e.SPECIALTY -- CM
  , COALESCE ( bcounsel.BC_Counsel , 'N' ) BC_Counsel -- 30
  , COALESCE ( pregcounsel.Preg_Counsel , 'N' ) Preg_Counsel -- 32
  , COALESCE ( before_c.Before_Method , 0 ) before_method -- 34 before_method
  , COALESCE ( dispensed.Primary_Method , 0 ) primary_method -- 35 primary_method
  , COALESCE ( dispensed.DISPENSED , 4 ) Dispensed -- 36
  ,e.copay
 INTO #titlex_fpEncs
 FROM #titlex_encs e 
  inner hash JOIN dbo.PATIENT_4 ON patient_4.PAT_ID = e.PersonID
  inner hash JOIN dbo.ACCOUNT_FPL_INFO fpl on fpl.ACCOUNT_ID = e.ACCOUNT_ID -- must be join , also  used in filter
  left join ZC_SEX ON ZC_SEX.RCPT_MEM_SEX_C = e.Sex
  LEFT JOIN #titlex_primaryCharge        ON e.VisitGrp = #titlex_primaryCharge.VisitGrp -- e.EncID = #titlex_primaryCharge.EncNbr
  LEFT JOIN #titlex_primaryCharge_backup ON -- e.VisitGrp = #titlex_primaryCharge_backup.VisitGrp
   e.EncID = #titlex_primaryCharge_backup.EncNbr
  LEFT JOIN #titlex_charges              ON -- e.VisitGrp = #titlex_charges.VisitGrp
   e.EncID = #titlex_charges.EncID
  LEFT JOIN #titlex_screening            ON -- e.VisitGrp = #titlex_screening.VisitGrp
   e.EncID = #titlex_screening.EncID
  LEFT JOIN #titlex_education            ON -- e.VisitGrp = #titlex_education.VisitGrp
   e.EncID = #titlex_education.EncID
  LEFT JOIN #titlex_diagnosis            ON -- e.VisitGrp = #titlex_diagnosis.VisitGrp
   e.EncID = #titlex_diagnosis.EncID
  LEFT JOIN #titlex_labs ON e.VisitGrp = #titlex_labs.VisitGrp --  e.EncID = #titlex_labs.EncID 
  left join clarity_ser_2 ser2 on ser2.PROV_ID = e.ProviderID 
  LEFT JOIN [ElRio].[v_TitleX_Tobacco] T on T.PAT_ID = e.PersonID AND T.RN = 1 -- THE LATEST INFORMATION WE HAVE ON TOBACCO
  LEFT JOIN ZC_DISP_ENC_TYPE ON ZC_DISP_ENC_TYPE.DISP_ENC_TYPE_C = e.ENC_TYPE_C 
  LEFT JOIN [ElRio].[v_TitleX_Sexual_Orientation] so on so.PAT_ID = e.PersonID -- #CM20230317
  left join [ElRio].v_TitleX_ReproductiveFlowSheet bcounsel on bcounsel.pat_enc_csn_id = e.EncID AND bcounsel.Titlex_item = 30 -- bc_counsel contraceptive counseling was provided
  LEFT JOIN [ElRio].v_TitleX_ReproductiveFlowSheet pregintent on pregintent.PAT_ENC_CSN_ID = e.EncID AND pregintent.Titlex_item = 31 -- preg intent
  LEFT JOIN [ElRio].v_TitleX_ReproductiveFlowSheet pregcounsel on pregcounsel.PAT_ENC_CSN_ID = e.EncID AND pregcounsel.Titlex_item = 32 -- preg counsel
  left join [ElRio].v_TitleX_ReproductiveFlowSheet before_c ON before_c.PAT_ENC_CSN_ID = e.EncID and before_c.TITLEX_ITEM = 34 -- for items 34 and 35. before and after
  left join [ElRio].v_TitleX_ReproductiveFlowSheet dispensed on dispensed.pat_enc_csn_id = e.EncID AND dispensed.Titlex_item = 35 -- dispensed
  Left Join [ElRio].[V_TitleX_Gender] G ON G.PAT_ID= E.PersonID --#CM7.9.24 Per Moira, asked for an update to Gender and orientation because of the epic updates. 
 WHERE fpl.LINE = 1 ;
 	IF @ShowDebug_Bitflag = 1 BEGIN SELECT '#titlex_fpEncs' select * from #titlex_fpEncs END ;

		   IF OBJECT_ID ( 'tempdb.dbo.#titlex_taxonomy' ) IS NOT NULL DROP TABLE #titlex_taxonomy 
   SELECT tax.VisitGrp , tax.ProviderID , ProviderName , tax.Specialty , tax.ProviderSubgrp , tax.AFHPProviderValue , tax.EncID
   INTO #titlex_taxonomy /*#titlex_taxonomy get all the providers associated with this visit and then get the highest one*/
   FROM ( SELECT VisitGrp , CASE WHEN ZC_LICENSE_DISPLAY.NAME IN ( 'RN' , 'LPN' ) THEN 3 -- RN
				             WHEN ZC_LICENSE_DISPLAY.NAME IN ( 'PA'	, 'NP' , 'FNP' , 'CNM' , 'PMHNP' ) THEN 2 -- NP, PA, CNMs
				             WHEN ZC_LICENSE_DISPLAY.NAME IN ( 'MD' , 'DO' )	THEN 1	ELSE 4 END AFHPProviderValue
		   , ROW_NUMBER() OVER ( PARTITION BY VisitGrp ORDER BY CASE WHEN ZC_LICENSE_DISPLAY.NAME IN ( 'RN' , 'LPN' ) THEN 3 -- RN
				                                                 WHEN ZC_LICENSE_DISPLAY.NAME IN ( 'PA' , 'NP' , 'FNP' , 'CNM' , 'PMHNP' ) THEN 2 -- NP, PA, CNMs
				                                                 WHEN ZC_LICENSE_DISPLAY.NAME IN ( 'MD' , 'DO' ) THEN 1 ELSE 4 END ASC ) RN
		   , ProviderID , fp.provider_name ProviderName , fp.SPECIALTY Specialty , ZC_LICENSE_DISPLAY.NAME ProviderSubgrp , fp.EncID
		  FROM #titlex_fpEncs fp 
		   inner hash JOIN CLARITY_SER_2 ON CLARITY_SER_2.PROV_ID = fp.ProviderID
		   LEFT JOIN ZC_LICENSE_DISPLAY ON ZC_LICENSE_DISPLAY.LICENSE_DISPLAY_C = CUR_CRED_C ) tax
	WHERE rn = 1 ;
	 	IF @ShowDebug_Bitflag = 1 BEGIN SELECT '#titlex_taxonomy' select * from #titlex_taxonomy END ;

	IF OBJECT_ID ( 'tempdb.dbo.#titlex_final' ) IS NOT NULL DROP TABLE #titlex_final 
	SELECT Delegate , MAX ( [Health Center] ) [Health Center] , Client --> THIS IS THE EPIC MRN
	 , MAX ( [Household Income] ) [Household Income]
	 , MAX ( [Household Size] ) [Household Size]
	 , MAX ( TitleX ) [TitleX]
	 , MAX ( PublicIns ) [PublicIns]
	 , MAX ( PrivateIns ) [PrivateIns]
	 , MAX ( SelfPay ) [SelfPay]
	 , MAX ( [TitleV] ) [TitleV]
	 , MAX ( [OtherPay] ) [OtherPay]
	 , VisitDate
	 , MAX ( Zip ) [Zip]
	 , MAX ( Sex ) [Sex]
	 , max ( X.AI ) AI
     , max ( X.Asian ) Asian
     , max ( X.AA ) AA
     , max ( X.NH ) NH
     , max ( X.White ) White
	 , MAX ( X.Ethnicity ) Ethnicity
	 , MAX ( DoB ) [DOB]
	 , COALESCE ( MAX ( [CPT Code] ) , '' ) [CPT Code] 
	 , MAX ( [Before] ) [Before]
	 , MAX ( [Primary] ) [Primary]
	 , MAX ( PtResult ) [PtResult]
	 , MAX ( PrivIns ) [PrivIns] 
	 , MAX ( PubIns ) [PubIns]
	 , MAX ( LEP ) [LEP]
	 , MIN ( PapResult ) [Pap] 
	 , MIN ( HPVResult ) [HPV]
	 , MIN ( CTResult ) [Chlam] 
	 , MIN ( GCResult ) GC
	 , MIN ( VDRLresult ) [Syphilis]
	 , MIN ( HIVresult ) [HIV]
	 , MAX ( Rendering_Provider ) [Final_Rendering_Provider]
	 , MAX ( VisitType ) VisitType
	 , Max ( EncNbr ) EncNbr
	 , Max ( PersonNbr ) PersonNbr
	 , MAX ( FirstName ) FirstName
	 , MAX ( LastName ) LastName
	 , VisitGrp
	 , provider_name [provider_name] -- #CM
	 , max ( Telehealth ) Telehealth
	 , max ( SYSTOLIC ) Systolic
	 , max ( DIASTOLIC ) Diastolic
	 , max ( HEIGHT ) height
	 , max ( [WEIGHT] ) [weight]
	 , Max ( TOBACCO ) tobacco
	 , gender gender
	 , sexo
	 , max ( [provider_numeric] ) [provider_numeric] --> this is numeric
	 , max ( NPI ) NPI
	 , max ( preg_intent ) preg_intent
	 , max ( x.bc_counsel ) BC_Counsel
	 , max ( x.preg_counsel ) Preg_Counsel
	 , MIN ( X.DISPENSED ) Dispensed
	 , Comment
	INTO #titlex_final 
	FROM ( SELECT @delegateID Delegate , CASE WHEN LocationName LIKE '%northwest%' THEN @siteHCIDNW
				                          WHEN LocationName LIKE '%el pueblo%' THEN @siteHCIDEP
				                          WHEN LocationName LIKE '%congress%' THEN @siteHCIDCong ELSE - 99 END [Health Center]
			, fp.MRN [Client]
			, fp.Income [Household Income]
			, fp.Household_Size [Household Size]

			  /*Title X - A ‘Y’ indicates that Title X (“ten”) is expected to cover part, or all, of the costs associated with the visit. An ‘N’ indicates that Title X is not an expected payment source for 
                any services associated with the visit. Example of Title X as expected payer source: Clients who are uninsured and at or below 250% FPL; clients who seek a confidential visit. Title X is a valid 
                payment source in conjunction with Title V, Private Insurance, Public Insurance, or on its own*/
			, CASE 
			   When fp.Income= -1  then 'N'
			   WHEN 
			            PERCENT_FPL IS NOT NULL AND 
			            PERCENT_FPL <= 250.0 AND 
						PERCENT_FPL >= 0.0 AND
						Household_Size >=0 And
						 --FP.copay IS Not Null  AND
						--#titlex_insurance.SelfPay = 'N' AND 
						#titlex_insurance.Other = 'N' AND 
						#TITLEX_INSURANCE.PublicIns = 0
						then 'Y' 
						
						ELSE #titlex_insurance.TitleX 
			  END TitleX
             , Case when fp.Income =-1 then 'No Income In Epic, Does Not Quality'
			           END Comment

			, CASE WHEN #titlex_insurance.PublicIns = 1 AND #titlex_insurance.SelfPay = 'N' AND #titlex_insurance.Other = 'N' THEN 'Y' ELSE 'N' END [PublicIns]
			, CASE WHEN #titlex_insurance.PrivateIns = 1 AND #titlex_insurance.SelfPay = 'N' AND #titlex_insurance.Other = 'N' THEN 'Y' ELSE 'N' END [PrivateIns]

			  /* Self-Pay - A ‘Y’ indicates that the client is expected to cover all the costs associated with the visit. 
			     Example of Self-pay expected payer source: Clients above 250% FPL and pay self-pay 
                 fees. If the Self-Pay field is coded as ‘Y’, then all other payment sources should be coded as ‘N’ */
			, CASE 
			WHEN PERCENT_FPL > 250.0 AND #titlex_insurance.SelfPay = 'Y'-- AND #TITLEX_INSURANCE.Other = 'N' 
			  then 'Y' 
			When PERCENT_FPL <= 250.0 AND #titlex_insurance.PrivateIns = 1  AND #titlex_insurance.SelfPay = 'Y' And FP.copay IS Not Null  
			   then 'N'
			WHEN PERCENT_FPL <= 250.0 And  #titlex_insurance.PrivateIns = 0 And   #titlex_insurance.PublicIns=0   AND #titlex_insurance.SelfPay = 'Y'  
			 Then 'N'
			else #titlex_insurance.SelfPay 
			END 
			SelfPay

			, CASE WHEN #titlex_insurance.TitleV = 1 AND #titlex_insurance.SelfPay = 'N' AND #titlex_insurance.Other = 'N' THEN 'Y' ELSE 'N' END [TitleV]

			, #titlex_insurance.Other [OtherPay]

			, fp.EncDate [VisitDate] 
			, LEFT ( fp.Zip , 5 ) [Zip] 
			, fp.Sex [Sex] 
			, fp.AI 
			, fp.Asian 
			, fp.AA 
			, fp.NH 
			, fp.White 
			, fp.Ethnicity 
			, CONVERT ( NVARCHAR , fp.DateOfBirth , 101 ) [DOB]
			, fp.PrimaryCharge [CPT Code] 
			, fp.before_method [Before] -- Contraceptive Method (before the visit) 
			, fp.primary_method [Primary] -- Primary Method (at the end of this visit) --
			, CASE WHEN Sex <> 'M' -- AND fp.LabType LIKE '%pregnan%' 
			   THEN fp.pt_result ELSE '0' END Ptresult
			, CASE WHEN #titlex_insurance.PrivateIns = 1 AND #titlex_insurance.SelfPay = 'N' AND #titlex_insurance.Other = 'N' THEN 'Y' ELSE 'N' END [PrivIns] -- look at the pdf
			, CASE WHEN #titlex_insurance.PublicIns = 1 AND #titlex_insurance.SelfPay = 'N' AND #titlex_insurance.Other = 'N' THEN 'Y' ELSE 'N' END [PubIns] -- look at the pdf
			, fp.LEP 
			, CASE WHEN Sex <> 'M' -- AND fp.LabType LIKE '%pap%' 
			   THEN fp.pap_result ELSE '0' END PapResult 
			, -- CASE WHEN fp.LabType LIKE '%hpv%' THEN fp.HPV_RESULT   ELSE '0' END 
			  fp.HPV_RESULT HPVresult
			, -- CASE WHEN fp.LabType LIKE '%chlam%' THEN fp.chlam_result ELSE '0' END 
			  fp.chlam_result Ctresult
			, -- CASE WHEN fp.LabType LIKE '%gono%' THEN fp.gc_result ELSE '0' END 
			  fp.gc_result GCresult
			, -- CASE WHEN fp.LabType LIKE '%syphilis%' OR fp.LabType LIKE '%VDRL%' THEN fp.vdrl_result ELSE '0' END 
			  fp.vdrl_result VDRLresult
		    , -- CASE WHEN fp.LabType LIKE '%HIV%' THEN fp.HIV_RESULT ELSE '0' END 
			  fp.HIV_RESULT HIVresult
			, Rendering_Provider 
			, fp.VisitType 
			, fp.EncNbr 
			, fp.PersonNbr 
			, fp.FirstName 
			, fp.LastName 
			, fp.percent_fpl PERCENT_FPL --#CM20230221
			, fp.VisitGrp 
			, fp.provider_name provider_name 
			, fp.Telehealth 
			, fp.SYSTOLIC 
			, fp.DIASTOLIC
			, fp.HEIGHT 
			, fp.WEIGHT 
			, COALESCE ( fp.TOBACCO , 0 ) tobacco
			, fp.gender 
			, fp.sexo 
			, fp.provider_numeric 
			, fp.NPI 
			, fp.preg_intent
			, fp.bc_counsel BC_Counsel
			, fp.preg_counsel Preg_Counsel
			, fp.DISPENSED -- How was contraceptive method provided? ITEM 36
		FROM #titlex_fpEncs fp 
		 inner hash JOIN #titlex_insurance ON -- fp.visitGRP = #titlex_insurance.visitGRP
		  fp.EncID = #titlex_insurance.PAT_ENC_CSN_ID
		 inner hash JOIN #titlex_taxonomy ON  -- fp.VisitGrp = #titlex_taxonomy.VisitGrp 
		  fp.EncID = #titlex_taxonomy.EncID ) X
		  --WHERE [Before] NOT IN ('4','5')  --#CM7.7.23 Per Moira she wanted it to fillter out these two. 
		  --#CM7.27.23 Moira wanted to go back to old version
    GROUP BY Delegate , [Household Income], Client , Comment, VisitDate , Rendering_Provider , VisitType , EncNbr , PersonNbr , FirstName , LastName , VisitGrp 
	 , provider_name , gender , sexo , preg_intent
	HAVING MAX ( [Health Center] ) > 0
	DELETE FROM #titlex_final WHERE LEN ( [CPT Code] ) = 0 -- can't have no CPT code
	DELETE #titlex_final WHERE ISNUMERIC ( Client ) = 0 -- let's weed out this patient altogether
	IF @ShowDebug_Bitflag = 1
	 BEGIN
	  SELECT 'SELECT * FROM #titlex_final'
	  SELECT * FROM #titlex_final
	 END

	IF @ShowDebug_Bitflag = 1
	 BEGIN
	  SELECT 'SELECT Helper Stats'
	  SELECT 1 STATORDER ,'Health Center (DISTINCT)' STATNAME,COUNT (DISTINCT [Health Center]) stat FROM #titlex_final UNION ALL
      SELECT 2 STATORDER ,'Client (DISTINCT)' STATNAME,COUNT (DISTINCT [Client]) stat FROM #titlex_final UNION ALL
      SELECT 3 STATORDER,'Household Income (>0)' STATNAME,SUM(CASE WHEN TRY_CONVERT(INT,[Household Income])>0 THEN 1 ELSE 0 END)  stat FROM #titlex_final UNION ALL
      SELECT 4 STATORDER,'Household Size (>0)' STATNAME,SUM(CASE WHEN TRY_CONVERT(INT,[Household Size])>0 THEN 1 ELSE 0 END)  stat FROM #titlex_final UNION ALL
      SELECT 5 STATORDER,'TitleX - '+CONVERT(VARCHAR(MAX),[TitleX]) STATNAME,CONVERT(DECIMAL(5,1),COUNT (1) OVER (PARTITION BY [TitleX]) / SUM(1.0) OVER () * 100.0 )  stat FROM #titlex_final  UNION ALL
      SELECT 6 STATORDER,'PublicIns - '+CONVERT(VARCHAR(MAX),[PublicIns]) STATNAME,CONVERT(DECIMAL(5,1),COUNT (1) OVER (PARTITION BY [PublicIns]) / SUM(1.0) OVER () * 100.0 )  stat FROM #titlex_final  UNION ALL
      SELECT 7 STATORDER,'PrivateIns - '+CONVERT(VARCHAR(MAX),[PrivateIns]) STATNAME,CONVERT(DECIMAL(5,1),COUNT (1) OVER (PARTITION BY [PrivateIns]) / SUM(1.0) OVER () * 100.0 )  stat FROM #titlex_final  UNION ALL
      SELECT 8 STATORDER,'SelfPay - '+CONVERT(VARCHAR(MAX),[SelfPay]) STATNAME,CONVERT(DECIMAL(5,1),COUNT (1) OVER (PARTITION BY [SelfPay]) / SUM(1.0) OVER () * 100.0 )  stat FROM #titlex_final  UNION ALL
      SELECT 9 STATORDER,'TitleV - '+CONVERT(VARCHAR(MAX),[TitleV]) STATNAME,CONVERT(DECIMAL(5,1),COUNT (1) OVER (PARTITION BY [TitleV]) / SUM(1.0) OVER () * 100.0 )  stat FROM #titlex_final  UNION ALL
      SELECT 10 STATORDER,'OtherPay - '+CONVERT(VARCHAR(MAX),[OtherPay]) STATNAME,CONVERT(DECIMAL(5,1),COUNT (1) OVER (PARTITION BY [OtherPay]) / SUM(1.0) OVER () * 100.0 )  stat FROM #titlex_final  UNION ALL
      SELECT 11 STATORDER,'VisitDate - '+CONVERT(VARCHAR(MAX),[VisitDate]) STATNAME,CONVERT(DECIMAL(5,1),COUNT (1) OVER (PARTITION BY [VisitDate]) / SUM(1.0) OVER () * 100.0 )  stat FROM #titlex_final  UNION ALL
      SELECT 12 STATORDER,'Zip - '+CONVERT(VARCHAR(MAX),[Zip]) STATNAME,CONVERT(DECIMAL(5,1),COUNT (1) OVER (PARTITION BY [Zip]) / SUM(1.0) OVER () * 100.0 )  stat FROM #titlex_final  UNION ALL
      SELECT 13 STATORDER,'Sex - '+CONVERT(VARCHAR(MAX),[Sex]) STATNAME,CONVERT(DECIMAL(5,1),COUNT (1) OVER (PARTITION BY [Sex]) / SUM(1.0) OVER () * 100.0 )  stat FROM #titlex_final  UNION ALL
      SELECT 14 STATORDER,'AI - '+CONVERT(VARCHAR(MAX),[AI]) STATNAME,CONVERT(DECIMAL(5,1),COUNT (1) OVER (PARTITION BY [AI]) / SUM(1.0) OVER () * 100.0 )  stat FROM #titlex_final  UNION ALL
      SELECT 15 STATORDER,'Asian - '+CONVERT(VARCHAR(MAX),[Asian]) STATNAME,CONVERT(DECIMAL(5,1),COUNT (1) OVER (PARTITION BY [Asian]) / SUM(1.0) OVER () * 100.0 )  stat FROM #titlex_final  UNION ALL
      SELECT 16 STATORDER,'AA - '+CONVERT(VARCHAR(MAX),[AA]) STATNAME,CONVERT(DECIMAL(5,1),COUNT (1) OVER (PARTITION BY [AA]) / SUM(1.0) OVER () * 100.0 )  stat FROM #titlex_final  UNION ALL
      SELECT 17 STATORDER,'NH - '+CONVERT(VARCHAR(MAX),[NH]) STATNAME,CONVERT(DECIMAL(5,1),COUNT (1) OVER (PARTITION BY [NH]) / SUM(1.0) OVER () * 100.0 )  stat FROM #titlex_final  UNION ALL
      SELECT 18 STATORDER,'White - '+CONVERT(VARCHAR(MAX),[White]) STATNAME,CONVERT(DECIMAL(5,1),COUNT (1) OVER (PARTITION BY [White]) / SUM(1.0) OVER () * 100.0 )  stat FROM #titlex_final  UNION ALL
      SELECT 19 STATORDER,'Ethnicity - '+CONVERT(VARCHAR(MAX),[Ethnicity]) STATNAME,CONVERT(DECIMAL(5,1),COUNT (1) OVER (PARTITION BY [Ethnicity]) / SUM(1.0) OVER () * 100.0 )  stat FROM #titlex_final  UNION ALL
      SELECT 21 STATORDER,'CPT Code - '+CONVERT(VARCHAR(MAX),[CPT Code]) STATNAME,CONVERT(DECIMAL(5,1),COUNT (1) OVER (PARTITION BY [CPT Code]) / SUM(1.0) OVER () * 100.0 )  stat FROM #titlex_final  UNION ALL
      SELECT 22 STATORDER,'Pap - '+CONVERT(VARCHAR(MAX),[Pap]) STATNAME,CONVERT(DECIMAL(5,1),COUNT (1) OVER (PARTITION BY [Pap]) / SUM(1.0) OVER () * 100.0 )  stat FROM #titlex_final  UNION ALL -- SELECT DISTINCT 23 STATORDER,'Breast - '+CONVERT(VARCHAR(MAX),[Breast]) STATNAME,CONVERT(DECIMAL(5,1),COUNT (1) OVER (PARTITION BY [Breast]) / SUM(1.0) OVER () * 100.0 )  stat FROM #titlex_final  UNION ALL
      SELECT 24 STATORDER,'VDRL - '+CONVERT(VARCHAR(MAX),[Syphilis]) STATNAME,CONVERT(DECIMAL(5,1),COUNT (1) OVER (PARTITION BY [Syphilis]) / SUM(1.0) OVER () * 100.0 )  stat FROM #titlex_final  UNION ALL
      SELECT 25 STATORDER,'GC - '+CONVERT(VARCHAR(MAX),[GC]) STATNAME,CONVERT(DECIMAL(5,1),COUNT (1) OVER (PARTITION BY [GC]) / SUM(1.0) OVER () * 100.0 )  stat FROM #titlex_final  UNION ALL
      SELECT 26 STATORDER,'Chlam - '+CONVERT(VARCHAR(MAX),[Chlam]) STATNAME,CONVERT(DECIMAL(5,1),COUNT (1) OVER (PARTITION BY [Chlam]) / SUM(1.0) OVER () * 100.0 )  stat FROM #titlex_final  UNION ALL
      SELECT 27 STATORDER,'HIV - '+CONVERT(VARCHAR(MAX),[HIV]) STATNAME,CONVERT(DECIMAL(5,1),COUNT (1) OVER (PARTITION BY [HIV]) / SUM(1.0) OVER () * 100.0 )  stat FROM #titlex_final  UNION ALL
      SELECT 28 STATORDER,'Before - '+CONVERT(VARCHAR(MAX),[Before]) STATNAME,CONVERT(DECIMAL(5,1),COUNT (1) OVER (PARTITION BY [Before]) / SUM(1.0) OVER () * 100.0 )  stat FROM #titlex_final  UNION ALL
      SELECT 29 STATORDER,'Primary - '+CONVERT(VARCHAR(MAX),[Primary]) STATNAME,CONVERT(DECIMAL(5,1),COUNT (1) OVER (PARTITION BY [Primary]) / SUM(1.0) OVER () * 100.0 )  stat FROM #titlex_final  UNION ALL
      SELECT 30 STATORDER,'Provider_numeric - '+CONVERT(VARCHAR(MAX),[Provider_numeric]) STATNAME,CONVERT(DECIMAL(5,1),COUNT (1) OVER (PARTITION BY [Provider_numeric]) / SUM(1.0) OVER () * 100.0 ) stat FROM #titlex_final  UNION ALL
      SELECT 31 STATORDER,'PtResult - '+CONVERT(VARCHAR(MAX),[PtResult]) STATNAME,CONVERT(DECIMAL(5,1),COUNT (1) OVER (PARTITION BY [PtResult]) / SUM(1.0) OVER () * 100.0 ) stat FROM #titlex_final  UNION ALL
      SELECT 32 STATORDER,'PrivIns - '+CONVERT(VARCHAR(MAX),[PrivIns]) STATNAME,CONVERT(DECIMAL(5,1),COUNT (1) OVER (PARTITION BY [PrivIns]) / SUM(1.0) OVER () * 100.0 ) stat FROM #titlex_final  UNION ALL
      SELECT 33 STATORDER,'PubIns - '+CONVERT(VARCHAR(MAX),[PubIns]) STATNAME,CONVERT(DECIMAL(5,1),COUNT (1) OVER (PARTITION BY [PubIns]) / SUM(1.0) OVER () * 100.0 ) stat FROM #titlex_final  UNION ALL
      SELECT 34 STATORDER,'LEP - '+CONVERT(VARCHAR(MAX),[LEP]) STATNAME,CONVERT(DECIMAL(5,1),COUNT (1) OVER (PARTITION BY [LEP]) / SUM(1.0) OVER () * 100.0 ) stat FROM #titlex_final  UNION ALL
      SELECT 35 STATORDER,'Pap - '+CONVERT(VARCHAR(MAX),[Pap]) STATNAME,CONVERT(DECIMAL(5,1),COUNT (1) OVER (PARTITION BY [Pap]) / SUM(1.0) OVER () * 100.0 )  stat FROM #titlex_final  UNION ALL  -- SELECT DISTINCT 36 STATORDER,'BrstRef - '+CONVERT(VARCHAR(MAX),[BrstRef]) STATNAME,CONVERT(DECIMAL(5,1),COUNT (1) OVER (PARTITION BY [BrstRef]) / SUM(1.0) OVER () * 100.0 )  stat FROM #titlex_final  UNION ALL
      SELECT 37 STATORDER,'CTResult - '+CONVERT(VARCHAR(MAX),[Chlam]) STATNAME,CONVERT(DECIMAL(5,1),COUNT (1) OVER (PARTITION BY [Chlam]) / SUM(1.0) OVER () * 100.0 )  stat FROM #titlex_final   -- ORDER BY statorder , statname
    END

	IF @ShowDebug_Bitflag = 1  SELECT '*** FINAL RESULT ***' 
	IF @ExportFileOption = 'GRANT' OR @ExportFileOption IS NULL
	 BEGIN -- the order of display changed #CM20230208 -- comply with new order
	  SELECT -- distinct 
	     [Delegate] -- 1. Delegate Delegate ID Numeric 2  To be assigned BY AFHP
	   , [Health Center] -- 2. Health_Center Health Center Numeric 4 To be assigned by AFHP -- MRN on Encounters tab and validation tab should be as it appear in Epic, Grants tab - the MRN does not include leading zeros
	   , TRY_CONVERT ( VARCHAR ( MAX ) , TRY_CONVERT ( INT , f.Client ) ) Client -- 3. Client Client ID Alphanumeric 10 Medical Record  Number -- , TRY_CONVERT ( VARCHAR ( MAX ) , TRY_CONVERT ( INT , P.PAT_MRN_ID ) ) FORMATTED_MRN
	   , [VisitDate] -- 4. Visit_Date Visit Date Date 10 ##/##/####
	   , [DOB] -- 5. DOB Birth Date Date 10 ##/##/####
	   , [Household Income] Income -- #CM6. Income  Household Income Numeric 7
	   , [Household Size] Household_Size -- #CM7. Household_Size Household  Size Numeric 2
	   , [PubIns] Public_Coverage -- #CM8. Public_Coverage Public  Insurance  Coverage Alpha 1 Y Yes
	   , [PrivIns] Private_Coverage -- #CM9. Private_Coverage Private Insurance Coverage Alpha 1 Y Yes
	   , [TitleX] -- 10. Title_X Title X Alpha 1 Y Yes
	   , [PublicIns] Public_Ins -- #CM11. Public_Ins Public Insurance Alpha 1 Y Yes
	   , [PrivateIns] Private_Ins -- #CM12. Private_Ins Private Insurance Alpha 1 Y Yes
	   , [SelfPay] -- 13. Selfpay Self-pay Alpha 1 Y Yes
	   , [TitleV] -- 14. Title_V Title V Alpha 1 Y Yes
	   , [OtherPay] -- 15. Otherpay Other pay Alpha 1 Y Yes
	   , [Zip] -- 16. Zip Zip Code Numeric 5
	   , [Sex] -- 17. Sex Sex Alpha 1 F Female 17. WARNING: if sex for a client has changed since PREVIOUS VISIT WARNING: if female clients are over age 55 M Male
	   , Gender -- GENDER 18. Gender Gender  Identity Numeric 
	   , COALESCE ( sexo , 0 ) Sexual_Orientation -- 19. Sexual_Orientation Sexual Orientation Numeric 
	   , [LEP] -- 20. LEP Limited  English  Proficiency Alpha 1 Y Yes
	   , [AI] -- 21. AI American  Indian or  Alaska Native Alpha 1 Y American Indian  or Alaska Native
	   , [Asian] -- 22. Asian Asian Alpha 1 Y Asian
	   , [AA] -- 23. AA Black or African  American Alpha 1 Y Black or African  American
	   , [NH] -- 24. NH Native Hawaiian or Other Pacific Islander Alpha 1 YNative Hawaiian or Other Pacific Islande
	   , [White] -- 25. White White Alpha 1 Y Whit
	   , Ethnicity -- #CM26. Ethnicity Ethnicity Numeric 
	   , [CPT Code] CPT -- #CM27. CPT Primary CPT CodeNumeric or alphanumeric 5
	   , provider_numeric [Provider] -- 28. Provider Role Numeric 
	   , NPI -- 29.  National Provider Identifier Numeric 
	   , BC_Counsel -- 30. BC_COUNSEL Contraceptive counseling was provided Alpha Y , N  do you see a z30.0 , z30.02 , z30.09 ICD CODE?
	   , preg_intent -- 31. PREG_INTENT Pregnancy Intention Numeric 
	   , Preg_Counsel -- 32. PREG_COUNSEL Counseling to achieve pregnancy was provided Alpha Y , N --  Z31.6 Encounter for general counseling and advice on procreation
	                  --Warning: Pregnancy Counseling (32) and Contraceptive Counseling (30) = ‘N’ AND both Before Method (34) and Primary Method (35) = ‘0’ AND Pregnancy Intention (31) = ‘0
	   , PTRESULT Pt_result -- 33.  Pregnancy test result Numeric 
	   , [Before] Before_Method -- 34. Before_Method Contraceptive method at intake reported Numeric 
	   , [Primary] Primary_Method -- 35. Contraceptive method at exit reported Numeric -- 36. Dispensed How was contraceptive method provided? Numeric 1 1 Provided onsite  1 Provided onsite 2 Prescription  3 Referral  4 Not provided 
	   , f.Dispensed
	   , coalesce ( [Pap] , 0 ) Pap -- 37. Pap Pap smear test result 
	   , COALESCE ( [HPV] , 0 ) HPV-- 38.  HPV test result 
	   , COALESCE ( [Chlam] , 0 ) CT -- #CM39. CT CT test result Numeric  
	   , COALESCE ( [GC] , 0 ) GC -- 40. GC test result Numeric 
	   , COALESCE ( [Syphilis] , 0 ) Syphilis -- #CM41.  Syphilis test result 
	   , COALESCE ( [HIV] , 0 ) HIV -- 42.  HIV test result 
	   , Telehealth -- 43. Telehealth Telehealth Visit Numeric 
	   , Systolic -- 44. Systolic Systolic Blood  Pressure Numeric 
	   , Diastolic -- 45. Diastolic Diastolic Blood  Pressure Numeric 
	   , height -- 46. Height Height (in.) Numeric 
	   , [weight]-- 47. Weight Weight (lbs.) Numeric 
	   , coalesce ( Tobacco , 0 ) Tobacco -- 48. Tobacco Smoking Status Numeric 
	  FROM #titlex_final f -- ORDER BY f.Client , f.VisitDate 
	 END

	ELSE IF @ExportFileOption = 'ENCOUNTERS'  /* final select for file */
	      BEGIN 
		   SELECT DISTINCT #titlex_fpEncs.personnbr PersonNbr , #titlex_fpEncs.MRN [Client] -- 3. Client Client ID Alphanumeric 10 Medical Record  Number
			, #titlex_fpEncs.FirstName FirstName
			, #titlex_fpEncs.LastName LastName
			, CONVERT ( DATE , #titlex_fpEncs.DateOfBirth ) DateOfBirth
			, #titlex_fpEncs.Payer1
			, #titlex_fpEncs.FinClass
			, #titlex_final.[Household Income] --#CM9.5.23
			, Case when #titlex_final.PublicIns='Y' Then 'Has Public Insurance Does Not Qualify'
			   When #titlex_final.OtherPay='Y' Then 'Has Indian Health Service or Tricare'
			   When #titlex_fpEncs.percent_fpl >250 then 'Over the 250% FPL'
			   When #titlex_final.TitleX='Y' Then 'Qualifies'
			   Else #titlex_final.Comment
			   End Comment
			, #titlex_fpEncs.LocationName
			, COALESCE ( #titlex_fpEncs.PrimaryCharge , '' ) PrimaryCPTCode
			, #titlex_fpEncs.EncNbr EncNbr
			, CONVERT ( DATE , #titlex_fpEncs.EncDate ) EncDate
		   FROM #titlex_final JOIN #titlex_fpEncs ON -- #titlex_fpEncs.MRN = #titlex_final.Client AND #titlex_final.VisitDate = #titlex_fpEncs.EncDate AND #titlex_final.EncNbr = #titlex_fpEncs.EncNbr AND #titlex_final.PersonNbr = #titlex_fpEncs.PersonNbr -- ORDER BY #titlex_fpEncs.personnbr , #titlex_fpEncs.EncNbr , EncDate
		    #titlex_fpencs.EncID = #titlex_final.EncNbr --> YES IT IS THE ID.. THE CSN ENCOUNTER ID
	      ENd

	ELSE IF @ExportFileOption = 'VALIDATION' 
	      BEGIN
		   IF OBJECT_ID ( 'tempdb.dbo.#titlex_charges_simpl' ) IS NOT NULL DROP TABLE #titlex_charges_simpl
		   SELECT VisitGrp , PersonID , ServiceType , c.EncID
		   INTO #titlex_charges_simpl   
		   FROM #titlex_charges   c
		   GROUP BY VisitGrp , PersonID , ServiceType , c.EncID -- select * from #titlex_charges_simpl 

		   IF OBJECT_ID ( 'tempdb.dbo.#titlex_screening_simpl' ) IS NOT NULL DROP TABLE #titlex_screening_simpl
		   SELECT VisitGrp , PersonID , ScreeningTYpe , S.EncID
		   INTO #titlex_screening_simpl 
		   FROM #titlex_screening S
		   GROUP BY VisitGrp , PersonID , ScreeningTYpe , S.EncID -- select * from #titlex_screening_simpl 

		   IF OBJECT_ID ( 'tempdb.dbo.#titlex_education_simpl' ) IS NOT NULL DROP TABLE #titlex_education_simpl
		   SELECT VisitGrp , PersonID , EducationType , E.EncID
		   INTO #titlex_education_simpl 
		   FROM #titlex_education E
		   GROUP BY VisitGrp , PersonID , EducationType , E.EncID -- select * from #titlex_education_simpl 

		   IF OBJECT_ID ( 'tempdb.dbo.#titlex_diagnosis_simpl' ) IS NOT NULL DROP TABLE #titlex_diagnosis_simpl
		   SELECT VisitGrp , PersonID , ServiceType , S.EncID
		   INTO #titlex_diagnosis_simpl 
		   FROM #titlex_diagnosis S
		   GROUP BY VisitGrp , PersonID , ServiceType , S.EncID -- select * from #titlex_diagnosis_simpl 

		   IF OBJECT_ID ( 'tempdb.dbo.#titlex_labs_simpl' ) IS NOT NULL DROP TABLE #titlex_labs_simpl
		   SELECT VisitGrp , PersonID -- , TestType 
		    , L.EncID
		   INTO #titlex_labs_simpl 
		   FROM #titlex_labs L
		   GROUP BY VisitGrp , PersonID -- , TestType  
		    , L.EncID 

		   IF OBJECT_ID ( 'tempdb.dbo.#titlex_encs_simpl' ) IS NOT NULL DROP TABLE #titlex_encs_simpl 
		   SELECT distinct #titlex_fpEncs.PersonID PersonID 
		    , #titlex_fpEncs.VisitGrp VisitGrp 
		    , #titlex_fpEncs.Payer1 Payer1
			, #titlex_fpEncs.FinClass FinClass
			, #titlex_fpEncs.LocationName LocationName
			, #titlex_fpEncs.PrimaryCharge PrimaryCharge
			, #titlex_fpEncs.EncNbr EncNbr
			, #titlex_fpEncs.EncDate EncDate
			, #titlex_final.Final_Rendering_Provider Rendering_Provider
			, #titlex_fpEncs.EncID EncID
			, #titlex_fpEncs.PracticeCd PracticeCd
			, #titlex_fpEncs.VisitType 
			, #titlex_fpEncs.PersonNbr
			, #titlex_fpEncs.FirstName
			, #titlex_fpEncs.LastName
			, #titlex_fpEncs.Sex
			, #titlex_fpEncs.DateOfBirth
			, #titlex_fpEncs.percent_fpl
			, #titlex_final.Comment
		   INTO #titlex_encs_simpl
		   FROM #titlex_final 
		    inner hash JOIN #titlex_fpEncs ON #titlex_fpencs.EncID = #titlex_final.EncNbr --> YES IT IS THE ID.. THE CSN ENCOUNTER ID

          IF OBJECT_ID ( 'tempdb.dbo.#titlex_charges_flat' ) IS NOT NULL DROP TABLE #titlex_charges_flat 
		  SELECT Visitgrp , PersonID , STUFF ( ( SELECT ',' + ServiceType -- stick all our results into flattened columns for easy join
					                             FROM #titlex_charges_simpl C
					                             WHERE C.VisitGrp = S.VisitGrp
					                             FOR XML PATH('')), 1, 1, '') [Type] , S.EncID
		  INTO #titlex_charges_flat
		  FROM #titlex_charges_simpl S -- select * from #titlex_charges_flat

		  IF OBJECT_ID ( 'tempdb.dbo.#titlex_screening_flat' ) IS NOT NULL DROP TABLE #titlex_screening_flat 
		  SELECT Visitgrp , PersonID , STUFF((SELECT ',' + ScreeningTYpe
					FROM #titlex_screening_simpl C
					WHERE C.VisitGrp = S.VisitGrp
					FOR XML PATH('')
					), 1, 1, '') [Type] , S.EncID
		  INTO #titlex_screening_flat
		  FROM #titlex_screening_simpl S -- select * from #titlex_screening_flat

		  IF OBJECT_ID ( 'tempdb.dbo.#titlex_education_flat' ) IS NOT NULL DROP TABLE #titlex_education_flat 
		  SELECT Visitgrp , PersonID , STUFF(( SELECT ',' + EducationType
					FROM #titlex_education_simpl C
					WHERE C.VisitGrp = E.VisitGrp
					FOR XML PATH('')
					), 1, 1, '') [Type] , E.EncID
		  INTO #titlex_education_flat
		  FROM #titlex_education_simpl E

		  IF OBJECT_ID ( 'tempdb.dbo.#titlex_diagnosis_flat' ) IS NOT NULL DROP TABLE #titlex_diagnosis_flat 
		  SELECT Visitgrp , PersonID , STUFF((SELECT ',' + ServiceType
					FROM #titlex_diagnosis_simpl C
					WHERE C.VisitGrp = D.VisitGrp
					FOR XML PATH('')
					), 1, 1, '') [Type] , D.EncID
		  INTO #titlex_diagnosis_flat
		  FROM #titlex_diagnosis_simpl D

		  IF OBJECT_ID ( 'tempdb.dbo.#titlex_labs_flat' ) IS NOT NULL DROP TABLE #titlex_labs_flat 
		  SELECT Visitgrp , PersonID , STUFF ( ( SELECT ',' -- + TestType
					FROM #titlex_labs_simpl C
					WHERE C.VisitGrp = L.VisitGrp
					FOR XML PATH('')
					), 1, 1, '') [Type] , L.EncID
		  INTO #titlex_labs_flat
		  FROM #titlex_labs_simpl L -- select top 10 * from #titlex_labs_flat

		  IF OBJECT_ID ( 'tempdb.dbo.#titlex_fpEncs_flat' ) IS NOT NULL DROP TABLE #titlex_fpEncs_flat
		  SELECT S.Visitgrp 
		   , S.PersonID 
		   , S.EncDate 
		   , s.Sex 
		   , s.DateOfBirth 
		   , S.EncID
		   , STUFF ( ( SELECT ',' + Payer1
					FROM #titlex_encs_simpl C
					WHERE C.PersonID = S.PersonID AND C.EncDate = S.EncDate
					GROUP BY Payer1
					FOR XML PATH('')
					), 1, 1, '') Payer
		
		   , STUFF((SELECT ',' + FinClass
					FROM #titlex_encs_simpl C
					WHERE C.PersonID = S.PersonID AND C.EncDate = S.EncDate
					GROUP BY FinClass
					FOR XML PATH('')
					), 1, 1, '') FinClass
			, STUFF(( SELECT ',' + LocationName
					FROM #titlex_encs_simpl C
					WHERE C.PersonID = S.PersonID AND C.EncDate = S.EncDate
					GROUP BY LocationName
					FOR XML PATH('')
					), 1, 1, '') LocationName
			, STUFF(( SELECT ',' + PrimaryCharge
					FROM #titlex_encs_simpl C
					WHERE C.PersonID = S.PersonID AND C.EncDate = S.EncDate
					GROUP BY PrimaryCharge
					FOR XML PATH('')
					), 1, 1, '') PrimaryCPTCode
			, STUFF ( ( SELECT ', ' + CAST(EncNbr AS VARCHAR)
					FROM #titlex_encs_simpl C
					WHERE C.PersonID = S.PersonID AND C.EncDate = S.EncDate
					GROUP BY CAST(EncNbr AS VARCHAR)
					FOR XML PATH('')
					), 1, 1, '') EncNbr
			, STUFF(( SELECT ', ' + CAST(DiagCD AS VARCHAR)
					FROM #titlex_diagnosis D
					WHERE D.PersonID = S.PersonID AND D.EncDate = S.EncDate
					GROUP BY CAST(DiagCD AS VARCHAR)
					FOR XML PATH('')
					), 1, 1, '') DiagCds
			, STUFF(( SELECT ', ' + CptCd 
					FROM #titlex_charges C
					WHERE C.PersonID = S.PersonID AND C.EncDate = S.EncDate
					GROUP BY CptCd FOR XML PATH ( '' ) ) , 1 , 1 , '' ) TitleXCPTs
			, STUFF ( ( SELECT ', ' + CPT_CODE
					    FROM ARPB_TRANSACTIONS c 
						WHERE c.PATIENT_ID = S.PersonID AND c.service_date = S.EncDate AND c.PAT_ENC_CSN_ID = S.encID
					    GROUP BY CPT_CODE FOR XML PATH ( '' ) ) , 1 , 1 , '' ) AllCPTs
			, S.percent_fpl AS FPL_Percentge
			, S.Comment
		INTO #titlex_fpEncs_flat
		FROM #titlex_encs_simpl S
		
 SELECT DISTINCT tf.[Delegate] -- 1. Delegate ID - Values for this field are assigned by Affirm.
  , tf.[Health Center] -- 2. Health Center Site - Values for this field are assigned by the Affirm.
  ,concat(tf.FirstName,' ' ,tf.LastName) AS Name
  , tf.Client [Client] 
	, tf.[VisitDate] 
	, tf.[DOB] -- 5.  The Date of Birth is recorded in a month/day/year (mm/dd/yyyy) format. Refer to the Date of Visit field, above, for specifications. Date of Visit and Date of Birth are used to calculate age.
 , Case when 
         tf.[Household Income] =-1 then 0
		 else  tf.[Household Income] 
		   END Income-- #CM6.  Annual Household Income - Client’s self-report of the numeric value of the annual household income where the client resides.
  
  , tf.[Household Size] Household_Size -- #CM7.  Household Size - Client’s self-report of the numeric value of the total number of persons living in the household, including the client.
  , MoiraStuff.FPL_Percentge
  , tf.[PubIns] Public_Coverage -- #CM20220329
  , tf.[PrivIns] Private_Coverage -- #CM20220329
  , tf.[TitleX] -- 10. Title X 
    , tf.[PublicIns] Public_Ins -- 11 -- #CM20220329
  , tf.[PrivateIns] Private_Ins -- 12 -- #CM20220329
  , tf.[SelfPay] -- 13
  , tf.[TitleV] -- 14
  , tf.[OtherPay] -- 15
  , CASE When 
        tf.[PubIns]  = 'Y' Then 'Has Public Insurance Does Not Qualify'
		When tf.[OtherPay]='Y' Then 'Has Indian Health Service or Tricare'
		When MoiraStuff.FPL_Percentge >250 then 'Over the 250% FPL'
		When tf.[TitleX]  ='Y' Then 'Qualifies'
		Else tf.Comment
		END  
		Comment
  , tf.[Zip] -- 16. Zip Code is the five-digit zip code of the client’s home address. This item is used to 
  , tf.[Sex] -- 17. Assigned at birth, determined based on anatomy and physiology or genetic (chromosome) 
, tf.gender Gender -- 18. gender
, COALESCE ( tf.sexo , 0 ) Sexual_Orientation-- 19. sexual orientation
  , tf.[LEP] -- 20. LEP
  , tf.[AI] -- 21.
  , tf.[Asian] -- 22.
  , tf.[AA] -- 23.
  , tf.[NH] -- 24.
  , tf.[White] -- 25.
  , tf.Ethnicity -- #CM26.
  , tf.[CPT Code] CPT -- #CM27.
    , tf.provider_numeric [provider] -- #CM-- 28. provider
	, tf.NPI NPI -- 29. npi
	, tf.BC_Counsel bc_counsel -- 30.
	, tf.preg_intent preg_intent -- 31. 
	, tf.Preg_Counsel preg_counsel -- 32. preg_counsel
    , tf.[PtResult] -- 33. pt_result
  , tf.[Before] Before_Method -- #CM34. Before method
  ,tf.[Primary] Primary_Method -- #CM35. Primary method
  , tf.Dispensed Dispensed 
  , coalesce ( tf.[Pap] , 0 ) Pap -- 37. pap
  , coalesce ( tf.HPV , 0 ) HPV -- 38. hpv
  , coalesce ( tf.[Chlam] , 0 ) CT -- #CM39. CT
  , coalesce ( tf.[GC] , 0 ) GC -- 40. GC
  , coalesce ( tf.Syphilis , 0 ) Syphilis -- #CM41. 
  , coalesce ( tf.[HIV] , 0 ) HIV -- 42. 
  , tf.Telehealth Telehealth -- 43. Telehealth
  , tf.Systolic systolic -- 44. systolic
  , tf.Diastolic diastolic -- 45. diastolic
  , Round(tf.height,1) height -- 46. 
  , ROUND(tf.[weight],1) [weight] -- 47. 
  , COALESCE ( tf.tobacco , 0 ) Tobacco -- 48.  -- , MoiraStuff.Age
  , MoiraStuff.Payers 
  , MoiraStuff.FinClass 
  , MoiraStuff.Locations
  , tf.provider_name 
  , MoiraStuff.FPCheckbox
  , MoiraStuff.PrimaryCPTs 
  , MoiraStuff.EncNbrs
  , MoiraStuff.DiagCds 
  , MoiraStuff.TitleXCPTs 
  , MoiraStuff.AllCPTs
  , MoiraStuff.Charges 
  , MoiraStuff.Screenings
  , MoiraStuff.Educations
  , MoiraStuff.Diagnoses
  , MoiraStuff.Labs 
 FROM #titlex_final tf 
  inner hash JOIN ( SELECT F.Client , FLAT.EncDate -- , COALESCE ( MAX ( x.AgeYearsIntRound ) , '' ) Age
			, COALESCE ( MAX ( FLAT.Payer ) , '' ) Payers
			, COALESCE ( MAX ( FLAT.FinClass ) , '' ) FinClass
			, COALESCE ( MAX ( FLAT.LocationName), '') Locations
			, COALESCE ( MAX ( FLAT.EncNbr), '') EncNbrs
			, COALESCE ( MAX ( FLAT.PrimaryCPTCode), '') PrimaryCPTs
			, COALESCE ( MAX ( FLAT.DiagCds), '') DiagCds
			, COALESCE ( MAX ( FLAT.TitleXCPTs), '') TitleXCPTs
			, COALESCE ( MAX ( FLAT.AllCPTs), '') AllCPTs 
			, COALESCE ( MAX ( CASE WHEN x.IsFPWorkflowEnc  = 0 THEN 'No' ELSE 'YES' END ) , '' ) FPCheckbox
			, COALESCE ( MAX ( c.Type ) , '' ) Charges
			, COALESCE ( MAX ( s.Type ) , '' ) Screenings
			, COALESCE ( MAX ( edu.Type ) , '' ) Educations
			, COALESCE ( MAX ( dx.Type ) , '' ) Diagnoses
			, COALESCE ( MAX ( lab.Type ) , '' ) Labs 
			,flat.FPL_Percentge
		FROM #titlex_final F 
		 inner hash JOIN #titlex_fpEncs_flat FLAT ON -- #titlex_fpEncs_flat.VisitGrp = #titlex_final.VisitGrp 
		  FLAT.EncID = F.EncNbr
		 LEFT JOIN #titlex_Encs x on -- x.VisitGrp = #titlex_fpEncs_flat.VisitGrp
		  x.EncID = FLAT.EncID --> YES IT IS THE ID.. THE CSN ENCOUNTER ID
		 LEFT JOIN #titlex_charges_flat c ON -- #titlex_fpEncs_flat.PersonID = #titlex_charges_flat.PersonID AND #titlex_fpEncs_flat.VisitGrp = #titlex_charges_flat.VisitGrp
		  c.EncID = FLAT.EncID
		 LEFT JOIN #titlex_screening_flat s ON -- FLAT.PersonID = s.PersonID AND FLAT.VisitGrp = s.VisitGrp
		  s.EncID = FLAT.EncID
		 LEFT JOIN #titlex_education_flat edu ON -- FLAT.PersonID = edu.PersonID AND FLAT.VisitGrp = edu.VisitGrp
		  edu.EncID = FLAT.EncID
		 LEFT JOIN #titlex_diagnosis_flat dx ON -- FLAT.PersonID = dx.PersonID AND FLAT.VisitGrp = dx.VisitGrp
		  dx.EncID = FLAT.EncID
		 LEFT JOIN #titlex_labs_flat lab ON FLAT.PersonID = lab.PersonID AND FLAT.VisitGrp = lab.VisitGrp -- lab.EncID = FLAT.EncID
		GROUP BY F.Client , FLAT.EncDate, FPL_Percentge ) MoiraStuff 
	   ON tf.Client = MoiraStuff.Client AND tf.VisitDate = MoiraStuff.encDate -- #tf.EncNbr = MoiraStuff.EncNbr   \
	end
END 
GO


