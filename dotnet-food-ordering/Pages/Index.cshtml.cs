using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;
using FoodOrdering.Data;

namespace FoodOrdering.Pages;

public class IndexModel : PageModel
{
    private readonly ApplicationDbContext _context;

    public IndexModel(ApplicationDbContext context)
    {
        _context = context;
    }

    public List<Models.MenuItem> MenuItems { get; set; } = new();
    public List<string> Categories { get; set; } = new();

    public async Task OnGetAsync()
    {
        MenuItems = await _context.MenuItems
            .OrderBy(m => m.Id)
            .ToListAsync();

        Categories = await _context.MenuItems
            .Select(m => m.Category)
            .Distinct()
            .OrderBy(c => c)
            .ToListAsync();
    }
}

