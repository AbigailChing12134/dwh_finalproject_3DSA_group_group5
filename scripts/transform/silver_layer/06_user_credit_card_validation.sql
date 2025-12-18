-- 1. Create Target Tables
CREATE TABLE IF NOT EXISTS silver.valid_user_credit_card_raw (LIKE public.user_credit_card_raw INCLUDING ALL);
CREATE TABLE IF NOT EXISTS silver.invalid_user_credit_card_raw (LIKE public.user_credit_card_raw INCLUDING ALL);

-- 2. Clear Old Data
TRUNCATE TABLE silver.valid_user_credit_card_raw;
TRUNCATE TABLE silver.invalid_user_credit_card_raw;

-- 3. Insert VALID Data
INSERT INTO silver.valid_user_credit_card_raw (
	user_id, 
	name, 
	issuing_bank, 
	credit_card_number, 
	source_index
)

SELECT 
    user_id, 
    name, 
    COALESCE(NULLIF(TRIM(issuing_bank), ''), 'Unknown Bank'),
    credit_card_number, 
    source_index
FROM public.user_credit_card_raw
WHERE
    NOT (user_id IS NULL OR TRIM(user_id) = '')
    AND NOT (credit_card_number IS NULL);

-- 4. Insert INVALID Data
INSERT INTO silver.invalid_user_credit_card_raw
SELECT * FROM public.user_credit_card_raw
WHERE
    (user_id IS NULL OR TRIM(user_id) = '')
    OR (credit_card_number IS NULL);

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
    'user_credit_card_raw',
    'required_fields_check',
    'NULL_CHECK',
    'ERROR',
    COUNT(*),
    COUNT(*) FILTER (WHERE user_id IS NULL OR TRIM(user_id) = '' OR credit_card_number IS NULL)
FROM public.user_credit_card_raw;