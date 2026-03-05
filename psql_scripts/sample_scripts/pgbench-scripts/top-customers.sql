/*
-- =================================================================================
Query being called by pgbench scripts to create a top 10 customer report.

-- =================================================================================
*/

-- select top ten customers by total sales amount
SELECT c.id, c.first_name, c.last_name, SUM(stl.qty * stl.price_at_sale) AS total_sales
FROM customer c
JOIN sales_transaction st ON c.id = st.customer_id 
JOIN sales_transaction_line stl ON st.id = stl.sales_transaction_id  
WHERE st.transaction_date >= CURRENT_DATE - INTERVAL '1 month'
GROUP BY c.id, c.first_name, c.last_name
ORDER BY total_sales DESC
LIMIT 10;


