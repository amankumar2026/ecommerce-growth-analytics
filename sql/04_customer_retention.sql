-- =====================================================================
-- 04. Customer retention
-- Do customers come back after their first order?
-- =====================================================================

-- name: repeat_rate
-- Q9. How many customers buy more than once?
SELECT
    CASE WHEN orders = 1 THEN '1 order'
         WHEN orders = 2 THEN '2 orders'
         ELSE '3 or more orders' END                             AS customer_group,
    COUNT(*)                                                     AS customers,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)           AS customer_share_pct,
    ROUND(SUM(revenue), 0)                                       AS revenue,
    ROUND(100.0 * SUM(revenue) / SUM(SUM(revenue)) OVER (), 1)   AS revenue_share_pct,
    ROUND(AVG(revenue), 2)                                       AS revenue_per_customer
FROM v_customers
GROUP BY 1
ORDER BY 1;

-- name: new_vs_returning
-- Q10. Each month, how much revenue comes from new and from returning customers?
-- customer_order_number = 1 marks a customer's first ever order.
SELECT
    order_month,
    COUNT(*) FILTER (WHERE customer_order_number = 1)            AS new_customer_orders,
    COUNT(*) FILTER (WHERE customer_order_number > 1)            AS returning_customer_orders,
    ROUND(SUM(revenue) FILTER (WHERE customer_order_number > 1), 0) AS returning_revenue,
    ROUND(100.0 * SUM(revenue) FILTER (WHERE customer_order_number > 1)
          / SUM(revenue), 1)                                     AS returning_revenue_pct
FROM v_orders
GROUP BY order_month
ORDER BY order_month;

-- name: cohort_retention
-- Q11. Of the customers who first bought in a given month, what share
--      ordered again 1, 2, 3 ... months later?
-- A cohort is the group of customers who placed their first order in
-- the same month. months_since_first = 0 is that first month.
WITH activity AS (
    SELECT DISTINCT
        c.cohort_month,
        o.customer_unique_id,
        (EXTRACT(YEAR FROM AGE(o.order_month, c.cohort_month)) * 12
         + EXTRACT(MONTH FROM AGE(o.order_month, c.cohort_month)))::int AS months_since_first
    FROM v_orders o
    JOIN v_customers c USING (customer_unique_id)
),
cohort_size AS (
    SELECT cohort_month, COUNT(*) AS customers
    FROM v_customers
    GROUP BY cohort_month
)
SELECT
    a.cohort_month,
    s.customers                                                  AS cohort_customers,
    a.months_since_first,
    COUNT(*)                                                     AS active_customers,
    ROUND(100.0 * COUNT(*) / s.customers, 2)                     AS retention_pct
FROM activity a
JOIN cohort_size s USING (cohort_month)
WHERE a.months_since_first <= 12
GROUP BY a.cohort_month, s.customers, a.months_since_first
ORDER BY a.cohort_month, a.months_since_first;

-- name: time_to_second_order
-- Q12. When customers do come back, how long does it take?
-- LEAD() fetches the date of each customer's next order.
WITH gaps AS (
    SELECT
        customer_order_number,
        LEAD(order_date) OVER (PARTITION BY customer_unique_id
                               ORDER BY customer_order_number) - order_date AS days_to_next
    FROM v_orders
),
first_gap AS (
    SELECT days_to_next
    FROM gaps
    WHERE customer_order_number = 1 AND days_to_next IS NOT NULL
)
SELECT
    CASE WHEN days_to_next = 0    THEN '1. Same day'
         WHEN days_to_next <= 30  THEN '2. Within 30 days'
         WHEN days_to_next <= 90  THEN '3. 31 to 90 days'
         WHEN days_to_next <= 180 THEN '4. 91 to 180 days'
         ELSE                          '5. Over 180 days' END    AS second_order_timing,
    COUNT(*)                                                     AS customers,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)           AS share_pct
FROM first_gap
GROUP BY 1
ORDER BY 1;

-- name: first_order_experience
-- Q13. Does a bad first order stop customers from coming back?
-- Compares the repeat rate by the review score of the FIRST order.
SELECT
    f.review_score                                               AS first_order_review,
    COUNT(*)                                                     AS customers,
    COUNT(*) FILTER (WHERE c.orders > 1)                         AS came_back,
    ROUND(100.0 * COUNT(*) FILTER (WHERE c.orders > 1) / COUNT(*), 2) AS repeat_rate_pct
FROM v_orders f
JOIN v_customers c USING (customer_unique_id)
WHERE f.customer_order_number = 1
  AND f.review_score IS NOT NULL
GROUP BY f.review_score
ORDER BY f.review_score;
