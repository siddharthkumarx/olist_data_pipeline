-- ===========================================================================
-- Q3. Where is delivery slow or unreliable?
-- Business question : Which states suffer the worst late-delivery rates?
-- Techniques        : DATEDIFF, AVG over a boolean expression (MySQL treats
--                     TRUE as 1, so AVG(condition) = percentage), HAVING
--                     for a minimum-volume threshold
-- Why it matters    : Late delivery is the strongest driver of bad reviews
--                     (proved in Q8). This query shows where the logistics
--                     problem lives geographically.
-- ===========================================================================

SELECT
    c.customer_state,
    COUNT(*)                                              AS delivered_orders,
    ROUND(AVG(DATEDIFF(o.order_delivered_customer_date,
                       o.order_purchase_timestamp)), 1)   AS avg_delivery_days,
    ROUND(AVG(DATEDIFF(o.order_estimated_delivery_date,
                       o.order_delivered_customer_date)), 1) AS avg_days_before_estimate,
    ROUND(100 * AVG(o.order_delivered_customer_date >
                    o.order_estimated_delivery_date), 2)  AS late_delivery_pct
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY c.customer_state
HAVING COUNT(*) >= 100
ORDER BY late_delivery_pct DESC;
