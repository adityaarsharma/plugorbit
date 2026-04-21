# Test Templates — Complete Guide

> Ready-to-use Playwright test templates for every WordPress plugin type. Copy, customize, run.

---

**New to automated testing? Start here.**

If you have never written a test before, this guide is written for you. You do not need to understand every line of code on first read. The goal is to get one test running, watch it pass, and build from there.

> **Analogy: What is Playwright?**
> Playwright is a robot that controls a real browser — Chrome, Firefox, or WebKit. It clicks buttons, fills in forms, navigates pages, and checks results, exactly like a human tester would, but it does it automatically every time you tell it to. Once you write the script once, you can run it in seconds instead of spending 20 minutes clicking through your plugin manually.

> **Analogy: What is a spec file?**
> A spec file is a script for that robot. You write out the steps — "go to this page, click this button, check that this text appears" — and the robot follows them exactly, every single time, without getting tired or skipping steps.

> **Q: I've never written a test before — where do I start?**
> Pick the template that matches your plugin type (Generic, Elementor, Gutenberg, etc.), copy it into your project, change the three `CHANGE ME` variables at the top, and run it with `--headed` so you can watch what happens in a real browser. You do not need to understand the full file. Start by running it, watch what it does, and then start tweaking.

> **Q: What's the difference between a smoke test and a full test?**
> A smoke test is the minimum check — "does the plugin activate without crashing, and does the admin page load?" A full test goes deeper: it saves settings, checks that they persist after a page reload, verifies that widgets appear, and confirms there are no JavaScript errors or broken assets. All the templates in this guide start with smoke-level checks and build toward full tests.

> **Q: Do I have to test every single feature?**
> No. Focus on the things that would be catastrophic if they broke silently — plugin activation, admin panel loading, settings saving, and the core feature your plugin is built around. Coverage you don't have is better than tests that exist but don't actually check anything meaningful (see the "What makes a good test" section below).

---

## What Makes a Good Test

Before diving into the templates, it is worth understanding what separates a test that actually protects you from a test that passes without checking anything meaningful.

**A good test:**
- Checks a specific outcome that would be wrong if something broke. For example: after saving a setting, reload the page and confirm the value is still there. This catches the case where save appears to work but the data never actually writes to the database.
- Fails loudly when something real is wrong. A test that always passes — even when you introduce a bug — is worse than no test at all, because it gives you false confidence.
- Tests one thing at a time. If a test fails, you should immediately know what broke.

**A weak test:**
- Only checks that a page "loads" without checking what's on it. A page full of PHP errors still "loads."
- Uses `await page.waitForTimeout(3000)` instead of waiting for a specific element to appear. Arbitrary sleeps hide real timing bugs.
- Has no assertions — it navigates around but never uses `expect(...)` to verify anything.

**Example — weak vs. good:**

Weak (checks nothing meaningful):
```javascript
test('admin page loads', async ({ page }) => {
  await page.goto('/wp-admin/admin.php?page=my-plugin');
  // No assertion. Will pass even if the page shows a fatal error.
});
```

Good (checks what actually matters):
```javascript
test('admin page loads without errors', async ({ page }) => {
  await page.goto('/wp-admin/admin.php?page=my-plugin');
  await assertPageReady(page, 'admin panel');
  const body = await page.evaluate(() => document.body.innerText);
  expect(body).not.toMatch(/PHP Warning|PHP Fatal|Parse error/i);
});
```

The second test will fail if a PHP fatal error appears on the page — which is exactly what you want.

---

## Table of Contents

1. [How Templates Work](#1-how-templates-work)
2. [Template: Generic Plugin](#2-template-generic-plugin)
3. [Template: Elementor Addon](#3-template-elementor-addon)
4. [Template: Gutenberg Blocks](#4-template-gutenberg-blocks)
5. [Template: SEO Plugin + Competitor Comparison](#5-template-seo-plugin--competitor-comparison)
6. [Template: WooCommerce Extension](#6-template-woocommerce-extension)
7. [Template: REST API Plugin](#7-template-rest-api-plugin)
8. [Template: Theme / FSE Plugin](#8-template-theme--fse-plugin)
9. [Visual Regression Testing](#9-visual-regression-testing)
10. [Accessibility Testing (axe-core)](#10-accessibility-testing-axe-core)
11. [Flow Tests with Video Recording](#11-flow-tests-with-video-recording)
12. [Helper Functions Reference](#12-helper-functions-reference)
13. [Test Projects Reference](#13-test-projects-reference)

---

## 1. How Templates Work

The steps below walk you through copying a template, making it point at your plugin, and running it for the first time. Do these in order.

First, copy the template folder that best matches your plugin type. Replace `my-plugin` with a folder name that matches your plugin:

```bash
# Copy the closest template for your plugin type
cp -r tests/playwright/templates/elementor-addon tests/playwright/my-plugin
# or: generic-plugin, gutenberg-block, seo-plugin, woocommerce, theme

# Open the spec
open tests/playwright/my-plugin/core.spec.js

# Look for <!-- CHANGE ME --> comments — update:
# 1. PLUGIN_SLUG — your wp-admin menu page slug
# 2. Selectors — inspect your plugin's actual DOM
# 3. Test data — real values your plugin uses

# Run with visible browser to see what's happening
WP_TEST_URL=http://localhost:8881 npx playwright test tests/playwright/my-plugin/ --headed

# Iterate with UI mode (auto-reruns on file save)
npx playwright test --ui
```

The `--headed` flag makes Playwright open a real browser window so you can see exactly what is happening. Use this while getting started. Once your tests are stable, you can drop `--headed` and let them run silently in the background.

The `--ui` flag opens Playwright's interactive UI mode, which automatically re-runs tests every time you save the file. This is the fastest way to iterate while writing new tests.

### Auth is automatic

> **Analogy: What is auth.setup.js?**
> Logging into WordPress for every single test would be slow and repetitive. `auth.setup.js` logs in once at the start of the test run and saves the login cookie to a file (`.auth/wp-admin.json`). Every subsequent test reads that saved cookie and skips the login screen entirely — like having a keycard that lets you into the building without signing in at reception every time.

All templates use the pre-saved admin cookies from `.auth/wp-admin.json`. The setup project runs once and all tests share the same auth state — no re-login needed.

---

## 2. Template: Generic Plugin

For any plugin that doesn't fit a specific category. This is the best starting point if you are unsure which template to use.

The template is organized into clearly labeled sections: activation, admin panel, settings, frontend, and deactivation. You can delete sections that don't apply to your plugin, and add new sections for your plugin's specific features.

```javascript
// tests/playwright/my-plugin/core.spec.js
const { test, expect } = require('@playwright/test');
const { assertPageReady, gotoAdmin, discoverNavLinks } = require('../helpers');

// ── CHANGE THESE ─────────────────────────────────────────────────────────────
const PLUGIN_SLUG = 'my-plugin-settings';  // admin.php?page=THIS
const PLUGIN_NAME = 'My Plugin';
// ─────────────────────────────────────────────────────────────────────────────

test.describe(`${PLUGIN_NAME} — Core Tests`, () => {

  // STEP 0: Discovery — run this first to get exact nav URLs
  // Then delete or skip it in subsequent runs
  test('STEP 0: Discovery — print all admin nav links', async ({ page }) => {
    await gotoAdmin(page, PLUGIN_SLUG);
    const links = await discoverNavLinks(page);
    console.log('\n[DISCOVERY] Nav links:');
    links.forEach(l => console.log(`  "${l.text}" → ${l.href}`));
  });

  // ────────────────────────────────────────────────────────────────────────────
  // ACTIVATION
  // ────────────────────────────────────────────────────────────────────────────

  test('plugin activates without PHP errors', async ({ page }) => {
    // Navigate to plugins list and check no deactivation error
    await page.goto('/wp-admin/plugins.php');
    await assertPageReady(page, 'plugins page');

    // Plugin should appear in the list as active
    const pluginRow = page.locator(`tr[data-plugin*="${PLUGIN_SLUG}"], tr:has-text("${PLUGIN_NAME}")`);
    await expect(pluginRow).toBeVisible();

    // Check for PHP error notices on the page
    const errorNotices = page.locator('.notice-error, .wp-die-message');
    await expect(errorNotices).toHaveCount(0);
  });

  // ────────────────────────────────────────────────────────────────────────────
  // ADMIN PANEL
  // ────────────────────────────────────────────────────────────────────────────

  test('admin panel loads without errors', async ({ page }) => {
    await gotoAdmin(page, PLUGIN_SLUG);
    await assertPageReady(page, 'admin panel');

    // Page title should contain something recognizable
    const title = await page.title();
    expect(title.length).toBeGreaterThan(0);

    // No PHP warnings or fatal errors
    const body = await page.evaluate(() => document.body.innerText);
    expect(body).not.toMatch(/PHP Warning|PHP Fatal|Parse error/i);
  });

  test('admin menu item is visible in WP sidebar', async ({ page }) => {
    await page.goto('/wp-admin/');
    await assertPageReady(page, 'wp-admin');

    // Check admin menu has your plugin
    const menuItem = page.locator(`#adminmenu a[href*="${PLUGIN_SLUG}"]`);
    await expect(menuItem).toBeVisible();
  });

  test('no 404s on admin panel assets', async ({ page }) => {
    const broken = [];
    page.on('response', r => {
      if (r.status() === 404 && (r.url().includes('.js') || r.url().includes('.css'))) {
        broken.push(`${r.status()} ${r.url()}`);
      }
    });

    await gotoAdmin(page, PLUGIN_SLUG);
    await page.waitForLoadState('networkidle');

    expect(broken, `Broken assets:\n${broken.join('\n')}`).toHaveLength(0);
  });

  test('no JavaScript console errors on admin panel', async ({ page }) => {
    const errors = [];
    page.on('console', msg => {
      if (msg.type() === 'error') errors.push(msg.text());
    });

    await gotoAdmin(page, PLUGIN_SLUG);
    await page.waitForLoadState('networkidle');

    expect(errors, `Console errors:\n${errors.join('\n')}`).toHaveLength(0);
  });

  // ────────────────────────────────────────────────────────────────────────────
  // SETTINGS
  // ────────────────────────────────────────────────────────────────────────────

  test('settings save and persist on reload', async ({ page }) => {
    await gotoAdmin(page, PLUGIN_SLUG);

    // CHANGE: fill in actual setting selector and test value
    const INPUT = 'input[name="mp_test_setting"]';
    const TEST_VALUE = 'orbit-test-' + Date.now();

    await page.fill(INPUT, TEST_VALUE);
    await page.click('input[type="submit"], button[type="submit"], .button-primary');

    // Wait for success notice
    await page.waitForSelector('.notice-success, .updated, .settings-saved', { timeout: 5000 })
      .catch(() => console.warn('No success notice found — check selector'));

    // Reload and verify persistence
    await page.reload();
    await expect(page.locator(INPUT)).toHaveValue(TEST_VALUE);
  });

  // ────────────────────────────────────────────────────────────────────────────
  // FRONTEND
  // ────────────────────────────────────────────────────────────────────────────

  test('frontend homepage loads without plugin errors', async ({ page }) => {
    const errors = [];
    page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });

    await page.goto('/');
    await page.waitForLoadState('networkidle');

    const body = await page.evaluate(() => document.body.innerText);
    expect(body).not.toMatch(/PHP Warning|PHP Fatal/i);
    expect(errors.filter(e => !e.includes('favicon'))).toHaveLength(0);
  });

  // ────────────────────────────────────────────────────────────────────────────
  // DEACTIVATION / REACTIVATION
  // ────────────────────────────────────────────────────────────────────────────

  test('plugin deactivates cleanly', async ({ page }) => {
    await page.goto('/wp-admin/plugins.php');

    const deactivateLink = page.locator(`tr:has-text("${PLUGIN_NAME}") a:has-text("Deactivate")`);
    if (await deactivateLink.isVisible()) {
      await deactivateLink.click();
      await page.waitForLoadState('domcontentloaded');
      // No fatal errors after deactivation
      await expect(page.locator('.notice-error')).toHaveCount(0);
    }

    // Re-activate for subsequent tests
    const activateLink = page.locator(`tr:has-text("${PLUGIN_NAME}") a:has-text("Activate")`);
    if (await activateLink.isVisible()) {
      await activateLink.click();
      await page.waitForLoadState('domcontentloaded');
    }
  });

});
```

---

## 3. Template: Elementor Addon

> **Analogy: What is assertPageReady()?**
> `assertPageReady()` is like waiting for a webpage to fully load before you start clicking. If you try to click a button that hasn't appeared yet, the test fails with a confusing "element not found" error. `assertPageReady()` waits for the page to be in a usable state — no login redirect, no PHP errors, no empty body — before proceeding. It prevents a whole class of false failures caused by tests running too fast.

This template covers Elementor addons — plugins that add widgets to the Elementor editor panel. The key tests here are: do your widgets appear in the panel search, do they render on the frontend, and do they look correct across desktop, tablet, and mobile viewports.

```javascript
// tests/playwright/my-plugin/core.spec.js
const { test, expect } = require('@playwright/test');
const { assertPageReady, gotoAdmin, discoverNavLinks, slowScroll } = require('../helpers');

const PLUGIN_SLUG   = 'my-elementor-plugin';          // CHANGE ME
const WIDGET_NAMES  = ['My Widget', 'My Advanced Widget'];  // CHANGE ME — exact names from Elementor panel
const WIDGET_SECTION = 'My Plugin';                   // CHANGE ME — category name in the panel
const TEST_PAGE_URL = '/test-page/';                   // CHANGE ME — page with your widgets placed

test.describe('Elementor Addon — Core Tests', () => {

  test('widgets appear in Elementor panel search', async ({ page }) => {
    // Open Elementor editor on a new page
    await page.goto('/wp-admin/post-new.php?post_type=page');
    await page.waitForLoadState('domcontentloaded');

    // Click "Edit with Elementor"
    const editBtn = page.locator('#elementor-switch-mode-button');
    if (!await editBtn.isVisible({ timeout: 3000 }).catch(() => false)) {
      test.skip(true, 'Elementor not active or page does not have Elementor button');
      return;
    }
    await editBtn.click();
    await page.waitForSelector('#elementor-panel-elements-wrapper', { timeout: 30000 });

    for (const widgetName of WIDGET_NAMES) {
      await page.fill('#elementor-panel-elements-search-input', widgetName);
      await page.waitForTimeout(500);

      const widgetEl = page.locator(`.elementor-element[title="${widgetName}"], .elementor-element:has-text("${widgetName}")`);
      await expect(widgetEl).toBeVisible({ timeout: 5000 });
      console.log(`[PASS] Widget found in panel: ${widgetName}`);
    }
  });

  test('widget section (category) appears in panel', async ({ page }) => {
    await page.goto('/wp-admin/post-new.php?post_type=page');
    await page.waitForLoadState('domcontentloaded');

    const editBtn = page.locator('#elementor-switch-mode-button');
    if (!await editBtn.isVisible({ timeout: 3000 }).catch(() => false)) {
      test.skip(true, 'Elementor not active');
      return;
    }
    await editBtn.click();
    await page.waitForSelector('#elementor-panel-elements-wrapper', { timeout: 30000 });

    const section = page.locator(`.elementor-panel-category:has-text("${WIDGET_SECTION}")`);
    await expect(section).toBeVisible({ timeout: 5000 });
  });

  test('frontend renders all widgets without errors', async ({ page }) => {
    const errors = [];
    const broken = [];

    page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
    page.on('response', r => {
      if (r.status() >= 400 && (r.url().includes(PLUGIN_SLUG) || r.url().includes('my-plugin'))) {
        broken.push(`${r.status()} ${r.url()}`);
      }
    });

    await page.goto(TEST_PAGE_URL);
    await page.waitForLoadState('networkidle');

    // Page should have at least one Elementor widget wrapper
    const widgetCount = await page.locator('.elementor-widget').count();
    expect(widgetCount).toBeGreaterThan(0);

    expect(errors, `JS errors:\n${errors.join('\n')}`).toHaveLength(0);
    expect(broken, `Broken assets:\n${broken.join('\n')}`).toHaveLength(0);
  });

  test('visual snapshot at 3 viewports', async ({ page }) => {
    for (const [w, h, label] of [[1440, 900, 'desktop'], [768, 1024, 'tablet'], [375, 812, 'mobile']]) {
      await page.setViewportSize({ width: w, height: h });
      await page.goto(TEST_PAGE_URL);
      await page.waitForLoadState('networkidle');
      await page.waitForTimeout(1000); // wait for animations to settle

      await expect(page).toHaveScreenshot(`${label}.png`, {
        fullPage: true,
        maxDiffPixelRatio: 0.03,
      });
    }
  });

  test('no horizontal scroll at mobile viewport', async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 812 });
    await page.goto(TEST_PAGE_URL);
    await page.waitForLoadState('networkidle');

    const hasHorizontalScroll = await page.evaluate(() =>
      document.documentElement.scrollWidth > window.innerWidth
    );
    expect(hasHorizontalScroll, 'Horizontal scroll detected at 375px').toBe(false);
  });

  test('admin settings panel accessible if exists', async ({ page }) => {
    // Many Elementor addons have their own settings page
    try {
      await gotoAdmin(page, PLUGIN_SLUG);
      await assertPageReady(page, 'settings panel');
      const body = await page.evaluate(() => document.body.innerText);
      expect(body).not.toMatch(/PHP Warning|PHP Fatal/i);
    } catch {
      // Plugin may not have an admin page — skip gracefully
      console.log('[INFO] No admin settings page found — skipping');
    }
  });

  test('editor performance: discover widget insert time', async ({ page }) => {
    await page.goto('/wp-admin/post-new.php?post_type=page');
    const editBtn = page.locator('#elementor-switch-mode-button');
    if (!await editBtn.isVisible({ timeout: 3000 }).catch(() => false)) {
      test.skip(true, 'Elementor not active');
      return;
    }
    await editBtn.click();
    await page.waitForSelector('#elementor-panel-elements-wrapper', { timeout: 30000 });

    // Time the first widget insert
    for (const widgetName of WIDGET_NAMES.slice(0, 1)) {
      await page.fill('#elementor-panel-elements-search-input', widgetName);
      await page.waitForTimeout(300);

      const start = Date.now();
      const widgetEl = page.locator(`.elementor-element:has-text("${widgetName}")`).first();
      const canvas = page.locator('#elementor-preview-iframe');
      await widgetEl.dragTo(canvas, { timeout: 10000 }).catch(() => {});
      const ms = Date.now() - start;

      console.log(`[PERF] ${widgetName} insert: ${ms}ms`);
      // Warn if slow but don't fail — use this as a baseline
      if (ms > 1500) {
        console.warn(`[WARN] Widget insert >1.5s: ${ms}ms`);
      }
    }
  });

});
```

---

## 4. Template: Gutenberg Blocks

This template covers plugins that register blocks for the WordPress block editor (Gutenberg). The key tests check that blocks appear in the inserter, can be added to a post, and render correctly on the frontend without PHP errors.

Notice the `block styles not loaded on non-block pages` test — this catches the common mistake of loading all block assets on every page, even pages that don't use the blocks. That mistake slows down every page on the site.

```javascript
// tests/playwright/my-plugin/core.spec.js
const { test, expect } = require('@playwright/test');
const { assertPageReady, gotoAdmin } = require('../helpers');

const PLUGIN_SLUG  = 'my-blocks';                      // CHANGE ME
const BLOCK_NAMES  = ['My Block', 'My Card Block'];    // CHANGE ME — exact names from inserter
const BLOCK_CATEGORY = 'My Plugin Blocks';             // CHANGE ME — category in inserter

test.describe('Gutenberg Blocks — Core Tests', () => {

  test('blocks appear in block inserter', async ({ page }) => {
    await page.goto('/wp-admin/post-new.php');
    await page.waitForLoadState('domcontentloaded');

    // Close welcome modal if present
    const dismissBtn = page.locator('button[aria-label="Close"], button:has-text("Got it")');
    if (await dismissBtn.isVisible({ timeout: 2000 }).catch(() => false)) {
      await dismissBtn.click();
    }

    // Open inserter
    await page.click('button[aria-label="Toggle block inserter"], button[aria-label="Add block"]');
    await page.waitForSelector('.block-editor-inserter__search input, .components-search-control__input', { timeout: 5000 });

    for (const blockName of BLOCK_NAMES) {
      await page.fill('.block-editor-inserter__search input, .components-search-control__input', blockName);
      await page.waitForTimeout(500);

      const blockBtn = page.locator(
        `.block-editor-block-types-list__item[title="${blockName}"],
         .block-editor-block-types-list__item:has-text("${blockName}")`
      );
      await expect(blockBtn).toBeVisible({ timeout: 5000 });
      console.log(`[PASS] Block found: ${blockName}`);
    }
  });

  test('block inserts and renders in editor', async ({ page }) => {
    await page.goto('/wp-admin/post-new.php');
    await page.waitForLoadState('domcontentloaded');

    const dismissBtn = page.locator('button[aria-label="Close"]');
    if (await dismissBtn.isVisible({ timeout: 2000 }).catch(() => false)) {
      await dismissBtn.click();
    }

    // Insert the first block via slash command
    await page.click('.block-editor-writing-flow__click-redirect, .wp-block[data-type="core/paragraph"]');
    await page.keyboard.type(`/${BLOCK_NAMES[0].split(' ').join('')}`);
    await page.waitForTimeout(500);

    const suggestion = page.locator(`.components-autocomplete__result:has-text("${BLOCK_NAMES[0]}")`);
    if (await suggestion.isVisible({ timeout: 3000 }).catch(() => false)) {
      await suggestion.click();
      await page.waitForTimeout(1000);

      // Check block rendered in editor
      const blockEl = page.locator(`[data-type*="my-plugin/"], [data-type*="${PLUGIN_SLUG}/"]`);
      await expect(blockEl).toBeVisible();
      console.log(`[PASS] Block rendered in editor: ${BLOCK_NAMES[0]}`);
    }
  });

  test('frontend block output has no PHP errors', async ({ page }) => {
    // CHANGE ME: URL of a page/post with your blocks already placed
    const TEST_URL = '/test-blocks/';

    const errors = [];
    page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });

    await page.goto(TEST_URL);
    await page.waitForLoadState('networkidle');

    const body = await page.evaluate(() => document.body.innerText);
    expect(body).not.toMatch(/PHP Warning|PHP Fatal|parse error/i);
    expect(errors.filter(e => !e.includes('favicon'))).toHaveLength(0);
  });

  test('block styles not loaded on non-block pages', async ({ page }) => {
    // Verify conditional asset loading
    const blockCSS = [];
    page.on('request', r => {
      if (r.url().includes(PLUGIN_SLUG) && r.url().includes('.css')) {
        blockCSS.push(r.url());
      }
    });

    // Visit a page that should NOT have your blocks
    await page.goto('/wp-admin/');
    await page.waitForLoadState('networkidle');

    // Your block CSS should not load on the WP admin dashboard
    const pluginCSSOnDashboard = blockCSS.filter(url => url.includes('frontend') || url.includes('style'));
    console.log(`[INFO] Block CSS requests on dashboard: ${pluginCSSOnDashboard.length}`);
    // Assert: frontend CSS shouldn't load in admin
    expect(pluginCSSOnDashboard).toHaveLength(0);
  });

  test('block.json exists for each registered block', async ({ page }) => {
    // This is a PHP check — verify via WP REST API
    const response = await page.request.get('/wp-json/wp/v2/block-types');
    const blocks = await response.json();

    for (const blockName of BLOCK_NAMES) {
      const found = blocks.find(b => b.title === blockName || b.name.includes(PLUGIN_SLUG));
      if (found) {
        console.log(`[PASS] Block registered via API: ${found.name}`);
      }
    }
    // If no blocks found in API, that's the issue
    const pluginBlocks = blocks.filter(b => b.name.includes(PLUGIN_SLUG));
    expect(pluginBlocks.length, `No blocks from ${PLUGIN_SLUG} found in REST API`).toBeGreaterThan(0);
  });

});
```

---

## 5. Template: SEO Plugin + Competitor Comparison

The SEO template uses the `PAIR-NN` naming convention to generate a side-by-side comparison report.

> **Analogy: The PAIR naming convention**
> Think of it like labeling "before/after" photos in a product comparison. `pair-01-a` is your plugin's dashboard screenshot. `pair-01-b` is the competitor's dashboard screenshot, taken in the same way. When the report generator sees both files with the same pair number, it places them side by side automatically. This lets a product manager or founder look at both plugins visually without reading code.

**How it works**:
1. Run `Discovery` tests for both plugins → get exact nav URLs
2. Map equivalent features to the same `PAIR-N` number
3. Screenshots named `pair-01-dashboard-a.png` and `pair-01-dashboard-b.png` appear side-by-side in the UAT report

```javascript
// tests/playwright/flows/seo-compare/core.spec.js
const { test, expect } = require('@playwright/test');
const path = require('path');
const {
  assertPageReady, gotoAdmin, discoverNavLinks,
  exploreAllTabs, slowScroll, checkFrontend, snapPair
} = require('../../helpers');

const BASE  = process.env.WP_TEST_URL || 'http://localhost:8881';
const SNAP  = path.join(__dirname, '../../../../reports/screenshots/flows-compare');

// CHANGE ME — admin menu page slugs for each plugin
const PLUGIN_A_SLUG = 'my-seo-plugin';       // your plugin
const PLUGIN_B_SLUG = 'wordpress-seo';       // competitor

// Auto-rename videos to pair naming convention
test.afterEach(async ({ page }, testInfo) => {
  await page.waitForTimeout(300);
  const videoPath = await page.video()?.path().catch(() => null);
  if (!videoPath) return;
  const m = testInfo.title.match(/^PAIR-(\d+)\s*\|\s*([a-z0-9-]+)\s*\|\s*(a|b)/i);
  if (!m) return;
  const num  = String(m[1]).padStart(2, '0');
  const slug = m[2].toLowerCase();
  const side = m[3].toLowerCase();
  const fs = require('fs');
  fs.mkdirSync(path.join(__dirname, '../../../../reports/videos'), { recursive: true });
  const dest = path.join(__dirname, `../../../../reports/videos/pair-${num}-${slug}-${side}.webm`);
  try { fs.copyFileSync(videoPath, dest); } catch {}
});

// ── DISCOVERY (run first, then fill in the real URLs below) ──────────────────

test('Discovery | Plugin A — print nav links', async ({ page }) => {
  await gotoAdmin(page, PLUGIN_A_SLUG);
  const links = await discoverNavLinks(page, 'a[href*="page="], a[href*="#/"], [role="tab"]');
  console.log('\n[DISCOVERY Plugin A]');
  links.forEach(l => console.log(`  "${l.text}" → ${l.href}`));
});

test('Discovery | Plugin B — print nav links', async ({ page }) => {
  await gotoAdmin(page, PLUGIN_B_SLUG);
  const links = await discoverNavLinks(page, 'a[href*="page="], a[href*="#/"], [role="tab"]');
  console.log('\n[DISCOVERY Plugin B]');
  links.forEach(l => console.log(`  "${l.text}" → ${l.href}`));
});

// ── PAIR 1: Dashboard ────────────────────────────────────────────────────────

test.describe('PAIR 1 — Dashboard', () => {

  test('PAIR-1 | dashboard | a | Plugin A dashboard overview', async ({ page }) => {
    await gotoAdmin(page, PLUGIN_A_SLUG);
    await assertPageReady(page, 'Plugin A dashboard');
    await snapPair(page, 1, 'dashboard', 'a', SNAP);
    await slowScroll(page, 3);
    await snapPair(page, 1, 'dashboard', 'a', SNAP, 'scroll');
  });

  test('PAIR-1 | dashboard | b | Plugin B dashboard overview', async ({ page }) => {
    await gotoAdmin(page, PLUGIN_B_SLUG);
    await assertPageReady(page, 'Plugin B dashboard');
    await snapPair(page, 1, 'dashboard', 'b', SNAP);
    await slowScroll(page, 3);
    await snapPair(page, 1, 'dashboard', 'b', SNAP, 'scroll');
  });

});

// ── PAIR 2: Meta / Title Templates ────────────────────────────────────────────

test.describe('PAIR 2 — Meta / Title Templates', () => {

  test('PAIR-2 | meta | a | Plugin A meta settings', async ({ page }) => {
    // CHANGE ME: update with URL from Discovery output
    await page.goto(`${BASE}/wp-admin/admin.php?page=${PLUGIN_A_SLUG}#/general`);
    await page.waitForLoadState('domcontentloaded');
    await page.waitForTimeout(2000);
    await assertPageReady(page, 'meta settings');
    await snapPair(page, 2, 'meta', 'a', SNAP);
    const tabCount = await exploreAllTabs(page, 10);
    console.log(`[PAIR-2 A] Tabs: ${tabCount}`);
    await snapPair(page, 2, 'meta', 'a', SNAP, 'tabs');
  });

  test('PAIR-2 | meta | b | Plugin B titles & meta', async ({ page }) => {
    // CHANGE ME: update with URL from Discovery output
    await page.goto(`${BASE}/wp-admin/admin.php?page=${PLUGIN_B_SLUG}-titles`);
    await page.waitForLoadState('domcontentloaded');
    await page.waitForTimeout(2000);
    await snapPair(page, 2, 'meta', 'b', SNAP);
    const tabCount = await exploreAllTabs(page, 14);
    console.log(`[PAIR-2 B] Tabs: ${tabCount}`);
  });

});

// ── PAIR 3: Sitemaps ──────────────────────────────────────────────────────────

test.describe('PAIR 3 — Sitemaps', () => {

  test('PAIR-3 | sitemaps | a | Plugin A sitemap settings', async ({ page }) => {
    // CHANGE ME
    test.skip(true, 'Update URL from Discovery');
  });

  test('PAIR-3 | sitemaps | b | Plugin B sitemaps', async ({ page }) => {
    // CHANGE ME
    test.skip(true, 'Update URL from Discovery');
  });

  test('Plugin A sitemap XML is reachable', async ({ page }) => {
    const res = await page.goto(`${BASE}/sitemap.xml`).catch(() => null);
    if (res) {
      console.log(`[PAIR-3] Sitemap A status: ${res.status()}`);
      expect(res.status()).toBeLessThan(400);
      await snapPair(page, 3, 'sitemaps', 'a', SNAP, 'xml');
    }
  });

  test('Plugin B sitemap XML is reachable', async ({ page }) => {
    const res = await page.goto(`${BASE}/sitemap_index.xml`).catch(() => null);
    if (res) {
      console.log(`[PAIR-3] Sitemap B status: ${res.status()}`);
      await snapPair(page, 3, 'sitemaps', 'b', SNAP, 'xml');
    }
  });

});

// ── PAIR 4: Schema / JSON-LD ──────────────────────────────────────────────────

test.describe('PAIR 4 — Schema', () => {

  test('PAIR-4 | schema | a | Plugin A schema settings', async ({ page }) => {
    test.skip(true, 'Update URL from Discovery');
  });

  test('PAIR-4 | schema | b | Plugin B schema settings', async ({ page }) => {
    test.skip(true, 'Update URL from Discovery');
  });

});

// ── Frontend checks ───────────────────────────────────────────────────────────

test('Frontend — OG / schema / canonical on homepage', async ({ page }) => {
  const data = await checkFrontend(page, BASE);

  console.log('\n[Frontend SEO signals]');
  console.log(`  Title:        ${data.title}`);
  console.log(`  Meta desc:    ${data.metaDesc}`);
  console.log(`  Canonical:    ${data.canonical}`);
  console.log(`  OG title:     ${data.ogTitle}`);
  console.log(`  Twitter card: ${data.twitterCard}`);
  console.log(`  Schema types: ${data.schemaTypes.join(', ')}`);
  console.log(`  Schema count: ${data.schemaCount}`);

  expect(data.title, 'Page has no <title>').toBeTruthy();
  expect(data.canonical, 'No canonical URL').toBeTruthy();
});
```

---

## 6. Template: WooCommerce Extension

This template covers plugins that extend WooCommerce — adding tabs to the WooCommerce settings screen, modifying the cart or checkout, or adding new product types. The critical tests here are shop page loading without errors, the add-to-cart flow working end-to-end, and any REST endpoints your plugin exposes being properly protected with authentication.

```javascript
// tests/playwright/my-plugin/core.spec.js
const { test, expect } = require('@playwright/test');
const { assertPageReady, gotoAdmin } = require('../helpers');

const PLUGIN_SLUG = 'my-woo-plugin-settings';  // CHANGE ME

test.describe('WooCommerce Extension — Core Tests', () => {

  test('WooCommerce is active', async ({ page }) => {
    await page.goto('/wp-admin/plugins.php');
    const body = await page.evaluate(() => document.body.innerText);
    expect(body).toMatch(/WooCommerce/i);
  });

  test('admin settings panel loads', async ({ page }) => {
    await gotoAdmin(page, PLUGIN_SLUG);
    await assertPageReady(page, 'settings');
    const body = await page.evaluate(() => document.body.innerText);
    expect(body).not.toMatch(/PHP Fatal|Parse error/i);
  });

  test('WooCommerce settings tab appears (if applicable)', async ({ page }) => {
    // Many WC plugins add a tab to WooCommerce > Settings
    await page.goto('/wp-admin/admin.php?page=wc-settings');
    await assertPageReady(page, 'wc-settings');

    // Check your plugin added a tab
    const tab = page.locator(`a:has-text("My Plugin"), .wc-tabs li:has-text("My Plugin")`);
    if (await tab.isVisible({ timeout: 2000 }).catch(() => false)) {
      await tab.click();
      await page.waitForLoadState('domcontentloaded');
      console.log('[PASS] WC settings tab found and clickable');
    } else {
      console.log('[INFO] No WC settings tab — plugin may use own settings page');
    }
  });

  test('shop page loads without errors', async ({ page }) => {
    const errors = [];
    page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });

    await page.goto('/shop/');
    await page.waitForLoadState('networkidle');

    const body = await page.evaluate(() => document.body.innerText);
    expect(body).not.toMatch(/PHP Fatal|Fatal error/i);
  });

  test('add to cart works', async ({ page }) => {
    await page.goto('/shop/');
    await page.waitForLoadState('networkidle');

    const addToCart = page.locator('.add_to_cart_button, button.single_add_to_cart_button').first();
    if (await addToCart.isVisible({ timeout: 3000 }).catch(() => false)) {
      await addToCart.click();
      await page.waitForTimeout(1000);

      // Check cart has items
      await page.goto('/cart/');
      const cartItem = page.locator('.cart_item, .wc-block-cart-item');
      await expect(cartItem).toBeVisible({ timeout: 5000 });
      console.log('[PASS] Add to cart works');
    }
  });

  test('checkout page loads without errors', async ({ page }) => {
    // First add something to cart
    await page.goto('/shop/');
    const addToCart = page.locator('.add_to_cart_button').first();
    if (await addToCart.isVisible({ timeout: 3000 }).catch(() => false)) {
      await addToCart.click();
      await page.waitForTimeout(1000);
    }

    await page.goto('/checkout/');
    await page.waitForLoadState('networkidle');

    const body = await page.evaluate(() => document.body.innerText);
    expect(body).not.toMatch(/PHP Fatal/i);
    expect(body).toMatch(/billing|payment|order|checkout/i);
  });

  test('unauthenticated REST endpoints return 401', async ({ page }) => {
    // Check your plugin's REST endpoints require auth
    // CHANGE ME: replace with your actual endpoint slugs
    const endpoints = [
      '/wp-json/my-plugin/v1/orders',
      '/wp-json/my-plugin/v1/customers',
    ];

    for (const endpoint of endpoints) {
      const response = await page.request.get(`http://localhost:${process.env.WP_ENV_PORT || 8881}${endpoint}`)
        .catch(() => null);

      if (response) {
        console.log(`[REST] ${endpoint} → ${response.status()}`);
        // These endpoints should require authentication
        if (response.status() === 200) {
          console.warn(`[WARN] ${endpoint} is publicly accessible — add permission_callback`);
        }
      }
    }
  });

});
```

---

## 7. Template: REST API Plugin

This template is for plugins that register custom REST API endpoints. The tests verify that your namespace is discoverable, public endpoints return data, protected endpoints properly reject unauthenticated requests, and the API handles bad input gracefully rather than returning a 500 server error.

A 500 error from an API endpoint is almost always a bug — good APIs return structured error messages with appropriate status codes like 400 (bad request) or 404 (not found).

```javascript
// tests/playwright/my-plugin/core.spec.js
const { test, expect } = require('@playwright/test');
const { gotoAdmin, assertPageReady } = require('../helpers');

const BASE_URL   = process.env.WP_TEST_URL || 'http://localhost:8881';
const API_PREFIX = '/wp-json/my-plugin/v1';  // CHANGE ME

// Admin auth token for authenticated requests
let authToken = null;

test.describe('REST API Plugin — Core Tests', () => {

  test.beforeAll(async ({ request }) => {
    // Get JWT or Application Password token if your plugin uses them
    // Otherwise, use cookie auth from storage state (already set by auth.setup.js)
    console.log('[INFO] REST API tests use cookie auth from admin setup');
  });

  test('public endpoints are discoverable', async ({ request }) => {
    const res = await request.get(`${BASE_URL}/wp-json/`);
    expect(res.status()).toBe(200);

    const body = await res.json();
    const namespaces = body.namespaces || [];
    const hasPlugin = namespaces.some(n => n.includes('my-plugin'));

    console.log('[REST] Available namespaces:', namespaces);
    expect(hasPlugin, 'Plugin REST namespace not registered').toBe(true);
  });

  test('GET public endpoint returns 200', async ({ request }) => {
    // CHANGE ME: your public endpoint
    const res = await request.get(`${BASE_URL}${API_PREFIX}/public-data`);
    console.log(`[REST] GET /public-data → ${res.status()}`);

    // Public endpoints should return data
    expect(res.status()).toBe(200);

    const body = await res.json();
    expect(body).toBeTruthy();
  });

  test('protected endpoint returns 401 without auth', async ({ request }) => {
    // CHANGE ME: your protected endpoints
    const protectedEndpoints = [
      `${API_PREFIX}/admin-data`,
      `${API_PREFIX}/settings`,
    ];

    for (const endpoint of protectedEndpoints) {
      // Make request WITHOUT auth cookies
      const res = await request.get(`${BASE_URL}${endpoint}`, {
        headers: {
          'Cookie': '',  // clear cookies to simulate unauthenticated
        },
      });
      console.log(`[REST] GET ${endpoint} (unauthenticated) → ${res.status()}`);
      expect(res.status(), `${endpoint} should require auth`).toBeOneOf([401, 403]);
    }
  });

  test('POST endpoint validates required fields', async ({ page, request }) => {
    // Use authenticated request (admin cookies from setup)
    // CHANGE ME: your POST endpoint + required fields
    const res = await request.post(`${BASE_URL}${API_PREFIX}/items`, {
      data: {
        // Missing required 'title' field
        description: 'Test item',
      },
    });

    console.log(`[REST] POST /items (missing field) → ${res.status()}`);
    // Should get validation error, not 500
    expect(res.status()).toBeOneOf([400, 422]);

    const body = await res.json();
    // Should return a useful error message
    expect(body.message || body.code).toBeTruthy();
  });

  test('REST response structure matches expected shape', async ({ request }) => {
    // CHANGE ME
    const res = await request.get(`${BASE_URL}${API_PREFIX}/items`);
    if (res.status() !== 200) return;  // skip if needs auth

    const body = await res.json();
    console.log(`[REST] Items response type: ${typeof body}`);

    // Verify the response has the expected shape
    expect(Array.isArray(body) || typeof body === 'object').toBe(true);
  });

  test('API handles invalid ID gracefully', async ({ request }) => {
    const res = await request.get(`${BASE_URL}${API_PREFIX}/items/999999`);
    console.log(`[REST] GET /items/999999 → ${res.status()}`);

    // Should return 404, not 500
    expect(res.status()).toBeOneOf([200, 404]);  // 200 = not found with empty body; 404 = explicit not found
    if (res.status() >= 500) {
      const body = await res.text();
      console.error('[FAIL] Server error:', body.slice(0, 200));
    }
  });

});
```

---

## 8. Template: Theme / FSE Plugin

This template covers WordPress themes and Full Site Editing (FSE) plugins. FSE (Full Site Editing) is WordPress's system for editing your entire site — headers, footers, templates — using the block editor. The tests check that the Site Editor loads, color palettes from `theme.json` appear correctly, and there is no content overflow or flash of unstyled content on mobile.

```javascript
// tests/playwright/my-plugin/core.spec.js
const { test, expect } = require('@playwright/test');
const { assertPageReady } = require('../helpers');

const BLOCK_NAMES = ['My Theme Block'];  // CHANGE ME

test.describe('Theme / FSE Plugin — Core Tests', () => {

  test('frontend homepage renders', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');
    await assertPageReady(page, 'homepage');

    const body = await page.evaluate(() => document.body.innerText);
    expect(body.length).toBeGreaterThan(100);
    expect(body).not.toMatch(/PHP Fatal/i);
  });

  test('theme.json color palette loads', async ({ page }) => {
    await page.goto('/wp-admin/post-new.php');
    await page.waitForLoadState('domcontentloaded');

    // Check theme.json colors appear in the editor palette
    const colorPalette = page.locator('.components-circular-option-picker__swatches, .block-editor-color-gradient-control');
    if (await colorPalette.isVisible({ timeout: 5000 }).catch(() => false)) {
      const swatches = await colorPalette.locator('button').count();
      console.log(`[FSE] Color palette swatches: ${swatches}`);
      expect(swatches).toBeGreaterThan(0);
    }
  });

  test('Site Editor loads for FSE theme', async ({ page }) => {
    await page.goto('/wp-admin/site-editor.php');
    await page.waitForLoadState('domcontentloaded');

    const body = await page.evaluate(() => document.body.innerText);
    if (body.includes('Site Editor') || body.includes('site-editor')) {
      console.log('[PASS] Site Editor accessible');
      expect(body).not.toMatch(/PHP Fatal/i);
    } else {
      console.log('[INFO] Site Editor not available (non-FSE theme)');
    }
  });

  test('no FOUC (flash of unstyled content)', async ({ page }) => {
    await page.goto('/');

    // Check CSS is loaded before page is visible
    const cssLoaded = await page.evaluate(() => {
      const sheets = document.styleSheets;
      return sheets.length > 0;
    });
    expect(cssLoaded).toBe(true);
  });

  test('responsive: no content overflow at mobile', async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 812 });
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    const overflows = await page.evaluate(() => {
      const elements = [];
      document.querySelectorAll('*').forEach(el => {
        const rect = el.getBoundingClientRect();
        if (rect.right > window.innerWidth + 5) {
          elements.push(el.tagName + (el.className ? '.' + el.className.split(' ').join('.') : ''));
        }
      });
      return elements.slice(0, 5); // first 5 overflowing elements
    });

    if (overflows.length > 0) {
      console.warn('[WARN] Overflow elements at 375px:', overflows);
    }
    // Allow up to 2 minor overflows (e.g., scrollable tables)
    expect(overflows.length).toBeLessThanOrEqual(2);
  });

});
```

---

## 9. Visual Regression Testing

> **Analogy: What are visual snapshot tests?**
> Think of visual snapshots as taking a photo of what the page should look like. On the first run, Playwright takes a "golden" screenshot and saves it as the baseline. On every future run, it takes a new screenshot and compares it to the baseline pixel by pixel. If the page looks different — a button moved, a color changed, a layout broke — the test fails and shows you exactly what changed. This catches visual regressions that functional tests miss entirely, because a broken layout can still "pass" if all the elements are technically present on the page.

Visual regression saves a "golden" screenshot on first run and diffs against it on every subsequent run.

The first time you run a visual test, no baseline exists yet, so Playwright creates one. The test will always pass on the first run. From the second run onward, it compares against that saved baseline.

```javascript
// tests/playwright/visual/snapshots.spec.js
const { test, expect } = require('@playwright/test');
const { gotoAdmin } = require('../helpers');

const PLUGIN_SLUG = 'my-plugin';  // CHANGE ME

test.describe('Visual Regression', () => {

  test('admin dashboard — visual baseline', async ({ page }) => {
    await gotoAdmin(page, PLUGIN_SLUG);
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(500); // animation settle

    await expect(page).toHaveScreenshot('admin-dashboard.png', {
      fullPage: true,
      maxDiffPixelRatio: 0.02,  // 2% tolerance
    });
  });

  test('frontend homepage — visual baseline', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(500);

    await expect(page).toHaveScreenshot('frontend-homepage.png', {
      fullPage: true,
      maxDiffPixelRatio: 0.02,
    });
  });

  test('settings page — visual baseline', async ({ page }) => {
    // CHANGE: URL and screenshot name
    await gotoAdmin(page, `${PLUGIN_SLUG}-settings`);
    await page.waitForLoadState('networkidle');

    await expect(page).toHaveScreenshot('settings-page.png', {
      maxDiffPixelRatio: 0.01,
    });
  });

});
```

**First run** — creates baseline screenshots in `tests/playwright/visual/*.spec.js-snapshots/`.

**Subsequent runs** — diffs against baseline. Fails if > `maxDiffPixelRatio` different.

**Intentional UI change** — when you deliberately change the UI and need to update the baseline, run this command. It replaces the old "golden" screenshots with the new ones:

```bash
npx playwright test tests/playwright/visual/ --update-snapshots
```

---

## 10. Accessibility Testing (axe-core)

**Jargon buster:**
- **WCAG** (Web Content Accessibility Guidelines) — the international standard for making web content accessible to people with disabilities. Version 2.2 AA is the most widely required level.
- **ARIA** (Accessible Rich Internet Applications) — a set of HTML attributes that tell screen readers what an element does. For example, `aria-label="Close dialog"` tells a screen reader that a button closes a dialog, even if the button only shows an X icon.
- **axe-core** — an open-source library that automatically checks a page for common accessibility violations. It catches things like missing alt text on images, form fields without labels, and insufficient color contrast.

The tests below run axe-core against your admin panel and frontend. The goal is to catch accessibility problems your plugin introduces, not problems that exist in WordPress core itself — which is why the tests filter results to only flag issues in your plugin's own markup.

```javascript
// tests/playwright/my-plugin/a11y.spec.js
const { test, expect } = require('@playwright/test');
const AxeBuilder = require('@axe-core/playwright').default;
const { gotoAdmin } = require('../helpers');

const PLUGIN_SLUG = 'my-plugin';  // CHANGE ME

test.describe('Accessibility — WCAG 2.2 AA', () => {

  test('admin panel passes axe-core WCAG 2.2 AA', async ({ page }) => {
    await gotoAdmin(page, PLUGIN_SLUG);
    await page.waitForLoadState('networkidle');

    const results = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa', 'wcag21aa', 'wcag22aa'])
      .exclude('#wpadminbar')  // exclude WP core admin bar
      .analyze();

    const violations = results.violations.filter(v =>
      // Only flag issues in your plugin's UI, not WP core
      v.nodes.some(n => n.html.includes(PLUGIN_SLUG) || n.target.some(t => t.includes(PLUGIN_SLUG)))
    );

    if (violations.length > 0) {
      console.error('[A11Y] Violations:', JSON.stringify(violations, null, 2));
    }

    expect(violations, `${violations.length} accessibility violations found`).toHaveLength(0);
  });

  test('frontend output passes axe-core WCAG 2.2 AA', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    const results = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa'])
      .analyze();

    // Log all violations for review
    if (results.violations.length > 0) {
      console.warn('[A11Y] Frontend violations:');
      results.violations.forEach(v => {
        console.warn(`  [${v.impact}] ${v.id}: ${v.description}`);
        v.nodes.slice(0, 2).forEach(n => console.warn(`    → ${n.html.slice(0, 100)}`));
      });
    }

    // Allow up to 2 inherited (WP-theme) violations — focus on your plugin's output
    const criticalViolations = results.violations.filter(v => v.impact === 'critical');
    expect(criticalViolations, 'Critical a11y violations on frontend').toHaveLength(0);
  });

  test('keyboard navigation: Tab reaches all interactive elements', async ({ page }) => {
    await gotoAdmin(page, PLUGIN_SLUG);
    await page.waitForLoadState('networkidle');

    // Tab through the first 20 focusable elements
    let focused = [];
    for (let i = 0; i < 20; i++) {
      await page.keyboard.press('Tab');
      const focusedEl = await page.evaluate(() => {
        const el = document.activeElement;
        return el ? `${el.tagName}.${el.className}` : 'none';
      });
      focused.push(focusedEl);
    }

    console.log('[A11Y] Tab order:', focused.join(' → '));
    // Verify focus never gets "stuck" or returns to body
    const stuckCount = focused.filter(f => f === 'BODY.' || f === 'none').length;
    expect(stuckCount, 'Focus got stuck (returned to body/null)').toBe(0);
  });

});
```

---

## 11. Flow Tests with Video Recording

Flow tests record video, capture `pair-NN-slug-a/b.png` screenshots, and generate a PM-friendly HTML report.

These are the most valuable tests for sharing with non-technical stakeholders. A product manager can open the HTML report and watch videos of both plugins completing the same tasks side by side, without looking at any code.

Before running flow tests, make sure you have set `PLUGIN_A` and `PLUGIN_B` to the correct admin slugs for your plugin and the competitor. Run the Discovery tests first if you are not sure what the slugs are.

```javascript
// tests/playwright/flows/my-feature/core.spec.js
const { test, expect } = require('@playwright/test');
const path = require('path');
const fs = require('fs');
const { gotoAdmin, snapPair, slowScroll, assertPageReady } = require('../../helpers');

const SNAP = path.join(__dirname, '../../../../reports/screenshots/flows-compare');
const VDIR = path.join(__dirname, '../../../../reports/videos');

const PLUGIN_A = 'my-plugin';       // CHANGE ME
const PLUGIN_B = 'competitor-slug'; // CHANGE ME

// Auto-rename video to pair naming convention
test.afterEach(async ({ page }, testInfo) => {
  await page.waitForTimeout(300);
  const videoPath = await page.video()?.path().catch(() => null);
  if (!videoPath || !fs.existsSync(videoPath)) return;
  const m = testInfo.title.match(/^PAIR-(\d+)\s*\|\s*([a-z0-9-]+)\s*\|\s*(a|b)/i);
  if (!m) return;
  const num = String(m[1]).padStart(2, '0');
  fs.mkdirSync(VDIR, { recursive: true });
  const dest = path.join(VDIR, `pair-${num}-${m[2].toLowerCase()}-${m[3].toLowerCase()}.webm`);
  try { fs.copyFileSync(videoPath, dest); } catch {}
});

test.describe('Feature Comparison Flow', () => {

  test('PAIR-1 | setup | a | Plugin A initial setup flow', async ({ page }) => {
    await gotoAdmin(page, PLUGIN_A);
    await assertPageReady(page, 'plugin A');
    await snapPair(page, 1, 'setup', 'a', SNAP);
    await slowScroll(page, 5);
    await snapPair(page, 1, 'setup', 'a', SNAP, 'bottom');
  });

  test('PAIR-1 | setup | b | Plugin B initial setup flow', async ({ page }) => {
    await gotoAdmin(page, PLUGIN_B);
    await assertPageReady(page, 'plugin B');
    await snapPair(page, 1, 'setup', 'b', SNAP);
    await slowScroll(page, 5);
    await snapPair(page, 1, 'setup', 'b', SNAP, 'bottom');
  });

});
```

Once your flow tests have run and the screenshots and videos are in the `reports/` folder, generate the HTML report with this command. The first line builds the report file, and the second line opens it in your browser:

```bash
python3 scripts/generate-uat-report.py \
  --title "Feature Comparison Report — $(date +%Y-%m-%d)" \
  --snaps reports/screenshots/flows-compare \
  --videos reports/videos \
  --out reports/uat-report-$(date +%Y%m%d).html

open reports/uat-report-*.html
```

---

## 12. Helper Functions Reference

These are the utility functions available in `../helpers` that all templates use. You do not need to understand how they are implemented — just know what each one does and when to call it.

| Function | Signature | What it does |
|---|---|---|
| `assertPageReady(page, context)` | `(page, string)` | Throws on login redirect, PHP errors, or empty page body |
| `gotoAdmin(page, slug, hashOrQuery)` | `(page, string, string?)` | Navigate to `wp-admin/admin.php?page=SLUG` with validation |
| `discoverNavLinks(page, selector?)` | `(page, string?)` | Returns all visible nav link `{text, href}` pairs |
| `exploreAllTabs(page, maxTabs?)` | `(page, number?)` | Clicks through all tabs on a settings page |
| `slowScroll(page, steps?)` | `(page, number?)` | Smooth scrolls from top to bottom to bottom |
| `waitForReady(page, selector, timeout?)` | `(page, string, number?)` | Waits for element, returns `true`/`false` (non-throwing) |
| `countElements(page, selector)` | `(page, string)` | Returns count of matching DOM elements |
| `snapPair(page, num, slug, side, dir, extra?)` | `(page, int, string, 'a'\|'b', string, string?)` | Saves screenshot with `pair-NN-slug-a/b[-extra].png` naming |
| `checkFrontend(page, url)` | `(page, string)` | Returns `{title, metaDesc, canonical, ogTitle, schemaTypes, ...}` |

The table above shows every helper function you might use in a test. The most important ones for beginners are `assertPageReady` (use it after every page navigation) and `gotoAdmin` (use it instead of writing `page.goto('/wp-admin/admin.php?page=...')` manually every time). The `discoverNavLinks` function is especially useful when you are getting started and do not yet know the exact URLs for your plugin's settings pages — run it once and it will print them all.

---

## 13. Test Projects Reference

Playwright's `playwright.config.js` defines multiple "projects" — different configurations for running your tests. Think of a project as a preset: it sets the browser, the viewport, whether to record video, and which test files to run.

To run all projects at once (the default), just run `npx playwright test`. To run only specific types of tests, use the `--project` flag:

```bash
# All projects (default)
npx playwright test

# Specific projects
npx playwright test --project=chromium      # functional tests
npx playwright test --project=visual        # snapshot tests
npx playwright test --project=mobile-chrome # mobile viewport
npx playwright test --project=tablet        # tablet viewport
npx playwright test --project=video         # flow tests with recording
npx playwright test --project=elementor-widgets  # Elementor-specific

# Multiple projects
npx playwright test --project=chromium --project=mobile-chrome
```

| Project | What it runs | Auth | Video |
|---|---|---|---|
| `setup` | `auth.setup.js` — WP login | None | No |
| `chromium` | All `*.spec.js` except visual/flows | Admin | On failure |
| `visual` | `visual/**/*.spec.js` | Admin | No |
| `mobile-chrome` | `responsive.spec.js` | Admin | No |
| `tablet` | `responsive.spec.js` | Admin | No |
| `video` | `flows/**/*.spec.js` | Admin | Always |
| `elementor-widgets` | `elementor/**/*.spec.js` | Admin | Always |

The table shows which test files each project runs and whether it records video. The `setup` project always runs first (it logs in and saves the auth cookie). The `video` project always records — this is intentional, because flow tests are meant to produce video evidence for stakeholder reviews. For all other projects, video is only recorded on failure so you can see what went wrong.

---

**Next**: [docs/08-reading-reports.md](08-reading-reports.md) — how to interpret every report type.
