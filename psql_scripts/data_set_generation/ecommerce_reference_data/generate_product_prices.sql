\c ecommerce_reference_data

DROP PROCEDURE IF EXISTS internal.generate_product_variant_prices;

CREATE PROCEDURE internal.generate_product_variant_prices ()
    AS  
        $$
            DECLARE
                v_product_record RECORD; --- this will be used to iterate over the product records
                v_product_variant_record RECORD;
                -- standard prices by category
                v_category_price NUMERIC[] := ARRAY[
                    90,     -- (1, 'Pants', 'long trousers'),
                    29,     -- (2, 'Shirts', 'long sleeve and short sleeve shirts'),
                    35,     -- (3, 'T-Shirts', 'long sleev and short sleeve T-shirts'),
                    120,    -- (4, 'Footwear', 'Dress shoes, sneakers, and sport shoes'),
                    75,     -- (5, 'Accessories', 'Belts, watches, sunglasses, and other accessories'),
                    85,     -- (6, 'Outerwear', 'Jackets, coats, and outdoor clothing'),
                    25,     -- (7, 'Sportswear', 'Athletic and casual sports clothing'),
                    180,    -- (8, 'Dresses', 'Formal and casual dresses for women'),
                    25,     -- (9, 'Swimwear', 'Swimming and beach attire'),
                    220,    -- (10, 'Jackets', 'Suit coats, leather jackets, sports coats'),
                    250     -- (11, 'Coats', 'Trench coats, duffle coats')
                    ];
                v_product_price NUMERIC;
                v_price_variance NUMERIC;
                v_inflation_adjusted_price NUMERIC;
                v_annual_inflation_rate NUMERIC := 0.03;
                v_price_validity_ranges DATERANGE[] := ARRAY[
                        '[2024-01-01, 2024-06-30]'::DATERANGE, 
                        '[2024-07-01, 2024-12-31]'::DATERANGE, 
                        '[2025-01-01, 2025-06-30]'::DATERANGE,
                        '[2025-07-01, 2025-12-31]'::DATERANGE,
                        '[2026-01-01, 2026-12-31]'::DATERANGE
                ];
                v_validity_range DATERANGE;
                v_current BOOLEAN DEFAULT false;
            BEGIN
                -- iterate through all the products
                FOR v_product_record IN SELECT p.id, pc.id AS category_id, pc.label AS category_label
                                            FROM product.product p, product.category pc
                                            WHERE p.category_id = pc.id
                    LOOP
                        --- look up the standard price
                        v_product_price := v_category_price[v_product_record.category_id];
                        RAISE NOTICE 'price %', v_product_price;
                        --- randomize the price
                        v_product_price := v_product_price + (random() * .25 * v_product_price);
                        -- iterate through all the variants for the product
                        FOR v_product_variant_record IN SELECT id FROM product_variant WHERE product_id = v_product_record.id
                            LOOP
                                -- iterate through the validity ranges and increase the price based on inflation
                                v_inflation_adjusted_price := v_product_price;
                                FOREACH v_validity_range IN ARRAY v_price_validity_ranges
                                    LOOP
                                        IF (v_validity_range @> current_date)
                                            THEN 
                                                v_current = true; 
                                            ELSE 
                                                v_current = false;
                                        END IF;    
                                        INSERT 
                                            INTO product.product_variant_price (product_variant_id, price, validity, current)
                                            VALUES (
                                                v_product_variant_record.id,
                                                v_inflation_adjusted_price,
                                                v_validity_range,
                                                v_current);
                                        v_inflation_adjusted_price := v_inflation_adjusted_price * (1 + v_annual_inflation_rate);         
                                    END LOOP;
                            END LOOP;
                    END LOOP;
            END;
        $$
    LANGUAGE plpgsql;

\echo '*** Generating variants and prices ***'

TRUNCATE product.product_variant_price CASCADE;
CALL internal.generate_product_variant_prices();