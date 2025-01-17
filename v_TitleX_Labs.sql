USE [CLARITY]
GO


SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE    VIEW [ElRio].[v_TitleX_Labs] as 
/* Description: Title X FPAR2.0 labs in one shot
   Author: Cindy Minera #CM
   select * from [ElRio].[v_TitleX_Labs] where  PAT_ID_procs = 'Z175125' order 
   
   */
SELECT ORDER_PROC.PAT_ID PAT_ID_procs
    , ORDER_PROC.PAT_ENC_CSN_ID
	, MAX ( ORDER_PROC.ORDER_PROC_ID ) ORDER_PROC_ID
	, ORDER_PROC.DESCRIPTION
	, MAX ( pap_result ) pap_result
	, cat.TitleX_ProcCategory
	, min ( ORDER_PROC_2.SPECIMN_TAKEN_DATE ) SPECIMN_TAKEN_DATE
	, MAX ( ABNORMAL_YN ) ABNORMAL_YN
	, MAX ( CASE WHEN ABNORMAL_YN = 'Y' THEN 1 ELSE 0 END ) Abnormal_bitflag
	, ORDER_PROC.LAB_STATUS_C
	, Z.NAME LAB_STATUS_DESC
	, max ( ORDER_PROC.RESULT_TIME ) RESULT_DT

	  -- changed these to max #CM20230322
	, max ( CT.chlam_result ) chlam_result
	, Max ( GC.GC_result ) GC_result
	, Max ( HPV.HPV_result ) HPV_result
	, Max ( VDRL.VDRL_result ) VDRL_result
	, Max ( HIV.HIV_result ) HIV_result
      -- 

	, MAX ( PT.PT_result ) PT_result
   FROM CLARITY.DBO.ORDER_PROC 
   	JOIN CLARITY.[ElRio].v_TitleX_procedure_categories cat ON cat.TitleX_PROC_ID = ORDER_PROC.PROC_ID

    -- LEFT #CM20230322 -- we want to make sure we bring the final status, we are forcing it to have a status
	JOIN CLARITY.DBO.ZC_LAB_STATUS Z ON Z.LAB_STATUS_C = ORDER_PROC.LAB_STATUS_C  -- SELECT  * FROM CLARITY.DBO.ZC_LAB_STATUS Z

    JOIN CLARITY.DBO.ORDER_PROC_2 ON -- ORDER_PROC_2.ORDER_PROC_ID = ORDER_PROC.ORDER_PROC_ID -- MOira wants to join by encounter #CM20230322
	 order_proc_2.PAT_ENC_CSN_ID = order_proc.PAT_ENC_CSN_ID 

    LEFT JOIN clarity.ELRio.V_TitleX_pap_results pap_result ON rn = 1 AND ( pap_result.result_proc_id = ORDER_PROC.order_proc_id OR pap_result.ORDER_INSTANTIATED_ORDER_ID = ORDER_PROC.order_proc_id ) 
	 -- pap_result.PAT_ENC_CSN_ID = order_proc.PAT_ENC_CSN_ID and pap_result.rn = 1

	LEFT JOIN CLARITY.ELrio.V_TitleX_chlam_results CT on CT.rn = 1 AND CT.order_proc_id = order_proc.order_proc_id 
	 -- CT.PAT_ENC_CSN_ID = order_proc.PAT_ENC_CSN_ID and ct.rn = 1

	LEFT JOIN CLARITY.ELrio.v_TitleX_GC_results GC ON  GC.rn = 1 AND GC.order_proc_id = order_proc.order_proc_id 
	 -- GC.PAT_ENC_CSN_ID = order_proc.PAT_ENC_CSN_ID and gc.rn = 1

	LEFT JOIN CLARITY.ELrio.V_TitleX_HPV_results HPV ON HPV.rn = 1 AND HPV.order_proc_id = order_proc.order_proc_id
	 -- hpv.PAT_ENC_CSN_ID = order_proc.PAT_ENC_CSN_ID and hpv.rn = 1

	LEFT JOIN CLARITY.ELrio.V_TitleX_VDRL_results VDRL ON VDRL.rn = 1 AND VDRL.order_proc_id = order_proc.order_proc_id
	 -- vdrl.PAT_ENC_CSN_ID = order_proc.PAT_ENC_CSN_ID and vdrl.rn = 1

	LEFT JOIN CLARITY.ELrio.V_TitleX_HIV_results HIV ON HIV.rn = 1 AND HIV.order_proc_id = order_proc.order_proc_id
	 -- HIV.PAT_ENC_CSN_ID = order_proc.PAT_ENC_CSN_ID and hiv.rn = 1

	LEFT JOIN CLARITY.ELrio.V_TitleX_PREGNANCY_results PT ON PT.rn = 1 and PT.order_proc_id = order_proc.order_proc_id
	 -- PT.PAT_ENC_CSN_ID = order_proc.PAT_ENC_CSN_ID and pt.rn = 1

  WHERE -- ORDER_PROC.RESULT_TIME > '10/31/2021' AND 
   ORDER_PROC.LAB_STATUS_C > 2 -- WE EITHER WANT THE FINAL RESULT, THE EDITED RESULT OR THE EDITED RESULT FINAL
  GROUP BY ORDER_PROC.PAT_ID 
   , cat.TitleX_ProcCategory 
   , ORDER_PROC.PAT_ENC_CSN_ID 
   , ORDER_PROC.DESCRIPTION 
   , ORDER_PROC.LAB_STATUS_C 
   , Z.NAME 
   -- , ORDER_PROC.RESULT_TIME
GO


