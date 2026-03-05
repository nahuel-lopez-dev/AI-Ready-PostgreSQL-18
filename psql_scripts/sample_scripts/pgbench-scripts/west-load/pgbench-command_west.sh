pgbench  -h localhost -p 5432 \
-d west_ecommerce_data \
-c 10 -n -T 18000  -P 5 -j 5 \
-f gen-sales-transactions.sql@4 \
> pgbench_run_summary_west.txt