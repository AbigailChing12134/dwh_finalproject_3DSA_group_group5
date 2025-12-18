-- 1. Create Target Tables
CREATE TABLE IF NOT EXISTS silver.valid_order_delays_raw (LIKE public.order_delays_raw INCLUDING ALL);
CREATE TABLE IF NOT EXISTS silver.invalid_order_delays_raw (LIKE public.order_delays_raw INCLUDING ALL);

-- 2. Clear Old Data
TRUNCATE TABLE silver.valid_order_delays_raw;
TRUNCATE TABLE silver.invalid_order_delays_raw;

-- 3. Insert VALID Data
INSERT INTO silver.valid_order_delays_raw (
	order_id, 
	"delay in days", 
	source_index
)

SELECT 
    order_id,
    COALESCE(NULLIF(REGEXP_REPLACE("delay in days"::text, '[^0-9]', '', 'g'), ''), '0')::integer,
    source_index
FROM public.order_delays_raw
WHERE
    NOT (order_id IS NULL OR TRIM(order_id) = '');

-- 4. Insert INVALID Data
INSERT INTO silver.invalid_order_delays_raw
SELECT * FROM public.order_delays_raw
WHERE
    (order_id IS NULL OR TRIM(order_id) = '');

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
    'order_delays_raw',
    'order_id_not_null',
    'NULL_CHECK',
    'ERROR',
    COUNT(*),
    COUNT(*) FILTER (WHERE order_id IS NULL OR TRIM(order_id) = '')
FROM public.order_delays_raw;