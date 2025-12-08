-- 1. Create Target Tables
CREATE TABLE IF NOT EXISTS silver.valid_line_item_products
AS SELECT * FROM public.line_item_products_raw WITH NO DATA;

CREATE TABLE IF NOT EXISTS silver.invalid_line_item_products
AS SELECT * FROM public.line_item_products_raw WITH NO DATA;

-- 2. Clear Old Data
TRUNCATE TABLE silver.valid_line_item_products;
TRUNCATE TABLE silver.invalid_line_item_products;

-- 3. Insert VALID Data
INSERT INTO silver.valid_line_item_products
SELECT * FROM public.line_item_products_raw
WHERE
    NOT (order_id IS NULL OR TRIM(order_id) = '')
    AND NOT (product_id IS NULL OR TRIM(product_id) = '')
    AND NOT (product_name IS NULL OR TRIM(product_name) = '');

-- 4. Insert INVALID Data
INSERT INTO silver.invalid_line_item_products
SELECT * FROM public.line_item_products_raw
WHERE
    (order_id IS NULL OR TRIM(order_id) = '')
    OR (product_id IS NULL OR TRIM(product_id) = '')
    OR (product_name IS NULL OR TRIM(product_name) = '');

-- 5. DQ Summary Stats (FIXED: Added run_id)
INSERT INTO silver.dq_summary (run_id, table_name, rule_name, issue_type, severity, total_rows, failed_rows)
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
           OR product_name IS NULL OR TRIM(product_name) = ''
    )
FROM public.line_item_products_raw;