-- ===========================================================================
-- Q7. How do customers pay, and does installment count track order size?
-- Business question : Payment mix drives processing fees and cash-flow
--                     timing. Installments are also a proxy for how price-
--                     sensitive customers are.
-- Techniques        : Window SUM() OVER () for share-of-total, boolean
--                     bucketing with CASE, two independent statements
-- ===========================================================================

-- 7a. Payment method mix
SELECT
    p.payment_type,
    COUNT(*)                                          AS payments,
    ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)  AS share_pct,
    ROUND(AVG(p.payment_installments), 2)             AS avg_installments,
    ROUND(AVG(p.payment_value), 2)                    AS avg_payment_value,
    ROUND(SUM(p.payment_value), 2)                    AS total_value
FROM order_payments p
GROUP BY p.payment_type
ORDER BY total_value DESC;

-- 7b. For credit cards: do bigger purchases mean more installments?
SELECT
    CASE
        WHEN p.payment_installments = 1  THEN '1_single'
        WHEN p.payment_installments <= 3 THEN '2_to_3'
        WHEN p.payment_installments <= 6 THEN '4_to_6'
        WHEN p.payment_installments <= 12 THEN '7_to_12'
        ELSE '13_plus'
    END                                   AS installment_bucket,
    COUNT(*)                              AS payments,
    ROUND(AVG(p.payment_value), 2)        AS avg_payment_value
FROM order_payments p
WHERE p.payment_type = 'credit_card'
GROUP BY installment_bucket
ORDER BY installment_bucket;
