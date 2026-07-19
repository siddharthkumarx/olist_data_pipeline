-- ===========================================================================
-- Q4. Do customers come back after their first purchase?
-- Business question : What does monthly cohort retention look like?
-- Techniques        : Chained CTEs, TIMESTAMPDIFF, COUNT(DISTINCT),
--                     FIRST_VALUE() window function
-- Why it matters    : Acquisition is expensive; retention is where
--                     e-commerce margins live. Cohort tables are a standard
--                     interview whiteboard exercise for exactly that reason.
-- Note              : Uses customer_unique_id, NOT customer_id - see Q9 for
--                     why that distinction changes everything.
-- ===========================================================================

WITH orders_with_customer AS (
    SELECT
        o.order_id,
        o.order_purchase_timestamp,
        c.customer_unique_id
    FROM orders o
    JOIN customers c ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
),
first_purchase AS (
    SELECT
        customer_unique_id,
        DATE_FORMAT(MIN(order_purchase_timestamp), '%Y-%m-01') AS cohort_month
    FROM orders_with_customer
    GROUP BY customer_unique_id
),
activity AS (
    SELECT
        f.cohort_month,
        TIMESTAMPDIFF(
            MONTH,
            f.cohort_month,
            DATE_FORMAT(oc.order_purchase_timestamp, '%Y-%m-01')
        ) AS month_offset,
        oc.customer_unique_id
    FROM orders_with_customer oc
    JOIN first_purchase f USING (customer_unique_id)
),
cohort_counts AS (
    SELECT
        cohort_month,
        month_offset,
        COUNT(DISTINCT customer_unique_id) AS active_customers
    FROM activity
    GROUP BY cohort_month, month_offset
)
SELECT
    cohort_month,
    month_offset,
    active_customers,
    ROUND(
        100 * active_customers /
        FIRST_VALUE(active_customers) OVER (
            PARTITION BY cohort_month ORDER BY month_offset
        ),
        2
    ) AS retention_pct
FROM cohort_counts
WHERE month_offset <= 6
ORDER BY cohort_month, month_offset;
