/* 


this generate the sales transactions with a skew that shows (a) that polos tend to be bought with sports coats and suit coats
and (b) blue jeans and T-shirts are bought together

Run it seperately against east and west to create both data sets

*/


/*
Generate the sales transaction data
Approach:
1) Iterate through 75% of the customers
    - Create a random set of sales transactions (between 1 and 10) spread over three years, using random products

2) Pick 25% of the customers at random
    - Create an order for 1-2 (random) polos and 1 sports coat

3) Pick 40% of the customers at random
    - Create 2 orders for 1-2 (random) T-shirts and 1 blue jeans    
*/

CREATE SCHEMA IF NOT EXISTS data_generation;

CREATE OR REPLACE PROCEDURE data_generation.generate_random_sales_transaction_data ()
AS
$$
DECLARE
    customer_record RECORD;
    customer_count INTEGER;
    random_date DATE;
    sales_transaction_id UUID;
    sales_transaction_lines INTEGER;
    p_product_variant_id INTEGER;
    p_product_variant_price NUMERIC;
BEGIN
    SELECT COUNT(*) INTO customer_count FROM customer;
    --- create random orders for 75% of customers, spread over the last 18 months
    FOR customer_record IN SELECT id FROM customer ORDER BY RANDOM() LIMIT customer_count*0.75
        LOOP
            --- select random date within last 24 months
            random_date := current_date - TRUNC(RANDOM() * 365)::INTEGER;

            INSERT INTO sales_transaction (transaction_date, customer_id)
                VALUES (random_date, customer_record.id)
                RETURNING id INTO sales_transaction_id;
            --- add between 1 and 4 product_variants to the order    
            sales_transaction_lines:= TRUNC(RANDOM() * 3) +1;
            FOR i IN 1.. sales_transaction_lines LOOP
                --- select a random product variant with its price
                SELECT 
                    pv.id, pvp.price INTO p_product_variant_id, p_product_variant_price
                    FROM product_variant pv, product_variant_price pvp
                    WHERE pv.id = pvp.product_variant_id
                    ORDER BY RANDOM() LIMIT 1;
                --- create a sales transaction line    
                INSERT INTO sales_transaction_line (sales_transaction_id, product_variant_id, price_at_sale, qty)
                    VALUES (sales_transaction_id, p_product_variant_id, p_product_variant_price, 1);
            END LOOP;
        END LOOP;
END;
$$ LANGUAGE plpgsql;

-- call data_generation.generate_random_sales_transaction_data ();


CREATE OR REPLACE PROCEDURE data_generation.generate_tshirt_jeans_sales_transaction_data (ratio NUMERIC DEFAULT 0.25)
AS
$$
DECLARE
    customer_record RECORD;
    customer_count INTEGER;
    random_date DATE;
    sales_transaction_id UUID;
    p_product_variant_id INTEGER;
    p_product_variant_price NUMERIC;
BEGIN
SELECT COUNT(*) INTO customer_count FROM customer;
    --- create t-shirt and jeans orders for subset of customers, spread over the last 18 months
    FOR customer_record IN SELECT id FROM customer ORDER BY RANDOM() LIMIT customer_count*ratio
        LOOP
            --- select random date within last 24 months
            random_date := current_date - TRUNC(RANDOM() * 365)::INTEGER;
            INSERT INTO sales_transaction (transaction_date, customer_id)
                VALUES (random_date, customer_record.id)
                RETURNING id INTO sales_transaction_id;
            --- select product  and price for t-shirts
            SELECT 
                pv.id, pvp.price INTO p_product_variant_id, p_product_variant_price
                FROM product p, product_variant pv, product_variant_price pvp
                WHERE p.id = pv.product_id 
                    AND pv.id = pvp.product_variant_id
                    AND p.label ilike '%t-shirt%'
                ORDER BY RANDOM() LIMIT 1;
                INSERT INTO sales_transaction_line (sales_transaction_id, product_variant_id, price_at_sale, qty)
                    VALUES (sales_transaction_id, p_product_variant_id, p_product_variant_price, 1);
            --- select product variant and price for jeans
            SELECT 
                pv.id, pvp.price INTO p_product_variant_id, p_product_variant_price
                FROM product p, product_variant pv, product_variant_price pvp
                WHERE p.id = pv.product_id 
                    AND pv.id = pvp.product_variant_id
                    AND p.label ilike '%jeans%'
                ORDER BY RANDOM() LIMIT 1;    
                INSERT INTO sales_transaction_line (sales_transaction_id, product_variant_id, price_at_sale, qty)
                    VALUES (sales_transaction_id, p_product_variant_id, p_product_variant_price, 1);      
        END LOOP;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE data_generation.generate_polo_sports_coat_sales_transaction_data (ratio NUMERIC DEFAULT 0.25)
AS
$$
DECLARE
    customer_record RECORD;
    customer_count INTEGER;
    random_date DATE;
    sales_transaction_id UUID;
    p_product_variant_id INTEGER;
    p_product_variant_price NUMERIC;
BEGIN
SELECT COUNT(*) INTO customer_count FROM customer;
    --- create polo and sports coat orders for subset of customers, spread over the last 18 months
    FOR customer_record IN SELECT id FROM customer ORDER BY RANDOM() LIMIT customer_count*ratio
        LOOP
            --- select random date within last 24 months
            random_date := current_date - TRUNC(RANDOM() * 365)::INTEGER;
            INSERT INTO sales_transaction (transaction_date, customer_id)
                VALUES (random_date, customer_record.id)
                RETURNING id INTO sales_transaction_id;
            --- select product  and price for polo
            SELECT 
                pv.id, pvp.price INTO p_product_variant_id, p_product_variant_price
                FROM product p, product_variant pv, product_variant_price pvp
                WHERE p.id = pv.product_id 
                    AND pv.id = pvp.product_variant_id
                    AND p.label ilike '%polo%'
                ORDER BY RANDOM() LIMIT 1;
                INSERT INTO sales_transaction_line (sales_transaction_id, product_variant_id, price_at_sale, qty)
                    VALUES (sales_transaction_id, p_product_variant_id, p_product_variant_price, 1);
            --- select product variant and price for jeans
            SELECT 
                pv.id, pvp.price INTO p_product_variant_id, p_product_variant_price
                FROM product p, product_variant pv, product_variant_price pvp
                WHERE p.id = pv.product_id 
                    AND pv.id = pvp.product_variant_id
                    AND p.label ilike '%sports coat%'
                ORDER BY RANDOM() LIMIT 1;    
                INSERT INTO sales_transaction_line (sales_transaction_id, product_variant_id, price_at_sale, qty)
                    VALUES (sales_transaction_id, p_product_variant_id, p_product_variant_price, 1);       
        END LOOP;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE data_generation.generate_sales_transaction_data ()
AS
$$
    DECLARE counter INTEGER;
    BEGIN
        RAISE DEBUG 'Creating base random transactions';
        CALL data_generation.generate_random_sales_transaction_data ();
        CALL data_generation.generate_random_sales_transaction_data ();
        SELECT COUNT(*) INTO counter FROM sales_transaction;
        RAISE DEBUG 'Created % base random transactions', counter;
        RAISE DEBUG 'Creating t-shirt jeans  transactions';
        CALL data_generation.generate_tshirt_jeans_sales_transaction_data (.60);
        RAISE DEBUG 'Creating polo sports coats  transactions';
        CALL data_generation.generate_polo_sports_coat_sales_transaction_data (.25);
        SELECT COUNT(*) INTO counter FROM sales_transaction;
        RAISE DEBUG 'Generated % sales transactions', counter;
    END;
$$ LANGUAGE PLPGSQL;

call data_generation.generate_sales_transaction_data();
