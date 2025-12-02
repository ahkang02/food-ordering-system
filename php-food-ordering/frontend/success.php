<?php
// Clear cart on success
unset($_SESSION['cart']);
ob_start();
?>

<div class="text-center" style="padding: 5rem 0;">
    <div style="width: 5rem; height: 5rem; background-color: #e6fffa; border-radius: 9999px; display: flex; align-items: center; justify-content: center; margin: 0 auto 1.5rem;">
        <i data-lucide="check-circle" width="40" style="color: var(--success);"></i>
    </div>
    <h1 class="text-4xl mb-4">Order Placed Successfully!</h1>
    <p class="text-text-light mb-8" style="max-width: 400px; margin: 0 auto 2rem;">
        Thank you for your order. We'll start preparing your delicious food right away.
    </p>
    <a href="/" class="btn btn-primary" style="display: inline-flex; padding: 0.75rem 2rem;">
        <i data-lucide="home" width="20"></i>
        Back to Home
    </a>
</div>

<?php
$content = ob_get_clean();
require __DIR__ . '/layout.php';
?>
