-- 1. Create Target Tables
CREATE TABLE IF NOT EXISTS silver.valid_user_credit_card_raw
AS SELECT * FROM public.user_credit_card_raw WITH NO DATA;

CREATE TABLE IF NOT EXISTS silver.invalid_user_credit_card_raw
AS SELECT * FROM public.user_credit_card_raw WITH NO DATA;

-- 2. Clear Old Data
TRUNCATE TABLE silver.valid_user_credit_card_raw;
TRUNCATE TABLE silver.invalid_user_credit_card_raw;

-- 3. Insert VALID Data
INSERT INTO silver.valid_user_credit_card_raw
SELECT * FROM public.user_credit_card_raw
WHERE
    NOT (user_id IS NULL OR TRIM(user_id) = '')
    AND NOT (credit_card_number IS NULL)
    AND NOT (issuing_bank IS NULL OR TRIM(issuing_bank) = '');

-- 4. Insert INVALID Data
INSERT INTO silver.invalid_user_credit_card_raw
SELECT * FROM public.user_credit_card_raw
WHERE
    (user_id IS NULL OR TRIM(user_id) = '')
    OR (credit_card_number IS NULL)
    OR (issuing_bank IS NULL OR TRIM(issuing_bank) = '');

-- 5. DQ Summary Stats (FIXED: Added run_id)
INSERT INTO silver.dq_summary (run_id, table_name, rule_name, issue_type, severity, total_rows, failed_rows)
SELECT
    (SELECT run_id FROM silver.validation_runs ORDER BY started_at DESC LIMIT 1),
    'user_credit_card_raw',
    'user_id_not_null',
    'NULL_CHECK',
    'ERROR',
    COUNT(*),
    COUNT(*) FILTER (WHERE user_id IS NULL OR TRIM(user_id) = '')
FROM public.user_credit_card_raw;

INSERT INTO silver.dq_summary (run_id, table_name, rule_name, issue_type, severity, total_rows, failed_rows)
SELECT
    (SELECT run_id FROM silver.validation_runs ORDER BY started_at DESC LIMIT 1),
    'user_credit_card_raw',
    'credit_card_number_not_null',
    'NULL_CHECK',
    'ERROR',
    COUNT(*),
    COUNT(*) FILTER (WHERE credit_card_number IS NULL)
FROM public.user_credit_card_raw;

INSERT INTO silver.dq_summary (run_id, table_name, rule_name, issue_type, severity, total_rows, failed_rows)
SELECT
    (SELECT run_id FROM silver.validation_runs ORDER BY started_at DESC LIMIT 1),
    'user_credit_card_raw',
    'issuing_bank_not_null',
    'NULL_CHECK',
    'WARNING',
    COUNT(*),
    COUNT(*) FILTER (WHERE issuing_bank IS NULL OR TRIM(issuing_bank) = '')
FROM public.user_credit_card_raw;