BEGIN;
-- 0) Define Run ID locally
CREATE TEMP TABLE _this_run AS
SELECT gen_random_uuid() AS run_id;

-- 1) Prepare target tables
CREATE TABLE IF NOT EXISTS silver.valid_orders_raw (
    run_id UUID, order_id TEXT, user_id TEXT, transaction_date TEXT, estimated_arrival TEXT, source_index DOUBLE PRECISION, source_ts_parsed TIMESTAMP, validated_at TIMESTAMP
);
CREATE TABLE IF NOT EXISTS silver.invalid_orders_raw (
    run_id UUID, order_id TEXT, user_id TEXT, transaction_date TEXT, estimated_arrival TEXT, source_index DOUBLE PRECISION, source_ts_parsed TIMESTAMP, invalidated_at TIMESTAMP, dq_reasons TEXT
);
TRUNCATE TABLE silver.valid_orders_raw;
TRUNCATE TABLE silver.invalid_orders_raw;

-- 2) Ingest and dedupe (using Temp Table)
CREATE TEMP TABLE _flagged AS
WITH raw_prep AS (
  SELECT
    o.order_id, o.user_id, o.transaction_date, o."estimated arrival" AS estimated_arrival,
    CAST(o.source_index AS DOUBLE PRECISION) AS source_index,
    (SELECT run_id FROM _this_run LIMIT 1) AS run_id,
    trim(lower(o.order_id)) AS order_id_clean,
    now() AS source_ts_parsed
  FROM public.orders_raw o
),
dedup AS (
  SELECT *, row_number() OVER (PARTITION BY order_id_clean ORDER BY source_ts_parsed DESC) AS rn
  FROM raw_prep
)
SELECT d.*, (order_id_clean IS NULL OR order_id_clean = '') AS bad_order_id, (user_id IS NULL) AS bad_user_id, (transaction_date IS NULL) AS bad_transaction_date
FROM dedup d WHERE rn = 1;

-- 3) Insert Valid
INSERT INTO silver.valid_orders_raw (run_id, order_id, user_id, transaction_date, estimated_arrival, source_index, source_ts_parsed, validated_at)
SELECT run_id, order_id_clean, user_id, transaction_date, estimated_arrival, source_index, source_ts_parsed, now()
FROM _flagged WHERE NOT (bad_order_id OR bad_user_id OR bad_transaction_date);

-- 4) Insert Invalid
INSERT INTO silver.invalid_orders_raw (run_id, order_id, user_id, transaction_date, estimated_arrival, source_index, source_ts_parsed, invalidated_at, dq_reasons)
SELECT run_id, order_id, user_id, transaction_date, estimated_arrival, source_index, source_ts_parsed, now(),
  concat_ws('; ', CASE WHEN bad_order_id THEN 'missing_order_id' END, CASE WHEN bad_user_id THEN 'missing_user_id' END, CASE WHEN bad_transaction_date THEN 'missing_transaction_date' END)
FROM _flagged WHERE (bad_order_id OR bad_user_id OR bad_transaction_date);

-- 5) Ref Integrity
CREATE TEMP TABLE _missing_refs AS
SELECT v.* FROM silver.valid_orders_raw v
LEFT JOIN silver.valid_user_data_raw u ON v.user_id = u.user_id
WHERE u.user_id IS NULL AND v.user_id IS NOT NULL;

INSERT INTO silver.invalid_orders_raw (run_id, order_id, user_id, transaction_date, estimated_arrival, source_index, source_ts_parsed, invalidated_at, dq_reasons)
SELECT run_id, order_id, user_id, transaction_date, estimated_arrival, source_index, source_ts_parsed, now(), 'missing_user_fk'
FROM _missing_refs;

DELETE FROM silver.valid_orders_raw v USING _missing_refs m WHERE v.order_id = m.order_id;

-- 6) DQ Summary
INSERT INTO silver.dq_summary (run_id, table_name, rule_name, issue_type, severity, total_rows, failed_rows, failed_ratio, created_at)
SELECT (SELECT run_id FROM _this_run LIMIT 1), 'orders', 'missing_order_id', 'NULL_CHECK', 'ERROR', (SELECT count(*) FROM public.orders_raw), (SELECT count(*) FROM silver.invalid_orders_raw WHERE dq_reasons ILIKE '%missing_order_id%'), 0, now();

COMMIT;