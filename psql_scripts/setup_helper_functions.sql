
DROP PROCEDURE IF EXISTS check_server_configuration;

CREATE PROCEDURE check_server_configuration()
LANGUAGE plpgsql
AS $$
/*
Check the underlying configuration
- server_version_num >= 18000 (minimum Postgres 18)
- wal_level = logical
- logging_collector=on 
- max_logical_replication_workers>=10 
- log_statement=ddl
*/
DECLARE 
    v_rep_workers INTEGER;
    v_wal_level TEXT;
BEGIN
    -- check server_version_num
    IF current_setting('server_version_num')::INTEGER < 180000 THEN
        RAISE EXCEPTION 'PostgreSQL version % is not supported. Minimum version is 18', current_setting('server_version_num');
    END IF;
    -- check max_logical_replication_workers
    SELECT setting INTO v_rep_workers
        FROM pg_settings 
        WHERE name = 'max_logical_replication_workers';
    IF v_rep_workers < 10 THEN
        RAISE EXCEPTION 'Parameter max_logical_replication_workers set to %. Must be above 10', v_rep_workers;
    END IF;
    -- check wal_level
    SELECT setting::TEXT INTO v_wal_level
        FROM pg_settings 
        WHERE name = 'wal_level';
    IF v_wal_level <> 'logical' THEN
        RAISE EXCEPTION 'Parameter wal_level set to %. Must be logical', v_wal_level;
    END IF;
END 
$$;

-- iterate through the list of subscriptions and check if they are caught up

DROP PROCEDURE IF EXISTS check_subscriptions;

CREATE PROCEDURE check_subscriptions () AS
$$
DECLARE 
    v_array_subscriptions text[] := ARRAY['east_product_data_sub','west_product_data_sub', 'central_analytics_product_sub', 'aidb_product_sub', 'west_customer_sales_data_sub', 'east_customer_sales_data_sub'];
    v_lsn_diff INTEGER := 0;
    v_total_lsn_diff INTEGER := 0;
    v_sub TEXT;
    v_loop_ctr INTEGER := 0;
    v_wait_limit INTEGER := 100; -- maximum wait loops
BEGIN
    RAISE NOTICE 'Checking that the following subscriptions are caught up: %', ARRAY_TO_STRING(v_array_subscriptions, ', ');
    LOOP
        -- check if any subscription has a lsn diff > 0
        v_total_lsn_diff :=0;
        v_loop_ctr := v_loop_ctr + 1;
        FOREACH v_sub IN ARRAY v_array_subscriptions LOOP
            RAISE NOTICE 'Checking on %', v_sub;
            SELECT pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) INTO v_lsn_diff
                FROM pg_stat_replication
            WHERE application_name = v_sub;
            IF v_lsn_diff > 0 THEN 
                RAISE NOTICE 'Subscription % has a LSN diff of %', v_sub, v_lsn_diff;
                v_total_lsn_diff := v_total_lsn_diff + v_lsn_diff;
            ELSE 
                RAISE NOTICE 'Subscription % is caught up', v_sub;
            END IF;
        END LOOP;
        -- if v_total_lsn_diff = 0, then all subscriptions have caught up. Exit loop
        IF v_total_lsn_diff = 0 THEN
            RAISE NOTICE 'All subscriptions are caught up';
            EXIT;
        -- if we tried too often, abort as there is a problem.
        ELSEIF v_loop_ctr > v_wait_limit THEN   
            RAISE EXCEPTION 'Stopped waiting for replications to catch up after % loops', v_loop_ctr;
        -- wait 1 sec and try again
        ELSE
            PERFORM PG_SLEEP(1);
        END IF;
    END LOOP;
END
$$ LANGUAGE PLPGSQL;



-- Check the extensions that are needed to load the data or
-- run the examples in the different chapters

DROP PROCEDURE IF EXISTS check_extension_list;
CREATE PROCEDURE check_extension_list()
AS
$$

DECLARE
    v_extensions VARCHAR[][] := ARRAY[
        ['pg_background', 'Chapter 6'],
        ['pg_squeeze', 'Chapter 8'],
        ['pg_stat_statements','Chapter 8'],
        ['pg_trgm', 'Chapter 14'],
        ['pgaudit', 'Chapter 4 and 8'],
        ['plpgsql_check','Chapter 6'],
        ['plpgsql', 'the whole book'],
        ['plpython3u','Chapter 6, and 3-19'],
        ['vector', 'Chapters 16 through 19'],
        ['btree_gist', 'basic data setup'],
        ['unaccent', 'Chapter 14']
        ];
    v_array_length INTEGER;
BEGIN
    v_array_length := array_length(v_extensions,1);
    -- iterate through the array of arrays
    FOR i IN 1..v_array_length LOOP
        IF NOT EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = v_extensions[i][1]) THEN
            RAISE NOTICE 'Required extension % is not available. The extension is needed for %', v_extensions[i][1], v_extensions[i][2];
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

CALL check_extension_list();