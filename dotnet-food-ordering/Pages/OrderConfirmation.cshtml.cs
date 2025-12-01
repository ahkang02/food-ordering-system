using Microsoft.AspNetCore.Mvc.RazorPages;

namespace FoodOrdering.Pages;

public class OrderConfirmationModel : PageModel
{
    [BindProperty(SupportsGet = true)]
    public int OrderId { get; set; }

    public void OnGet()
    {
    }
}

