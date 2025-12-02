// Cart management
function getCart() {
    const cartJson = sessionStorage.getItem('cart');
    return cartJson ? JSON.parse(cartJson) : [];
}

function saveCart(cart) {
    sessionStorage.setItem('cart', JSON.stringify(cart));
    updateCartBadge();
}

function addToCart(menuItemId, name, price, imageUrl) {
    const cart = getCart();
    const existingItem = cart.find(item => item.menuItemId === menuItemId);

    if (existingItem) {
        existingItem.quantity++;
    } else {
        cart.push({
            menuItemId: menuItemId,
            name: name,
            price: price,
            imageUrl: imageUrl,
            quantity: 1
        });
    }

    saveCart(cart);

    // Show feedback
    showToast('Added to cart!');
}

function updateCartBadge() {
    const cart = getCart();
    const badge = document.getElementById('cart-badge');
    if (!badge) return;

    const count = cart.reduce((sum, item) => sum + item.quantity, 0);

    if (count > 0) {
        badge.textContent = count;
        badge.style.display = 'flex';
    } else {
        badge.style.display = 'none';
    }
}

function showToast(message) {
    // Simple toast notification
    const toast = document.createElement('div');
    toast.textContent = message;
    toast.style.cssText = `
        position: fixed;
        bottom: 2rem;
        left: 50%;
        transform: translateX(-50%);
        background: #2ed573;
        color: white;
        padding: 0.75rem 1.5rem;
        border-radius: 0.5rem;
        font-weight: 500;
        z-index: 1000;
        animation: slideUp 0.3s ease-out;
    `;

    document.body.appendChild(toast);

    setTimeout(() => {
        toast.style.animation = 'slideDown 0.3s ease-out';
        setTimeout(() => toast.remove(), 300);
    }, 2000);
}

// Add CSS for toast animations
const style = document.createElement('style');
style.textContent = `
    @keyframes slideUp {
        from { transform: translate(-50%, 100%); opacity: 0; }
        to { transform: translate(-50%, 0); opacity: 1; }
    }
    @keyframes slideDown {
        from { transform: translate(-50%, 0); opacity: 1; }
        to { transform: translate(-50%, 100%); opacity: 0; }
    }
`;
document.head.appendChild(style);
