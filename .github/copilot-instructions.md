# Copilot Instructions for AI Coding Agents

## Project Overview
- This repository implements a reference e-commerce architecture using PostgreSQL 18, featuring logical replication, analytics, and AI-powered search.
- Major databases: `ecommerce_reference_data` (master product data), `west_ecommerce_data` & `east_ecommerce_data` (regional), `central_analytics` (warehouse), and `aidb` (AI/semantic search).
- Data flows from reference → regional → analytics → AI DB, using logical replication and custom scripts.

## Key Directories & Files
- `psql_scripts/`: Main automation scripts for setup, teardown, schema, data, and replication.
  - `master_setup.sql`: End-to-end setup (creates all DBs, schemas, replication, and loads data).
  - `master_teardown.sql`: Full teardown (removes all DBs and replication artifacts).
  - `database_definitions/`: Per-database schema definitions.
  - `replication/`: Replication setup/teardown scripts.
  - `data_sets/`: Data population scripts.
  - `sample_scripts/`: Example scripts for book chapters.
- `docker-compose.yml`: Launches a containerized environment with all required PostgreSQL extensions.
- `README.md`: Full architecture, workflow, and environment details.

## Developer Workflows
- **Setup:** Run `psql -U <superuser> -f psql_scripts/master_setup.sql` after configuring PostgreSQL for logical replication and setting the OpenAI API key.
- **Teardown:** Run `psql -U <superuser> -f psql_scripts/master_teardown.sql` to clean up.
- **Docker:** Use `docker-compose up` for a pre-configured environment (see `docker-compose.yml`).
- **Chapter Examples:** Use scripts in `psql_scripts/sample_scripts/` for targeted demos.

## Project-Specific Conventions
- All automation is via `psql` scripts using meta-commands and variables—avoid ad-hoc manual steps.
- Database names, schemas, and replication slots are hardcoded for reproducibility.
- Extensions (e.g., `pgvector`, `pg_trgm`, `plpython3u`) must be installed in the environment.
- AI/semantic search features require a valid OpenAI API key set via `ALTER SYSTEM`.
- Data model uses advanced types: `DATERANGE`, `JSONB`, and `vector`.

## Integration & External Dependencies
- Relies on PostgreSQL 18+ with specific configuration (see `README.md`).
- Integrates with OpenAI for embeddings (RAG, semantic search in `aidb`).
- Uses multiple PostgreSQL extensions for analytics, search, and auditing.

## Patterns & Examples
- Replication setup: See `psql_scripts/replication/product_replication_setup.sql`.
- Analytics schema: See `psql_scripts/database_definitions/central_analytics_stars.sql`.
- AI search: See `psql_scripts/database_definitions/aidb.sql` and related scripts.

## Troubleshooting
- If setup fails, check PostgreSQL config, extension availability, and API key.
- Use logs and final report output from `master_setup.sql` for diagnostics.

---
For more, see `README.md` and comments in key scripts.
