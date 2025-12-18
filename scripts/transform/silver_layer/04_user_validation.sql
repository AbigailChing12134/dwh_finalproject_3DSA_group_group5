-- 1. Create Target Tables
CREATE TABLE IF NOT EXISTS silver.valid_user_data_raw (LIKE public.user_data_raw INCLUDING ALL);
CREATE TABLE IF NOT EXISTS silver.invalid_user_data_raw (LIKE public.user_data_raw INCLUDING ALL);

-- 2. Clear Old Data
TRUNCATE TABLE silver.valid_user_data_raw;
TRUNCATE TABLE silver.invalid_user_data_raw;

-- 3. Insert VALID Data
INSERT INTO silver.valid_user_data_raw (
	user_id, 
	birthdate, 
	gender, 
	creation_date, 
	name, 
	street, 
	state, 
	city, 
	country, 
	device_address, 
	user_type, 
	source_index
)

SELECT 
    user_id, 
    COALESCE(NULLIF(TRIM(birthdate), ''), '1900-01-01'),
    COALESCE(NULLIF(TRIM(gender), ''), 'Unknown'),
    creation_date, 
	name, 
	street, 
	state, 
	city, 
	country, 
	device_address, 
	user_type, 
	source_index
FROM public.user_data_raw
WHERE
    NOT (user_id IS NULL OR TRIM(user_id) = '');

-- 4. Insert INVALID Data
INSERT INTO silver.invalid_user_data_raw
SELECT * FROM public.user_data_raw
WHERE
    (user_id IS NULL OR TRIM(user_id) = '');

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
    'user_data_raw',
    'user_id_not_null',
    'NULL_CHECK',
    'ERROR',
    COUNT(*),
    COUNT(*) FILTER (WHERE user_id IS NULL OR TRIM(user_id) = '')
FROM public.user_data_raw;