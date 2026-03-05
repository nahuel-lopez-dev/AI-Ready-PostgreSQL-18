

/*
================================================================================
  Tabled-Based Analytics Schema for Central Analytics Database
================================================================================
  OWNER: Superuser
  PURPOSE: Explain how to create a table-based analytics schema for reporting
           on the central_analytics database.
  Details:
            * Schema: tt_analytics
            * 3 dimensions: date, product, customer location
            * 1 fact table: sales      
            * Indexes for performance defined on fact and dimension tables
            * date dimension table generated from a date series
            * trigger-based maintenance of product and customer-location dimension dimensions
                * Customer-location dimension maintained via triggers on customer table
                * Product dimension maintained via triggers on product_variant, product_variant_price, product, category, brand, country_of_origin tables
            * trigger-based maintenance of sales fact table via triggers on sales_transaction_line table

  This script is executed as part of the master setup script in
  psql_scripts/database_definitions/master_setup.sql                
================================================================================
*/


-- create the schema for trigger-based table analytics
DROP SCHEMA IF EXISTS tt_analytics CASCADE;
CREATE SCHEMA tt_analytics;   


-- create the date dimension table. It is not dependant on replication so we can just create it directly from a date series

DROP TABLE IF EXISTS tt_analytics.dim_date CASCADE;
CREATE TABLE tt_analytics.dim_date(
    date_key DATE,
    day INTEGER,
    month INTEGER,
    quarter INTEGER,
    year INTEGER,
    day_of_week INTEGER,
    is_weekend BOOLEAN
);  

CREATE UNIQUE INDEX idx_dim_date ON tt_analytics.dim_date(date_key);


INSERT INTO tt_analytics.dim_date (date_key, day, month, quarter, year, day_of_week, is_weekend)
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




-- create the customer location dimension table  

DROP TABLE IF EXISTS tt_analytics.dim_customer_location CASCADE;
CREATE TABLE tt_analytics.dim_customer_location (
    customer_id UUID,
    zipcode CHAR(5),
    city VARCHAR(100),
    state_code CHAR(2),
    state_name VARCHAR(50),
    sales_territory VARCHAR(100),
    geographic_region VARCHAR(50),
    country VARCHAR(50)
);

CREATE UNIQUE INDEX idx_dim_customer_location ON tt_analytics.dim_customer_location (customer_id);

-- create the triggers and functions to maintain the dim_customer_location table

CREATE OR REPLACE FUNCTION tt_analytics.sf_insert_customer () 
RETURNS TRIGGER AS
$$
  BEGIN
    INSERT INTO tt_analytics.dim_customer_location (
        customer_id, zipcode, city, state_code, state_name, sales_territory, geographic_region, country)
    VALUES (
        NEW.id,
        auxiliary.parse_zipcode_postalcode(NEW.postal_code),
        NEW.city,
        auxiliary.parse_state_postalcode(NEW.postal_code),
        (SELECT state_name FROM auxiliary.us_state WHERE state_code = auxiliary.parse_state_postalcode(NEW.postal_code)),
        (SELECT territory_name FROM auxiliary.sales_territory WHERE us_state_code = auxiliary.parse_state_postalcode(NEW.postal_code)),
        (SELECT region FROM auxiliary.us_state WHERE state_code = auxiliary.parse_state_postalcode(NEW.postal_code)),
        NEW.country
    );
    RETURN NEW;
  END;
$$ LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION tt_analytics.sf_update_customer () 
RETURNS TRIGGER AS
$$
  BEGIN
    UPDATE tt_analytics.dim_customer_location
    SET
        zipcode = auxiliary.parse_zipcode_postalcode(NEW.postal_code),
        city = NEW.city,
        state_code = auxiliary.parse_state_postalcode(NEW.postal_code),
        state_name = (SELECT state_name FROM auxiliary.us_state WHERE state_code = auxiliary.parse_state_postalcode(NEW.postal_code)),
        sales_territory = (SELECT territory_name FROM auxiliary.sales_territory WHERE us_state_code = auxiliary.parse_state_postalcode(NEW.postal_code)),
        geographic_region = (SELECT region FROM auxiliary.us_state WHERE state_code = auxiliary.parse_state_postalcode(NEW.postal_code)),
        country = NEW.country
    WHERE customer_id = NEW.id;
    RETURN NEW;
  END;
$$ LANGUAGE PLPGSQL;
CREATE OR REPLACE FUNCTION tt_analytics.sf_delete_customer () 
RETURNS TRIGGER AS
$$
  BEGIN
    DELETE FROM tt_analytics.dim_customer_location
    WHERE customer_id = OLD.id;
    RETURN OLD;
  END;
$$ LANGUAGE PLPGSQL;    

-- Triggers on the base tables

CREATE TRIGGER tr_insert_customer 
  AFTER INSERT
  ON customer.customer FOR EACH ROW EXECUTE FUNCTION tt_analytics.sf_insert_customer(); 
CREATE TRIGGER tr_update_customer 
  AFTER UPDATE
  ON customer.customer FOR EACH ROW EXECUTE FUNCTION tt_analytics.sf_update_customer(); 
CREATE TRIGGER tr_delete_customer 
  AFTER DELETE
  ON customer.customer FOR EACH ROW EXECUTE FUNCTION tt_analytics.sf_delete_customer();

-- enable the replica triggers
ALTER TABLE customer.customer ENABLE REPLICA TRIGGER tr_insert_customer;
ALTER TABLE customer.customer ENABLE REPLICA TRIGGER tr_update_customer;
ALTER TABLE customer.customer ENABLE REPLICA TRIGGER tr_delete_customer;


-- create the product dimension table   
DROP TABLE IF EXISTS tt_analytics.dim_product CASCADE;
CREATE TABLE tt_analytics.dim_product (
    product_variant_id INTEGER,
    attributes JSONB,
    current_price NUMERIC(10,2),
    size VARCHAR(20),
    color VARCHAR(20),
    label VARCHAR(100),
    category VARCHAR(100),
    brand VARCHAR(100),
    co_name VARCHAR(100),
    co_alpha3_code VARCHAR(3)
);

CREATE UNIQUE INDEX idx_dim_product ON tt_analytics.dim_product (product_variant_id);

-- create the triggers and functions to maintain the dim_product table
-- this will include triggers on 
    -- product_variant
    -- product_variant_price
    -- product (only needs update trigger as product cannot be deleted if there are variants)
    -- category (only needs update trigger as category cannot be deleted if there are variants)
    -- brand (only needs update trigger as brand cannot be deleted if there are variants)
    -- country_of_origin (only needs update trigger as coo cannot be deleted if there are variants)

-- create trigger and function for product_variant insert, update, and delete
CREATE OR REPLACE FUNCTION tt_analytics.sf_upsert_product_variant () 
RETURNS TRIGGER AS
$$
  BEGIN
    RAISE NOTICE 'sf_upsert_product_variant %', NEW.id;
    INSERT INTO tt_analytics.dim_product (
        product_variant_id, attributes, current_price, size, color, label, category, brand, co_name, co_alpha3_code)
    VALUES (
        NEW.id,
        NEW.attributes,
        (SELECT price FROM product.product_variant_price WHERE product_variant_id = NEW.id AND current = true),
        NEW.attributes->>'size',
        NEW.attributes->>'color',
        (SELECT p.label FROM product.product p 
            JOIN product.product_variant pv ON pv.product_id = p.id WHERE pv.id = NEW.id),
        (SELECT c.label FROM product.category c 
            JOIN product.product p ON p.category_id = c.id 
            JOIN product.product_variant pv ON pv.product_id = p.id WHERE pv.id = NEW.id),
        (SELECT b.label FROM product.brand b 
            JOIN product.product p ON p.brand_id = b.id 
            JOIN product.product_variant pv ON pv.product_id = p.id WHERE pv.id = NEW.id),
        (SELECT co.name FROM product.country_of_origin co 
            JOIN product.brand b ON co.brand_id = b.id 
            JOIN product.product p ON p.brand_id = b.id 
            JOIN product.product_variant pv ON pv.product_id = p.id WHERE pv.id = NEW.id),
        (SELECT co.alpha3_code FROM product.country_of_origin co 
            JOIN product.brand b ON co.brand_id = b.id 
            JOIN product.product p ON p.brand_id = b.id 
            JOIN product.product_variant pv ON pv.product_id = p.id WHERE pv.id = NEW.id)
    )
    ON CONFLICT (product_variant_id) DO UPDATE SET
        attributes = EXCLUDED.attributes,
        current_price = EXCLUDED.current_price,
        size = EXCLUDED.size,
        color = EXCLUDED.color,
        label = EXCLUDED.label,
        category = EXCLUDED.category,
        brand = EXCLUDED.brand,
        co_name = EXCLUDED.co_name,
        co_alpha3_code = EXCLUDED.co_alpha3_code;
    RETURN NEW;
  END;
$$ LANGUAGE PLPGSQL;

CREATE TRIGGER tr_upsert_product_variant 
  AFTER INSERT OR UPDATE
  ON product.product_variant FOR EACH ROW EXECUTE FUNCTION tt_analytics.sf_upsert_product_variant(); 
-- enable the replica trigger
ALTER TABLE product.product_variant ENABLE REPLICA TRIGGER tr_upsert_product_variant;

-- create tables and trigger for product_variant delete
CREATE OR REPLACE FUNCTION tt_analytics.sf_delete_product_variant () 
RETURNS TRIGGER AS
$$
  BEGIN
    DELETE FROM tt_analytics.dim_product
    WHERE product_variant_id = OLD.id;
    RETURN OLD;
  END;
$$ LANGUAGE PLPGSQL;
CREATE TRIGGER tr_delete_product_variant 
  AFTER DELETE
  ON product.product_variant FOR EACH ROW EXECUTE FUNCTION tt_analytics.sf_delete_product_variant(); 
-- enable the replica trigger
ALTER TABLE product.product_variant ENABLE REPLICA TRIGGER tr_delete_product_variant;



-- create the trigger and function to handle updates to product_variant_price to maintain current price
CREATE OR REPLACE FUNCTION tt_analytics.sf_update_product_variant_price () 
RETURNS TRIGGER AS
$$
  BEGIN
    IF NEW.current = true THEN
        UPDATE tt_analytics.dim_product
        SET current_price = NEW.price
        WHERE product_variant_id = NEW.product_variant_id;
    END IF;
    RETURN NEW;
  END;
$$ LANGUAGE PLPGSQL;
CREATE TRIGGER tr_update_product_variant_price 
  AFTER INSERT OR UPDATE
  ON product.product_variant_price FOR EACH ROW EXECUTE FUNCTION tt_analytics.sf_update_product_variant_price(); 
-- enable the replica trigger
ALTER TABLE product.product_variant_price ENABLE REPLICA TRIGGER tr_update_product_variant_price;

-- create the trigger and function to handle updates to product to maintain label, category, brand, co_name, co_alpha3_code
CREATE OR REPLACE FUNCTION tt_analytics.sf_update_product () 
RETURNS TRIGGER AS
$$
  BEGIN
    UPDATE tt_analytics.dim_product
    SET
        label = NEW.label,
        category = (SELECT c.label FROM product.category c WHERE c.id = NEW.category_id),
        brand = (SELECT b.label FROM product.brand b WHERE b.id = NEW.brand_id),
        co_name = (SELECT co.name FROM product.country_of_origin co 
                    JOIN product.brand b ON co.brand_id = b.id WHERE b.id = NEW.brand_id),
        co_alpha3_code = (SELECT co.alpha3_code FROM product.country_of_origin co 
                    JOIN product.brand b ON co.brand_id = b.id WHERE b.id = NEW.brand_id)
    WHERE product_variant_id IN (SELECT pv.id FROM product.product_variant pv WHERE pv.product_id = NEW.id);
    RETURN NEW;
  END;
$$ LANGUAGE PLPGSQL;
CREATE TRIGGER tr_update_product 
  AFTER UPDATE
  ON product.product FOR EACH ROW EXECUTE FUNCTION tt_analytics.sf_update_product(); 
-- enable the replica trigger
ALTER TABLE product.product ENABLE REPLICA TRIGGER tr_update_product;

-- create the triggers and functions to handle updates to the category table
CREATE OR REPLACE FUNCTION tt_analytics.sf_update_category () 
RETURNS TRIGGER AS
$$
  BEGIN
    UPDATE tt_analytics.dim_product
    SET category = NEW.label
    WHERE product_variant_id IN (SELECT pv.id FROM product.product_variant pv 
                                    JOIN product.product p ON pv.product_id = p.id WHERE p.category_id = NEW.id);
    RETURN NEW;
  END;
$$ LANGUAGE PLPGSQL;
CREATE TRIGGER tr_update_category 
  AFTER UPDATE
  ON product.category FOR EACH ROW EXECUTE FUNCTION tt_analytics.sf_update_category(); 
-- enable the replica trigger
ALTER TABLE product.category ENABLE REPLICA TRIGGER tr_update_category;

-- create the triggers and functions to handle updates to the brand table
CREATE OR REPLACE FUNCTION tt_analytics.sf_update_brand () 
RETURNS TRIGGER AS
$$
  BEGIN
    UPDATE tt_analytics.dim_product
    SET brand = NEW.label
    WHERE product_variant_id IN (SELECT pv.id FROM product.product_variant pv 
                                    JOIN product.product p ON pv.product_id = p.id WHERE p.brand_id = NEW.id);
    RETURN NEW;
  END;
$$ LANGUAGE PLPGSQL;
CREATE TRIGGER tr_update_brand 
  AFTER UPDATE
  ON product.brand FOR EACH ROW EXECUTE FUNCTION tt_analytics.sf_update_brand(); 
-- enable the replica trigger
ALTER TABLE product.brand ENABLE REPLICA TRIGGER tr_update_brand;

-- create the triggers and functions to handle updates to the country_of_origin table
CREATE OR REPLACE FUNCTION tt_analytics.sf_update_country_of_origin () 
RETURNS TRIGGER AS
$$
  BEGIN
    UPDATE tt_analytics.dim_product
    SET
        co_name = NEW.name,
        co_alpha3_code = NEW.alpha3_code
    WHERE product_variant_id IN (SELECT pv.id FROM product.product_variant pv 
                                    JOIN product.product p ON pv.product_id = p.id 
                                    JOIN product.brand b ON p.brand_id = b.id WHERE b.id = NEW.brand_id);
    RETURN NEW;
  END;
$$ LANGUAGE PLPGSQL;
CREATE TRIGGER tr_update_country_of_origin 
  AFTER UPDATE
  ON product.country_of_origin FOR EACH ROW EXECUTE FUNCTION tt_analytics.sf_update_country_of_origin(); 
-- enable the replica trigger
ALTER TABLE product.country_of_origin ENABLE REPLICA TRIGGER tr_update_country_of_origin;




-- create the sales fact table   
DROP TABLE IF EXISTS tt_analytics.fact_sales CASCADE;
CREATE TABLE tt_analytics.fact_sales (
    sales_transaction_line_id UUID,
    date DATE,
    product_variant_id INTEGER,
    customer_id UUID,
    quantity INTEGER,
    unit_price NUMERIC(10,2),
    sales_amount NUMERIC(12,2)
);

-- create an index on sales_transaction_line_id for faster joins
CREATE UNIQUE INDEX idx_fact_sales ON tt_analytics.fact_sales (sales_transaction_line_id);

-- indexes on foreign keys for faster joins
CREATE INDEX idx_fact_sales_date ON tt_analytics.fact_sales (date);
CREATE INDEX idx_fact_sales_product_variant ON tt_analytics.fact_sales (product_variant_id);
CREATE INDEX idx_fact_sales_customer ON tt_analytics.fact_sales (customer_id);

-- create the triggers and functions to maintain the fact_sales table
CREATE OR REPLACE FUNCTION tt_analytics.sf_insert_sales_transaction_line () 
RETURNS TRIGGER AS
$$
  BEGIN
    INSERT INTO tt_analytics.fact_sales (
        sales_transaction_line_id, date, product_variant_id, customer_id, quantity, unit_price, sales_amount)
    VALUES (
        NEW.id,
        (SELECT transaction_date FROM sales.sales_transaction WHERE id = NEW.sales_transaction_id),
        NEW.product_variant_id,
        (SELECT customer_id FROM sales.sales_transaction WHERE id = NEW.sales_transaction_id),
        NEW.qty,
        NEW.price_at_sale,
        (NEW.qty * NEW.price_at_sale)
    );
    RETURN NEW;
  END;
$$ LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION tt_analytics.sf_update_sales_transaction_line () 
RETURNS TRIGGER AS
$$
  BEGIN
    UPDATE tt_analytics.fact_sales
    SET
        date = (SELECT transaction_date FROM sales.sales_transaction WHERE id = NEW.sales_transaction_id),
        product_variant_id = NEW.product_variant_id,
        customer_id = (SELECT customer_id FROM sales.sales_transaction WHERE id = NEW.sales_transaction_id),
        quantity = NEW.qty,
        unit_price = NEW.price_at_sale,
        sales_amount = (NEW.qty * NEW.price_at_sale)
    WHERE sales_transaction_line_id = NEW.id;
    RETURN NEW;
  END;
$$ LANGUAGE PLPGSQL;
CREATE OR REPLACE FUNCTION tt_analytics.sf_delete_sales_transaction_line () 
RETURNS TRIGGER AS
$$
  BEGIN
    DELETE FROM tt_analytics.fact_sales
    WHERE sales_transaction_line_id = OLD.id;
    RETURN OLD;
  END;
$$ LANGUAGE PLPGSQL;    
CREATE TRIGGER tr_insert_sales_transaction_line 
  AFTER INSERT
  ON sales.sales_transaction_line FOR EACH ROW EXECUTE FUNCTION tt_analytics.sf_insert_sales_transaction_line(); 

CREATE TRIGGER tr_update_sales_transaction_line 
  AFTER UPDATE
  ON sales.sales_transaction_line FOR EACH ROW EXECUTE FUNCTION tt_analytics.sf_update_sales_transaction_line(); 
CREATE TRIGGER tr_delete_sales_transaction_line 
  AFTER DELETE
  ON sales.sales_transaction_line FOR EACH ROW EXECUTE FUNCTION tt_analytics.sf_delete_sales_transaction_line();
-- enable the replica triggers
ALTER TABLE sales.sales_transaction_line ENABLE REPLICA TRIGGER tr_insert_sales_transaction_line;
ALTER TABLE sales.sales_transaction_line ENABLE REPLICA TRIGGER tr_update_sales_transaction_line;
ALTER TABLE sales.sales_transaction_line ENABLE REPLICA TRIGGER tr_delete_sales_transaction_line;