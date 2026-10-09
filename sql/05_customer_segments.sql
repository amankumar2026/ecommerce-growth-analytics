-- =====================================================================
-- 05. Customer segmentation (RFM)
-- Which customers are worth the most, and which are slipping away?
-- The scoring rules are defined once, in the view v_customer_rfm
-- (see 02_views.sql).
-- =====================================================================

-- name: rfm_segments
-- Q14. How many customers are in each segment and what are they worth?
SELECT
    segment,
    COUNT(*)                                                     AS customers,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)           AS customer_share_pct,
    ROUND(SUM(monetary), 0)                                      AS revenue,
    ROUND(100.0 * SUM(monetary) / SUM(SUM(monetary)) OVER (), 1) AS revenue_share_pct,
    ROUND(AVG(monetary), 2)                                      AS avg_revenue,
    ROUND(AVG(recency_days), 0)                                  AS avg_days_since_order,
    ROUND(AVG(frequency), 2)                                     AS avg_orders
FROM v_customer_rfm
GROUP BY segment
ORDER BY revenue DESC;

-- name: revenue_concentration
-- Q15. How much of revenue comes from the top customers?
-- NTILE(10) splits customers into ten equal groups by revenue.
-- Decile 1 is the top 10% of spenders.
WITH deciles AS (
    SELECT
        monetary,
        NTILE(10) OVER (ORDER BY monetary DESC, customer_unique_id) AS decile
    FROM v_customer_rfm
)
SELECT
    decile,
    COUNT(*)                                                     AS customers,
    ROUND(MIN(monetary), 2)                                      AS min_spend,
    ROUND(SUM(monetary), 0)                                      AS revenue,
    ROUND(100.0 * SUM(monetary) / SUM(SUM(monetary)) OVER (), 1) AS revenue_share_pct,
    ROUND(100.0 * SUM(SUM(monetary)) OVER (ORDER BY decile)
          / SUM(SUM(monetary)) OVER (), 1)                       AS cumulative_share_pct
FROM deciles
GROUP BY decile
ORDER BY decile;

-- name: segment_top_category
-- Q16. What does each segment buy most?
-- ROW_NUMBER() ranks categories inside each segment; rank 1 is kept.
WITH segment_category AS (
    SELECT
        r.segment,
        i.product_category,
        SUM(i.price) AS revenue
    FROM v_order_items i
    JOIN v_orders o       USING (order_id)
    JOIN v_customer_rfm r USING (customer_unique_id)
    GROUP BY r.segment, i.product_category
),
ranked AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY segment ORDER BY revenue DESC) AS category_rank,
           100.0 * revenue / SUM(revenue) OVER (PARTITION BY segment)     AS share_of_segment
    FROM segment_category
)
SELECT
    segment,
    product_category        AS top_category,
    ROUND(revenue, 0)       AS revenue,
    ROUND(share_of_segment, 1) AS share_of_segment_pct
FROM ranked
WHERE category_rank = 1
ORDER BY revenue DESC;
