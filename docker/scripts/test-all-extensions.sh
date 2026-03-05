#!/bin/bash
set -euo pipefail

: "${POSTGRES_USER:=postgres}"
: "${POSTGRES_DB:=postgres}"

echo "=== Testing extensions in ${POSTGRES_DB} ==="

# Inventory
/usr/pgsql-18/bin/psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -v ON_ERROR_STOP=1 -c "
SELECT extname, extversion FROM pg_extension ORDER BY extname;
"

# pgvector sanity
/usr/pgsql-18/bin/psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -v ON_ERROR_STOP=1 -c "
SELECT '[1,2,3]'::vector as test_vector;
"

echo "=== Testing pg_background extension ==="
/usr/pgsql-18/bin/psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -v ON_ERROR_STOP=1 -c "
CREATE EXTENSION IF NOT EXISTS pg_background;

-- Cast to text so function resolution is unambiguous
SELECT * FROM pg_background_result(
  pg_background_launch('SELECT 42'::text)
) AS t(result int);
"

echo "=== OK: tests passed ==="
