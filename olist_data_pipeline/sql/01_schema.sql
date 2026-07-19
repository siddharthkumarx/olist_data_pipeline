-- ===========================================================================
-- Olist warehouse schema (MySQL 8)
-- Executed automatically by the pipeline (src/load.py).
-- All statements are idempotent: CREATE TABLE IF NOT EXISTS.
--
-- Design notes
--   * All Olist IDs are 32-char hex strings -> CHAR(32).
--   * Foreign keys enforce referential integrity between core tables.
--   * products.product_category_name has NO foreign key to the
--     translation table: a handful of categories are missing from the
--     translation file at the source, so queries use LEFT JOIN instead.
--   * Indexes cover the join and filter columns the analytics layer uses.
-- ===========================================================================

CREATE TABLE IF NOT EXISTS geolocation (
    geolocation_zip_code_prefix INT          NOT NULL,
    geolocation_lat             DOUBLE       NOT NULL,
    geolocation_lng             DOUBLE       NOT NULL,
    geolocation_city            VARCHAR(64),
    geolocation_state           CHAR(2),
    PRIMARY KEY (geolocation_zip_code_prefix)
);

CREATE TABLE IF NOT EXISTS customers (
    customer_id              CHAR(32)    NOT NULL,
    customer_unique_id       CHAR(32)    NOT NULL,
    customer_zip_code_prefix INT         NOT NULL,
    customer_city            VARCHAR(64),
    customer_state           CHAR(2),
    PRIMARY KEY (customer_id),
    INDEX idx_customers_unique_id (customer_unique_id),
    INDEX idx_customers_state (customer_state)
);

CREATE TABLE IF NOT EXISTS sellers (
    seller_id              CHAR(32)    NOT NULL,
    seller_zip_code_prefix INT         NOT NULL,
    seller_city            VARCHAR(64),
    seller_state           CHAR(2),
    PRIMARY KEY (seller_id),
    INDEX idx_sellers_state (seller_state)
);

CREATE TABLE IF NOT EXISTS product_category_translation (
    product_category_name         VARCHAR(64) NOT NULL,
    product_category_name_english VARCHAR(64),
    PRIMARY KEY (product_category_name)
);

CREATE TABLE IF NOT EXISTS products (
    product_id                 CHAR(32) NOT NULL,
    product_category_name      VARCHAR(64),
    product_name_length        DOUBLE,
    product_description_length DOUBLE,
    product_photos_qty         DOUBLE,
    product_weight_g           DOUBLE,
    product_length_cm          DOUBLE,
    product_height_cm          DOUBLE,
    product_width_cm           DOUBLE,
    PRIMARY KEY (product_id),
    INDEX idx_products_category (product_category_name)
);

CREATE TABLE IF NOT EXISTS orders (
    order_id                      CHAR(32)    NOT NULL,
    customer_id                   CHAR(32)    NOT NULL,
    order_status                  VARCHAR(20) NOT NULL,
    order_purchase_timestamp      DATETIME    NOT NULL,
    order_approved_at             DATETIME,
    order_delivered_carrier_date  DATETIME,
    order_delivered_customer_date DATETIME,
    order_estimated_delivery_date DATETIME,
    PRIMARY KEY (order_id),
    INDEX idx_orders_customer (customer_id),
    INDEX idx_orders_purchase_ts (order_purchase_timestamp),
    INDEX idx_orders_status (order_status),
    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id) REFERENCES customers (customer_id)
);

CREATE TABLE IF NOT EXISTS order_items (
    order_id            CHAR(32)      NOT NULL,
    order_item_id       INT           NOT NULL,
    product_id          CHAR(32)      NOT NULL,
    seller_id           CHAR(32)      NOT NULL,
    shipping_limit_date DATETIME,
    price               DECIMAL(10,2) NOT NULL,
    freight_value       DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (order_id, order_item_id),
    INDEX idx_items_product (product_id),
    INDEX idx_items_seller (seller_id),
    CONSTRAINT fk_items_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id),
    CONSTRAINT fk_items_product
        FOREIGN KEY (product_id) REFERENCES products (product_id),
    CONSTRAINT fk_items_seller
        FOREIGN KEY (seller_id) REFERENCES sellers (seller_id)
);

CREATE TABLE IF NOT EXISTS order_payments (
    order_id             CHAR(32)      NOT NULL,
    payment_sequential   INT           NOT NULL,
    payment_type         VARCHAR(20)   NOT NULL,
    payment_installments INT           NOT NULL,
    payment_value        DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (order_id, payment_sequential),
    INDEX idx_payments_type (payment_type),
    CONSTRAINT fk_payments_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
);

CREATE TABLE IF NOT EXISTS order_reviews (
    review_id               CHAR(32) NOT NULL,
    order_id                CHAR(32) NOT NULL,
    review_score            TINYINT  NOT NULL,
    review_comment_title    TEXT,
    review_comment_message  TEXT,
    review_creation_date    DATETIME,
    review_answer_timestamp DATETIME,
    PRIMARY KEY (review_id, order_id),
    INDEX idx_reviews_order (order_id),
    INDEX idx_reviews_score (review_score),
    CONSTRAINT fk_reviews_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
);
