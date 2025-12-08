-- 1. Create Target Tables
CREATE TABLE IF NOT EXISTS silver.valid_merchant_data_raw
AS SELECT * FROM public.merchant_data_raw WITH NO DATA;

CREATE TABLE IF NOT EXISTS silver.invalid_merchant_data_raw
AS SELECT * FROM public.merchant_data_raw WITH NO DATA;

-- 2. Clear Old Data
TRUNCATE TABLE silver.valid_merchant_data_raw;
TRUNCATE TABLE silver.invalid_merchant_data_raw;

-- 3. Insert VALID Data
INSERT INTO silver.valid_merchant_data_raw
SELECT * FROM public.merchant_data_raw
WHERE
    NOT (merchant_id IS NULL OR TRIM(merchant_id) = '')
    AND NOT (name IS NULL OR TRIM(name) = '')
    AND NOT (country IS NULL OR TRIM(country) = '');

-- 4. Insert INVALID Data
INSERT INTO silver.invalid_merchant_data_raw
SELECT * FROM public.merchant_data_raw
WHERE
    (merchant_id IS NULL OR TRIM(merchant_id) = '')
    OR (name IS NULL OR TRIM(name) = '')
    OR (country IS NULL OR TRIM(country) = '');

-- 5. DQ Summary Stats (FIXED: Added run_id)
INSERT INTO silver.dq_summary (run_id, table_name, rule_name, issue_type, severity, total_rows, failed_rows)
SELECT
    (SELECT run_id FROM silver.validation_runs ORDER BY started_at DESC LIMIT 1),
    'merchant_data_raw',
    'merchant_id_not_null',
    'NULL_CHECK',
    'ERROR',
    COUNT(*),
    COUNT(*) FILTER (WHERE merchant_id IS NULL OR TRIM(merchant_id) = '')
FROM public.merchant_data_raw;

INSERT INTO silver.dq_summary (run_id, table_name, rule_name, issue_type, severity, total_rows, failed_rows)
SELECT
    (SELECT run_id FROM silver.validation_runs ORDER BY started_at DESC LIMIT 1),
    'merchant_data_raw',
    'name_not_null',
    'NULL_CHECK',
    'ERROR',
    COUNT(*),
    COUNT(*) FILTER (WHERE name IS NULL OR TRIM(name) = '')
FROM public.merchant_data_raw;

INSERT INTO silver.dq_summary (run_id, table_name, rule_name, issue_type, severity, total_rows, failed_rows)
SELECT
    (SELECT run_id FROM silver.validation_runs ORDER BY started_at DESC LIMIT 1),
    'merchant_data_raw',
    'country_not_null',
    'NULL_CHECK',
    'ERROR',
    COUNT(*),
    COUNT(*) FILTER (WHERE country IS NULL OR TRIM(country) = '')
FROM public.merchant_data_raw;