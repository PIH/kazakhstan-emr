-- Local test user for e2e/ (e2e-test / E2eTest123), as a server DB's admin passwords aren't known. Never
-- run against production.
SET @exists = (SELECT COUNT(*) FROM users WHERE username = 'e2e-test');
INSERT INTO person (gender, creator, date_created, voided, uuid, dead)
  SELECT 'U', 1, NOW(), 0, UUID(), 0 FROM DUAL WHERE @exists = 0;
SET @p = IF(@exists = 0, LAST_INSERT_ID(), NULL);
INSERT INTO person_name (preferred, person_id, given_name, family_name, creator, date_created, voided, uuid)
  SELECT 1, @p, 'E2E', 'Test', 1, NOW(), 0, UUID() FROM DUAL WHERE @p IS NOT NULL;
SET @salt = SHA2(UUID(), 512);
INSERT INTO users (system_id, username, password, salt, creator, date_created, person_id, retired, uuid)
  SELECT 'e2e-test', 'e2e-test', SHA2(CONCAT('E2eTest123', @salt), 512), @salt, 1, NOW(), @p, 0, UUID()
  FROM DUAL WHERE @p IS NOT NULL;
SET @u = IF(@p IS NOT NULL, LAST_INSERT_ID(), NULL);
INSERT INTO user_role (user_id, role)
  SELECT @u, r FROM (SELECT 'System Developer' r UNION SELECT 'Provider' UNION SELECT 'SuperAdmin') roles
  WHERE @u IS NOT NULL;
INSERT INTO provider (person_id, identifier, creator, date_created, retired, uuid)
  SELECT @p, 'E2E-TEST', 1, NOW(), 0, UUID() FROM DUAL WHERE @p IS NOT NULL;
INSERT INTO user_property (user_id, property, property_value)
  SELECT @u, 'defaultLocale', 'en' FROM DUAL WHERE @u IS NOT NULL;
