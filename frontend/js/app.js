// Main Application
let menuItems = [];
let categories = [];
let currentCategory = 'all';

// Initialize app
document.addEventListener('DOMContentLoaded', () => {
    initializeApp();
});

async function initializeApp() {
    setupEventListeners();
    await loadMenu();
    loadCartPage();
}

function setupEventListeners() {
    // Navigation
    document.querySelectorAll('.nav-btn').forEach(btn => {
        btn.addEventListener('click', (e) => {
            const page = e.target.dataset.page;
            showPage(page);
        });
    });

    // Place order button
    const placeOrderBtn = document.getElementById('place-order-btn');
    if (placeOrderBtn) {
        placeOrderBtn.addEventListener('click', placeOrder);
    }

    // Close modal
    const closeModal = document.querySelector('.close-modal');
    if (closeModal) {
        closeModal.addEventListener('click', closeOrderModal);
    }

    // Close modal on outside click
    const modal = document.getElementById('order-modal');
    if (modal) {
        modal.addEventListener('click', (e) => {
            if (e.target === modal) {
                closeOrderModal();
            }
        });
    }
}

// Page Navigation
function showPage(pageName) {
    // Hide all pages
    document.querySelectorAll('.page').forEach(page => {
        page.classList.remove('active');
    });

    // Show selected page
    const page = document.getElementById(`${pageName}-page`);
    if (page) {
        page.classList.add('active');
    }

    // Update nav buttons
    document.querySelectorAll('.nav-btn').forEach(btn => {
        btn.classList.toggle('active', btn.dataset.page === pageName);
    });

    // Load page-specific content
    if (pageName === 'cart') {
        loadCartPage();
    } else if (pageName === 'orders') {
        loadOrders();
    }
}

// Menu Functions
async function loadMenu() {
    try {
        const [items, cats] = await Promise.all([
            api.getMenuItems(),
            api.getCategories()
        ]);
        
        menuItems = items;
        categories = cats;
        
        renderMenu();
        renderCategoryFilters();
    } catch (error) {
        showError('Failed to load menu. Please check your API configuration.');
        console.error('Error loading menu:', error);
    }
}

function renderCategoryFilters() {
    const filterContainer = document.querySelector('.category-filter');
    if (!filterContainer) return;

    // Keep "All" button
    const allBtn = filterContainer.querySelector('[data-category="all"]');
    filterContainer.innerHTML = '';
    filterContainer.appendChild(allBtn);

    // Add category buttons
    categories.forEach(category => {
        const btn = document.createElement('button');
        btn.className = 'filter-btn';
        btn.textContent = category;
        btn.dataset.category = category;
        btn.addEventListener('click', () => filterByCategory(category));
        filterContainer.appendChild(btn);
    });
}

function filterByCategory(category) {
    currentCategory = category;
    
    // Update filter buttons
    document.querySelectorAll('.filter-btn').forEach(btn => {
        btn.classList.toggle('active', btn.dataset.category === category);
    });
    
    renderMenu();
}

function renderMenu() {
    const container = document.getElementById('menu-items');
    if (!container) return;

    const filteredItems = currentCategory === 'all' 
        ? menuItems 
        : menuItems.filter(item => item.category === currentCategory);

    if (filteredItems.length === 0) {
        container.innerHTML = '<div class="loading">No items found in this category.</div>';
        return;
    }

    container.innerHTML = filteredItems.map(item => `
        <div class="menu-item">
            <div class="menu-item-image">${getFoodEmoji(item.category)}</div>
            <div class="menu-item-content">
                <div class="menu-item-header">
                    <h3 class="menu-item-name">${item.name}</h3>
                    <span class="menu-item-price">$${item.price.toFixed(2)}</span>
                </div>
                <p class="menu-item-description">${item.description}</p>
                <span class="menu-item-category">${item.category}</span>
                <div class="menu-item-actions">
                    ${getQuantityControls(item)}
                </div>
            </div>
        </div>
    `).join('');

    // Attach event listeners
    attachMenuEventListeners();
}

function getFoodEmoji(category) {
    const emojis = {
        'Pizza': '🍕',
        'Burgers': '🍔',
        'Salads': '🥗',
        'Sides': '🍟',
        'Drinks': '🥤',
        'Desserts': '🍰'
    };
    return emojis[category] || '🍽️';
}

function getQuantityControls(item) {
    const cartItem = cart.items.find(ci => ci.menuItemId === item.id);
    const quantity = cartItem ? cartItem.quantity : 0;

    if (quantity === 0) {
        return `<button class="btn-primary" onclick="addToCart(${item.id})">Add to Cart</button>`;
    }

    return `
        <div class="quantity-control">
            <button class="quantity-btn" onclick="updateCartQuantity(${item.id}, ${quantity - 1})">-</button>
            <span class="quantity-display">${quantity}</span>
            <button class="quantity-btn" onclick="updateCartQuantity(${item.id}, ${quantity + 1})">+</button>
        </div>
    `;
}

function attachMenuEventListeners() {
    // Event listeners are attached via onclick in the HTML
}

function addToCart(menuItemId) {
    const item = menuItems.find(m => m.id === menuItemId);
    if (item) {
        cart.addItem(item, 1);
        renderMenu(); // Refresh to show quantity controls
    }
}

function updateCartQuantity(menuItemId, quantity) {
    cart.updateQuantity(menuItemId, quantity);
    renderMenu(); // Refresh to update UI
}

// Cart Functions
function loadCartPage() {
    const cartContent = document.getElementById('cart-content');
    const cartSummary = document.getElementById('cart-summary');
    
    if (!cartContent || !cartSummary) return;

    if (cart.items.length === 0) {
        cartContent.innerHTML = `
            <div class="empty-cart">
                <p>Your cart is empty</p>
                <button class="btn-primary" onclick="showPage('menu')">Browse Menu</button>
            </div>
        `;
        cartSummary.classList.add('hidden');
        return;
    }

    cartContent.innerHTML = cart.items.map(item => `
        <div class="cart-item">
            <div class="cart-item-info">
                <div class="cart-item-name">${item.name}</div>
                <div class="cart-item-price">$${item.price.toFixed(2)} each</div>
            </div>
            <div class="quantity-control">
                <button class="quantity-btn" onclick="updateCartItemQuantity(${item.menuItemId}, ${item.quantity - 1})">-</button>
                <span class="quantity-display">${item.quantity}</span>
                <button class="quantity-btn" onclick="updateCartItemQuantity(${item.menuItemId}, ${item.quantity + 1})">+</button>
            </div>
            <div class="cart-item-total">$${(item.price * item.quantity).toFixed(2)}</div>
        </div>
    `).join('');

    document.getElementById('cart-total-amount').textContent = `$${cart.getTotal().toFixed(2)}`;
    cartSummary.classList.remove('hidden');
}

function updateCartItemQuantity(menuItemId, quantity) {
    cart.updateQuantity(menuItemId, quantity);
    loadCartPage();
}

async function placeOrder() {
    const name = document.getElementById('customer-name').value.trim();
    const phone = document.getElementById('customer-phone').value.trim();
    const address = document.getElementById('delivery-address').value.trim();

    if (!name || !phone || !address) {
        showToast('Please fill in all delivery information', 'error');
        return;
    }

    if (cart.items.length === 0) {
        showToast('Your cart is empty', 'error');
        return;
    }

    const placeOrderBtn = document.getElementById('place-order-btn');
    placeOrderBtn.disabled = true;
    placeOrderBtn.textContent = 'Placing Order...';

    try {
        const orderData = {
            cartItems: cart.items.map(item => ({
                menuItemId: item.menuItemId,
                quantity: item.quantity
            })),
            customerName: name,
            customerPhone: phone,
            deliveryAddress: address
        };

        const order = await api.createOrder(orderData);
        
        cart.clearCart();
        showOrderSuccess(order.id);
        loadCartPage();
        
        // Clear form
        document.getElementById('customer-name').value = '';
        document.getElementById('customer-phone').value = '';
        document.getElementById('delivery-address').value = '';
    } catch (error) {
        showToast('Failed to place order. Please try again.', 'error');
        console.error('Error placing order:', error);
    } finally {
        placeOrderBtn.disabled = false;
        placeOrderBtn.textContent = 'Place Order';
    }
}

function showOrderSuccess(orderId) {
    const modal = document.getElementById('order-modal');
    const orderIdDisplay = document.getElementById('order-id-display');
    
    if (orderIdDisplay) {
        orderIdDisplay.textContent = `#${orderId}`;
    }
    
    if (modal) {
        modal.classList.remove('hidden');
        modal.classList.add('show');
    }
}

function closeOrderModal() {
    const modal = document.getElementById('order-modal');
    if (modal) {
        modal.classList.remove('show');
        setTimeout(() => {
            modal.classList.add('hidden');
        }, 300);
    }
}

// Orders Functions
async function loadOrders() {
    const ordersList = document.getElementById('orders-list');
    if (!ordersList) return;

    ordersList.innerHTML = '<div class="loading">Loading orders...</div>';

    try {
        const orders = await api.getOrders();
        
        if (orders.length === 0) {
            ordersList.innerHTML = '<div class="empty-cart"><p>No orders yet</p></div>';
            return;
        }

        ordersList.innerHTML = orders.map(order => `
            <div class="order-card">
                <div class="order-header">
                    <div>
                        <div class="order-id">Order #${order.id}</div>
                        <div class="order-date">${formatDate(order.createdAt)}</div>
                    </div>
                    <span class="order-status ${order.status}">${order.status}</span>
                </div>
                ${order.customerName ? `<p><strong>Customer:</strong> ${order.customerName}</p>` : ''}
                ${order.deliveryAddress ? `<p><strong>Address:</strong> ${order.deliveryAddress}</p>` : ''}
                <div class="order-items">
                    ${order.items.map(item => `
                        <div class="order-item">
                            <span>${item.menuItemName} x ${item.quantity}</span>
                            <span>$${(item.price * item.quantity).toFixed(2)}</span>
                        </div>
                    `).join('')}
                </div>
                <div class="order-total">Total: $${order.total.toFixed(2)}</div>
            </div>
        `).join('');
    } catch (error) {
        ordersList.innerHTML = '<div class="loading">Failed to load orders. Please check your API configuration.</div>';
        console.error('Error loading orders:', error);
    }
}

function formatDate(dateString) {
    const date = new Date(dateString);
    return date.toLocaleString('en-US', {
        year: 'numeric',
        month: 'short',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
    });
}

// Utility Functions
function showToast(message, type = 'success') {
    const toast = document.getElementById('toast');
    if (toast) {
        toast.textContent = message;
        toast.className = `toast ${type} show`;
        
        setTimeout(() => {
            toast.classList.remove('show');
        }, 3000);
    }
}

function showError(message) {
    showToast(message, 'error');
}

