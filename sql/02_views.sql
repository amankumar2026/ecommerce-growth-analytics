-- =====================================================================
-- 02. Clean analysis views
-- All cleaning decisions live here, in one place. Every analysis query
-- and the Power BI dashboard read from these views, never from the raw
-- tables, so every number in the project uses the same definitions.
--
-- They are MATERIALIZED views: PostgreSQL runs the query once and stores
-- the result like a table, so the analysis queries are fast. If the raw
-- data changes, refresh them with REFRESH MATERIALIZED VIEW <name>.
--
-- Decisions:
--   1. Only DELIVERED orders count as sales (97% of all orders).
--      Cancelled or unavailable orders never became revenue.
--   2. Analysis window: January 2017 to August 2018. Earlier and later
--      months hold only a handful of orders (incomplete data).
--   3. Revenue = sum of item prices. Freight is kept separately because
--      it is passed on to the carrier, not earned by the business.
--   4. A customer is identified by customer_unique_id, not customer_id
--      (customer_id changes with every order).
--   5. If an order has several reviews, the most recent one is used.
-- =====================================================================

DROP MATERIALIZED VIEW IF EXISTS v_customer_rfm, v_customers, v_order_items, v_orders CASCADE;
DROP VIEW IF EXISTS dim_date;

-- ---------------------------------------------------------------------
-- v_orders: one row per delivered order
-- ---------------------------------------------------------------------
CREATE MATERIALIZED VIEW v_orders AS
WITH item_totals AS (
    SELECT order_id,
           SUM(price)         AS revenue,
           SUM(freight_value) AS freight,
           COUNT(*)           AS items
    FROM order_items
    GROUP BY order_id
),
latest_review AS (
    SELECT DISTINCT ON (order_id) order_id, review_score
    FROM reviews
    ORDER BY order_id, review_creation_date DESC
)
SELECT
    o.order_id,
    c.customer_unique_id,
    c.customer_state,
    o.order_purchase_timestamp::date                        AS order_date,
    DATE_TRUNC('month', o.order_purchase_timestamp)::date   AS order_month,
    t.revenue,
    t.freight,
    t.items,
    -- Days from purchase to delivery, and whether it missed the promised date
    o.order_delivered_customer_date::date - o.order_purchase_timestamp::date AS delivery_days,
    o.order_delivered_customer_date::date > o.order_estimated_delivery_date::date AS delivered_late,
    r.review_score,
    -- 1 for a customer's first order, 2 for their second, and so on
    ROW_NUMBER() OVER (PARTITION BY c.customer_unique_id
                       ORDER BY o.order_purchase_timestamp)  AS customer_order_number
FROM orders o
JOIN customers c        ON c.customer_id = o.customer_id
JOIN item_totals t      ON t.order_id = o.order_id
LEFT JOIN latest_review r ON r.order_id = o.order_id
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= DATE '2017-01-01'
  AND o.order_purchase_timestamp <  DATE '2018-09-01';

-- ---------------------------------------------------------------------
-- v_order_items: one row per item sold, with its product category
-- ---------------------------------------------------------------------
CREATE MATERIALIZED VIEW v_order_items AS
SELECT
    i.order_id,
    i.order_item_id,
    i.product_id,
    COALESCE(p.product_category, 'unknown') AS product_category,
    i.seller_id,
    o.order_date,
    o.order_month,
    i.price,
    i.freight_value
FROM order_items i
JOIN v_orders o  ON o.order_id = i.order_id
JOIN products p  ON p.product_id = i.product_id;

-- ---------------------------------------------------------------------
-- v_customers: one row per real customer
-- ---------------------------------------------------------------------
CREATE MATERIALIZED VIEW v_customers AS
SELECT
    customer_unique_id,
    -- State of the most recent order
    (ARRAY_AGG(customer_state ORDER BY order_date DESC))[1] AS customer_state,
    MIN(order_date)   AS first_order_date,
    MIN(order_month)  AS cohort_month,      -- month of the first order
    MAX(order_date)   AS last_order_date,
    COUNT(*)          AS orders,
    SUM(revenue)      AS revenue
FROM v_orders
GROUP BY customer_unique_id;

-- ---------------------------------------------------------------------
-- v_customer_rfm: Recency, Frequency, Monetary scores and a segment
--
--   Recency    days since the last order, counted from 1 Sep 2018
--              (the day after the analysis window ends)
--   Frequency  number of orders
--   Monetary   total revenue
--
-- Recency and Monetary are scored 1 to 5 with NTILE (5 = best).
-- Frequency is NOT scored with NTILE: 97% of customers have exactly one
-- order, so NTILE would split identical customers into different
-- scores at random. It is used directly instead (1 order or 2+).
-- ---------------------------------------------------------------------
CREATE MATERIALIZED VIEW v_customer_rfm AS
WITH scored AS (
    SELECT
        customer_unique_id,
        DATE '2018-09-01' - last_order_date                         AS recency_days,
        orders                                                      AS frequency,
        revenue                                                     AS monetary,
        -- customer_unique_id breaks ties, so the scores are the same on every run
        NTILE(5) OVER (ORDER BY last_order_date, customer_unique_id) AS r_score,
        NTILE(5) OVER (ORDER BY revenue, customer_unique_id)         AS m_score
    FROM v_customers
)
SELECT
    *,
    CASE
        WHEN frequency >= 2 AND r_score >= 4 THEN 'Champions'
        WHEN frequency >= 2                  THEN 'Loyal, cooling off'
        WHEN r_score >= 4 AND m_score >= 4   THEN 'New big spenders'
        WHEN r_score >= 4                    THEN 'New customers'
        WHEN r_score <= 2 AND m_score >= 4   THEN 'Lost big spenders'
        WHEN r_score <= 2                    THEN 'Lost low value'
        ELSE                                      'Need attention'
    END AS segment
FROM scored;

-- ---------------------------------------------------------------------
-- dim_date: one row per calendar day in the analysis window (Power BI)
-- ---------------------------------------------------------------------
CREATE VIEW dim_date AS
SELECT
    d::date                              AS date,
    EXTRACT(YEAR FROM d)::int            AS year,
    EXTRACT(QUARTER FROM d)::int         AS quarter,
    EXTRACT(MONTH FROM d)::int           AS month_number,
    TO_CHAR(d, 'Mon')                    AS month_name,
    TO_CHAR(d, 'YYYY-MM')                AS year_month,
    DATE_TRUNC('month', d)::date         AS month_start,
    EXTRACT(ISODOW FROM d)::int          AS weekday_number,   -- 1 = Monday
    TO_CHAR(d, 'Dy')                     AS weekday_name
FROM GENERATE_SERIES(DATE '2017-01-01', DATE '2018-08-31', INTERVAL '1 day') AS d;

-- Indexes on the columns the analysis queries join and group on.
CREATE INDEX ON v_orders (customer_unique_id);
CREATE INDEX ON v_orders (order_month);
CREATE INDEX ON v_order_items (order_id);
CREATE UNIQUE INDEX ON v_customers (customer_unique_id);
CREATE UNIQUE INDEX ON v_customer_rfm (customer_unique_id);
