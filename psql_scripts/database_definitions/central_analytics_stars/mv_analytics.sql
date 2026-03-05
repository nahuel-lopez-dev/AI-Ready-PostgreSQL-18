
/*
================================================================================
  Materialized-View Based Analytics Schema for Central Analytics Database
================================================================================
  OWNER: Superuser
  PURPOSE: Explain how to create a materlized view-based analytics schema for reporting
           on the central_analytics database.
  Details:
            * Schema: mv_analytics
            * 3 dimensions: date, product, customer location
            * 1 fact table: sales      
            * Primary keys and indexes for performance defined on fact and dimension tables
  Uses the view definitions from vo_analytics as the basis for the materialized views.       

  This script is executed as part of the master setup script in
  psql_scripts/database_definitions/master_setup.sql             
================================================================================
*/

-- create the schema for materialized view analytics
DROP SCHEMA IF EXISTS mv_analytics CASCADE;
CREATE SCHEMA mv_analytics; 

-- create the date dimension materialized view
DROP MATERIALIZED VIEW IF EXISTS mv_analytics.mv_dim_date;  
CREATE MATERIALIZED VIEW mv_analytics.mv_dim_date AS
SELECT * FROM vo_analytics.vw_dim_date;
-- create an index on date_key for faster joins and concurrent refreshes
CREATE UNIQUE INDEX idx_mv_dim_date ON mv_analytics.mv_dim_date (date_key);

-- create the product dimension materialized view
DROP MATERIALIZED VIEW IF EXISTS mv_analytics.mv_dim_product;  
CREATE MATERIALIZED VIEW mv_analytics.mv_dim_product AS
SELECT * FROM vo_analytics.vw_dim_product;

-- create an index on product_variant_id for faster joins and concurrent refreshes
CREATE UNIQUE INDEX idx_mv_dim_product ON mv_analytics.mv_dim_product (product_variant_id);

-- create the customer location dimension materialized view
DROP MATERIALIZED VIEW IF EXISTS mv_analytics.mv_dim_customer_location;  
CREATE MATERIALIZED VIEW mv_analytics.mv_dim_customer_location AS
SELECT * FROM vo_analytics.vw_dim_customer_location;

-- create an index on customer_id for faster joins and concurrent refreshes
CREATE UNIQUE INDEX idx_mv_dim_customer_location ON mv_analytics.mv_dim_customer_location (customer_id);

-- create the sales fact materialized view    
DROP MATERIALIZED VIEW IF EXISTS mv_analytics.mv_fact_sales;  
CREATE MATERIALIZED VIEW mv_analytics.mv_fact_sales AS
SELECT * FROM vo_analytics.vw_fact_sales;

-- create an index on sales_transaction_line_id for faster joins and concurrent refreshes
CREATE UNIQUE INDEX idx_mv_fact_sales ON mv_analytics.mv_fact_sales (sales_transaction_line_id);

-- indexes on foreign keys for faster joins
CREATE INDEX idx_mv_fact_sales_date ON mv_analytics.mv_fact_sales (date);
CREATE INDEX idx_mv_fact_sales_product_variant ON mv_analytics.mv_fact_sales (product_variant_id);
CREATE INDEX idx_mv_fact_sales_customer ON mv_analytics.mv_fact_sales (customer_id);


