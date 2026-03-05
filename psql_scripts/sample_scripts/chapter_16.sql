
/* ============================================================================

                        Code samples for Chapter 16

    Chapter 16 illustrates embedding and vector similarity search in PostgreSQL 
    using the pgvector extension. 
    The code below illustrates:
        1) Basic pgvector usage using a simple fruit dataset
        2) Creating and using vector indexes (IVFFLAT and HNSW)
        3) Realizing semantic search in PostgreSQL using OpenAI embeddings
        4) Building a recommendation engine with pgvector

    Note: 
    - the first example can be run in any database
    - the latter examples assume the presence of the aidb database

============================================================================ */ 


-- From Concept to Code: Finding the Closest Fruit
-- A simple examples of pgvector usage
-- This code can be run against any database.

-- Ensure pgvector extension is installed
CREATE EXTENSION IF NOT EXISTS vector;


-- Define a simple table to hold fruit data with vector embeddings
DROP TABLE IF EXISTS fruit_vectors;
CREATE TABLE fruit_vectors (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  features VECTOR(3) -- [taste, color, softness]
);

-- Insert sample fruit data with 3-dimensional feature vectors
INSERT INTO fruit_vectors (name, description, features) VALUES
  ('Apple',  'Sweet, medium red, medium firm',   '[0.70, 0.60, 0.50]'),
  ('Banana', 'Very sweet, yellow, soft',         '[0.95, 0.90, 0.80]'),
  ('Mango',  'Very sweet, orange, very soft',    '[0.90, 0.80, 0.70]'),
  ('Lemon',  'Very tart, yellow, firm',          '[0.30, 0.20, 0.40]'),
  ('Orange', 'Sweet-tart, orange, firm',         '[0.80, 0.70, 0.40]'),
  ('Peach',  'Sweet, pinkish, very soft',        '[0.85, 0.65, 0.90]'),
  ('Grape',  'Sweet, purple/green, soft-ish',    '[0.75, 0.50, 0.40]'),
  ('Kiwi',   'Tart-sweet, brown/green, soft',    '[0.60, 0.35, 0.60]'),
  ('Potato', 'Starchy, brown, firm',             '[0.20, 0.15, 0.10]'),
  ('Cherry', 'Sweet, red, firm',                 '[0.80, 0.55, 0.50]');

-- Optional index for faster KNN (ivfflat requires ANALYZE after insert)
CREATE INDEX ON fruit_vectors USING ivfflat (features vector_l2_ops) WITH (lists = 10);
ANALYZE fruit_vectors;

-- Examples:

-- Querying vector similarity using pgvector operators
-- 1) Euclidean distance operator (<->) to find the fruits closet to banana-like features
SELECT id, name, description,
       features <-> '[0.95,0.90,0.80]' AS distance
FROM fruit_vectors
ORDER BY distance ASC
LIMIT 5;


-- 2) Find nearest neighbors to "Apple"
SELECT f2.id, f2.name, f2.description,
       f2.features <-> f1.features AS distance
FROM fruit_vectors f1
JOIN fruit_vectors f2 ON f1.id <> f2.id
WHERE f1.name = 'Apple'
ORDER BY distance
LIMIT 5;

-- 3) Use cosine distance operator (vector_cosine_ops) to rank by cosine similarity
SELECT id, name,
       features <#> '[0.70,0.60,0.50]' AS cosine_distance
FROM fruit_vectors
ORDER BY cosine_distance
LIMIT 5;


--- Indexing for AI: Finding the Needle in the Haystack

-- Create our IVFFLAT "Supermarket" index for 1 million products
-- this is not functional code, just an example of creating an ivfflat index!
CREATE INDEX ON embeddings.product_embedding
    -- identify the index type, the column to index, and the operator class
    USING ivfflat (embedding vector_cosine_ops)
    WITH (lists = 1000);


-- EXAMPLE: FAST, "GOOD ENOUGH" SEARCH (Default)
-- this is not functional code, just an example of querying with pgvector!
-- By default, ivfflat.probes is 1. This is the fastest search.
SELECT product_id, product_name
    FROM product
    ORDER BY embedding <-> [...your_search_vector...]::vector
    LIMIT 5;

-- EXAMPLE: HIGH-ACCURACY, SLOWER SEARCH
-- 1. Tell Postgres to be "more accurate" for this one query
SET LOCAL ivfflat.probes = 10;

-- 2. Run the exact same query
-- This time, Postgres will search the 10 best-matching "aisles"
SELECT product_id, product_name
    FROM product
    ORDER BY embedding <-> [...your_search_vector...]::vector
    LIMIT 5;


-- Create our HNSW "City Map" index with 16 "roads" per house
-- and a "perfectionist" builder
-- this is not functional code, just an example of creating an hnsw index!

CREATE INDEX ON embeddings.product_embedding
    -- identify the index type, the column to index, and the operator class
    USING hnsw (embedding vector_cosine_ops)
    -- m=16 means each node connects to 16 neighbors (default)
    -- ef_construction=200 means higher accuracy during index building
    WITH (m = 16, ef_construction = 200);

-- EXAMPLE: HIGH-ACCURACY SEARCH

-- 1. Tell PostgreSQL to be "more diligent" for this search
SET LOCAL hnsw.ef_search = 100;

-- 2. Run the query
-- PostgreSQL will search the "map" more thoroughly
SELECT product_id, product_name
    FROM product
    ORDER BY embedding <-> [...your_search_vector...]::vector
    LIMIT 5;


-- Realizing Semantic Search in PostgreSQL
-- this code needs to be executed in the aidb database!

-- Ensure pgvector extension is installed
CREATE EXTENSION IF NOT EXISTS vector; 

-- Create table to hold product embeddings
CREATE TABLE embeddings.product_embedding (
    product_id INTEGER PRIMARY KEY 
               REFERENCES product.product(id) ON DELETE CASCADE,
    embedding VECTOR(1536) NOT NULL);


-- Function to embed all products using OpenAI API
-- this PLPython3u function is defined in AIDB.sql
-- it uses the OpenAI API to generate embeddings for products
-- and stores them in the embeddings.product_embedding table
-- make sure you have set your OpenAI API key using 
-- ALTER SYSTEM SET api.openai_api_key = 'your_openai_api_key_here';
--- To run the function and embed products, use:

SELECT api.embed_products();

-- create index on product embeddings for faster similarity search
CREATE INDEX idx_product_embedding_hnsw
    ON embeddings.product_embedding
USING hnsw (embedding vector_l2_ops);

-- perform the semantic search

WITH 
-- CTE to get the query embedding
query_embedding AS (
  SELECT api.openai_embed('Men''s attire for a formal occasion')::vector AS vec
),
-- CTE to get products with their embeddings
prod_w_embedding AS (
  SELECT p.id, p.label, pe.embedding
    FROM product AS p
    JOIN embeddings.product_embedding pe ON p.id = pe.product_id
)
-- Final selection with similarity calculation
SELECT pwe.id, pwe.label, 1 - (pwe.embedding <=> qe.vec) AS similarity
   FROM prod_w_embedding AS pwe, query_embedding AS qe
   ORDER BY pwe.embedding <=> qe.vec
   LIMIT 3;



-- Using pgvector to Build a Recommendation Engine
-- product to product recommendations

-- Example query that finds similar products to a given product ID
WITH 
-- CTE to get the embedding of the target product
target_product_embedding AS (
  SELECT pe.embedding
    FROM embeddings.product_embedding pe
    WHERE pe.product_id = 9 -- Replace with the target product ID
),
-- CTE to get products with their embeddings
prod_w_embedding AS (
  SELECT p.id, p.label, pe.embedding
    FROM product AS p
    JOIN embeddings.product_embedding pe ON p.id = pe.product_id
)
-- Final selection with similarity calculation
SELECT pwe.id, pwe.label, 1 - (pwe.embedding <=> tpe.embedding) AS similarity
    FROM prod_w_embedding AS pwe, target_product_embedding AS tpe
    WHERE pwe.id <> 9 -- Exclude the target product itself
    ORDER BY pwe.embedding <=> tpe.embedding
    LIMIT 3;

-- Spotify-Style User-Preference Lists

WITH 
-- CTE to get the average embedding of the target products
avg_product_embedding AS (
  SELECT AVG(pe.embedding) AS avg_embedding
    FROM embeddings.product_embedding pe
    WHERE pe.product_id IN (9, 8, 6) 
),
-- CTE to get products with their embeddings
prod_w_embedding AS (
  SELECT p.id, p.label, pe.embedding
    FROM product AS p
    JOIN embeddings.product_embedding pe ON p.id = pe.product_id
)
-- Final selection with similarity calculation
SELECT pwe.id, pwe.label, 1 - (pwe.embedding <=> ape.avg_embedding) AS similarity
    FROM prod_w_embedding AS pwe, avg_product_embedding AS ape
    WHERE pwe.id NOT IN (9, 8, 6) -- Exclude the target products themselves
    ORDER BY pwe.embedding <=> ape.avg_embedding
    LIMIT 3;


