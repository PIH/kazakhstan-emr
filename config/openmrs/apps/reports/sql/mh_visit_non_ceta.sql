SELECT o.person_id,
(SELECT identifier FROM patient_identifier WHERE voided = 0 AND o.person_id = patient_id) AS 'EMR ID',
DATE(o.obs_datetime) 'Visit date',
(SELECT 
            name
        FROM
            concept_name c
        WHERE
            o1.value_coded = c.concept_id
                AND voided = 0
                AND locale = 'en'
                AND concept_name_type = 'SHORT') AS 'Mental health intervention',
 (SELECT
            name
        FROM
            concept_name c
        WHERE
            o7.value_coded = c.concept_id
                AND voided = 0
                AND locale = 'en'
                AND concept_name_type = 'SHORT') AS 'Diagnosis',
(SELECT 
            name
        FROM
            concept_name c
        WHERE
            o2.value_coded = c.concept_id
                AND voided = 0
                AND locale = 'en'
                AND concept_name_type = 'SHORT') AS 'Inpatient',
(SELECT 
            name
        FROM
            concept_name c
        WHERE
            o3.value_coded = c.concept_id
                AND voided = 0
                AND locale = 'en'
                AND concept_name_type = 'SHORT') AS 'High Risk',
(SELECT 
            name
        FROM
            concept_name c
        WHERE
            o4.value_coded = c.concept_id
                AND voided = 0
                AND locale = 'en'
                AND concept_name_type = 'SHORT') AS 'Mental Health Crisis Plan',
o5.value_numeric 'PHQ-9 score',
DATE(o6.value_datetime) 'Return visit date',
DATE(o.date_created) 'Date entered',
		(SELECT CONCAT(family_name," ",given_name) FROM person_name WHERE voided = 0 AND person_id = 
       (SELECT person_id FROM users WHERE user_id = o.creator)) AS 'User entered'
FROM
(
SELECT person_id, obs_id, obs_group_id, encounter_id, obs_datetime, date_created, creator FROM obs WHERE voided = 0 AND concept_id = (
SELECT concept_id FROM concept_name WHERE name = 'MH, Visit Template' AND voided = 0 AND concept_name_type = 'FULLY_SPECIFIED' AND locale = 'en'
) AND DATE(obs_datetime) >= '#startDate#' AND DATE(obs_datetime) <= '#endDate#' ) o LEFT JOIN obs o1 
ON o1.person_id = o.person_id  
AND o1.encounter_id = o.encounter_id 
AND o1.obs_datetime = o.obs_datetime 
AND o1.voided = 0 
AND o1.concept_id = (SELECT concept_id FROM concept_reference_term_map_view c WHERE concept_reference_source_name = 'PIH' AND c.code = 'Mental health intervention')
LEFT JOIN obs o2 
ON o2.person_id = o.person_id  
AND o2.encounter_id = o.encounter_id 
AND o2.obs_datetime = o.obs_datetime 
AND o2.voided = 0 
AND o2.concept_id = (SELECT concept_id FROM concept_reference_term_map_view c WHERE concept_reference_source_name = 'PIH' AND c.code = '6134') 
AND o2.obs_group_id IN 
(SELECT obs_id FROM obs WHERE voided = 0 AND concept_id = (
SELECT concept_id FROM concept_name WHERE name = 'MH, Visit Template' AND voided = 0 AND concept_name_type = 'FULLY_SPECIFIED' AND locale = 'en'
))
LEFT JOIN obs o3
ON o3.person_id = o.person_id  
AND o3.encounter_id = o.encounter_id 
AND o3.obs_datetime = o.obs_datetime 
AND o3.voided = 0 
AND o3.concept_id = (SELECT concept_id FROM concept_reference_term_map_view c WHERE concept_reference_source_name = 'PIH-BAH-MH' AND c.code = 'HighRisk')
LEFT JOIN obs o4
ON o4.person_id = o.person_id  
AND o4.encounter_id = o.encounter_id 
AND o4.obs_datetime = o.obs_datetime 
AND o4.voided = 0 
AND o4.concept_id = (SELECT concept_id FROM concept_reference_term_map_view c WHERE concept_reference_source_name = 'PIH-BAH-MH' AND c.code = 'MentalHealthCrisisPlan')
LEFT JOIN obs o5
ON o5.person_id = o.person_id  
AND o5.encounter_id = o.encounter_id 
AND o5.obs_datetime = o.obs_datetime 
AND o5.voided = 0
AND o5.concept_id = (SELECT concept_id FROM concept_reference_term_map_view c WHERE concept_reference_source_name = 'CIEL' AND c.code = '165137')
LEFT JOIN obs o6
ON o6.person_id = o.person_id  
AND o6.encounter_id = o.encounter_id 
AND o6.obs_datetime = o.obs_datetime 
AND o6.voided = 0
AND o6.concept_id = (SELECT concept_id FROM concept_reference_term_map_view c WHERE concept_reference_source_name = 'PIH' AND c.code = 'RETURN VISIT DATE')
AND o6.obs_group_id IN 
(SELECT obs_id FROM obs WHERE voided = 0 AND concept_id = (
SELECT concept_id FROM concept_name WHERE name = 'MH, Visit Template' AND voided = 0 AND concept_name_type = 'FULLY_SPECIFIED' AND locale = 'en'
))
JOIN obs o7
ON o7.person_id = o.person_id  
AND o7.voided = 0
AND o7.concept_id = (SELECT concept_id FROM concept_reference_term_map_view c WHERE concept_reference_source_name = 'PIH' AND c.code = 'DIAGNOSIS')
AND o7.obs_group_id IN 
(SELECT MAX(obs_id) FROM obs WHERE voided = 0 AND concept_id = (
SELECT concept_id FROM concept_name WHERE name = 'MH, Baseline Template' AND voided = 0 AND concept_name_type = 'FULLY_SPECIFIED' AND locale = 'en'
) GROUP BY person_id ) 
ORDER BY o.person_id;
