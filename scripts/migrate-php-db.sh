#!/bin/bash
set -e

echo "=== PHP Database Migration Script ==="

# Accept command-line arguments OR environment variables
# Usage: ./migrate-php-db.sh [DB_ENDPOINT] [DB_USERNAME] [DB_PASSWORD]
if [ -n "$1" ]; then
    DB_ENDPOINT="$1"
fi
if [ -n "$2" ]; then
    DB_USERNAME="$2"
fi
if [ -n "$3" ]; then
    DB_PASSWORD="$3"
fi

# Check required variables
if [ -z "$DB_ENDPOINT" ] || [ -z "$DB_USERNAME" ] || [ -z "$DB_PASSWORD" ]; then
    echo "Error: Required database credentials not set"
    echo "Usage: $0 <DB_ENDPOINT> <DB_USERNAME> <DB_PASSWORD>"
    echo "   OR: Set environment variables DB_ENDPOINT, DB_USERNAME, DB_PASSWORD"
    exit 1
fi

DB_NAME="foodordering"
SCHEMA_FILE="/var/www/html/database-schema.sql"

echo "Database: $DB_NAME"
echo "Endpoint: $DB_ENDPOINT"

# Check if schema file exists
if [ ! -f "$SCHEMA_FILE" ]; then
    echo "Error: Schema file not found at $SCHEMA_FILE"
    exit 1
fi

# Parse endpoint - handle both "host" and "host:port" formats
DB_HOST="${DB_ENDPOINT%%:*}"
DB_PORT="${DB_ENDPOINT##*:}"
# If no port was specified (i.e., no colon in endpoint), default to 3306
if [ "$DB_PORT" = "$DB_HOST" ]; then
    DB_PORT="3306"
fi

echo "Host: $DB_HOST, Port: $DB_PORT"

# Test database connection
echo "Testing database connection..."
mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USERNAME" -p"$DB_PASSWORD" -e "SELECT 1;" > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Error: Cannot connect to database"
    echo "Debug: Trying with verbose output..."
    mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USERNAME" -p"$DB_PASSWORD" -e "SELECT 1;" 2>&1 || true
    exit 1
fi

echo "Connection successful!"

# Create database if it doesn't exist
echo "Creating database if not exists..."
mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USERNAME" -p"$DB_PASSWORD" -e "CREATE DATABASE IF NOT EXISTS $DB_NAME;"

# Check if tables already exist
TABLE_COUNT=$(mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USERNAME" -p"$DB_PASSWORD" -D "$DB_NAME" -sN -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '$DB_NAME';")

if [ "$TABLE_COUNT" -gt 0 ]; then
    echo "Database already has $TABLE_COUNT tables. Skipping schema import."
    echo "To force re-import, manually drop the database first."
else
    echo "Importing schema from $SCHEMA_FILE..."
    mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USERNAME" -p"$DB_PASSWORD" "$DB_NAME" < "$SCHEMA_FILE"
    echo "Schema imported successfully!"
fi

echo "=== Migration completed ==="
