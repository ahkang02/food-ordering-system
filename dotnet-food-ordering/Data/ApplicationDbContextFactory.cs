using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;
using FoodOrdering.Data;

namespace FoodOrdering;

public class ApplicationDbContextFactory : IDesignTimeDbContextFactory<ApplicationDbContext>
{
    public ApplicationDbContext CreateDbContext(string[] args)
    {
        var optionsBuilder = new DbContextOptionsBuilder<ApplicationDbContext>();
        
        // Use a dummy connection string for design-time operations
        // This allows migrations to be created without a running database
        var connectionString = "Server=localhost;Database=foodordering;User Id=root;Password=;";
        
        optionsBuilder.UseMySql(
            connectionString,
            new MySqlServerVersion(new Version(8, 0, 21)),
            options => options.EnableRetryOnFailure()
        );

        return new ApplicationDbContext(optionsBuilder.Options);
    }
}
