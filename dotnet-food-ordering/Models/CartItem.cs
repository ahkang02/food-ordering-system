using System.ComponentModel.DataAnnotations.Schema;

namespace FoodOrdering.Models;

public class CartItem
{
    public int MenuItemId { get; set; }
    public int Quantity { get; set; }
}
