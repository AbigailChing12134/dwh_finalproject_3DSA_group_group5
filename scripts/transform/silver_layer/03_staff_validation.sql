-- 1. Create Target Tables
CREATE TABLE IF NOT EXISTS silver.valid_staff_data_raw (LIKE public.staff_data_raw INCLUDING ALL);
CREATE TABLE IF NOT EXISTS silver.invalid_staff_data_raw (LIKE public.staff_data_raw INCLUDING ALL);

-- 2. Clear Old Data
TRUNCATE TABLE silver.valid_staff_data_raw;
TRUNCATE TABLE silver.invalid_staff_data_raw;

-- 3. Insert VALID Data
INSERT INTO silver.valid_staff_data_raw (
	staff_id, 
	name, 
	job_level, 
	street, 
	state, 
	city, 
	country, 
	contact_number, 
	creation_date, 
	source_index
)

SELECT 
    staff_id,
    COALESCE(NULLIF(TRIM(name), ''), 'Unknown Staff'),
    COALESCE(NULLIF(TRIM(job_level), ''), 'Unspecified'),
    street, 
	state, 
	city, 
	country, 
	contact_number, 
	creation_date, 
	source_index
FROM public.staff_data_raw
WHERE
    NOT (staff_id IS NULL OR TRIM(staff_id) = '');

-- 4. Insert INVALID Data
INSERT INTO silver.invalid_staff_data_raw
SELECT * FROM public.staff_data_raw
WHERE
    (staff_id IS NULL OR TRIM(staff_id) = '');

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
    'staff_data_raw',
    'staff_id_not_null',
    'NULL_CHECK',
    'ERROR',
    COUNT(*),
    COUNT(*) FILTER (WHERE staff_id IS NULL OR TRIM(staff_id) = '')
FROM public.staff_data_raw;