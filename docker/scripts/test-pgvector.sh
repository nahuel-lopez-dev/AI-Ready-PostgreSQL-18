#!/bin/bash
set -euo pipefail

: "${POSTGRES_USER:=postgres}"
: "${POSTGRES_DB:=postgres}"

echo "=== Testing pgvector in ${POSTGRES_DB} ==="

/usr/pgsql-18/bin/psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -v ON_ERROR_STOP=1 -c "
CREATE EXTENSION IF NOT EXISTS vector;
SELECT '[1,2,3]'::vector <-> '[4,5,6]'::vector as l2_distance;
SELECT 1 - ('[1,2,3]'::vector <=> '[4,5,6]'::vector) as cosine_similarity;
"

echo "=== OK: pgvector test passed ==="
