/* ============================================================================

                        Code samples for Chapter 18 - pgvector and Semantic Search

1) cURL code to create an embedding using OpenAI API (requires cURL version 8.7.1 or higher)
2) Python code to create an embedding using OpenAI API (requires Python version 3.13.7 or higher)
3) PostgreSQL function to create an embedding using OpenAI API with PL/Python
4) Example usage of the PostgreSQL function to create embeddings for product categories
5) Batch embedding of products and storing in product_embedding table
6) Example similarity search using the created embeddings
7) Example similarity search with additional hard constraints
8) Retrieve the embedding for a specific product
9) Find top 3 similar products to a given query
10) Spotify-style recommendation example

This code assumes you have an OpenAI API key.

============================================================================ */ 

# Curl Command to Create an Embedding using OpenAI API

curl https://api.openai.com/v1/embeddings \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
        "model": "text-embedding-3-small",
        "input": "Here is the text I want to turn into an embedding."
      }'

# Note: Replace YOUR_API_KEY with your actual OpenAI API key.
# The response will contain the embedding vector for the provided input text.

# Python Code to Create an Embedding using OpenAI API

import json
import ssl
import time
import random
import urllib.request
import urllib.error

# Your OpenAI API key
api_key = 'YOUR_API_KEY'

# The text you want to embed
input_text = "Here is the text I want to turn into an embedding."

# The endpoint and headers
url = "https://api.openai.com/v1/embeddings"
headers = {
    "Authorization": f"Bearer {api_key}",
    "Content-Type": "application/json"
}

# The data payload
data = {
    "model": "text-embedding-3-small",
    "input": input_text
}

# Make the request
request = urllib.request.Request(url, data=json.dumps(data).encode('utf-8'), headers=headers, method='POST')
try:
    with urllib.request.urlopen(request) as resp:
        resp_data = json.load(resp)
        embedding = resp_data['data'][0]['embedding']
        print("Embedding:", embedding)
except urllib.error.HTTPError as e:
    print("Error:", e.code, e.read().decode())

# Note: Replace YOUR_API_KEY with your actual OpenAI API key.
# The response will contain the embedding vector for the provided input text.


/* PL/Python code to create and manage embeddings in PostgreSQL */

-- Set your OpenAI API key in PostgreSQL configuration
-- Option 1: Session-level parameter
 SELECT set_config('api.openai_api_key','your_openai_api_key_here', false);

-- Option 2: Server-level parameter
ALTER SYSTEM SET api.openai_api_key = 'your_openai_api_key_here';
-- Reload the configuration to apply the change
SELECT pg_reload_conf();


-- PostgreSQL Function to Create an Embedding using OpenAI API
CREATE OR REPLACE FUNCTION api.openai_embed(input_text text)
RETURNS float4[]
LANGUAGE plpython3u
AS $$
import json
import ssl
import urllib.request
import urllib.error

# Read API key from a session-scoped setting (GUC)
rv = plpy.execute("SELECT current_setting('api.openai_api_key', true) AS k")
api_key = rv[0]["k"] if rv and rv[0]["k"] is not None else None
if not api_key:
    raise Exception("OpenAI API key not set. Use: SELECT set_config('api.openai_api_key','sk-...','f');")

# Input text we want to embed
text = input_text or ""

# OpenAI endpoint for embeddings
url = "https://api.openai.com/v1/embeddings"

# HTTP headers (auth + JSON)
headers = {
    "Authorization": f"Bearer {api_key}",
    "Content-Type": "application/json"
}

# JSON payload (model + input text)
payload = {
    "model": "text-embedding-3-small",
    "input": text
}

# Create and send POST request
req = urllib.request.Request(
    url,
    data=json.dumps(payload).encode("utf-8"),
    headers=headers,
    method="POST"
)

ctx = ssl.create_default_context()

try:
    with urllib.request.urlopen(req, context=ctx, timeout=30) as resp:
        data = json.loads(resp.read().decode("utf-8"))
        emb = data["data"][0]["embedding"]
        return [float(x) for x in emb]
except urllib.error.HTTPError as e:
    body = e.read().decode("utf-8", errors="ignore")
    raise Exception(f"OpenAI HTTP {e.code}. Body: {body[:400]} ...")
$$;

SELECT set_config('api.openai_api_key','sk-...YOUR_KEY...', false);
SELECT api.openai_embed('waterproof trail running shoes');
SELECT api.openai_embed('waterproof trail running shoes')::vector(1536) AS embedding_vec;
SELECT vector_dims(api.openai_embed('waterproof trail running shoes')::vector(1536)) AS dims;

# More robust error handling:
CREATE OR REPLACE FUNCTION api.openai_embed(input_text text)
RETURNS float4[]
LANGUAGE plpython3u
AS $$
import json, ssl, time, random, urllib.request, urllib.error

def call_openai(payload, api_key, org):
    req = urllib.request.Request(
        "https://api.openai.com/v1/embeddings",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}",
            "User-Agent": "aidb-postgres-plpython/1.0",
            **({"OpenAI-Organization": org} if org else {})
        }
    )
    ctx = ssl.create_default_context()
    with urllib.request.urlopen(req, context=ctx, timeout=30) as resp:
        raw = resp.read().decode("utf-8")
        return json.loads(raw)

rv = plpy.execute("""
    SELECT current_setting('api.openai_api_key', true) AS k,
           current_setting('api.openai_organization', true) AS o
""")
api_key = rv[0]["k"] if rv and rv[0]["k"] is not None else None
org     = rv[0]["o"] if rv and rv[0]["o"] is not None else None
if not api_key:
    raise Exception("OpenAI API key not set. Use: SELECT set_config('api.openai_api_key','sk-...','f');")

payload = {"model":"text-embedding-3-small","input": input_text or ""}

attempts = 6
for i in range(attempts):
    try:
        data = call_openai(payload, api_key, org)

        # Validate response structure for clearer errors
        if "data" not in data or not data["data"] or "embedding" not in data["data"][0]:
            raise Exception(f"Unexpected OpenAI response shape: keys={list(data.keys())}")

        emb = data["data"][0]["embedding"]
        if not isinstance(emb, list):
            raise Exception("Embedding is not a list in OpenAI response")

        return [float(x) for x in emb]

    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="ignore")
        # Retry only on transient HTTP errors
        if e.code not in (429, 500, 502, 503, 504) or i == attempts - 1:
            raise Exception(f"OpenAI HTTP {e.code} (attempt {i+1}/{attempts}). Body: {body[:400]} ...")

        # If rate-limited, honor Retry-After when present
        retry_after = None
        try:
            retry_after = e.headers.get("Retry-After")
        except Exception:
            retry_after = None

        if retry_after:
            try:
                sleep_s = float(retry_after)
            except Exception:
                sleep_s = (2 ** i) * 0.5 + random.uniform(0, 0.3)
        else:
            sleep_s = (2 ** i) * 0.5 + random.uniform(0, 0.3)

        time.sleep(sleep_s)

    except urllib.error.URLError as e:
        # Common transient network error
        if i == attempts - 1:
            raise
        time.sleep((2 ** i) * 0.5 + random.uniform(0, 0.2))

    except Exception as e:
        # Fail fast on unexpected errors on last attempt; otherwise short backoff
        if i == attempts - 1:
            raise
        time.sleep((2 ** i) * 0.5 + random.uniform(0, 0.2))
$$;

-- Example Usage: Creating Embeddings for Product Categories
SELECT
  c.id,
  c.label,
  api.openai_embed(coalesce(c.label,'') || ' ' || coalesce(c.description,''))::vector(1536) AS embedding
FROM product.category c
WHERE c.id = 1;

-- Batch Embedding of Products and Storing in product_embedding Table
CREATE OR REPLACE FUNCTION api.embed_products(batch_size int DEFAULT 200)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    r RECORD;
    done_count int := 0;
BEGIN
    FOR r IN
        SELECT p.id, p.label, p.shortdescription, p.longdescription,
               pc.label AS category_label,
               pb.label AS brand_label
        FROM product.product p
        JOIN product.category pc ON pc.id = p.category_id
        JOIN product.brand    pb ON pb.id = p.brand_id
        LEFT JOIN embeddings.product_embedding pe ON pe.product_id = p.id
        WHERE pe.product_id IS NULL
        ORDER BY p.id
        LIMIT batch_size
    LOOP
        BEGIN
            MERGE INTO embeddings.product_embedding AS target
            USING (SELECT r.id AS product_id) AS source
            ON (target.product_id = source.product_id)
            WHEN NOT MATCHED THEN
              INSERT (product_id, embedding)
              VALUES (r.id, api.openai_embed(
                  coalesce(r.label, '') || ' ' ||
                  coalesce(r.brand_label, '') || ' ' ||
                  coalesce(r.category_label, '') || ' ' ||
                  coalesce(r.shortdescription, '') || ' ' ||
                  coalesce(r.longdescription, '')));
            done_count := done_count + 1;
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Failed to embed product id %: %', r.id, SQLERRM;
        END;
    END LOOP;

    RETURN done_count;
END;
$$;

-- Example call to embed a batch of 200 products
SELECT api.embed_products(200);

-- Example Similarity Search using the Created Embeddings
WITH q AS (
  SELECT api.openai_embed('Show me premium men''s clothes for a formal occasion')::vector(1536) AS qvec
)
SELECT
  p.id,
  p.label,
  1 - (pe.embedding <=> q.qvec) AS similarity
FROM q
JOIN embeddings.product_embedding pe ON TRUE
JOIN product.product p ON p.id = pe.product_id
ORDER BY pe.embedding <=> q.qvec
LIMIT 10;

-- Example Similarity Search with Additional Hard Constraints
WITH q AS (
  SELECT api.openai_embed('Show me premium men''s clothes for a formal occasion')::vector(1536) AS qvec
)
SELECT
  DISTINCT
  p.id,
  p.label,
  pvp.price,
  1 - (pe.embedding <=> q.qvec) AS similarity
FROM q
JOIN embeddings.product_embedding pe ON TRUE
JOIN product.product p ON p.id = pe.product_id
JOIN product.product_variant pv ON pv.product_id = p.id
JOIN product.product_variant_price pvp
  ON pvp.product_variant_id = pv.id
 AND pvp.current = true
WHERE pvp.price <= 500  -- example hard constraint
LIMIT 10;

-- Retrieve the Embedding for a Specific Product
SELECT pe.embedding FROM embeddings.product_embedding pe WHERE product_id = 9;

-- Find Top 3 Similar Products to a Given Query
WITH
query_embedding AS (
  SELECT api.openai_embed('Men''s leather jacket by Boss')::vector(1536) AS qvec
),
prod_w_embedding AS (
  SELECT p.id, p.label, pe.embedding
  FROM product.product p
  JOIN embeddings.product_embedding pe ON p.id = pe.product_id
)
SELECT
  pwe.id,
  pwe.label,
  1 - (pwe.embedding <=> qe.qvec) AS similarity
FROM prod_w_embedding pwe, query_embedding qe
ORDER BY pwe.embedding <=> qe.qvec
LIMIT 3;

-- Spotify-style Song Recommendation Example
 WITH taste AS (
  SELECT api.openai_embed(
    'I like classic menswear, tailored fits, neutral colors, premium brands'
  )::vector(1536) AS tvec
)
SELECT
  p.id,
  p.label,
  1 - (pe.embedding <=> taste.tvec) AS similarity
FROM taste
JOIN embeddings.product_embedding pe ON TRUE
JOIN product.product p ON p.id = pe.product_id
ORDER BY pe.embedding <=> taste.tvec
LIMIT 5;

