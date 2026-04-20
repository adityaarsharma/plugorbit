// PlugOrbit — Gutenberg Block Plugin Test Template
// Tests: block inserter discovery, save+reload, block.json validity, frontend render
const { test, expect } = require('@playwright/test');

const BLOCK_NAMES = ['My Block One', 'My Block Two']; // <-- your blocks
const BLOCK_NAMESPACE = 'my-plugin';                   // <-- from block.json "name"

test.describe('Gutenberg block plugin', () => {
  test('blocks appear in block inserter', async ({ page }) => {
    await page.goto('/wp-admin/post-new.php');
    await page.waitForSelector('.edit-post-header');

    // Close welcome modal if present
    const close = page.locator('button[aria-label="Close"]');
    if (await close.isVisible().catch(() => false)) await close.click();

    await page.click('button[aria-label="Toggle block inserter"]');
    for (const name of BLOCK_NAMES) {
      await page.fill('input[placeholder="Search"]', name);
      await expect(page.locator(`button.block-editor-block-types-list__item:has-text("${name}")`)).toBeVisible();
    }
  });

  test('block survives save + reload', async ({ page }) => {
    await page.goto('/wp-admin/post-new.php');
    await page.waitForSelector('.edit-post-header');

    // Insert first block via slash command
    await page.click('.block-editor-default-block-appender__content');
    await page.keyboard.type(`/${BLOCK_NAMES[0]}`);
    await page.keyboard.press('Enter');

    // Save draft
    await page.click('button:has-text("Save draft")');
    await page.waitForSelector('text=Draft saved');

    // Reload and assert block still present
    await page.reload();
    await expect(page.locator(`[data-type*="${BLOCK_NAMESPACE}/"]`)).toBeVisible();
  });

  test('frontend renders block without JS errors', async ({ page }) => {
    const errors = [];
    page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
    await page.goto('/gutenberg-test/'); // page with block placed
    await page.waitForLoadState('networkidle');
    expect(errors.filter(e => e.toLowerCase().includes(BLOCK_NAMESPACE))).toHaveLength(0);
  });

  test('visual snapshot of rendered block', async ({ page }) => {
    await page.goto('/gutenberg-test/');
    await page.waitForLoadState('networkidle');
    await expect(page).toHaveScreenshot('gutenberg-rendered.png', { maxDiffPixelRatio: 0.02, fullPage: true });
  });
});
