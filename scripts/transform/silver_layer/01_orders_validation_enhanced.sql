BEGIN;
-- 0) Define Run ID locally
CREATE TEMP TABLE _this_run AS
SELECT gen_random_uuid() AS run_id;

-- 1) Prepare target tables
CREATE TABLE IF NOT EXISTS silver.valid_orders_raw (LIKE public.orders_raw INCLUDING ALL);
ALTER TABLE silver.valid_orders_raw ADD COLUMN IF NOT EXISTS run_id UUID, ADD COLUMN IF NOT EXISTS validated_at TIMESTAMP;

CREATE TABLE IF NOT EXISTS silver.invalid_orders_raw (LIKE public.orders_raw INCLUDING ALL);
ALTER TABLE silver.invalid_orders_raw 
	ADD COLUMN IF NOT EXISTS run_id UUID, 
	ADD COLUMN IF NOT EXISTS invalidated_at TIMESTAMP, 
	ADD COLUMN IF NOT EXISTS dq_reasons TEXT;

TRUNCATE TABLE silver.valid_orders_raw;
TRUNCATE TABLE silver.invalid_orders_raw;

-- 2) Ingest and dedupe
CREATE TEMP TABLE _flagged AS
WITH raw_prep AS (
  SELECT *,
    trim(lower(order_id)) AS order_id_clean,
    (SELECT run_id FROM _this_run LIMIT 1) AS run_id
  FROM public.orders_raw
),
dedup AS (
  SELECT *, 
    row_number() OVER (PARTITION BY COALESCE(order_id_clean, GEN_RANDOM_UUID()::text) ORDER BY source_index DESC) AS rn
  FROM raw_prep
)
SELECT d.*, 
    (order_id_clean IS NULL OR order_id_clean = '') AS bad_order_id, 
    (user_id IS NULL) AS bad_user_id
FROM dedup d WHERE rn = 1;

-- 3) Insert Valid
INSERT INTO silver.valid_orders_raw (
	order_id, 
	user_id, 
	transaction_date, 
	"estimated arrival", 
	source_index, 
	run_id, 
	validated_at
)

SELECT 
    order_id, 
	user_id, 
	transaction_date, 
    COALESCE(NULLIF(TRIM("estimated arrival"), ''), 'Unknown'),
    source_index, 
	run_id, 
	now()
FROM _flagged WHERE NOT (bad_order_id OR bad_user_id);

-- 4) Insert Invalid
INSERT INTO silver.invalid_orders_raw (
	order_id, 
	user_id, 
	transaction_date, 
	"estimated arrival", 
	source_index, 
	run_id, 
	invalidated_at, 
	dq_reasons
)

SELECT 
	order_id, 
	user_id, 
	transaction_date, 
	"estimated arrival", 
	source_index, 
	run_id, 
	now(), 
	'missing_order_id'
FROM _flagged WHERE (bad_order_id OR bad_user_id);

-- 5) DQ Summary
INSERT INTO silver.dq_summary (
	run_id, 
	table_name, 
	rule_name, 
	issue_type, 
	severity, 
	total_rows, 
	failed_rows, 
	failed_ratio, 
	created_at
)

SELECT 
	(SELECT run_id FROM _this_run LIMIT 1), 
	'orders', 
	'id_check', 
	'NULL_CHECK', 
	'ERROR', 
	COUNT(*), 
	COUNT(*) FILTER (WHERE bad_order_id), 
	0, 
	now()
FROM _flagged;

COMMIT;