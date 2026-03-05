  
  --- Chapter 7 examples
  --- JSONB Example
  \c postgres

  CREATE TABLE jsonb_example (
    id SERIAL PRIMARY KEY,
    info JSONB
  );

  INSERT INTO jsonb_example (info)
  VALUES (
  '{"firstName": "John",  
  "lastName": "Smith",         
  "isAlive": true,             
  "age": 25,                   
  "height_cm": 167.6,          
  "address": {                 
    "streetAddress": "21 2nd Street",
    "city": "New York",
    "state": "NY",
    "postalCode": "10021-3100"
  },
  "phoneNumbers": [         
    {                   
      "type": "home",
      "number": "212 555-1234"
    },
    {
      "type": "office",
      "number": "646 555-4567"
    }
  ]
}'
  );
 

SELECT jsonb_pretty(JSONB_INSERT (info, '{phoneNumbers,0}', '{"type":"mobile", "number": "617 306 6059"}', true))
  FROM jsonb_example WHERE id=1;  

SELECT jsonb_pretty(JSONB_INSERT (info, '{address, country}', '"US"', true))
  FROM jsonb_example WHERE id=1;  

SELECT jsonb_pretty(JSONB_SET (info, '{address, state}', '"NY State"', true))
  FROM jsonb_example WHERE id=1; 

-- replaces the 0 entry in the array
SELECT jsonb_pretty(JSONB_SET (info, '{phoneNumbers,0}', '{"type":"mobile", "number": "617 306 6059"}', true))
  FROM jsonb_example WHERE id=1;   

-- adds a new entry at the end of the array
SELECT 
  JSONB_SET (
    info, -- the target JSONB column
    '{phoneNumbers,2}', -- the path to the new entry
    '{"type":"mobile", "number": "617 306 6059"}', -- the changed data
    true -- create missing path elements if needed
    )
  FROM jsonb_example WHERE id=1;       

-- updates the number of the second entry in the array
SELECT 
  JSONB_SET(
    info,
    '{phoneNumbers,1,number}',
    '"617 306 6059"'
  )
FROM jsonb_example WHERE id=1;  

SELECT info - 'isAlive' FROM jsonb_example WHERE id=1;      

-- delete key "state" from the address object
SELECT info #- '{address, state}' FROM jsonb_example WHERE id=1; 

SELECT info #- '{phoneNumbers,1}' FROM jsonb_example WHERE id=1; 

SELECT
  jsonb_insert(
    '{"name":"John Doe", "address" : { "city": "San Francisco"}}',
    '{address,state}',
    '"California"'
  );

-- formatted output
SELECT id, jsonb_pretty(info) FROM jsonb_example;

/*

Creating and Accessing JSON Documents 

*/

\c east_ecommerce_data

-- building a JSON object from tabular data

DROP TABLE IF EXISTS brand_country_json;

CREATE  TABLE brand_country_json ( id, brand_info ) AS
(SELECT 
    id,
    JSONB_BUILD_OBJECT(
      'brand id', id,
      'label', label, 
      'description', description, 
      'country', 
        JSONB_BUILD_OBJECT(
          'iso code', alpha3_code, 
          'name', name)
        )
  FROM brand b 
  JOIN country_of_origin coo on b.id = coo.brand_id);



SELECT id, jsonb_pretty(brand_info) FROM brand_country_json WHERE id = 9;

SELECT brand_info->>'brand id' AS label_text FROM brand_country_json WHER id=9;

SELECT brand_info->'label' AS label_json FROM brand_country_json WHERE id=9;

SELECT * FROM brand_country_json WHERE id=9;

SELECT  
  JSONB_PATH_QUERY (brand_info, '$.label') AS label, 
  JSONB_PATH_QUERY (brand_info, '$.country.name') AS country_name
FROM brand_country_json WHERE id=9;


\c postgres

SELECT JSONB_PATH_QUERY (info, '$.lastName') AS name, 
  JSONB_PATH_QUERY(info,  '$.phoneNumbers[*][0] ? (@.type == "home")')->'number' AS home_nbr 
  FROM jsonb_example;


SELECT JSONB_INSERT (info, '{weight_kg}', '84', true) 
  FROM jsonb_example WHERE id=1;

/*

Updating JSON Documents 

*/

-- add a new phone number entry to our complex JSON example

SELECT  
  JSONB_SET ( 
    info, -- the target JSONB column 
    '{phoneNumbers,2}', -- the path to the new entry 
    '{"type":"mobile", "number": "617 306 6059"}', -- the changed data 
    true -- create missing path elements if needed 
    ) 
  FROM jsonb_example WHERE id=1;    

-- update the existing phone number    

SELECT  
  JSONB_SET( 
    info, 
    '{phoneNumbers,1,number}', 
    '"617 306 6059"') 
FROM jsonb_example WHERE id=1; 

-- The first example REMOVES the key state and its value from the query results
--  the second example removes the 2nd entry in the array of phone numbers

SELECT info #- '{address, state}' FROM jsonb_example WHERE id=1;  
 
SELECT info #- '{phoneNumbers,1}' FROM jsonb_example WHERE id=1;  



-- JSON_TABLE example

\c east_ecommerce_data

SELECT id, first_name, pn.* FROM customer,
  JSON_TABLE(
    phone_numbers, 
    '$'
    COLUMNS (
        mobile TEXT PATH '$.mobile',
        home TEXT PATH '$.home')
      ) AS pn;

-- create an index on the mobile phone number extracted from the JSONB column phone_numbers

DROP INDEX IF EXISTS idx_customers_mobile;
CREATE INDEX idx_customers_mobile ON customer ((phone_numbers->>'mobile'));    

select phone_numbers->>'mobile' from customer;

/*

-- Arrays

*/

\c postgres

-- example with military spelling

DROP TABLE IF EXISTS array_spelling;

CREATE TABLE array_spelling (
  country TEXT PRIMARY KEY,
  spelling TEXT[]
);

-- array with spelling alphabets for US, DE, FR
INSERT INTO array_spelling (country, spelling) 
  VALUES
  ('US', '{Alpha,Bravo,Charlie,Delta,Echo,Foxtrot}'),
  ('DE', '{Anton,Berta,Cäsar,Dora,Emil,Friedrich}'),
  ('FR', '{Anatole,Berthe,Célestin,Désiré,Eugène,François}');

-- view the data
SELECT * FROM array_spelling;

-- replace Foxtrot with Foxtrott
UPDATE array_spelling
SET spelling = ARRAY_REPLACE(spelling, 'Foxtrot', 'Foxtrott')
WHERE country = 'US';

-- add Golf to the end of the array
UPDATE array_spelling
SET spelling = ARRAY_APPEND(spelling, 'Golf')
WHERE country = 'US';

-- remove Golf from the array
UPDATE array_spelling
SET spelling = ARRAY_REMOVE(spelling, 'Golf')
WHERE country = 'US';

--- ranges example

-- see the definition of product.product_variant_price table
-- in psql_scripts/database_definitions/ecommerce_reference_data.sql

/*

-- Custom Data Types

*/ 

\c postgres

-- Domain Types

CREATE DOMAIN price AS NUMERIC(8,2)
  CHECK (VALUE >= 0);

CREATE TABLE custom_type_example (
    id SERIAL PRIMARY KEY,
    product_name TEXT,
    product_price price
);

INSERT INTO custom_type_example (product_name, product_price)
  VALUES ('Product 1', 19.99),
         ('Product 2', 29.99);

INSERT INTO custom_type_example (product_name, product_price)
  VALUES ('Product 3', -5.00);  -- this will fail due to the CHECK constraint

SELECT * FROM custom_type_example;


--- Composite Types

DROP TYPE IF EXISTS custom_product CASCADE;

CREATE TYPE custom_product AS (
  name VARCHAR(2),
  description  TEXT,
  cost PRICE); -- uses the custom domain defined above

DROP TABLE IF EXISTS composite_type_example;
CREATE TABLE composite_type_example (
    id SERIAL PRIMARY KEY,
    product_info custom_product );

INSERT INTO composite_type_example (product_info)
  VALUES (ROW('P1', 'Product 1 description', 19.99)),
         (ROW('P2', 'Product 2 description', 29.99));    

INSERT INTO composite_type_example (product_info)
  VALUES ('("P3", "Product 3 description", 32.15)');  

INSERT INTO composite_type_example (product_info)
  VALUES ('("P4", "Product 3 description", -5.00)');  -- this will fail due to the PRICE domain CHECK constraint


SELECT * FROM composite_type_example;

-- Enumeration Types

DROP TYPE IF EXISTS week_days;

CREATE TYPE week_days AS ENUM (
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
);

DROP TABLE IF EXISTS enum_example;

CREATE TABLE enum_example (
    id SERIAL PRIMARY KEY,
    day week_days NOT NULL
);  

INSERT INTO enum_example (day) VALUES ('Monday'), ('Tuesday'), ('Sunday');

INSERT INTO enum_example (day) VALUES ('FRIDAY');  -- this will fail

SELECT * FROM enum_example WHERE day > 'Friday';

--- UUID Type

DROP TABLE IF EXISTS uuid_example;

CREATE TABLE uuid_example (
    id UUID PRIMARY KEY DEFAULT uuidV7(),
    name TEXT
);

INSERT INTO uuid_example (name) VALUES ('Item 1'), ('Item 2'), ('Item 3');

SELECT *, uuid_extract_timestamp(id) FROM uuid_example;

--- UUID versus INTEGER table size test

-- Extension pgstattuple provides information about table and index sizes
CREATE EXTENSION pgstattuple;


DROP TABLE IF EXISTS test_integer;
DROP TABLE IF EXISTS test_UUID;

CREATE TABLE test_integer (
  id INTEGER PRIMARY KEY
);

INSERT INTO test_integer (id)
SELECT generate_series(1, 100000000);


CREATE TABLE test_UUID (
  id UUID PRIMARY KEY DEFAULT uuidV7()
);

INSERT INTO test_UUID (id)
SELECT uuidV7() FROM generate_series(1, 100000000);

select pg_relation_size('test_integer');
select pg_relation_size('test_UUID');

SELECT (pgstattuple('test_integer'));

SELECT (pgstattuple('test_integer')).tuple_len;

SELECT * FROM pgstattuple('test_UUID');
SELECT * FROM pgstattuple('test_integer');

--- Vector Type

DROP TABLE IF EXISTS vector_example;


CREATE TABLE vector_example (
    id bigserial PRIMARY KEY, 
    embedding vector(3));

INSERT INTO vector_example (embedding) 
  VALUES 
    ('[1,1,0]'),
    ('[1,2,2]'),
    ('[3,2,3]'),
    ('[1.5,2,3]');

SELECT embedding <-> '[0.8,1.5,0]' as L2_distance, * 
  FROM vector_example ORDER BY L2_distance;


/*

Dealing with hostpots in MVCC

*/

\c postgres

DROP TABLE IF EXISTS users; 
CREATE TABLE users ( 
  id SERIAL PRIMARY KEY, 
  f_name TEXT, 
  l_name TEXT, 
  email TEXT UNIQUE NOT NULL, 
  nbr_followers INTEGER, 
  UNIQUE (f_name, l_name) 
); 
 
CREATE INDEX idx_user_test_fname_lname ON users (f_name, l_name); 

DROP TABLE IF EXISTS follower_count CASCADE;

CREATE TABLE follower_count ( 
  user_id INTEGER REFERENCES users(id) ON DELETE CASCADE, 
  follower_count INTEGER 
); 

CREATE TABLE follower_count ( 
  user_id INTEGER REFERENCES users(id) ON DELETE CASCADE, 
  follower_count INTEGER 
) PARTITION BY HASH (user_id); 
 
-- Create partitions 
CREATE TABLE follower_count_part_0 PARTITION OF follower_count FOR VALUES WITH (MODULUS 4, REMAINDER 0); 
CREATE TABLE follower_count_part_1 PARTITION OF follower_count FOR VALUES WITH (MODULUS 4, REMAINDER 1); 
CREATE TABLE follower_count_part_2 PARTITION OF follower_count FOR VALUES WITH (MODULUS 4, REMAINDER 2); 
CREATE TABLE follower_count_part_3 PARTITION OF follower_count FOR VALUES WITH (MODULUS 4, REMAINDER 3);





-------------------------------
-- Expression Indexes

\c east_ecommerce_data

DROP INDEX IF EXISTS idx_customer_city_lower;
CREATE INDEX idx_customer_city_lower ON customer (LOWER(city));  

-- Muli-column index

SELECT * FROM customer where last_name = 'West' and first_name = 'Waldo';
EXPLAIN  SELECT * FROM customer where last_name = 'West' and first_name = 'Waldo';

CREATE INDEX idx_m_customer_lname_lname ON customer (last_name, first_name);
EXPLAIN  SELECT * FROM customer where last_name = 'West' and first_name = 'Waldo';

CREATE INDEX idx_customer_lname ON customer (last_name);
EXPLAIN  SELECT * FROM customer where last_name = 'West' and first_name = 'Waldo';

CREATE INDEX idx_customer_fname ON customer (first_name);

-- Index only scan

CREATE INDEX idx_customer_lname_w_city ON CUSTOMER(last_name) include (CITY);
EXPLAIN  SELECT city FROM customer where last_name = 'West';


--- MVCC hotspots

DROP TABLE IF EXISTS users;
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  f_name TEXT,
  l_name TEXT,
  email TEXT UNIQUE NOT NULL,
  nbr_followers INTEGER,
  UNIQUE (f_name, l_name)
);

CREATE INDEX idx_user_test_fname_lname ON users (f_name, l_name);


DROP TABLE IF EXISTS users;
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  f_name TEXT,
  l_name TEXT,
  email TEXT UNIQUE NOT NULL,
  nbr_followers INTEGER,
  UNIQUE (f_name, l_name)
);

CREATE TABLE follower_count (
  user_id INTEGER REFERNCES users(id) ON DELETE CASCADE,
  follower_count INTEGER
);


DROP TABLE IF EXISTS users;
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  f_name TEXT,
  l_name TEXT,
  email TEXT UNIQUE NOT NULL,
  UNIQUE (f_name, l_name)
);

-- Drop the table if it exists
DROP TABLE IF EXISTS follower_count CASCADE;

-- Create the partitioned table
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  f_name TEXT,
  l_name TEXT,
  email TEXT UNIQUE NOT NULL,
  nbr_followers INTEGER,
  UNIQUE (f_name, l_name)
);
CREATE TABLE follower_count (
  user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
  follower_count INTEGER
) PARTITION BY HASH (user_id);
-- Create partitions
CREATE TABLE follower_count_part_0 PARTITION OF follower_count FOR VALUES WITH (MODULUS 4, REMAINDER 0);
CREATE TABLE follower_count_part_1 PARTITION OF follower_count FOR VALUES WITH (MODULUS 4, REMAINDER 1);
CREATE TABLE follower_count_part_2 PARTITION OF follower_count FOR VALUES WITH (MODULUS 4, REMAINDER 2);
CREATE TABLE follower_count_part_3 PARTITION OF follower_count FOR VALUES WITH (MODULUS 4, REMAINDER 3);  
