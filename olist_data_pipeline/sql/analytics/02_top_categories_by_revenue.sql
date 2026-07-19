-- ===========================================================================
-- Q2. Which product categories drive revenue?
-- Business question : Where should marketing and inventory investment go?
-- Techniques        : Multi-table join, LEFT JOIN (translation table is
--                     incomplete at the source), window SUM() OVER () for
--                     revenue share
-- Why it matters    : Revenue share, not raw revenue, shows concentration
--                     risk - how dependent the marketplace is on few
--                     categories.
-- ===========================================================================

SELECT
    COALESCE(t.product_category_name_english,
             p.product_category_name,
             'uncategorized')                             AS category,
    COUNT(DISTINCT oi.order_id)                           AS orders,
    ROUND(SUM(oi.price), 2)                               AS revenue,
    ROUND(100 * SUM(oi.price) / SUM(SUM(oi.price)) OVER (), 2) AS revenue_share_pct
FROM order_items oi
JOIN orders o
    ON o.order_id = oi.order_id
   AND o.order_status = 'delivered'
JOIN products p
    ON p.product_id = oi.product_id
LEFT JOIN product_category_translation t
    ON t.product_category_name = p.product_category_name
GROUP BY category
ORDER BY revenue DESC
LIMIT 15;
