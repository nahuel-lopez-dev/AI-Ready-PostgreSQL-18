/* ============================================================================

Code samples for Chapter 19 - Production-Ready AI Embedding Pipeline Patterns

To use the Chapter 19 SQL script, connect to a clean aidb database and run the following 
commands in the psql terminal after connecting to the aidb database.
For creating clean aidb database, you can use the following commands in your terminal:

   psql -f psql_scripts/master_setup.sql -U postgres postgres
   or
   \i psql_scripts/master_setup.sql (from psql)

This chapter assumes that you have the OpenAI API key set in your session for embedding generation
and that no prior embedding jobs or embeddings exist in the database.

*/


CREATE TABLE IF NOT EXISTS embeddings.embedding_job (
  id            bigserial PRIMARY KEY,
  entity_type   text NOT NULL CHECK (entity_type IN ('category','brand','product','variant')),
  entity_id     integer NOT NULL,
  status        text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','running','done','failed')),
  attempts      int  NOT NULL DEFAULT 0,
  last_error    text,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);


CREATE INDEX IF NOT EXISTS embedding_job_pending_idx
  ON embeddings.embedding_job (status, created_at);

CREATE INDEX IF NOT EXISTS embedding_job_entity_idx
  ON embeddings.embedding_job (entity_type, entity_id);

/* Trigger functions to enqueue embedding jobs on relevant table changes.
*/
CREATE OR REPLACE FUNCTION embeddings.sf_enqueue_embedding_job(p_entity_type text, p_entity_id int)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  -- Avoid enqueuing duplicates when multiple updates happen quickly.
  -- If a job is already pending/running for that entity, we do nothing.
  IF EXISTS (
    SELECT 1
    FROM embeddings.embedding_job
    WHERE entity_type = p_entity_type
      AND entity_id   = p_entity_id
      AND status IN ('pending','running')
  ) THEN
    RETURN;
  END IF;

  INSERT INTO embeddings.embedding_job(entity_type, entity_id)
  VALUES (p_entity_type, p_entity_id);
END;
$$;

CREATE OR REPLACE FUNCTION embeddings.trg_enqueue_category_embedding()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM embeddings.sf_enqueue_embedding_job('category', NEW.id);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS enqueue_category_embedding ON product.category;

CREATE TRIGGER enqueue_category_embedding
AFTER INSERT OR UPDATE OF label, description
ON product.category
FOR EACH ROW
EXECUTE FUNCTION embeddings.trg_enqueue_category_embedding();

CREATE OR REPLACE FUNCTION embeddings.trg_enqueue_brand_embedding()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM embeddings.sf_enqueue_embedding_job('brand', NEW.id);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS enqueue_brand_embedding ON product.brand;

CREATE TRIGGER enqueue_brand_embedding
AFTER INSERT OR UPDATE OF label, description
ON product.brand
FOR EACH ROW
EXECUTE FUNCTION embeddings.trg_enqueue_brand_embedding();

CREATE OR REPLACE FUNCTION embeddings.trg_enqueue_product_embedding()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM embeddings.sf_enqueue_embedding_job('product', NEW.id);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS enqueue_product_embedding ON product.product;

CREATE TRIGGER enqueue_product_embedding
AFTER INSERT OR UPDATE OF label, shortdescription, longdescription, category_id, brand_id
ON product.product
FOR EACH ROW
EXECUTE FUNCTION embeddings.trg_enqueue_product_embedding();

CREATE OR REPLACE FUNCTION embeddings.trg_enqueue_variant_embedding()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM embeddings.sf_enqueue_embedding_job('variant', NEW.id);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS enqueue_variant_embedding ON product.product_variant;

CREATE TRIGGER enqueue_variant_embedding
AFTER INSERT OR UPDATE OF attributes
ON product.product_variant
FOR EACH ROW
EXECUTE FUNCTION embeddings.trg_enqueue_variant_embedding();

/* Process embedding jobs in batches; generates embeddings and upserts into per-entity embedding tables.
*/
CREATE OR REPLACE FUNCTION embeddings.sf_process_embedding_jobs(
  p_batch_size integer DEFAULT 50
)
RETURNS integer
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = pg_catalog, embeddings, product, api
AS $function$
DECLARE
  v_job        embeddings.embedding_job%ROWTYPE;
  v_processed  integer := 0;
  v_input_text text;
  v_vec        public.vector(1536);
BEGIN
  FOR v_job IN
    SELECT ej.*
    FROM embeddings.embedding_job ej
    WHERE ej.status = 'pending'
    ORDER BY ej.created_at
    LIMIT p_batch_size
    FOR UPDATE SKIP LOCKED
  LOOP
    BEGIN
      -- Mark running
      UPDATE embeddings.embedding_job ej
      SET status     = 'running',
          attempts   = ej.attempts + 1,
          updated_at = now(),
          last_error = NULL
      WHERE ej.id = v_job.id;

      -- Build input text and upsert the embedding into the correct table.
      IF v_job.entity_type = 'category' THEN
        SELECT coalesce(c.label, '') || ' ' || coalesce(c.description, '')
        INTO v_input_text
        FROM product.category c
        WHERE c.id = v_job.entity_id;

        v_vec := api.openai_embed(v_input_text)::public.vector(1536);

        INSERT INTO embeddings.product_category_embedding (product_category_id, embedding)
        VALUES (v_job.entity_id, v_vec)
        ON CONFLICT (product_category_id)
        DO UPDATE
          SET embedding = EXCLUDED.embedding;

      ELSIF v_job.entity_type = 'brand' THEN
        SELECT coalesce(b.label, '') || ' ' || coalesce(b.description, '')
        INTO v_input_text
        FROM product.brand b
        WHERE b.id = v_job.entity_id;

        v_vec := api.openai_embed(v_input_text)::public.vector(1536);

        INSERT INTO embeddings.product_brand_embedding (product_brand_id, embedding)
        VALUES (v_job.entity_id, v_vec)
        ON CONFLICT (product_brand_id)
        DO UPDATE
          SET embedding = EXCLUDED.embedding;

      ELSIF v_job.entity_type = 'product' THEN
        SELECT
          coalesce(p.label, '') || ' ' ||
          coalesce(b.label, '') || ' ' ||
          coalesce(c.label, '') || ' ' ||
          coalesce(p.shortdescription, '') || ' ' ||
          coalesce(p.longdescription, '')
        INTO v_input_text
        FROM product.product p
        JOIN product.brand b
          ON b.id = p.brand_id
        JOIN product.category c
          ON c.id = p.category_id
        WHERE p.id = v_job.entity_id;

        v_vec := api.openai_embed(v_input_text)::public.vector(1536);

        INSERT INTO embeddings.product_embedding (product_id, embedding)
        VALUES (v_job.entity_id, v_vec)
        ON CONFLICT (product_id)
        DO UPDATE
          SET embedding = EXCLUDED.embedding;

      ELSIF v_job.entity_type = 'variant' THEN
        SELECT coalesce(v.attributes::text, '')
        INTO v_input_text
        FROM product.product_variant v
        WHERE v.id = v_job.entity_id;

        v_vec := api.openai_embed(v_input_text)::public.vector(1536);

        INSERT INTO embeddings.product_variant_embedding (product_variant_id, embedding)
        VALUES (v_job.entity_id, v_vec)
        ON CONFLICT (product_variant_id)
        DO UPDATE
          SET embedding = EXCLUDED.embedding;

      ELSE
        RAISE EXCEPTION 'Unknown entity_type: %', v_job.entity_type
          USING ERRCODE = '22023';
      END IF;

      -- Mark done
      UPDATE embeddings.embedding_job ej
      SET status     = 'done',
          updated_at = now()
      WHERE ej.id = v_job.id;

      v_processed := v_processed + 1;

    EXCEPTION WHEN OTHERS THEN
      -- Mark failed but keep the job for retry/inspection
      UPDATE embeddings.embedding_job ej
      SET status     = 'failed',
          last_error = SQLERRM,
          updated_at = now()
      WHERE ej.id = v_job.id;
    END;
  END LOOP;

  RETURN v_processed;
END;
$function$;

COMMENT ON FUNCTION embeddings.sf_process_embedding_jobs(integer)
IS 'Process pending embedding jobs in batches; generates embeddings and upserts into per-entity embedding tables.';


/* Updates to trigger the process for creating job queue and processing embedding jobs.
This will reset the values to trigger the embedding job creation.
*/

UPDATE product.category
SET description = description
WHERE true;

UPDATE product.brand
SET description = description
WHERE true;

/* Verify the pending jobs in embedding_job table
and process them in batches.
*/
SELECT *
FROM embeddings.embedding_job
WHERE status = 'pending'
ORDER BY created_at LIMIT 10;

/* Process embedding jobs in batches of 50.
*/
SELECT set_config('api.openai_api_key','sk-...YOUR_KEY...', false);

SELECT embeddings.sf_process_embedding_jobs(50);

/* Check successful and failed jobs for inspection. and completed jobs
*/
SELECT * FROM embeddings.embedding_job WHERE status = 'pending' ORDER BY created_at;

SELECT id, entity_type, entity_id, attempts, last_error
FROM embeddings.embedding_job
WHERE status = 'failed'
ORDER BY updated_at DESC;

SELECT id, entity_type, entity_id, attempts, last_error
FROM embeddings.embedding_job
WHERE status = 'done'
ORDER BY updated_at DESC;

/* Neccessary schema changes for next_run_at and max_attempts columns in embedding_job table.
*/

ALTER TABLE embeddings.embedding_job
ADD COLUMN IF NOT EXISTS next_run_at timestamptz NOT NULL DEFAULT now(),
ADD COLUMN IF NOT EXISTS max_attempts int NOT NULL DEFAULT 10;

CREATE INDEX IF NOT EXISTS embedding_job_runnable_idx
  ON embeddings.embedding_job (status, next_run_at, created_at);

/* Adding content_hash column to embedding tables to store hash of input text used for generating embeddings.
*/

ALTER TABLE embeddings.product_category_embedding
ADD COLUMN IF NOT EXISTS content_hash text;

ALTER TABLE embeddings.product_brand_embedding
ADD COLUMN IF NOT EXISTS content_hash text;

ALTER TABLE embeddings.product_embedding
ADD COLUMN IF NOT EXISTS content_hash text;

ALTER TABLE embeddings.product_variant_embedding
ADD COLUMN IF NOT EXISTS content_hash text;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

ALTER TABLE embeddings.embedding_job
ADD COLUMN IF NOT EXISTS next_run_at timestamptz NOT NULL DEFAULT now(),
ADD COLUMN IF NOT EXISTS max_attempts int NOT NULL DEFAULT 10;

CREATE INDEX IF NOT EXISTS embedding_job_runnable_idx
  ON embeddings.embedding_job (status, next_run_at, created_at);

ALTER TABLE embeddings.embedding_job
ADD COLUMN IF NOT EXISTS next_run_at timestamptz NOT NULL DEFAULT now(),
ADD COLUMN IF NOT EXISTS max_attempts int NOT NULL DEFAULT 10;

CREATE INDEX IF NOT EXISTS embedding_job_runnable_idx
  ON embeddings.embedding_job (status, next_run_at, created_at);


--- New version of function based on content hash and new recommendation logic.

CREATE OR REPLACE FUNCTION embeddings.sf_process_embedding_jobs(
  p_batch_size integer DEFAULT 50
)
RETURNS integer
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = pg_catalog, embeddings, product, api, public
AS $function$
DECLARE
  v_job        embeddings.embedding_job%ROWTYPE;
  v_processed  integer := 0;

  v_input_text text;
  v_vec        public.vector(1536);

  v_new_hash   text;
  v_old_hash   text;
BEGIN
  /*
    Pick only runnable jobs:
      - pending or failed
      - next_run_at <= now()
      - attempts < max_attempts
    Use SKIP LOCKED for safe concurrency.
  */
  FOR v_job IN
    SELECT ej.*
    FROM embeddings.embedding_job ej
    WHERE ej.status IN ('pending','failed')
      AND ej.next_run_at <= now()
      AND ej.attempts < ej.max_attempts
    ORDER BY ej.created_at
    LIMIT p_batch_size
    FOR UPDATE SKIP LOCKED
  LOOP
    BEGIN
      -- Mark running (increment attempts)
      UPDATE embeddings.embedding_job ej
      SET status     = 'running',
          attempts   = ej.attempts + 1,
          updated_at = now(),
          last_error = NULL
      WHERE ej.id = v_job.id;

      /*
        Build input_text per entity type
      */
      IF v_job.entity_type = 'category' THEN
        SELECT coalesce(c.label, '') || ' ' || coalesce(c.description, '')
        INTO v_input_text
        FROM product.category c
        WHERE c.id = v_job.entity_id;

      ELSIF v_job.entity_type = 'brand' THEN
        SELECT coalesce(b.label, '') || ' ' || coalesce(b.description, '')
        INTO v_input_text
        FROM product.brand b
        WHERE b.id = v_job.entity_id;

      ELSIF v_job.entity_type = 'product' THEN
        SELECT
          coalesce(p.label, '') || ' ' ||
          coalesce(b.label, '') || ' ' ||
          coalesce(c.label, '') || ' ' ||
          coalesce(p.shortdescription, '') || ' ' ||
          coalesce(p.longdescription, '')
        INTO v_input_text
        FROM product.product p
        JOIN product.brand b ON b.id = p.brand_id
        JOIN product.category c ON c.id = p.category_id
        WHERE p.id = v_job.entity_id;

      ELSIF v_job.entity_type = 'variant' THEN
        -- NOTE: assumes product.product_variant has an attributes column (jsonb/json/etc.)
        SELECT coalesce(v.attributes::text, '')
        INTO v_input_text
        FROM product.product_variant v
        WHERE v.id = v_job.entity_id;

      ELSE
        RAISE EXCEPTION 'Unknown entity_type: %', v_job.entity_type
          USING ERRCODE = '22023';
      END IF;

      -- If the entity row vanished, fail the job (avoids embedding empty content silently)
      IF v_input_text IS NULL THEN
        RAISE EXCEPTION 'No source row found for % id %', v_job.entity_type, v_job.entity_id
          USING ERRCODE = '22023';
      END IF;

      -- Compute content hash (sha256)
      SELECT encode(digest(v_input_text, 'sha256'), 'hex') INTO v_new_hash;

      /*
        Compare with stored hash; if unchanged, skip embedding generation.
        Assumes each embedding table has a content_hash column.
      */
      v_old_hash := NULL;

      IF v_job.entity_type = 'category' THEN
        SELECT e.content_hash
          INTO v_old_hash
        FROM embeddings.product_category_embedding e
        WHERE e.product_category_id = v_job.entity_id;

        IF v_old_hash IS NOT NULL AND v_old_hash = v_new_hash THEN
          UPDATE embeddings.embedding_job
          SET status = 'done', updated_at = now()
          WHERE id = v_job.id;

          v_processed := v_processed + 1;
          CONTINUE;
        END IF;

        v_vec := api.openai_embed(v_input_text)::public.vector(1536);

        INSERT INTO embeddings.product_category_embedding (product_category_id, embedding, content_hash)
        VALUES (v_job.entity_id, v_vec, v_new_hash)
        ON CONFLICT (product_category_id)
        DO UPDATE
          SET embedding     = EXCLUDED.embedding,
              content_hash  = EXCLUDED.content_hash;

      ELSIF v_job.entity_type = 'brand' THEN
        SELECT e.content_hash
          INTO v_old_hash
        FROM embeddings.product_brand_embedding e
        WHERE e.product_brand_id = v_job.entity_id;

        IF v_old_hash IS NOT NULL AND v_old_hash = v_new_hash THEN
          UPDATE embeddings.embedding_job
          SET status = 'done', updated_at = now()
          WHERE id = v_job.id;

          v_processed := v_processed + 1;
          CONTINUE;
        END IF;

        v_vec := api.openai_embed(v_input_text)::public.vector(1536);

        INSERT INTO embeddings.product_brand_embedding (product_brand_id, embedding, content_hash)
        VALUES (v_job.entity_id, v_vec, v_new_hash)
        ON CONFLICT (product_brand_id)
        DO UPDATE
          SET embedding     = EXCLUDED.embedding,
              content_hash  = EXCLUDED.content_hash;

      ELSIF v_job.entity_type = 'product' THEN
        SELECT e.content_hash
          INTO v_old_hash
        FROM embeddings.product_embedding e
        WHERE e.product_id = v_job.entity_id;

        IF v_old_hash IS NOT NULL AND v_old_hash = v_new_hash THEN
          UPDATE embeddings.embedding_job
          SET status = 'done', updated_at = now()
          WHERE id = v_job.id;

          v_processed := v_processed + 1;
          CONTINUE;
        END IF;

        -- keep your sf function here if that’s intended for product
        v_vec := api.openai_embed(v_input_text)::public.vector(1536);

        INSERT INTO embeddings.product_embedding (product_id, embedding, content_hash)
        VALUES (v_job.entity_id, v_vec, v_new_hash)
        ON CONFLICT (product_id)
        DO UPDATE
          SET embedding     = EXCLUDED.embedding,
              content_hash  = EXCLUDED.content_hash;

      ELSIF v_job.entity_type = 'variant' THEN
        SELECT e.content_hash
          INTO v_old_hash
        FROM embeddings.product_variant_embedding e
        WHERE e.product_variant_id = v_job.entity_id;

        IF v_old_hash IS NOT NULL AND v_old_hash = v_new_hash THEN
          UPDATE embeddings.embedding_job
          SET status = 'done', updated_at = now()
          WHERE id = v_job.id;

          v_processed := v_processed + 1;
          CONTINUE;
        END IF;

        v_vec := api.openai_embed(v_input_text)::public.vector(1536);

        INSERT INTO embeddings.product_variant_embedding (product_variant_id, embedding, content_hash)
        VALUES (v_job.entity_id, v_vec, v_new_hash)
        ON CONFLICT (product_variant_id)
        DO UPDATE
          SET embedding     = EXCLUDED.embedding,
              content_hash  = EXCLUDED.content_hash;
      END IF;

      -- Mark done
      UPDATE embeddings.embedding_job
      SET status     = 'done',
          updated_at = now()
      WHERE id = v_job.id;

      v_processed := v_processed + 1;

    EXCEPTION WHEN OTHERS THEN
      /*
        Mark failed and apply exponential backoff + jitter to avoid retry storms.
        Backoff caps at 300 seconds.
        Jitter adds up to ~1 second.
      */
      UPDATE embeddings.embedding_job
      SET status     = 'failed',
          last_error = SQLERRM,
          updated_at = now(),
          next_run_at = now()
            + make_interval(secs =>
                LEAST(
                  300,
                  (2 ^ LEAST(
                         (SELECT attempts FROM embeddings.embedding_job WHERE id = v_job.id),
                         10
                       ))::int
                  + (random() * 1.0)
                )
              )
      WHERE id = v_job.id;
    END;
  END LOOP;

  RETURN v_processed;
END;
$function$;

/* before we try the above function, lets remove the existing jobs and embeddings to start fresh.
*/

TRUNCATE embeddings.embedding_job ;
TRUNCATE embeddings.product_brand_embedding ;
TRUNCATE embeddings.product_embedding ;
TRUNCATE embeddings.product_category_embedding ;
TRUNCATE embeddings.product_variant_embedding ;

/* Lets add new triggers functions
*/
DROP TRIGGER IF EXISTS enqueue_category_embedding ON product.category;
DROP TRIGGER IF EXISTS enqueue_brand_embedding ON product.brand;
DROP TRIGGER IF EXISTS enqueue_variant_embedding ON product.product_variant;

-- Category change (INSERT or UPDATE) => enqueue category + all products in that category
-- 1) CATEGORY: enqueue category + cascade enqueue all products in that category
CREATE OR REPLACE FUNCTION embeddings.sf_trg_enqueue_category_embedding()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  -- enqueue the category itself
  PERFORM embeddings.sf_enqueue_embedding_job('category', NEW.id);

  -- cascade enqueue products referencing this category
  INSERT INTO embeddings.embedding_job(entity_type, entity_id)
  SELECT 'product', p.id
  FROM product.product p
  WHERE p.category_id = NEW.id
  ON CONFLICT DO NOTHING;  -- relies on a unique constraint (entity_type, entity_id) OR similar

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS enqueue_category_embedding ON product.category;

CREATE TRIGGER enqueue_category_embedding
AFTER INSERT OR UPDATE OF label, description
ON product.category
FOR EACH ROW
EXECUTE FUNCTION embeddings.trg_enqueue_category_embedding();


-- 2) BRAND: enqueue brand + cascade enqueue all products for that brand
CREATE OR REPLACE FUNCTION embeddings.trg_enqueue_brand_embedding()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  -- enqueue the brand itself
  PERFORM embeddings.sf_enqueue_embedding_job('brand', NEW.id);

  -- cascade enqueue products referencing this brand
  INSERT INTO embeddings.embedding_job(entity_type, entity_id)
  SELECT 'product', p.id
  FROM product.product p
  WHERE p.brand_id = NEW.id
  ON CONFLICT DO NOTHING;  -- relies on a unique constraint (entity_type, entity_id) OR similar

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS enqueue_brand_embedding ON product.brand;

CREATE TRIGGER enqueue_brand_embedding
AFTER INSERT OR UPDATE OF label, description
ON product.brand
FOR EACH ROW
EXECUTE FUNCTION embeddings.trg_enqueue_brand_embedding();

/* Testing the new recommendation logic with caching of query embeddings.
*/

UPDATE product.category
SET description = description
WHERE true;

UPDATE product.brand
SET description = description
WHERE true;

/* Verify the pending jobs in embedding_job table
and process them in batches.
*/
SELECT *
FROM embeddings.embedding_job
WHERE status = 'pending'
ORDER BY created_at LIMIT 10;

/* Process embedding jobs in batches of 50.
*/
SELECT set_config('api.openai_api_key','sk-...YOUR_KEY...', false);

SELECT embeddings.sf_process_embedding_jobs(50);

SELECT *                                        
FROM embeddings.embedding_job
WHERE status = 'failed'
ORDER BY created_at LIMIT 10;

SELECT *
FROM embeddings.embedding_job
WHERE status = 'done'
ORDER BY created_at LIMIT 10;

SELECT embeddings.sf_process_embedding_jobs(50);

/* Example query using no cached query embeddings for recommendations with hard constraints.
*/

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
LIMIT 5;

/* Now, we create a caching mechanism for query embeddings to speed up repeated queries.
*/

CREATE TABLE IF NOT EXISTS embeddings.query_embedding_cache (
  query_text     text PRIMARY KEY,
  embedding      public.vector(1536) NOT NULL,
  model_id       text NOT NULL,
  created_at     timestamptz NOT NULL DEFAULT now(),
  last_used_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS query_embedding_cache_last_used_idx
  ON embeddings.query_embedding_cache (last_used_at);

/* Function to get (and cache) query embeddings.
*/

CREATE OR REPLACE FUNCTION embeddings.sf_get_query_embedding(
  p_query    text,
  p_model_id text DEFAULT 'text-embedding-3-small'
)
RETURNS public.vector(1536)
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = pg_catalog, embeddings, api
AS $function$
DECLARE
  v_embedding public.vector(1536);
BEGIN
  -- Fast path: cache hit
  SELECT qec.embedding
  INTO v_embedding
  FROM embeddings.query_embedding_cache qec
  WHERE qec.query_text = p_query
    AND qec.model_id    = p_model_id;

  IF v_embedding IS NOT NULL THEN
    UPDATE embeddings.query_embedding_cache qec
    SET last_used_at = now()
    WHERE qec.query_text = p_query
      AND qec.model_id    = p_model_id;

    RETURN v_embedding;
  END IF;

  -- Cache miss: compute embedding
  v_embedding := api.openai_embed(p_query)::public.vector(1536);

  INSERT INTO embeddings.query_embedding_cache (query_text, embedding, model_id, last_used_at)
  VALUES (p_query, v_embedding, p_model_id, now())
  ON CONFLICT (query_text)
  DO UPDATE
    SET embedding    = EXCLUDED.embedding,
        model_id     = EXCLUDED.model_id,
        last_used_at = now();

  RETURN v_embedding;
END;
$function$;

COMMENT ON FUNCTION embeddings.sf_get_query_embedding(text, text)
IS 'Return (and cache) an embedding for the given query text and model id.';

/* Example usage of the cached query embedding function for recommendations.
   First time will compute and cache the embedding. Second time will hit the cache.
*/
WITH q AS (
  SELECT embeddings.sf_get_query_embedding('Show me premium men''s clothes for a formal occasion')::vector(1536) AS qvec
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
LIMIT 5;



DELETE FROM embeddings.query_embedding_cache
WHERE last_used_at < now() - interval '7 days';

ALTER TABLE embeddings.product_embedding
ADD COLUMN IF NOT EXISTS model_id text NOT NULL DEFAULT 'text-embedding-3-small';

WITH q AS (
  SELECT embeddings.sf_get_query_embedding('Show me premium men''s clothes for a formal occasion', 'text-embedding-3-small' )::vector(1536) AS qvec
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
AND pe.model_id = 'text-embedding-3-small'
LIMIT 10;


