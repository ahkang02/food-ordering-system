using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using FoodOrdering.Data;
using FoodOrdering.Models;

namespace FoodOrdering.Controllers;

[ApiController]
[Route("api/[controller]")]
public class MenuController : ControllerBase
{
    private readonly ApplicationDbContext _context;

    public MenuController(ApplicationDbContext context)
    {
        _context = context;
    }

    [HttpGet]
    public async Task<ActionResult<List<MenuItem>>> GetMenuItems()
    {
        return await _context.MenuItems.OrderBy(m => m.Id).ToListAsync();
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<MenuItem>> GetMenuItem(int id)
    {
        var item = await _context.MenuItems.FindAsync(id);
        if (item == null)
            return NotFound();
        return item;
    }
}

[ApiController]
[Route("api/[controller]")]
public class OrdersController : ControllerBase
{
    private readonly ApplicationDbContext _context;

    public OrdersController(ApplicationDbContext context)
    {
        _context = context;
    }

    [HttpPost]
    public async Task<ActionResult<Order>> CreateOrder([FromBody] CreateOrderRequest request)
    {
        if (request.CartItems == null || request.CartItems.Count == 0)
            return BadRequest("Cart cannot be empty");

        var order = new Order
        {
            CustomerName = request.CustomerName,
            CustomerPhone = request.CustomerPhone,
            DeliveryAddress = request.DeliveryAddress,
            Status = "pending",
            CreatedAt = DateTime.UtcNow
        };

        decimal total = 0;
        foreach (var cartItem in request.CartItems)
        {
            var menuItem = await _context.MenuItems.FindAsync(cartItem.MenuItemId);
            if (menuItem != null)
            {
                var orderItem = new OrderItem
                {
                    MenuItemId = menuItem.Id,
                    MenuItemName = menuItem.Name,
                    Quantity = cartItem.Quantity,
                    Price = menuItem.Price
                };
                order.OrderItems.Add(orderItem);
                total += menuItem.Price * cartItem.Quantity;
            }
        }

        order.Total = total;
        _context.Orders.Add(order);
        await _context.SaveChangesAsync();

        return CreatedAtAction(nameof(GetOrder), new { id = order.Id }, order);
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<Order>> GetOrder(int id)
    {
        var order = await _context.Orders
            .Include(o => o.OrderItems)
            .FirstOrDefaultAsync(o => o.Id == id);
        
        if (order == null)
            return NotFound();
        
        return order;
    }
}

public class CreateOrderRequest
{
    public List<CartItemDto> CartItems { get; set; } = new();
    public string? CustomerName { get; set; }
    public string? CustomerPhone { get; set; }
    public string? DeliveryAddress { get; set; }
}

public class CartItemDto
{
    public int MenuItemId { get; set; }
    public int Quantity { get; set; }
}

