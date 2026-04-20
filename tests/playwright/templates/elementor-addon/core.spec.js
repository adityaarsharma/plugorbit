// PlugOrbit — Elementor Addon Test Template
// Tests: widget panel discovery, editor render, frontend output, responsive
const { test, expect } = require('@playwright/test');

const WIDGET_NAMES = ['My Widget One', 'My Widget Two']; // <-- your widgets
const TEST_PAGE    = '/elementor-test/';                  // page with widgets placed

test.describe('Elementor addon widgets', () => {
  test('widgets appear in Elementor panel search', async ({ page }) => {
    await page.goto('/wp-admin/post-new.php?post_type=page');
    await page.click('#elementor-switch-mode-button');
    await page.waitForSelector('#elementor-panel-elements-wrapper');

    for (const name of WIDGET_NAMES) {
      await page.fill('#elementor-panel-elements-search-input', name);
      await expect(page.locator(`.elementor-element:has-text("${name}")`)).toBeVisible();
    }
  });

  test('frontend renders every widget without errors', async ({ page }) => {
    const errors = [];
    page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });

    await page.goto(TEST_PAGE);
    await page.waitForLoadState('networkidle');

    // Expect at least one Elementor widget wrapper
    await expect(page.locator('.elementor-widget')).toHaveCount.toBeGreaterThan(0);
    expect(errors).toHaveLength(0);
  });

  test('no broken asset URLs on test page', async ({ page }) => {
    const bad = [];
    page.on('response', r => { if (r.status() >= 400) bad.push(`${r.status()} ${r.url()}`); });
    await page.goto(TEST_PAGE);
    await page.waitForLoadState('networkidle');
    expect(bad).toHaveLength(0);
  });

  test('visual snapshot per viewport', async ({ page }) => {
    for (const [vw, vh] of [[1440, 900], [768, 1024], [375, 667]]) {
      await page.setViewportSize({ width: vw, height: vh });
      await page.goto(TEST_PAGE);
      await page.waitForLoadState('networkidle');
      await expect(page).toHaveScreenshot(`elementor-${vw}x${vh}.png`, { maxDiffPixelRatio: 0.03, fullPage: true });
    }
  });
});
