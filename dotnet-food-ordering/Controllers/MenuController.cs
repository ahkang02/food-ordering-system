using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using FoodOrdering.Models;
using FoodOrdering.Data;

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
    public async Task<ActionResult<List<MenuItem>>> GetAllMenuItems()
    {
        var items = await _context.MenuItems.OrderBy(m => m.Id).ToListAsync();
        return Ok(items);
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<MenuItem>> GetMenuItem(int id)
    {
        var item = await _context.MenuItems.FindAsync(id);
        if (item == null)
            return NotFound();
        return Ok(item);
    }

    [HttpGet("category/{category}")]
    public async Task<ActionResult<List<MenuItem>>> GetMenuItemsByCategory(string category)
    {
        var items = await _context.MenuItems
            .Where(m => m.Category == category)
            .ToListAsync();
        return Ok(items);
    }

    [HttpGet("categories")]
    public async Task<ActionResult<List<string>>> GetCategories()
    {
        var categories = await _context.MenuItems
            .Select(m => m.Category)
            .Distinct()
            .OrderBy(c => c)
            .ToListAsync();
        return Ok(categories);
    }
}

