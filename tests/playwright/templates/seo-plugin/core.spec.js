// PlugOrbit — SEO Plugin Test Template
// Tests: meta tags output, sitemap, schema injection, admin UI
const { test, expect } = require('@playwright/test');

test.describe('SEO plugin smoke', () => {
  test('meta description is output on homepage', async ({ page }) => {
    await page.goto('/');
    const desc = await page.locator('meta[name="description"]').getAttribute('content');
    expect(desc, 'meta description should not be empty').toBeTruthy();
  });

  test('canonical URL is present', async ({ page }) => {
    await page.goto('/');
    const canonical = await page.locator('link[rel="canonical"]').getAttribute('href');
    expect(canonical).toMatch(/^https?:\/\//);
  });

  test('Open Graph tags are output', async ({ page }) => {
    await page.goto('/');
    await expect(page.locator('meta[property="og:title"]')).toHaveAttribute('content', /.+/);
    await expect(page.locator('meta[property="og:type"]')).toHaveAttribute('content', /.+/);
  });

  test('sitemap index is reachable and valid XML', async ({ request }) => {
    const resp = await request.get('/sitemap_index.xml').catch(() => null)
              || await request.get('/sitemap.xml');
    expect(resp.ok(), 'sitemap should return 200').toBeTruthy();
    expect(await resp.text()).toMatch(/<\?xml/);
  });

  test('JSON-LD schema is injected on homepage', async ({ page }) => {
    await page.goto('/');
    const scripts = await page.locator('script[type="application/ld+json"]').count();
    expect(scripts, 'at least one JSON-LD script should be present').toBeGreaterThan(0);
  });

  test('admin settings page loads without PHP errors', async ({ page }) => {
    const phpErrors = [];
    page.on('console', m => {
      if (/PHP (Warning|Notice|Fatal)/.test(m.text())) phpErrors.push(m.text());
    });
    await page.goto('/wp-admin/admin.php?page=seo-plugin-settings'); // adjust slug
    await page.waitForLoadState('networkidle');
    expect(phpErrors).toHaveLength(0);
  });
});
