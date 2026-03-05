/*
-- =================================================================================
 Master script to set up the eCommerce structure with multiple databases on the same server.
 This script should be run from the 'postgres' database as a superuser.
 The script performs the following steps:

 0) Check the underlying configuration and create helper function to check replication status
 1) Define the DBA users
 2) Create the databases
 3) Create the replication publications and subscriptions
 4) Load the reference data into the ecommerce_reference_data database
 5) Load the customer and sales data into the east_ecommerce_data and west_ecommerce_data databases
 6) Check the replication results in all databases  

 Use master_teardown.sql to drop all databases, replication definitions, and users.
-- =================================================================================
*/


--- make sure psql stops after the first error
\set ON_ERROR_STOP on
SET client_min_messages TO NOTICE;

\c postgres

--- =================================================================
---  Step 0: Check Server Configuration and Load Replication 
-- and Helper Functions
--- =================================================================


-- load replication configuration variables
\i replication/replication_configuration.sql

-- load helper functions
\i setup_helper_functions.sql


\echo 'Checking server configuration'
CALL check_server_configuration();
\echo 'Server config ok'

\echo 'Check if all required extensions are available'
CALL check_extension_list();


-- helper function to check progress of subscriptions
-- defined in database postgres
-- will be dropped at the end of the setup script



-- start Step 1

\echo 'Defining the DBA users'
\i database_definitions/define_roles.sql

\echo 'Creating databases ...'
\i database_definitions/create_databases.sql

-- DDL for each database
\echo '.... database_definitions/ecommerce_reference_data.sql'
\i database_definitions/ecommerce_reference_data.sql

-- set variable to indicate origin for use in sales_transaction and customer tables
\set origin 'WEST'

\echo '.... executing database_definitions/west_ecommerce_data.sql'
\i database_definitions/west_ecommerce_data.sql

\echo '.... adding shared API definitions to west ecommerce'
\c west_ecommerce_data
\i database_definitions/ecommerce_api.sql

-- set variable to indicate origin for use in sales_transaction and customer tables
\set origin 'EAST'

\echo '.... executing database_definitions/east_ecommerce_data.sql'
\i database_definitions/east_ecommerce_data.sql

\echo '.... adding shared API definitions to east ecommerce'
\c east_ecommerce_data
\i database_definitions/ecommerce_api.sql

\echo '.... executing database_definitions/central_analytics.sql'
\i database_definitions/central_analytics.sql

\echo '... the star schemas to central_analytics'
\i database_definitions/central_analytics_stars.sql

\echo '.... executing database_definitions/aidb.sql'
\i database_definitions/aidb.sql

-- add the pgbench stored procedures to east_ecommerce_data
-- pgbench-command.sh (psql_scripts/sample_scripts/pgbench-scripts/) in 
-- runs against east_ecommerce_data database
\echo '.... adding pgbench-specific stored procedures to east_ecommerce_data'
\i sample_scripts/pgbench-scripts/pgbench-stored-procedures.sql


\echo 'Databases defined'
\echo '--------------------------------------------------------------------'

\echo 'Setting up replication ...'

\echo '.... executing replication/product_replication_setup.sql'
\i replication/product_replication_setup.sql

\echo '.... executing replication/customer_sales_replication_setup.sql'
\i replication/customer_sales_replication_setup.sql

\echo 'Replication set up'
\echo '--------------------------------------------------------------------'

\echo '.... loading product reference data'

\c ecommerce_reference_data
\i data_sets/ecommerce_reference_data/product/brand.sql
\i data_sets/ecommerce_reference_data/product/country_of_origin.sql
\i data_sets/ecommerce_reference_data/product/category.sql
\i data_sets/ecommerce_reference_data/product/product.sql
\i data_sets/ecommerce_reference_data/product/product_variant.sql
\i data_sets/ecommerce_reference_data/product/product_variant_price.sql


\echo 'Product reference data loaded'
\echo '--------------------------------------------------------------------'



\c postgres 
-- make sure replication has caught up
CALL check_subscriptions();

/*
This resets the sequences used by the product definitions so that the API calls 
don't conflict. This is needed as the initial product definitions are hard coded
and the sequences need to be set to a value above the highest hard coded value.
*/
\echo 'Resetting product sequences ...'
\i data_sets/ecommerce_reference_data/product/alter_product_sequences.sql

\echo '... loading east ecommerce data for customers and sales'

\c east_ecommerce_data
-- load the customer data first from file.
\i data_sets/east_ecommerce_data/customer.sql
-- then generate inventory
\i data_set_generation/generate_inventory.sql
-- wait 1 sec to make sure that inventory data is committed and visible
SELECT PG_SLEEP(1);
-- then generate sales data
\i data_set_generation/generate_sales.sql


\echo '... loading west ecommerce data for customers and sales'

\c west_ecommerce_data
-- load the customer data first from file
\i data_sets/west_ecommerce_data/customer.sql
-- then generate inventory and sales data
\i data_set_generation/generate_inventory.sql
-- wait 1 sec to make sure that inventory data is committed and visible
SELECT PG_SLEEP(1);
-- then generate sales data
\i data_set_generation/generate_sales.sql

\echo 'Customer and sales data loaded'
\echo '--------------------------------------------------------------------'

-- make sure replication has caught up
\c postgres 
CALL check_subscriptions();

-- collect data to make sure all data has arrived in east/west/central/aidb
\echo 'Checking replication results ...'

\echo 'Data counts on ecommerce_reference_data'
\c ecommerce_reference_data
SELECT COUNT(*) as product_count from product;
-- sets the variable ecommerce_product_count
\gset ecommerce_

SELECT COUNT(*) as active_product_price_count from product_variant_price where current=true;
-- sets the variable ecommerce_active_product_price_count
\gset ecommerce_

\echo 'Data counts on east_ecommerce_data'
\c east_ecommerce_data

SELECT COUNT(*) as product_count from product;
-- sets the variable east_ecommerce_data_product_count
\gset east_ecommerce_data_

SELECT COUNT(*) as active_product_price_count from product_variant_price where current=true;
-- sets the variable east_ecommerce_data_active_product_price_count
\gset east_ecommerce_data_

SELECT COUNT(*) as customer_count from customer;
-- sets the variable east_ecommerce_data_customer_count
\gset east_ecommerce_data_

SELECT COUNT(*) as sales_transaction_count from sales_transaction;
-- sets the variable east_ecommerce_data_sales_transaction_count
\gset east_ecommerce_data_

SELECT COUNT(*) as sales_transaction_line_count from sales_transaction_line;
-- sets the variable east_ecommerce_data_sales_transaction_line_count
\gset east_ecommerce_data_

\echo 'Data counts on west_ecommerce_data'
\c west_ecommerce_data

SELECT COUNT(*) as product_count from product;
-- sets the variable west_ecommerce_data_product_count
\gset west_ecommerce_data_

SELECT COUNT(*) as active_product_price_count from product_variant_price where current=true;
-- sets the variable west_ecommerce_data_active_product_price_count
\gset west_ecommerce_data_

SELECT COUNT(*) as customer_count from customer;
-- sets the variable west_ecommerce_data_customer_count
\gset west_ecommerce_data_

SELECT COUNT(*) as sales_transaction_count from sales_transaction;
-- sets the variable west_ecommerce_data_sales_transaction_count
\gset west_ecommerce_data_

SELECT COUNT(*) as sales_transaction_line_count from sales_transaction_line;
-- sets the variable west_ecommerce_data_sales_transaction_line_count
\gset west_ecommerce_data_

\echo 'Data counts on central_analytics'
\c central_analytics

SELECT COUNT(*) as product_count from product;
-- sets the variable central_analytics_product_count
\gset central_analytics_ 

SELECT COUNT(*) as active_product_price_count from product_variant_price where current=true;
-- sets the variable central_analytics_active_product_price_count
\gset central_analytics_ 


SELECT COUNT(*) as customer_count from customer.customer;
-- sets the variable central_analytics_customer_count
\gset central_analytics_ 

SELECT COUNT(*) as sales_transaction_count from sales.sales_transaction;
-- sets the variable central_analytics_sales_transaction_count
\gset central_analytics_

SELECT COUNT(*) as sales_transaction_line_count from sales.sales_transaction_line;
-- sets the variable central_analytics_sales_transaction_line_count
\gset central_analytics_

\echo 'Data counts on aidb'
\c aidb

SELECT COUNT(*) as product_count from product;
-- sets the variable aidb_product_count
\gset aidb_ 

SELECT COUNT(*) as active_product_price_count from product_variant_price where current=true;
-- sets the variable aidb_active_product_price_count
\gset aidb_ 


\echo '--------------------------------------------------------------------'
\echo 'Checking product replication results'
\echo 'ecommerce_product_count:' :ecommerce_product_count
\echo 'ecommerce_active_product_price_count:' :ecommerce_active_product_price_count
\echo 'east_ecommerce_data_product_count:' :east_ecommerce_data_product_count
\echo 'east_ecommerce_data_active_product_price_count:' :east_ecommerce_data_active_product_price_count
\echo 'west_ecommerce_data_product_count:' :west_ecommerce_data_product_count
\echo 'west_ecommerce_data_active_product_price_count:' :west_ecommerce_data_active_product_price_count
\echo 'central_analytics_product_count:' :central_analytics_product_count
\echo 'central_analytics_active_product_price_count:' :central_analytics_active_product_price_count
\echo 'aidb_product_count:' :aidb_product_count
\echo 'aidb_active_product_price_count:' :aidb_active_product_price_count
\echo '--------------------------------------------------------------------'
\echo 'Checking customer and sales replication results'
\echo 'east_ecommerce_data_customer_count:' :east_ecommerce_data_customer_count
\echo 'east_ecommerce_data_sales_transaction_count:' :east_ecommerce_data_sales_transaction_count
\echo 'east_ecommerce_data_sales_transaction_line_count:' :east_ecommerce_data_sales_transaction_line_count
\echo 'west_ecommerce_data_customer_count:' :west_ecommerce_data_customer_count
\echo 'west_ecommerce_data_sales_transaction_count:' :west_ecommerce_data_sales_transaction_count
\echo 'west_ecommerce_data_sales_transaction_line_count:' :west_ecommerce_data_sales_transaction_line_count
\echo 'central_analytics_customer_count:' :central_analytics_customer_count
\echo 'central_analytics_sales_transaction_count:' :central_analytics_sales_transaction_count
\echo 'central_analytics_sales_transaction_line_count:' :central_analytics_sales_transaction_line_count
\echo '--------------------------------------------------------------------'

\c postgres

-- cleanup helper function

DROP PROCEDURE IF EXISTS check_subscriptions;

-- list databases

\l