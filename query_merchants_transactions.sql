-- Query to find merchants (vendors) with highest number of transactions in the last month
-- Using vendor_payments table which represents payment transactions to vendors/merchants

SELECT 
    v.vendor_name AS merchant_name,
    COUNT(vp.payment_id) AS transaction_count,
    SUM(vp.total_amount) AS total_amount,
    vp.currency
FROM synthetic.vendor_payments vp
INNER JOIN synthetic.vendors v ON vp.vendor_id = v.vendor_id
WHERE vp.payment_date >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '1 month')
  AND vp.payment_date < DATE_TRUNC('month', CURRENT_DATE)
GROUP BY v.vendor_name, vp.currency
ORDER BY transaction_count DESC
LIMIT 20;

-- Alternative query if you want to use payment_transactions table instead
-- Note: This requires finding the relationship between payment_transactions and merchants
-- Since payment_transactions has order_id, we might need to join through orders table

-- SELECT 
--     m.merchant_name,
--     COUNT(pt.transaction_id) AS transaction_count,
--     SUM(pt.amount) AS total_amount,
--     pt.currency
-- FROM synthetic.payment_transactions pt
-- INNER JOIN synthetic.orders o ON pt.order_id = o.order_id
-- INNER JOIN synthetic.merchants m ON o.merchant_id = m.merchant_id  -- This join may not exist
-- WHERE pt.processed_at >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '1 month')
--   AND pt.processed_at < DATE_TRUNC('month', CURRENT_DATE)
-- GROUP BY m.merchant_name, pt.currency
-- ORDER BY transaction_count DESC
-- LIMIT 20;
