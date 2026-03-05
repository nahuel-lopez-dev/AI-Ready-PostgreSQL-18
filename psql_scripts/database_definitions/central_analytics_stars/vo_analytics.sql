
/*
================================================================================
  View-Only Analytics Schema for Central Analytics Database
================================================================================
  OWNER: Superuser
  PURPOSE: Explain how to create a view-only analytics schema for reporting
           on the central_analytics database.
  Details:
            * Schema: vo_analytics
            * 3 dimensions: date, product, customer location
            * 1 fact table: sales     

  This script is executed as part of the master setup script in
  psql_scripts/database_definitions/master_setup.sql           
================================================================================
*/



-- create the schema for view-only analytics
DROP SCHEMA IF EXISTS vo_analytics CASCADE;
CREATE SCHEMA vo_analytics;


-- create the date dimension view
DROP VIEW IF EXISTS vo_analytics.vw_dim_date CASCADE;

CREATE OR REPLACE VIEW vo_analytics.vw_dim_date AS
SELECT
    d::DATE AS date_key,
    EXTRACT(DAY FROM d) AS day,
    EXTRACT(MONTH FROM d) AS month,
    EXTRACT(QUARTER FROM d) AS quarter,
    EXTRACT(YEAR FROM d) AS year,
    EXTRACT(DOW FROM d) AS day_of_week,
    CASE WHEN EXTRACT(DOW FROM d) IN (0, 6) THEN true ELSE false END AS is_weekend
FROM
    GENERATE_SERIES('2020-01-01'::DATE, '2030-12-31'::DATE, INTERVAL '1 day') AS d;

-- create the product dimension view
DROP VIEW IF EXISTS vo_analytics.vw_dim_product CASCADE;

CREATE OR REPLACE VIEW vo_analytics.vw_dim_product AS
    SELECT 
        pv.id as product_variant_id, attributes, 
        pvp.price as current_price, 
        pv.attributes->>'size' as size, 
        pv.attributes->>'color' as color,
        p.label, c.label AS category, b.label AS brand, 
        co.name AS co_name,
        co.alpha3_code AS co_alpha3_code
    FROM product_variant pv
    JOIN product_variant_price pvp ON pv.id = pvp.product_variant_id AND pvp.current = true
    JOIN product p ON pv.product_id = p.id
    JOIN category c ON p.category_id = c.id
    JOIN brand b ON p.brand_id = b.id
    JOIN country_of_origin co ON co.brand_id = b.id;

-- create the customer location dimension view
DROP VIEW IF EXISTS vo_analytics.vw_dim_customer_location CASCADE;

CREATE VIEW vo_analytics.vw_dim_customer_location AS
SELECT 
    c.id AS customer_id,
    auxiliary.parse_zipcode_postalcode(c.postal_code) AS zipcode,
    city,
    state_code,
    state_name,
    st.territory_name sales_territory,
    ds.region geographic_region, 
    c.country
    FROM customer c
    JOIN auxiliary.us_state ds ON ds.state_code = auxiliary.parse_state_postalcode(c.postal_code)
    JOIN auxiliary.sales_territory st ON st.us_state_code = ds.state_code
    WHERE c.country = 'US';

-- create the sales fact view    

DROP VIEW IF EXISTS vo_analytics.vw_fact_sales CASCADE;

CREATE VIEW vo_analytics.vw_fact_sales AS
SELECT 
    stl.id sales_transaction_line_id,
    st.transaction_date AS date,
    stl.product_variant_id,
    st.customer_id,
    stl.qty AS quantity,
    stl.price_at_sale AS unit_price,
    (stl.qty * stl.price_at_sale) AS sales_amount
 FROM sales_transaction_line stl
JOIN sales_transaction st ON stl.sales_transaction_id = st.id;   