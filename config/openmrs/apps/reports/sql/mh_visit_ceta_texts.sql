SELECT o.person_id,
(SELECT identifier FROM patient_identifier WHERE voided = 0 AND o.person_id = patient_id) AS 'EMR ID',
DATE(o.obs_datetime) 'Visit date',
(SELECT 
            name
        FROM
            concept_name c
        WHERE
            o.concept_id = c.concept_id
                AND voided = 0
                AND locale = 'en'
                AND concept_name_type = 'SHORT'

) 'visit type',
(SELECT 
            name
        FROM
            concept_name c
        WHERE
            o13.value_coded = c.concept_id
                AND voided = 0
                AND locale = 'en'
                AND concept_name_type = 'SHORT') AS 'High risk',
(SELECT 
            name
        FROM
            concept_name c
        WHERE
            o17.value_coded = c.concept_id
                AND voided = 0
                AND locale = 'en'
                AND concept_name_type = 'SHORT') AS 'CETA treatment flow',
o18.components AS 'Component done',
DATE(o19.value_datetime) 'Return visit date',
DATE(o.date_created) 'Date entered',
(SELECT CONCAT(family_name," ",given_name) FROM person_name WHERE voided = 0 AND person_id = (SELECT person_id FROM users WHERE user_id = o.creator)) AS 'User entered'
FROM
(
SELECT person_id, obs_id, obs_group_id, encounter_id, obs_datetime, date_created, creator, concept_id 
FROM obs WHERE voided = 0 AND DATE(obs_datetime) BETWEEN '#startDate#' AND '#endDate#'
AND concept_id IN (
(SELECT concept_id FROM concept_name WHERE name = 'MH, Common Elements Treatment Approach Baseline Visit Template' AND voided = 0 AND concept_name_type = 'FULLY_SPECIFIED' AND locale = 'en'), 
(SELECT concept_id FROM concept_name WHERE name = 'MH, Common Elements Treatment Approach Follow-up Visit Template' AND voided = 0 AND concept_name_type = 'FULLY_SPECIFIED' AND locale = 'en')
)) o
LEFT JOIN obs o13
ON o13.person_id = o.person_id  
AND o13.encounter_id = o.encounter_id 
AND o13.obs_datetime = o.obs_datetime 
AND o13.voided = 0 
AND o13.concept_id IN( (SELECT concept_id FROM concept_reference_term_map_view c WHERE concept_reference_source_name = 'PIH-BAH-MH' AND c.code = 'High Risk'),
(SELECT concept_id FROM concept_reference_term_map_view c WHERE concept_reference_source_name = 'PIH-BAH-MH' AND c.code = 'Patient High Risk')
) 
LEFT JOIN obs o17
ON o17.person_id = o.person_id  
AND o17.encounter_id = o.encounter_id 
AND o17.obs_datetime = o.obs_datetime 
AND o17.voided = 0 
AND o17.concept_id = (SELECT GROUP_CONCAT(concept_id) FROM concept_reference_term_map_view c WHERE concept_reference_source_name = 'PIH-BAH-MH' AND c.code = 'CETA Treatment Flow') 
LEFT JOIN
(
select person_id, encounter_id, obs_datetime, obs_group_id, value_coded, group_concat(oo.components) components from
(
select person_id, encounter_id, obs_datetime, obs_group_id, value_coded, c.name components from
obs o20 join 
concept_name c
ON value_coded = c.concept_id
                AND c.voided = 0
                AND c.locale = 'en'
                AND c.concept_name_type = 'SHORT'
and
o20.voided = 0 and
o20.concept_id IN ((SELECT concept_id FROM concept_reference_term_map_view c WHERE concept_reference_source_name = 'PIH-BAH-MH' AND c.code = 'Component Done'),
(SELECT concept_id FROM concept_reference_term_map_view c WHERE concept_reference_source_name = 'PIH-BAH-MH' AND c.code = 'Baseline Component Done')
)
) oo group by oo.obs_group_id
) o18
ON o18.person_id = o.person_id
AND o18.encounter_id = o.encounter_id
AND o18.obs_datetime = o.obs_datetime
LEFT JOIN obs o19
ON o19.person_id = o.person_id  
AND o19.encounter_id = o.encounter_id 
AND o19.obs_datetime = o.obs_datetime 
AND o19.voided = 0
AND o19.concept_id = (SELECT concept_id FROM concept_reference_term_map_view c WHERE concept_reference_source_name = 'PIH' AND c.code = 'RETURN VISIT DATE')
AND o19.obs_group_id IN (o.obs_id)

ORDER BY o.person_id, o.obs_datetime;
