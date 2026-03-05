-- =================================================================
--  PSQL SCRIPT FOR SETTING UP LOGICAL REPLICATION
--  Publisher: ecommerce_reference_data
--  Subscriber: west_ecommerce_data
-- =================================================================



\echo '*** Replication Setup Script Started ***'

-- ================================================================================
--  Step 1: Configure the Product Reference Publisher Database (:publisher_db1)
-- ================================================================================
\c :publisher_db1
\echo 'Connected to publisher database ->' :publisher_db1

\echo '--> Dropping old publications if they exist...'
DROP PUBLICATION IF EXISTS ecommerce_product_publication;
DROP PUBLICATION IF EXISTS central_analytics_product_publication;


-- publishing the reference data to west_ecommerce

\echo '--> Creating the ecommerce publication for product reference tables...'
CREATE PUBLICATION ecommerce_product_publication
    FOR TABLE 
        product.category, 
        product.brand, 
        product.product, 
        product.product_variant,
        --- send only rows that pertain are currently active
        product.product_variant_price WHERE (current = true);


-- publishing the reference data to central analytics

\echo '--> Creating the central analytics publication for product reference tables...'
CREATE PUBLICATION central_analytics_product_publication
    FOR TABLE 
        product.category, 
        product.brand, 
        product.country_of_origin,
        product.product, 
        product.product_variant,
        --- send all rows
        product.product_variant_price;

\echo '--> Verification: Listing tables in publications...'
SELECT pubname, schemaname, tablename FROM pg_publication_tables;

-- =================================================================
--  Step 2: Configure the Product Reference Subscriptions
-- =================================================================
\c :subscriber_db1

\echo 'Connected to subscriber database ->' :subscriber_db1

\echo '--> Dropping old subscriptions if they exist...'
DROP SUBSCRIPTION IF EXISTS :sub_slot_1;

\echo '--> Creating subscription for core reference data...'
CREATE SUBSCRIPTION :sub_slot_1
    CONNECTION :'publisher_conn_string1'
    PUBLICATION ecommerce_product_publication
    WITH (connect = false); -- connect=false is essential for same-server setup

\c :subscriber_db2

\echo 'Connected to subscriber database ->' :subscriber_db2

\echo '--> Dropping old subscriptions if they exist...'
DROP SUBSCRIPTION IF EXISTS :sub_slot_2;

\echo '--> Creating subscription for core reference data...'
CREATE SUBSCRIPTION :sub_slot_2
    CONNECTION :'publisher_conn_string1'
    PUBLICATION ecommerce_product_publication
    WITH (connect = false); -- connect=false is essential for same-server setup

\c :subscriber_db3

\echo 'Connected to subscriber database ->' :subscriber_db3

\echo '--> Dropping old subscriptions if they exist...'
DROP SUBSCRIPTION IF EXISTS :sub_slot_3;

\echo '--> Creating subscription for core reference data...'
CREATE SUBSCRIPTION :sub_slot_3
    CONNECTION :'publisher_conn_string1'
    PUBLICATION central_analytics_product_publication
    WITH (connect = false); -- connect=false is essential for same-server setup    

\c :subscriber_db4

\echo 'Connected to subscriber database ->' :subscriber_db4

\echo '--> Dropping old subscriptions if they exist...'
DROP SUBSCRIPTION IF EXISTS :sub_slot_4;

\echo '--> Creating subscription for core reference data...'
CREATE SUBSCRIPTION :sub_slot_4
    CONNECTION :'publisher_conn_string1'
    PUBLICATION central_analytics_product_publication
    WITH (connect = false); -- connect=false is essential for same-server setup
-- =================================================================
--  Step 3: Create Replication Slots on the Publisher
-- =================================================================
\c :publisher_db1

SET vars.slot_1 TO :'sub_slot_1';
SET vars.slot_2 TO :'sub_slot_2';
SET vars.slot_3 TO :'sub_slot_3';
SET vars.slot_4 TO :'sub_slot_4';

\echo 'Connected back to publisher to manage replication slots...'

-- Conditionally create the first slot to avoid errors on re-runs
DO $$
DECLARE
  sub_slot_1 TEXT := current_setting('vars.slot_1');
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_replication_slots WHERE slot_name = sub_slot_1) THEN
        RAISE NOTICE '--> Creating replication slot: %', sub_slot_1;
        PERFORM pg_create_logical_replication_slot(sub_slot_1, 'pgoutput');
    ELSE
        RAISE NOTICE '--> Replication slot % already exists. Skipping creation.', sub_slot_1;
    END IF;
END$$;

-- Conditionally create the second slot to avoid errors on re-runs
DO $$
DECLARE
  sub_slot_2 TEXT := current_setting('vars.slot_2');
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_replication_slots WHERE slot_name = sub_slot_2) THEN
        RAISE NOTICE '--> Creating replication slot: %', sub_slot_2;
        PERFORM pg_create_logical_replication_slot(sub_slot_2, 'pgoutput');
    ELSE
        RAISE NOTICE '--> Replication slot % already exists. Skipping creation.', sub_slot_2;
    END IF;
END$$;

-- Conditionally create the third slot to avoid errors on re-runs
DO $$
DECLARE
  sub_slot_3 TEXT := current_setting('vars.slot_3');
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_replication_slots WHERE slot_name = sub_slot_3) THEN
        RAISE NOTICE '--> Creating replication slot: %', sub_slot_3;
        PERFORM pg_create_logical_replication_slot(sub_slot_3, 'pgoutput');
    ELSE
        RAISE NOTICE '--> Replication slot % already exists. Skipping creation.', sub_slot_3;
    END IF;
END$$;

-- Conditionally create the fourth slot to avoid errors on re-runs
DO $$
DECLARE
  sub_slot_4 TEXT := current_setting('vars.slot_4');
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_replication_slots WHERE slot_name = sub_slot_4) THEN
        RAISE NOTICE '--> Creating replication slot: %', sub_slot_4;
        PERFORM pg_create_logical_replication_slot(sub_slot_4, 'pgoutput');
    ELSE
        RAISE NOTICE '--> Replication slot % already exists. Skipping creation.', sub_slot_4;
    END IF;
END$$;
-- ================================================================================
--  Step 4: Enable and Refresh Product Reference Subscriptions on the Subscriber
-- ================================================================================
\c :subscriber_db1
\echo 'Connected back to subscriber to enable and refresh data on ' :subscriber_db1

\echo '--> Enabling and refreshing subscription:' :'sub_slot_1'
ALTER SUBSCRIPTION :sub_slot_1 ENABLE;
ALTER SUBSCRIPTION :sub_slot_1 REFRESH PUBLICATION;


\c :subscriber_db2
\echo 'Connected back to subscriber to enable and refresh data on ' :subscriber_db2

\echo '--> Enabling and refreshing subscription:' :'sub_slot_2'
ALTER SUBSCRIPTION :sub_slot_2 ENABLE;
ALTER SUBSCRIPTION :sub_slot_2 REFRESH PUBLICATION;

\c :subscriber_db3
\echo 'Connected back to subscriber to enable and refresh data on ' :subscriber_db3

\echo '--> Enabling and refreshing subscription:' :'sub_slot_3'
ALTER SUBSCRIPTION :sub_slot_3 ENABLE;
ALTER SUBSCRIPTION :sub_slot_3 REFRESH PUBLICATION;


\c :subscriber_db4
\echo 'Connected back to subscriber to enable and refresh data on ' :subscriber_db4

\echo '--> Enabling and refreshing subscription:' :'sub_slot_4'
ALTER SUBSCRIPTION :sub_slot_4 ENABLE;
ALTER SUBSCRIPTION :sub_slot_4 REFRESH PUBLICATION;


\echo '*** Script Finished Successfully ***'
