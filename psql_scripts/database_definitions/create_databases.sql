
/*
================================================================================
  PSQL SCRIPT FOR CENTRAL ANALYTICS DATABASE
================================================================================
  OWNER: Superuser
  PURPOSE: Creates the databases
           * ecommerce_reference_data
           * east_ecommerce_data
           * west_ecommerce_data
           * central_analytics
           * aidb          
================================================================================
*/

\echo '[DATABASE PREP] ==> Preparing to drop and recreate the database ecommerce_reference_data'
-- Terminate all active connections to the target database before dropping it.

SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = 'ecommerce_reference_data' AND pid <> pg_backend_pid();

DROP DATABASE IF EXISTS ecommerce_reference_data;

\echo '[DATABASE PREP] ==> Creating the database...'
CREATE DATABASE ecommerce_reference_data;

-------------------------------------------------------------------------------

\echo '[DATABASE PREP] ==> Preparing to drop and recreate the database east_ecommerce_data.'

-- Terminate active connections before dropping the database for a safe teardown.
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = 'east_ecommerce_data' AND pid <> pg_backend_pid();

DROP DATABASE IF EXISTS east_ecommerce_data;

\echo '[DATABASE PREP] ==> Creating the database...'
CREATE DATABASE east_ecommerce_data;

-------------------------------------------------------------------------------

\echo '[DATABASE PREP] ==> Preparing to drop and recreate the database west_ecommerce_data.'

-- Terminate active connections before dropping the database for a safe teardown.
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = 'west_ecommerce_data' AND pid <> pg_backend_pid();

DROP DATABASE IF EXISTS west_ecommerce_data;

\echo '[DATABASE PREP] ==> Creating the database...'
CREATE DATABASE west_ecommerce_data;

-------------------------------------------------------------------------------

\echo '[DATABASE PREP] ==> Preparing to drop and recreate the database central_analytics.'
-- Terminate all active connections to the target database before dropping it.

SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = 'central_analytics' AND pid <> pg_backend_pid();

DROP DATABASE IF EXISTS central_analytics;

\echo '[DATABASE PREP] ==> Creating the database...'
CREATE DATABASE central_analytics;

-------------------------------------------------------------------------------

\echo '[DATABASE PREP] ==> Preparing to drop and recreate the database aidb.'
-- Terminate all active connections to the target database before dropping it.

SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = 'aidb' AND pid <> pg_backend_pid();

DROP DATABASE IF EXISTS aidb;

\echo '[DATABASE PREP] ==> Creating the database...'
CREATE DATABASE aidb;
