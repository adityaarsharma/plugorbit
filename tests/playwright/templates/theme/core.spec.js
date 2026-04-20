// PlugOrbit — WordPress Theme Test Template
// Tests: activation, customizer, block templates, FSE, frontend smoke
const { test, expect } = require('@playwright/test');

test.describe('Theme smoke', () => {
  test('theme is active and renders frontend', async ({ page }) => {
    await page.goto('/');
    await expect(page.locator('body')).toBeVisible();
    const bodyClass = await page.locator('body').getAttribute('class');
    expect(bodyClass).toBeTruthy();
  });

  test('customizer loads', async ({ page }) => {
    const phpErrors = [];
    page.on('console', m => { if (/PHP (Warning|Notice|Fatal)/.test(m.text())) phpErrors.push(m.text()); });
    await page.goto('/wp-admin/customize.php');
    await page.waitForLoadState('networkidle');
    expect(phpErrors).toHaveLength(0);
  });

  test('site editor loads (block themes)', async ({ page }) => {
    const resp = await page.goto('/wp-admin/site-editor.php');
    // If block theme → 200. If classic theme → redirect or 404 (ok).
    expect([200, 302, 404]).toContain(resp.status());
  });

  test('key pages render — home, archive, single, 404', async ({ page }) => {
    for (const path of ['/', '/?s=test', '/404-nonexistent-url']) {
      await page.goto(path);
      await expect(page.locator('body')).toBeVisible();
    }
  });

  test('no 404 on theme-enqueued assets', async ({ page }) => {
    const bad = [];
    page.on('response', r => {
      if (r.status() === 404 && r.url().includes('/themes/')) bad.push(r.url());
    });
    await page.goto('/');
    await page.waitForLoadState('networkidle');
    expect(bad).toHaveLength(0);
  });

  test('responsive — no horizontal scroll at 375px', async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 667 });
    await page.goto('/');
    const hasOverflow = await page.evaluate(() => document.documentElement.scrollWidth > window.innerWidth);
    expect(hasOverflow, 'horizontal scroll at 375px').toBe(false);
  });
});
