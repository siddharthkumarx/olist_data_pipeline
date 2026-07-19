-- ===========================================================================
-- Q10. Where does freight eat the margin?
-- Business question : Compare freight cost - absolute and as a share of
--                     product price - across customer states, and measure
--                     how often shipments stay in-state.
-- Techniques        : 4-table join, NULLIF to avoid division by zero,
--                     AVG over boolean for same-state shipment share
-- Expected finding  : Remote northern states pay far more freight, both
--                     absolutely and relative to product price, and almost
--                     nothing ships from within their own state.
-- ===========================================================================

SELECT
    c.customer_state,
    COUNT(DISTINCT oi.order_id)                              AS orders,
    ROUND(AVG(oi.freight_value), 2)                          AS avg_freight,
    ROUND(AVG(oi.freight_value / NULLIF(oi.price, 0)) * 100, 1) AS freight_pct_of_price,
    ROUND(100 * AVG(s.seller_state = c.customer_state), 1)   AS same_state_shipment_pct
FROM order_items oi
JOIN orders o    ON o.order_id   = oi.order_id
               AND o.order_status = 'delivered'
JOIN customers c ON c.customer_id = o.customer_id
JOIN sellers s   ON s.seller_id   = oi.seller_id
GROUP BY c.customer_state
HAVING COUNT(DISTINCT oi.order_id) >= 100
ORDER BY avg_freight DESC;
