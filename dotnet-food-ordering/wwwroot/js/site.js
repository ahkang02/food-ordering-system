// Global cart management
let cart = [];

// Load cart from sessionStorage
function loadCart() {
    const cartJson = sessionStorage.getItem('cart');
    cart = cartJson ? JSON.parse(cartJson) : [];
    updateCartBadge();
}

// Save cart to sessionStorage
function saveCart() {
    sessionStorage.setItem('cart', JSON.stringify(cart));
    updateCartBadge();
}

// Add item to cart
function addToCart(itemId, itemName, itemPrice) {
    const existingItem = cart.find(item => item.menuItemId === itemId);
    
    if (existingItem) {
        existingItem.quantity += 1;
    } else {
        cart.push({
            menuItemId: itemId,
            name: itemName,
            price: itemPrice,
            quantity: 1
        });
    }
    
    saveCart();
    showNotification('Item added to cart!');
}

// Update cart badge
function updateCartBadge() {
    const badge = document.getElementById('cart-badge');
    if (badge) {
        const count = cart.reduce((sum, item) => sum + item.quantity, 0);
        if (count > 0) {
            badge.textContent = count;
            badge.style.display = 'inline-block';
        } else {
            badge.style.display = 'none';
        }
    }
}

// Show notification
function showNotification(message) {
    // Simple alert for now, can be enhanced with toast
    console.log(message);
}

// Initialize on page load
document.addEventListener('DOMContentLoaded', function() {
    loadCart();
});

