/*
-- =================================================================================
 Master script to remove the eCommerce sample.
 This script should be run from the 'postgres' database as a superuser.
 The script performs the following steps:

 0) Makes sure that the script continues on error
    1) Removes the product replication between east_ecommerce_data, west_ecommerce_data, central_analytics and aidb
    2) Removes the customer and sales replication between east_ecommerce_data, west_ecommerce_data and central_analytics
    3) Drops the east_ecommerce_data, west_ecommerce_data, central_analytics, ecommerce_reference_data, and aidb databases
    4) Drops the users created for the eCommerce sample

 Use master_setup.sql to recreate the setup.
-- =================================================================================
*/

-- Continue on error
\set ON_ERROR_STOP off 

\c postgres



-- load replication configuration variables
\i replication/replication_configuration.sql

\echo '.... running remove_product_replication.sql'
\i replication/remove_product_replication.sql

\echo '.... running remove_replication.sql'
\i replication/remove_customer_sales_replication.sql

\echo '.... running cleanup_databases.sql'
\i cleanup_databases.sql

\echo '.... running remove_roles.sql'
\i database_definitions/remove_roles.sql

