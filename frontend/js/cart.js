// Cart Management
class Cart {
    constructor() {
        this.items = this.loadCart();
        this.updateCartUI();
    }

    loadCart() {
        const saved = localStorage.getItem('cart');
        return saved ? JSON.parse(saved) : [];
    }

    saveCart() {
        localStorage.setItem('cart', JSON.stringify(this.items));
        this.updateCartUI();
    }

    addItem(menuItem, quantity = 1) {
        const existingItem = this.items.find(item => item.menuItemId === menuItem.id);
        
        if (existingItem) {
            existingItem.quantity += quantity;
        } else {
            this.items.push({
                menuItemId: menuItem.id,
                name: menuItem.name,
                price: menuItem.price,
                quantity: quantity,
            });
        }
        
        this.saveCart();
        this.showToast('Item added to cart!', 'success');
    }

    updateQuantity(menuItemId, quantity) {
        const item = this.items.find(item => item.menuItemId === menuItemId);
        if (item) {
            if (quantity <= 0) {
                this.removeItem(menuItemId);
            } else {
                item.quantity = quantity;
                this.saveCart();
            }
        }
    }

    removeItem(menuItemId) {
        this.items = this.items.filter(item => item.menuItemId !== menuItemId);
        this.saveCart();
    }

    clearCart() {
        this.items = [];
        this.saveCart();
    }

    getTotal() {
        return this.items.reduce((total, item) => total + (item.price * item.quantity), 0);
    }

    getItemCount() {
        return this.items.reduce((count, item) => count + item.quantity, 0);
    }

    updateCartUI() {
        const count = this.getItemCount();
        const cartCountEl = document.querySelector('.cart-count');
        if (cartCountEl) {
            cartCountEl.textContent = count;
            cartCountEl.style.display = count > 0 ? 'inline-block' : 'none';
        }
    }

    showToast(message, type = 'success') {
        const toast = document.getElementById('toast');
        toast.textContent = message;
        toast.className = `toast ${type} show`;
        
        setTimeout(() => {
            toast.classList.remove('show');
        }, 3000);
    }
}

// Initialize cart
const cart = new Cart();

