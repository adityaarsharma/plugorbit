// The Plus Addons for Elementor — Core functional tests
const { test, expect } = require('@playwright/test');
const AxeBuilder = require('@axe-core/playwright').default;

test.describe('The Plus Addons — Admin Panel', () => {
  test('settings page loads without PHP errors', async ({ page }) => {
    await page.goto('/wp-admin/admin.php?page=tpa_dashboard');
    await expect(page.getByRole('heading')).toBeVisible();
    // No PHP fatal/warning banners
    await expect(page.locator('.notice-error')).toHaveCount(0);
    await expect(page.locator('text=Fatal error')).toHaveCount(0);
  });

  test('widgets list page loads and shows widget toggles', async ({ page }) => {
    await page.goto('/wp-admin/admin.php?page=tpa_widgets');
    await expect(page.locator('[data-widget]').first()).toBeVisible();
  });

  test('extensions panel accessible', async ({ page }) => {
    await page.goto('/wp-admin/admin.php?page=tpa_extensions');
    await expect(page.locator('body')).not.toContainText('Fatal error');
  });
});

test.describe('The Plus Addons — Elementor Editor', () => {
  test('Elementor editor loads with TPA widgets panel', async ({ page }) => {
    // Create a test page if needed
    await page.goto('/wp-admin/post-new.php?post_type=page');
    const editWithElementor = page.getByRole('link', { name: /Edit with Elementor/i });

    if (await editWithElementor.isVisible()) {
      await editWithElementor.click();
    } else {
      // New page — click "Edit with Elementor" button
      await page.getByRole('button', { name: /Edit with Elementor/i }).click();
    }

    // Wait for Elementor editor frame
    await page.waitForSelector('.elementor-editor-active, #elementor-preview-iframe', {
      timeout: 60_000,
    });
    await expect(page.locator('#elementor-panel')).toBeVisible({ timeout: 60_000 });
  });

  test('TPA widget category visible in Elementor panel', async ({ page }) => {
    await page.goto('/wp-admin/post.php?post=1&action=elementor');
    await page.waitForSelector('#elementor-panel', { timeout: 60_000 });

    // Search for a TPA widget
    await page.fill('#elementor-panel-search-input', 'TP');
    await expect(page.locator('.elementor-element-wrapper').first()).toBeVisible({ timeout: 10_000 });
  });
});

test.describe('The Plus Addons — Frontend Rendering', () => {
  test.beforeEach(async ({ page }) => {
    // Set test page URL via env var or use homepage
    await page.goto(process.env.TPA_TEST_PAGE || '/');
  });

  test('page loads without JS console errors', async ({ page }) => {
    const errors = [];
    page.on('console', msg => {
      if (msg.type() === 'error') errors.push(msg.text());
    });
    await page.goto(process.env.TPA_TEST_PAGE || '/');
    await page.waitForLoadState('networkidle');

    // Filter out known third-party errors
    const pluginErrors = errors.filter(e =>
      e.includes('the-plus-addons') || e.includes('tpa-') || e.includes('theplus')
    );
    expect(pluginErrors, `JS errors: ${pluginErrors.join(', ')}`).toHaveLength(0);
  });

  test('page loads within performance budget', async ({ page }) => {
    const start = Date.now();
    await page.goto(process.env.TPA_TEST_PAGE || '/');
    await page.waitForLoadState('networkidle');
    const loadTime = Date.now() - start;

    expect(loadTime, `Page took ${loadTime}ms (budget: 4000ms)`).toBeLessThan(4000);
  });

  test('no broken images on page', async ({ page }) => {
    await page.waitForLoadState('networkidle');
    const brokenImages = await page.evaluate(() => {
      return Array.from(document.images)
        .filter(img => !img.complete || img.naturalWidth === 0)
        .map(img => img.src);
    });
    expect(brokenImages, `Broken images: ${brokenImages.join(', ')}`).toHaveLength(0);
  });
});

test.describe('The Plus Addons — Accessibility', () => {
  test('homepage passes axe accessibility checks', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    const results = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa'])
      .analyze();

    // Report violations (don't fail on 3rd-party issues)
    const critical = results.violations.filter(v =>
      v.impact === 'critical' || v.impact === 'serious'
    );

    if (critical.length > 0) {
      console.log('Accessibility violations:', JSON.stringify(critical, null, 2));
    }

    expect(critical, `${critical.length} critical/serious a11y violations`).toHaveLength(0);
  });
});

test.describe('The Plus Addons — Visual Regression', () => {
  test('homepage visual snapshot', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');
    await expect(page).toHaveScreenshot('tpa-homepage.png', {
      maxDiffPixelRatio: 0.02,
    });
  });

  test('TPA test page snapshot', async ({ page }) => {
    await page.goto(process.env.TPA_TEST_PAGE || '/tpa-test/');
    await page.waitForLoadState('networkidle');
    await expect(page).toHaveScreenshot('tpa-test-page.png', {
      maxDiffPixelRatio: 0.02,
    });
  });
});
