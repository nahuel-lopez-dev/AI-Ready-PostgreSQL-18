#=================================================================================
# File: pgbench-command.sh
# Description: runs a pgbench test against the east_ecommerce_data database
# Run it as a shell script from the psql_scripts/sample_scripts/pgbench-scripts directory
# Prerequisites:
# 1) a running PostgreSQL instance on localhost port 5432
# 2) the east_ecommerce_data database created and populated with data
# 3) the pgbench stored procedures created in the east_ecommerce_data database
# 4) the pg_stat_statements extension created in the east_ecommerce_data database
# 5) the pgbench command line tool installed
# 6) the user postgres with no password access to the east_ecommerce_data database
#=================================================================================


# vacuum full firstly the entire database 

ECHO "Vacuuming the database east_ecommerce_data"

vacuumdb -h localhost -p 5432 --dbname=east_ecommerce_data --full --verbose

# reset the statistics counters
ECHO "Resetting the statistics counters"

psql -h localhost -p 5432 -d east_ecommerce_data -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"

psql -h localhost -p 5432 -d east_ecommerce_data -c "SELECT * FROM pg_stat_reset ();"
psql -h localhost -p 5432 -d east_ecommerce_data -c "SELECT * FROM pg_stat_statements_reset();"


# the commands run against database east_ecommerce_data on localhost port 5432
# 10 concurrent connections for 1200 seconds with 5 threads (jobs)
# progress report every 5 seconds
# the files are run in the order specified, with the @n indicating the relative frequency of execution
pgbench  -h localhost -p 5432 \
-d east_ecommerce_data \
-c 10 -n -T 1200  -P 5 -j 5 \
-f gen-inventory.sql@10 \
-f gen-sales-transactions.sql@4 \
-f delete-sales-transaction-line.sql@1 \
-f update-customer.sql@4 \
-f select-customer.sql@6 \
-f top-customers.sql@2 \
-f top-selling-products.sql@4 > pgbench_run_summary.txt
