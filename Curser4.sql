USE CLARITY
--Declare 
--@Startdate Date =  DATEADD(MONTH, -12, DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()), 0)),
--@EndDate Date = EOMONTH(getdate(), -1)


--Getting the transaction information
IF OBJECT_ID ('tempdb.dbo.#First') IS NOT NULL DROP TABLE #First  
SELECT *,  
CASE WHEN ORGANIZE = '1' THEN Amount ELSE 0 END CinAmount,  
CASE WHEN ORGANIZE = '1' THEN TOT_AR_INS_PMT ELSE 0 END EOBAcutalInsuranceAmount,  
CASE WHEN ORGANIZE = '1' THEN TOT_AR_SP_PMT ELSE 0 END Pre_Payment ,
CASE WHEN ORGANIZE = '1' THEN Charge_amount ELSE 0 END CinAmount2
--CASE WHEN ORGANIZE = '1' THEN SBO_TOTAL_CHARGES ELSE 0 END CinAmount3 
INTO #First 
FROM (  
    SELECT   
    ROW_NUMBER() OVER (PARTITION BY V_CUBE_F_PB_TRANSACTION_DETAIL.TRANSACTION_ID ORDER BY V_CUBE_F_PB_TRANSACTION_DETAIL.TDL_ID) AS 'ORGANIZE',  
    Patient.PAT_MRN_ID,  
    Patient.PAT_NAME, 
	ARPB_TRANSACTIONS.STMT_INT_STATUS_C,
	ARPB_TRANSACTIONS.TX_BATCH_NUM,
    ARPB_TRANSACTIONS.PAT_ENC_CSN_ID,    
    ARPB_TRANSACTIONS.VISIT_NUMBER,
    V_CUBE_F_PB_TRANSACTION_DETAIL.CPT_CODE,  
	Clarity_EPP.BENEFIT_PLAN_NAME, 
	Clarity_EPP.BENEFIT_PLAN_ID,
	 V_CUBE_D_PAYOR.PAYOR_DISPLAY_NAME,
	Clarity_EPP.PAYOR_ID,
	V_CUBE_F_PB_TRANSACTION_DETAIL.DETAIL_TYPE_NAME,
	V_CUBE_F_PB_TRANSACTION_DETAIL.CREDIT_BENEFIT_PLAN_ID,
    V_CUBE_F_PB_TRANSACTION_DETAIL.TDL_ID,
    V_CUBE_F_PB_TRANSACTION_DETAIL.TRANSACTION_ID,  
    V_CUBE_F_PB_TRANSACTION_DETAIL.ACCOUNT_ID,  
    V_CUBE_F_PB_TRANSACTION_DETAIL.Service_Date, 
    V_CUBE_F_PB_TRANSACTION_DETAIL.TYPE_NAME,
	V_CUBE_F_PB_TRANSACTION_DETAIL.TRANSACTION_TYPE,
	V_CUBE_F_PB_TRANSACTION_DETAIL.TDL_NAMECOLUMN,
    V_CUBE_F_PB_TRANSACTION_DETAIL.AMOUNT, --Bill Amount  
    V_CUBE_F_PB_TRANSACTION_DETAIL.PATIENT_AMOUNT, --CoPayment  
    V_CUBE_F_PB_TRANSACTION_DETAIL.INSURANCE_AMOUNT,  
    V_CUBE_F_PB_TRANSACTION_DETAIL.CHARGE_AMOUNT,  
    V_CUBE_F_PB_TRANSACTION_DETAIL.PAYMENT_AMOUNT,  
    V_CUBE_F_PB_TRANSACTION_DETAIL.ADJUSTMENT_AMOUNT, --Adjustment  
    V_CUBE_F_PB_TRANSACTION_DETAIL.CREDIT_ADJUSTMENT_AMOUNT,  
    ARPB_TX_COLL_RATIO.TOT_AR_INS_PMT, ---Added here Arraceli tip  
    ARPB_TX_COLL_RATIO.TOT_AR_SP_PMT  
    FROM V_CUBE_F_PB_TRANSACTION_DETAIL  
	--LEFT JOIN HSP_ACCT_SBO ON  HSP_ACCT_SBO.HSP_ACCOUNT_ID=V_CUBE_F_PB_TRANSACTION_DETAIL.ACCOUNT_ID
    LEFT JOIN ARPB_TRANSACTIONS ON ARPB_TRANSACTIONS.TX_ID=V_CUBE_F_PB_TRANSACTION_DETAIL.TRANSACTION_ID  
    LEFT JOIN PATIENT ON Patient.PAT_ID = V_CUBE_F_PB_TRANSACTION_DETAIL.PATIENT_ID  
    LEFT JOIN Clarity_EPP ON CLARITY_EPP.Benefit_Plan_ID = V_CUBE_F_PB_TRANSACTION_DETAIL.ORIGINAL_BENEFIT_PLAN_ID  
	LEFT JOIN V_CUBE_D_PAYOR ON V_CUBE_D_PAYOR.Payor_ID = CLARITY_EPP.Payor_ID
    LEFT JOIN ARPB_TX_COLL_RATIO ON ARPB_TX_COLL_RATIO.TX_ID = V_CUBE_F_PB_TRANSACTION_DETAIL.TRANSACTION_ID
    WHERE V_CUBE_F_PB_TRANSACTION_DETAIL.ORIGINAL_BENEFIT_PLAN_ID > 0 --  
    AND V_CUBE_F_PB_TRANSACTION_DETAIL.SERVICE_DATE BETWEEN   '01/01/2022' and '12/31/2022'    --@StartDate AND @EndDate
) AS InnerQuery  
ORDER BY InnerQuery.TDL_ID    






--IF OBJECT_ID ('tempdb.dbo.#Second') IS NOT NULL DROP TABLE #Second     
--SELECT Distinct * INTO #Second   
--FROM (  
--    SELECT ROW_NUMBER() OVER (PARTITION BY TX_Batch_NUM,Account_ID ORDER BY TX_Batch_NUM ) AS 'ORGANIZE',
--	ROW_NUMBER() OVER (PARTITION BY ACCOUNT_ID,TX_Batch_NUM, CPT_Code ORDER BY TX_Batch_NUM ) AS 'ORGANIZE2',   
--        PAT_NAME,    
--        CONVERT(VARCHAR(10), #First.SERVICE_DATE, 101) AS Date,    
--        TDL_ID,  
--		TX_BATCH_NUM,
--        TRANSACTION_ID,    
--        ACCOUNT_ID,    
--        PAT_ENC_CSN_ID,    
--        VISIT_NUMBER,    
--        CPT_CODE,    
     
--        BENEFIT_PLAN_NAME,    
--        BENEFIT_PLAN_ID,    
--        PAYOR_DISPLAY_NAME,    
--        CREDIT_BENEFIT_PLAN_ID,    
--        TYPE_NAME,    
--        TRANSACTION_TYPE,    
--        DETAIL_TYPE_NAME,   
     
--        SUM(CinAmount2) AS ChargeAmount2,    
--        SUM(CinAmount) AS ChargeAmount, -- THE ACTUAL AMOUNT THAT WAS BILLED    
--        SUM(PATIENT_AMOUNT) AS CoPayCoInsurance, -- THIS IS A PATIENT CO PAYMENT    
--        SUM(ADJUSTMENT_AMOUNT) AS EOB_NonCovered, -- CONTRACTUAL ADJUSTMENT CONTRACTUAL ADJ CO45+    
--        SUM(Pre_Payment) AS Pre_Payment,    
--        SUM(EOBAcutalInsuranceAmount) AS EOB_INSURANCE_PAYMENT, -- THIS IS WHAT THE INSURANCE PAID US    
--        SUM(PAYMENT_AMOUNT) AS EOB_COVERED -- THIS IS THE ALLOWED AMOUNT WILL CALCULATE COPAY CO INSURANCE    
--    FROM #First    
--    GROUP BY    
--        TDL_ID,    
--        PAT_NAME,    
--        BENEFIT_PLAN_NAME,    
--        CONVERT(VARCHAR(10), #First.SERVICE_DATE, 101),    
--        TRANSACTION_ID,    
--        ACCOUNT_ID,    
--        PAT_ENC_CSN_ID,    
--        VISIT_NUMBER,    
--        CPT_CODE,    
--        BENEFIT_PLAN_NAME,    
--        BENEFIT_PLAN_ID,    
--        PAYOR_ID,    
--        TYPE_NAME,    
--        TRANSACTION_TYPE,    
--        DETAIL_TYPE_NAME,   
   
--        PAYOR_DISPLAY_NAME,    
--        CREDIT_BENEFIT_PLAN_ID ,
--		TX_BATCH_NUM
--) AS Query   
--Where Query.Organize <2
--ORDER BY TRANSACTION_ID, ACCOUNT_ID, Date DESC  

IF OBJECT_ID ('tempdb.dbo.#Second') IS NOT NULL DROP TABLE #Second
SELECT Distinct * INTO #Second
FROM (
SELECT 
--ROW_NUMBER() OVER (PARTITION BY TX_Batch_NUM,Account_ID ORDER BY TX_Batch_NUM ) AS 'ORGANIZE',
--ROW_NUMBER() OVER (PARTITION BY ACCOUNT_ID, CPT_Code ORDER BY ACCOUNT_ID) AS 'ORGANIZE2',
PAT_NAME,
CONVERT(VARCHAR(10), #First.SERVICE_DATE, 101) AS Date,
TDL_ID,
STMT_INT_STATUS_C,
TX_BATCH_NUM,
TRANSACTION_ID,
ACCOUNT_ID,
PAT_ENC_CSN_ID,
VISIT_NUMBER,
CPT_CODE,
    BENEFIT_PLAN_NAME,      
    BENEFIT_PLAN_ID,      
    PAYOR_DISPLAY_NAME,      
    TYPE_NAME,      
    TRANSACTION_TYPE,      
    DETAIL_TYPE_NAME,     
    SUM(CinAmount2) AS ChargeAmount2,      
    SUM(CinAmount) AS ChargeAmount, -- THE ACTUAL AMOUNT THAT WAS BILLED      
    SUM(PATIENT_AMOUNT) AS CoPayCoInsurance, -- THIS IS A PATIENT CO PAYMENT      
    SUM(ADJUSTMENT_AMOUNT) AS EOB_NonCovered, -- CONTRACTUAL ADJUSTMENT CONTRACTUAL ADJ CO45+      
    SUM(Pre_Payment) AS Pre_Payment,      
    SUM(EOBAcutalInsuranceAmount) AS EOB_INSURANCE_PAYMENT, -- THIS IS WHAT THE INSURANCE PAID US      
    SUM(PAYMENT_AMOUNT) AS EOB_COVERED -- THIS IS THE ALLOWED AMOUNT WILL CALCULATE COPAY CO INSURANCE      
 --   COUNT(*) OVER (PARTITION BY  Account_ID,TX_BATCH_NUM, [CinAmount] ) AS DuplicateFlag,  
	--CASE WHEN COUNT(*) OVER (PARTITION BY Account_ID, TX_BATCH_NUM, CinAmount) > 1 THEN 1 ELSE 2 END AS DuplicateFlag2
FROM #First      
Where DETAIL_TYPE_NAME <>'Voided Charge [10]'
GROUP BY      
    TDL_ID,      
    PAT_NAME,      
    BENEFIT_PLAN_NAME,      
    CONVERT(VARCHAR(10), #First.SERVICE_DATE, 101),      
    TRANSACTION_ID,      
    ACCOUNT_ID,      
    PAT_ENC_CSN_ID,      
    VISIT_NUMBER,      
    CPT_CODE,      
    BENEFIT_PLAN_NAME,   
	STMT_INT_STATUS_C,
    BENEFIT_PLAN_ID,      
    PAYOR_ID,      
    TYPE_NAME,      
    TRANSACTION_TYPE,      
    DETAIL_TYPE_NAME,     
    PAYOR_DISPLAY_NAME,      
	CinAmount,
	TX_Batch_NUM) as query


--Select *
--From (
--Select *,ROW_NUMBER() OVER (PARTITION BY TX_Batch_NUM,max (ChargeAmount) ORDER BY TX_Batch_NUM ) AS 'ORGANIZE'
--From #Second
--where Account_ID = '160454'
--And PAYOR_DISPLAY_NAME ='ALT DENTAL ALLWELL [100277]'
--AND Date = '02/18/2022'
--Group BY  TDL_ID,      
--    PAT_NAME,      
--    BENEFIT_PLAN_NAME,
--	TX_Batch_NUM,
--	Date,
--	ChargeAmount2,
--    ChargeAmount,      
--    TRANSACTION_ID,      
--    ACCOUNT_ID,      
--    PAT_ENC_CSN_ID,      
--    VISIT_NUMBER,      
--    CPT_CODE,      
--    BENEFIT_PLAN_NAME,   
--	STMT_INT_STATUS_C,
--    BENEFIT_PLAN_ID,            
--    TYPE_NAME,      
--    TRANSACTION_TYPE,      
--    DETAIL_TYPE_NAME,     
--    PAYOR_DISPLAY_NAME,CoPayCoInsurance,EOB_NonCovered,Pre_Payment,EOB_INSURANCE_PAYMENT,EOB_COVERED) AS Query
--	Where Query.ORGANIZE =1
----AND Organize <2
----Where BENEFIT_PLAN_NAME LIKE 'AARP'
----Order By ORGANIZE2 asc
----Where BENEFIT_PLAN_NAME IS NULL


--Calculations
IF OBJECT_ID ( 'tempdb.dbo.#Third' ) IS NOT NULL DROP TABLE #Third
SELECT
BENEFIT_PLAN_NAME, 
BENEFIT_PLAN_ID,
PAYOR_DISPLAY_NAME,
Count(distinct ACCOUNT_ID) Total_Patients,
Count(Distinct PAT_ENC_CSN_ID) AS Encounters
,sum(ChargeAmount) AS Charge_Amount--Actual Amount that was billed
,SUM(EOB_NonCovered) AS Adjustment --Contractal ajustment 
,SUM(EOB_Insurance_Payment) AS Revenue_Insurance_Payment -- Araceli Tip This is Revenue
,SUM(CoPayCoInsurance) AS Patient_Co_Pay 
,sum(CoPayCoInsurance+EOB_INSURANCE_PAYMENT) Total_Collections --Patient CoPayment + The InsurancePayment
,(SUM(EOB_Insurance_Payment)-SUM(EOB_NonCovered)) / Count(Distinct PAT_ENC_CSN_ID) AS Money_Per_Visit
--,(sum(ChargeAmount)-Sum(EOB_NonCovered))/ Count(Distinct PAT_ENC_CSN_ID) AS Money_Per_Visit2
INTO #Third
FROM #Second
GROUP BY BENEFIT_PLAN_ID,PAYOR_DISPLAY_NAME,
#Second.BENEFIT_PLAN_NAME





IF OBJECT_ID ( 'tempdb.dbo.#Fourth' ) IS NOT NULL DROP TABLE #Fourth
SELECT
PAT_NAME,
Account_ID,
Date,
PAT_ENC_CSN_ID,
BENEFIT_PLAN_NAME, 
BENEFIT_PLAN_ID,
PAYOR_DISPLAY_NAME,
--PAYOR_ID,
sum(ChargeAmount) AS Charge_Amount--Actual Amount that was billed
,SUM(EOB_NonCovered) AS Adjustment --Contractal ajustment 
,SUM(EOB_Insurance_Payment) AS Revenue_Insurance_Payment -- Araceli Tip This is Revenue
,SUM(CoPayCoInsurance) AS Patient_Co_Pay 
--,(sum(ChargeAmount)-Sum(EOB_NonCovered))/ Count(Distinct PAT_ENC_CSN_ID) AS Money_Per_Visit2
INTO #Fourth
FROM #Second
GROUP BY BENEFIT_PLAN_ID,
PAYOR_DISPLAY_NAME,
Date,
--PAYOR_ID,
PAT_NAME,
PAT_ENC_CSN_ID,
BENEFIT_PLAN_NAME,
Account_ID


--Select *
--From #Fourth
--Where Pat_name is not null
--And BENEFIT_PLAN_NAME LIKE 'AETNA DENTAL DMO'
--Order BY PAT_NAME


----------FINAL ANALYSIS-------


--Summary OF THE TABLE
Select *
FroM #Third
Where Benefit_plan_ID like '20000106'
--Where Benefit_Plan_name like '%Dental%'
--Where BENEFIT_PLAN_NAME  IS NULL
Order BY BENEFIT_PLAN_NAME asc


---SUMMARY OF CPT
SELECT   
    ROW_NUMBER() OVER (ORDER BY Total_CPT DESC) AS Rank,  
    CPT_Code,   
    Total_CPT  
FROM (  
    SELECT   
        CPT_Code,   
        COUNT(CPT_Code) AS Total_CPT    
    FROM #Second     
    WHERE Benefit_plan_ID LIKE '20000106'  
    GROUP BY CPT_Code      
) AS subquery  
ORDER BY Total_CPT DESC  
OFFSET 0 ROWS  
FETCH NEXT 25 ROWS ONLY;  


---Detailed Table
Select *
From #Fourth
Where Benefit_plan_ID like '20000106'
--And Account_ID like '160454'
ORder by PAT_NAME