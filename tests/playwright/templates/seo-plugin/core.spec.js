/**
 * Orbit — SEO Plugin Test Template
 *
 * HOW TO USE THIS FOR A NEW PLUGIN:
 * ----------------------------------
 * Step 1: Run the discovery test first (SEO-0 below).
 *         It prints all nav links to the console — copy those exact URLs.
 * Step 2: Replace the slug/URL placeholders in SEO-1 through SEO-7 with
 *         the real URLs from Step 1.
 * Step 3: Run the full suite. Never guess selectors without inspecting first.
 *
 * NEVER:
 *   - Screenshot before calling assertPageReady()
 *   - Use [role="tab"] without confirming it exists in the live DOM
 *   - Assume the settings page URL — always check wp_admin menu links first
 */

const { test, expect } = require('@playwright/test');
const {
  assertPageReady,
  gotoAdmin,
  discoverNavLinks,
  exploreAllTabs,
  slowScroll,
  checkFrontend,
} = require('../../helpers');

const BASE  = process.env.WP_TEST_URL || 'http://localhost:8881';
const ADMIN = `${BASE}/wp-admin`;

// ── REPLACE THIS with your plugin's admin page slug ──────────────────────────
const PLUGIN_PAGE = 'your-plugin-slug';   // e.g. 'nxt_content_seo' or 'rank-math'
const PLUGIN_NAME = 'My SEO Plugin';
// ─────────────────────────────────────────────────────────────────────────────

test.describe(`${PLUGIN_NAME} — SEO Core Tests`, () => {

  // SEO-0: Run this FIRST to discover all nav URLs. Read console output.
  test('SEO-0 | DISCOVERY — print all nav links (run this first)', async ({ page }) => {
    await gotoAdmin(page, PLUGIN_PAGE);

    // Try common nav selectors
    const links = await discoverNavLinks(page, 'a[href*="page="], a[href*="#/"], .nav-tab-wrapper a, [role="tab"]');
    console.log('\n[DISCOVERY] Nav links found:');
    links.forEach(l => console.log(`  ${l.text} → ${l.href}`));
    console.log('\nCopy these URLs into SEO-1 through SEO-7 below.\n');

    // Also check what tab selector works
    const ariaTabCount  = await page.locator('[role="tab"]').count();
    const navTabCount   = await page.locator('.nav-tab-wrapper a').count();
    const customNavCount = await page.locator('.nxtext_navlink, .plugin-nav a').count();
    console.log(`[DISCOVERY] Tab selectors: [role=tab]=${ariaTabCount}, .nav-tab-wrapper a=${navTabCount}, custom=${customNavCount}`);

    expect(links.length).toBeGreaterThan(0);
  });

  // SEO-1: Settings page loads without errors
  test('SEO-1 | Settings page loads', async ({ page }) => {
    await gotoAdmin(page, PLUGIN_PAGE); // assertPageReady called inside gotoAdmin
    const title = await page.title();
    expect(title).not.toMatch(/Error|Fatal|Forbidden/i);
  });

  // SEO-2: Frontend meta tags
  test('SEO-2 | Frontend meta tags — description, canonical, OG', async ({ page }) => {
    const data = await checkFrontend(page, BASE);

    expect(data.metaDesc,   'meta description missing').toBeTruthy();
    expect(data.canonical,  'canonical URL missing').toBeTruthy();
    expect(data.ogTitle,    'og:title missing').toBeTruthy();
    expect(data.twitterCard,'twitter:card missing').toBeTruthy();

    console.log(`[SEO-2] OG: ${data.ogTitle} | Twitter: ${data.twitterCard}`);
  });

  // SEO-3: JSON-LD schema on homepage
  test('SEO-3 | JSON-LD schema on homepage', async ({ page }) => {
    const data = await checkFrontend(page, BASE);
    expect(data.schemaCount, 'No JSON-LD scripts found').toBeGreaterThan(0);
    console.log(`[SEO-3] Schema types: ${data.schemaTypes.join(', ')}`);
  });

  // SEO-4: XML Sitemap
  test('SEO-4 | XML Sitemap accessible', async ({ page }) => {
    // Try common sitemap URLs
    let found = false;
    for (const url of [`${BASE}/sitemap.xml`, `${BASE}/sitemap_index.xml`]) {
      const res = await page.goto(url).catch(() => null);
      if (res && res.status() === 200) {
        const body = await page.content();
        if (body.includes('<urlset') || body.includes('<sitemapindex')) {
          found = true;
          console.log(`[SEO-4] Sitemap found at: ${url}`);
          break;
        }
      }
    }
    expect(found, 'No valid sitemap found at /sitemap.xml or /sitemap_index.xml').toBeTruthy();
  });

  // SEO-5: Redirections page (replace URL with real slug from SEO-0)
  test('SEO-5 | Redirections — page accessible', async ({ page }) => {
    // Replace with real URL from SEO-0 discovery
    // e.g. await gotoAdmin(page, 'rank-math-redirections');
    // e.g. await page.goto(`${ADMIN}/admin.php?page=nxt_content_seo#/advanced/link-redirects`);
    test.skip(true, 'Update URL from SEO-0 discovery output first');
  });

  // SEO-6: Settings depth — count tabs/sections
  test('SEO-6 | Settings depth — count tabs and inputs', async ({ page }) => {
    await gotoAdmin(page, PLUGIN_PAGE);

    const tabCount    = await exploreAllTabs(page, 15);
    const inputCount  = await page.locator('input:not([type=hidden]):not([type=submit])').count();
    const toggleCount = await page.locator('input[type=checkbox]').count();

    console.log(`[SEO-6] Tabs: ${tabCount} | Inputs: ${inputCount} | Toggles: ${toggleCount}`);
    expect(tabCount + inputCount + toggleCount).toBeGreaterThan(0);
  });

  // SEO-7: No PHP errors on settings page
  test('SEO-7 | No PHP errors on settings page', async ({ page }) => {
    const errors = [];
    page.on('console', m => {
      if (/PHP (Warning|Notice|Fatal|Error)/i.test(m.text())) errors.push(m.text());
    });

    await gotoAdmin(page, PLUGIN_PAGE);
    await page.waitForLoadState('networkidle').catch(() => {});

    if (errors.length > 0) {
      console.warn('[SEO-7] PHP errors detected:\n' + errors.join('\n'));
    }
    expect(errors, `PHP errors on settings page: ${errors.join(', ')}`).toHaveLength(0);
  });

});
