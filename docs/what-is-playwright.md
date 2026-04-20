# What Is Playwright — And Why Orbit Uses It

> A beginner-friendly explanation for anyone new to browser automation.

---

## The Problem Playwright Solves

When you add a new widget or setting to a WordPress plugin, you need to verify:
- It renders correctly on the frontend
- Admin settings save properly
- No JS errors in the console
- Works on mobile + tablet + desktop
- Still passes accessibility checks
- The visual design didn't break anywhere

Manually checking all this per release = hours of clicking and squinting at screenshots. A human **misses things**. A human gets **bored**. A human **can't do it on every commit**.

## What Playwright Does

Playwright is a browser automation library. It lets you write JavaScript code that:
- Opens a real Chromium/Firefox/WebKit browser
- Clicks, types, scrolls, navigates like a user
- Asserts things ("this element should be visible", "no console errors")
- Takes screenshots and diffs them against baselines
- Measures performance numbers

Think: **a tireless QA tester that runs every rule in your checklist in 30 seconds**.

## Why Playwright (vs Cypress, Puppeteer, Selenium)

| Feature | Playwright | Cypress | Puppeteer | Selenium |
|---|---|---|---|---|
| Cross-browser (Chrome + Firefox + Safari) | ✅ | ❌ Chrome only | ❌ Chrome only | ✅ |
| Native parallel | ✅ | Paid tier | Manual | Manual |
| Built-in trace viewer | ✅ | ❌ | ❌ | ❌ |
| Auto-wait (no sleep/retry spam) | ✅ | ✅ | ❌ | ❌ |
| Mobile viewport testing | ✅ | Limited | ✅ | ✅ |
| Actively maintained by | Microsoft | Cypress.io | Google | Community |

**Playwright wins** on the combination of cross-browser + parallel + developer experience.

---

## How Playwright Works (Mental Model)

```
┌─────────────────────────┐
│ Your test file          │
│ tests/xyz.spec.js       │
└───────────┬─────────────┘
            │  npx playwright test
            ▼
┌─────────────────────────┐
│ Playwright test runner  │
│ - picks project (chrome)│
│ - launches browser      │
│ - runs test in parallel │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐          ┌─────────────────────┐
│ Chromium browser (real) │◀────────▶│ Your WP test site   │
│ - executes your script  │          │ http://localhost:... │
│ - records screenshots   │          └─────────────────────┘
│ - logs console          │
│ - captures network      │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│ Pass / Fail + artifacts │
│ - screenshot            │
│ - video (on failure)    │
│ - trace (on retry)      │
└─────────────────────────┘
```

Your WP site runs in Docker (via wp-env). Playwright drives a real browser that talks to that site. Each test is isolated: a fresh browser context, no state leak from other tests.

---

## A Simple Test — Annotated

```js
// A single test file lives in tests/playwright/<plugin>/core.spec.js
const { test, expect } = require('@playwright/test');

// Group related tests
test.describe('My plugin smoke', () => {

  test('admin menu item appears', async ({ page }) => {
    // 1. Go somewhere
    await page.goto('/wp-admin/');

    // 2. Assert something
    await expect(
      page.locator('a[href*="my-plugin"]')
    ).toBeVisible();
  });

  test('settings save without PHP errors', async ({ page }) => {
    // Collect any PHP errors Playwright sees in the page source
    const phpErrors = [];
    page.on('console', msg => {
      if (/PHP (Warning|Notice|Fatal)/.test(msg.text())) phpErrors.push(msg.text());
    });

    await page.goto('/wp-admin/admin.php?page=my-plugin');
    await page.fill('input[name="setting_key"]', 'my value');
    await page.click('button:has-text("Save")');
    await page.waitForLoadState('networkidle');

    expect(phpErrors, phpErrors.join('\n')).toHaveLength(0);
  });

});
```

Plain English:
- `test('name', async ({ page }) => {...})` — defines one test that gets a fresh `page` (new browser tab)
- `await page.goto(url)` — navigate
- `await page.locator('css')` — find element
- `await expect(...).toBeVisible()` — assert
- `page.on('console', ...)` — listen to browser console

---

## What Gets Tested Automatically in Orbit

Every template in `tests/playwright/templates/` checks:

| Check | What It Catches |
|---|---|
| Admin menu appears | Plugin didn't activate properly |
| Settings page loads | PHP fatal errors on admin |
| No 404s on plugin assets | Missing CSS/JS file paths |
| No JS console errors | Broken frontend scripts |
| No horizontal scroll at 375px | Busted mobile layout |
| WCAG 2.1 AA compliance | Accessibility regressions (via axe-core) |
| Visual snapshot matches baseline | Unintended design change |

Per-plugin-type templates add more:
- **Elementor addon**: widget panel discovery, editor render, frontend widget output
- **Gutenberg block**: inserter, save + reload, block.json validity
- **SEO plugin**: meta tags, sitemap, schema, Open Graph
- **WooCommerce extension**: shop page, cart, checkout flow
- **Theme**: activation, customizer, site-editor, template hierarchy

---

## Playwright's Killer Feature — UI Mode

```bash
npx playwright test --ui
```

Opens an interactive runner. You see:

1. **Sidebar** with every test — click to run one
2. **Live preview** — the browser inside the UI
3. **Time-travel debugger** — click any action in the test log, see the DOM at that exact moment
4. **Watch mode** — save a test file, it re-runs automatically

This is where Playwright beats every competitor. Use UI mode while writing tests.

---

## Trace Viewer — Post-Mortem on Failures

When a test fails, Playwright saves a trace zip. Open it with:

```bash
npx playwright show-trace test-results/.../trace.zip
```

You get:
- DOM snapshot at every step
- Network waterfall
- Console logs
- Screenshots
- Video (if enabled)

Perfect for "this failed on CI but works locally" debugging — the trace has all the evidence.

---

## How Orbit Avoids Re-Login Spam

Without smart setup, every test would do this:

```js
// BAD — repeat in every test
test('foo', async ({ page }) => {
  await page.goto('/wp-login.php');
  await page.fill('input[name=log]', 'admin');
  await page.fill('input[name=pwd]', 'password');
  await page.click('button');
  // ... actual test
});
```

100 tests × 3-second login = 5 minutes wasted per run.

**Orbit's approach** — Playwright's `storageState`:

1. `tests/playwright/auth.setup.js` logs in **ONCE** and saves cookies to `.auth/wp-admin.json`
2. `playwright.config.js` declares every other project `dependencies: ['setup']`
3. Every other test starts with cookies pre-loaded — **already logged in**, zero re-auth

100 tests × 0 seconds of login = instant.

---

## Parallelism — How We Run Many Tests Fast

`playwright.config.js` has:

```js
fullyParallel: true,
workers: '50%',  // uses half your CPU cores
```

On a 10-core Mac → 5 tests run simultaneously. Test suite that used to take 10 minutes now takes 2.

For batch testing across multiple plugins, `scripts/batch-test.sh` runs N whole gauntlets in parallel, each against its own wp-env site on its own port.

---

## What Playwright Can't Do

Be honest about limits:

- **Can't catch every visual glitch** — snapshots detect pixel diffs but not "the design feels ugly"
- **Can't replace human exploratory testing** — surprising user flows still need humans
- **Won't catch bugs in code paths no test touches** — coverage gaps exist
- **Tests can lie** — a poorly written test can pass even when the feature is broken

That's why Orbit combines Playwright (behavior) + PHPCS (code) + PHPStan (types) + Lighthouse (perf) + manual checklists (judgment). No single tool is sufficient.

---

## Further Reading

- [Playwright docs](https://playwright.dev/)
- [docs/writing-tests.md](writing-tests.md) — how to write your own tests
- [tests/playwright/templates/README.md](../tests/playwright/templates/README.md) — templates per plugin type
