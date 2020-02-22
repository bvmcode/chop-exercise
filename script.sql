------------------------------------------------------
------ get base data and low hanging fruit metrics  -------
------------------------------------------------------
DROP TABLE IF EXISTS tmp_patients;
CREATE TEMP TABLE tmp_patients AS
SELECT distinct 
       e.id as ENCOUNTER_ID,
	   e.patient as PATIENT_ID,
	   case when p.deathdate is null then 0
			when p.deathdate>=e.start and p.deathdate<=e.stop then 1
			else 0
		end as DEATH_AT_VISIT_IND,
		EXTRACT(YEAR FROM age(e.start, p.birthdate)) as AGE_AT_VISIT,
	   e.start as HOSPITAL_ENCOUNTER_DATE,
	   e.stop
FROM encounters as e
	 inner join
	 patients as p on p.id=e.patient
WHERE reasoncode='55680006' 
      and start>'7/15/1999'
	  and EXTRACT(YEAR FROM age(e.start, p.birthdate)) between 18 and 35
;

------------------------------------------------------
------ get meds metrics at start of the encounter ----
------------------------------------------------------
DROP TABLE IF EXISTS tmp_meds;
CREATE TEMP TABLE tmp_meds AS
SELECT t.ENCOUNTER_ID,
	   count(m.code) as COUNT_CURRENT_MEDS,
	   sum(
	      case when (lower(m.description) like '%hydromorphone%'
					 and lower(m.description) like '%325%'
					 and lower(m.description) like '%mg%')
		   			or
		            (lower(m.description) like '%fentanyl%'
					 and lower(m.description)like '%100%'
					 and lower(m.description) like '%mgc%')
		   			or
		   			(lower(m.description) like '%oxycodone%'
					 and lower(m.description) like '%acetaminophen%'
					 and lower(m.description) like '%100%'
					 and lower(m.description) like '%mi%')
		        then 1
		   else 0 end
	   ) as CURRENT_OPIOID_IND
FROM tmp_patients as t
	 left join
	 medications as m on t.PATIENT_ID=m.patient 
                         and t.HOSPITAL_ENCOUNTER_DATE>=m.start 
	                     and (t.HOSPITAL_ENCOUNTER_DATE<=m.stop or m.stop is null)
GROUP BY t.ENCOUNTER_ID
;

								
------------------------------------------------------
------    get readmission metrics  ---------------------
------------------------------------------------------
DROP TABLE IF EXISTS tmp_readmission;
CREATE TEMP TABLE tmp_readmission AS
SELECT p.ENCOUNTER_ID,
	   p.PATIENT_ID,
								p.HOSPITAL_ENCOUNTER_DATE,
	   p2.HOSPITAL_ENCOUNTER_DATE as FIRST_READMISSION_DATE,
	   case when p2.HOSPITAL_ENCOUNTER_DATE - p.HOSPITAL_ENCOUNTER_DATE <=30 then 1 else 0 end as READMISSION_30_DAY_IND,
	   case when p2.HOSPITAL_ENCOUNTER_DATE - p.HOSPITAL_ENCOUNTER_DATE >30 and 
				 p2.HOSPITAL_ENCOUNTER_DATE - p.HOSPITAL_ENCOUNTER_DATE <= 90 then 1 else 0
		end as READMISSION_90_DAY_IND
FROM tmp_patients as p,
	  lateral
	 (
	 	SELECT x.PATIENT_ID, x.ENCOUNTER_ID, x.HOSPITAL_ENCOUNTER_DATE 
		FROM tmp_patients as x
		WHERE x.PATIENT_ID=p.PATIENT_ID and x.HOSPITAL_ENCOUNTER_DATE>p.HOSPITAL_ENCOUNTER_DATE
		ORDER BY x.HOSPITAL_ENCOUNTER_DATE ASC
		FETCH FIRST 1 ROW ONLY
	 )  as p2  
;														
								
------------------------------------------------------
--------------    SUMMARY   --------------------------
------------------------------------------------------
SELECT p.PATIENT_ID,
	   p.ENCOUNTER_ID,
	   p.HOSPITAL_ENCOUNTER_DATE,
	   p.AGE_AT_VISIT,
	   p.DEATH_AT_VISIT_IND,
	   m.COUNT_CURRENT_MEDS,
	   m.CURRENT_OPIOID_IND,
	   case when a.READMISSION_90_DAY_IND is null then 0 else a.READMISSION_90_DAY_IND end as READMISSION_90_DAY_IND ,
	   case when a.READMISSION_30_DAY_IND is null then 0 else a.READMISSION_30_DAY_IND end as READMISSION_30_DAY_IND ,
	   a.FIRST_READMISSION_DATE
FROM tmp_patients as p
 	 left join
 	 tmp_meds as m on m.ENCOUNTER_ID=p.ENCOUNTER_ID
 	 left join
	 tmp_readmission as a on a.ENCOUNTER_ID=p.ENCOUNTER_ID
ORDER BY p.PATIENT_ID, p.HOSPITAL_ENCOUNTER_DATE
	 
					