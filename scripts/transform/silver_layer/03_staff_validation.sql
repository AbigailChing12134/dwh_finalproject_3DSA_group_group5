-- 1. Create Target Tables
CREATE TABLE IF NOT EXISTS silver.valid_staff_data_raw
AS SELECT * FROM public.staff_data_raw WITH NO DATA;

CREATE TABLE IF NOT EXISTS silver.invalid_staff_data_raw
AS SELECT * FROM public.staff_data_raw WITH NO DATA;

-- 2. Clear Old Data
TRUNCATE TABLE silver.valid_staff_data_raw;
TRUNCATE TABLE silver.invalid_staff_data_raw;

-- 3. Insert VALID Data
INSERT INTO silver.valid_staff_data_raw
SELECT * FROM public.staff_data_raw
WHERE
    NOT (staff_id IS NULL OR TRIM(staff_id) = '')
    AND NOT (name IS NULL OR TRIM(name) = '')
    AND NOT (job_level IS NULL OR TRIM(job_level) = '');

-- 4. Insert INVALID Data
INSERT INTO silver.invalid_staff_data_raw
SELECT * FROM public.staff_data_raw
WHERE
    (staff_id IS NULL OR TRIM(staff_id) = '')
    OR (name IS NULL OR TRIM(name) = '')
    OR (job_level IS NULL OR TRIM(job_level) = '');

-- 5. DQ Summary Stats (FIXED: Added run_id)
INSERT INTO silver.dq_summary (run_id, table_name, rule_name, issue_type, severity, total_rows, failed_rows)
SELECT
    (SELECT run_id FROM silver.validation_runs ORDER BY started_at DESC LIMIT 1),
    'staff_data_raw',
    'staff_id_not_null',
    'NULL_CHECK',
    'ERROR',
    COUNT(*),
    COUNT(*) FILTER (WHERE staff_id IS NULL OR TRIM(staff_id) = '')
FROM public.staff_data_raw;

INSERT INTO silver.dq_summary (run_id, table_name, rule_name, issue_type, severity, total_rows, failed_rows)
SELECT
    (SELECT run_id FROM silver.validation_runs ORDER BY started_at DESC LIMIT 1),
    'staff_data_raw',
    'name_not_null',
    'NULL_CHECK',
    'ERROR',
    COUNT(*),
    COUNT(*) FILTER (WHERE name IS NULL OR TRIM(name) = '')
FROM public.staff_data_raw;

INSERT INTO silver.dq_summary (run_id, table_name, rule_name, issue_type, severity, total_rows, failed_rows)
SELECT
    (SELECT run_id FROM silver.validation_runs ORDER BY started_at DESC LIMIT 1),
    'staff_data_raw',
    'job_level_not_null',
    'NULL_CHECK',
    'ERROR',
    COUNT(*),
    COUNT(*) FILTER (WHERE job_level IS NULL OR TRIM(job_level) = '')
FROM public.staff_data_raw;