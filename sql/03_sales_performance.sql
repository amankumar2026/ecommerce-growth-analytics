-- =====================================================================
-- 03. Sales performance
-- How much are we selling, is it growing, and where does it come from?
-- =====================================================================

-- name: kpi_summary
-- Q1. What are the headline numbers for the business?
SELECT
    COUNT(*)                                   AS orders,
    COUNT(DISTINCT customer_unique_id)         AS customers,
    ROUND(SUM(revenue), 0)                     AS revenue,
    ROUND(AVG(revenue), 2)                     AS avg_order_value,
    ROUND(SUM(items)::numeric / COUNT(*), 2)   AS items_per_order,
    ROUND(AVG(delivery_days), 1)               AS avg_delivery_days,
    ROUND(AVG(review_score), 2)                AS avg_review_score
FROM v_orders;

-- name: monthly_revenue
-- Q2. How has revenue changed month by month?
-- LAG() fetches the previous month's revenue so growth can be calculated.
-- SUM() OVER (ORDER BY ...) gives a running total.
WITH monthly AS (
    SELECT
        order_month,
        COUNT(*)      AS orders,
        SUM(revenue)  AS revenue
    FROM v_orders
    GROUP BY order_month
)
SELECT
    order_month,
    orders,
    ROUND(revenue, 0)                                     AS revenue,
    ROUND(revenue / orders, 2)                            AS avg_order_value,
    ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY order_month))
          / LAG(revenue) OVER (ORDER BY order_month), 1)  AS growth_pct,
    ROUND(SUM(revenue) OVER (ORDER BY order_month), 0)    AS running_revenue
FROM monthly
ORDER BY order_month;

-- name: year_over_year
-- Q3. Compared with the same month a year earlier, how much did we grow?
-- Comparing January with January removes the effect of seasonality.
-- LAG(revenue, 12) looks back twelve rows, which is twelve months.
WITH monthly AS (
    SELECT order_month, SUM(revenue) AS revenue
    FROM v_orders
    GROUP BY order_month
),
compared AS (
    SELECT
        order_month,
        revenue,
        LAG(revenue, 12) OVER (ORDER BY order_month) AS revenue_last_year
    FROM monthly
)
SELECT
    order_month,
    ROUND(revenue_last_year, 0)                                      AS revenue_last_year,
    ROUND(revenue, 0)                                                AS revenue_this_year,
    ROUND(100.0 * (revenue - revenue_last_year) / revenue_last_year, 0) AS yoy_growth_pct
FROM compared
WHERE revenue_last_year IS NOT NULL
ORDER BY order_month;

-- name: top_categories
-- Q4. Which product categories bring in the most revenue?
-- The cumulative share shows how few categories make up most of sales.
WITH by_category AS (
    SELECT
        product_category,
        COUNT(*)                  AS items_sold,
        COUNT(DISTINCT order_id)  AS orders,
        SUM(price)                AS revenue
    FROM v_order_items
    GROUP BY product_category
)
SELECT
    RANK() OVER (ORDER BY revenue DESC)                              AS rank,
    product_category,
    items_sold,
    ROUND(revenue, 0)                                                AS revenue,
    ROUND(revenue / items_sold, 2)                                   AS avg_item_price,
    ROUND(100.0 * revenue / SUM(revenue) OVER (), 1)                 AS revenue_share_pct,
    ROUND(100.0 * SUM(revenue) OVER (ORDER BY revenue DESC)
          / SUM(revenue) OVER (), 1)                                 AS cumulative_share_pct
FROM by_category
ORDER BY revenue DESC
LIMIT 15;

-- name: category_concentration
-- Q5. How many categories does it take to reach 80% of revenue?
WITH by_category AS (
    SELECT product_category, SUM(price) AS revenue
    FROM v_order_items
    GROUP BY product_category
),
ranked AS (
    SELECT
        product_category,
        SUM(revenue) OVER (ORDER BY revenue DESC) / SUM(revenue) OVER () AS cumulative_share
    FROM by_category
)
SELECT
    COUNT(*) FILTER (WHERE cumulative_share <= 0.80) + 1  AS categories_for_80_pct,
    COUNT(*)                                              AS total_categories
FROM ranked;

-- name: revenue_by_state
-- Q6. Which states do customers buy from?
SELECT
    customer_state,
    COUNT(*)                                             AS orders,
    ROUND(SUM(revenue), 0)                               AS revenue,
    ROUND(100.0 * SUM(revenue) / SUM(SUM(revenue)) OVER (), 1) AS revenue_share_pct,
    ROUND(AVG(revenue), 2)                               AS avg_order_value,
    ROUND(AVG(freight), 2)                               AS avg_freight
FROM v_orders
GROUP BY customer_state
ORDER BY revenue DESC
LIMIT 10;

-- name: weekday_pattern
-- Q7. On which days of the week do customers order?
SELECT
    EXTRACT(ISODOW FROM order_date)::int                 AS weekday_number,
    TO_CHAR(order_date, 'Day')                           AS weekday,
    COUNT(*)                                             AS orders,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)   AS share_pct
FROM v_orders
GROUP BY 1, 2
ORDER BY 1;

-- name: payment_methods
-- Q8. How do customers pay?
-- Joins the raw payments table to the clean orders view.
SELECT
    p.payment_type,
    COUNT(DISTINCT p.order_id)                                   AS orders,
    ROUND(SUM(p.payment_value), 0)                               AS amount_paid,
    ROUND(100.0 * SUM(p.payment_value) / SUM(SUM(p.payment_value)) OVER (), 1) AS share_pct,
    ROUND(AVG(p.payment_installments), 1)                        AS avg_installments
FROM payments p
JOIN v_orders o ON o.order_id = p.order_id
GROUP BY p.payment_type
ORDER BY amount_paid DESC;
