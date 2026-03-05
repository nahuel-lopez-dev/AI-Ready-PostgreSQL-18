
/* ============================================================================

                        Code samples for Chapter 12

    Part 1: the three different star schemas (view-only, materialized-view based,
    trigger-table based) are created and populated using the scripts in
    psql_scripts/database_definitions/central_analytics_stars.sql

    They are all created and populated when running the master setup
    script in psql_scripts/database_definitions/master_setup.sql.
    
    Part 2: Benchmarking code to compare the performance of the three different 
    star schemas implementations

    The code below runs the same query against each of the three implementations
    multiple times and measures the execution time for each approach.

    We recommend running the pgbench scripts, decribed Chapter 8, to generate
    sufficient data in the central_analytics database before running the 
    benchmarking code below to get more meaningful results.

    Remember to refresh the materialized views before running the benchmark!

    The code needs to be run when connected to the central_analytics database.

============================================================================ */ 

-- simple example for a view

CREATE OR REPLACE VIEW transactions_per_month AS
    SELECT EXTRACT(YEAR FROM transaction_date) AS year, 
        EXTRACT(MONTH FROM transaction_date) AS month, 
        COUNT(id) AS total_transactions
    FROM sales_transaction
    WHERE transaction_date BETWEEN '2024-01-01' AND '2024-12-31'
    GROUP BY year, month
    ORDER BY year, month;

-- refresh the materialized views before running the benchmark
REFRESH MATERIALIZED VIEW mv_analytics.mv_dim_date;
REFRESH MATERIALIZED VIEW mv_analytics.mv_dim_product;
REFRESH MATERIALIZED VIEW mv_analytics.mv_dim_customer_location;
REFRESH MATERIALIZED VIEW mv_analytics.mv_fact_sales;    


-- measure the time it takes to run this query in the three different star schema implementations
DO
$$
DECLARE
    v_start_time_tt TIMESTAMP WITH TIME ZONE;
    v_end_time_tt TIMESTAMP WITH TIME ZONE;
    v_execution_time_tt NUMERIC;
    v_total_sales_tt NUMERIC;
    v_start_time_vo TIMESTAMP WITH TIME ZONE;
    v_end_time_vo TIMESTAMP WITH TIME ZONE;
    v_execution_time_vo NUMERIC;
    v_total_sales_vo NUMERIC;
    v_start_time_mv TIMESTAMP WITH TIME ZONE;
    v_end_time_mv TIMESTAMP WITH TIME ZONE;
    v_execution_time_mv NUMERIC;
    v_total_sales_mv NUMERIC;    
    v_iterations INTEGER = 5;
BEGIN
    -- tables and triggers
    v_start_time_tt:= CLOCK_TIMESTAMP();
    FOR i IN 1 .. v_iterations LOOP
        SELECT SUM(sales_amount) INTO v_total_sales_tt FROM tt_analytics.fact_sales;
        PERFORM state_name, COALESCE(city, 'Total'), SUM(sales_amount) AS total_sales_amount 
            FROM tt_analytics.fact_sales
            JOIN tt_analytics.dim_customer_location AS cl ON fact_sales.customer_id = cl.customer_id
            JOIN tt_analytics.dim_date AS dd ON fact_sales.date = dd.date_key
            WHERE 
                year = 2025 AND 
                month IN(1,2,3) AND
                cl.geographic_region = 'Northeast'
            GROUP BY ROLLUP (state_name, city)
            HAVING SUM(sales_amount) > 250
            ORDER BY state_name, city ASC NULLS LAST;
    END LOOP;
    v_end_time_tt := CLOCK_TIMESTAMP();  
    v_execution_time_tt := EXTRACT(EPOCH FROM v_end_time_tt - v_start_time_tt) * 1000/ v_iterations;  

    -- view only
    v_start_time_vo:= CLOCK_TIMESTAMP();
    FOR i IN 1 .. v_iterations LOOP
        SELECT SUM(sales_amount) INTO v_total_sales_vo FROM vo_analytics.vw_fact_sales;
        PERFORM state_name, COALESCE(city, 'Total'), SUM(sales_amount) AS total_sales_amount 
            FROM vo_analytics.vw_fact_sales
            JOIN vo_analytics.vw_dim_customer_location AS cl ON vw_fact_sales.customer_id = cl.customer_id
            JOIN vo_analytics.vw_dim_date AS dd ON vw_fact_sales.date = dd.date_key
            WHERE 
                year = 2025 AND 
                month IN(1,2,3) AND
                cl.geographic_region = 'Northeast'
            GROUP BY ROLLUP (state_name, city)
            HAVING SUM(sales_amount) > 250
            ORDER BY state_name, city ASC NULLS LAST;
    END LOOP;
    v_end_time_vo := CLOCK_TIMESTAMP();  
    v_execution_time_vo := EXTRACT(EPOCH FROM v_end_time_vo - v_start_time_vo) * 1000 / v_iterations;
   
    -- materialized view
    v_start_time_mv:= CLOCK_TIMESTAMP();
    FOR i IN 1 .. v_iterations LOOP
        SELECT SUM(sales_amount) INTO v_total_sales_mv FROM vo_analytics.vw_fact_sales;
        PERFORM state_name, COALESCE(city, 'Total'), SUM(sales_amount) AS total_sales_amount 
            FROM mv_analytics.mv_fact_sales
            JOIN mv_analytics.mv_dim_customer_location AS cl ON mv_fact_sales.customer_id = cl.customer_id
            JOIN mv_analytics.mv_dim_date AS dd ON mv_fact_sales.date = dd.date_key
            WHERE 
                year = 2025 AND 
                month IN(1,2,3) AND
                cl.geographic_region = 'Northeast'
            GROUP BY ROLLUP (state_name, city)
            HAVING SUM(sales_amount) > 250
            ORDER BY state_name, city ASC NULLS LAST;
    END LOOP;
    v_end_time_mv := CLOCK_TIMESTAMP();  
    v_execution_time_mv := EXTRACT(EPOCH FROM v_end_time_mv - v_start_time_mv) * 1000 / v_iterations;

    RAISE NOTICE 'Comparing Totals:';
    RAISE NOTICE 'Tables & triggers: %', v_total_sales_tt;
    RAISE NOTICE 'View only: %', v_total_sales_vo;
    RAISE NOTICE 'Materialized view: %', v_total_sales_mv;
    
    RAISE NOTICE 'Execution times:';
    RAISE NOTICE 'View only: % ms', ROUND(v_execution_time_vo, 2);
    RAISE NOTICE 'Materialized view: % ms', ROUND(v_execution_time_mv, 2);
    RAISE NOTICE 'Tables & triggers: % ms', ROUND(v_execution_time_tt,2);
END
$$ LANGUAGE PLPGSQL;



            