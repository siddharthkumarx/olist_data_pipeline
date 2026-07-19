-- ===========================================================================
-- Q5. Who are our best customers? (RFM segmentation)
-- Business question : Segment customers by Recency, Frequency, Monetary
--                     value so marketing can target each group differently.
-- Techniques        : CTEs, NTILE(5) window function, scalar subquery,
--                     CASE-based segment labelling
-- Why it matters    : RFM is the classic, explainable segmentation model -
--                     no ML needed, pure SQL, and every marketer
--                     understands the output.
-- Honest caveat     : ~97% of Olist customers ordered exactly once, so the
--                     frequency dimension is skewed. NTILE still splits it
--                     into 5 buckets mechanically - worth mentioning in an
--                     interview, because noticing it matters more than the
--                     query itself.
-- ===========================================================================

WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        MAX(o.order_purchase_timestamp)          AS last_purchase,
        COUNT(DISTINCT o.order_id)               AS frequency,
        SUM(oi.price + oi.freight_value)         AS monetary
    FROM orders o
    JOIN customers c   ON c.customer_id = o.customer_id
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
scored AS (
    SELECT
        customer_unique_id,
        DATEDIFF(
            (SELECT MAX(order_purchase_timestamp) FROM orders),
            last_purchase
        )                                        AS recency_days,
        frequency,
        monetary,
        NTILE(5) OVER (ORDER BY last_purchase ASC) AS r_score,  -- 5 = most recent
        NTILE(5) OVER (ORDER BY frequency     ASC) AS f_score,  -- 5 = most frequent
        NTILE(5) OVER (ORDER BY monetary      ASC) AS m_score   -- 5 = highest spend
    FROM customer_orders
)
SELECT
    CASE
        WHEN r_score >= 4 AND f_score >= 4 THEN 'champions'
        WHEN r_score >= 4 AND f_score <= 2 THEN 'promising_new'
        WHEN r_score <= 2 AND f_score >= 4 THEN 'at_risk_loyal'
        WHEN r_score <= 2 AND f_score <= 2 THEN 'hibernating'
        ELSE 'regular'
    END                                          AS segment,
    COUNT(*)                                     AS customers,
    ROUND(AVG(recency_days))                     AS avg_recency_days,
    ROUND(AVG(frequency), 2)                     AS avg_frequency,
    ROUND(AVG(monetary), 2)                      AS avg_monetary
FROM scored
GROUP BY segment
ORDER BY customers DESC;
