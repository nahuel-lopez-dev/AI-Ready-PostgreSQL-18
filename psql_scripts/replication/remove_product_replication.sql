-- =================================================================
--  PSQL SCRIPT FOR ROLLING BACK LOGICAL REPLICATION FOR PRODUCT REFERENCE
--  This script tears down the publications, subscriptions,
--  and replication slots created by the setup script.
--  configuration definition is in replication_configuration.sql and
--  has been loaded as part of master_teardown.sql
-- =================================================================



\echo '*** Removal Script Started ***'

-- =================================================================
--  Step 1: Disable and Drop Subscriptions on the Subscriber
-- =================================================================
\c :subscriber_db1
\echo 'Connected to subscriber database ->' :subscriber_db1


\echo '--> Disabling subscription' :'sub_slot_1' 'if it exists...'
-- It's good practice to disable before dropping.
-- And remove slot dependencies
-- The IF EXISTS on the DROP command handles cases where it's already gone.
ALTER SUBSCRIPTION :sub_slot_1 DISABLE;
ALTER SUBSCRIPTION :sub_slot_1 SET (slot_name = NONE);

\echo '--> Dropping subscription' :'sub_slot_1' 'if it exists...'
DROP SUBSCRIPTION IF EXISTS :sub_slot_1;

\c :subscriber_db2
\echo 'Connected to subscriber database ->' :subscriber_db2


\echo '--> Disabling subscription' :'sub_slot_2' 'if it exists...'
-- It's good practice to disable before dropping.
-- And remove slot dependencies
-- The IF EXISTS on the DROP command handles cases where it's already gone.
ALTER SUBSCRIPTION :sub_slot_2 DISABLE;
ALTER SUBSCRIPTION :sub_slot_2 SET (slot_name = NONE);

\echo '--> Dropping subscription' :'sub_slot_1' 'if it exists...'
DROP SUBSCRIPTION IF EXISTS :sub_slot_2;

\c :subscriber_db3
\echo 'Connected to subscriber database ->' :subscriber_db3


\echo '--> Disabling subscription' :'sub_slot_3' 'if it exists...'
-- It's good practice to disable before dropping.
-- And remove slot dependencies
-- The IF EXISTS on the DROP command handles cases where it's already gone.
ALTER SUBSCRIPTION :sub_slot_3 DISABLE;
ALTER SUBSCRIPTION :sub_slot_3 SET (slot_name = NONE);

\echo '--> Dropping subscription' :'sub_slot_3' 'if it exists...'
DROP SUBSCRIPTION IF EXISTS :sub_slot_3;

\c :subscriber_db4
\echo 'Connected to subscriber database ->' :subscriber_db4
\echo '--> Disabling subscription' :'sub_slot_4' 'if it exists...'
-- It's good practice to disable before dropping.
-- And remove slot dependencies
-- The IF EXISTS on the DROP command handles cases where it's already gone.
ALTER SUBSCRIPTION :sub_slot_4 DISABLE;
ALTER SUBSCRIPTION :sub_slot_4 SET (slot_name = NONE);

\echo '--> Dropping subscription' :'sub_slot_4' 'if it exists...'
DROP SUBSCRIPTION IF EXISTS :sub_slot_4;


\echo '--> Subscriptions dropped.'

-- =================================================================
--  Step 2: Drop Replication Slots on the Publisher ecommerce reference
-- =================================================================
\c :publisher_db1
SET vars.sub_slot_1 TO :'sub_slot_1';
SET vars.sub_slot_2 TO :'sub_slot_2';
SET vars.sub_slot_3 TO :'sub_slot_3';
SET vars.sub_slot_4 TO :'sub_slot_4';

\echo 'Connected to publisher database ->' :publisher_db1

-- Drop the replication slot for the first subscription, if it exists.
-- A DO block is used to conditionally call the drop function.
DO $$
DECLARE
        sub_slot_1 TEXT := current_setting('vars.sub_slot_1');
BEGIN
    IF EXISTS (SELECT 1 FROM pg_replication_slots WHERE slot_name = sub_slot_1) THEN
        RAISE NOTICE  '--> Dropping replication slot: %', sub_slot_1;
        -- Note: pg_drop_replication_slot is a function, not standard DDL.
        PERFORM pg_drop_replication_slot(sub_slot_1);
    ELSE
        RAISE NOTICE '--> Replication slot : % does not exist. Skipping.', sub_slot_1;
    END IF;
END$$;

-- Drop the replication slot for the second subscription, if it exists.
-- A DO block is used to conditionally call the drop function.
DO $$
DECLARE
        sub_slot_2 TEXT := current_setting('vars.sub_slot_2');
BEGIN
    IF EXISTS (SELECT 1 FROM pg_replication_slots WHERE slot_name = sub_slot_2) THEN
        RAISE NOTICE  '--> Dropping replication slot: %', sub_slot_2;
        -- Note: pg_drop_replication_slot is a function, not standard DDL.
        PERFORM pg_drop_replication_slot(sub_slot_2);
    ELSE
        RAISE NOTICE '--> Replication slot : % does not exist. Skipping.', sub_slot_2;
    END IF;
END$$;

-- Drop the replication slot for the third subscription, if it exists.
-- A DO block is used to conditionally call the drop function.
DO $$
DECLARE
        sub_slot_3 TEXT := current_setting('vars.sub_slot_3');
BEGIN
    IF EXISTS (SELECT 1 FROM pg_replication_slots WHERE slot_name = sub_slot_3) THEN
        RAISE NOTICE  '--> Dropping replication slot: %', sub_slot_3;
        -- Note: pg_drop_replication_slot is a function, not standard DDL.
        PERFORM pg_drop_replication_slot(sub_slot_3);
    ELSE
        RAISE NOTICE '--> Replication slot : % does not exist. Skipping.', sub_slot_2;
    END IF;
END$$;

-- Drop the replication slot for the fourth subscription, if it exists.
-- A DO block is used to conditionally call the drop function.
DO $$
DECLARE
        sub_slot_4 TEXT := current_setting('vars.sub_slot_4');
BEGIN
    IF EXISTS (SELECT 1 FROM pg_replication_slots WHERE slot_name = sub_slot_4) THEN
        RAISE NOTICE  '--> Dropping replication slot: %', sub_slot_4;
        -- Note: pg_drop_replication_slot is a function, not standard DDL.
        PERFORM pg_drop_replication_slot(sub_slot_4);
    ELSE
        RAISE NOTICE '--> Replication slot : % does not exist. Skipping.', sub_slot_4;
    END IF;
END$$;


\echo '--> Replication slots have been dropped.'


-- =================================================================
--  Step 3: Drop Publications on the Publisher
-- =================================================================
-- This can be done in the same connection to the publisher.

\echo '--> Dropping publication: west_product_publication'
DROP PUBLICATION IF EXISTS west_product_publication;

\echo '--> Dropping publication: east_product_publication'
DROP PUBLICATION IF EXISTS east_product_publication;

\echo '--> Dropping publication: central_product_publication'
DROP PUBLICATION IF EXISTS central_analytics_product_publication;

\echo '--> Dropping publication: ecommerce_product_publication'
DROP PUBLICATION IF EXISTS ecommerce_product_publication;

\echo '--> Publications dropped.'

\echo '*** Rollback Script Finished Successfully ***'