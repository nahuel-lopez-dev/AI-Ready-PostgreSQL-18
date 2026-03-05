#!/bin/bash
set -euo pipefail

: "${PGDATA:=/var/lib/pgsql/18/data}"
: "${PG_SHARED_PRELOAD_LIBRARIES:=pg_stat_statements,vector,pg_ivm,pg_background,pg_squeeze,pgaudit}"

conf_dir="${PGDATA}/conf.d"
base_conf="${PGDATA}/postgresql.conf"
env_conf="${conf_dir}/10-docker-env.conf"
user_conf="${conf_dir}/99-user.conf"

mkdir -p "${conf_dir}"
chown -R postgres:postgres "${conf_dir}"

cat > "${base_conf}" <<EOF
# -----------------------------------------------------------------------------
# postgresql.conf (base)
# Keep this file stable. Tunables live in conf.d/*.conf.
# -----------------------------------------------------------------------------
include_if_exists = 'conf.d/10-docker-env.conf'
include_if_exists = 'conf.d/99-user.conf'
EOF

cat > "${env_conf}" <<EOF
# -----------------------------------------------------------------------------
# conf.d/10-docker-env.conf (generated)
# Generated from environment variables at container start.
# -----------------------------------------------------------------------------

# Connection
listen_addresses = '${PG_LISTEN_ADDRESSES}'
port = ${PG_PORT}

# Capacity
max_connections = ${PG_MAX_CONNECTIONS}

# Memory
shared_buffers = '${PG_SHARED_BUFFERS}'
effective_cache_size = '${PG_EFFECTIVE_CACHE_SIZE}'
work_mem = '${PG_WORK_MEM}'
maintenance_work_mem = '${PG_MAINTENANCE_WORK_MEM}'

# Planner / IO
random_page_cost = ${PG_RANDOM_PAGE_COST}
effective_io_concurrency = ${PG_EFFECTIVE_IO_CONCURRENCY}
default_statistics_target = ${PG_DEFAULT_STATISTICS_TARGET}

# WAL / Checkpoints
max_wal_size = '${PG_MAX_WAL_SIZE}'
checkpoint_timeout = '${PG_CHECKPOINT_TIMEOUT}'
wal_level = ${PG_WAL_LEVEL}

# Replication
max_replication_slots = ${PG_MAX_REPLICATION_SLOTS}
max_wal_senders = ${PG_MAX_WAL_SENDERS}
hot_standby = ${PG_HOT_STANDBY}
max_logical_replication_workers = ${PG_MAX_LOGICAL_REPLICATION_WORKERS}

# Workers
max_worker_processes = ${PG_MAX_WORKER_PROCESSES}
max_parallel_workers = ${PG_MAX_PARALLEL_WORKERS}
max_parallel_workers_per_gather = ${PG_MAX_PARALLEL_WORKERS_PER_GATHER}
max_parallel_maintenance_workers = ${PG_MAX_PARALLEL_MAINTENANCE_WORKERS}

# Autovacuum
autovacuum = ${PG_AUTOVACUUM}
autovacuum_max_workers = ${PG_AUTOVACUUM_MAX_WORKERS}

# Logging
log_destination = '${PG_LOG_DESTINATION}'
logging_collector = ${PG_LOGGING_COLLECTOR}
log_directory = '${PG_LOG_DIRECTORY}'
log_filename = '${PG_LOG_FILENAME}'
log_truncate_on_rotation = on
log_rotation_age = ${PG_LOG_ROTATION_AGE}
log_rotation_size = ${PG_LOG_ROTATION_SIZE}
log_line_prefix = '${PG_LOG_LINE_PREFIX}'
log_min_duration_statement = ${PG_LOG_MIN_DURATION_STATEMENT}
log_statement = '${PG_LOG_STATEMENT}'

# Extensions (preload)
shared_preload_libraries = '${PG_SHARED_PRELOAD_LIBRARIES}'

# pgaudit (only meaningful if preloaded)
pgaudit.log = 'all'
pgaudit.log_catalog = off
pgaudit.log_parameter = on

# pg_stat_statements
pg_stat_statements.max = 10000
pg_stat_statements.track = all
pg_stat_statements.save = on
EOF

if [[ ! -f "${user_conf}" ]]; then
  cat > "${user_conf}" <<'EOF'
# -----------------------------------------------------------------------------
# conf.d/99-user.conf
# Optional user overrides. Mount your own file here.
# -----------------------------------------------------------------------------
EOF
fi

chown -R postgres:postgres "${base_conf}" "${env_conf}" "${user_conf}"
