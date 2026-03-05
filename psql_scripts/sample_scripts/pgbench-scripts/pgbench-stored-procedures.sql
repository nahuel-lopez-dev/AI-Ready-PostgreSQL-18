/*
-- =================================================================================
Procedures being called by pgbench scripts to
1) randomly increase inventory of a random product variant by 1-10 units
2) generate a random sales transaction for a random customer on a random date with 1-5 lines of random product variants and quantities
3) randomly delete a sales transaction line and adjust inventory accordingly

The procedures are created in the east_ecommerce_data database as part of the master_setup.sql script.
-- =================================================================================
*/

\c east_ecommerce_data

CREATE OR REPLACE PROCEDURE random_inventory_increase()
LANGUAGE plpgsql
AS $$
DECLARE
    v_product_variant_id INT;
    v_increase_amount INT;
BEGIN
    -- Step 1: Randomly select a product_variant_id
    SELECT id INTO v_product_variant_id
    FROM product_variant
    ORDER BY RANDOM()
    LIMIT 1;    
    -- Step 2: Randomly determine an increase amount between 1 and 10
    v_increase_amount := FLOOR(RANDOM() * 10) + 1;
    -- Step 3: Update the inventory for the selected product_variant_id
    UPDATE product_variant_inventory
    SET qty = qty + v_increase_amount
    WHERE product_variant_id = v_product_variant_id;
    RAISE DEBUG 'Increased inventory of product_variant_id % by % units', v_product_variant_id, v_increase_amount;
END;
$$;



CREATE OR REPLACE PROCEDURE generate_random_sales_transaction (IN p_adjust_inventory BOOLEAN DEFAULT TRUE)
AS
$$
DECLARE 
    v_customer_id UUID;
    v_transaction_date DATE;
    v_product_variant_ids INT[];
    v_qtys INT[];
    v_num_lines INT;
    v_product_variant_id INT;
    v_qty INT;
    i INT;
BEGIN
    -- select a random customer
    SELECT id INTO v_customer_id FROM customer ORDER BY RANDOM() LIMIT 1;
    -- select a random date within the last 18 months
    v_transaction_date := CURRENT_DATE - TRUNC(RANDOM() * 540)::INTEGER;
    -- determine a random number of lines between 1 and 5
    v_num_lines := FLOOR(RANDOM() * 5) + 1;
    v_product_variant_ids := ARRAY[]::INT[];
    v_qtys := ARRAY[]::INT[];
    FOR i IN 1..v_num_lines LOOP
        -- select a random product variant
        SELECT id INTO v_product_variant_id FROM product_variant ORDER BY RANDOM() LIMIT 1;
        -- select a random quantity between 1 and 5
        v_qty := FLOOR(RANDOM() * 5) + 1;
        v_product_variant_ids := array_append(v_product_variant_ids, v_product_variant_id);
        v_qtys := array_append(v_qtys, v_qty);
    END LOOP;
    -- call the execute_sales_transaction procedure
    CALL api.execute_sales_transaction(v_customer_id, v_transaction_date, v_product_variant_ids, v_qtys, p_adjust_inventory);
END;
$$ LANGUAGE plpgsql;


-- randomly delete a sales transaction line and adjust inventory accordingly
CREATE OR REPLACE PROCEDURE delete_random_sales_transaction_line()
LANGUAGE plpgsql
AS $$
DECLARE
    v_line_id UUID;
    v_sales_transaction_id UUID;
    v_product_variant_id INT;
    v_qty INT;
BEGIN
    -- Step 1: Randomly select a sales_transaction_line id
    SELECT stl.sales_transaction_id, stl.id, stl.product_variant_id, stl.qty INTO v_sales_transaction_id, v_line_id, v_product_variant_id, v_qty
    FROM sales_transaction_line stl
    ORDER BY RANDOM()
    LIMIT 1;    
    -- Step 2: Delete the selected sales_transaction_line
    DELETE FROM sales_transaction_line WHERE id = v_line_id;
    -- Step 3: Adjust the inventory for the associated product_variant_id
    UPDATE product_variant_inventory
    SET qty = qty + v_qty
    WHERE product_variant_id = v_product_variant_id;
    RAISE DEBUG 'Deleted sales_transaction_line id %, increased inventory of product_variant_id % by % units', v_line_id, v_product_variant_id, v_qty;
    -- delete the sales transaction if it has no more lines
    IF NOT EXISTS (SELECT 1 FROM sales_transaction_line WHERE sales_transaction_id = v_sales_transaction_id) THEN
        DELETE FROM sales_transaction WHERE id = v_sales_transaction_id;
        RAISE DEBUG 'Deleted sales_transaction id % as it had no more lines', v_sales_transaction_id;
    END IF;
END;
$$;