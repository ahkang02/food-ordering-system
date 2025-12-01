// API Service
class ApiService {
    constructor(baseURL) {
        this.baseURL = baseURL;
    }

    async request(endpoint, options = {}) {
        const url = `${this.baseURL}${endpoint}`;
        const config = {
            headers: {
                'Content-Type': 'application/json',
                ...options.headers,
            },
            ...options,
        };

        if (config.body && typeof config.body === 'object') {
            config.body = JSON.stringify(config.body);
        }

        try {
            const response = await fetch(url, config);
            const data = await response.json();
            
            if (!response.ok) {
                throw new Error(data.error || `HTTP error! status: ${response.status}`);
            }
            
            return data;
        } catch (error) {
            console.error('API Error:', error);
            throw error;
        }
    }

    // Menu endpoints
    async getMenuItems() {
        return this.request('/menu');
    }

    async getMenuItem(id) {
        return this.request(`/menu/${id}`);
    }

    async getMenuItemsByCategory(category) {
        return this.request(`/menu/category/${encodeURIComponent(category)}`);
    }

    async getCategories() {
        return this.request('/menu/categories');
    }

    // Order endpoints
    async createOrder(orderData) {
        return this.request('/orders', {
            method: 'POST',
            body: orderData,
        });
    }

    async getOrders() {
        return this.request('/orders');
    }

    async getOrder(id) {
        return this.request(`/orders/${id}`);
    }

    async updateOrderStatus(id, status) {
        return this.request(`/orders/${id}/status`, {
            method: 'PATCH',
            body: { status },
        });
    }
}

// Initialize API service
const api = new ApiService(API_CONFIG.baseURL);

