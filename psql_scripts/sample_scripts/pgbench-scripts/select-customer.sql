/*
-- =================================================================================
Query being called by pgbench scripts to look up a customer.

-- =================================================================================
*/

-- select a  customer based on random last_name and random first_name

SELECT * FROM customer.customer
WHERE last_name = (
    SELECT last_name FROM customer.customer
    ORDER BY RANDOM()
    LIMIT 1
)
AND first_name = (
    SELECT first_name FROM customer.customer
    ORDER BY RANDOM()
    LIMIT 1
)
LIMIT 1;