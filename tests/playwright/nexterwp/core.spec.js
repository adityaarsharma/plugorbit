// NexterWP Theme + Nexter Blocks + Nexter Extension — Core tests
const { test, expect } = require('@playwright/test');
const AxeBuilder = require('@axe-core/playwright').default;

test.describe('NexterWP — Theme Activation', () => {
  test('theme is active and no critical notices', async ({ page }) => {
    await page.goto('/wp-admin/themes.php');
    await expect(page.locator('.notice-error')).toHaveCount(0);
    await expect(page.locator('text=Fatal error')).toHaveCount(0);
  });

  test('customizer loads without errors', async ({ page }) => {
    await page.goto('/wp-admin/customize.php');
    await page.waitForSelector('#customize-controls', { timeout: 30_000 });
    await expect(page.locator('#customize-controls')).toBeVisible();
    await expect(page.locator('text=Fatal error')).toHaveCount(0);
  });
});

test.describe('NexterWP — Nexter Blocks in Gutenberg', () => {
  test('block editor loads with Nexter Blocks available', async ({ page }) => {
    await page.goto('/wp-admin/post-new.php?post_type=page');
    await page.waitForSelector('.edit-post-layout, .editor-styles-wrapper', { timeout: 30_000 });

    // Open block inserter
    await page.getByLabel('Toggle block inserter').click();
    await page.waitForSelector('.block-editor-inserter__content', { timeout: 10_000 });

    // Search for Nexter block
    const searchInput = page.getByPlaceholder('Search for blocks and patterns');
    await searchInput.fill('Nexter');

    // At least one Nexter block should appear
    await expect(page.locator('.block-editor-block-types-list__item').first())
      .toBeVisible({ timeout: 10_000 });
  });

  test('Nexter Blocks admin page loads', async ({ page }) => {
    await page.goto('/wp-admin/admin.php?page=nexter-blocks');
    await expect(page.locator('body')).not.toContainText('Fatal error');
    await expect(page.locator('h1, h2').first()).toBeVisible();
  });

  test('Nexter Extension settings page loads', async ({ page }) => {
    await page.goto('/wp-admin/admin.php?page=nexter-extension');
    await expect(page.locator('body')).not.toContainText('Fatal error');
  });
});

test.describe('NexterWP — Frontend Rendering', () => {
  test('homepage loads without JS errors', async ({ page }) => {
    const errors = [];
    page.on('console', msg => {
      if (msg.type() === 'error') errors.push(msg.text());
    });

    await page.goto('/');
    await page.waitForLoadState('networkidle');

    const pluginErrors = errors.filter(e =>
      e.includes('nexter') || e.includes('nexterwp') || e.includes('nb-')
    );
    expect(pluginErrors, `JS errors: ${pluginErrors.join(', ')}`).toHaveLength(0);
  });

  test('header builder renders correctly', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    const header = page.locator('header, [class*="site-header"], [class*="nexter-header"]').first();
    await expect(header).toBeVisible();
  });

  test('footer renders correctly', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    const footer = page.locator('footer, [class*="site-footer"]').first();
    await expect(footer).toBeVisible();
  });

  test('single post template renders', async ({ page }) => {
    // Navigate to first post
    await page.goto('/wp-admin/edit.php');
    const firstPostLink = page.locator('.row-title').first();
    const postTitle = await firstPostLink.textContent();
    await firstPostLink.click();
    await page.waitForLoadState('networkidle');

    await expect(page.locator('article, .single-post, main').first()).toBeVisible();
    await expect(page.locator('body')).not.toContainText('Fatal error');
  });

  test('page template renders without horizontal overflow', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    const overflow = await page.evaluate(() =>
      document.documentElement.scrollWidth > document.documentElement.clientWidth
    );
    expect(overflow, 'Horizontal scroll detected').toBe(false);
  });
});

test.describe('NexterWP — Performance Budgets', () => {
  test('homepage loads within 4 seconds', async ({ page }) => {
    const start = Date.now();
    await page.goto('/');
    await page.waitForLoadState('networkidle');
    const elapsed = Date.now() - start;
    expect(elapsed, `Load time ${elapsed}ms exceeds 4000ms budget`).toBeLessThan(4000);
  });

  test('CSS files load without 404', async ({ page }) => {
    const failed = [];
    page.on('response', response => {
      if (response.url().includes('.css') && response.status() === 404) {
        failed.push(response.url());
      }
    });
    await page.goto('/');
    await page.waitForLoadState('networkidle');
    expect(failed, `404 CSS: ${failed.join(', ')}`).toHaveLength(0);
  });

  test('JS files load without 404', async ({ page }) => {
    const failed = [];
    page.on('response', response => {
      if (response.url().includes('.js') && response.status() === 404) {
        failed.push(response.url());
      }
    });
    await page.goto('/');
    await page.waitForLoadState('networkidle');
    expect(failed, `404 JS: ${failed.join(', ')}`).toHaveLength(0);
  });
});

test.describe('NexterWP — Accessibility', () => {
  test('homepage passes WCAG 2.1 AA', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    const results = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa'])
      .exclude('[class*="elementor"]') // exclude Elementor elements
      .analyze();

    const critical = results.violations.filter(v =>
      v.impact === 'critical' || v.impact === 'serious'
    );

    if (critical.length > 0) {
      console.log('A11y violations:', critical.map(v => `${v.id}: ${v.description}`).join('\n'));
    }
    expect(critical).toHaveLength(0);
  });
});

test.describe('NexterWP — Visual Regression', () => {
  test('homepage visual snapshot', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');
    await expect(page).toHaveScreenshot('nexterwp-homepage.png', { maxDiffPixelRatio: 0.02 });
  });

  test('single post visual snapshot', async ({ page }) => {
    await page.goto('/?p=1');
    await page.waitForLoadState('networkidle');
    await expect(page).toHaveScreenshot('nexterwp-single-post.png', { maxDiffPixelRatio: 0.02 });
  });
});
