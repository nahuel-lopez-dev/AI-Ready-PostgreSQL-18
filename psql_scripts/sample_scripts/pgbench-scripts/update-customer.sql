/*
-- =================================================================================
Query being called by pgbench scripts to update an existing customer by adding
a random home phone number in the phone_numbers JSONB column

-- =================================================================================
*/

-- add a home phone number to the customer table for a random customer    
UPDATE customer.customer
SET phone_numbers = jsonb_set(
    COALESCE(phone_numbers, '{}'),
    '{home}',
    to_jsonb('+1-555-' || LPAD((FLOOR(RANDOM() * 10000))::TEXT, 4, '0'))
)
WHERE id = (
    SELECT id FROM customer.customer
    ORDER BY RANDOM()
    LIMIT 1
);

