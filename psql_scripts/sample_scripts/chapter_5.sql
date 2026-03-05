
/* ============================================================================

                        Code samples for Chapter 5

============================================================================ */ 

/*

Section: ACID Compliance – What is it and why does it matter? 

*/


BEGIN TRANSACTION
-- create the sales transaction line
    INSERT INTO sales_transaction_line 
        (sales_transaction_id, product_variant_id, qty, price_at_sale)  
        VALUES ('east_7108', 50, 1, 12); 
-- decrement the inventory     
    UPDATE product_variant_inventory SET qty = qty -1 
        WHERE product_variant_id = 50;  
COMMIT TRANSACTION; 


-------------------------------------------------------------------------------


\d inventory.product_variant_inventory ;
          Table "inventory.product_variant_inventory"
       Column       |  Type   | Collation | Nullable | Default 
--------------------+---------+-----------+----------+---------
 product_variant_id | integer |           | not null | 
 qty                | integer |           | not null | 0
Indexes:
    "uq_inventory_variant" PRIMARY KEY, btree (product_variant_id)
Check constraints:
    "product_variant_inventory_qty_check" CHECK (qty >= 0)
Foreign-key constraints:
    "product_variant_inventory_product_variant_id_fkey" FOREIGN KEY (product_variant_id) REFERENCES product_variant(id) ON DELETE CASCADE




/*

Section: Working with Transactions in PostgreSQL

*/

INSERT INTO brand (id, label, description)
    VALUES (10001, 'Wrangler Jeans', 'Good Mornings Make for Better Days');


BEGIN;
INSERT INTO brand (id, label, description)
    VALUES (10001, 'Wrangler Jeans', 'Good Mornings Make for Better Days');

INSERT INTO product (id, category_id, brand_id, label, shortdescription)
    VALUES (10000, 1, 10001, 'Jeans by Wrangler', 'Best pants for a great day');

INSERT INTO product_variant (id, product_id, attributes)    
    VALUES (10001, 10000, '{"color": "blue", "size": "32/36", "fit": "Boot Leg"}');
COMMIT;

BEGIN;

INSERT INTO brand (label, description)
    VALUES ('Wrangler Jeans', 'Good Mornings Make for Better Days');

COMMIT;
 
-------------------------------------------------------------------------------

-- Transaction Blocks

-- Two implicit transactions
INSERT INTO sales_transaction_line 
    (sales_transaction_id, product_variant_id, qty, price_at_sale) 
    VALUES ('east_5316', 10001, 5, 19.99);

UPDATE product_variant_inventory SET qty = qty - 5 WHERE product_variant_id = 10001;

-- Wrap in explicit transaction

BEGIN;

INSERT INTO sales_transaction_line 
    (sales_transaction_id, product_variant_id, qty, price_at_sale) 
    VALUES ('east_5316', 10001, 5, 19.99);
    
UPDATE product_variant_inventory SET qty = qty - 5 WHERE product_variant_id = 10001;

END;

-------------------------------------------------------------------------------
-- Rollback

CREATE OR REPLACE  PROCEDURE add_to_sales_transaction (p_st_id TEXT, p_pv_id INTEGER, p_qty INTEGER, p_price NUMERIC)
AS 
$$
BEGIN
    INSERT INTO sales_transaction_line 
        (sales_transaction_id, product_variant_id, qty, price_at_sale) 
        VALUES (p_st_id, p_pv_id,p_qty, p_price);
    UPDATE product_variant_inventory SET qty = qty - p_qty WHERE product_variant_id = p_pv_id;   
EXCEPTION 
    WHEN check_violation THEN
        ROLLBACK;
        RAISE NOTICE 'Check constraint failure';
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE NOTICE 'Transaction failed for unknown reasons';
END $$ LANGUAGE PLPGSQL;

/*

Section: A Closer Look at Isolation Levels and Their Importance

*/

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

DO $$
    BEGIN 
    IF (SELECT 1 FROM product_variant_inventory 
        WHERE product_variant_id = 50
        AND qty > 1)
    THEN
    -- create the sales transaction line
        INSERT INTO sales_transaction_line 
            (sales_transaction_id, product_variant_id, qty, price_at_sale)  
            VALUES ('east_7108', 50, 1, 12); 
    -- decrement the inventory     
        UPDATE product_variant_inventory SET qty = qty -1 
            WHERE product_variant_id = 50;  
    ELSE
        RAISE NOTICE 'No inventory available';
    END IF;
END $$;

-------------------------------------------------------------------------------

SELECT qty FROM product_variant_inventory WHERE product_variant_id = 50;
UPDATE product_variant_inventory SET qty = qty -1 WHERE product_variant_id = 50;

-------------------------------------------------------------------------------

SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;

DO $$
    BEGIN 
    IF (SELECT 1 FROM product_variant_inventory 
        WHERE product_variant_id = 50
        AND qty > 1)
    THEN
    -- create the sales transaction line
        INSERT INTO sales_transaction_line 
            (sales_transaction_id, product_variant_id, qty, price_at_sale)  
            VALUES ('east_7108', 50, 1, 12); 
    -- decrement the inventory     
        UPDATE product_variant_inventory SET qty = qty -1 
            WHERE product_variant_id = 50;  
    ELSE
        RAISE NOTICE 'No inventory available';
    END IF;
END $$;

-------------------------------------------------------------------------------


/*

Section: SELECT FOR (NO KEY) UPDATE
*/

\c east_ecommerce_data

INSERT INTO brand (label, description) VALUES ('test brand', 'description');

INSERT INTO product (category_id, brand_id, label, shortdescription) 
    VALUES (1, 10000, 'New product', 'Short description');

UPDATE brand SET description = 'New Description' WHERE id = 10000;    

/*

Section: Slowly Changing Dimensions

*/

-- this is the product.product_variant_price table from the ecommerce reference data set
-- it implements a type 6 slowly changing dimension for product prices
-- note the EXCLUDE constraint to avoid overlapping validity periods for the same product variant
-- also note the CHECK constraint to ensure that prices are always greater than 0
CREATE TABLE product.product_variant_price (
    id INTEGER PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY,
    product_variant_id INTEGER NOT NULL REFERENCES product.product_variant (id) ON DELETE CASCADE,
    -- make sure the prices are always greater 0
    price NUMERIC(10, 2) NOT NULL CHECK (price > 0),
    -- DATERANGE where the lower bound is inclusive, and the upper bound is exclusive.
    validity DATERANGE NOT NULL,
    current BOOLEAN NOT NULL DEFAULT false,
    -- Ensures that there are no overlapping price validity periods for the same product and geography.
    EXCLUDE USING GIST (product_variant_id WITH =, validity WITH &&)
);

-- use the @> operator to check if the value is contained in the range
SELECT * FROM product_variant_price 
    WHERE validity @> '2025-07-18'::date 
    AND product_variant_id = 109;


-------------------------------------------------------------------------------


-- both upper and lower boundaries are included in the range
INSERT INTO product_variant_price
   (product_variant__id, price, validity, current)
VALUES
   (109, 100.00, '[2025-07-01,2025-07-02]', false);
