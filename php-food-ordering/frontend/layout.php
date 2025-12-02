<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>GourmetNow - Food Ordering</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
    <script src="https://unpkg.com/lucide@latest"></script>
    <style>
        :root {
            --primary: #ff4757;
            --primary-dark: #e84148;
            --secondary: #2f3542;
            --background: #f1f2f6;
            --surface: #ffffff;
            --text: #2f3542;
            --text-light: #747d8c;
            --success: #2ed573;
            --font-main: 'Inter', system-ui, -apple-system, sans-serif;
        }

        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: var(--font-main); background-color: var(--background); color: var(--text); line-height: 1.5; }
        a { text-decoration: none; color: inherit; }
        button { cursor: pointer; border: none; font-family: inherit; }
        .container { max-width: 1200px; margin: 0 auto; padding: 0 1rem; }
        
        /* Header */
        header { background-color: var(--surface); box-shadow: 0 1px 3px rgba(0,0,0,0.1); position: sticky; top: 0; z-index: 50; }
        .header-content { height: 4rem; display: flex; align-items: center; justify-content: space-between; }
        .logo { display: flex; align-items: center; gap: 0.5rem; color: var(--primary); font-weight: 700; font-size: 1.25rem; }
        .nav-link { font-weight: 500; color: var(--text-light); transition: color 0.2s; }
        .nav-link:hover, .nav-link.active { color: var(--primary); }
        .cart-btn { position: relative; padding: 0.5rem; border-radius: 9999px; transition: background-color 0.2s; }
        .cart-btn:hover { background-color: var(--background); }
        .cart-badge { position: absolute; top: 0; right: 0; background-color: var(--primary); color: white; font-size: 0.75rem; font-weight: 700; width: 1.25rem; height: 1.25rem; display: flex; align-items: center; justify-content: center; border-radius: 9999px; }

        /* Main */
        main { padding: 2rem 0; min-height: calc(100vh - 8rem); }

        /* Utilities */
        .text-center { text-align: center; }
        .mb-4 { margin-bottom: 1rem; }
        .mb-8 { margin-bottom: 2rem; }
        .text-4xl { font-size: 2.25rem; font-weight: 700; }
        .text-xl { font-size: 1.25rem; font-weight: 700; }
        .text-text-light { color: var(--text-light); }
        .bg-surface { background-color: var(--surface); }
        .rounded-xl { border-radius: 0.75rem; }
        .shadow-sm { box-shadow: 0 1px 2px rgba(0,0,0,0.05); }
        .grid { display: grid; gap: 1.5rem; }
        .grid-cols-1 { grid-template-columns: repeat(1, 1fr); }
        @media (min-width: 640px) { .grid-cols-2 { grid-template-columns: repeat(2, 1fr); } }
        @media (min-width: 1024px) { .grid-cols-3 { grid-template-columns: repeat(3, 1fr); } }
        @media (min-width: 1280px) { .grid-cols-4 { grid-template-columns: repeat(4, 1fr); } }

        /* Buttons */
        .btn { display: inline-flex; align-items: center; justify-content: center; gap: 0.5rem; padding: 0.5rem 1rem; border-radius: 0.5rem; font-weight: 500; transition: all 0.2s; }
        .btn-primary { background-color: var(--primary); color: white; }
        .btn-primary:hover { background-color: var(--primary-dark); }
        .btn-full { width: 100%; }

        /* Footer */
        footer { background-color: var(--surface); border-top: 1px solid #eee; padding: 2rem 0; margin-top: auto; text-align: center; color: var(--text-light); font-size: 0.875rem; }
    </style>
</head>
<body>
    <header>
        <div class="container header-content">
            <a href="/" class="logo">
                <i data-lucide="utensils-crossed"></i>
                <span>GourmetNow</span>
            </a>
            <nav style="display: flex; gap: 1.5rem; align-items: center;">
                <a href="/" class="nav-link <?php echo $path === '/' ? 'active' : ''; ?>">Menu</a>
                <a href="/checkout" class="cart-btn">
                    <i data-lucide="shopping-bag" color="<?php echo isset($_SESSION['cart']) && count($_SESSION['cart']) > 0 ? '#ff4757' : '#747d8c'; ?>"></i>
                    <?php 
                    $cartCount = 0;
                    if (isset($_SESSION['cart'])) {
                        foreach ($_SESSION['cart'] as $item) {
                            $cartCount += $item['quantity'];
                        }
                    }
                    if ($cartCount > 0): ?>
                        <span class="cart-badge"><?php echo $cartCount; ?></span>
                    <?php endif; ?>
                </a>
            </nav>
        </div>
    </header>

    <main class="container">
        <?php echo $content; ?>
    </main>

    <footer>
        <div class="container">
            <p>&copy; <?php echo date('Y'); ?> GourmetNow. All rights reserved.</p>
        </div>
    </footer>
    <script>
        lucide.createIcons();
    </script>
</body>
</html>
