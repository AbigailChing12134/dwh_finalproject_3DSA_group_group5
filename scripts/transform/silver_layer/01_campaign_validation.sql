-- 1. Create Target Tables (Structure copies Raw)
CREATE TABLE IF NOT EXISTS silver.valid_campaign_data_raw
AS SELECT * FROM public.campaign_data_raw WITH NO DATA;

CREATE TABLE IF NOT EXISTS silver.invalid_campaign_data_raw
AS SELECT * FROM public.campaign_data_raw WITH NO DATA;

-- 2. Clear Old Data
TRUNCATE TABLE silver.valid_campaign_data_raw;
TRUNCATE TABLE silver.invalid_campaign_data_raw;

-- 3. Insert VALID Data
INSERT INTO silver.valid_campaign_data_raw
SELECT * FROM public.campaign_data_raw
WHERE
    NOT (campaign_id IS NULL OR TRIM(campaign_id) = '')
    AND NOT (campaign_name IS NULL OR TRIM(campaign_name) = '')
    AND NOT (
            discount IS NULL
            OR TRIM(discount) = ''
            OR REGEXP_REPLACE(discount, '[^0-9]', '', 'g') = ''
        );

-- 4. Insert INVALID Data
INSERT INTO silver.invalid_campaign_data_raw
SELECT * FROM public.campaign_data_raw
WHERE
    (campaign_id IS NULL OR TRIM(campaign_id) = '')
    OR (campaign_name IS NULL OR TRIM(campaign_name) = '')
    OR (
            discount IS NULL
            OR TRIM(discount) = ''
            OR REGEXP_REPLACE(discount, '[^0-9]', '', 'g') = ''
        );

-- 5. DQ Summary Stats (FIXED: Added run_id)
INSERT INTO silver.dq_summary (run_id, table_name, rule_name, issue_type, severity, total_rows, failed_rows)
SELECT
    (SELECT run_id FROM silver.validation_runs ORDER BY started_at DESC LIMIT 1),
    'campaign_data_raw',
    'campaign_id_not_null',
    'NULL_CHECK',
    'ERROR',
    COUNT(*),
    COUNT(*) FILTER (WHERE campaign_id IS NULL OR TRIM(campaign_id) = '')
FROM public.campaign_data_raw;

INSERT INTO silver.dq_summary (run_id, table_name, rule_name, issue_type, severity, total_rows, failed_rows)
SELECT
    (SELECT run_id FROM silver.validation_runs ORDER BY started_at DESC LIMIT 1),
    'campaign_data_raw',
    'campaign_name_not_null',
    'NULL_CHECK',
    'ERROR',
    COUNT(*),
    COUNT(*) FILTER (WHERE campaign_name IS NULL OR TRIM(campaign_name) = '')
FROM public.campaign_data_raw;

INSERT INTO silver.dq_summary (run_id, table_name, rule_name, issue_type, severity, total_rows, failed_rows)
SELECT
    (SELECT run_id FROM silver.validation_runs ORDER BY started_at DESC LIMIT 1),
    'campaign_data_raw',
    'discount_has_digits',
    'FORMAT_CHECK',
    'ERROR',
    COUNT(*),
    COUNT(*) FILTER (
        WHERE discount IS NULL
           OR TRIM(discount) = ''
           OR REGEXP_REPLACE(discount, '[^0-9]', '', 'g') = ''
    )
FROM public.campaign_data_raw;