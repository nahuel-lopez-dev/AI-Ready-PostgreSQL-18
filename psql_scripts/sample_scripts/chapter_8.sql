


-- enable the pg_stat_statements extension if not already enabled
-- check if the extension is available
SELECT * FROM pg_available_extensions WHERE name = 'pg_stat_statements';

CREATE EXTENSION IF NOT EXISTS pg_stat_statements;


-- see file pgbench-scripts/pgbench-command.sh for the pgbench command to run the scripts

-- identifying long running queries

-- column query truncated to first 25 characters for readability
WITH totals AS (
    SELECT 
        SUM(total_exec_time) AS sum_exec_time,
        SUM(calls) AS sum_calls
    FROM pg_stat_statements
)
SELECT 
    SUBSTRING(query, 0, 25) AS query, calls AS nbr_of_calls, TO_CHAR(calls/totals.sum_calls, 'FM99.00%') as perc_total_calls, 
    ROUND(total_exec_time) AS total_exec_time, TO_CHAR(total_exec_time/totals.sum_exec_time, 'FM99.00%') AS perc_exec_time
FROM pg_stat_statements
JOIN totals ON TRUE
ORDER BY total_exec_time DESC
LIMIT 10;

-- without truncation of column query

WITH totals AS (
    SELECT 
        SUM(total_exec_time) AS sum_exec_time,
        SUM(calls) AS sum_calls
    FROM pg_stat_statements
)
SELECT 
    query, calls AS nbr_of_calls, TO_CHAR(calls/totals.sum_calls, 'FM99.00%') as perc_total_calls, 
    ROUND(total_exec_time) AS total_exec_time, TO_CHAR(total_exec_time/totals.sum_exec_time, 'FM99.00%') AS perc_exec_time
FROM pg_stat_statements
JOIN totals ON TRUE
ORDER BY total_exec_time DESC
LIMIT 10;

-- select top 10 queries Queries with low cache-hit ratio

-- column query truncated to first 25 characters for readability
WITH totals AS (
    SELECT SUM(shared_blks_hit + shared_blks_read) AS sum_accesses,
        SUM(shared_blks_hit) AS sum_hits
    FROM pg_stat_statements
)
SELECT 
    SUBSTRING(query, 0, 25) AS query, calls AS nbr_of_calls, 
    shared_blks_hit, shared_blks_read,
    100* (shared_blks_hit::numeric / NULLIF(shared_blks_hit + shared_blks_read,0))::NUMERIC(5,2) AS hit_cache_ratio
FROM pg_stat_statements
JOIN totals ON TRUE
ORDER BY hit_cache_ratio ASC
LIMIT 10;

-- without truncation of query
WITH totals AS (
    SELECT SUM(shared_blks_hit + shared_blks_read) AS sum_accesses,
        SUM(shared_blks_hit) AS sum_hits
    FROM pg_stat_statements
)
SELECT 
    query, calls AS nbr_of_calls, 
    shared_blks_hit, shared_blks_read,
    100* (shared_blks_hit::numeric / NULLIF(shared_blks_hit + shared_blks_read,0))::NUMERIC(5,2) AS hit_cache_ratio
FROM pg_stat_statements
JOIN totals ON TRUE
ORDER BY hit_cache_ratio ASC
LIMIT 10;



