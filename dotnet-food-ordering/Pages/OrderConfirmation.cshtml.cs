using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.AspNetCore.Mvc;

namespace FoodOrdering.Pages;

public class OrderConfirmationModel : PageModel
{
    [BindProperty(SupportsGet = true)]
    public int OrderId { get; set; }

    public void OnGet()
    {
        // Intentionally left blank: page model only needs OrderId bound for the view.
    }
}

