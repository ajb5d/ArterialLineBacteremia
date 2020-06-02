-- !preview conn=con
WITH postive_blood_cultures AS (
	SELECT DISTINCT
		hadm_id
		,  COALESCE(charttime, chartdate) AS "charttime"
	FROM
		microbiologyevents
	WHERE 
		spec_itemid = 70012
		AND org_itemid IS NOT NULL
), first_blood_culture AS (
	SELECT
		postive_blood_cultures.hadm_id
		, icustays.icustay_id
		, MIN(postive_blood_cultures.charttime) AS "first_blood_culture"
		, COUNT(*) AS "blood_culture_count"
	FROM
		postive_blood_cultures
	LEFT JOIN admissions USING (hadm_id)
	LEFT JOIN icustays USING (hadm_id)
	WHERE
		charttime > admittime + '48 hours' 
		AND charttime BETWEEN icustays.intime AND icustays.outtime + '48 hours'
	GROUP BY hadm_id, icustay_id
), cases AS (
	SELECT
		icustay_id
		, CASE
			WHEN first_blood_culture < outtime THEN first_blood_culture
			ELSE outtime
		END AS "event_time"
		, CASE
			WHEN first_blood_culture < outtime THEN TRUE
			ELSE FALSE
		END AS "culture_positive"
	FROM
		icustays
	LEFT JOIN first_blood_culture USING (icustay_id)
), arterial_lines AS (
	SELECT  
		icustay_id
		, SUM(CASE 
			WHEN endtime < event_time THEN endtime - starttime
			WHEN event_time <= endtime THEN event_time - starttime
			ELSE NULL 
		END) AS "arterial_line_duration"
	FROM 	
		cases
	JOIN arterial_line_durations USING (icustay_id)
	WHERE
		starttime < event_time
	GROUP BY icustay_id
), central_lines AS (
	SELECT  
		icustay_id
		, SUM(CASE 
			WHEN endtime < event_time THEN endtime - starttime
			WHEN event_time <= endtime THEN event_time - starttime
			ELSE NULL 
		END) AS "central_line_duration"
	FROM 	
		cases
	JOIN central_line_durations USING (icustay_id)
	WHERE
		starttime < event_time
	GROUP BY icustay_id
), first_services AS (
	SELECT
		icustay_id
		, intime
		, outtime
		, transfertime
		, curr_service
		, first_careunit
		, CASE 
			WHEN curr_service IN ('MED', 'CMED', 'NMED', 'OMED', 'GU', 'GYN', 'ENT', 'OBS') THEN 'medical'
			WHEN curr_service IN ('CSURG', 'TRAUM', 'SURG', 'NSURG', 'TSURG', 'VSURG', 'ORTHO', 'PSURG', 'DENT') THEN 'surgical' 
			WHEN curr_service IN ('NB', 'NBB') THEN 'pediatric'
			ELSE NULL END AS "service_type"
		, CASE
			WHEN first_careunit IN ('MICU', 'CCU') THEN 'medical'
			WHEN first_careunit IN ('CSRU', 'TSICU', 'SICU') THEN 'surgical'
			WHEN first_careunit IN ('NICU') THEN 'pediatric'
			ELSE NULL END AS "unit_type"
		, ROW_NUMBER() OVER(PARTITION BY icustay_id ORDER BY transfertime DESC) as "row_n"
	FROM
		icustays
	LEFT JOIN services ON 
			services.hadm_id = icustays.hadm_id
			AND transfertime <= intime
), first_service AS (
	SELECT
		* 
	FROM
		first_services
	WHERE row_n = 1
), admit_to_icu AS (
	SELECT
		icustay_id
		, TRUE AS "icu_first"
	FROM
		transfers
	WHERE
	eventtype = 'admit'
		AND icustay_id IS NOT NULL
)
SELECT
	icustay_id
	, icustays.subject_id
	, icustays.hadm_id
	, EXTRACT(EPOCH FROM age(admissions.admittime, patients.dob)) / (365.25*24*60*60) AS age_at_admission
	, patients.gender
	, elixhauser_sid30
	, icustays.intime
	, COALESCE(admit_to_icu.icu_first, FALSE) AS "icu_first"
	, event_time
	, culture_positive
	, icustays.los as "icu_los"
	, EXTRACT(EPOCH FROM COALESCE(arterial_lines.arterial_line_duration, interval '0 minutes')) / (60 * 60 * 24) AS "arterial_line"
	, EXTRACT(EPOCH FROM COALESCE(central_lines.central_line_duration, interval '0 minutes')) / (60 * 60 * 24) AS "central_line"
	, COALESCE(service_type, unit_type) AS "admission_type"
	, icustays.dbsource as "data_source"
	, sapsii.sapsii
	, sapsii.sapsii_prob
	, oasis.oasis
	, oasis.oasis_prob
	, angus_sepsis.angus AS sepsis
FROM 
	cases
LEFT JOIN icustays USING (icustay_id)
LEFT JOIN first_service USING (icustay_id)
LEFT JOIN arterial_lines USING (icustay_id)
LEFT JOIN central_lines USING (icustay_id)
LEFT JOIN sapsii USING (icustay_id, hadm_id, subject_id)
LEFT JOIN oasis USING (icustay_id, hadm_id, subject_id)
LEFT JOIN admit_to_icu USING (icustay_id)
LEFT JOIN admissions USING (hadm_id, subject_id) 
LEFT JOIN patients USING(subject_id)
LEFT JOIN elixhauser_ahrq_score USING (hadm_id, subject_id)
LEFT JOIN angus_sepsis USING (hadm_id, subject_id)
WHERE
	age(admissions.admittime, patients.dob) > '18 years'