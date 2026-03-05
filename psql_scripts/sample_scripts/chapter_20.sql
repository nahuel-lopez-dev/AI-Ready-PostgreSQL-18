/* ============================================================================

Code samples for Chapter 20 - PostgreSQL and MCP: the blueprint for a robust AI assistant

This is continuation of Chapter 19.sql. Chapter 19 creates embedding 
and we are going to leverage those here for similarity search. 

This code should be executed against aidb.

*/

CREATE OR REPLACE FUNCTION api.sf_similar_items(
  p_query_text text,
  p_k          integer DEFAULT 10
)
RETURNS TABLE (
  product_id       integer,
  name             text,
  category         text,
  shortdescription text,
  longdescription  text,
  price            numeric,
  distance         double precision
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, api, product, embeddings
AS $$
DECLARE
  v_qvec vector(1536);
BEGIN
  v_qvec := api.openai_embed(p_query_text)::vector(1536);

  RETURN QUERY
  WITH res AS MATERIALIZED (
    SELECT
      p.id                      AS product_id,
      p.label::text             AS name,
      c.label::text             AS category,
      p.shortdescription::text  AS shortdescription,
      p.longdescription::text   AS longdescription,
      pvp.price                 AS price,
      (v_qvec <=> pe.embedding) AS distance
    FROM product.product p
    JOIN embeddings.product_embedding pe
      ON pe.product_id = p.id
    JOIN product.category c
      ON c.id = p.category_id
    JOIN product.product_variant pv
      ON pv.product_id = p.id
    JOIN product.product_variant_price pvp
      ON pvp.product_variant_id = pv.id
     AND pvp.current = true
    ORDER BY pe.embedding <=> v_qvec
  )
  SELECT
    res.product_id,
    res.name,
    res.category,
    res.shortdescription,
    res.longdescription,
    res.price,
    res.distance
  FROM res
  LIMIT p_k;
END;
$$;

COMMENT ON FUNCTION api.sf_similar_items(text, integer)
IS 'Return top-k products similar to query text using embedding distance.';

SELECT product_id, name, category, price FROM api.sf_similar_items('looking for tailored clothing', 1);

CREATE OR REPLACE FUNCTION api.sf_answer_with_openai(
  p_question text,
  p_rows     jsonb
)
RETURNS text
LANGUAGE plpython3u
VOLATILE
SECURITY DEFINER
SET search_path = pg_catalog, public, api, product, embeddings
AS $$
import json
import random
import ssl
import time
import urllib.error
import urllib.request


def _get_guc(p_name: str):
    v_rv = plpy.execute(
        "SELECT current_setting(%s, true) AS v",
        [p_name],
    )
    if not v_rv or v_rv[0]["v"] is None:
        return None
    return v_rv[0]["v"]


def _call_openai_chat_completions(p_payload: dict, p_api_key: str, p_org):
    v_headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {p_api_key}",
        "User-Agent": "pg18book-plpython-openai-chat/1.0",
    }
    if p_org:
        v_headers["OpenAI-Organization"] = p_org

    v_req = urllib.request.Request(
        url="https://api.openai.com/v1/chat/completions",
        data=json.dumps(p_payload).encode("utf-8"),
        headers=v_headers,
        method="POST",
    )

    v_ctx = ssl.create_default_context()

    with urllib.request.urlopen(v_req, context=v_ctx, timeout=30) as v_resp:
        v_raw = v_resp.read().decode("utf-8", errors="replace")
        return json.loads(v_raw)


def _extract_content(p_data: dict) -> str:
    if "choices" not in p_data or not p_data["choices"]:
        raise Exception("Unexpected OpenAI response: missing choices")

    v_msg = p_data["choices"][0].get("message", {})
    v_content = v_msg.get("content", None)
    if v_content is None:
        raise Exception("Unexpected OpenAI response: missing message content")

    return str(v_content).strip()


v_api_key = _get_guc("api.openai_api_key")
v_org = _get_guc("api.openai_organization")

if not v_api_key:
    raise Exception(
        "OpenAI API key not set. Use: "
        "SELECT set_config('api.openai_api_key','sk-...','f');"
    )

v_rows = json.dumps(p_rows)

v_system = (
    "You are a helpful assistant.\n"
    "Take the user question and the SQL rows returned, and write a clear, "
    "human reply.\n"
    "- Mention the question.\n"
    "- Summarize how many results were found.\n"
    "- List items with their label, price if present, and category.\n"
    "- Do not invent anything beyond rows JSON.\n"
    "Schema tables/columns:\n"
    "- product.product(id, category_id, brand_id, label, shortdescription, "
    "longdescription)\n"
    "- embeddings.product_embedding(product_id, embedding)\n"
    "- product.category(id, label, description)\n"
    "- product.brand(id, label, description)\n"
    "- product.product_variant(id, product_id, attributes)\n"
    "- product.product_variant_price(id, product_variant_id, price, validity, "
    "current)\n"
    "- api.category_complements(category_name, complements)\n"
    "\n"
    "Rules:\n"
    "- Categories are broad: product.category.label values like 'Jeans', "
    "'Shirt', 'Skirt'.\n"
    "- Gender words (women, men, kids) appear in product.label, NOT in "
    "category.\n"
    "- Price: product_variant_price.price (alias pvp).\n"
    "- Color/size attributes are in product_variant.attributes (JSONB).\n"
    "- Category: product.category.label (alias pc). Join pc ON pc.id = "
    "p.category_id.\n"
    "- To use price/color: JOIN product_variant pv ON pv.product_id = p.id "
    "AND JOIN product_variant_price pvp ON pvp.product_variant_id = pv.id.\n"
    "- Use LOWER() for case-insensitive filters, e.g. LOWER(p.name) LIKE "
    "'%women%'.\n"
    "- Only SELECT. No semicolons.\n"
    "- Prefer clear aliases (product_name, price).\n"
    "- If no rows are returned just respond.\n"
)

v_user = f"Question: {p_question}\n\nRows: {v_rows}"

v_payload = {
    "model": "gpt-4o-mini",
    "messages": [
        {"role": "system", "content": v_system},
        {"role": "user", "content": v_user},
    ],
    "temperature": 0.2,
    "max_tokens": 500,
}

v_attempts = 6

for v_i in range(v_attempts):
    try:
        v_data = _call_openai_chat_completions(v_payload, v_api_key, v_org)
        return _extract_content(v_data)

    except urllib.error.HTTPError as v_e:
        v_body = v_e.read().decode("utf-8", errors="ignore") if hasattr(v_e, "read") else ""
        v_code = getattr(v_e, "code", None)

        v_transient = v_code in (429, 500, 502, 503, 504)
        v_last = (v_i == v_attempts - 1)

        if (not v_transient) or v_last:
            raise Exception(
                f"OpenAI HTTP {v_code} (attempt {v_i + 1}/{v_attempts}). "
                f"Body: {v_body[:400]} ..."
            )

        v_retry_after = None
        try:
            v_retry_after = v_e.headers.get("Retry-After")
        except Exception:
            v_retry_after = None

        if v_retry_after:
            try:
                v_sleep_s = float(v_retry_after)
            except Exception:
                v_sleep_s = (2 ** v_i) * 0.5 + random.uniform(0, 0.3)
        else:
            v_sleep_s = (2 ** v_i) * 0.5 + random.uniform(0, 0.3)

        time.sleep(v_sleep_s)

    except urllib.error.URLError:
        v_last = (v_i == v_attempts - 1)
        if v_last:
            raise
        time.sleep((2 ** v_i) * 0.5 + random.uniform(0, 0.2))

    except Exception:
        v_last = (v_i == v_attempts - 1)
        if v_last:
            raise
        time.sleep((2 ** v_i) * 0.5 + random.uniform(0, 0.2))
$$;

COMMENT ON FUNCTION api.sf_answer_with_openai(text, jsonb)
IS 'Call OpenAI chat completions to produce a human answer from a question and SQL rows.';

CREATE OR REPLACE FUNCTION api.sf_chat(
  p_question text,
  p_k        integer DEFAULT 10
)
RETURNS TABLE (
  assistant_text text,
  rows           jsonb
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, api, product, embeddings
AS $$
DECLARE
  v_data jsonb;
BEGIN
  SELECT jsonb_agg(t)
  INTO v_data
  FROM (
    SELECT
      s.product_id,
      s.name,
      s.category,
      s.shortdescription,
      s.longdescription,
      s.price,
      s.distance
    FROM api.sf_similar_items(p_question, p_k) s
  ) t;

  assistant_text := api.answer_with_openai(p_question, v_data);
  rows := coalesce(v_data, '[]'::jsonb);

  RETURN NEXT;
END;
$$;

COMMENT ON FUNCTION api.sf_chat(text, integer)
IS 'Return an assistant answer and the underlying rows for a question via embeddings search.';

SELECT * FROM api.sf_chat('looking for tailored clothing', 1);

/* Robust version of sf_similar_items using embeddings.sf_get_query_embedding */
CREATE OR REPLACE FUNCTION api.sf_similar_items(
  p_query_text text,
  p_k          integer DEFAULT 10
)
RETURNS TABLE (
  product_id       integer,
  name             text,
  category         text,
  shortdescription text,
  longdescription  text,
  price            numeric,
  distance         double precision
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, api, product, embeddings
AS $$
DECLARE
  v_qvec vector(1536);
BEGIN
  v_qvec := embeddings.sf_get_query_embedding(p_query_text)::vector(1536);

  RETURN QUERY
  WITH res AS MATERIALIZED (
    SELECT
      p.id                      AS product_id,
      p.label::text             AS name,
      c.label::text             AS category,
      p.shortdescription::text  AS shortdescription,
      p.longdescription::text   AS longdescription,
      pvp.price                 AS price,
      (v_qvec <=> pe.embedding) AS distance
    FROM product.product p
    JOIN embeddings.product_embedding pe
      ON pe.product_id = p.id
    JOIN product.category c
      ON c.id = p.category_id
    JOIN product.product_variant pv
      ON pv.product_id = p.id
    JOIN product.product_variant_price pvp
      ON pvp.product_variant_id = pv.id
     AND pvp.current = true
    ORDER BY pe.embedding <=> v_qvec
  )
  SELECT
    res.product_id,
    res.name,
    res.category,
    res.shortdescription,
    res.longdescription,
    res.price,
    res.distance
  FROM res
  LIMIT p_k;
END;
$$;


/* Example SQL query to find products with "polo" in the label and price <= 80 */
/* safe query */
SELECT
  p.id,
  p.label,
  c.label AS category,
  pvp.price,
  pv.attributes->>'color' AS color
FROM product.product p
JOIN product.category c ON c.id = p.category_id
JOIN product.product_variant pv ON pv.product_id = p.id
JOIN product.product_variant_price pvp
  ON pvp.product_variant_id = pv.id
 AND pvp.current = true
WHERE LOWER(p.label) LIKE '%polo%'
  AND pvp.price <= 80
LIMIT 3;

/* Function to safely execute user-provided SELECT queries with guardrails */

CREATE OR REPLACE FUNCTION api.sf_safe_select(
  p_sql      text,
  p_max_rows integer DEFAULT 50
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, api, product, embeddings
AS $$
DECLARE
  v_sql  text;
  v_rows jsonb;
BEGIN
  --- Normalize whitespace
  v_sql := regexp_replace(coalesce(p_sql, ''), '\s+', ' ', 'g');

  --- Single statement only (reject semicolons)
  IF position(';' IN v_sql) > 0 THEN
    RAISE EXCEPTION 'Only a single SELECT statement is allowed (no semicolons).'
      USING ERRCODE = '42601';
  END IF;

  --- Must start with SELECT or WITH (CTE)
  IF NOT (v_sql ~* '^\s*(select|with)\y') THEN
    RAISE EXCEPTION 'Only SELECT queries are allowed.'
      USING ERRCODE = '42501';
  END IF;

  --- Reject dangerous keywords (defense-in-depth)
  IF v_sql ~* '\y(insert|update|delete|merge|drop|alter|create|truncate|grant|revoke|comment|vacuum|analyze|copy|call|do)\y' THEN
    RAISE EXCEPTION 'Non-SELECT keywords detected. Query rejected.'
      USING ERRCODE = '42501';
  END IF;

  --- Disallow system schemas
  IF v_sql ~* '\y(pg_catalog|information_schema)\y' THEN
    RAISE EXCEPTION 'System schemas are not allowed.'
      USING ERRCODE = '42501';
  END IF;

  --- Require allowed schemas (intentionally strict)
  IF v_sql !~* '\y(product|api|embeddings)\.' THEN
    RAISE EXCEPTION
      'Query must reference allowed schemas (product., embeddings., api.).'
      USING ERRCODE = '42501';
  END IF;

  --- Add LIMIT only if missing
  IF v_sql !~* '\ylimit\y' THEN
    --- If query ends with FOR UPDATE/SHARE variants, insert LIMIT before it
    IF v_sql ~* '\yfor\s+(update|share|no\s+key\s+update|key\s+share)\y\s*$' THEN
      v_sql := regexp_replace(
        v_sql,
        '(\yfor\s+(update|share|no\s+key\s+update|key\s+share)\y\s*)$',
        format(' LIMIT %s \1', p_max_rows),
        1, 1, 'i'
      );
    ELSE
      v_sql := v_sql || format(' LIMIT %s', p_max_rows);
    END IF;
  END IF;

  --- Wrap to return JSON
  v_sql := format(
    'SELECT coalesce(jsonb_agg(t), ''[]''::jsonb) FROM (%s) t',
    v_sql
  );

  EXECUTE v_sql INTO v_rows;

  RETURN coalesce(v_rows, '[]'::jsonb);
END;
$$;

COMMENT ON FUNCTION api.sf_safe_select(text, integer)
IS 'Execute a single SELECT/CTE query with guardrails and return rows as jsonb.';

/* Example usage of sf_safe_select */
SELECT api.sf_safe_select('INSERT INTO TEST VALUES(1,2)', 3); -- should raise exception
SELECT api.sf_safe_select('SELECT * FROM pg_catalog.pg_class', 4); -- should raise exception
SELECT api.sf_safe_select('SELECT * FROM public.test', 4); -- should raise exception
SELECT api.sf_safe_select('SELECT * FROM product.product WHERE label ILIKE ''%polo%''', 1); -- should work


/* Function to create SQL from Question using OpenAI */
CREATE OR REPLACE FUNCTION api.sf_sql_from_question(
  p_question  text,
  p_row_limit integer DEFAULT 20
)
RETURNS text
LANGUAGE plpython3u
VOLATILE
AS $$
import json
import ssl
import urllib.request

rv = plpy.execute("SELECT current_setting('api.openai_api_key', true) AS k")
v_api_key = rv[0]["k"] if rv and rv[0]["k"] is not None else None
if not v_api_key:
    raise Exception("OpenAI API key not set.")

v_system = f"""
You are a PostgreSQL SQL generator for an e-commerce schema.
Return ONLY SQL (no markdown, no explanation, no semicolons).

Hard rules:
- SELECT or WITH only.
- Must include LIMIT {p_row_limit}.
- Use only these schemas: product, embeddings, api.
- Prefer current price only: JOIN product.product_variant_price pvp ON pvp.product_variant_id = pv.id AND pvp.current = true
- product table: product.product p (id, category_id, brand_id, label, shortdescription, longdescription, image_filename)
- category table: product.category c (id, label, description)
- brand table: product.brand b (id, label, description)
- variants: product.product_variant pv (id, product_id, attributes JSONB)
- price: product.product_variant_price pvp (product_variant_id, price, validity, current)
- For color/size use pv.attributes->>'color', pv.attributes->>'size'
- For case-insensitive text: use LOWER(p.label) LIKE '%...%'

Output columns should be useful: id, label, category, price, and attributes when relevant.
"""

v_user = f"Question: {p_question}"

v_payload = {
  "model": "gpt-4o-mini",
  "messages": [
    {"role": "system", "content": v_system},
    {"role": "user", "content": v_user}
  ],
  "temperature": 0.0,
  "max_tokens": 250
}

v_headers = {
  "Content-Type": "application/json",
  "Authorization": f"Bearer {v_api_key}"
}

v_ctx = ssl.create_default_context()

v_req = urllib.request.Request(
  "https://api.openai.com/v1/chat/completions",
  data=json.dumps(v_payload).encode("utf-8"),
  headers=v_headers
)

with urllib.request.urlopen(v_req, context=v_ctx) as resp:
    v_data = json.loads(resp.read().decode("utf-8"))

v_sql = v_data["choices"][0]["message"]["content"].strip()

# Defensive cleanup: remove trailing semicolons if model slips
v_sql = v_sql.replace(";", "")

return v_sql
$$;

COMMENT ON FUNCTION api.sf_sql_from_question(text, integer)
IS 'Generate a SELECT-only SQL statement (no semicolons) from a question.';

/* Example usage of sf_sql_from_question */
SELECT * FROM api.sf_sql_from_question('Show me polo shirts under $80 with current price', 10);

SELECT * FROM api.sf_dynamic_chat('Show me men''s shirts in blue, include the color attribute', 1);

CREATE OR REPLACE FUNCTION api.sf_dynamic_chat(
  p_question  text,
  p_row_limit integer DEFAULT 20
)
RETURNS TABLE (
  assistant_text text,
  sql_used       text,
  rows           jsonb
)
LANGUAGE plpgsql
VOLATILE
AS $$
DECLARE
  v_sql  text;
  v_rows jsonb;
BEGIN
  --- Ask model for SQL
  v_sql :=  api.sf_sql_from_question(p_question, p_row_limit);

  --- Execute safely (SELECT-only + limit + allowlist)
  v_rows := api.sf_safe_select(v_sql, p_row_limit);

  --- Narrate based only on returned rows
  assistant_text := api.answer_with_openai(p_question, v_rows);
  sql_used := v_sql;
  rows := v_rows;

  RETURN NEXT;
END;
$$;

COMMENT ON FUNCTION api.sf_dynamic_chat(text, integer)
IS 'Generate SQL from a question, run it via safe_select, and answer using returned rows.';

/* Example usage of sf_dynamic_chat */
SELECT * FROM api.sf_dynamic_chat('Show me polo shirts under $80 with current price', 1);


/* Function to route between semantic and dynamic SQL chatbots */
CREATE OR REPLACE FUNCTION api.sf_route_chat(
  p_question  text,
  p_k         integer DEFAULT 10,
  p_row_limit integer DEFAULT 20
)
RETURNS TABLE (
  tool_used      text,
  assistant_text text,
  rows           jsonb
)
LANGUAGE plpgsql
VOLATILE
AS $$
DECLARE
  v_question_lc text := lower(coalesce(p_question, ''));
BEGIN
  /*
    Routing heuristic:
    - If question contains explicit constraints (price, color, size, limit, current,
      category), prefer dynamic SQL chatbot.
    - Otherwise, prefer semantic chatbot.
    This is intentionally conservative: structured constraints should be enforced
    by SQL.
  */

  IF v_question_lc ~ (
       '\yunder\y|\yless than\y|\yprice\y|\$|\ycolor\y|\ysize\y|\ylimit\y|' ||
       '\ycurrent\y|\yin[- ]stock\y|\ycategory\y|\ybrand\y'
     )
  THEN
    tool_used := 'dynamic_sql';

    SELECT dc.assistant_text,
           dc.rows
    INTO assistant_text,
         rows
    FROM api.sf_dynamic_chat(p_question, p_row_limit) dc;

    RETURN NEXT;
  ELSE
    tool_used := 'semantic';

    SELECT c.assistant_text,
           c.rows
    INTO assistant_text,
         rows
    FROM api.sf_chat(p_question, p_k) c;

    RETURN NEXT;
  END IF;
END;
$$;

COMMENT ON FUNCTION api.sf_route_chat(text, integer, integer)
IS 'Route chat to dynamic_sql or semantic tool based on question heuristics.';

/* Example usage of sf_route_chat for dynamic SQL routing  */
SELECT * FROM api.sf_route_chat('Show me one polo shirts under $80 with current price', 1,1);

/* Example usage of sf_route_chat for semantic routing  */
SELECT * FROM api.sf_route_chat('I am looking for tailored clothing', 1,1);


/* Hybrid chat function: semantic search with optional price filter, then answer */
CREATE OR REPLACE FUNCTION api.sf_hybrid_chat(
  p_question   text,
  p_max_price  numeric DEFAULT NULL,
  p_k          integer DEFAULT 20
)
RETURNS TABLE (
  assistant_text text,
  rows           jsonb
)
LANGUAGE plpgsql
VOLATILE
AS $$
DECLARE
  v_data jsonb;
BEGIN
  SELECT jsonb_agg(t)
  INTO v_data
  FROM (
    SELECT
      s.product_id,
      s.name,
      s.category,
      s.shortdescription,
      s.longdescription,
      s.price,
      s.distance
    FROM api.sf_similar_items(p_question, p_k) s
    WHERE (p_max_price IS NULL OR s.price <= p_max_price)
    ORDER BY s.distance
    LIMIT 10
  ) t;

  assistant_text := api.answer_with_openai(p_question, coalesce(v_data, '[]'::jsonb));
  rows := coalesce(v_data, '[]'::jsonb);

  RETURN NEXT;
END;
$$;

COMMENT ON FUNCTION api.sf_hybrid_chat(text, numeric, integer)
IS 'Hybrid chat: semantic search with optional max price filter, then answer using returned rows.';

/* Example usage of sf_hybrid_chat */
SELECT * FROM api.sf_hybrid_chat('something like a leather jacket but lighter', 150, 20);


/* MCP: Example usage of sf_dynamic_chat */
CREATE OR REPLACE FUNCTION api.sf_similar_items_v2(
    p_query_text text DEFAULT NULL,
    p_qvec_in vector(1536) DEFAULT NULL,
    p_k int DEFAULT 10
)
RETURNS TABLE(
    product_id int,
    name text,
    category text,
    shortdescription text,
    longdescription text,
    price numeric,
    distance double precision
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_qvec vector(1536);
    p_k_safe int;
BEGIN
    p_k_safe := GREATEST(1, LEAST(p_k, 50)); -- hard cap

    IF p_qvec_in IS NOT NULL THEN
        v_qvec := p_qvec_in;
    ELSE
        IF p_query_text IS NULL OR btrim(p_query_text) = '' THEN
            RAISE EXCEPTION 'p_query_text or p_qvec_in must be provided';
        END IF;
        SELECT api.embeddings.sf_get_query_embedding(p_query_text)::vector(1536) INTO v_qvec;
    END IF;

    RETURN QUERY
    WITH res AS MATERIALIZED (
      SELECT
          p.id                     AS product_id,
          p.label::text            AS name,
          c.label::text            AS category,
          p.shortdescription::text  AS shortdescription,
          p.longdescription::text   AS longdescription,
          pvp.price                AS price,
          (v_qvec <=> pe.embedding)  AS distance
      FROM product.product p
      JOIN embeddings.product_embedding pe ON p.id = pe.product_id
      JOIN product.category c ON c.id = p.category_id
      JOIN product.product_variant pv ON pv.product_id = p.id
      JOIN product.product_variant_price pvp
        ON pvp.product_variant_id = pv.id
       AND pvp.current = true
      ORDER BY pe.embedding <=> v_qvec
    )
    SELECT * FROM res
    LIMIT p_k_safe;
END;
$$;

WITH q AS (
  SELECT embeddings.sf_get_query_embedding('looking for tailored clothing') AS qvec
)
SELECT *
FROM q, api.sf_similar_items_v2(NULL, q.qvec, 5);


/* Audit log table for API chatbot usage */

CREATE TABLE IF NOT EXISTS api.chat_audit_log (
  id bigserial PRIMARY KEY,
  created_at timestamptz NOT NULL DEFAULT now(),
  tool_used text NOT NULL,
  question text NOT NULL,
  sql_used text,
  row_count int,
  success boolean NOT NULL DEFAULT true,
  error text
);

INSERT INTO api.chat_audit_log(tool_used, question, sql_used, row_count, success)
VALUES ('dynamic_sql', p_question, v_sql, jsonb_array_length(v_rows), true);


/* sf_dynamic_chat with audit logging */
/* Function to create SQL from Question using OpenAI, run safely, and answer along with logging */

CREATE OR REPLACE FUNCTION api.sf_dynamic_chat(
  p_question  text,
  p_row_limit integer DEFAULT 20
)
RETURNS TABLE (
  assistant_text text,
  sql_used       text,
  rows           jsonb
)
LANGUAGE plpgsql
VOLATILE
AS $$
DECLARE
  v_sql  text;
  v_rows jsonb;
BEGIN
  --- Ask model for SQL
   v_sql := api.sf_sql_from_question(p_question, p_row_limit);

  --- Execute safely (SELECT-only + limit + allowlist)
  v_rows := api.sf_safe_select(v_sql, p_row_limit);

  --- Narrate based only on returned rows
  assistant_text := api.answer_with_openai(p_question, v_rows);
  sql_used := v_sql;
  rows := v_rows;
    --- One audit row per successful call
  INSERT INTO api.chat_audit_log (tool_used, question, sql_used, row_count, success)
  VALUES (
    'dynamic_sql',
    p_question,
    v_sql,
    jsonb_array_length(rows),
    true
  );

    RETURN NEXT;

  EXCEPTION WHEN OTHERS THEN
  --- On error, log the exception (assumes error_message column exists)
  INSERT INTO api.chat_audit_log (
    tool_used, question, sql_used, row_count, success, error_message
  )
  VALUES (
    'dynamic_sql',
    p_question,
    v_sql,
    NULL,
    false,
    SQLERRM
  );

  RAISE;
END;
$$;

/* Example usage of sf_dynamic_chat with audit logging */

SELECT * FROM api.sf_dynamic_chat('Show me polo shirts under $80 with current price', 1);

/* View audit log */
SELECT * FROM api.chat_audit_log;

/* MCP Basic router function with audit logging */
CREATE OR REPLACE FUNCTION api.sf_route_chat(
  p_question  text,
  p_k         integer DEFAULT 10,
  p_row_limit integer DEFAULT 20
)
RETURNS TABLE (
  tool_used      text,
  assistant_text text,
  rows           jsonb,
  sql_used       text
)
LANGUAGE plpgsql
VOLATILE
AS $$
DECLARE
  v_q               text := lower(coalesce(p_question, ''));
  v_has_constraints boolean;
  v_has_intent      boolean;
BEGIN
  v_has_constraints :=
    v_q ~ (
      '\yunder\y|\yprice\y|\$|\ycheapest\y|\ymost expensive\y|\ycount\y|\yavg\y|' ||
      '\ygroup\y|\ybrand\y|\ycategory\y|\ycolor\y|\ysize\y'
    );

  v_has_intent :=
    v_q ~ (
      '\ylike\y|\ysimilar\y|\yrecommend\y|\ytailored\y|\yformal\y|\ycasual\y|\yvibe\y'
    );

  --- Hybrid (constraints + intent)
  IF v_has_constraints AND v_has_intent THEN
    tool_used := 'hybrid';
    sql_used := NULL;

    SELECT h.assistant_text,
           h.rows
    INTO assistant_text,
         rows
    FROM api.sf_hybrid_chat(p_question, NULL, greatest(1, least(p_k, 30))) h;

    --- One audit row per successful call
    INSERT INTO api.chat_audit_log (tool_used, question, sql_used, row_count, success)
    VALUES ('hybrid', p_question, NULL, jsonb_array_length(coalesce(rows, '[]'::jsonb)), true);

    RETURN NEXT;
    RETURN;
  END IF;

  --- Dynamic SQL (constraints)
  IF v_has_constraints THEN
    tool_used := 'dynamic_sql';

    SELECT d.assistant_text,
           d.rows,
           d.sql_used
    INTO assistant_text,
         rows,
         sql_used
    FROM api.sf_dynamic_chat(p_question, greatest(1, least(p_row_limit, 50))) d;

    --- One audit row per successful call
    INSERT INTO api.chat_audit_log (tool_used, question, sql_used, row_count, success)
    VALUES (
      'dynamic_sql',
      p_question,
      sql_used,
      jsonb_array_length(coalesce(rows, '[]'::jsonb)),
      true
    );

    RETURN NEXT;
    RETURN;
  END IF;

  --- Semantic default
  tool_used := 'semantic';
  sql_used := NULL;

  SELECT c.assistant_text,
         c.rows
  INTO assistant_text,
       rows
  FROM api.sf_chat(p_question, greatest(1, least(p_k, 30))) c;

  --- One audit row per successful call
  INSERT INTO api.chat_audit_log (tool_used, question, sql_used, row_count, success)
  VALUES ('semantic', p_question, NULL, jsonb_array_length(coalesce(rows, '[]'::jsonb)), true);

  RETURN NEXT;
END;
$$;

COMMENT ON FUNCTION api.sf_route_chat(text, integer, integer)
IS 'Route chat to hybrid, dynamic_sql, or semantic based on heuristics; writes an audit row.';

/* Example usage of sf_route_chat with audit logging */
SELECT tool_used, assistant_text
FROM api.sf_route_chat('looking for tailored clothing', 2, 2);

SELECT tool_used, sql_used, assistant_text
FROM api.sf_route_chat('Show me polo shirts under $80', 2, 2);


/* View audit log */
SELECT * FROM api.chat_audit_log;

-- A role used by the MCP server / assistant runtime
CREATE ROLE mcp_assistant NOINHERIT;

-- Allow it to connect
GRANT CONNECT ON DATABASE aidb TO mcp_assistant;

-- Allow usage on schemas it needs
GRANT USAGE ON SCHEMA api, product, embeddings TO mcp_assistant;

-- Allow SELECT from required tables
GRANT SELECT ON
  product.category,
  product.brand,
  product.product,
  product.product_variant,
  product.product_variant_price,
  embeddings.product_embedding
TO mcp_assistant;

-- Allow execute on the specific functions we expose as tools
GRANT EXECUTE ON FUNCTION
  api.sf_chat(text,int),
  api.sf_similar_items(text,int),
  api.sf_route_chat(text,int,int),
  api.sf_dynamic_chat(text,int)
TO mcp_assistant;

/* Set statement timeout for the role to prevent long-running queries */
ALTER ROLE mcp_assistant SET statement_timeout = '2s';

/* Function-level (inside your executor function)*/
PERFORM set_config('statement_timeout', '2000ms', true);


/* Function to check if a SQL string is a safe SELECT/CTE for basic validation */
CREATE OR REPLACE FUNCTION api.sf_is_safe_select(
  p_sql text
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_sql_lc text := lower(coalesce(p_sql, ''));
BEGIN
  --- Block empty
  IF btrim(v_sql_lc) = '' THEN
    RETURN false;
  END IF;

  --- Only one statement
  IF position(';' IN v_sql_lc) > 0 THEN
    RETURN false;
  END IF;

  --- Must start with SELECT or WITH
  IF v_sql_lc !~ '^\s*(select|with)\y' THEN
    RETURN false;
  END IF;

  --- Block dangerous keywords
  IF v_sql_lc ~ '\y(insert|update|delete|drop|alter|create|truncate|grant|revoke|copy|call|do)\y' THEN
    RETURN false;
  END IF;

  --- Restrict schemas (adjust as needed)
  IF v_sql_lc ~ '\y(pg_catalog|information_schema)\y' THEN
    RETURN false;
  END IF;

  RETURN true;
END;
$$;

COMMENT ON FUNCTION api.sf_is_safe_select(text)
IS 'Return true if the SQL string looks like a single SELECT/CTE and avoids unsafe constructs.';

IF length(btrim(p_question)) < 3 THEN
  RAISE EXCEPTION 'Query too short to embed safely';
END IF;

SELECT embeddings.sf_get_query_embedding(p_question) INTO qvec;

/* View to simplify product search queries for MCP Server*/
CREATE OR REPLACE VIEW api.product_search_vw AS
SELECT
  p.id              AS product_id,
  p.label           AS product_name,
  c.label           AS category,
  b.label           AS brand,
  p.shortdescription AS shortdescription,
  p.longdescription  AS longdescription,
  pv.id             AS product_variant_id,
  pv.attributes     AS attributes,
  pvp.price         AS price
FROM product.product p
JOIN product.category c
  ON c.id = p.category_id
JOIN product.brand b
  ON b.id = p.brand_id
JOIN product.product_variant pv
  ON pv.product_id = p.id
JOIN product.product_variant_price pvp
  ON pvp.product_variant_id = pv.id
 AND pvp.current = true;