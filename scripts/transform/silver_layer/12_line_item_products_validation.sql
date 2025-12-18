-- 1. Create Target Tables
CREATE TABLE IF NOT EXISTS silver.valid_line_item_products (LIKE public.line_item_products_raw INCLUDING ALL);
CREATE TABLE IF NOT EXISTS silver.invalid_line_item_products (LIKE public.line_item_products_raw INCLUDING ALL);

-- 2. Clear Old Data
TRUNCATE TABLE silver.valid_line_item_products;
TRUNCATE TABLE silver.invalid_line_item_products;

-- 3. Insert VALID Data
INSERT INTO silver.valid_line_item_products (
	order_id, 
	product_id, 
	product_name, 
	source_index
)

SELECT 
    order_id, 
    product_id, 
    COALESCE(NULLIF(TRIM(product_name), ''), 'Unknown Product'),
    source_index
FROM public.line_item_products_raw
WHERE
    NOT (order_id IS NULL OR TRIM(order_id) = '')
    AND NOT (product_id IS NULL OR TRIM(product_id) = '');

-- 4. Insert INVALID Data
INSERT INTO silver.invalid_line_item_products
SELECT * FROM public.line_item_products_raw
WHERE
    (order_id IS NULL OR TRIM(order_id) = '')
    OR (product_id IS NULL OR TRIM(product_id) = '');

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
    'line_item_products_raw',
    'required_fields_not_null',
    'NULL_CHECK',
    'ERROR',
    COUNT(*),
    COUNT(*) FILTER (
        WHERE order_id IS NULL OR TRIM(order_id) = ''
           OR product_id IS NULL OR TRIM(product_id) = ''
    )
FROM public.line_item_products_raw;