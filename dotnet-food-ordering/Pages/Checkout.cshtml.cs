using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;
using FoodOrdering.Data;
using FoodOrdering.Models;

namespace FoodOrdering.Pages;

public class CheckoutModel : PageModel
{
    private readonly ApplicationDbContext _context;

    public CheckoutModel(ApplicationDbContext context)
    {
        _context = context;
    }

    [BindProperty]
    public string CustomerName { get; set; } = string.Empty;

    [BindProperty]
    public string CustomerPhone { get; set; } = string.Empty;

    [BindProperty]
    public string DeliveryAddress { get; set; } = string.Empty;

    [BindProperty]
    public string PaymentMethod { get; set; } = string.Empty;

    public void OnGet()
    {
    }

    public IActionResult OnPost()
    {
        // Get cart items from form (passed via hidden field or we'll use API)
        // For simplicity, we'll create order via API call from JavaScript
        // This method will handle the form submission
        
        if (!ModelState.IsValid)
        {
            return Page();
        }

        // In a real implementation, cart would be passed from the form
        // For now, we'll redirect to API endpoint via JavaScript
        return Page();
    }
}

