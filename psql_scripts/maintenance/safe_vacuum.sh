#!/bin/bash

# Safe vacuum script that handles replication conflicts
# Usage: ./safe_vacuum.sh <database_name>

if [ $# -eq 0 ]; then
    echo "Usage: $0 <database_name>"
    echo "Example: $0 east_ecommerce_data"
    exit 1
fi

DB_NAME=$1
PSQL_OPTS="-h localhost -p 5432 -U postgres"

echo "Starting safe vacuum for database: $DB_NAME"

# Step 1: Temporarily disable related subscriptions
echo "Disabling replication subscriptions..."
case $DB_NAME in
    "east_ecommerce_data")
        psql $PSQL_OPTS -d central_analytics -c "ALTER SUBSCRIPTION east_customer_sales_data_sub DISABLE;" 2>/dev/null || true
        ;;
    "west_ecommerce_data")
        psql $PSQL_OPTS -d central_analytics -c "ALTER SUBSCRIPTION west_customer_sales_data_sub DISABLE;" 2>/dev/null || true
        ;;
    "ecommerce_reference_data")
        psql $PSQL_OPTS -d west_ecommerce_data -c "ALTER SUBSCRIPTION west_product_data_sub DISABLE;" 2>/dev/null || true
        psql $PSQL_OPTS -d east_ecommerce_data -c "ALTER SUBSCRIPTION east_product_data_sub DISABLE;" 2>/dev/null || true
        psql $PSQL_OPTS -d central_analytics -c "ALTER SUBSCRIPTION central_analytics_product_sub DISABLE;" 2>/dev/null || true
        psql $PSQL_OPTS -d aidb -c "ALTER SUBSCRIPTION aidb_product_sub DISABLE;" 2>/dev/null || true
        ;;
esac

# Step 2: Wait a moment for connections to settle
sleep 2

# Step 3: Run vacuum with deadlock prevention
echo "Running vacuum on $DB_NAME..."
vacuumdb $PSQL_OPTS --skip-locked --verbose $DB_NAME

# Step 4: Re-enable subscriptions
echo "Re-enabling replication subscriptions..."
case $DB_NAME in
    "east_ecommerce_data")
        psql $PSQL_OPTS -d central_analytics -c "ALTER SUBSCRIPTION east_customer_sales_data_sub ENABLE;" 2>/dev/null || true
        ;;
    "west_ecommerce_data")
        psql $PSQL_OPTS -d central_analytics -c "ALTER SUBSCRIPTION west_customer_sales_data_sub ENABLE;" 2>/dev/null || true
        ;;
    "ecommerce_reference_data")
        psql $PSQL_OPTS -d west_ecommerce_data -c "ALTER SUBSCRIPTION west_product_data_sub ENABLE;" 2>/dev/null || true
        psql $PSQL_OPTS -d east_ecommerce_data -c "ALTER SUBSCRIPTION east_product_data_sub ENABLE;" 2>/dev/null || true
        psql $PSQL_OPTS -d central_analytics -c "ALTER SUBSCRIPTION central_analytics_product_sub ENABLE;" 2>/dev/null || true
        psql $PSQL_OPTS -d aidb -c "ALTER SUBSCRIPTION aidb_product_sub ENABLE;" 2>/dev/null || true
        ;;
esac

echo "Safe vacuum completed for $DB_NAME"
exit 0