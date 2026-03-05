#!/bin/bash
set -euo pipefail

: "${POSTGRES_USER:=postgres}"
: "${POSTGRES_DB:=postgres}"
: "${POSTGRES_PASSWORD:=}"

psql_as_postgres() {
  # Pass ONE string to su -c to avoid word-splitting bugs.
  local sql="$1"
  su - postgres -c "/usr/pgsql-18/bin/psql -v ON_ERROR_STOP=1 -d postgres -c \"${sql}\""
}

# Set postgres password if provided
if [[ -n "${POSTGRES_PASSWORD}" ]]; then
  # Escape single quotes in password (basic safety)
  esc_pw="${POSTGRES_PASSWORD//\'/\'\'}"
  psql_as_postgres "ALTER USER postgres PASSWORD '${esc_pw}';"
fi

# Create user if requested
if [[ "${POSTGRES_USER}" != "postgres" ]]; then
  esc_user="${POSTGRES_USER//\"/\"\"}"
  psql_as_postgres "DO \$\$BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='${esc_user}') THEN
      CREATE ROLE ${POSTGRES_USER} WITH LOGIN SUPERUSER CREATEDB CREATEROLE REPLICATION;
    END IF;
  END\$\$;"

  if [[ -n "${POSTGRES_PASSWORD}" ]]; then
    esc_pw="${POSTGRES_PASSWORD//\'/\'\'}"
    psql_as_postgres "ALTER USER ${POSTGRES_USER} PASSWORD '${esc_pw}';"
  fi
fi

# Create DB if requested
if [[ "${POSTGRES_DB}" != "postgres" ]]; then
  esc_db="${POSTGRES_DB//\"/\"\"}"
  psql_as_postgres "DO \$\$BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_database WHERE datname='${esc_db}') THEN
      CREATE DATABASE ${POSTGRES_DB} OWNER ${POSTGRES_USER};
    END IF;
  END\$\$;"
fi
