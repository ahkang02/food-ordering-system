# Database Migrations in CI/CD

## Overview
The CI/CD pipelines now automatically handle database schema setup and migrations during deployment.

## How It Works

### PHP Application
1. **Deployment**: Code is deployed to EC2 instances via SSM
2. **Migration**: The `scripts/migrate-php-db.sh` script runs on one instance
3. **Process**:
   - Checks if database exists, creates if needed
   - Checks if tables exist
   - If no tables, imports `database-schema.sql`
   - If tables exist, skips import (idempotent)

### .NET Application
1. **Deployment**: Code is deployed to EC2 instances via SSM
2. **Migration**: The `scripts/migrate-dotnet-db.sh` script runs on one instance
3. **Process**:
   - Installs EF Core tools if needed
   - Runs `dotnet ef database update`
   - Applies pending migrations

## Migration Scripts

### PHP: `scripts/migrate-php-db.sh`
- Uses MySQL client to execute SQL schema
- Idempotent (safe to run multiple times)
- Only imports if database is empty

### .NET: `scripts/migrate-dotnet-db.sh`
- Uses Entity Framework Core migrations
- Automatically tracks applied migrations
- Only applies new migrations

## Deployment Flow

```
1. Code Push → GitHub
2. GitHub Actions Triggered
3. Build Application
4. Upload to S3
5. Deploy to EC2 (all instances)
6. Run Migrations (first instance only)
7. Health Check
```

## Required Secrets

Ensure these GitHub secrets are set:
- `DB_ENDPOINT` - RDS endpoint
- `DB_USERNAME` - Database username
- `DB_PASSWORD` - Database password

## Manual Migration

To run migrations manually via SSM:

### PHP
```bash
aws ssm start-session --target <instance-id>
export DB_ENDPOINT=<rds-endpoint>
export DB_USERNAME=admin
export DB_PASSWORD=<password>
/var/www/html/php-food-ordering/scripts/migrate-php-db.sh
```

### .NET
```bash
aws ssm start-session --target <instance-id>
export DB_ENDPOINT=<rds-endpoint>
export DB_USERNAME=admin
export DB_PASSWORD=<password>
/opt/food-ordering/current/scripts/migrate-dotnet-db.sh
```

## Troubleshooting

### Migration Fails
1. Check SSM command output in AWS Console
2. Verify database credentials in GitHub secrets
3. Ensure EC2 has network access to RDS
4. Check security group rules (port 3306)

### Tables Not Created
1. Verify schema file is in deployment package
2. Check migration script logs via SSM
3. Manually connect to RDS to verify

### .NET EF Core Issues
1. Ensure EF Core tools are installed
2. Check connection string format
3. Verify migrations exist in project
