-- 1. Create Target Tables
CREATE TABLE IF NOT EXISTS silver.valid_merchant_data_raw (LIKE public.merchant_data_raw INCLUDING ALL);
CREATE TABLE IF NOT EXISTS silver.invalid_merchant_data_raw (LIKE public.merchant_data_raw INCLUDING ALL);

-- 2. Clear Old Data
TRUNCATE TABLE silver.valid_merchant_data_raw;
TRUNCATE TABLE silver.invalid_merchant_data_raw;

-- 3. Insert VALID Data
INSERT INTO silver.valid_merchant_data_raw (
	merchant_id, 
	name, 
	country, 
	creation_date, 
	street, 
	state, 
	city, 
	contact_number, 
	source_index
)

SELECT 
    merchant_id, 
    COALESCE(NULLIF(TRIM(name), ''), 'Unknown Merchant'),
    COALESCE(NULLIF(TRIM(country), ''), 'Unknown Country'),
    creation_date, 
	street, 
	state, 
	city, 
	contact_number, 
	source_index
FROM public.merchant_data_raw
WHERE
    NOT (merchant_id IS NULL OR TRIM(merchant_id) = '');

-- 4. Insert INVALID Data
INSERT INTO silver.invalid_merchant_data_raw
SELECT * FROM public.merchant_data_raw
WHERE
    (merchant_id IS NULL OR TRIM(merchant_id) = '');

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
    'merchant_data_raw',
    'merchant_id_not_null',
    'NULL_CHECK',
    'ERROR',
    COUNT(*),
    COUNT(*) FILTER (WHERE merchant_id IS NULL OR TRIM(merchant_id) = '')
FROM public.merchant_data_raw;