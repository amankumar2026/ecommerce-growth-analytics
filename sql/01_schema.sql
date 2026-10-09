-- =====================================================================
-- 01. Raw tables
-- Seven Olist tables, loaded as they come from the source files.
-- Nothing is cleaned here; cleaning happens in the views (02_views.sql)
-- so the raw data is always available to check against.
-- =====================================================================

DROP TABLE IF EXISTS order_items, payments, reviews, orders, customers,
                     products, sellers CASCADE;

-- One row per ORDER, not per person. customer_unique_id identifies the
-- real person; the same person gets a new customer_id for every order.
CREATE TABLE customers (
    customer_id         TEXT PRIMARY KEY,
    customer_unique_id  TEXT NOT NULL,
    customer_city       TEXT,
    customer_state      CHAR(2)
);

CREATE TABLE sellers (
    seller_id     TEXT PRIMARY KEY,
    seller_city   TEXT,
    seller_state  CHAR(2)
);

CREATE TABLE products (
    product_id        TEXT PRIMARY KEY,
    product_category  TEXT          -- English name; NULL for 610 products
);

CREATE TABLE orders (
    order_id                       TEXT PRIMARY KEY,
    customer_id                    TEXT NOT NULL REFERENCES customers,
    order_status                   TEXT NOT NULL,
    order_purchase_timestamp       TIMESTAMP NOT NULL,
    order_delivered_customer_date  TIMESTAMP,
    order_estimated_delivery_date  TIMESTAMP
);

-- One row per item in an order.
CREATE TABLE order_items (
    order_id       TEXT NOT NULL REFERENCES orders,
    order_item_id  INT  NOT NULL,
    product_id     TEXT NOT NULL REFERENCES products,
    seller_id      TEXT NOT NULL REFERENCES sellers,
    price          NUMERIC(10, 2) NOT NULL,
    freight_value  NUMERIC(10, 2) NOT NULL,
    PRIMARY KEY (order_id, order_item_id)
);

-- An order can be paid in several parts (for example voucher + card).
CREATE TABLE payments (
    order_id              TEXT NOT NULL REFERENCES orders,
    payment_sequential    INT  NOT NULL,
    payment_type          TEXT NOT NULL,
    payment_installments  INT,
    payment_value         NUMERIC(10, 2) NOT NULL,
    PRIMARY KEY (order_id, payment_sequential)
);

-- review_id is not unique in the source, so the key is the pair.
CREATE TABLE reviews (
    review_id             TEXT NOT NULL,
    order_id              TEXT NOT NULL REFERENCES orders,
    review_score          INT  NOT NULL CHECK (review_score BETWEEN 1 AND 5),
    review_creation_date  TIMESTAMP,
    PRIMARY KEY (review_id, order_id)
);

CREATE INDEX idx_orders_customer ON orders (customer_id);
CREATE INDEX idx_orders_purchase ON orders (order_purchase_timestamp);
CREATE INDEX idx_customers_unique ON customers (customer_unique_id);
CREATE INDEX idx_items_product ON order_items (product_id);
