CREATE SCHEMA IF NOT EXISTS silver;

-------------------------------------------------------------
-- 1. CAMPAIGN DATA 
-------------------------------------------------------------
DROP TABLE IF EXISTS silver.campaign_data;
CREATE TABLE silver.campaign_data (
    campaign_id          TEXT,
    campaign_name        TEXT,
    campaign_description TEXT,
    discount             TEXT,
    source_index         DOUBLE PRECISION
);
INSERT INTO silver.campaign_data (campaign_id, campaign_name, campaign_description, discount, source_index)
SELECT 
    TRIM(campaign_id), 
    TRIM(campaign_name), 
    TRIM(campaign_description), 
    REGEXP_REPLACE(discount, '[^0-9]', '', 'g'),
    CAST(source_index AS DOUBLE PRECISION)
FROM silver.valid_campaign_data_raw;

-------------------------------------------------------------
-- 2. MERCHANT DATA
-------------------------------------------------------------
DROP TABLE IF EXISTS silver.merchant_data;
CREATE TABLE silver.merchant_data (
    merchant_id    TEXT,
    creation_date  TEXT,
    merchant_name  TEXT,
    street         TEXT,
    state          TEXT,
    city           TEXT,
    country        TEXT,
    contact_number TEXT,
    source_index   DOUBLE PRECISION
);
INSERT INTO silver.merchant_data (merchant_id, creation_date, merchant_name, street, state, city, country, contact_number, source_index)
SELECT
    TRIM(merchant_id),
    TRIM(creation_date),
    TRIM(name),
    TRIM(street),
    TRIM(state),
    TRIM(city),
    TRIM(country),
    TRIM(contact_number),
    CAST(source_index AS DOUBLE PRECISION)
FROM silver.valid_merchant_data_raw;

-------------------------------------------------------------
-- 3. STAFF DATA
-------------------------------------------------------------
DROP TABLE IF EXISTS silver.staff_data;
CREATE TABLE silver.staff_data (
    staff_id       TEXT,
    staff_name     TEXT,
    job_level      TEXT,
    street         TEXT,
    state          TEXT,
    city           TEXT,
    country        TEXT,
    contact_number TEXT,
    creation_date  TEXT,
    source_index   DOUBLE PRECISION
);
INSERT INTO silver.staff_data (staff_id, staff_name, job_level, street, state, city, country, contact_number, creation_date, source_index)
SELECT
    TRIM(staff_id),
    TRIM(name),
    TRIM(job_level),
    TRIM(street),
    TRIM(state),
    TRIM(city),
    TRIM(country),
    TRIM(contact_number),
    TRIM(creation_date),
    CAST(source_index AS DOUBLE PRECISION)
FROM silver.valid_staff_data_raw;

-------------------------------------------------------------
-- 4. USER JOB
-------------------------------------------------------------
DROP TABLE IF EXISTS silver.user_job;
CREATE TABLE silver.user_job (
    user_id   TEXT,
    name      TEXT,
    job_title TEXT,
    job_level TEXT,
    source_index DOUBLE PRECISION
);
INSERT INTO silver.user_job (user_id, name, job_title, job_level, source_index)
SELECT
    TRIM(user_id),
    TRIM(name),
    TRIM(job_title),
    TRIM(job_level),
    CAST(source_index AS DOUBLE PRECISION)
FROM silver.valid_user_job_raw;

-------------------------------------------------------------
-- 5. USER DATA
-------------------------------------------------------------
DROP TABLE IF EXISTS silver.user_data;
CREATE TABLE silver.user_data (
    user_id        TEXT,
    creation_date  TEXT,
    name           TEXT,
    street         TEXT,
    state          TEXT,
    city           TEXT,
    country        TEXT,
    birthdate      TEXT,
    gender         TEXT,
    device_address TEXT,
    user_type      TEXT,
    source_index   DOUBLE PRECISION
);
INSERT INTO silver.user_data (user_id, creation_date, name, street, state, city, country, birthdate, gender, device_address, user_type, source_index)
SELECT
    TRIM(user_id),
    TRIM(creation_date),
    TRIM(name),
    TRIM(street),
    TRIM(state),
    TRIM(city),
    TRIM(country),
    TRIM(birthdate),
    TRIM(gender),
    TRIM(device_address),
    TRIM(user_type),
    CAST(source_index AS DOUBLE PRECISION)
FROM silver.valid_user_data_raw;

-------------------------------------------------------------
-- 6. USER CREDIT CARD
-------------------------------------------------------------
DROP TABLE IF EXISTS silver.user_credit_card;
CREATE TABLE silver.user_credit_card (
    user_id            TEXT,
    name               TEXT,
    issuing_bank       TEXT,
    credit_card_number BIGINT,
    source_index       DOUBLE PRECISION
);
INSERT INTO silver.user_credit_card (user_id, name, issuing_bank, credit_card_number, source_index)
SELECT
    TRIM(user_id),
    TRIM(name),
    TRIM(issuing_bank),
    -- Fix: Cast to BIGINT explicitly
    CAST(REGEXP_REPLACE(credit_card_number::text, '[^0-9]', '', 'g') AS BIGINT),
    CAST(source_index AS DOUBLE PRECISION)
FROM silver.valid_user_credit_card_raw;

-------------------------------------------------------------
-- 7. PRODUCT LIST
-------------------------------------------------------------
DROP TABLE IF EXISTS silver.product_list;
CREATE TABLE silver.product_list (
    product_id   TEXT,
    product_name TEXT,
    product_type TEXT,
    price        DOUBLE PRECISION,
    source_index DOUBLE PRECISION
);
INSERT INTO silver.product_list (product_id, product_name, product_type, price, source_index)
SELECT
    TRIM(product_id),
    TRIM(product_name),
    TRIM(product_type),
    -- Fix: Cast to DOUBLE explicitly
    CAST(REGEXP_REPLACE(price::text, '[^0-9.]', '', 'g') AS DOUBLE PRECISION),
    CAST(source_index AS DOUBLE PRECISION)
FROM silver.valid_product_list_raw;

-------------------------------------------------------------
-- 8. ORDER DELAYS
-------------------------------------------------------------
DROP TABLE IF EXISTS silver.order_delays;
CREATE TABLE silver.order_delays (
    order_id   TEXT,
    delay_days INTEGER,
    source_index DOUBLE PRECISION
);
INSERT INTO silver.order_delays (order_id, delay_days, source_index)
SELECT 
    TRIM(order_id),
    COALESCE(NULLIF(REGEXP_REPLACE("delay in days"::text, '[^0-9]', '', 'g'), ''), '0')::int,
    CAST(source_index AS DOUBLE PRECISION)
FROM silver.valid_order_delays_raw;

-------------------------------------------------------------
-- 9. ORDERS
-------------------------------------------------------------
DROP TABLE IF EXISTS silver.orders;
CREATE TABLE silver.orders (
    order_id          TEXT,
    user_id           TEXT,
    estimated_arrival TEXT,
    transaction_date  TEXT,
    source_index      DOUBLE PRECISION
);
INSERT INTO silver.orders (order_id, user_id, estimated_arrival, transaction_date, source_index)
SELECT
    order_id,
    user_id,
    "estimated arrival",
    transaction_date,
    CAST(source_index AS DOUBLE PRECISION)
FROM silver.valid_orders_raw;

-------------------------------------------------------------
-- 10. ORDER_WITH_MERCHANT
-------------------------------------------------------------
DROP TABLE IF EXISTS silver.order_with_merchant;
CREATE TABLE silver.order_with_merchant (
    order_id    TEXT,
    merchant_id TEXT,
    staff_id    TEXT,
    source_index DOUBLE PRECISION
);
INSERT INTO silver.order_with_merchant (order_id, merchant_id, staff_id, source_index)
SELECT
    order_id,
    merchant_id,
    staff_id,
    CAST(source_index AS DOUBLE PRECISION)
FROM silver.valid_order_with_merchant;

-------------------------------------------------------------
-- 11. LINE ITEM PRICES
-------------------------------------------------------------
DROP TABLE IF EXISTS silver.line_item_prices;
CREATE TABLE silver.line_item_prices (
    order_id TEXT,
    price    DOUBLE PRECISION,
    quantity INT,
    source_index DOUBLE PRECISION
);
INSERT INTO silver.line_item_prices (order_id, price, quantity, source_index)
SELECT
    TRIM(order_id),
    -- Fix: Cast Price and Quantity explicitly
    CAST(REGEXP_REPLACE(price::text, '[^0-9.]', '', 'g') AS DOUBLE PRECISION),
    CAST(REGEXP_REPLACE(quantity::text, '[^0-9]', '', 'g') AS INTEGER),
    CAST(source_index AS DOUBLE PRECISION)
FROM silver.valid_line_item_prices;

-------------------------------------------------------------
-- 12. LINE ITEM PRODUCTS
-------------------------------------------------------------
DROP TABLE IF EXISTS silver.line_item_products;
CREATE TABLE silver.line_item_products (
    order_id     TEXT,
    product_id   TEXT,
    product_name TEXT,
    source_index DOUBLE PRECISION
);
INSERT INTO silver.line_item_products (order_id, product_id, product_name, source_index)
SELECT
    TRIM(order_id),
    TRIM(product_id),
    TRIM(product_name),
    CAST(source_index AS DOUBLE PRECISION)
FROM silver.valid_line_item_products;

-------------------------------------------------------------
-- 13. TRANSACTIONAL CAMPAIGN DATA (CRITICAL MISSING PIECE)
-------------------------------------------------------------
DROP TABLE IF EXISTS silver.transactional_campaign_data;
CREATE TABLE silver.transactional_campaign_data (
    order_id    TEXT,
    campaign_id TEXT,
    availed     INT,
    source_index DOUBLE PRECISION
);
-- We pull directly from public raw because there was no validation logic required in previous steps for this simple mapping
INSERT INTO silver.transactional_campaign_data (order_id, campaign_id, availed, source_index)
SELECT
    TRIM(order_id),
    TRIM(campaign_id),
    CAST(REGEXP_REPLACE(availed::text, '[^0-9]', '', 'g') AS INTEGER),
    CAST(source_index AS DOUBLE PRECISION)
FROM public.transactional_campaign_data_raw;