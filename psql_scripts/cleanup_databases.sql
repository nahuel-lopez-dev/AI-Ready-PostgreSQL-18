-- =================================================================
--  PSQL SCRIPT FOR TERMINATING CONNECTIONS AND DROPPING DATABASES
--  WARNING: THIS IS A DESTRUCTIVE OPERATION AND CANNOT BE UNDONE.
--  Run this script while connected to a maintenance database (e.g., 'postgres').
-- =================================================================

\c postgres

-- Step 0: Define variables for the databases to be dropped
\set db_to_drop_1 'ecommerce_reference_data'
\set db_to_drop_2 'west_ecommerce_data'
\set db_to_drop_3 'east_ecommerce_data'
\set db_to_drop_4 'central_analytics'
\set db_to_drop_5 'aidb'
\set db_to_drop_6 'central_analytics_bcp'

\echo '*** Database Cleanup Script Started ***'
\echo 'WARNING: This script will permanently delete databases:' :'db_to_drop_1'', ':'db_to_drop_2', ', ':'db_to_drop_3' ', ':'db_to_drop_4', ', ':'db_to_drop_5', ', ':'db_to_drop_6'


-- =================================================================
--  Step 1: Terminate connections and drop the first database
-- =================================================================


DROP DATABASE IF EXISTS :db_to_drop_1 WITH (FORCE);
DROP DATABASE IF EXISTS :db_to_drop_2 WITH (FORCE);
DROP DATABASE IF EXISTS :db_to_drop_3 WITH (FORCE);
DROP DATABASE IF EXISTS :db_to_drop_4 WITH (FORCE);
DROP DATABASE IF EXISTS :db_to_drop_5 WITH (FORCE); 
DROP DATABASE IF EXISTS :db_to_drop_6 WITH (FORCE);


\echo '--> Verifying that databases are gone. The following list should not contain the dropped databases:'
\l

\echo '*** Cleanup Script Finished Successfully ***'
