/*
-- =================================================================
--  PSQL SCRIPT to DEFINE THE ECOMMERCE API SCHEMA
-- =================================================================
--  OWNER: Superuser
--  PURPOSE: Creates the api functions and views to be used in both
--           the east and west ecommerce databases
-- =================================================================

*/

/*
    customer API
    * api.manage_customer
    * api.vw_customer
*/

CREATE OR REPLACE FUNCTION api.manage_customer (
    p_operation_type TEXT,
    p_id UUID DEFAULT NULL,
    p_first_name VARCHAR(50) DEFAULT NULL,
    p_last_name VARCHAR(50) DEFAULT NULL,
    p_phone_numbers JSONB DEFAULT NULL,
    p_street_address VARCHAR(100) DEFAULT NULL,
    p_city VARCHAR(100) DEFAULT NULL,
    p_postal_code VARCHAR (20) DEFAULT NULL,
    p_country VARCHAR(50) DEFAULT NULL
)
RETURNS TABLE (
    operation_type TEXT,
    old_value JSONB,
    new_value JSONB
)
AS $$
DECLARE
    v_old_row JSONB;
    v_new_row JSONB;
    v_inserted_id JSONB;
BEGIN
    IF p_operation_type = 'INSERT' THEN
        INSERT INTO customer (first_name, last_name, phone_numbers, street_address, city, postal_code, country)
            VALUES (p_first_name, p_last_name, p_phone_numbers, p_street_address, p_city, p_postal_code, p_country)
            RETURNING to_jsonb(NEW) INTO v_new_row;
        RETURN QUERY SELECT 
            'INSERT'::TEXT AS operation_type,
            NULL::JSONB AS old_value, --- there is no old value
            v_new_row AS new_value;

    ELSEIF p_operation_type = 'UPDATE' THEN
        UPDATE customer 
            SET
                first_name = p_first_name,
                last_name = p_last_name,
                phone_numbers = p_phone_numbers,
                street_address = p_street_address,
                city = p_city,
                postal_code = p_postal_code,
                country = p_country
            WHERE id = p_id
            RETURNING to_jsonb (OLD), to_jsonb (NEW) INTO v_old_row, v_new_row;
        -- If no row was updated (p_id not found), return nothing
        IF NOT FOUND THEN
            RETURN;
        END IF;
        -- Return the old and new values as part of a table record
        RETURN QUERY SELECT 
            'UPDATE'::TEXT AS operation_type,
            v_old_row AS old_value,
            v_new_row AS new_value;

    ELSEIF p_operation_type = 'DELETE' THEN
        DELETE FROM customer 
            WHERE id = p_id
            RETURNING to_jsonb (OLD) INTO v_old_row;
             -- If no row was deleted (p_id not found), return nothing
            IF NOT FOUND THEN
                RETURN;
            END IF;      
        RETURN QUERY SELECT 
            'DELETE'::TEXT AS operation_type,
            v_old_row AS old_value,
            NULL::JSONB AS new_value;

    ELSE
        RAISE EXCEPTION 'Invalid operation type: %', p_operation_type;
    END IF;
END;
$$ LANGUAGE PLPGSQL;

CREATE OR REPLACE VIEW api.vw_customer AS
    SELECT id, first_name, last_name, phone_numbers, street_address, city, postal_code, country
        FROM customer;

--------------------------------------------------------------------------------
/*
    inventory API
    * api.manage_product_variant_inventory
    * api.vw_product_variant_inventory
*/


CREATE OR REPLACE FUNCTION api.manage_product_variant_inventory (
    p_operation_type TEXT,
    p_product_variant_id INTEGER DEFAULT NULL,
    p_qty INTEGER DEFAULT NULL
)
RETURNS TABLE (
    operation_type TEXT,
    old_value JSONB,
    new_value JSONB
)
AS $$
DECLARE
    v_old_row JSONB;
    v_new_row JSONB;
    v_inserted_id JSONB;
BEGIN
    IF p_operation_type = 'INSERT' THEN
        INSERT INTO product_variant_inventory (product_variant_id, qty)
            VALUES (p_product_variant_id, p_qty)
            RETURNING to_jsonb(NEW) INTO v_new_row;
        RETURN QUERY SELECT 
            'INSERT'::TEXT AS operation_type,
            NULL::JSONB AS old_value, --- there is no old value
            v_new_row AS new_value;

    ELSEIF p_operation_type = 'UPDATE' THEN
        UPDATE product_variant_inventory 
            SET
                qty = p_qty
            WHERE product_variant_id = p_product_variant_id
            RETURNING to_jsonb (OLD), to_jsonb (NEW) INTO v_old_row, v_new_row;
        -- If no row was updated (p_id not found), return nothing
        IF NOT FOUND THEN
            RETURN;
        END IF;
        -- Return the old and new values as part of a table record
        RETURN QUERY SELECT 
            'UPDATE'::TEXT AS operation_type,
            v_old_row AS old_value,
            v_new_row AS new_value;

    ELSEIF p_operation_type = 'DELETE' THEN
        DELETE FROM product_variant_inventory 
            WHERE product_variant_id = p_product_variant_id
            RETURNING to_jsonb (OLD) INTO v_old_row;
             -- If no row was deleted (p_id not found), return nothing
            IF NOT FOUND THEN
                RETURN;
            END IF;      
        RETURN QUERY SELECT 
            'DELETE'::TEXT AS operation_type,
            v_old_row AS old_value,
            NULL::JSONB AS new_value;

    ELSE
        RAISE EXCEPTION 'Invalid operation type: %', p_operation_type;
    END IF;
END;
$$ LANGUAGE PLPGSQL;

CREATE OR REPLACE VIEW api.vw_product_variant_inventory AS
    SELECT product_variant_id, qty FROM product_variant_inventory;

--------------------------------------------------------------------------------
/*
    sales_transaction API
    * api.manage_sales_transaction
    * api.vw_sales_transaction_line
*/


CREATE OR REPLACE FUNCTION api.manage_sales_transaction (
    p_operation_type TEXT,
    p_id TEXT DEFAULT NULL,
    p_transaction_date DATE DEFAULT NULL,
    p_customer_id UUID DEFAULT NULL
)
RETURNS TABLE (
    operation_type TEXT,
    old_value JSONB,
    new_value JSONB
)
AS $$
DECLARE
    v_old_row JSONB;
    v_new_row JSONB;
    v_inserted_id JSONB;
BEGIN
    IF p_operation_type = 'INSERT' THEN
        INSERT INTO sales_transaction (transaction_date, customer_id)
            VALUES (p_transaction_date, p_customer_id)
            RETURNING to_jsonb(NEW) INTO v_new_row;
        RETURN QUERY SELECT 
            'INSERT'::TEXT AS operation_type,
            NULL::JSONB AS old_value, --- there is no old value
            v_new_row AS new_value;

    ELSEIF p_operation_type = 'UPDATE' THEN
        UPDATE sales_transaction 
            SET
                transaction_date = p_transaction_date,
                customer_id = p_customer_id
            WHERE id = p_id
            RETURNING to_jsonb (OLD), to_jsonb (NEW) INTO v_old_row, v_new_row;
        -- If no row was updated (p_id not found), return nothing
        IF NOT FOUND THEN
            RETURN;
        END IF;
        -- Return the old and new values as part of a table record
        RETURN QUERY SELECT 
            'UPDATE'::TEXT AS operation_type,
            v_old_row AS old_value,
            v_new_row AS new_value;

    ELSEIF p_operation_type = 'DELETE' THEN
        DELETE FROM sales_transaction 
            WHERE id = p_id
            RETURNING to_jsonb (OLD) INTO v_old_row;
             -- If no row was deleted (p_id not found), return nothing
            IF NOT FOUND THEN
                RETURN;
            END IF;      
        RETURN QUERY SELECT 
            'DELETE'::TEXT AS operation_type,
            v_old_row AS old_value,
            NULL::JSONB AS new_value;

    ELSE
        RAISE EXCEPTION 'Invalid operation type: %', p_operation_type;
    END IF;
END;
$$ LANGUAGE PLPGSQL;

CREATE OR REPLACE VIEW api.vw_sales_transaction AS
    SELECT id, transaction_date, customer_id FROM sales_transaction;    

--------------------------------------------------------------------------------
/*
    sales_transaction_line API
    * api.manage_sales_transaction_line
    * api.vw_sales_transaction_line
*/


CREATE OR REPLACE FUNCTION api.manage_sales_transaction_line (
    p_operation_type TEXT,
    p_id TEXT DEFAULT NULL,
    p_sales_transaction_id TEXT DEFAULT NULL,
    p_product_variant_id INTEGER DEFAULT NULL,
    p_qty INTEGER DEFAULT NULL,
    p_price_at_sale NUMERIC DEFAULT NULL
)
RETURNS TABLE (
    operation_type TEXT,
    old_value JSONB,
    new_value JSONB
)
AS $$
DECLARE
    v_old_row JSONB;
    v_new_row JSONB;
    v_inserted_id JSONB;
BEGIN
    IF p_operation_type = 'INSERT' THEN
        INSERT INTO sales_transaction_line (sales_transaction_id, product_variant_id, qty, price_at_sale)
            VALUES (p_sales_transaction_id, p_product_variant_id,p_qty, p_price_at_sale)
            RETURNING to_jsonb(NEW) INTO v_new_row;
        RETURN QUERY SELECT 
            'INSERT'::TEXT AS operation_type,
            NULL::JSONB AS old_value, --- there is no old value
            v_new_row AS new_value;

    ELSEIF p_operation_type = 'UPDATE' THEN
        UPDATE sales_transaction_line 
            SET
                sales_transaction_id = p_sales_transaction_id,
                product_variant_id = p_product_variant_id,
                qty = p_qty,
                price_at_sale = p_price_at_sale
            WHERE id = p_id
            RETURNING to_jsonb (OLD), to_jsonb (NEW) INTO v_old_row, v_new_row;
        -- If no row was updated (p_id not found), return nothing
        IF NOT FOUND THEN
            RETURN;
        END IF;
        -- Return the old and new values as part of a table record
        RETURN QUERY SELECT 
            'UPDATE'::TEXT AS operation_type,
            v_old_row AS old_value,
            v_new_row AS new_value;

    ELSEIF p_operation_type = 'DELETE' THEN
        DELETE FROM sales_transaction_line
            WHERE id = p_id
            RETURNING to_jsonb (OLD) INTO v_old_row;
             -- If no row was deleted (p_id not found), return nothing
            IF NOT FOUND THEN
                RETURN;
            END IF;      
        RETURN QUERY SELECT 
            'DELETE'::TEXT AS operation_type,
            v_old_row AS old_value,
            NULL::JSONB AS new_value;

    ELSE
        RAISE EXCEPTION 'Invalid operation type: %', p_operation_type;
    END IF;
END;
$$ LANGUAGE PLPGSQL;

CREATE OR REPLACE VIEW api.vw_sales_transaction_line AS
    SELECT id, sales_transaction_id, product_variant_id, qty, price_at_sale FROM sales_transaction_line;     


--- procedure to create a sales transaction with lines and adjust inventory

CREATE OR REPLACE PROCEDURE api.execute_sales_transaction(
    p_customer_id UUID, 
    p_transaction_date DATE, IN 
    p_array_product_variant_ids INT[], 
    IN p_array_qtys INT[],
    p_adjust_inventory BOOLEAN DEFAULT TRUE)
AS
$$
-- check that the arrays are the same length
-- create sales transaction for the customer and timestamp
-- iterate through the arrays of product_variant_ids and qtys to create sales transaction lines
-- if p_adjust_inventory is true, adjust the inventory for each product variant
DECLARE
    v_sales_transaction_id UUID; -- the new sales transaction id
    i INT; -- loop counter for the arrays
    v_product_variant_price NUMERIC; -- price of the product variant
    v_qty_on_hand INT; -- quantity on hand for the product variant
    v_qty_adjustment INT; -- quantity adjustment for the inventory
    v_product_variant_id INT; -- product variant id from the array
    
BEGIN
    IF array_length(p_array_product_variant_ids, 1) IS DISTINCT FROM array_length(p_array_qtys, 1) THEN
        RAISE EXCEPTION 'Arrays for product variant IDs and quantities arrays must be of the same length, cancelling transaction';
    END IF;
    
    INSERT INTO sales_transaction (customer_id, transaction_date)
    VALUES (p_customer_id, p_transaction_date)
    RETURNING id INTO v_sales_transaction_id;
    RAISE DEBUG 'Created sales transaction with id %s for customer id %', v_sales_transaction_id, p_customer_id; 
    FOR i IN 1..array_length(p_array_product_variant_ids, 1) LOOP
        -- get the price for the product variant
        SELECT price INTO v_product_variant_price FROM product_variant_price 
        WHERE product_variant_id = p_array_product_variant_ids[i]
        AND current = true 
        LIMIT 1;
        IF v_product_variant_price IS NULL THEN
            RAISE EXCEPTION 'No current price found for product_variant_id %, cancelling transaction', p_array_product_variant_ids[i];
        END IF;
        INSERT INTO sales_transaction_line (sales_transaction_id, product_variant_id, price_at_sale, qty)
        VALUES (
            v_sales_transaction_id, 
            p_array_product_variant_ids[i], 
            v_product_variant_price,
            p_array_qtys[i]
        );
        RAISE DEBUG 'Added line: product_variant_id %, qty %', p_array_product_variant_ids[i], p_array_qtys[i];
        IF p_adjust_inventory THEN
        -- adjust product_variant_inventory
            --- put these values into procedure-level variables for clarity in error message
            v_product_variant_id := p_array_product_variant_ids[i];
            v_qty_adjustment := p_array_qtys[i];
            SELECT qty INTO v_qty_on_hand FROM product_variant_inventory
                WHERE product_variant_id = v_product_variant_id;
            UPDATE product_variant_inventory
            SET qty = qty - p_array_qtys[i]
            WHERE product_variant_id = p_array_product_variant_ids[i];
            RAISE DEBUG 'Updated inventory for product_variant_id %', p_array_product_variant_ids[i];
        END IF;
    END LOOP;
    -- error handling could be added to manage inventory issues, etc.
    EXCEPTION
        WHEN check_violation THEN
            RAISE WARNING 'Check constraint violation occurred when adjusting inventory for variant % from % by %.', v_product_variant_id, v_qty_on_hand, v_qty_adjustment;
            RAISE WARNING ' %s, cancelling transaction', SQLERRM;
            RAISE DEBUG 'Rolling back transaction with ID %', v_sales_transaction_id;
        WHEN OTHERS THEN
            RAISE WARNING 'Error occurred: %', SQLERRM;
END;  
$$ LANGUAGE plpgsql; 

--- view for sales by customer

CREATE OR REPLACE VIEW api.sales_by_customer AS
    SELECT
        c.id as customer_id, c.first_name as customer_first_name, c.last_name as customer_last_name,
        st.id as sales_transaction_id, st.transaction_date as sales_transaction_date,
        stl.id as sales_transaction_line_id, stl.qty as sales_transaction_qty, stl.price_at_sale as sales_transaction_line_price_at_sale,
        p.id as product_id, p.label as product_label, p.shortdescription as product_short_description
        FROM customer c
        JOIN sales_transaction st ON st.customer_id = c.id 
        JOIN sales_transaction_line stl ON stl.sales_transaction_id = st.id 
        JOIN product_variant pv ON pv.id = stl.product_variant_id
        JOIN product p ON pv.product_id = p.id;

-- views for brand, category, product_variant, product_variant_price

CREATE OR REPLACE VIEW api.vw_catgory AS
    SELECT id, label, description FROM category;

CREATE OR REPLACE VIEW api.vw_brand AS
    SELECT id, label, description FROM brand;

CREATE OR REPLACE VIEW api.vw_product AS
    SELECT id, category_id, brand_id, label, shortdescription, longdescription, image_filename FROM product;

CREATE OR REPLACE VIEW api.vw_product_variant AS
    SELECT id, product_id, attributes FROM product_variant;

CREATE OR REPLACE VIEW api.vw_product_variant_price AS
    SELECT id, product_variant_id, price, validity, current FROM product_variant_price;    

