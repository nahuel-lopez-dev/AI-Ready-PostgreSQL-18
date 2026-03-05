/*
-- =================================================================================
Query being called by pgbench scripts to create a top selling products report.

-- =================================================================================
*/

-- select top products and brands

SELECT b.label AS brand, p.label AS product, SUM(stl.qty) AS total_qty, SUM(stl.qty * stl.price_at_sale) AS total_sales
FROM product_variant pv
JOIN product p ON pv.product_id = p.id
JOIN brand b ON p.brand_id = b.id
JOIN sales_transaction_line stl ON pv.id = stl.product_variant_id  
GROUP BY CUBE (b.label, p.label)
ORDER BY b.label,  p.label DESC;