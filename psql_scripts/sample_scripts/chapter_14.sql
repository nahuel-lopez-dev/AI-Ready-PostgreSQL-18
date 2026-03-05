/* ============================================================================

                        Code samples for Chapter 14

    Chapter 14 illustrates text search in PostgreSQL. We will show three approaches:
    1) Basic SQL LIKE pattern matching
    2) Full Text Search using PostgreSQL's built-in text search capabilities
    3) Using the pg_trgm extension for trigram based similarity searching

    This code should be run against the central_analytics database.

============================================================================ */ 

-- connect to the central_analytics database
\c central_analytics



-- 1) Basic SQL LIKE pattern matching

-- simple tests using LIKE
SELECT DISTINCT p.id, p.label AS product, b.label AS brand FROM product p 
    JOIN brand b ON p.brand_id = b.id
    WHERE p.label LIKE '%shirt%';

SELECT DISTINCT p.id, p.label AS product, b.label AS brand FROM product p 
    JOIN brand b ON p.brand_id = b.id
    WHERE p.label LIKE '_olo%';

-- test with composite pattern
SELECT DISTINCT p.id, p.label AS product, b.label AS brand FROM product p 
    JOIN brand b ON p.brand_id = b.id
    WHERE p.label LIKE '%Oxford%Shirt%';


-- Show the limits of LIKE pattern matching  
SELECT DISTINCT p.id, p.label, b.label FROM product p 
    JOIN brand b ON p.brand_id = b.id
    WHERE p.label ILIKE '%Men%Oxford%shirt%';

SELECT DISTINCT p.id, p.label, b.label FROM product p 
    JOIN brand b ON p.brand_id = b.id
    WHERE p.label ILIKE '%Oxford%shirt%Men';    

-- Casefold instead of lower/upper
SELECT DISTINCT p.id, p.label, b.label FROM product p 
    JOIN brand b ON p.brand_id = b.id
    WHERE casefold(p.longdescription) LIKE casefold('%Oxford%Shirt%');

-- cretae a functional index to speed up LIKE queries
CREATE INDEX idx_product_longdescription_casefold ON product (casefold(longdescription));
);


-- POSIX regular expressions with ~ operator
SELECT DISTINCT p.id, p.label, b.label FROM product p 
    JOIN brand b ON p.brand_id = b.id
    WHERE p.label ~* 'Men.*Oxford.*shirt';

SELECT DISTINCT p.id, p.label, b.label FROM product p 
    JOIN brand b ON p.brand_id = b.id
    WHERE p.label ~* '(^Nike|^Zara).*$';

SELECT DISTINCT p.id, p.label, b.label FROM product p 
    JOIN brand b ON p.brand_id = b.id
    WHERE p.label ~* '^Chinos .* (Boss|The Gap)$';
 

-- 2) Full Text Search using PostgreSQL's built-in text search capabilities
-- create a tsvector column for the product text information (label, shortdescription, longdescription)

SELECT to_tsvector(
    'english', 
    'A shirt is not like a T-shirt, even though they both use the string shirt');

SELECT to_tsquery('english', 'Oxford & Shirts & Gap');

SELECT phraseto_tsquery('english', 'Oxford Shirt from the Gap');


ALTER TABLE product DROP COLUMN IF EXISTS infotext_tsv;



ALTER TABLE product
    ADD COLUMN infotext_tsv tsvector 
    GENERATED ALWAYS AS (
        to_tsvector('english', 
        -- cannot use format here as its not immutable
            coalesce(label,'') || ' ' ||
            coalesce(shortdescription,'') || ' ' ||
            coalesce(longdescription,'')
        )
    ) STORED;

 ALTER TABLE product DROP COLUMN infotext_tsv;

ALTER TABLE product
    ADD COLUMN infotext_tsv tsvector 
    GENERATED ALWAYS AS (
        setweight (to_tsvector('english', COALESCE(label, '')), 'A') ||
        setweight (to_tsvector('english', COALESCE(shortdescription, '')), 'B') ||
        setweight (to_tsvector('english', COALESCE(longdescription, '')), 'C'
        )
    ) STORED;    

-- create an index on the tsvector column
CREATE INDEX idx_product_infotext_tsv ON product USING GIN (infotext_tsv);

-- sample full text search query
SELECT DISTINCT p.id, p.label, b.label FROM product p 
    JOIN brand b ON p.brand_id = b.id
    WHERE p.infotext_tsv @@ to_tsquery('english', 'Oxford & Shirt');

SELECT DISTINCT p.id, p.label product, b.label brand FROM product p 
    JOIN brand b ON p.brand_id = b.id
    WHERE p.infotext_tsv @@ 
        plainto_tsquery('english', 'An Oxford shirt from the Gap');    

select websearch_to_tsquery(
            'english', 
            'T-Shirt from the Gap or Oxford Shirt from the gap');         

SELECT DISTINCT p.id, p.label product, b.label brand FROM product p 
    JOIN brand b ON p.brand_id = b.id
    WHERE p.infotext_tsv @@ 
        websearch_to_tsquery(
            'english', 
            'T-Shirt from the Gap or Oxford Shirt from the gap');       

         


select websearch_to_tsquery('english', 'Gap -"T-shirt"');    

SELECT DISTINCT p.id, p.label as product_label, b.label as brand_label, 
    ts_rank(p.infotext_tsv, to_tsquery('english', 'gap & !( "t-shirt")')) AS rank
    FROM product p 
    JOIN brand b ON p.brand_id = b.id
    ORDER BY rank DESC; 

SELECT DISTINCT p.id, p.label as product_label, b.label as brand_label, 
    ts_rank(p.infotext_tsv, 
        websearch_to_tsquery(
            'english', 
            'T-Shirt from the Gap or Oxford Shirt from the gap')) AS rank
    FROM product p 
    JOIN brand b ON p.brand_id = b.id
    ORDER BY rank DESC
    LIMIT 5;


SELECT DISTINCT p.id, p.label as product_label, b.label as brand_label, 
    ts_rank(p.infotext_tsv, 
        websearch_to_tsquery(
            'english', 
            'T-Shirt from the Gap or Oxford Shirt from the gap')) AS rank,
    ts_headline(p.label || ' '|| p.shortdescription|| ' '|| p.longdescription, 
        websearch_to_tsquery(
            'english', 
            'T-Shirt from the Gap or Oxford Shirt from the gap')) AS snippet
    FROM product p 
    JOIN brand b ON p.brand_id = b.id
    ORDER BY rank DESC
    LIMIT 5;

-- find a casual blue shirt that costs less then $50

SELECT p.id, p.label, FORMAT ('%s-%s', MIN(pvp.price), MAX (pvp.price)) AS price_range 
FROM product p 
    JOIN product_variant pv ON p.id = pv.product_id
    JOIN product_variant_price pvp ON pv.id = pvp.product_variant_id
    WHERE p.infotext_tsv @@ 
        websearch_to_tsquery(
            'english', 
            'edgy and cool shirt or t-shirt') 
        AND pvp.price < 50
    GROUP BY p.id, p.label
    ORDER BY MAX( pvp.price) desc;



3) Using the pg_trgm extension for trigram based similarity searching
-- enable the pg_trgm extension

CREATE EXTENSION IF NOT EXISTS pg_trgm;
-- create an index on the longdescription column using GIN and pg_trgm

CREATE INDEX idx_product_longdescription_trgm ON product USING GIN (longdescription gin_trgm_ops);

SELECT 
    show_trgm('Uniqlo'), 
    show_trgm('Uniclo'), 
    similarity('Uniqlo','Uniclo'), 
    word_similarity('Uniqlo','Uniclo');


SELECT p.id, p.label AS product, b.label AS brand FROM product p 
    JOIN brand b ON p.brand_id = b.id
    WHERE b.label % 'Uniclo';


-- Using trigram for type-ahead search for product labels

CREATE FUNCTION type_ahead_product_search(search_text TEXT, limit_results INT DEFAULT 5)
RETURNS TABLE (product_label TEXT, simi REAL) AS $$
BEGIN
    RETURN QUERY
    SELECT label::TEXT, similarity(label, search_text) AS simi FROM product 
    WHERE label ILIKE search_text || '%'
    ORDER BY simi DESC
    LIMIT limit_results;
END;
$$ LANGUAGE plpgsql;


-- test the type_ahead_search function
SELECT * FROM type_ahead_product_search('Ca', 5);
SELECT * FROM type_ahead_product_search('Cal', 5);
SELECT * FROM type_ahead_product_search('Cali', 5);
SELECT * FROM type_ahead_product_search('Calvi', 5);



-- 4) The unaccent extension

CREATE EXTENSION IF NOT EXISTS unaccent;

SELECT unaccent('Café Münsterländer');

-- create an immutable version of the unaccent function
CREATE OR REPLACE FUNCTION unaccent_immutable(text)
RETURNS text AS $$
    SELECT unaccent($1);
$$ LANGUAGE SQL IMMUTABLE;


-- show how trigrams can be used to build auto-complete i.e. type-ahead search bars