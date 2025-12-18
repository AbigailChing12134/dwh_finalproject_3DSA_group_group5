BEGIN;
CREATE SCHEMA IF NOT EXISTS silver;

CREATE TABLE IF NOT EXISTS silver.validation_runs (
  run_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  started_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  description TEXT
);

-- Ensure run_id exists
INSERT INTO silver.validation_runs (description) VALUES ('Run Initializer');

CREATE TABLE IF NOT EXISTS silver.dq_summary (
  run_id UUID NOT NULL,
  table_name TEXT NOT NULL,
  rule_name TEXT NOT NULL,
  issue_type TEXT,
  severity TEXT,
  total_rows BIGINT,
  failed_rows BIGINT,
  failed_ratio DOUBLE PRECISION,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

CREATE TABLE IF NOT EXISTS silver.invalid_samples (
  run_id UUID NOT NULL,
  table_name TEXT NOT NULL,
  rule_name TEXT NOT NULL,
  example_row JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
COMMIT;