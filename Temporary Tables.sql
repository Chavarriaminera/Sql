
Select person_id, enc_id, pregNum, hospitalName /*selecting the variables*/ 
INTO #Preggers /*putting the variables into a temporary table*/
from stg.OB_Prenatal_Flow_
where hospitalName is not null

Select *
From #Preggers


Select person_id, encounterID, birthOUTCOME,fetusSex, fetusWeight, hospital,laborINDUCTION /*selecting the variables*/ 
INTO #Preggers2 /*putting the variables into a temporary table*/ 
from stg.OB_postpartPregHx_extended_
where person_id is not null
and encounterID is not null
and birthOUTCOME is not null
and fetusSex is not null
and fetusWeight is not null
and hospital is not null 
and laborINDUCTION is not null


Select #Preggers.person_id , #Preggers.enc_id, #Preggers.pregNum, #Preggers.hospitalName,
#Preggers2.person_id  person_ID2 , #Preggers2.encounterID, #Preggers2.birthOUTCOME,#Preggers2.fetusSex,
#Preggers2.fetusWeight, #Preggers2.hospital,#Preggers2.laborINDUCTION /*selecting the variables from the temporary tables above*/ 
into #ultimatePreggers  /*putting the variables into a temporary table*/
from #Preggers
inner join #Preggers2 /* doing the inner join of the temporary table*/
on #Preggers.person_id = #Preggers2.person_id

/* the final table*/
Select *
from #ultimatePreggers 