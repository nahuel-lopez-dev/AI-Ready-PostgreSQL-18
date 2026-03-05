/*
-- =================================================================================
Command being called by pgbench scripts to randomly delete a sales transaction line 
and adjust inventory accordingly.

-- =================================================================================
*/
-- delete_random_sales_transaction_line() is defined in pgbench-stored-procedures.sql
CALL delete_random_sales_transaction_line();
