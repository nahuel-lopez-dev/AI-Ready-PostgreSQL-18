/* ============================================================================

                        Code samples for Chapter 6

============================================================================ */ 



/*

Section PL/pgSQL: Control Structures

*/

DO 
$$
DECLARE x INTEGER := 4;
BEGIN
    IF x = 1 OR x = 2 THEN 
        RAISE NOTICE 'The value is either 1 or 2';
    ELSEIF x = 3 THEN
        RAISE NOTICE 'The value is 3';
    ELSE
        RAISE NOTICE 'The value is neither 1, 2, or 3';
    END IF;
END
$$;

-- Simple CASE

DO 
$$
DECLARE x INTEGER := 4;
BEGIN
    CASE x
        WHEN 1, 2 THEN 
            RAISE NOTICE 'The value is either 1 or 2';
        WHEN 3 THEN
            RAISE NOTICE 'The value is 3';
        ELSE 
            RAISE NOTICE 'The value is neither 1, 2, or 3';
    END CASE;
END
$$;

-- Searched CASE

DO 
$$
DECLARE x INTEGER := 4;
BEGIN
    CASE 
        WHEN x IN (1, 2) THEN 
            RAISE NOTICE 'The value is either 1 or 2';
        WHEN x = 3 THEN
            RAISE NOTICE 'The value is 3';
        ELSE 
            RAISE NOTICE 'The value is neither 1, 2, or 3';
    END CASE;
END
$$;

-- LOOP and EXIT

DO 
$$
DECLARE 
    v_max INTEGER := 4;
    v_ctr INTEGER :=1;
BEGIN
    LOOP
        RAISE NOTICE 'Iteration # %', v_ctr;
        IF v_ctr >= v_max THEN 
            EXIT; 
        ELSE 
            v_ctr := v_ctr +1;
        END IF;
    END LOOP;
END        
$$;

-- FOR .. LOOP
-- iterates over an integer range. 

DO 
$$
DECLARE 
    v_max INTEGER := 4;
BEGIN
    FOR v_ctr IN 1.. v_max LOOP
        RAISE NOTICE 'Iteration # %', v_ctr;
    END LOOP;
END        
$$;


-- FOR EACH ... LOOP
-- looping through a one-dimensional array 

DO 
$$
DECLARE 
    v_array INTEGER[]:= '{1,2,3,4}';
    v_i INTEGER;
BEGIN
    FOREACH v_i IN ARRAY v_array LOOP
        RAISE NOTICE 'Iteration # %', v_i;
    END LOOP;
END        
$$;

-- looping through a two-dimensional array 
DO 
$$
DECLARE 
    v_array INTEGER[][]:= '{{1,2},{2,3},{3,5},{4,7}}';
    v_i INTEGER[];
BEGIN
    FOREACH v_i SLICE 1 IN ARRAY v_array LOOP
        RAISE NOTICE 'Prime number # % = %', v_i[1], v_i[2];
    END LOOP;
END        
$$;

-- FOR ... IN SELECT ... LOOP
-- looping through the result set of a query

DO $$
DECLARE 
    v_product_variant_price_record RECORD;
    v_new_price NUMERIC;
    v_old_price NUMERIC;
BEGIN
    -- find all the current product prices that are close to the round number
    -- and adjust them to 0.99
    FOR v_product_variant_price_record 
        IN 
        (SELECT * FROM product_variant_price 
            WHERE 
                current = TRUE
            AND (price - TRUNC (price)) > .70)
        LOOP
            UPDATE product_variant_price 
                SET price = TRUNC (price) + 0.99
                WHERE product_variant_price.id = v_product_variant_price_record.id 
                -- use new PostgreSQL 18 capability to return old and new
                RETURNING NEW.price, OLD.price INTO v_new_price, v_old_price;
            RAISE NOTICE 'Changed price for id % from % to %', v_product_variant_price_record.id, v_old_price, v_new_price; 
        END LOOP;
END;
$$;

/*
 Section: Diagnostics to Understand the Most Recent Query

*/

DO $$
DECLARE
    v_call_stack TEXT;
    v_row_count INTEGER;
    v_OID OID;
BEGIN
    PERFORM  * FROM product;
    GET DIAGNOSTICS v_row_count = ROW_COUNT;
    GET DIAGNOSTICS v_OID = PG_ROUTINE_OID;
    GET DIAGNOSTICS v_call_stack = PG_CONTEXT;
    RAISE NOTICE 'Routine OID %', v_OID;
    RAISE NOTICE 'Call stack: %', v_call_stack;
    IF FOUND THEN 
        RAISE NOTICE 'Query successful. Found % rows', v_row_count;
    ELSE 
        RAISE NOTICE 'Nothing found';
    END IF;
END;
$$;


/* 

Section: Exception Handling and Stacked Diagnostics

*/

-- simple exception handler

DO $$
BEGIN
    -- this will fail as table constraint requires prices > 0
    UPDATE product_variant_price SET price = 0.99 WHERE id = 1;
    EXCEPTION WHEN OTHERS THEN   
        RAISE NOTICE 'Update failed';
END;
$$;

-- A more sophisticated handler with stacked diagnostics
DO $$
    DECLARE 
    v_RETURNED_SQLSTATE TEXT; 
    v_COLUMN_NAME TEXT; 
    v_MESSAGE_TEXT TEXT;
    v_CONSTRAINT_NAME TEXT; 
    v_TABLE_NAME TEXT;
BEGIN
    -- this will fail as table constraint requires prices > 0
    UPDATE product_variant_price SET price = '-0.99' WHERE id = 1;
    EXCEPTION 
        WHEN check_violation THEN
            RAISE NOTICE 'Violated check constraint; Details below';
            GET STACKED DIAGNOSTICS 
                v_RETURNED_SQLSTATE = RETURNED_SQLSTATE,
                v_COLUMN_NAME = COLUMN_NAME,
                v_CONSTRAINT_NAME = CONSTRAINT_NAME,
                v_MESSAGE_TEXT = MESSAGE_TEXT,
                v_TABLE_NAME = TABLE_NAME;
            RAISE NOTICE 'Detailed state % on column %', v_RETURNED_SQLSTATE, v_COLUMN_NAME;
            RAISE NOTICE 'CONSTRAINT_NAME %', v_CONSTRAINT_NAME;
            RAISE NOTICE 'MESSAGE_TEXT %',v_MESSAGE_TEXT;
            RAISE NOTICE 'TABLE_NAME %', v_TABLE_NAME;
END;
$$;

-- raising an exception explicitly

DO $$
BEGIN
    UPDATE product_variant_price SET price = 0.01 WHERE id =1;
    RAISE check_violation USING MESSAGE = 'Price too low';
END $$;    

-------------------------------------------------------------------------------

/*

Section: Triggers – Reacting to Data Changes and Events
*/

\c east_ecommerce_data

-- adding three additional columns to the inventory table
ALTER TABLE product_variant_inventory 
    ADD COLUMN last_update_timestamp TIMESTAMP,
    ADD COLUMN last_update_user TEXT,
    ADD COLUMN prior_value JSONB;

-- defining a before trigger for insert and update that tracks the changes

CREATE OR REPLACE FUNCTION tr_inventory_last_update() RETURNS TRIGGER 
AS
  $$
    BEGIN
        NEW.last_update_timestamp = NOW();
        NEW.last_update_user = CURRENT_USER;
        NEW.prior_value = TO_JSONB (OLD);
        RETURN NEW; -- returns the new row
    END
  $$ LANGUAGE PLPGSQL;

-- adding the trigger to the table as a BEFORE trigger for INSERT and UPDATE
CREATE OR REPLACE TRIGGER tr_track_last_update_inventory
    BEFORE INSERT OR UPDATE
    ON product_variant_inventory FOR EACH ROW EXECUTE FUNCTION tr_inventory_last_update(); 
  
-- testing the trigger with an insert
-- the inventory value from the original data set is 94
-- so this insert will show NULL in prior_value
UPDATE product_variant_inventory SET qty = 93 WHERE product_variant_id = 1;
UPDATE product_variant_inventory SET qty = 90 WHERE product_variant_id = 1;

SELECT 
    product_variant_id id, 
    qty, 
    DATE(last_update_timestamp) date, 
    last_update_user user, 
    JSONB_PRETTY (prior_value) AS prior_value
FROM product_variant_inventory WHERE product_variant_id = 1;


/*

Section: PL/pgSQL, Transactions and Subtransactions

*/


CREATE OR REPLACE FUNCTION sf_add_lines_to_sales_order (
    p_sales_transaction_id TEXT, -- sales transaction
    p_line_info NUMERIC[][][]) --- order lines with product, qty, and price
    RETURNS INTEGER[][] --- product and quantities that were committed successfully
AS
$$
DECLARE
    v_products_ordered INTEGER[][] := ARRAY[]::INTEGER[][]; -- result array of all successful lines
    v_i INTEGER;
    v_pv_id INTEGER;
    v_qty INTEGER;
    v_price NUMERIC;
BEGIN
    -- iterate through all the lines and commit the inventory
    FOR v_i IN 1.. ARRAY_LENGTH(p_line_info, 1) LOOP
            BEGIN -- start a new subtransaction for each line of the order
            v_pv_id := p_line_info[v_i][1];
            v_qty := p_line_info[v_i][2];
            v_price := p_line_info[v_i][3];
            -- add the sales transaction line
            INSERT INTO sales_transaction_line 
                (sales_transaction_id, product_variant_id, qty, price_at_sale)
                VALUES 
                (p_sales_transaction_id,v_pv_id,v_qty,v_price);
            -- commit the inventory
            UPDATE product_variant_inventory SET qty = qty - v_qty
                WHERE product_variant_id = v_pv_id;
            RAISE NOTICE 
                'Success with order % for % units. Sufficient inventory on hand',
                 v_pv_id, v_qty;
            -- add this successful line to the return result
            v_products_ordered := v_products_ordered || ARRAY[[v_pv_id, v_qty]];
            -- In case of an exception in this subtransaction, the latest line will be rolled back
            -- all other lines will be committed, unless there is another error that is not handled
            EXCEPTION -- handle exceptions that pertain to this line of the order
                WHEN check_violation THEN   
                    RAISE NOTICE 
                        'Failure with % for % units. Out of inventory', 
                        p_line_info[v_i][1], p_line_info[v_i][2];
            END;
    END LOOP;     
    RETURN v_products_ordered;
END $$ LANGUAGE PLPGSQL;    


-- Invoke the function defined above, after resetting the inventory level and the specific sales transaction
-- remove all other sales transaction lines from sales transaction to simplify output
DELETE FROM sales_transaction_line WHERE sales_transaction_id = 'east_5316';
-- reset the inventory to create the 'Out of inventory' condition
UPDATE product_variant_inventory set qty = 1 WHERE product_variant_id IN (1,7,8,18,19);

SELECT sf_add_lines_to_sales_order AS committed_lines 
    FROM sf_add_lines_to_sales_order(
        'east_5316', 
        '{{1,1,29.11}, {7,1,15}, {8,1, 32}, {18,3, 58}, {19,1, 5.23}}');

/*

Section: pg_background – Breaking Out of the Transaction Constraints

*/

\c east_ecommerce_data;

CREATE EXTENSION pg_background;

CREATE TABLE inventory_request (
    time TIMESTAMP, 
    product_variant_id INTEGER, 
    sales_transaction_id TEXT, 
    qty INTEGER);


CREATE OR REPLACE PROCEDURE record_inventory_request (
    p_product_variant_id INTEGER, 
    p_sales_transaction_id TEXT, 
    p_qty INTEGER)
AS
$$
BEGIN
    RAISE NOTICE 'Recording inventory request for product variant % with sales transaction % and qty %', 
        p_product_variant_id, p_sales_transaction_id, p_qty;
    INSERT INTO inventory_request 
        (time, product_variant_id,sales_transaction_id, qty)
    VALUES (CLOCK_TIMESTAMP(), p_product_variant_id,p_sales_transaction_id, p_qty);
END
$$ LANGUAGE PLPGSQL;


CREATE OR REPLACE FUNCTION sf_add_lines_to_sales_order (
    p_sales_transaction_id TEXT, -- sales transaction
    p_line_info NUMERIC[][][]) --- order lines with product, qty, and price
    RETURNS INTEGER[][] --- product and quantities that were committed successfully
AS
$$
DECLARE
    v_products_ordered INTEGER[][]; -- result array of all successful lines
    v_pv_id INTEGER;
    v_qty INTEGER;
    v_price NUMERIC;
    v_background_command TEXT; -- command to run in the background
    v_bg_worker_pid      INTEGER; -- Variable to hold the background worker's PID
    v_bg_result          TEXT; -- Variable to hold the result from the background worker
BEGIN
    -- iterate through all the lines and commit the inventory
    FOR v_i IN 1.. ARRAY_LENGTH(p_line_info, 1) LOOP
            BEGIN -- start a new subtransaction for each line of the order
            v_pv_id := p_line_info[v_i][1];
            v_qty := p_line_info[v_i][2];
            v_price := p_line_info[v_i][3];
            -- Use pg_background to record the inventory request in the background
            -- 1) Build the command string for the background worker
            v_background_command := format(
                'CALL record_inventory_request(%L, %L, %L)',
                v_pv_id, 
                p_sales_transaction_id, 
                v_qty
            );
            -- 2) Launch the worker and capture its PID
            v_bg_worker_pid := pg_background_launch(v_background_command);
            -- 3) Capture any results (including errors) and detach the background process 
            SELECT result INTO v_bg_result FROM pg_background_result(v_bg_worker_pid) AS (result TEXT);
            -- Print the result from the background worker
            RAISE DEBUG 'Background worker result: %', v_bg_result;
            -- 4) Now we can proceed with the main transaction
            -- 4.a) add the sales transaction line
            INSERT INTO sales_transaction_line 
                (sales_transaction_id, product_variant_id, qty, price_at_sale)
                VALUES 
                (p_sales_transaction_id,v_pv_id,v_qty,v_price);
            -- 4.b) commit the inventory
            UPDATE product_variant_inventory SET qty = qty - v_qty
                WHERE product_variant_id = v_pv_id;
            RAISE NOTICE 'Success with order % for % units. Sufficient inventory on hand',
                         v_pv_id, v_qty;
            -- add this successful line to the return result
            v_products_ordered := v_products_ordered || ARRAY[[v_pv_id, v_qty]];
            -- In case of an exception in this subtransaction, the latest line will be rolled back
            -- all other lines will be committed, unless there is another error that is not handled
            EXCEPTION -- handle exceptions that pertain to this line of the order
                WHEN check_violation THEN   
                    RAISE NOTICE 'Failure with % for % units. Out of inventory', 
                                v_pv_id, v_qty;
            END;
    END LOOP;     
    RETURN v_products_ordered;
END $$ LANGUAGE PLPGSQL;   

-- runing the sample procedure to record inventory requests

TRUNCATE inventory_request; 
-- Invoke the function defined above, after resetting the inventory level and the specific sales transaction
-- remove all other sales transaction lines from sales transaction to simplify output
DELETE FROM sales_transaction_line WHERE sales_transaction_id = 'east_5316';
-- reset the inventory to create the 'Out of inventory' condition
UPDATE product_variant_inventory set qty = 1 WHERE product_variant_id IN (1,7,8,18,19);

SELECT sf_add_lines_to_sales_order AS committed_lines 
    FROM sf_add_lines_to_sales_order(
        'east_5316', 
        '{{1,1,29.11}, {7,1,15}, {8,1, 32}, {18,3, 58}, {19,1, 5.23}}');

SELECT * FROM inventory_request;    


/* 

Section: plpgsql_check – a Powerful Linter for PL/pgSQL code

*/

CREATE EXTENSION plpgsql_check;

CREATE OR REPLACE FUNCTION product.insert_brand_test_linter
    (p_id INTEGER, p_label TEXT, p_description TEXT) RETURNS TEXT
AS
$$
DECLARE
    v_test_var INTEGER :=0; -- unused variable to test linter
BEGIN
    IF current_date < '2025-12-31' THEN
        INSERT INTO product.brand (id, label, description)
            VALUES (p_id, p_label, p_description);
    ELSE
        INSERT INTO product.brand (id, label, description)
            VALUES (p_id, 'All new: ' || p_description);
    END IF;
    RETURN 'Done';
END $$ LANGUAGE plpgsql;

-- running the sample function
SELECT insert_brand_test_linter (100, 'Brand X', 'A new brand');

-- running the linter
SELECT plpgsql_check_function('product.insert_brand_test_linter', fatal_errors := false);
/*

Section PL/Python

*/

\c ecommerce_reference_data

CREATE EXTENSION plpython3u;

CREATE OR REPLACE PROCEDURE product.ensure_description_uppercase()
AS $$
import plpy
rows = plpy.execute("SELECT id, description FROM product.category")
for row in rows:
    desc = row['description']
    if desc and not desc[0].isupper():
        # Print the description that needs to be fixed
        plpy.notice("This description needs to be fixed: %s" % desc)
        # Capitalize the first letter of the description
        new_desc = desc[0].upper() + desc[1:]
        plpy.notice("Fixed: %s" % new_desc)
        # Use % formatting and escape single quotes to create query string
        update_sql = (
            "UPDATE product.category "
            "SET description = '%s' WHERE id = %d"
        ) % (new_desc.replace("'", "''"), row['id'])
        plpy.execute(update_sql)
$$ LANGUAGE plpython3u;

CALL product.ensure_description_uppercase();

CREATE OR REPLACE PROCEDURE product.ensure_description_uppercase_cursor()
AS $$
import plpy
cursor = plpy.cursor("SELECT id, description FROM product.category")
while True:
    rows = cursor.fetch(5)  # fetch 5 rows at a time
    if not rows:
        break
    for row in rows:
        desc = row['description']
        if desc and not desc[0].isupper():
            # Print the description that needs to be fixed
            plpy.notice("This description needs to be fixed: %s" % desc)
            # Capitalize the first letter of the description
            new_desc = desc[0].upper() + desc[1:]
            plpy.notice("Fixed: %s" % new_desc)
            # Use % formatting and escape single quotes to create query string
            update_sql = (
                "UPDATE product.category "
                "SET description = '%s' WHERE id = %d"
            ) % (new_desc.replace("'", "''"), row['id'])
            plpy.execute(update_sql)
$$ LANGUAGE plpython3u;

CALL product.ensure_description_uppercase_cursor();

-- exception handling in PL/Python

CREATE OR REPLACE FUNCTION product.insert_category(
    p_id INTEGER,
    p_label TEXT,
    p_description TEXT
)
RETURNS TEXT
AS $$
import plpy
from plpy import spiexceptions
try:
    sql = (
        "INSERT INTO product.category (id, label, description) "
        "VALUES (%d, '%s', '%s')"
    ) % (
        p_id,
        p_label.replace("'", "''"),
        p_description.replace("'", "''")
    )
    plpy.execute(sql)
    return "Insert successful"
except spiexceptions.UniqueViolation as e:
    return "Unique constraint violation: " + str(e)
except spiexceptions.PrimaryKeyViolation as e:
    return "Unique constraint violation: " + str(e)
except plpy.SPIError as e:
    return "other error, SQLSTATE %s" % e.sqlstate
except Exception as e:
        return "Unknown error: " + str(e)
$$ LANGUAGE plpython3u;

-- running the sample function
SELECT product.insert_category(14, 'Blouses', 'long sleeve and short sleeve shirts');
