# Configuration Reference

> Everything `qa.config.json` does, every field explained, with real examples for every plugin type.

Think of `qa.config.json` as a project brief for Orbit. You fill it in once — plugin name, where the code lives, what WordPress version you're targeting, which other plugins should be active during tests — and Orbit reads it every time you run a test. You never have to remember or re-type any of it.

---

## Table of Contents

1. [Creating Your Config](#1-creating-your-config)
2. [Plugin Section](#2-plugin-section)
3. [Environment Section](#3-environment-section)
4. [Companions Section](#4-companions-section)
5. [Upgrade Testing](#5-upgrade-testing)
6. [Competitors Section](#6-competitors-section)
7. [QA Focus Section](#7-qa-focus-section)
8. [Thresholds Section](#8-thresholds-section)
9. [Complete Examples by Plugin Type](#9-complete-examples-by-plugin-type)
10. [Using Config Without a File](#10-using-config-without-a-file)

---

## 1. Creating Your Config

Orbit ships with an example config file you can use as a starting point. The command below copies that example to the real config file Orbit looks for. Think of this like duplicating a template — the original stays untouched so you can always refer back to it.

```bash
cp qa.config.example.json qa.config.json
```

`qa.config.json` is gitignored — it's local to your machine. Never commit it (it may contain staging URLs or internal paths).

> **Q: Why is it gitignored?** Your config file might contain staging site URLs, internal server paths, or Pro plugin zip locations. These aren't things you want showing up in a public GitHub repository or shared with team members who have different setups.

Once the file exists in the Orbit directory, you can run the gauntlet without `--plugin`:

The first command (with config) is the normal everyday flow. The second (without config) is a quick one-off test when you haven't set up a config file yet — just point Orbit directly at your plugin folder.

```bash
# With config file
cd ~/Claude/orbit
bash scripts/gauntlet.sh

# Without config file (path required)
bash scripts/gauntlet.sh --plugin ~/plugins/my-plugin
```

**You're done when:** `qa.config.json` exists in your Orbit directory and you can open it in a text editor and see the fields. Now you're ready to fill it in.

---

## 2. Plugin Section

This is the most important part of your config. It tells Orbit which plugin you're testing and a few key facts about it — the same facts listed in your plugin's main PHP file header.

```json
"plugin": {
  "name": "My Awesome Plugin",
  "slug": "my-awesome-plugin",
  "type": "general",
  "path": "/Users/you/plugins/my-awesome-plugin",
  "version": "2.1.0",
  "hasPro": true,
  "proZip": "/Users/you/plugins/my-awesome-plugin-pro.zip",
  "textDomain": "my-awesome-plugin",
  "requiresAtLeast": "5.9",
  "testedUpTo": "6.7",
  "requiresPHP": "7.4"
}
```

### Field reference

| Field | Type | Required | Description |
|---|---|---|---|
| `name` | string | Yes | Human-readable plugin name (used in reports) |
| `slug` | string | Yes | WP.org slug — used for admin menu detection, competitor lookup |
| `type` | string | Yes | See plugin types below |
| `path` | string | Yes | **Absolute path** to the plugin folder |
| `version` | string | Yes | Current version being tested |
| `hasPro` | boolean | No | Whether a Pro version exists |
| `proZip` | string | If `hasPro: true` | Path to Pro zip for upgrade path testing |
| `textDomain` | string | Yes | Must match the `Text Domain:` in plugin header |
| `requiresAtLeast` | string | Yes | Minimum WP version from plugin header |
| `testedUpTo` | string | Yes | "Tested up to" WP version from plugin header |
| `requiresPHP` | string | Yes | Minimum PHP version from plugin header |

Most of these values (`textDomain`, `requiresAtLeast`, `testedUpTo`, `requiresPHP`) are things you've already written in the comment block at the top of your plugin's main PHP file. You're just copying them here so Orbit can verify they're accurate and consistent.

> **Q: Where do I find my plugin's slug?** Your slug is typically the name of your plugin's folder and the name it uses on WordPress.org. If your plugin lives at `wp-content/plugins/my-awesome-plugin/`, the slug is `my-awesome-plugin`.

> **Q: What if I don't have a Pro version?** Set `hasPro: false` and leave out the `proZip` field entirely. Orbit will skip the Pro-specific upgrade path tests.

**Why does this matter?** The `path` field must be an absolute path — not relative like `../my-plugin`. If the path is wrong, Orbit can't find your plugin files and the entire gauntlet fails before it starts. Double-check this if you ever move your plugin folder.

### Plugin types

The `type` field controls which test templates load and which add-on skills fire in Step 11.

> **Analogy:** Plugin type is like telling a specialist doctor what kind of patient is coming in. A cardiologist and a dermatologist are both doctors, but they ask completely different questions and run completely different tests. When you tell Orbit your plugin is an `elementor-addon`, it brings in Elementor-specific tests — widget registration, editor loading speed, canvas rendering — that a general plugin test would never run.

| Type value | When to use | Extra skills triggered |
|---|---|---|
| `general` | Any plugin that doesn't fit the others | None |
| `elementor-addon` | Adds widgets to Elementor | `/antigravity-design-expert` |
| `gutenberg-blocks` | Registers Gutenberg blocks | `/wordpress-theme-development` |
| `seo` | SEO metadata, sitemaps, schema | None (all covered by 6 core) |
| `woocommerce` | WooCommerce extensions, gateways | `/wordpress-woocommerce-development` |
| `rest-api` | Custom REST endpoints, headless | `/api-security-testing` |
| `theme` | WP theme or FSE theme | `/wordpress-theme-development` |

The "Extra skills triggered" column shows specialist Claude skills that Orbit automatically calls during Step 11 of the gauntlet. For example, if you set `type: "woocommerce"`, Orbit will invoke a WooCommerce development expert to review your code for cart hooks, checkout flow, and payment gateway patterns — things a general code review would miss.

If none of the specific types fit your plugin exactly, use `general`. It still runs all the core tests — activation, admin panel, frontend output, performance, security — just without the type-specific specialist layer.

---

## 3. Environment Section

This section tells Orbit where your test WordPress site lives and how to log into it. If you're using Orbit's built-in `create-test-site.sh` script (recommended for beginners), the defaults here will match what that script sets up automatically.

> **Analogy:** wp-env is a disposable test WordPress site that lives inside Docker (a container system that runs isolated software environments on your computer). It's completely separate from any live or staging site you have. You can destroy it and rebuild it in under a minute. Think of it like a sandbox — what happens in wp-env stays in wp-env.

```json
"environment": {
  "testUrl": "http://localhost:8881",
  "wpEnvPort": 8881,
  "adminUser": "admin",
  "adminPass": "password",
  "multisite": false,
  "stagingUrl": "https://staging.example.com"
}
```

### Field reference

| Field | Type | Default | Description |
|---|---|---|---|
| `testUrl` | string | `http://localhost:8881` | Base URL Playwright uses for all tests |
| `wpEnvPort` | number | `8881` | Port wp-env listens on |
| `adminUser` | string | `admin` | WordPress admin username |
| `adminPass` | string | `password` | WordPress admin password |
| `multisite` | boolean | `false` | If true, gauntlet runs multisite-specific checks |
| `stagingUrl` | string | `""` | Optional — if set, Playwright can also run against staging |

**What these settings actually change in practice:**

- `testUrl` and `wpEnvPort` must match each other. If you change the port to `8882` in one, change it in the other too. If they don't match, Playwright (the browser automation tool Orbit uses to click through your plugin's UI and verify things look right) will try to connect to a site that isn't there.
- Setting `multisite: true` adds an extra set of tests that check your plugin works correctly in a WordPress network installation — where one WordPress install runs multiple subsites. If your plugin doesn't claim multisite support, leave this `false`.
- `adminUser` and `adminPass` use simple defaults because this is a local test environment with no real data. Don't use real production credentials here.

> **Q: Do I need to change the admin username and password?** Not for local testing. The defaults (`admin` / `password`) are fine because wp-env is a sandboxed environment that only you can access. If you're running tests against a real staging server, use that server's actual credentials.

### Using staging URL

Sometimes you want to run tests against a real staging server instead of (or in addition to) your local wp-env site. These commands let you point Playwright at a different URL without changing your config file.

```bash
# Run Playwright against staging (not local wp-env)
WP_TEST_URL=https://staging.example.com npx playwright test

# Or set in config and override with env var
WP_TEST_URL=https://staging.example.com bash scripts/gauntlet.sh
```

For staging behind basic auth:

```bash
WP_TEST_URL=https://user:pass@staging.example.com bash scripts/gauntlet.sh
```

> **Q: What is "basic auth"?** Basic auth is a simple password protection layer that some staging servers use to prevent public access. If you visit your staging site in a browser and it asks for a username and password before even showing the site, that's basic auth. You include those credentials directly in the URL using the `user:pass@` format shown above.

---

## 4. Companions Section

Companions are plugins that should be active alongside yours during testing. Use WP.org slugs.

Real WordPress sites almost always have multiple plugins active at once. Your plugin needs to work correctly when Elementor, WooCommerce, or a contact form plugin is also running — not just in isolation. The companions list tells Orbit which plugins to install and activate before running tests.

```json
"companions": [
  "woocommerce",
  "elementor",
  "wordpress-seo",
  "contact-form-7"
]
```

The test site setup script reads this list and installs these plugins automatically:

This command handles the entire site setup — it starts Docker, installs WordPress, activates your plugin, and then installs every plugin in your companions list. You don't need to manually install anything inside the test site.

```bash
bash scripts/create-test-site.sh --plugin ~/plugins/my-plugin
# → installs companions from qa.config.json automatically
```

### Common companion combinations

Choose the combination that matches what your plugin is built to work alongside:

```json
// WooCommerce addon
"companions": ["woocommerce", "woocommerce-payments"]

// Elementor addon
"companions": ["elementor", "elementor-pro"]

// SEO plugin
"companions": ["wordpress-seo", "rank-math-seo"]  // conflict testing

// General plugin (conflict hardening)
"companions": ["woocommerce", "elementor", "wordpress-seo", "contact-form-7", "wpml"]
```

> **Q: Should I add every popular plugin as a companion?** Not necessarily. Add the plugins your target users are most likely to have installed. If you're building an Elementor add-on, nearly all your users have Elementor active. Add that. The general conflict hardening list (WooCommerce, Elementor, Yoast, CF7, WPML) is a good stress test for any plugin, but it does slow down setup time.

**Why does this matter?** Plugin conflicts are one of the most common causes of 1-star WordPress plugin reviews. Two plugins can each work perfectly alone but break each other when active simultaneously — because they both hook into the same WordPress function, register a class with the same name, or output JavaScript that conflicts. Running tests with companions active catches these problems before your users do.

---

## 5. Upgrade Testing

Test that upgrading from an older version doesn't break anything.

This is one of the most valuable and most-skipped tests in WordPress plugin development. When a user upgrades your plugin, their database already has data from the old version. If your new version changes the database structure — adds a table, renames a column, changes how settings are stored — and the upgrade migration doesn't handle it correctly, the user's site can break.

```json
"upgrade": {
  "test": true,
  "fromVersion": "1.5.0",
  "fromZip": "/path/to/old-version.zip"
}
```

When `test: true`, the gauntlet:
1. Installs `fromZip` version
2. Creates test content (simulates real user data)
3. Upgrades to current version
4. Runs full functional tests

This catches the most common release-day breakage: DB schema changes that the upgrade migration doesn't handle.

> **Q: Where do I get the old version zip?** You should keep zip archives of previous releases. GitHub Releases is the standard place — when you tag a release, attach the plugin zip to it. Then you can download it for upgrade testing. If you don't have the old zip, check your Git history and build it from there.

> **Q: What if I set `test: false`?** Orbit skips all upgrade-path testing. Your plugin will still be tested for the current version in isolation, but you won't catch any problems that only appear when upgrading from an existing installation. For any plugin with active users, this test is worth running before every release.

---

## 6. Competitors Section

```json
"competitors": [
  "competitor-plugin-slug",
  "another-competitor-slug"
]
```

Used by Step 9 (Competitor Comparison) and by the SEO/comparison test templates. Competitors are installed automatically in wp-env and tested side-by-side with your plugin.

The `seo-plugin` test template uses the `PAIR-NN` naming convention to generate a report where each feature of your plugin sits next to the same feature from the competitor.

> **Q: What if I don't have a competitor plugin?** You can leave the competitors section empty — Orbit will skip the comparison steps entirely. It only becomes useful when you want to see your plugin's performance scores, UI patterns, or feature coverage compared side-by-side with a rival. This is most valuable for SEO plugins, page builders, and form plugins where benchmarks matter.

**What this actually produces:** When competitors are configured, Orbit installs each competitor plugin in the test environment, runs the same test suite on both your plugin and theirs, and generates a comparison report. This is useful for identifying where you're ahead (and can say so in marketing) and where you're lagging (and should improve before your next release).

---

## 7. QA Focus Section

Control which areas of testing get attention.

Not every test run needs to be a full audit. When you're in the middle of development and just want to check that your new admin panel doesn't crash, running all 11 gauntlet steps would waste 20 minutes. The `qaFocus` section lets you run a targeted subset.

```json
"qaFocus": {
  "priority": "full",
  "testAreas": [
    "activation",
    "admin-panel-load",
    "frontend-output",
    "rest-api-auth",
    "multisite",
    "upgrade-path",
    "accessibility"
  ]
}
```

### Priority values

| Value | What it does |
|---|---|
| `full` | All 11 gauntlet steps |
| `quick` | Steps 1–6 only (no Lighthouse, DB profile, editor perf, or skills) |
| `security` | Steps 1, 2, and 11 (security skill only) |
| `performance` | Steps 4, 7, 8, 10, and performance skill |

**What changing `priority` actually does:**

- `full` — Use this before any release. It runs everything: static analysis, security scans, browser tests, Lighthouse scores, database profiling, editor performance, and specialist skill reviews. Takes the longest but gives you the most confidence.
- `quick` — Use this during active development when you want fast feedback. It runs the core checks (does it activate, does the admin load, does the frontend render) but skips the heavier performance and skill-based tests.
- `security` — Use this when you've just made a change to how your plugin handles user input, REST endpoints, or file uploads. It runs a focused security audit without the full test suite.
- `performance` — Use this when you suspect a performance regression — for example, after adding a new feature that touches the database on every page load.

> **Q: Which priority should I use for my first test run?** Start with `full`. It takes longer but gives you a complete picture of your plugin's health. Once you know where the issues are, you can use focused modes during fix-and-verify cycles.

### testAreas values

Flags specific Playwright (browser automation) test projects to include/skip. Values map to test file names in `tests/playwright/`. If you only list `activation` and `admin-panel-load`, Playwright will only run those two test files and skip everything else — making the test run much faster when you're iterating on a specific feature.

---

## 8. Thresholds Section

Define your pass/fail thresholds. The gauntlet will `warn` or `fail` based on these.

Thresholds are the lines your plugin must not cross. Think of them like code quality gates: if your plugin causes more than 60 database queries on a single page load, something is probably wrong. Orbit uses these numbers to decide whether to flag a warning (yellow) or fail the gauntlet entirely (red).

```json
"thresholds": {
  "lighthouse": {
    "performance": 75,
    "accessibility": 85,
    "bestPractices": 80,
    "seo": 80
  },
  "dbQueriesPerPage": 60,
  "dbQueriesAdmin": 100,
  "jsBundleKb": 500,
  "cssBundleKb": 200,
  "editorReadyMs": 4000,
  "widgetInsertMs": 800
}
```

### Threshold reference

| Threshold | Default | Warn | Fail |
|---|---|---|---|
| `lighthouse.performance` | 75 | < 75 | < 60 |
| `lighthouse.accessibility` | 85 | < 85 | < 70 |
| `dbQueriesPerPage` | 60 | > 60 | > 100 |
| `dbQueriesAdmin` | 100 | > 100 | > 200 |
| `jsBundleKb` | 500 | > 500 | > 1000 |
| `cssBundleKb` | 200 | > 200 | > 500 |
| `editorReadyMs` | 4000 | > 4000ms | > 8000ms |
| `widgetInsertMs` | 800 | > 800ms | > 2000ms |

**Reading this table:** Each row has two thresholds — warn and fail. A "warn" means Orbit flags it in the report but still passes the gauntlet overall. A "fail" means the gauntlet exits with a failure status, which will block a CI/CD pipeline if you've configured one.

**What changing these values actually does:**

- `lighthouse.performance: 75` — Lighthouse (Google's tool for measuring page speed and quality) scores pages 0–100. Setting this to 75 means your plugin's frontend output must score at least 75 for performance. Lowering this is lenient; raising it is stricter.
- `dbQueriesPerPage: 60` — Every time a page loads, WordPress runs database queries. Too many queries slow down your site. If your plugin adds 30 queries to every page load, and WordPress itself runs 30, you're at the warning threshold already. Plugins with efficient caching can stay well under 20 additional queries.
- `editorReadyMs: 4000` — How long it takes for the Elementor or Gutenberg editor to be usable after opening. 4000ms (4 seconds) is the default warn threshold. If your plugin's widgets slow the editor beyond this, something needs optimization.
- `jsBundleKb: 500` — The total size of JavaScript files your plugin loads. 500KB is a generous limit. If you're loading large libraries unnecessarily on every page, this will catch it.

> **Q: Should I raise the thresholds to make my plugin "pass" more easily?** That's the wrong approach. The thresholds exist to protect your users' experience. A plugin that scores 55 on Lighthouse performance is genuinely slow. Raising the threshold to 50 just hides the problem. Instead, investigate what's causing the poor score and fix it.

> **Q: My plugin is brand new — should I use stricter or looser thresholds?** Start with the defaults. Once you understand your plugin's baseline scores, you can tighten specific thresholds if your plugin type demands it. For example, an SEO plugin should have a much higher `lighthouse.seo` threshold than 80 — it should score 95+ since SEO is the whole point.

---

## 9. Complete Examples by Plugin Type

These are ready-to-use config files for the four most common plugin types. Copy the one that matches your situation, then swap in your real plugin name, path, and version.

### Elementor Addon

```json
{
  "plugin": {
    "name": "My Elementor Widget Pack",
    "slug": "my-elementor-widgets",
    "type": "elementor-addon",
    "path": "/Users/you/plugins/my-elementor-widgets",
    "version": "3.0.0",
    "hasPro": true,
    "proZip": "/Users/you/plugins/my-elementor-widgets-pro.zip",
    "textDomain": "my-elementor-widgets",
    "requiresAtLeast": "5.9",
    "testedUpTo": "6.7",
    "requiresPHP": "7.4"
  },
  "environment": {
    "testUrl": "http://localhost:8881",
    "wpEnvPort": 8881,
    "adminUser": "admin",
    "adminPass": "password",
    "multisite": false
  },
  "companions": ["elementor", "elementor-pro"],
  "upgrade": {
    "test": true,
    "fromVersion": "2.9.0"
  },
  "competitors": ["essential-addons-for-elementor-lite"],
  "qaFocus": {
    "priority": "full",
    "testAreas": ["activation", "elementor-widgets", "frontend-output", "accessibility"]
  },
  "thresholds": {
    "lighthouse": { "performance": 70, "accessibility": 90 },
    "editorReadyMs": 3000,
    "widgetInsertMs": 600
  }
}
```

Notice the stricter `editorReadyMs` (3000ms instead of 4000ms) and `widgetInsertMs` (600ms instead of 800ms) — Elementor add-ons live inside the editor, so editor performance matters more than it would for a general plugin.

### WooCommerce Extension

```json
{
  "plugin": {
    "name": "Custom WooCommerce Checkout",
    "slug": "custom-woo-checkout",
    "type": "woocommerce",
    "path": "/Users/you/plugins/custom-woo-checkout",
    "version": "1.2.0",
    "hasPro": false,
    "textDomain": "custom-woo-checkout",
    "requiresAtLeast": "6.0",
    "testedUpTo": "6.7",
    "requiresPHP": "8.0"
  },
  "environment": {
    "testUrl": "http://localhost:8881",
    "wpEnvPort": 8881,
    "adminUser": "admin",
    "adminPass": "password"
  },
  "companions": ["woocommerce"],
  "qaFocus": {
    "priority": "full",
    "testAreas": ["activation", "woocommerce-checkout", "rest-api-auth", "security"]
  },
  "thresholds": {
    "lighthouse": { "performance": 80, "accessibility": 90 },
    "dbQueriesPerPage": 50
  }
}
```

The tighter `dbQueriesPerPage: 50` threshold reflects WooCommerce's need for fast product and checkout pages. WooCommerce itself generates many queries — your plugin shouldn't add to that unnecessarily.

### SEO Plugin

```json
{
  "plugin": {
    "name": "My SEO Plugin",
    "slug": "my-seo-plugin",
    "type": "seo",
    "path": "/Users/you/plugins/my-seo-plugin",
    "version": "5.1.0",
    "hasPro": true,
    "proZip": "/Users/you/plugins/my-seo-plugin-pro.zip",
    "textDomain": "my-seo-plugin",
    "requiresAtLeast": "5.5",
    "testedUpTo": "6.7",
    "requiresPHP": "7.4"
  },
  "environment": {
    "testUrl": "http://localhost:8881",
    "wpEnvPort": 8881,
    "adminUser": "admin",
    "adminPass": "password"
  },
  "competitors": ["wordpress-seo", "rank-math-seo"],
  "qaFocus": {
    "priority": "full",
    "testAreas": ["activation", "admin-panel-load", "frontend-output", "sitemaps", "schema"]
  },
  "thresholds": {
    "lighthouse": { "performance": 85, "seo": 95 },
    "dbQueriesPerPage": 40
  }
}
```

The `lighthouse.seo: 95` threshold is high because an SEO plugin that scores poorly on SEO would be embarrassing — and telling. `dbQueriesPerPage: 40` is strict because SEO plugins often run on every page load to inject meta tags; they need to be lean.

### REST API / Headless Plugin

```json
{
  "plugin": {
    "name": "Custom REST API Extensions",
    "slug": "custom-rest-api",
    "type": "rest-api",
    "path": "/Users/you/plugins/custom-rest-api",
    "version": "1.0.0",
    "hasPro": false,
    "textDomain": "custom-rest-api",
    "requiresAtLeast": "5.5",
    "testedUpTo": "6.7",
    "requiresPHP": "8.0"
  },
  "environment": {
    "testUrl": "http://localhost:8881",
    "wpEnvPort": 8881,
    "adminUser": "admin",
    "adminPass": "password"
  },
  "qaFocus": {
    "priority": "full",
    "testAreas": ["activation", "rest-api-auth", "security"]
  },
  "thresholds": {
    "lighthouse": { "performance": 90 },
    "dbQueriesPerPage": 30
  }
}
```

REST API plugins get the `api-security-testing` specialist skill automatically. Authentication and authorization are the critical concerns — hence `rest-api-auth` and `security` in testAreas. The performance and query thresholds are strict because REST endpoints are often called programmatically at high frequency.

---

## 10. Using Config Without a File

You can pass all config as CLI arguments and environment variables instead of a JSON file. This is useful for CI/CD pipelines (automated systems that run tests on every code push) or for one-off test runs where you don't want to maintain a config file.

Environment variables (like `WP_TEST_URL=...`) are temporary — they only apply for the duration of that one command. They don't change your `qa.config.json` file.

```bash
# Plugin path via CLI flag
bash scripts/gauntlet.sh --plugin ~/plugins/my-plugin --mode full

# WordPress URL via env var
WP_TEST_URL=http://localhost:8882 bash scripts/gauntlet.sh --plugin ~/plugins/my-plugin

# Admin credentials via env vars
WP_ADMIN_USER=admin WP_ADMIN_PASS=secret bash scripts/gauntlet.sh --plugin ~/plugins/my-plugin
```

Environment variables always override `qa.config.json` values.

> **Q: When should I use env vars instead of the config file?** Use env vars in your CI/CD pipeline — GitHub Actions, CircleCI, etc. — where you don't want to commit a config file with server-specific paths. The pipeline sets the variables, Orbit reads them, and no local file is needed. For everyday local development, the config file is much more convenient.

---

**Next**: [docs/03-test-environment.md](03-test-environment.md) — spin up a WordPress test site for your plugin.
