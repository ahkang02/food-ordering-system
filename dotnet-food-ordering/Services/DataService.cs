using FoodOrdering.Models;
using System.Collections.Concurrent;

namespace FoodOrdering.Services;

public class DataService
{
    private readonly ConcurrentDictionary<int, MenuItem> _menuItems = new();
    private readonly ConcurrentDictionary<int, Order> _orders = new();
    private int _nextOrderId = 1;

    public DataService()
    {
        InitializeMenu();
    }

    private void InitializeMenu()
    {
        var menuItems = new List<MenuItem>
        {
            new() { Id = 1, Name = "Margherita Pizza", Description = "Classic tomato, mozzarella, and basil", Price = 12.99m, Category = "Pizza", ImageUrl = "/images/margherita.jpg" },
            new() { Id = 2, Name = "Pepperoni Pizza", Description = "Pepperoni and mozzarella cheese", Price = 14.99m, Category = "Pizza", ImageUrl = "/images/pepperoni.jpg" },
            new() { Id = 3, Name = "Caesar Salad", Description = "Fresh romaine lettuce with caesar dressing", Price = 8.99m, Category = "Salads", ImageUrl = "/images/caesar.jpg" },
            new() { Id = 4, Name = "Chicken Burger", Description = "Grilled chicken breast with lettuce and mayo", Price = 10.99m, Category = "Burgers", ImageUrl = "/images/chicken-burger.jpg" },
            new() { Id = 5, Name = "Beef Burger", Description = "Juicy beef patty with cheese and vegetables", Price = 11.99m, Category = "Burgers", ImageUrl = "/images/beef-burger.jpg" },
            new() { Id = 6, Name = "French Fries", Description = "Crispy golden fries", Price = 4.99m, Category = "Sides", ImageUrl = "/images/fries.jpg" },
            new() { Id = 7, Name = "Coca Cola", Description = "Refreshing cola drink", Price = 2.99m, Category = "Drinks", ImageUrl = "/images/coke.jpg" },
            new() { Id = 8, Name = "Chocolate Cake", Description = "Rich chocolate cake slice", Price = 6.99m, Category = "Desserts", ImageUrl = "/images/chocolate-cake.jpg" }
        };

        foreach (var item in menuItems)
        {
            _menuItems[item.Id] = item;
        }
    }

    public List<MenuItem> GetAllMenuItems() => _menuItems.Values.OrderBy(m => m.Id).ToList();

    public MenuItem? GetMenuItem(int id) => _menuItems.TryGetValue(id, out var item) ? item : null;

    public List<MenuItem> GetMenuItemsByCategory(string category) =>
        _menuItems.Values.Where(m => m.Category.Equals(category, StringComparison.OrdinalIgnoreCase)).ToList();

    public List<string> GetCategories() =>
        _menuItems.Values.Select(m => m.Category).Distinct().OrderBy(c => c).ToList();

    public Order CreateOrder(List<CartItem> cartItems, string? customerName, string? customerPhone, string? deliveryAddress)
    {
        var order = new Order
        {
            Id = _nextOrderId++,
            CreatedAt = DateTime.UtcNow,
            Status = "pending",
            CustomerName = customerName,
            CustomerPhone = customerPhone,
            DeliveryAddress = deliveryAddress
        };

        foreach (var cartItem in cartItems)
        {
            var menuItem = GetMenuItem(cartItem.MenuItemId);
            if (menuItem != null)
            {
                order.Items.Add(new OrderItem
                {
                    MenuItemId = menuItem.Id,
                    MenuItemName = menuItem.Name,
                    Quantity = cartItem.Quantity,
                    Price = menuItem.Price
                });
                order.Total += menuItem.Price * cartItem.Quantity;
            }
        }

        _orders[order.Id] = order;
        return order;
    }

    public List<Order> GetAllOrders() => _orders.Values.OrderByDescending(o => o.CreatedAt).ToList();

    public Order? GetOrder(int id) => _orders.TryGetValue(id, out var order) ? order : null;

    public Order? UpdateOrderStatus(int id, string status)
    {
        if (_orders.TryGetValue(id, out var order))
        {
            order.Status = status;
            return order;
        }
        return null;
    }
}

