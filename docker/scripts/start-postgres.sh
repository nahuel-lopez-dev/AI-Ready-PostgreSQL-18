#!/bin/bash
set -euo pipefail

: "${PGDATA:=/var/lib/pgsql/18/data}"
: "${PG_LOG_DIRECTORY:=/var/log/postgresql}"
: "${PG_PORT:=5432}"

chown -R postgres:postgres "${PGDATA}" "${PG_LOG_DIRECTORY}"

# First-run init or re-render includes (so env updates apply on restart)
if [[ ! -f "${PGDATA}/PG_VERSION" ]]; then
  /usr/local/bin/init-postgres.sh
else
  /usr/local/bin/render-postgresql-conf.sh
fi

# If a server is already running, don't start a second one.
if /usr/pgsql-18/bin/pg_isready -h localhost -p "${PG_PORT}" >/dev/null 2>&1; then
  echo "PostgreSQL already running on port ${PG_PORT}. Not starting another instance."
  # Keep container alive by waiting on the server process (best effort)
  exec su - postgres -c "ps -eo pid,comm | awk '\$2==\"postgres\" {print \$1; exit}' | xargs -r tail --pid"
fi

# If PID file exists but server isn't ready, remove stale pid file (common after unclean stop)
if [[ -f "${PGDATA}/postmaster.pid" ]]; then
  echo "Warning: postmaster.pid exists but server not ready; removing stale pid file."
  rm -f "${PGDATA}/postmaster.pid"
fi

echo ""
echo "=== PostgreSQL 18 Starting (foreground) ==="
echo "  Host: localhost"
echo "  Port: ${PG_PORT}"
echo "  DB:   ${POSTGRES_DB:-postgres}"
echo "  User: ${POSTGRES_USER:-postgres}"
echo "  Preload: ${PG_SHARED_PRELOAD_LIBRARIES:-}"
echo "  Init dir: ${PG_INIT_DIR:-/docker-entrypoint-initdb.d}"
echo ""

# Run postgres in the foreground as PID 1 (Docker-native)
echo "Starting PostgreSQL (bootstrap)..."

exec su - postgres -c "/usr/pgsql-18/bin/postgres -D '${PGDATA}'"
