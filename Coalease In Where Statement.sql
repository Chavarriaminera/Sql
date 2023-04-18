USE DM_FINANCE
Select 
C.ProviderNumber
,C.Provider_Name
,C.StartDate
,C.EndDate
,C.ClinicSessions
,C.d_provider_ky
,C.Create_TimeStamp
,C.Create_User
,C.Modify_TimeStamp
,C.Modify_User
From Incentive.D_ClinicSessions AS  C
Where Coalesce (delete_ind, 'N')='N'
Order BY C.StartDate desc, C.EndDate desc, C.provider_name
