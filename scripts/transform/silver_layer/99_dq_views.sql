CREATE OR REPLACE VIEW silver.v_dq_summary AS
SELECT
    table_name,
    rule_name,
    issue_type,
    severity,
    total_rows,
    failed_rows,
    CASE
        WHEN total_rows = 0 THEN 0
        ELSE failed_rows::numeric / total_rows::numeric
    END AS failed_ratio,
    created_at
FROM silver.dq_summary;

CREATE OR REPLACE VIEW silver.v_dq_invalid_counts AS
SELECT 'campaign_data_raw'::text AS table_name, COUNT(*) AS invalid_rows
FROM silver.invalid_campaign_data_raw
UNION ALL
SELECT 'merchant_data_raw', COUNT(*) FROM silver.invalid_merchant_data_raw
UNION ALL
SELECT 'staff_data_raw', COUNT(*) FROM silver.invalid_staff_data_raw
UNION ALL
SELECT 'user_data_raw', COUNT(*) FROM silver.invalid_user_data_raw
UNION ALL
SELECT 'user_job_raw', COUNT(*) FROM silver.invalid_user_job_raw
UNION ALL
SELECT 'user_credit_card_raw', COUNT(*) FROM silver.invalid_user_credit_card_raw
UNION ALL
SELECT 'product_list_raw', COUNT(*) FROM silver.invalid_product_list_raw
UNION ALL
SELECT 'order_delays_raw', COUNT(*) FROM silver.invalid_order_delays_raw
UNION ALL
-- Consolidated Orders
SELECT 'orders_raw', COUNT(*) FROM silver.invalid_orders_raw
UNION ALL
-- Consolidated Order with Merchant
SELECT 'order_with_merchant_raw', COUNT(*) FROM silver.invalid_order_with_merchant
UNION ALL
-- Consolidated Line Item Prices
SELECT 'line_item_prices_raw', COUNT(*) FROM silver.invalid_line_item_prices
UNION ALL
-- Consolidated Line Item Products
SELECT 'line_item_products_raw', COUNT(*) FROM silver.invalid_line_item_products;