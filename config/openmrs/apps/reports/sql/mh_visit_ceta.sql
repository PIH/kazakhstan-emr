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
o1.value_text AS 'provide name',
(SELECT 
            name
        FROM
            concept_name c
        WHERE
            o2.value_coded = c.concept_id
                AND voided = 0
                AND locale = 'en'
                AND concept_name_type = 'SHORT') AS 'Type of session',
(SELECT 
            name
        FROM
            concept_name c
        WHERE
            o3.value_coded = c.concept_id
                AND voided = 0
                AND locale = 'en'
                AND concept_name_type = 'SHORT') AS 'Outcome of session',
(SELECT 
            name
        FROM
            concept_name c
        WHERE
            o4.value_coded = c.concept_id
                AND voided = 0
                AND locale = 'en'
                AND concept_name_type = 'SHORT') AS 'Reason session was missed',
o5.value_numeric AS 'Problem score',
o6.value_numeric AS 'Substance use score',
o7.value_numeric AS 'Client monitoring score',
o8.value_numeric AS 'Relaxation score',
o9.value_numeric AS 'General depression score',
o10.value_numeric AS 'Getting active score',
o11.value_numeric AS 'Live exposure score',
o12.value_numeric AS 'Alcohol use score',
o14.value_numeric AS 'Talking about difficult memories score',
o15.value_numeric AS 'Thinking different way score',
o16.value_numeric AS 'Solving problems score',
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
LEFT JOIN obs o1
ON o1.person_id = o.person_id  
AND o1.encounter_id = o.encounter_id 
AND o1.obs_datetime = o.obs_datetime 
AND o1.voided = 0 
AND o1.concept_id = (SELECT concept_id FROM concept_reference_term_map_view c WHERE concept_reference_source_name = 'PIH-BAH-MH' AND c.code = 'Counselor who completed the session')
LEFT JOIN obs o2
ON o2.person_id = o.person_id  
AND o2.encounter_id = o.encounter_id 
AND o2.obs_datetime = o.obs_datetime 
AND o2.voided = 0 
AND o2.concept_id = (SELECT concept_id FROM concept_reference_term_map_view c WHERE concept_reference_source_name = 'PIH-BAH-MH' AND c.code = 'Session Type') 
LEFT JOIN obs o3
ON o3.person_id = o.person_id  
AND o3.encounter_id = o.encounter_id 
AND o3.obs_datetime = o.obs_datetime 
AND o3.voided = 0 
AND o3.concept_id = (SELECT concept_id FROM concept_reference_term_map_view c WHERE concept_reference_source_name = 'PIH-BAH-MH' AND c.code = 'Outcome of Session') 
LEFT JOIN obs o4
ON o4.person_id = o.person_id  
AND o4.encounter_id = o.encounter_id 
AND o4.obs_datetime = o.obs_datetime 
AND o4.voided = 0 
AND o4.concept_id = (SELECT concept_id FROM concept_reference_term_map_view c WHERE concept_reference_source_name = 'PIH-BAH-MH' AND c.code = 'Reason the session was missed') 
LEFT JOIN obs o5
ON o5.person_id = o.person_id  
AND o5.encounter_id = o.encounter_id 
AND o5.obs_datetime = o.obs_datetime 
AND o5.voided = 0 
AND o5.concept_id = (SELECT concept_id FROM concept_reference_term_map_view c WHERE concept_reference_source_name = 'PIH-BAH-MH' AND c.code = 'CMT Solving Problems Score') 
LEFT JOIN obs o6
ON o6.person_id = o.person_id  
AND o6.encounter_id = o.encounter_id 
AND o6.obs_datetime = o.obs_datetime 
AND o6.voided = 0 
AND o6.concept_id = (SELECT concept_id FROM concept_reference_term_map_view c WHERE concept_reference_source_name = 'PIH-BAH-MH' AND c.code = 'CMT Substance Use Score') 
LEFT JOIN obs o7
ON o7.person_id = o.person_id  
AND o7.encounter_id = o.encounter_id 
AND o7.obs_datetime = o.obs_datetime 
AND o7.voided = 0 
AND o7.concept_id = (SELECT concept_id FROM concept_reference_term_map_view c WHERE concept_reference_source_name = 'PIH-BAH-MH' AND c.code = 'CM Monitoring Score') 
LEFT JOIN obs o8
ON o8.person_id = o.person_id  
AND o8.encounter_id = o.encounter_id 
AND o8.obs_datetime = o.obs_datetime 
AND o8.voided = 0 
AND o8.concept_id = (SELECT concept_id FROM concept_reference_term_map_view c WHERE concept_reference_source_name = 'PIH-BAH-MH' AND c.code = 'CMT Relaxation Score') 
LEFT JOIN obs o9
ON o9.person_id = o.person_id  
AND o9.encounter_id = o.encounter_id 
AND o9.obs_datetime = o.obs_datetime 
AND o9.voided = 0 
AND o9.concept_id = (SELECT concept_id FROM concept_reference_term_map_view c WHERE concept_reference_source_name = 'PIH-BAH-MH' AND c.code = 'General Depression Score') 
LEFT JOIN obs o10
ON o10.person_id = o.person_id  
AND o10.encounter_id = o.encounter_id 
AND o10.obs_datetime = o.obs_datetime 
AND o10.voided = 0 
AND o10.concept_id = (SELECT concept_id FROM concept_reference_term_map_view c WHERE concept_reference_source_name = 'PIH-BAH-MH' AND c.code = 'CMT Getting Active Score') 
LEFT JOIN obs o11
ON o11.person_id = o.person_id  
AND o11.encounter_id = o.encounter_id 
AND o11.obs_datetime = o.obs_datetime 
AND o11.voided = 0 
AND o11.concept_id = (SELECT concept_id FROM concept_reference_term_map_view c WHERE concept_reference_source_name = 'PIH-BAH-MH' AND c.code = 'CMT Live Exposure Score') 
LEFT JOIN obs o12
ON o12.person_id = o.person_id  
AND o12.encounter_id = o.encounter_id 
AND o12.obs_datetime = o.obs_datetime 
AND o12.voided = 0 
AND o12.concept_id = (SELECT concept_id FROM concept_reference_term_map_view c WHERE concept_reference_source_name = 'PIH-BAH-MH' AND c.code = 'CMT Alcohol Use Score') 
LEFT JOIN obs o14
ON o14.person_id = o.person_id  
AND o14.encounter_id = o.encounter_id 
AND o14.obs_datetime = o.obs_datetime 
AND o14.voided = 0 
AND o14.concept_id = (SELECT concept_id FROM concept_reference_term_map_view c WHERE concept_reference_source_name = 'PIH-BAH-MH' AND c.code = 'CMT Difficult Memories Score') 
LEFT JOIN obs o15
ON o15.person_id = o.person_id  
AND o15.encounter_id = o.encounter_id 
AND o15.obs_datetime = o.obs_datetime 
AND o15.voided = 0 
AND o15.concept_id = (SELECT concept_id FROM concept_reference_term_map_view c WHERE concept_reference_source_name = 'PIH-BAH-MH' AND c.code = 'Thinking Different Way Score') 
LEFT JOIN obs o16
ON o16.person_id = o.person_id  
AND o16.encounter_id = o.encounter_id 
AND o16.obs_datetime = o.obs_datetime 
AND o16.voided = 0 
AND o16.concept_id = (SELECT concept_id FROM concept_reference_term_map_view c WHERE concept_reference_source_name = 'PIH-BAH-MH' AND c.code = 'CMT Solving Problems Score') 
LEFT JOIN obs o19
ON o19.person_id = o.person_id  
AND o19.encounter_id = o.encounter_id 
AND o19.obs_datetime = o.obs_datetime 
AND o19.voided = 0
AND o19.concept_id = (SELECT concept_id FROM concept_reference_term_map_view c WHERE concept_reference_source_name = 'PIH' AND c.code = 'RETURN VISIT DATE')
AND o19.obs_group_id IN (o.obs_id)
ORDER BY o.person_id, o.obs_datetime;
