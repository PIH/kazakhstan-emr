SELECT pi.patient_id AS 'patient_id', 
		identifier AS 'emr_id',
        (SELECT 
            name
        FROM
            concept_name c
        WHERE
            o.value_coded = c.concept_id
                AND voided = 0
                AND locale = 'en'
                AND concept_name_type = 'SHORT') AS 'diagnosis',
		IF(o6.value_coded = (SELECT concept_id FROM concept WHERE uuid = '657837b7-9bf2-42eb-b61b-20569f1cfc97') AND o7.value_coded IS NOT NULL, 'Both', IF(o6.value_coded = 
        (SELECT concept_id FROM concept WHERE uuid = '657837b7-9bf2-42eb-b61b-20569f1cfc97'), 'HIV' , IF(o7.value_coded IS NOT NULL, 'TB',
                NULL))) AS 'comorbid condition',
		(SELECT 
            name
        FROM
            concept_name c
        WHERE
            o1.concept_id = c.concept_id
                AND voided = 0
                AND locale = 'en'
                AND concept_name_type = 'SHORT') AS 'symptoms',
	   IF(
       o1.concept_id = (SELECT DISTINCT(concept_id) FROM concept_reference_term_map_view c WHERE concept_reference_source_name = 'CIEL' AND c.code = '158801'),
       (SELECT value_numeric FROM obs WHERE voided = 0 AND  o1.obs_group_id = obs.obs_group_id AND
       concept_id = (SELECT concept_id FROM concept_reference_term_map_view c WHERE concept_reference_source_name = 'PIH-BAH-MH' AND c.code = 'DepressionSympDuration')),
       IF(o1.concept_id = (SELECT DISTINCT(concept_id) FROM concept_reference_term_map_view c WHERE concept_reference_source_name = 'CIEL' AND c.code = '139146'),
       (SELECT value_numeric FROM obs WHERE voided = 0 AND  o1.obs_group_id = obs.obs_group_id AND
       concept_id = (SELECT concept_id FROM concept_reference_term_map_view c WHERE concept_reference_source_name = 'PIH-BAH-MH' AND c.code = 'HallucinationDuration')),
       IF(o1.concept_id = (SELECT DISTINCT(concept_id) FROM concept_reference_term_map_view c WHERE concept_reference_source_name = 'CIEL' AND c.code = '119570'),
       (SELECT value_numeric FROM obs WHERE voided = 0 AND  o1.obs_group_id = obs.obs_group_id AND
       concept_id = (SELECT concept_id FROM concept_reference_term_map_view c WHERE concept_reference_source_name = 'PIH-BAH-MH' AND c.code = 'DelusionDuration')),
       IF(o1.concept_id = (SELECT DISTINCT(concept_id) FROM concept_reference_term_map_view c WHERE concept_reference_source_name = 'CIEL' AND c.code = '137668'),
       (SELECT value_numeric FROM obs WHERE voided = 0 AND  o1.obs_group_id = obs.obs_group_id AND
       concept_id = (SELECT concept_id FROM concept_reference_term_map_view c WHERE concept_reference_source_name = 'PIH-BAH-MH' AND c.code = 'InappropBehaviorDuration')),
       IF(o1.concept_id = (SELECT DISTINCT(concept_id) FROM concept_reference_term_map_view c WHERE concept_reference_source_name = 'CIEL' AND c.code = '137646'),
       (SELECT value_numeric FROM obs WHERE voided = 0 AND  o1.obs_group_id = obs.obs_group_id AND
       concept_id = (SELECT concept_id FROM concept_reference_term_map_view c WHERE concept_reference_source_name = 'PIH-BAH-MH' AND c.code = 'IncoherentSpeechDuration')),
       IF(o1.concept_id = (SELECT DISTINCT(concept_id) FROM concept_reference_term_map_view c WHERE concept_reference_source_name = 'CIEL' AND c.code = '113054'),
       (SELECT value_numeric FROM obs WHERE voided = 0 AND  o1.obs_group_id = obs.obs_group_id AND
       concept_id = (SELECT concept_id FROM concept_reference_term_map_view c WHERE concept_reference_source_name = 'PIH' AND c.code = 'Duration of seizure')),
       NULL)))))) 'duration',
       (SELECT 
            name
        FROM
            concept_name c
        WHERE
            o3.value_coded = c.concept_id
                AND voided = 0
                AND locale = 'en'
                AND concept_name_type = 'SHORT') AS 'alcohol_exposure',
		(SELECT 
            name
        FROM
            concept_name c
        WHERE
            o4.value_coded = c.concept_id
                AND voided = 0
                AND locale = 'en'
                AND concept_name_type = 'SHORT') AS 'drug_exposure',
                DATE(o5.date_created) AS 'date_entered',
		(SELECT CONCAT(family_name," ",given_name) FROM person_name WHERE voided = 0 AND person_id = 
       (SELECT person_id FROM users WHERE user_id = o5.creator)) AS 'user_entered'
	   FROM 
       patient_identifier pi
       JOIN person p ON p.person_id = pi.patient_id AND identifier LIKE '%KZM%' AND pi.voided = 0
	   LEFT JOIN obs o 
	   ON pi.patient_id = o.person_id AND o.voided = 0
       AND o.concept_id = (SELECT concept_id FROM concept_reference_term_map_view c WHERE concept_reference_source_name = 'PIH' AND c.code = 'DIAGNOSIS')
       LEFT JOIN
       (SELECT concept_id, person_id, obs_group_id FROM obs WHERE voided = 0 AND value_coded = 1 AND obs_group_id IN (SELECT obs_id FROM obs WHERE voided = 0 AND concept_id IN (
       SELECT concept_id FROM concept_reference_term_map_view c WHERE concept_reference_source_name = 'PIH-BAH-MH' AND c.code = 'PresentingFeatures'
))) o1 ON o1.person_id = pi.patient_id
       LEFT JOIN
       (SELECT value_coded, person_id FROM obs WHERE voided = 0 AND concept_id = (SELECT concept_id FROM concept_reference_term_map_view c WHERE 
       concept_reference_source_name = 'CIEL' AND c.code = '70468' )) o3 ON o3.person_id = pi.patient_id
       LEFT JOIN
       (SELECT value_coded, person_id FROM obs WHERE voided = 0 AND concept_id = (SELECT concept_id FROM concept_reference_term_map_view c WHERE 
       concept_reference_source_name = 'PIH-BAH-MH' AND c.code = 'Drugs' )) o4 ON o4.person_id = pi.patient_id
       LEFT JOIN
       (SELECT concept_id, person_id, value_coded FROM obs WHERE voided = 0 AND concept_id = 
       (SELECT concept_id FROM concept_reference_term_map_view c WHERE concept_reference_source_name = 'PIH' AND c.code = 'HIV STATUS')) o6 ON o6.person_id = pi.patient_id
       LEFT JOIN
       (SELECT concept_id, person_id, value_coded FROM obs WHERE voided = 0 AND concept_id = 
       (SELECT concept_id FROM concept_reference_term_map_view c WHERE concept_reference_source_name = 'PIH-BAH-MH' AND c.code = 'TBInformation')) o7 ON o7.person_id = pi.patient_id
       JOIN
       (SELECT person_id, date_created, creator FROM obs WHERE voided = 0 AND concept_id = (
       (SELECT concept_id FROM concept_name c WHERE voided = 0 AND locale = 'en' AND concept_name_type = 'SHORT' AND c.name = 'Mental Health Baseline'))) o5 
       ON o5.person_id = pi.patient_id
ORDER BY  pi.identifier;
