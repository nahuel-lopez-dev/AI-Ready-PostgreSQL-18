/*

--- generate inventory levels for for the us and eu ecommerce setups
--- populates the table inventory.product_inventory with random amounts

*/

DROP PROCEDURE IF EXISTS generate_product_variant_inventory;

CREATE PROCEDURE generate_product_variant_inventory (p_maxunits INTEGER DEFAULT 400)
AS
$$
DECLARE
    v_product_variant_record RECORD;
    v_random_qty INTEGER;
BEGIN
    FOR v_product_variant_record IN SELECT id FROM product.product_variant 
        LOOP
            v_random_qty := 100+ TRUNC (RANDOM() * p_maxunits);
            INSERT INTO product_variant_inventory (product_variant_id, qty)
                VALUES (v_product_variant_record.id, v_random_qty);
        END LOOP;
END;
$$ LANGUAGE PLPGSQL;

CALL generate_product_variant_inventory(400);