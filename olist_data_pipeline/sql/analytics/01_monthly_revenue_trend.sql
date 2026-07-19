-- ===========================================================================
-- Q1. How is revenue trending month over month?
-- Business question : Is the marketplace growing, and how fast?
-- Techniques        : CTE, LAG() window function, date bucketing
-- Why it matters    : The first chart every stakeholder asks for.
--                     MoM growth exposes seasonality and momentum that a
--                     raw revenue total hides.
-- ===========================================================================

WITH monthly AS (
    SELECT
        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS order_month,
        COUNT(DISTINCT o.order_id)                       AS orders,
        ROUND(SUM(oi.price), 2)                          AS product_revenue,
        ROUND(SUM(oi.freight_value), 2)                  AS freight_revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m')
)
SELECT
    order_month,
    orders,
    product_revenue,
    freight_revenue,
    LAG(product_revenue) OVER (ORDER BY order_month) AS prev_month_revenue,
    ROUND(
        100 * (product_revenue - LAG(product_revenue) OVER (ORDER BY order_month))
            / LAG(product_revenue) OVER (ORDER BY order_month),
        1
    ) AS mom_growth_pct
FROM monthly
ORDER BY order_month;
