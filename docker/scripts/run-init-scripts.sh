#!/bin/bash
set -euo pipefail

: "${PG_INIT_DIR:=/docker-entrypoint-initdb.d}"
: "${POSTGRES_DB:=postgres}"

if [[ ! -d "${PG_INIT_DIR}" ]]; then
  exit 0
fi

shopt -s nullglob

echo "Running init scripts in ${PG_INIT_DIR}..."
for f in "${PG_INIT_DIR}"/*; do
  case "$f" in
    *.sql)
      echo "  - $f (sql)"
      su - postgres -c "/usr/pgsql-18/bin/psql -v ON_ERROR_STOP=1 -d '${POSTGRES_DB}' -f '$f'"
      ;;
    *.sh)
      echo "  - $f (sh)"
      bash "$f"
      ;;
    *)
      echo "  - $f (ignored)"
      ;;
  esac
done
