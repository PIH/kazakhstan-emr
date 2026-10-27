SELECT o.person_id,
(SELECT identifier FROM patient_identifier WHERE voided = 0 AND o.person_id = patient_id) AS 'EMR ID',
o2.form_name AS 'Form name',
DATE(o.obs_datetime) 'Visit date',
(SELECT 
            name
        FROM
            concept_name c
        WHERE
            o.value_coded = c.concept_id
                AND voided = 0
                AND locale = 'en'
                AND concept_name_type = 'SHORT') AS 'Type of support',
o4.value_text AS 'Provider',
(SELECT CONCAT(family_name," ",given_name) FROM person_name WHERE voided = 0 AND person_id = (SELECT person_id FROM users WHERE user_id = o.creator)) AS 'User entered',
DATE(o.date_created) 'Date entered'
FROM
(
SELECT person_id, obs_id, concept_id, obs_group_id, obs_datetime, encounter_id, value_coded, creator, date_created FROM obs WHERE 
DATE(obs_datetime) >= '#startDate#' AND  DATE(obs_datetime) <= '#endDate#'
AND voided = 0 AND concept_id = (
SELECT concept_id FROM concept_reference_term_map_view c WHERE concept_reference_source_name = 'PIH' AND c.code = 'SOCIO-ECONOMIC ASSISTANCE ALREADY RECEIVED')
) o
JOIN obs o6 ON o6.person_id = o.person_id 
AND o6.concept_id = ( SELECT concept_id FROM concept_reference_term_map_view c WHERE concept_reference_source_name = 'PIH-BAH-MH' AND c.code = 'AssistanceGiven')
AND o.obs_group_id = o6.obs_id
LEFT JOIN obs o4 ON o4.person_id = o.person_id AND o6.obs_group_id = o4.obs_group_id AND
o4.concept_id = (SELECT concept_id FROM concept_reference_term_map_view c WHERE concept_reference_source_name = 'PIH-BAH-MH' AND c.code = 'Counselor who completed the session')
JOIN 
( SELECT person_id, encounter_id, obs_datetime, obs_id, obs_group_id, concept_id,
(SELECT 
            name
        FROM
            concept_name c
        WHERE
            o1.concept_id = c.concept_id
                AND voided = 0
                AND locale = 'en'
                AND concept_name_type = 'SHORT' ) form_name
FROM obs o1 WHERE o1.voided = 0 AND o1.obs_id IN (
SELECT obs_group_id FROM obs WHERE voided = 0 AND concept_id = (
SELECT concept_id FROM concept_reference_term_map_view c WHERE concept_reference_source_name = 'PIH-BAH-MH' AND c.code = 'AssistanceGiven')) )
o2 
ON o2.person_id = o.person_id 
AND o6.obs_group_id = o2.obs_id
ORDER BY o.person_id, o.obs_id, o.obs_datetime;
