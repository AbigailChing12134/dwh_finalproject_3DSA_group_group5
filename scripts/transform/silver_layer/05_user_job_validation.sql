-- 1. Create Target Tables
CREATE TABLE IF NOT EXISTS silver.valid_user_job_raw
AS SELECT * FROM public.user_job_raw WITH NO DATA;

CREATE TABLE IF NOT EXISTS silver.invalid_user_job_raw
AS SELECT * FROM public.user_job_raw WITH NO DATA;

-- 2. Clear Old Data
TRUNCATE TABLE silver.valid_user_job_raw;
TRUNCATE TABLE silver.invalid_user_job_raw;

-- 3. Insert VALID Data
INSERT INTO silver.valid_user_job_raw
SELECT * FROM public.user_job_raw
WHERE
    NOT (user_id IS NULL OR TRIM(user_id) = '')
    AND NOT (job_title IS NULL OR TRIM(job_title) = '');

-- 4. Insert INVALID Data
INSERT INTO silver.invalid_user_job_raw
SELECT * FROM public.user_job_raw
WHERE
    (user_id IS NULL OR TRIM(user_id) = '')
    OR (job_title IS NULL OR TRIM(job_title) = '');

-- 5. DQ Summary Stats (FIXED: Added run_id)
INSERT INTO silver.dq_summary (run_id, table_name, rule_name, issue_type, severity, total_rows, failed_rows)
SELECT
    (SELECT run_id FROM silver.validation_runs ORDER BY started_at DESC LIMIT 1),
    'user_job_raw',
    'user_id_not_null',
    'NULL_CHECK',
    'ERROR',
    COUNT(*),
    COUNT(*) FILTER (WHERE user_id IS NULL OR TRIM(user_id) = '')
FROM public.user_job_raw;

INSERT INTO silver.dq_summary (run_id, table_name, rule_name, issue_type, severity, total_rows, failed_rows)
SELECT
    (SELECT run_id FROM silver.validation_runs ORDER BY started_at DESC LIMIT 1),
    'user_job_raw',
    'job_title_not_null',
    'NULL_CHECK',
    'WARNING',
    COUNT(*),
    COUNT(*) FILTER (WHERE job_title IS NULL OR TRIM(job_title) = '')
FROM public.user_job_raw;