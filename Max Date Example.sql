Select 
Account_ID --Primary Key
, FPL_EFF_Date
,FPL_INCOME
,FPL_FAMILY_SIZE
,FPL_PERCENTAGE
--,FPL_EXP_DATE
From (Select *,
          RANK() 
		  over(order by FPL_EFF_Date desc) as The_rank
		  from ACCOUNT_FPL_INFO
		  Where ACCOUNT_ID = '50042248'
		  ) Account
Where The_rank =1