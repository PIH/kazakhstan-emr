SELECT 	o.person_id AS patient_id,
	(SELECT identifier FROM patient_identifier pi WHERE pi.patient_id = o.person_id AND pi.voided = 0 ) emr_id, 
	DATE(o.obs_datetime) AS visit_date, 
        o.value_text AS medication, 
        DATE(o.date_created) AS date_entered, 
        (SELECT CONCAT(family_name," ",given_name) FROM person_name WHERE voided = 0 AND person_id = 
        (SELECT person_id FROM users WHERE user_id = o1.creator)) AS 'user_entered'
FROM obs o JOIN obs o1 ON o1.person_id = o.person_id AND o.voided = 0 AND o1.voided = 0 
AND o.concept_id = (SELECT concept_id FROM concept_reference_term_map_view c WHERE concept_reference_source_name = 'PIH-BAH-MH' AND c.code = 'Medications-Drug') 
AND o.obs_id = o1.obs_id
AND o.obs_datetime >= '#startDate#' AND o.obs_datetime <= '#endDate#';
