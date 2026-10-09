-- =====================================================================
-- 06. Delivery and customer satisfaction
-- Does delivery performance affect how customers rate us?
-- =====================================================================

-- name: late_vs_on_time
-- Q17. How do review scores differ between late and on-time orders?
SELECT
    CASE WHEN delivered_late THEN 'Late' ELSE 'On time' END      AS delivery,
    COUNT(*)                                                     AS orders,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)           AS share_pct,
    ROUND(AVG(delivery_days), 1)                                 AS avg_delivery_days,
    ROUND(AVG(review_score), 2)                                  AS avg_review_score,
    ROUND(100.0 * COUNT(*) FILTER (WHERE review_score <= 2)
          / COUNT(review_score), 1)                              AS bad_review_pct
FROM v_orders
WHERE delivered_late IS NOT NULL
GROUP BY delivered_late
ORDER BY delivered_late;

-- name: review_by_delivery_time
-- Q18. How does the review score fall as delivery takes longer?
SELECT
    CASE WHEN delivery_days <= 7  THEN '1. Up to 7 days'
         WHEN delivery_days <= 14 THEN '2. 8 to 14 days'
         WHEN delivery_days <= 21 THEN '3. 15 to 21 days'
         WHEN delivery_days <= 28 THEN '4. 22 to 28 days'
         ELSE                          '5. Over 28 days' END     AS delivery_time,
    COUNT(*)                                                     AS orders,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)           AS share_pct,
    ROUND(AVG(review_score), 2)                                  AS avg_review_score,
    ROUND(100.0 * COUNT(*) FILTER (WHERE review_score <= 2)
          / COUNT(review_score), 1)                              AS bad_review_pct
FROM v_orders
WHERE delivery_days IS NOT NULL
GROUP BY 1
ORDER BY 1;

-- name: delivery_by_state
-- Q19. Which states have the slowest and latest deliveries?
-- HAVING keeps only states with enough orders for a stable figure.
SELECT
    customer_state,
    COUNT(*)                                                     AS orders,
    ROUND(AVG(delivery_days), 1)                                 AS avg_delivery_days,
    ROUND(100.0 * AVG(delivered_late::int), 1)                   AS late_pct,
    ROUND(AVG(review_score), 2)                                  AS avg_review_score,
    ROUND(AVG(freight), 2)                                       AS avg_freight
FROM v_orders
GROUP BY customer_state
HAVING COUNT(*) >= 500
ORDER BY late_pct DESC;

-- name: monthly_delivery_trend
-- Q20. Is delivery getting better or worse over time?
SELECT
    order_month,
    COUNT(*)                                                     AS orders,
    ROUND(AVG(delivery_days), 1)                                 AS avg_delivery_days,
    ROUND(100.0 * AVG(delivered_late::int), 1)                   AS late_pct,
    ROUND(AVG(review_score), 2)                                  AS avg_review_score
FROM v_orders
GROUP BY order_month
ORDER BY order_month;

-- name: lowest_rated_categories
-- Q21. Which large categories have the unhappiest customers?
-- An order can hold items from several categories, so the order's
-- review is counted once for each category in it.
SELECT
    i.product_category,
    COUNT(DISTINCT i.order_id)                                   AS orders,
    ROUND(AVG(o.review_score), 2)                                AS avg_review_score,
    ROUND(100.0 * AVG(o.delivered_late::int), 1)                 AS late_pct
FROM (SELECT DISTINCT order_id, product_category FROM v_order_items) i
JOIN v_orders o USING (order_id)
GROUP BY i.product_category
HAVING COUNT(DISTINCT i.order_id) >= 1000
ORDER BY avg_review_score
LIMIT 8;
