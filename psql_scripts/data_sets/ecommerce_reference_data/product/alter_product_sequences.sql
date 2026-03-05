--- the base data examples are loaded manually for illustration purposes 
--- after the initial data load, the sequences are altered to start at 10,000
--- this avoids conflicts when data is added through the API

\c ecommerce_reference_data

ALTER SEQUENCE brand_id_seq START 10000;
ALTER SEQUENCE brand_id_seq RESTART;

ALTER SEQUENCE category_id_seq START 10000;
ALTER SEQUENCE category_id_seq RESTART;

ALTER SEQUENCE product_id_seq START 10000;
ALTER SEQUENCE product_id_seq RESTART;

ALTER SEQUENCE product_variant_id_seq START 10000;
ALTER SEQUENCE product_variant_id_seq RESTART;

ALTER SEQUENCE product_variant_price_id_seq START 10000;
ALTER SEQUENCE product_variant_price_id_seq RESTART;