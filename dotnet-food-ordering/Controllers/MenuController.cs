using Microsoft.AspNetCore.Mvc;
using FoodOrdering.Models;
using FoodOrdering.Services;

namespace FoodOrdering.Controllers;

[ApiController]
[Route("api/[controller]")]
public class MenuController : ControllerBase
{
    private readonly DataService _dataService;

    public MenuController(DataService dataService)
    {
        _dataService = dataService;
    }

    [HttpGet]
    public ActionResult<List<MenuItem>> GetAllMenuItems()
    {
        return Ok(_dataService.GetAllMenuItems());
    }

    [HttpGet("{id}")]
    public ActionResult<MenuItem> GetMenuItem(int id)
    {
        var item = _dataService.GetMenuItem(id);
        if (item == null)
            return NotFound();
        return Ok(item);
    }

    [HttpGet("category/{category}")]
    public ActionResult<List<MenuItem>> GetMenuItemsByCategory(string category)
    {
        return Ok(_dataService.GetMenuItemsByCategory(category));
    }

    [HttpGet("categories")]
    public ActionResult<List<string>> GetCategories()
    {
        return Ok(_dataService.GetCategories());
    }
}

