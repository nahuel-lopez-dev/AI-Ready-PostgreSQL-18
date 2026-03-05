#!/bin/bash
set -euo pipefail

: "${POSTGRES_DB:=postgres}"

psql_in_db() {
  local sql="$1"
  su - postgres -c "/usr/pgsql-18/bin/psql -v ON_ERROR_STOP=1 -d '${POSTGRES_DB}' -c \"${sql}\""
}

echo "Ensuring extensions in ${POSTGRES_DB}..."
extensions=(pg_stat_statements vector pg_ivm pg_background pg_squeeze pgaudit plpgsql_check plpython3u)

for ext in "${extensions[@]}"; do
  if ! psql_in_db "CREATE EXTENSION IF NOT EXISTS ${ext};" >/dev/null 2>&1; then
    echo "  - warning: could not create extension '${ext}' (skipping)"
  else
    echo "  - ok: ${ext}"
  fi
done
