# PostgreSQL 18 + pgvector (AI-ready) on Rocky Linux 9

A PostgreSQL 18 container image with **pgvector and advanced extensions**, designed for **AI, analytics, and modern transactional workloads**.

This image prioritizes:
- clarity over cleverness
- explicit configuration over magic
- safe defaults with strong override mechanisms
- developer friendliness *without* sacrificing production discipline

## Features

- **PostgreSQL 18**
- **AI / Vector support**
  - `pgvector`
- **Advanced extensions**
  - `pg_ivm`
  - `pg_background`
  - `pg_squeeze`
  - `pgaudit`
  - `plpgsql_check`
  - `plpython3u`
  - `pg_stat_statements`
- **Rocky Linux 9** base
- **Multi-architecture friendly** (amd64 / arm64)
- **Environment-driven configuration**
- **Config layering with `conf.d/` includes**
- **Idempotent init scripts**
- **Docker Compose ready**
- **Clean bootstrap lifecycle (no double starts)**

##  Image
```docker
vibhorkumar123/pg18-vector:
```

Example:

```docker
vibhorkumar123/pg18-vector:v2.4
```

## Design Philosophy

This image intentionally **does not** behave like the official Postgres image.

Key differences:

| Area | This Image |
|---|---|
| Startup | PostgreSQL runs **in foreground** (PID 1) |
| Config | Generated via `conf.d/10-docker-env.conf` |
| Overrides | User overrides via `conf.d/99-user.conf` |
| Init | One-time bootstrap using `pg_ctl` |
| Tests | Explicit test scripts (not implicit) |
| Security | Trust auth by default (dev-first) |
| AI | pgvector + Python stack included |


## Repository Layout

```bash
├── Dockerfile
├── docker-compose.yml
├── scripts/
│   ├── start-postgres.sh
│   ├── init-postgres.sh
│   ├── render-postgresql-conf.sh
│   ├── ensure-users-db.sh
│   ├── ensure-extensions.sh
│   ├── run-init-scripts.sh
│   ├── test-all-extensions.sh
│   └── test-pgvector.sh
└── README.md
```

## Quick Start (Docker)

### Run directly

```bash
docker run -d \
  --name pg18 \
  -p 5432:5432 \
  -e POSTGRES_PASSWORD=postgres \
  vibhorkumar123/pg18-vector:v2.4
```

Connect:
```bash
docker exec -it pg18 psql -U postgres
```

## Configuration Model

Configuration layering (important)

PostgreSQL reads:

- postgresql.conf (base, minimal)
- conf.d/10-docker-env.conf (generated from env vars)
- conf.d/99-user.conf (optional user override)

This allows:

- safe defaults
- runtime overrides
- zero rebuilds for tuning


#  Environment Variables (Core)

## Basics

| Variable | Default |
|---|---|
| `POSTGRES_USER` | `postgres` |
| `POSTGRES_PASSWORD` | *(required at runtime)* |
| `POSTGRES_DB` | `postgres` |
| `PGDATA` | `/var/lib/pgsql/18/data` |
| `PG_PORT` | `5432` |


## Memory & Performance

| Variable | Default |
|---|---|
| `PG_SHARED_BUFFERS` | `256MB` |
| `PG_EFFECTIVE_CACHE_SIZE` | `1GB` |
| `PG_WORK_MEM` | `4MB` |
| `PG_MAINTENANCE_WORK_MEM` | `64MB` |
| `PG_RANDOM_PAGE_COST` | `1.1` |
| `PG_EFFECTIVE_IO_CONCURRENCY` | `200` |

### Connections & Workers

| Variable | Default |
|---|---|
| `PG_MAX_CONNECTIONS` | `100` |
| `PG_MAX_WORKER_PROCESSES` | `8` |
| `PG_MAX_PARALLEL_WORKERS` | `8` |
| `PG_MAX_PARALLEL_WORKERS_PER_GATHER` | `2` |
| `PG_MAX_PARALLEL_MAINTENANCE_WORKERS` | `2` |



### WAL & Replication

| Variable | Default |
|---|---|
| `PG_WAL_LEVEL` | `logical` |
| `PG_MAX_WAL_SENDERS` | `10` |
| `PG_MAX_REPLICATION_SLOTS` | `10` |
| `PG_MAX_LOGICAL_REPLICATION_WORKERS` | `4` |
| `PG_MAX_WAL_SIZE` | `2GB` |
| `PG_CHECKPOINT_TIMEOUT` | `10min` |


### Logging

| Variable | Default |
|---|---|
| `PG_LOG_DESTINATION` | `stderr` |
| `PG_LOGGING_COLLECTOR` | `on` |
| `PG_LOG_DIRECTORY` | `/var/log/postgresql` |
| `PG_LOG_MIN_DURATION_STATEMENT` | `1000` |
| `PG_LOG_STATEMENT` | `none` |
| `PG_LOG_LINE_PREFIX` | `%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h ` |

## Extensions (preload)

PG_SHARED_PRELOAD_LIBRARIES="pg_stat_statements,vector,pg_ivm,pg_background,pg_squeeze,pgaudit"


## Testing

### Test pgvector

```
docker exec pg18 /usr/local/bin/test-pgvector.sh
```

### Test all extensions

```
docker exec pg18 /usr/local/bin/test-all-extensions.sh
```

## Init Scripts (`/docker-entrypoint-initdb.d`)

- Executed **only on first initialization**
- Supports:
  - `*.sql`
  - `*.sh`

Example:

```bash
docker run -d \
  -v ./initdb:/docker-entrypoint-initdb.d:ro \
  -e POSTGRES_PASSWORD=postgres \
  vibhorkumar123/pg18-vector:v2.4
```


## User Override Configuration

Mount your own config safely:

```bash
-v ./my-user.conf:/var/lib/pgsql/18/data/conf.d/99-user.conf:ro
```

Example my-user.conf:

```sql
shared_buffers = '512MB'
max_connections = 200
```


# Docker Compose

Development

```bash
docker compose -f docker-compose.dev.yml up -d
```

Production-ish

```bash
docker compose -f docker-compose.prod.yml up -d
```

The prod compose:

- uses Docker secrets
- avoids plaintext passwords
- prefers stderr logging



#  Clean Build Script

For full rebuild + validation:

```bash
./clean_build_pg18.sh
```

Optional flags:

```bash
POSTGRES_PASSWORD=secret DO_SYSTEM_PRUNE=1 ./clean_build_pg18.sh
```

#  Operational Notes
- PostgreSQL runs once in foreground (no double-start bugs)
- Bootstrap server is always stopped before final handoff
- Stale postmaster.pid files are handled safely
- Tests are idempotent and defensive


# Author

- Vibhor Kumar
- Technology Leader - PostgreSQL, Data Platforms, AI
- LinkedIn: https://www.linkedin.com/in/vibhork
- GitHub: https://github.com/vibhorkumar123

