using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace FoodOrdering.Models;

[Table("orders")]
public class Order
{
    [Key]
    [Column("id")]
    public int Id { get; set; }

    [Column("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [Required]
    [MaxLength(50)]
    [Column("status")]
    public string Status { get; set; } = "pending"; // pending, preparing, ready, completed

    [Column("total", TypeName = "decimal(10,2)")]
    public decimal Total { get; set; }

    [MaxLength(200)]
    [Column("customer_name")]
    public string? CustomerName { get; set; }

    [MaxLength(50)]
    [Column("customer_phone")]
    public string? CustomerPhone { get; set; }

    [MaxLength(500)]
    [Column("delivery_address")]
    public string? DeliveryAddress { get; set; }

    public virtual ICollection<OrderItem> OrderItems { get; set; } = new List<OrderItem>();
}

[Table("order_items")]
public class OrderItem
{
    [Key]
    [Column("id")]
    public int Id { get; set; }

    [Column("order_id")]
    public int OrderId { get; set; }

    [Column("menu_item_id")]
    public int MenuItemId { get; set; }

    [Required]
    [MaxLength(200)]
    [Column("menu_item_name")]
    public string MenuItemName { get; set; } = string.Empty;

    [Column("quantity")]
    public int Quantity { get; set; }

    [Column("price", TypeName = "decimal(10,2)")]
    public decimal Price { get; set; }

    [ForeignKey("OrderId")]
    public virtual Order Order { get; set; } = null!;
}
