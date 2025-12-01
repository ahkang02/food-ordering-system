using Microsoft.EntityFrameworkCore;
using FoodOrdering.Data;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container
builder.Services.AddRazorPages();

// Database configuration
var connectionString = builder.Configuration.GetConnectionString("DefaultConnection") 
    ?? "Server=localhost;Database=foodordering;User Id=root;Password=;";

// Support both MySQL and PostgreSQL
if (connectionString.Contains("Server=") && !connectionString.Contains("Port="))
{
    // MySQL connection
    builder.Services.AddDbContext<ApplicationDbContext>(options =>
        options.UseMySql(connectionString, ServerVersion.AutoDetect(connectionString)));
}
else
{
    // PostgreSQL connection
    builder.Services.AddDbContext<ApplicationDbContext>(options =>
        options.UseNpgsql(connectionString));
}

var app = builder.Build();

// Configure the HTTP request pipeline
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error");
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseRouting();
app.UseAuthorization();
app.MapRazorPages();

// Ensure database is created
using (var scope = app.Services.CreateScope())
{
    var dbContext = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
    dbContext.Database.EnsureCreated();
    
    // Seed initial data if database is empty
    if (!dbContext.MenuItems.Any())
    {
        SeedData(dbContext);
    }
}

app.Run();

static void SeedData(ApplicationDbContext context)
{
    var menuItems = new[]
    {
        new Models.MenuItem { Name = "Margherita Pizza", Description = "Classic tomato, mozzarella, and basil", Price = 12.99m, Category = "Pizza", ImageUrl = "https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=400&h=300&fit=crop" },
        new Models.MenuItem { Name = "Pepperoni Pizza", Description = "Pepperoni and mozzarella cheese", Price = 14.99m, Category = "Pizza", ImageUrl = "https://images.unsplash.com/photo-1628840042765-356cda07504e?w=400&h=300&fit=crop" },
        new Models.MenuItem { Name = "Caesar Salad", Description = "Fresh romaine lettuce with caesar dressing", Price = 8.99m, Category = "Salads", ImageUrl = "https://images.unsplash.com/photo-1546793665-c74611f273ed?w=400&h=300&fit=crop" },
        new Models.MenuItem { Name = "Chicken Burger", Description = "Grilled chicken breast with lettuce and mayo", Price = 10.99m, Category = "Burgers", ImageUrl = "https://images.unsplash.com/photo-1606755962773-d324e0a13086?w=400&h=300&fit=crop" },
        new Models.MenuItem { Name = "Beef Burger", Description = "Juicy beef patty with cheese and vegetables", Price = 11.99m, Category = "Burgers", ImageUrl = "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=400&h=300&fit=crop" },
        new Models.MenuItem { Name = "French Fries", Description = "Crispy golden fries", Price = 4.99m, Category = "Sides", ImageUrl = "https://images.unsplash.com/photo-1573080496219-bb080dd4f877?w=400&h=300&fit=crop" },
        new Models.MenuItem { Name = "Coca Cola", Description = "Refreshing cola drink", Price = 2.99m, Category = "Drinks", ImageUrl = "https://images.unsplash.com/photo-1554866585-cd94860890b7?w=400&h=300&fit=crop" },
        new Models.MenuItem { Name = "Chocolate Cake", Description = "Rich chocolate cake slice", Price = 6.99m, Category = "Desserts", ImageUrl = "https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=400&h=300&fit=crop" }
    };

    context.MenuItems.AddRange(menuItems);
    context.SaveChanges();
}
