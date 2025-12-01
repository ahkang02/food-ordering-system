using Microsoft.AspNetCore.Mvc.RazorPages;
using FoodOrdering.Models;

namespace FoodOrdering.Pages;

public class CartModel : PageModel
{
    public List<CartItemViewModel> CartItems { get; set; } = new();
    public decimal Total { get; set; }

    public void OnGet()
    {
        // Cart is managed via sessionStorage in the browser
        // This page just displays the cart
        CartItems = new List<CartItemViewModel>();
        Total = 0;
    }
}

public class CartItemViewModel
{
    public int MenuItemId { get; set; }
    public string Name { get; set; } = string.Empty;
    public decimal Price { get; set; }
    public int Quantity { get; set; }
}

