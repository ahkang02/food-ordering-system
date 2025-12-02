#!/bin/bash
set -e

echo "=== PHP Database Migration Script ==="

# Check required environment variables
if [ -z "$DB_ENDPOINT" ] || [ -z "$DB_USERNAME" ] || [ -z "$DB_PASSWORD" ]; then
    echo "Error: Required environment variables not set"
    echo "Required: DB_ENDPOINT, DB_USERNAME, DB_PASSWORD"
    exit 1
fi

DB_NAME="foodordering"
SCHEMA_FILE="/var/www/html/php-food-ordering/database-schema.sql"

echo "Database: $DB_NAME"
echo "Endpoint: $DB_ENDPOINT"

# Check if schema file exists
if [ ! -f "$SCHEMA_FILE" ]; then
    echo "Error: Schema file not found at $SCHEMA_FILE"
    exit 1
fi

# Test database connection
echo "Testing database connection..."
mysql -h "$DB_ENDPOINT" -u "$DB_USERNAME" -p"$DB_PASSWORD" -e "SELECT 1;" > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Error: Cannot connect to database"
    exit 1
fi

echo "Connection successful!"

# Create database if it doesn't exist
echo "Creating database if not exists..."
mysql -h "$DB_ENDPOINT" -u "$DB_USERNAME" -p"$DB_PASSWORD" -e "CREATE DATABASE IF NOT EXISTS $DB_NAME;"

# Check if tables already exist
TABLE_COUNT=$(mysql -h "$DB_ENDPOINT" -u "$DB_USERNAME" -p"$DB_PASSWORD" -D "$DB_NAME" -sN -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '$DB_NAME';")

if [ "$TABLE_COUNT" -gt 0 ]; then
    echo "Database already has $TABLE_COUNT tables. Skipping schema import."
    echo "To force re-import, manually drop the database first."
else
    echo "Importing schema from $SCHEMA_FILE..."
    mysql -h "$DB_ENDPOINT" -u "$DB_USERNAME" -p"$DB_PASSWORD" "$DB_NAME" < "$SCHEMA_FILE"
    echo "Schema imported successfully!"
fi

echo "=== Migration completed ==="
