-- 1. Create Target Tables
CREATE TABLE IF NOT EXISTS silver.valid_order_with_merchant
AS SELECT * FROM public.order_with_merchant_raw WITH NO DATA;

CREATE TABLE IF NOT EXISTS silver.invalid_order_with_merchant
AS SELECT * FROM public.order_with_merchant_raw WITH NO DATA;

-- 2. Clear Old Data
TRUNCATE TABLE silver.valid_order_with_merchant;
TRUNCATE TABLE silver.invalid_order_with_merchant;

-- 3. Insert VALID Data
INSERT INTO silver.valid_order_with_merchant
SELECT * FROM public.order_with_merchant_raw
WHERE
    NOT (order_id IS NULL OR TRIM(order_id) = '')
    AND NOT (merchant_id IS NULL OR TRIM(merchant_id) = '')
    AND NOT (staff_id IS NULL OR TRIM(staff_id) = '');

-- 4. Insert INVALID Data
INSERT INTO silver.invalid_order_with_merchant
SELECT * FROM public.order_with_merchant_raw
WHERE
    (order_id IS NULL OR TRIM(order_id) = '')
    OR (merchant_id IS NULL OR TRIM(merchant_id) = '')
    OR (staff_id IS NULL OR TRIM(staff_id) = '');

-- 5. DQ Summary Stats (FIXED: Added run_id)
INSERT INTO silver.dq_summary (run_id, table_name, rule_name, issue_type, severity, total_rows, failed_rows)
SELECT
    (SELECT run_id FROM silver.validation_runs ORDER BY started_at DESC LIMIT 1),
    'order_with_merchant_raw',
    'required_ids_not_null',
    'NULL_CHECK',
    'ERROR',
    COUNT(*),
    COUNT(*) FILTER (
        WHERE order_id IS NULL OR TRIM(order_id) = ''
           OR merchant_id IS NULL OR TRIM(merchant_id) = ''
           OR staff_id IS NULL OR TRIM(staff_id) = ''
    )
FROM public.order_with_merchant_raw;