# .NET Entity Framework Migrations Guide

## Setup EF Core Tools

First, install the EF Core tools globally:

```bash
dotnet tool install --global dotnet-ef --version 9.0.0
```

If you get an error, try updating instead:

```bash
dotnet tool update --global dotnet-ef
```

## Create Initial Migration

Navigate to the .NET project directory:

```bash
cd dotnet-food-ordering
```

Create the initial migration:

```bash
dotnet ef migrations add InitialCreate
```

✅ **Note**: The project includes a `ApplicationDbContextFactory` that allows migrations to be created without a running database. This is a design-time factory that EF Core uses when creating migrations.

This will create a `Migrations` folder with the migration files.

## Apply Migrations

### Option 1: Automatic (Recommended for Development)
The app will automatically apply migrations on startup (already configured in `Program.cs`).

Just start the app:
```bash
dotnet run
```

### Option 2: Manual
Apply migrations manually:

```bash
dotnet ef database update
```

## Common Commands

### Create a new migration
```bash
dotnet ef migrations add <MigrationName>
```

### Apply all pending migrations
```bash
dotnet ef database update
```

### Rollback to a specific migration
```bash
dotnet ef database update <MigrationName>
```

### Remove the last migration (if not applied)
```bash
dotnet ef migrations remove
```

### List all migrations
```bash
dotnet ef migrations list
```

## Database Connection

Make sure MySQL is running (via XAMPP) and the database exists:

1. Start XAMPP MySQL
2. Open phpMyAdmin: `http://localhost/phpmyadmin`
3. Create database: `foodordering`

The connection string in `Program.cs` will use:
- Host: `localhost`
- Database: `foodordering`
- User: `root`
- Password: (empty)

## Troubleshooting

### "dotnet-ef not found"
```bash
export PATH="$PATH:$HOME/.dotnet/tools"
dotnet ef --version
```

### "Unable to connect to MySQL"
- Ensure XAMPP MySQL is running
- Verify database `foodordering` exists
- Check connection string in `Program.cs`

### Migration already exists
If you get "migration already exists", either:
- Remove it: `dotnet ef migrations remove`
- Or use a different name: `dotnet ef migrations add InitialCreate2`
