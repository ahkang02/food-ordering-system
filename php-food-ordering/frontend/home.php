<?php
ob_start();
?>

<div style="max-width: 600px; margin: 0 auto;">
    <div class="text-center mb-8">
        <h1 class="text-4xl mb-4">Our Menu</h1>
        <p class="text-text-light">
            Discover our delicious selection of dishes.
        </p>
    </div>

    <!-- Categories -->
    <div style="display: flex; justify-content: center; gap: 0.75rem; flex-wrap: wrap; margin-bottom: 2rem; position: sticky; top: 4.5rem; background: var(--background); padding: 1rem 0; z-index: 40;">
        <?php foreach ($categories as $cat): ?>
            <a href="/?category=<?php echo urlencode($cat); ?>" 
               style="padding: 0.5rem 1rem; border-radius: 9999px; font-weight: 500; font-size: 0.9rem; transition: all 0.2s; 
                      <?php echo $activeCategory === $cat ? 'background-color: var(--primary); color: white; box-shadow: 0 4px 6px rgba(0,0,0,0.1);' : 'background-color: white; color: var(--text-light);'; ?>">
                <?php echo $cat; ?>
            </a>
        <?php endforeach; ?>
    </div>

    <!-- Menu Grid -->
    <div class="grid grid-cols-1" style="gap: 1.5rem;">
        <?php foreach ($filteredItems as $item): ?>
            <div class="bg-surface rounded-xl shadow-sm overflow-hidden" style="display: flex; height: 8rem;">
                <div style="width: 8rem; height: 8rem; flex-shrink: 0;">
                    <img src="<?php echo $item['image_url']; ?>" alt="<?php echo $item['name']; ?>" style="width: 100%; height: 100%; object-fit: cover;">
                </div>
                
                <div style="padding: 1rem; flex: 1; display: flex; flex-direction: column; justify-content: space-between;">
                    <div>
                        <div style="display: flex; justify-content: space-between; align-items: start; margin-bottom: 0.25rem;">
                            <h3 style="font-weight: 700; font-size: 1rem; line-height: 1.2;"><?php echo $item['name']; ?></h3>
                            <span style="font-weight: 700; color: var(--primary); font-size: 0.9rem;">$<?php echo number_format($item['price'], 2); ?></span>
                        </div>
                        <p class="text-text-light" style="font-size: 0.8rem; display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden;">
                            <?php echo $item['description']; ?>
                        </p>
                    </div>
                    
                    <form action="/cart" method="POST">
                        <input type="hidden" name="action" value="add">
                        <input type="hidden" name="id" value="<?php echo $item['id']; ?>">
                        <button type="submit" class="btn btn-primary" style="width: 100%; padding: 0.4rem; font-size: 0.9rem;">
                            Add
                        </button>
                    </form>
                </div>
            </div>
        <?php endforeach; ?>
    </div>

    <?php if (empty($filteredItems)): ?>
        <div class="text-center text-text-light" style="padding: 5rem 0;">
            No items found in this category.
        </div>
    <?php endif; ?>
</div>

<?php
$content = ob_get_clean();
require __DIR__ . '/layout.php';
?>
