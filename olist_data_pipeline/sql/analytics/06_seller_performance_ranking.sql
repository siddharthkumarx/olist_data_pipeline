-- ===========================================================================
-- Q6. Which sellers deserve promotion - and which need intervention?
-- Business question : Rank sellers by revenue, but read revenue TOGETHER
--                     with review score. High revenue + low rating is a
--                     brand risk hiding inside a top-line success metric.
-- Techniques        : Two independent CTE aggregations joined together,
--                     DENSE_RANK(), LEFT JOIN (some sellers have no
--                     reviews), minimum-volume filter
-- ===========================================================================

WITH seller_sales AS (
    SELECT
        oi.seller_id,
        COUNT(DISTINCT oi.order_id) AS orders,
        ROUND(SUM(oi.price), 2)     AS revenue
    FROM order_items oi
    JOIN orders o
        ON o.order_id = oi.order_id
       AND o.order_status = 'delivered'
    GROUP BY oi.seller_id
),
seller_reviews AS (
    SELECT
        oi.seller_id,
        ROUND(AVG(r.review_score), 2) AS avg_review_score
    FROM order_items oi
    JOIN order_reviews r ON r.order_id = oi.order_id
    GROUP BY oi.seller_id
)
SELECT
    ss.seller_id,
    s.seller_state,
    ss.orders,
    ss.revenue,
    sr.avg_review_score,
    DENSE_RANK() OVER (ORDER BY ss.revenue DESC) AS revenue_rank
FROM seller_sales ss
JOIN sellers s        ON s.seller_id  = ss.seller_id
LEFT JOIN seller_reviews sr ON sr.seller_id = ss.seller_id
WHERE ss.orders >= 10
ORDER BY revenue_rank
LIMIT 20;
