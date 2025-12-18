-- 1. Create Target Tables
CREATE TABLE IF NOT EXISTS silver.valid_product_list_raw (LIKE public.product_list_raw INCLUDING ALL);
CREATE TABLE IF NOT EXISTS silver.invalid_product_list_raw (LIKE public.product_list_raw INCLUDING ALL);

-- 2. Clear Old Data
TRUNCATE TABLE silver.valid_product_list_raw;
TRUNCATE TABLE silver.invalid_product_list_raw;

-- 3. Insert VALID Data
INSERT INTO silver.valid_product_list_raw (
	product_id, 
	product_name, 
	product_type, 
	price, 
	source_index
)

SELECT 
    product_id,
    COALESCE(NULLIF(TRIM(product_name), ''), 'Unknown Product'),
    COALESCE(NULLIF(TRIM(product_type), ''), 'Uncategorized'),
    price,
    source_index
FROM public.product_list_raw
WHERE
    NOT (product_id IS NULL OR TRIM(product_id) = '')
    AND NOT (price IS NULL); -- Critical check

-- 4. Insert INVALID Data
INSERT INTO silver.invalid_product_list_raw
SELECT * FROM public.product_list_raw
WHERE
    (product_id IS NULL OR TRIM(product_id) = '')
    OR (price IS NULL);

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
    'product_list_raw',
    'price_not_null',
    'NULL_CHECK',
    'ERROR',
    COUNT(*),
    COUNT(*) FILTER (WHERE price IS NULL)
FROM public.product_list_raw;