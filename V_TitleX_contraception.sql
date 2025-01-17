USE [CLARITY]
GO


SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON


CREATE   VIEW [ElRio].[V_TitleX_contraception] as 
/* Description: Title X FPAR2.0 contraception values
   Author: Cindy Chavarria  
select * from [ElRio].[V_TitleX_contraception] where before_value is not null  and after_value is not null order by flw_inpatient_data_id  */



SELECT distinct IP_FLWSHT_REC.INPATIENT_DATA_ID flw_inpatient_data_id
, fs_9303.fs_Value before_value
			  , case when fs_9303.fs_Value is null then 0
			  when fs_9303.fs_Value = 'abstinence' then 21
			  when fs_9303.fs_Value = 'cervical cap' then 13
			  when fs_9303.fs_Value like '%condom%' and fs_9303.fs_Value like '%female%' then 15
			  when fs_9303.fs_Value like '%condom%' and fs_9303.fs_Value like '% male%' then 12
			  when fs_9303.fs_Value like '%patch%' then 10
			  when fs_9303.fs_Value like '%depo%' then 6
			  when fs_9303.fs_Value like '%diaphragm%' then 14
			  when fs_9303.fs_Value like '%emergency%' then 22
			  when fs_9303.fs_Value like '%hysterectomy%' then 4
			  when fs_9303.fs_Value like '%tubal%' then 4
when fs_9303.fs_Value like '%IUD%' and fs_9303.fs_Value like '%hormon%' and fs_9303.fs_Value not like '%non%'then 2
when fs_9303.fs_Value like '%IUD%' and fs_9303.fs_Value like '%non%' then 3
when fs_9303.fs_Value like '%Nexplanon%' then 1
when fs_9303.fs_Value like '%non%' and fs_9303.fs_Value like '%FDA%' then 23
when fs_9303.fs_Value like '%none%' or fs_9303.fs_Value like '%no method%' then 24
when fs_9303.fs_Value like '%Ring%' then 11
when fs_9303.fs_Value like '%oral%' then 8
when fs_9303.fs_Value like '%pregnant%' then 27
when fs_9303.fs_Value like '%rhythm%' or fs_9303.fs_Value like '%FAM%' OR fs_9303.fs_Value like '%awareness%' then 19
when fs_9303.fs_Value like '%lactation%' or fs_9303.fs_Value like '%LAM%' then 20
when fs_9303.fs_Value like '%seeking%' THEN 28
when fs_9303.fs_Value like '%cide%' or 
     fs_9303.fs_Value like '%gel%' or 
	 fs_9303.fs_Value like '%jelly%' or 
	 fs_9303.fs_Value like '%foam%' or 
	 fs_9303.fs_Value like '%cream%' or 
	 fs_9303.fs_Value like '%cide%' or 
	 fs_9303.fs_Value like '%film%' or
	 fs_9303.fs_Value like '%phexxi%' THEN 17 
when fs_9303.fs_Value like '%unknown%' then 0
when fs_9303.fs_Value like '%vasectomy%' then 5
when fs_9303.fs_Value like '%withdrawal%' then 16
	else 29 -- when fs_9303.fs_Value like '%other%' then 29
end	beginvisit_contraception
			  , fs_9304.fs_Value after_value
			  , case when fs_9304.fs_Value is null then 0
			  when fs_9304.fs_Value = 'abstinence' then 21
			  when fs_9304.fs_Value = 'cervical cap' then 13
			  when fs_9304.fs_Value like '%condom%' and fs_9304.fs_Value like '%female%' then 15
			  when fs_9304.fs_Value like '%condom%' and fs_9304.fs_Value like '% male%' then 12
			  when fs_9304.fs_Value like '%patch%' then 10
			  when fs_9304.fs_Value like '%depo%' then 6
			  when fs_9304.fs_Value like '%diaphragm%' then 14
			  when fs_9304.fs_Value like '%emergency%' then 22
			  when fs_9304.fs_Value like '%hysterectomy%' then 4
			  when fs_9304.fs_Value like '%tubal%' then 4
when fs_9304.fs_Value like '%IUD%' and fs_9304.fs_Value like '%hormon%' and fs_9304.fs_Value not like '%non%'then 2
when fs_9304.fs_Value like '%IUD%' and fs_9304.fs_Value like '%non%' then 3
when fs_9304.fs_Value like '%Nexplanon%' then 1
when fs_9304.fs_Value like '%non%' and fs_9304.fs_Value like '%FDA%' then 23
when fs_9304.fs_Value like '%none%' or fs_9304.fs_Value like '%no method%' then 24
when fs_9304.fs_Value like '%Ring%' then 11
when fs_9304.fs_Value like '%oral%' then 8
when fs_9304.fs_Value like '%pregnant%' then 27
when fs_9304.fs_Value like '%rhythm%' or fs_9304.fs_Value like '%FAM%' OR fs_9304.fs_Value like '%awareness%' then 19
when fs_9304.fs_Value like '%lactation%' or fs_9304.fs_Value like '%LAM%' then 20
when fs_9304.fs_Value like '%seeking%' THEN 28
when fs_9304.fs_Value like '%cide%' or 
     fs_9304.fs_Value like '%gel%' or 
	 fs_9304.fs_Value like '%jelly%' or 
	 fs_9304.fs_Value like '%foam%' or 
	 fs_9304.fs_Value like '%cream%' or 
	 fs_9304.fs_Value like '%cide%' or 
	 fs_9304.fs_Value like '%film%' or
	 fs_9304.fs_Value like '%phexxi%' THEN 17 
when fs_9304.fs_Value like '%unknown%' then 0
when fs_9304.fs_Value like '%vasectomy%' then 5
when fs_9304.fs_Value like '%withdrawal%' then 16
	else 29 -- other
			    end aftervisit_contraception
			 FROM IP_FLWSHT_REC 
			  LEFT JOIN ( SELECT INPATIENT_DATA_ID INPAT_DATA_ID 
			               , MEAS_VALUE fs_Value 
						   , FLT_ID fs_flt
					       , ROW_NUMBER ( ) OVER ( PARTITION BY INPATIENT_DATA_ID ORDER BY LINE DESC ) RN /* 9303 ELR R TITLE X CONTRACEPTION METHOD SINGLE SELECT */
				          FROM IP_FLWSHT_REC  
						   JOIN IP_FLWSHT_MEAS ON IP_FLWSHT_REC.FSD_ID = IP_FLWSHT_MEAS.FSD_ID 
						    AND FLO_MEAS_ID = '9303' 
							AND ISACCEPTED_YN = 'Y' ) fs_9303 ON fs_9303.INPAT_DATA_ID = IP_FLWSHT_REC.INPATIENT_DATA_ID AND fs_9303.rn = 1
			  LEFT JOIN ( SELECT INPATIENT_DATA_ID INPAT_DATA_ID , MEAS_VALUE fs_Value , FLT_ID fs_flt
					       , ROW_NUMBER ( ) OVER ( PARTITION BY INPATIENT_DATA_ID ORDER BY LINE DESC ) RN /* 9304 ELR R TITLE X CONTRACEPTION AFTER VISIT SINGLE SELECT */
				          FROM IP_FLWSHT_REC 
						   JOIN IP_FLWSHT_MEAS ON IP_FLWSHT_REC.FSD_ID = IP_FLWSHT_MEAS.FSD_ID 
						    AND FLO_MEAS_ID = '9304' 
							AND ISACCEPTED_YN = 'Y' ) fs_9304 ON fs_9304.INPAT_DATA_ID = IP_FLWSHT_REC.INPATIENT_DATA_ID 
		AND fs_9304.rn = 1
GO


