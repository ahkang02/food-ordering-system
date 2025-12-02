#!/bin/bash
set -e

echo "=== .NET Database Migration Script ==="

# Check required environment variables
if [ -z "$DB_ENDPOINT" ] || [ -z "$DB_USERNAME" ] || [ -z "$DB_PASSWORD" ]; then
    echo "Error: Required environment variables not set"
    echo "Required: DB_ENDPOINT, DB_USERNAME, DB_PASSWORD"
    exit 1
fi

APP_DIR="/opt/food-ordering/current"
DB_NAME="foodordering"

echo "Database: $DB_NAME"
echo "Endpoint: $DB_ENDPOINT"
echo "App Directory: $APP_DIR"

# Navigate to application directory
cd "$APP_DIR"

# Set connection string
export ConnectionStrings__DefaultConnection="Server=$DB_ENDPOINT;Database=$DB_NAME;User Id=$DB_USERNAME;Password=$DB_PASSWORD;"

# Install EF Core tools if not present
if ! dotnet tool list -g | grep -q dotnet-ef; then
    echo "Installing EF Core tools..."
    dotnet tool install --global dotnet-ef
fi

# Ensure PATH includes dotnet tools
export PATH="$PATH:$HOME/.dotnet/tools"

# Run migrations
echo "Running EF Core migrations..."
dotnet ef database update --no-build --verbose

echo "=== Migration completed ==="
