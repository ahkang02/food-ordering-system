# Database Migrations Guide

## Using Entity Framework Migrations

### 1. Install EF Tools (if not already installed)

```bash
dotnet tool install --global dotnet-ef
```

### 2. Create Initial Migration

```bash
dotnet ef migrations add InitialCreate
```

This will create a `Migrations` folder with migration files.

### 3. Apply Migration to Database

```bash
dotnet ef database update
```

This will create the database and all tables if they don't exist.

### 4. For RDS Deployment

Update `appsettings.json` or use environment variables:

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=your-rds-endpoint.region.rds.amazonaws.com;Database=foodordering;User Id=admin;Password=your-password;"
  }
}
```

Then run:
```bash
dotnet ef database update
```

## Alternative: Manual SQL Script

If you prefer to run SQL manually:

1. **For MySQL:** Run `database-schema.sql`
2. **For PostgreSQL:** Run `database-schema-postgresql.sql`

Then update `Program.cs` to remove `EnsureCreated()` and use migrations only.

## Connection String Formats

**MySQL:**
```
Server=host;Database=dbname;User Id=user;Password=pass;
```

**PostgreSQL:**
```
Host=host;Database=dbname;Username=user;Password=pass;
```

## Environment Variables

You can also use environment variables:

```bash
export ConnectionStrings__DefaultConnection="Server=host;Database=dbname;User Id=user;Password=pass;"
```

