using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using FoodOrdering.Models;
using FoodOrdering.Data;

namespace FoodOrdering.Controllers;

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
            return BadRequest(new { error = "Cart cannot be empty" });

        var order = new Order
        {
            CustomerName = request.CustomerName ?? "",
            CustomerPhone = request.CustomerPhone ?? "",
            DeliveryAddress = request.DeliveryAddress ?? "",
            Status = "pending",
            CreatedAt = DateTime.UtcNow
        };

        // Calculate total and create order items
        decimal total = 0;
        var orderItems = new List<OrderItem>();

        foreach (var cartItem in request.CartItems)
        {
            var menuItem = await _context.MenuItems.FindAsync(cartItem.MenuItemId);
            if (menuItem == null)
                continue;

            var orderItem = new OrderItem
            {
                MenuItemId = cartItem.MenuItemId,
                MenuItemName = menuItem.Name,
                Quantity = cartItem.Quantity,
                Price = menuItem.Price
            };

            orderItems.Add(orderItem);
            total += menuItem.Price * cartItem.Quantity;
        }

        order.Total = total;
        order.OrderItems = orderItems;

        _context.Orders.Add(order);
        await _context.SaveChangesAsync();

        return CreatedAtAction(nameof(GetOrder), new { id = order.Id }, order);
    }

    [HttpGet]
    public async Task<ActionResult<List<Order>>> GetAllOrders()
    {
        var orders = await _context.Orders
            .Include(o => o.OrderItems)
            .OrderByDescending(o => o.CreatedAt)
            .ToListAsync();
        return Ok(orders);
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<Order>> GetOrder(int id)
    {
        var order = await _context.Orders
            .Include(o => o.OrderItems)
            .FirstOrDefaultAsync(o => o.Id == id);
            
        if (order == null)
            return NotFound();
        return Ok(order);
    }

    [HttpPatch("{id}/status")]
    public async Task<ActionResult<Order>> UpdateOrderStatus(int id, [FromBody] UpdateStatusRequest request)
    {
        var order = await _context.Orders.FindAsync(id);
        if (order == null)
            return NotFound();

        order.Status = request.Status;
        await _context.SaveChangesAsync();

        return Ok(order);
    }
}

public class CreateOrderRequest
{
    public List<CartItem> CartItems { get; set; } = new();
    public string? CustomerName { get; set; }
    public string? CustomerPhone { get; set; }
    public string? DeliveryAddress { get; set; }
}

public class UpdateStatusRequest
{
    public string Status { get; set; } = string.Empty;
}

