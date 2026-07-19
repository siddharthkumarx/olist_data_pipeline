-- ===========================================================================
-- Q9. What share of customers ever buy twice?
-- Business question : Repeat rate is the health metric for any marketplace.
-- Techniques        : CTE, SUM over boolean, the customer_id trap
--
-- THE TRAP (favourite interview topic for this dataset):
--   In Olist, customer_id is unique PER ORDER - it is an order-session id.
--   Count repeat customers with customer_id and you get exactly 0%.
--   customer_unique_id is the actual person. Using the wrong one silently
--   produces a wrong-but-plausible answer, which is the most dangerous
--   kind of wrong.
-- ===========================================================================

WITH per_customer AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS order_count
    FROM orders o
    JOIN customers c ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
)
SELECT
    COUNT(*)                                        AS total_customers,
    SUM(order_count > 1)                            AS repeat_customers,
    ROUND(100 * SUM(order_count > 1) / COUNT(*), 2) AS repeat_rate_pct,
    MAX(order_count)                                AS max_orders_one_customer
FROM per_customer;

-- Distribution of orders per customer.
-- Note: a CTE only lives for one statement, so it is declared again here.
WITH per_customer AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS order_count
    FROM orders o
    JOIN customers c ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
)
SELECT
    order_count,
    COUNT(*) AS customers
FROM per_customer
GROUP BY order_count
ORDER BY order_count;
