/* ============================================================================

                        Code samples for Chapter 13

    Examples of advanced SQL features including grouping sets, window functions,
    and recursive common table expressions (CTEs) are shown below.

    The sample code is focused on the table and trigger based star schema tt_analytics
    created using the script in
    psql_scripts/database_definitions/central_analytics_stars.sql

    The same queries can be run against the other two star schema implementations
    (view-only and materialized view based) by changing the search_path to
    vo_analytics or mv_analytics respectively.

    The samples should be run against the central_analytics database.
============================================================================ */ 

-- adding tt_analytics to the search_path for the current session
SELECT SET_CONFIG('search_path', 'tt_analytics,'||CURRENT_SETTING('search_path'), false);

-- Section Groups and Aggregates

SELECT 
    brand, category,
    FORMAT ('%2s - %s', 
        DIV(current_price, 10) *10, 
        (DIV(current_price, 10)+1)*10) AS price_range,
    COUNT(*) nbr_products,
    ROUND(AVG(current_price),2) AS avg_price,
    SUM (fact_sales.sales_amount) AS total
FROM dim_product
NATURAL JOIN fact_sales
JOIN dim_date ON fact_sales.date = dim_date.date_key
WHERE co_alpha3_code = 'USA' AND year = 2025
GROUP BY brand, category, price_range
HAVING SUM(fact_sales.sales_amount) > 10000
ORDER BY brand, category, price_range ASC;

-- Section Grouping Sets

SELECT 
    brand, category,
    FORMAT ('%2s - %s', 
        DIV(current_price, 10) *10, 
        (DIV(current_price, 10)+1)*10) AS price_range,
    COUNT(*) nbr_products,
    ROUND(AVG(current_price),2) as avg_price,
    SUM (fact_sales.sales_amount) as total
FROM dim_product
NATURAL JOIN fact_sales
WHERE co_alpha3_code = 'USA'
GROUP BY
    GROUPING SETS  ((brand, category, price_range), (brand, category), (brand), ())
HAVING SUM(fact_sales.sales_amount) > 5000
ORDER BY brand, category, price_range ASC NULLS LAST;


-- Section Rollup

SELECT 
    brand, category,
    FORMAT ('%2s - %s', 
        DIV(current_price, 10) *10, 
        (DIV(current_price, 10)+1)*10) AS price_range,
    COUNT(*) nbr_products,
    ROUND(AVG(current_price),2) as avg_price,
    SUM (fact_sales.sales_amount) as total
FROM dim_product
NATURAL JOIN fact_sales
WHERE co_alpha3_code = 'USA'
GROUP BY
    ROLLUP  (brand, category, price_range)
HAVING SUM(fact_sales.sales_amount) > 10000
ORDER BY brand, category, price_range ASC NULLS LAST;


SELECT 
    year, quarter, month, 
    SUM (fact_sales.sales_amount) AS total
FROM dim_date
JOIN fact_sales ON fact_sales.date = dim_date.date_key
WHERE year IN (2025)
GROUP BY 
    ROLLUP (year, quarter, month)
ORDER BY year, quarter, month ASC NULLS LAST;


-- Section Cube

SELECT 
    brand, category,
    FORMAT ('%2s - %s', 
        DIV(current_price, 10) *10, 
        (DIV(current_price, 10)+1)*10) AS price_range,
    COUNT(*) nbr_products,
    ROUND(AVG(current_price),2) as avg_price,
    SUM (fact_sales.sales_amount) as total
FROM dim_product
NATURAL JOIN fact_sales
WHERE co_alpha3_code = 'USA'
GROUP BY
    CUBE  (brand, category, price_range)
HAVING SUM(fact_sales.sales_amount) > 10000
ORDER BY brand ASC NULLS LAST, category ASC NULLS LAST, price_range ASC NULLS LAST;


-- Section Window Functions

SELECT DISTINCT brand, label, current_price AS price, 
    ROUND(AVG(current_price) OVER (PARTITION BY brand),2) AS avg_brand
    FROM dim_product
    ORDER by brand, label ASC;    


SELECT DISTINCT 
    brand, 
    sum(sales_amount) OVER (PARTITION BY brand) AS total_brand_sales,
    sum(sales_amount) OVER () AS total_sales,
    ROUND( (sum(sales_amount) OVER (PARTITION BY brand)/ sum(sales_amount) OVER ()) * 100, 2) AS pct_total_sales
    FROM dim_product
    JOIN fact_sales ON fact_sales.product_variant_id = dim_product.product_variant_id
    ORDER by total_brand_sales DESC;

SELECT DISTINCT 
    brand, 
    sum(sales_amount) OVER (PARTITION BY brand) AS total_brand_sales,
    -- sum(sales_amount) OVER () AS total_sales,
    ROUND( (sum(sales_amount) OVER (PARTITION BY brand)/ sum(sales_amount) OVER ()) * 100, 2) AS pct_total_sales,
    SUM(sales_amount) OVER w
    FROM dim_product
    JOIN fact_sales ON fact_sales.product_variant_id = dim_product.product_variant_id
    WINDOW w AS (ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
    ORDER by total_brand_sales DESC;


-- Section CTE

WITH brand_sales 
AS (
    -- the temp table expression to calculate total sales per brand
    SELECT brand, sum(sales_amount) AS total_brand_sales
    FROM dim_product dp
    NATURAL JOIN fact_sales
    GROUP BY brand
    ORDER BY total_brand_sales DESC
)
    -- main query to rank brands by sales and calculate running totals and percentages
SELECT 
    RANK() OVER (ORDER BY total_brand_sales DESC) AS rank,
    brand, total_brand_sales,
    SUM(total_brand_sales) OVER w AS running_total,
    ROUND( (SUM(total_brand_sales) OVER w / SUM(total_brand_sales) OVER ()) * 100, 2) AS pct_sales
FROM brand_sales
WINDOW w AS (ORDER BY total_brand_sales DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
ORDER BY total_brand_sales DESC;

SELECT
  bs.brand,
  bs.total_brand_sales,
  SUM(bs.total_brand_sales) OVER w AS running_total_sales,
  ROUND( (SUM(bs.total_brand_sales) OVER w / SUM(bs.total_brand_sales) OVER ()) * 100, 2) AS pct_total_sales
FROM (
  SELECT d.brand, SUM(f.sales_amount) AS total_brand_sales
  FROM dim_product d
  NATURAL JOIN fact_sales
  GROUP BY d.brand
) AS bs
WINDOW w AS (ORDER BY bs.total_brand_sales DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
ORDER BY bs.total_brand_sales DESC;    

SELECT RANK() OVER (ORDER BY bs.total_brand_sales DESC) AS rank,
       bs.brand,
       bs.total_brand_sales AS brand_sales,
       SUM(bs.total_brand_sales) OVER w AS running_total,
       ROUND(
        (SUM(bs.total_brand_sales) OVER w / 
        SUM(bs.total_brand_sales) OVER ()) * 100, 2) 
            AS pct_sales
FROM
    (SELECT d.brand, SUM(f.sales_amount) AS total_brand_sales
     FROM dim_product d
     NATURAL JOIN fact_sales f
     GROUP BY d.brand) AS bs 
     -- define a window 'w' to be used in the calculations
     -- the window orders by total_brand_sales in descending order
     -- and includes all rows from the start of the result set to the current row
WINDOW w AS (ORDER BY bs.total_brand_sales DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
ORDER BY bs.total_brand_sales DESC;

-- Section Recursive CTEs

-- simple example of a recursive CTE to generate a sequence of numbers
WITH RECURSIVE sum_to_10 AS (
    SELECT 1 AS n
  UNION ALL
    SELECT n+1 FROM sum_to_10 WHERE n < 10
)
SELECT sum(n) FROM sum_to_10;  

-- CTE to traverse the hierachy of sales organization employees
WITH RECURSIVE sales_hierarchy AS (
    -- identify top managers (those without a manager)
    SELECT employee_id, first_name, last_name, 
        territory_id, manager_id, 1 AS level
    FROM auxiliary.sales_organization
    WHERE manager_id IS NULL   
    UNION ALL
    -- recursively join to find employees under each manager
    SELECT so.employee_id, so.first_name, so.last_name, so.territory_id, so.manager_id, sh.level + 1 AS level
    FROM auxiliary.sales_organization so
    JOIN sales_hierarchy sh ON so.manager_id = sh.employee_id
)
SELECT employee_id, first_name, last_name, manager_id FROM sales_hierarchy ORDER BY level, employee_id;


-- CTE to aggregate sales targets up the hierarchy
WITH RECURSIVE bottom_up AS (
    -- leaves of the hierarchy (those without subordinates)
    SELECT employee_id, first_name, last_name, manager_id, sales_target
        FROM auxiliary.sales_organization
        WHERE NOT EXISTS 
            (SELECT 1 FROM auxiliary.sales_organization so 
                WHERE so.manager_id = auxiliary.sales_organization.employee_id) 
    UNION ALL
    -- aggregate sales targets up the hierarchy
    SELECT so.employee_id, so.first_name, so.last_name, so.manager_id,
        so.sales_target + bu.sales_target
    FROM auxiliary.sales_organization so
    JOIN bottom_up bu ON so.employee_id = bu.manager_id
)
SELECT  DISTINCT employee_id, first_name, last_name, manager_id,
    sum(sales_target) OVER (PARTITION BY employee_id) AS total_sales_target
    FROM bottom_up
    ORDER BY total_sales_target DESC;



-- CTE to illustrate the SEARCH DEPTH FIRST (BREADTH FIRST is the default)
WITH RECURSIVE hierarchy AS (
    SELECT employee_id, first_name, last_name, manager_id
    FROM auxiliary.sales_organization
    WHERE manager_id IS NULL
    UNION ALL
    SELECT so.employee_id, so.first_name, so.last_name, so.manager_id
    FROM auxiliary.sales_organization so
    JOIN hierarchy h ON so.manager_id = h.employee_id
) SEARCH DEPTH FIRST BY employee_id SET ordercol
SELECT employee_id, first_name, last_name, manager_id, ordercol FROM hierarchy
ORDER BY employee_id;


-- sample table for a cyclic data structure
CREATE TABLE test_cycle ( employee_id TEXT PRIMARY KEY, manager_id TEXT ); 
INSERT INTO test_cycle VALUES ('E001', 'E002'); 
INSERT INTO test_cycle VALUES ('E002', 'E003'); 
INSERT INTO test_cycle VALUES ('E003', 'E001'); 

-- CTE to detect cycles in the hierarchy using the CYCLE clause
WITH RECURSIVE hierarchy AS ( 
    SELECT employee_id, manager_id 
        FROM test_cycle 
        --WHERE manager_id IS NULL 
    UNION ALL 
    SELECT tc.employee_id, tc.manager_id 
        FROM test_cycle tc JOIN hierarchy h ON tc.manager_id = h.employee_id ) 
        CYCLE employee_id SET is_cycle USING path 
SELECT employee_id, manager_id, is_cycle, path FROM hierarchy ORDER BY path;