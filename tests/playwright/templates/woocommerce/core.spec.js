// PlugOrbit — WooCommerce Extension Test Template
// Tests: shop/cart/checkout render, WC hooks compat, no conflicts
const { test, expect } = require('@playwright/test');

test.describe('WooCommerce extension smoke', () => {
  test('shop page renders without errors', async ({ page }) => {
    const phpErrors = [];
    page.on('console', m => { if (/PHP (Warning|Notice|Fatal)/.test(m.text())) phpErrors.push(m.text()); });
    await page.goto('/shop/');
    await page.waitForLoadState('networkidle');
    expect(phpErrors).toHaveLength(0);
  });

  test('single product page works', async ({ page }) => {
    await page.goto('/shop/');
    const firstProduct = page.locator('.products .product').first();
    await firstProduct.locator('a').first().click();
    await expect(page.locator('.single-product, .product-type-simple')).toBeVisible();
    await expect(page.locator('form.cart')).toBeVisible();
  });

  test('add to cart → cart page shows item', async ({ page }) => {
    await page.goto('/shop/');
    await page.locator('.add_to_cart_button').first().click();
    await page.waitForTimeout(1000);
    await page.goto('/cart/');
    await expect(page.locator('.cart_item, table.shop_table')).toBeVisible();
  });

  test('checkout page loads', async ({ page }) => {
    // seed cart first
    await page.goto('/shop/');
    await page.locator('.add_to_cart_button').first().click();
    await page.goto('/checkout/');
    await expect(page.locator('form.checkout, form.woocommerce-checkout')).toBeVisible();
  });

  test('extension admin settings load', async ({ page }) => {
    const phpErrors = [];
    page.on('console', m => { if (/PHP (Warning|Notice|Fatal)/.test(m.text())) phpErrors.push(m.text()); });
    await page.goto('/wp-admin/admin.php?page=wc-settings'); // adjust tab if yours
    await page.waitForLoadState('networkidle');
    expect(phpErrors).toHaveLength(0);
  });
});
