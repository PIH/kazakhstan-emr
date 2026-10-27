SELECT
pi.patient_id, 
identifier AS 'EMR ID',
p.birthdate AS 'dob',
FLOOR(DATEDIFF(CURDATE(), p.birthdate) / 365) AS 'age',
p.gender,
DATE(date_enrolled) AS 'Enrollment start date',
(SELECT 
            name
        FROM
            concept_name c
        WHERE
            o3.value_coded = c.concept_id
                AND voided = 0
                AND voided = 0
                AND locale = 'en'
                AND concept_name_type = 'SHORT') AS 'Type pf referral',
o2.interventions AS 'Mental health intervention',
(SELECT 
            name
        FROM
            concept_name c
        WHERE
            o.value_coded = c.concept_id
                AND voided = 0
                AND voided = 0
                AND locale = 'en'
                AND concept_name_type = 'SHORT') AS 'Outcome',
DATE(o1.value_datetime) 'Date of Outcome'
FROM patient_identifier pi 
JOIN person p ON p.person_id = pi.patient_id AND identifier LIKE 'KZM%' AND p.voided = 0 AND pi.voided = 0
JOIN patient_program pp ON pp.patient_id = pi.patient_id AND pp.voided = 0 AND pp.date_enrolled >= '#startDate#' AND  pp.date_enrolled <= '#endDate#'
LEFT OUTER JOIN obs o ON o.person_id = pi.patient_id AND o.concept_id = (SELECT concept_id FROM concept_reference_term_map_view c WHERE concept_reference_source_name = 'PIH' AND c.code = 'Mental Health Outcome')
LEFT OUTER JOIN obs o1 ON o1.person_id = pi.patient_id AND o1.concept_id = (SELECT concept_id FROM concept_reference_term_map_view c WHERE concept_reference_source_name = 'PIH-BAH-MH' AND c.code = 'Outcome Date')
LEFT OUTER JOIN  (
SELECT person_id,  GROUP_CONCAT(DISTINCT(
SELECT 
            name
        FROM
            concept_name c
        WHERE
            value_coded = c.concept_id
                AND voided = 0
                AND voided = 0
                AND locale = 'en'
                AND concept_name_type = 'SHORT'
) SEPARATOR ' | ') interventions  FROM obs WHERE voided = 0 AND concept_id = (
SELECT concept_id FROM concept_reference_term_map_view c WHERE concept_reference_source_name = 'PIH' AND c.code = 'Mental health intervention')
GROUP BY person_id
ORDER BY person_id ) o2  ON o2.person_id = pi.patient_id 
LEFT OUTER JOIN obs o3 ON o3.person_id = pi.patient_id AND o3.concept_id = (SELECT concept_id FROM concept_reference_term_map_view c WHERE concept_reference_source_name = 'CIEL' AND c.code = '1272')
GROUP BY pi.patient_id
ORDER BY identifier
;
