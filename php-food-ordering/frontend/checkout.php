<?php
ob_start();
$cartTotal = 0;
if (isset($_SESSION['cart'])) {
    foreach ($_SESSION['cart'] as $item) {
        $cartTotal += $item['price'] * $item['quantity'];
    }
}
?>

<a href="/" style="display: inline-flex; align-items: center; gap: 0.5rem; color: var(--text-light); margin-bottom: 1.5rem;">
    <i data-lucide="arrow-left" width="20"></i>
    Back to Menu
</a>

<?php if (empty($_SESSION['cart'])): ?>
    <div class="text-center" style="padding: 5rem 0;">
        <h2 class="text-xl mb-4">Your cart is empty</h2>
        <p class="text-text-light mb-8">Looks like you haven't added anything yet.</p>
        <a href="/" class="btn btn-primary" style="display: inline-block;">Go to Menu</a>
    </div>
<?php else: ?>
    <div class="grid" style="grid-template-columns: 1fr; gap: 2rem;">
        <!-- Cart Items -->
        <div style="grid-column: span 2;">
            <h2 class="text-xl mb-4">Your Order</h2>
            <div class="bg-surface rounded-xl shadow-sm overflow-hidden">
                <?php foreach ($_SESSION['cart'] as $id => $item): ?>
                    <div style="padding: 1rem; border-bottom: 1px solid #eee; display: flex; align-items: center; gap: 1rem;">
                        <img src="<?php echo $item['image_url']; ?>" alt="<?php echo $item['name']; ?>" style="width: 5rem; height: 5rem; object-fit: cover; border-radius: 0.5rem;">
                        <div style="flex: 1;">
                            <h3 style="font-weight: 700;"><?php echo $item['name']; ?></h3>
                            <p style="color: var(--primary); font-weight: 500;">$<?php echo number_format($item['price'], 2); ?></p>
                        </div>
                        <div style="display: flex; align-items: center; gap: 0.75rem;">
                            <form action="/cart" method="POST" style="display: inline;">
                                <input type="hidden" name="action" value="update">
                                <input type="hidden" name="id" value="<?php echo $id; ?>">
                                <input type="hidden" name="delta" value="-1">
                                <button type="submit" style="padding: 0.25rem; border-radius: 9999px; background: #f1f2f6;">
                                    <i data-lucide="minus" width="16"></i>
                                </button>
                            </form>
                            <span style="font-weight: 500; min-width: 1.5rem; text-align: center;"><?php echo $item['quantity']; ?></span>
                            <form action="/cart" method="POST" style="display: inline;">
                                <input type="hidden" name="action" value="update">
                                <input type="hidden" name="id" value="<?php echo $id; ?>">
                                <input type="hidden" name="delta" value="1">
                                <button type="submit" style="padding: 0.25rem; border-radius: 9999px; background: #f1f2f6;">
                                    <i data-lucide="plus" width="16"></i>
                                </button>
                            </form>
                        </div>
                        <form action="/cart" method="POST" style="margin-left: 0.5rem;">
                            <input type="hidden" name="action" value="remove">
                            <input type="hidden" name="id" value="<?php echo $id; ?>">
                            <button type="submit" style="color: var(--text-light); padding: 0.5rem;">
                                <i data-lucide="trash-2" width="20"></i>
                            </button>
                        </form>
                    </div>
                <?php endforeach; ?>
            </div>
        </div>

        <!-- Checkout Form -->
        <div>
            <div class="bg-surface rounded-xl shadow-sm" style="padding: 1.5rem; position: sticky; top: 6rem;">
                <h2 class="text-xl mb-6">Delivery Details</h2>
                <form action="/place_order" method="POST">
                    <div class="mb-4">
                        <label style="display: block; font-size: 0.875rem; font-weight: 500; color: var(--text-light); margin-bottom: 0.25rem;">Full Name</label>
                        <input required type="text" name="name" style="width: 100%; padding: 0.5rem 1rem; border-radius: 0.5rem; border: 1px solid #ddd; outline: none;">
                    </div>
                    <div class="mb-4">
                        <label style="display: block; font-size: 0.875rem; font-weight: 500; color: var(--text-light); margin-bottom: 0.25rem;">Phone Number</label>
                        <input required type="tel" name="phone" style="width: 100%; padding: 0.5rem 1rem; border-radius: 0.5rem; border: 1px solid #ddd; outline: none;">
                    </div>
                    <div class="mb-4">
                        <label style="display: block; font-size: 0.875rem; font-weight: 500; color: var(--text-light); margin-bottom: 0.25rem;">Delivery Address</label>
                        <textarea required name="address" rows="3" style="width: 100%; padding: 0.5rem 1rem; border-radius: 0.5rem; border: 1px solid #ddd; outline: none; resize: none;"></textarea>
                    </div>

                    <div style="border-top: 1px solid #eee; padding-top: 1rem; margin-top: 1.5rem;">
                        <div style="display: flex; justify-content: space-between; color: var(--text-light); margin-bottom: 0.5rem;">
                            <span>Subtotal</span>
                            <span>$<?php echo number_format($cartTotal, 2); ?></span>
                        </div>
                        <div style="display: flex; justify-content: space-between; color: var(--text-light); margin-bottom: 0.5rem;">
                            <span>Delivery Fee</span>
                            <span>$5.00</span>
                        </div>
                        <div style="display: flex; justify-content: space-between; font-weight: 700; font-size: 1.25rem; margin-top: 0.5rem;">
                            <span>Total</span>
                            <span>$<?php echo number_format($cartTotal + 5, 2); ?></span>
                        </div>
                    </div>

                    <button type="submit" class="btn btn-primary btn-full" style="margin-top: 1.5rem; padding: 0.75rem;">
                        <i data-lucide="credit-card" width="20"></i>
                        Place Order
                    </button>
                </form>
            </div>
        </div>
    </div>
    <style>
        @media (min-width: 1024px) {
            .grid { grid-template-columns: 2fr 1fr !important; }
        }
    </style>
<?php endif; ?>

<?php
$content = ob_get_clean();
require __DIR__ . '/layout.php';
?>
