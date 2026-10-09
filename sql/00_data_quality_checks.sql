-- =====================================================================
-- 00. Data quality checks on the raw tables
-- Run these after loading (01_schema.sql). What they show is the reason
-- for each cleaning decision in 02_views.sql.
-- =====================================================================

-- name: table_sizes
-- Check 1. How many rows did each table load?
SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL SELECT 'orders',      COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL SELECT 'payments',    COUNT(*) FROM payments
UNION ALL SELECT 'reviews',     COUNT(*) FROM reviews
UNION ALL SELECT 'products',    COUNT(*) FROM products
UNION ALL SELECT 'sellers',     COUNT(*) FROM sellers;

-- name: order_status
-- Check 2. What states can an order be in?
-- Decision: only 'delivered' orders count as sales.
SELECT
    order_status,
    COUNT(*)                                            AS orders,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)  AS share_pct
FROM orders
GROUP BY order_status
ORDER BY orders DESC;

-- name: orders_per_month
-- Check 3. Is every month complete?
-- Decision: 2016 and Sep-Oct 2018 hold almost no orders, so the
-- analysis window is Jan 2017 to Aug 2018.
SELECT
    DATE_TRUNC('month', order_purchase_timestamp)::date AS order_month,
    COUNT(*)                                            AS orders
FROM orders
GROUP BY 1
ORDER BY 1;

-- name: customer_identity
-- Check 4. Does customer_id identify a person?
-- Decision: no. There are as many customer_ids as orders. The real
-- person is customer_unique_id.
SELECT
    COUNT(*)                            AS customer_rows,
    COUNT(DISTINCT customer_id)         AS distinct_customer_id,
    COUNT(DISTINCT customer_unique_id)  AS distinct_customer_unique_id
FROM customers;

-- name: missing_values
-- Check 5. Where are values missing?
-- COUNT(column) skips NULLs, so COUNT(*) - COUNT(column) counts them.
SELECT 'orders.order_delivered_customer_date (all orders)' AS field,
       COUNT(*) - COUNT(order_delivered_customer_date)     AS missing
FROM orders
UNION ALL
SELECT 'orders.order_delivered_customer_date (delivered only)',
       COUNT(*) - COUNT(order_delivered_customer_date)
FROM orders WHERE order_status = 'delivered'
UNION ALL
SELECT 'products.product_category',
       COUNT(*) - COUNT(product_category)
FROM products
UNION ALL
SELECT 'orders with no items',
       COUNT(*)
FROM orders o
WHERE NOT EXISTS (SELECT 1 FROM order_items i WHERE i.order_id = o.order_id)
UNION ALL
SELECT 'delivered orders with no review',
       COUNT(*)
FROM orders o
WHERE o.order_status = 'delivered'
  AND NOT EXISTS (SELECT 1 FROM reviews r WHERE r.order_id = o.order_id);

-- name: duplicate_reviews
-- Check 6. Can an order have more than one review?
-- Decision: yes, so the most recent review per order is used.
SELECT
    reviews_per_order,
    COUNT(*) AS orders
FROM (
    SELECT order_id, COUNT(*) AS reviews_per_order
    FROM reviews
    GROUP BY order_id
) t
GROUP BY reviews_per_order
ORDER BY reviews_per_order;

-- name: price_sanity
-- Check 7. Are prices and freight values sensible?
SELECT
    MIN(price)                              AS min_price,
    MAX(price)                              AS max_price,
    ROUND(AVG(price), 2)                    AS avg_price,
    COUNT(*) FILTER (WHERE price <= 0)      AS zero_or_negative_prices,
    COUNT(*) FILTER (WHERE freight_value = 0) AS free_shipping_items
FROM order_items;
