--3/7/2023- Arredondo would like a list of her ICD codes for Psy License. Cindy C Minera
SELECT
	*
FROM (
	-- We have a problem, some patients have multiple codes for the same thing but this report should not be on the ganularity of codes but a list of ICD codes and descriptions
	-- so use the rank windowing function on a one patient per provider per location per day PER TYPE (that way we get insert/remove on the same day)
	SELECT
		*,

		ROW_NUMBER() OVER(PARTITION BY d_encounter_ky, enc_timestamp, icd_code ORDER BY d_patient_ky DESC, enc_timestamp desc ) AS Ranking
		--I did the partition by the encounter key, then the time stamp, and the ICD_code because I want to get rid of duplicates. I wanted to order by the patient ID and the date. 
	FROM(
		SELECT 
		f_charges.f_charges_ky  
		,f_charges.[d_encounter_ky]
		,f_charges.[d_patient_ky]
		,f_charges.[d_provider_ky]
		,f_charges.[d_location_ky]
		,f_charges.[d_service_item_ky]  
		,f_charges.[enc_timestamp]

		, D_PATIENT.first_name
		, D_PATIENT.last_name
		, D_PATIENT.mrn
		, D_PATIENT.date_of_birth
     
		, [D_SERVICE_ITEM].service_item_id 
		, [D_SERVICE_ITEM].[cpt_desc]
		, D_PROVIDER.provider_name
		, D_PROVIDER.provider_subgroup
		, D_LOCATION.location_name
		, D_DEPT.DeptName as DeptName

	    ,F_DIAGNOSIS.icd_code
		,[D_DIAGNOSIS_CODE].diag_description


		FROM [DM_FINANCE].[dbo].f_charges
		INNER JOIN [DM_FINANCE].[dbo].[D_SERVICE_ITEM] on [D_SERVICE_ITEM].d_service_item_ky = f_charges.d_service_item_ky
		INNER JOIN [DM_FINANCE].[dbo].D_PROVIDER on D_PROVIDER.d_provider_ky = f_charges.d_provider_ky
		INNER JOIN [DM_FINANCE].[dbo].D_LOCATION on D_LOCATION.d_location_ky = f_charges.d_location_ky
		INNER JOIN [DM_FINANCE].[dbo].D_DEPT on D_DEPT.d_dept_ky = f_charges.d_dept_ky
		INNER JOIN DM_FINANCE.dbo.F_ENCOUNTERS on F_ENCOUNTERS.d_encounter_ky = f_charges.[d_encounter_ky]
		INNER JOIN [DM_FINANCE].[dbo].D_PATIENT on D_PATIENT.d_patient_ky = f_charges.d_patient_ky
		INNER JOIN [DM_FINANCE].[dbo].[F_DIAGNOSIS] ON [F_DIAGNOSIS].d_encounter_ky=f_charges.[d_encounter_ky]
		INNER JOIN [DM_FINANCE].[dbo].[D_DIAGNOSIS_CODE]ON [F_DIAGNOSIS].d_diagnosis_code_ky=[D_DIAGNOSIS_CODE].d_diagnosis_code_ky
		where 
		 D_PROVIDER.provider_name like '%Chavarria%'
		and f_charges.enc_timestamp >= '3/01/2022'

	) as Ranked
) AS RankingFinished
WHERE Ranking=1



