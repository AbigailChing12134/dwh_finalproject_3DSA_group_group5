-- 1. Create Target Tables (Structure copies Raw)
CREATE TABLE IF NOT EXISTS silver.valid_user_data_raw
AS SELECT * FROM public.user_data_raw WITH NO DATA;
CREATE TABLE IF NOT EXISTS silver.invalid_user_data_raw
AS SELECT * FROM public.user_data_raw WITH NO DATA;
-- 2. Clear Old Data
TRUNCATE TABLE silver.valid_user_data_raw;
TRUNCATE TABLE silver.invalid_user_data_raw;
-- 3. Insert VALID Data
INSERT INTO silver.valid_user_data_raw
SELECT * FROM public.user_data_raw
WHERE
    NOT (user_id IS NULL OR TRIM(user_id) = '')
    AND NOT (birthdate IS NULL OR TRIM(birthdate) = '')
    AND NOT (gender IS NULL OR TRIM(gender) = '');
-- 4. Insert INVALID Data
INSERT INTO silver.invalid_user_data_raw
SELECT * FROM public.user_data_raw
WHERE
    (user_id IS NULL OR TRIM(user_id) = '')
    OR (birthdate IS NULL OR TRIM(birthdate) = '')
    OR (gender IS NULL OR TRIM(gender) = '');

-- 5. DQ Summary Stats (FIXED: Added explicit run_id retrieval)
INSERT INTO silver.dq_summary (run_id, table_name, rule_name, issue_type, severity, total_rows, failed_rows)
SELECT
    (SELECT run_id FROM silver.validation_runs ORDER BY started_at DESC LIMIT 1), -- Get the most recent run_id
    'user_data_raw',
    'user_id_not_null',
    'NULL_CHECK',
    'ERROR',
    COUNT(*),
    COUNT(*) FILTER (WHERE user_id IS NULL OR TRIM(user_id) = '')
FROM public.user_data_raw;

INSERT INTO silver.dq_summary (run_id, table_name, rule_name, issue_type, severity, total_rows, failed_rows)
SELECT
    (SELECT run_id FROM silver.validation_runs ORDER BY started_at DESC LIMIT 1), -- Get the most recent run_id
    'user_data_raw',
    'birthdate_not_null',
    'NULL_CHECK',
    'WARNING',
    COUNT(*),
    COUNT(*) FILTER (WHERE birthdate IS NULL OR TRIM(birthdate) = '')
FROM public.user_data_raw;

INSERT INTO silver.dq_summary (run_id, table_name, rule_name, issue_type, severity, total_rows, failed_rows)
SELECT
    (SELECT run_id FROM silver.validation_runs ORDER BY started_at DESC LIMIT 1), -- Get the most recent run_id
    'user_data_raw',
    'gender_not_null',
    'NULL_CHECK',
    'WARNING',
    COUNT(*),
    COUNT(*) FILTER (WHERE gender IS NULL OR TRIM(gender) = '')
FROM public.user_data_raw;