// PlugOrbit — Generic WordPress Plugin Test Template
// Copy this file, replace PLUGIN_SLUG and selectors with your plugin's specifics.
//
// Usage:
//   WP_TEST_URL=http://my-site.local npx playwright test tests/playwright/my-plugin/

const { test, expect } = require('@playwright/test');
const AxeBuilder = require('@axe-core/playwright').default;

const PLUGIN_SLUG = 'my-plugin'; // <-- CHANGE ME
const ADMIN_SLUG  = 'my-plugin'; // <-- admin menu slug, e.g. admin.php?page=my-plugin

test.describe('Generic plugin smoke', () => {
  test('admin menu item appears', async ({ page }) => {
    await page.goto('/wp-admin/');
    await expect(page.locator(`a[href*="${ADMIN_SLUG}"]`)).toBeVisible();
  });

  test('settings page loads without PHP errors', async ({ page }) => {
    const phpErrors = [];
    page.on('console', msg => {
      if (/PHP (Warning|Notice|Fatal|Parse error)/.test(msg.text())) phpErrors.push(msg.text());
    });

    await page.goto(`/wp-admin/admin.php?page=${ADMIN_SLUG}`);
    await page.waitForLoadState('networkidle');

    expect(phpErrors, `PHP errors in plugin admin:\n${phpErrors.join('\n')}`).toHaveLength(0);
  });

  test('no 404s on plugin-enqueued assets', async ({ page }) => {
    const bad = [];
    page.on('response', r => {
      if (r.status() === 404 && r.url().includes(PLUGIN_SLUG)) bad.push(r.url());
    });

    await page.goto('/');
    await page.waitForLoadState('networkidle');

    expect(bad, `404s on plugin assets:\n${bad.join('\n')}`).toHaveLength(0);
  });

  test('no plugin-scoped JS errors on frontend', async ({ page }) => {
    const errors = [];
    page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });

    await page.goto('/');
    await page.waitForLoadState('networkidle');

    const pluginErrors = errors.filter(e => e.toLowerCase().includes(PLUGIN_SLUG));
    expect(pluginErrors, `JS errors:\n${pluginErrors.join('\n')}`).toHaveLength(0);
  });

  test('accessibility — no WCAG A/AA violations on homepage', async ({ page }) => {
    await page.goto('/');
    const results = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa'])
      .analyze();
    expect(results.violations, JSON.stringify(results.violations, null, 2)).toEqual([]);
  });

  test('visual regression — homepage snapshot', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');
    await expect(page).toHaveScreenshot('homepage.png', { maxDiffPixelRatio: 0.02, fullPage: true });
  });
});
