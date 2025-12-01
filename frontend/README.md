# Food Ordering Frontend

A modern, responsive frontend for the food ordering system. Works with both .NET Core 9 and PHP backends.

## Features

- 🎨 Modern, beautiful UI with smooth animations
- 📱 Fully responsive design (mobile, tablet, desktop)
- 🛒 Shopping cart with quantity management
- 📋 Menu browsing with category filters
- 📦 Order placement and tracking
- 🔔 Toast notifications for user feedback
- ⚡ Fast and lightweight (vanilla JavaScript, no frameworks)

## Setup

1. **Configure API URL**

   Edit `js/config.js` and set the `baseURL` to match your backend:

   ```javascript
   const API_CONFIG = {
       // For local .NET Core backend
       baseURL: 'http://localhost:5000/api',
       
       // For local PHP backend
       // baseURL: 'http://localhost:8000/api',
       
       // For EC2 deployment
       // baseURL: 'http://your-ec2-ip:5000/api',  // .NET
       // baseURL: 'http://your-ec2-ip/api',        // PHP
   };
   ```

2. **Serve the frontend**

   You can use any web server. Here are a few options:

   **Option 1: Python HTTP Server**
   ```bash
   cd frontend
   python3 -m http.server 8080
   ```
   Then open: http://localhost:8080

   **Option 2: PHP Built-in Server**
   ```bash
   cd frontend
   php -S localhost:8080
   ```

   **Option 3: Node.js http-server**
   ```bash
   npx http-server frontend -p 8080
   ```

   **Option 4: Apache/Nginx**
   - Place the `frontend` folder in your web server's document root
   - Access via your web server URL

## File Structure

```
frontend/
├── index.html          # Main HTML file
├── css/
│   └── style.css      # All styles
├── js/
│   ├── config.js      # API configuration
│   ├── api.js         # API service layer
│   ├── cart.js        # Cart management
│   └── app.js         # Main application logic
└── README.md
```

## Usage

1. **Browse Menu**: View all menu items, filter by category
2. **Add to Cart**: Click "Add to Cart" or use quantity controls
3. **View Cart**: Click the Cart button in navigation
4. **Place Order**: Fill in delivery information and place order
5. **Track Orders**: View all orders in the Orders section

## CORS Configuration

If you encounter CORS errors, make sure your backend has CORS enabled:

- **.NET Core**: Already configured in `Program.cs`
- **PHP**: CORS headers are set in `menu.php` and `orders.php`

## EC2 Deployment

### Option 1: Serve with Nginx

1. **Upload frontend files** to `/var/www/html/food-ordering` (or your preferred location)

2. **Configure Nginx**:
   ```nginx
   server {
       listen 80;
       server_name your-domain.com;
       root /var/www/html/food-ordering;
       index index.html;

       location / {
           try_files $uri $uri/ /index.html;
       }
   }
   ```

3. **Update API config** in `js/config.js` to point to your backend EC2 instance

### Option 2: Serve with Apache

1. **Upload frontend files** to `/var/www/html/food-ordering`

2. **Create `.htaccess`** (if not using Apache's default config):
   ```apache
   RewriteEngine On
   RewriteBase /
   RewriteRule ^index\.html$ - [L]
   RewriteCond %{REQUEST_FILENAME} !-f
   RewriteCond %{REQUEST_FILENAME} !-d
   RewriteRule . /index.html [L]
   ```

3. **Update API config** in `js/config.js`

### Option 3: Serve with Backend (Same Origin)

You can also serve the frontend from the same server as your backend:

- **.NET Core**: Place frontend files in `wwwroot` folder
- **PHP**: Place frontend files in the same directory or subdirectory

Then update `config.js` to use relative paths:
```javascript
baseURL: '/api'  // Relative path
```

## Browser Support

- Chrome (latest)
- Firefox (latest)
- Safari (latest)
- Edge (latest)
- Mobile browsers (iOS Safari, Chrome Mobile)

## Customization

### Colors

Edit CSS variables in `css/style.css`:
```css
:root {
    --primary-color: #ff6b35;
    --secondary-color: #004e89;
    /* ... */
}
```

### Menu Items

Menu items are loaded from the backend API. To add/remove items, update your backend's menu data.

## Troubleshooting

**CORS Errors:**
- Ensure backend CORS is configured correctly
- Check that API URL in `config.js` matches your backend URL

**API Not Loading:**
- Check browser console for errors
- Verify backend is running
- Check network tab for failed requests
- Ensure API URL is correct in `config.js`

**Cart Not Persisting:**
- Cart uses localStorage, ensure it's enabled in your browser
- Check browser console for localStorage errors

## License

Free to use and modify for your projects.

