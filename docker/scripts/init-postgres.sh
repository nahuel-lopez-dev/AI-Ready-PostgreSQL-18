#!/bin/bash
set -euo pipefail

: "${PGDATA:=/var/lib/pgsql/18/data}"
: "${PG_LOG_DIRECTORY:=/var/log/postgresql}"
: "${PG_PORT:=5432}"

mkdir -p "${PGDATA}" "${PG_LOG_DIRECTORY}"
chown -R postgres:postgres "${PGDATA}" "${PG_LOG_DIRECTORY}"

if [[ ! -f "${PGDATA}/PG_VERSION" ]]; then
  echo "Initializing database in ${PGDATA}..."
  su - postgres -c "/usr/pgsql-18/bin/initdb -D '${PGDATA}'"
fi

/usr/local/bin/render-postgresql-conf.sh

# Trust config unchanged (as requested)
cat > "${PGDATA}/pg_hba.conf" <<'HBACONF'
# TYPE  DATABASE        USER            ADDRESS                 METHOD
local   all             all                                     trust
host    all             all             127.0.0.1/32            scram-sha-256
host    all             all             ::1/128                 scram-sha-256
host    all             all             0.0.0.0/0               scram-sha-256
HBACONF
chown postgres:postgres "${PGDATA}/pg_hba.conf"

echo "Starting PostgreSQL (bootstrap)..."
su - postgres -c "/usr/pgsql-18/bin/pg_ctl -D '${PGDATA}' -l '${PG_LOG_DIRECTORY}/postgresql.log' start"

until /usr/pgsql-18/bin/pg_isready -p "${PG_PORT}" >/dev/null 2>&1; do
  sleep 1
done

/usr/local/bin/ensure-users-db.sh
/usr/local/bin/ensure-extensions.sh
/usr/local/bin/run-init-scripts.sh

echo "Stopping PostgreSQL (handoff to foreground run)..."
su - postgres -c "/usr/pgsql-18/bin/pg_ctl -D '${PGDATA}' -m fast stop" || true
rm -f "${PGDATA}/postmaster.pid"

echo "Init complete."
