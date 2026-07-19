-- ===========================================================================
-- Q8. Does late delivery actually cause bad reviews?
-- Business question : Quantify the relationship between delivery timing
--                     and review score - the single clearest operational
--                     insight in this dataset.
-- Techniques        : CTE, DATEDIFF, CASE bucketing, AVG over boolean for
--                     percentage of 1-star reviews
-- Expected finding  : Review scores collapse as delay grows. Orders 8+
--                     days late average close to 2 stars.
-- ===========================================================================

WITH delivered AS (
    SELECT
        o.order_id,
        DATEDIFF(o.order_delivered_customer_date,
                 o.order_estimated_delivery_date) AS delay_days
    FROM orders o
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
)
SELECT
    CASE
        WHEN d.delay_days <= -7 THEN '1_week_plus_early'
        WHEN d.delay_days <  0  THEN '2_early'
        WHEN d.delay_days =  0  THEN '3_on_time'
        WHEN d.delay_days <= 3  THEN '4_late_1_to_3d'
        WHEN d.delay_days <= 7  THEN '5_late_4_to_7d'
        ELSE '6_late_8d_plus'
    END                                     AS delivery_bucket,
    COUNT(*)                                AS orders,
    ROUND(AVG(r.review_score), 2)           AS avg_review_score,
    ROUND(100 * AVG(r.review_score = 1), 1) AS pct_one_star
FROM delivered d
JOIN order_reviews r ON r.order_id = d.order_id
GROUP BY delivery_bucket
ORDER BY delivery_bucket;
