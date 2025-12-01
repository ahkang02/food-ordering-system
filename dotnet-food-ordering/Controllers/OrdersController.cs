using Microsoft.AspNetCore.Mvc;
using FoodOrdering.Models;
using FoodOrdering.Services;

namespace FoodOrdering.Controllers;

[ApiController]
[Route("api/[controller]")]
public class OrdersController : ControllerBase
{
    private readonly DataService _dataService;

    public OrdersController(DataService dataService)
    {
        _dataService = dataService;
    }

    [HttpPost]
    public ActionResult<Order> CreateOrder([FromBody] CreateOrderRequest request)
    {
        if (request.CartItems == null || request.CartItems.Count == 0)
            return BadRequest("Cart cannot be empty");

        var order = _dataService.CreateOrder(
            request.CartItems,
            request.CustomerName,
            request.CustomerPhone,
            request.DeliveryAddress
        );

        return CreatedAtAction(nameof(GetOrder), new { id = order.Id }, order);
    }

    [HttpGet]
    public ActionResult<List<Order>> GetAllOrders()
    {
        return Ok(_dataService.GetAllOrders());
    }

    [HttpGet("{id}")]
    public ActionResult<Order> GetOrder(int id)
    {
        var order = _dataService.GetOrder(id);
        if (order == null)
            return NotFound();
        return Ok(order);
    }

    [HttpPatch("{id}/status")]
    public ActionResult<Order> UpdateOrderStatus(int id, [FromBody] UpdateStatusRequest request)
    {
        var order = _dataService.UpdateOrderStatus(id, request.Status);
        if (order == null)
            return NotFound();
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

