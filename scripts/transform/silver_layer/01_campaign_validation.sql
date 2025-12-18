-- 1. Create Target Tables
CREATE TABLE IF NOT EXISTS silver.valid_campaign_data_raw (LIKE public.campaign_data_raw INCLUDING ALL);
CREATE TABLE IF NOT EXISTS silver.invalid_campaign_data_raw (LIKE public.campaign_data_raw INCLUDING ALL);

-- 2. Clear Old Data
TRUNCATE TABLE silver.valid_campaign_data_raw;
TRUNCATE TABLE silver.invalid_campaign_data_raw;

-- 3. Insert VALID Data
INSERT INTO silver.valid_campaign_data_raw (
	campaign_id, 
	campaign_name, 
	campaign_description, 
	discount, 
	source_index
)

SELECT 
    campaign_id,
    COALESCE(NULLIF(TRIM(campaign_name), ''), 'Unknown Campaign'),
    campaign_description,
    COALESCE(NULLIF(TRIM(discount), ''), '0'),
    source_index
FROM public.campaign_data_raw
WHERE
    NOT (campaign_id IS NULL OR TRIM(campaign_id) = '');

-- 4. Insert INVALID Data
INSERT INTO silver.invalid_campaign_data_raw
SELECT * FROM public.campaign_data_raw
WHERE
    (campaign_id IS NULL OR TRIM(campaign_id) = '');

-- 5. DQ Summary Stats
INSERT INTO silver.dq_summary (
	run_id, 
	table_name, 
	rule_name, 
	issue_type, 
	severity, 
	total_rows, 
	failed_rows
)

SELECT
    (SELECT run_id FROM silver.validation_runs ORDER BY started_at DESC LIMIT 1),
    'campaign_data_raw',
    'campaign_id_not_null',
    'NULL_CHECK',
    'ERROR',
    COUNT(*),
    COUNT(*) FILTER (WHERE campaign_id IS NULL OR TRIM(campaign_id) = '')
FROM public.campaign_data_raw;