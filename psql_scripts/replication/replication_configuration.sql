
-- =================================================================
--  Configuration Variables for Replication Setup and Teardown Scripts
-- =================================================================



\set publisher_conn_string1 'host=localhost port=5432 dbname=ecommerce_reference_data user=postgres password=postgres'
\set publisher_conn_string2 'host=localhost port=5432 dbname=west_ecommerce_data user=postgres password=postgres'
\set publisher_conn_string3 'host=localhost port=5432 dbname=east_ecommerce_data user=postgres password=postgres'


\set publisher_db1 'ecommerce_reference_data'
\set publisher_db2 'west_ecommerce_data'
\set publisher_db3 'east_ecommerce_data'


\set subscriber_db1 'west_ecommerce_data'
\set subscriber_db2 'east_ecommerce_data'
\set subscriber_db3 'central_analytics'
\set subscriber_db4 'aidb'


\set sub_slot_1 'west_product_data_sub'
\set sub_slot_2 'east_product_data_sub'
\set sub_slot_3 'central_analytics_product_sub'
\set sub_slot_4 'aidb_product_sub'
\set sub_slot_5 'west_customer_sales_data_sub'
\set sub_slot_6 'east_customer_sales_data_sub'