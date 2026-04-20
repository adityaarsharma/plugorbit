# Real-World WordPress QA — Cases Most Checklists Miss

> The stuff that sinks releases even when your test suite is green.

---

## 1. Plugin Uninstall — Does It Clean Up?

### What breaks
User uninstalls your plugin → database still has `wp_options` rows, custom tables, cron jobs, transients. Over time, a WP site accumulates gigabytes of orphaned plugin data.

### How Orbit catches it

```bash
# Inside wp-env
wp-env run cli wp plugin install my-plugin.zip --activate
wp-env run cli wp option list --search="my_plugin_*"   # BEFORE — note count
wp-env run cli wp plugin deactivate my-plugin
wp-env run cli wp plugin uninstall my-plugin
wp-env run cli wp option list --search="my_plugin_*"   # AFTER — should be 0
wp-env run cli wp db query "SHOW TABLES LIKE '%my_plugin%'"  # should be empty
wp-env run cli wp cron event list | grep my_plugin      # should be empty
```

### Fix
Ship an `uninstall.php` at the plugin root:

```php
<?php
if ( ! defined( 'WP_UNINSTALL_PLUGIN' ) ) exit;

// Options
foreach ( ['my_plugin_settings', 'my_plugin_cache', 'my_plugin_version'] as $opt ) {
    delete_option( $opt );
    delete_site_option( $opt );   // multisite
}

// Post meta
delete_post_meta_by_key( '_my_plugin_meta' );

// Custom tables
global $wpdb;
$wpdb->query( "DROP TABLE IF EXISTS {$wpdb->prefix}my_plugin_data" );

// Transients
delete_transient( 'my_plugin_api_cache' );

// Cron
wp_clear_scheduled_hook( 'my_plugin_daily' );

// Capabilities
$role = get_role( 'administrator' );
if ( $role ) $role->remove_cap( 'my_plugin_manage' );
```

### Skill for this
```
/wordpress-plugin-development
Audit my plugin's uninstall cleanup. Verify uninstall.php removes: options, postmeta, custom tables, transients, cron, capabilities. Flag anything that leaks.
```

---

## 2. Upgrade Path — Old → New Version

### What breaks
User has v1.0 installed, upgrades to v2.0. Your new code assumes a DB schema that v1.0 didn't have. Site white-screens.

### How Orbit catches it

```bash
# 1. Install old version
wp-env run cli wp plugin install plugins/free/my-plugin/my-plugin-1.0.zip --activate

# 2. Populate with real data (simulate user activity)
wp-env run cli wp post create --post_type=my_cpt --post_title="Test" --post_status=publish

# 3. Upgrade in place
wp-env run cli wp plugin install plugins/free/my-plugin/my-plugin-2.0.zip --activate --force

# 4. Visit frontend + admin — any fatal errors?
curl -sf http://localhost:8881/?my_cpt=test -o /dev/null || echo "Frontend broken"
WP_TEST_URL=http://localhost:8881 bash scripts/gauntlet.sh --mode quick
```

### Fix
Write `upgrade_from_v1_to_v2()` in an `upgrade.php` that runs on `plugins_loaded`:

```php
add_action( 'plugins_loaded', function() {
    $current = get_option( 'my_plugin_version', '1.0' );
    if ( version_compare( $current, '2.0', '<' ) ) {
        require_once __DIR__ . '/includes/upgrade.php';
        my_plugin_upgrade_to_v2();
        update_option( 'my_plugin_version', '2.0' );
    }
});
```

---

## 3. Multisite Compatibility

### What breaks
Plugin works fine on single WP. On multisite, a super-admin activates network-wide and your plugin:
- Uses `get_option()` instead of `get_site_option()`
- Writes to `wp_options` of site 1 only, breaks sites 2..N
- Has admin pages that don't check `is_network_admin()`

### How Orbit catches it

Create a multisite test site:

```bash
# In wp-env, enable multisite
wp-env run cli wp core multisite-convert --title="Test Network"
wp-env run cli wp site create --slug=site2 --title="Second Site"

# Network-activate your plugin
wp-env run cli wp plugin activate my-plugin --network
```

Run your gauntlet with the second site URL too: `http://localhost:8881/site2/`

### Skill for this
```
/wordpress-plugin-development
Audit my plugin for multisite compatibility:
- Uses of get_option should use get_site_option where appropriate
- Network settings pages use network_admin_menu hook
- Per-site data isolation
- Deactivation/uninstall handles network-wide properly
```

---

## 4. Plugin Conflicts — Interoperability

### What breaks
Your plugin works alone. User activates it alongside WooCommerce / Elementor / Yoast / WPML → crashes.

### How Orbit catches it

Extend `.wp-env.json` with top conflicters:

```json
{
  "plugins": [
    "/path/to/my-plugin",
    "https://downloads.wordpress.org/plugin/woocommerce.zip",
    "https://downloads.wordpress.org/plugin/elementor.zip",
    "https://downloads.wordpress.org/plugin/wordpress-seo.zip"
  ]
}
```

Run gauntlet. If it passes with these active, you're probably safe.

### Skill for this
```
/wordpress-plugin-development
Review my plugin for conflict risks with popular plugins (WooCommerce, Elementor, Yoast, WPML, Rank Math).
Check: hook priority clashes, class name collisions, enqueue handle conflicts, filter return type mismatches.
```

---

## 5. Staging URL Testing — Before Production Push

### What breaks
Local passes. Staging fails because of: HTTPS redirect rules, CDN caching, server-level rewrite issues, different PHP version than local.

### How Orbit handles it

```bash
# Point Playwright at your staging URL (requires auth cookie or basic auth)
WP_TEST_URL=https://staging.example.com \
WP_ADMIN_USER=staging_admin \
WP_ADMIN_PASS=...............  \
  npx playwright test tests/playwright/my-plugin/

# Lighthouse against staging
lighthouse https://staging.example.com --output=html --output-path=reports/staging-lh.html
```

For basic-auth-protected staging:

```js
// playwright.config.js
use: {
  httpCredentials: {
    username: process.env.STAGING_USER,
    password: process.env.STAGING_PASS,
  },
},
```

---

## 6. i18n / Translation Readiness

### What breaks
Your plugin ships with English. French user installs the `.po` file → half the strings still show in English because you forgot `__()` wrappers.

### How Orbit catches it

Gauntlet Step 5 (i18n/POT) already does:
```bash
wp i18n make-pot . plugin.pot    # generates fresh POT
grep "echo '" *.php               # flags raw echoed strings not wrapped
```

But go deeper — test actual translation load:

```bash
# Create a fake locale with 100% coverage
wp-env run cli wp language plugin install my-plugin fr_FR --activate
wp-env run cli wp site switch-language fr_FR

# Visit pages + assert no English strings remain
WP_TEST_URL=http://localhost:8881/?lang=fr npx playwright test --grep=translated
```

### Manual-but-important checks
- **RTL support** — activate Arabic, does CSS flip correctly?
- **Pluralization** — `_n()` usage for counts
- **Date/number formatting** — use `date_i18n()` not `date()`
- **JS strings** — use `wp_set_script_translations()` for JS string i18n

### Skill
```
/wordpress-plugin-development
Audit i18n in my plugin:
- Every user-facing string wrapped in __(), _e(), esc_html__() etc.
- Text domain matches plugin slug consistently
- JS strings use wp.i18n.__() and wp_set_script_translations()
- Date/number formatting uses date_i18n() / number_format_i18n()
- RTL-friendly CSS (margin-inline instead of margin-left)
```

---

## 7. Cron Jobs — Do They Actually Run?

### What breaks
Plugin schedules `my_plugin_daily`. Works fine in dev. User's site has `DISABLE_WP_CRON` set → your cron never fires → feature looks broken.

### How Orbit catches it

```bash
# List scheduled events
wp-env run cli wp cron event list

# Force-run a specific event
wp-env run cli wp cron event run my_plugin_daily

# Disable WP-Cron to simulate user's setup
wp-env run cli wp config set DISABLE_WP_CRON true --type=constant

# Your plugin should gracefully handle "cron never runs"
```

### Fix patterns
- Document the real alternative (real cron job hitting `wp-cron.php`)
- Don't rely on cron for time-critical things
- Use `wp_schedule_event()` with `wp_next_scheduled()` guard to avoid duplicates

---

## 8. GDPR / Privacy Compliance

### What breaks
Plugin stores IP addresses, emails, user behavior → GDPR audit fails → plugin removed from repo.

### What to check
- [ ] Plugin declares what data it collects in readme.txt
- [ ] Exposes data via WP's privacy export hook (`wp_privacy_personal_data_exporters`)
- [ ] Supports data erasure (`wp_privacy_personal_data_erasers`)
- [ ] Privacy policy text block contributed (`wp_add_privacy_policy_content`)
- [ ] No data sent to third-party services without user consent
- [ ] Cookies respect consent plugins

### Test in wp-env

```bash
wp-env run cli wp user create testuser test@example.com
# Trigger your plugin storing data about that user
# Go to Tools > Export Personal Data → should include your plugin's data
# Go to Tools > Erase Personal Data → should clean it
```

### Skill
```
/wordpress-penetration-testing
Audit GDPR compliance for my plugin:
- Personal data identification (emails, IPs, names)
- Export handler registered
- Erasure handler registered
- Privacy policy content contributed
- Third-party API calls use opt-in
- Cookies follow consent patterns
```

---

## 9. REST API — Does Every Endpoint Check Permissions?

### What breaks
Public REST endpoint lets anyone read admin-only data. Critical security bug.

### How Orbit catches it

```bash
# Discover all REST routes added by your plugin
curl -s http://localhost:8881/wp-json/ | python3 -m json.tool | grep -A3 my-plugin
```

For each route: does it have `permission_callback`?

### Playwright test

```js
test('protected endpoint rejects unauthenticated', async ({ request }) => {
  const resp = await request.get('http://localhost:8881/wp-json/my-plugin/v1/admin-data');
  expect(resp.status()).toBe(401);  // or 403
});
```

### Skill
```
/wordpress-penetration-testing
Audit every register_rest_route call in my plugin:
- Missing permission_callback → flag
- permission_callback that returns true without checking → flag
- Endpoints that should check capabilities instead of auth-only → flag
```

---

## 10. File Uploads — Are They Safe?

### What breaks
Plugin accepts user uploads → attacker uploads `.php` disguised as `.jpg` → RCE.

### What to check
- [ ] `wp_check_filetype_and_ext()` used before saving
- [ ] Whitelist MIME types, don't blacklist
- [ ] Uploads go through `wp_handle_upload()` not raw `move_uploaded_file`
- [ ] Upload dir has `.htaccess` blocking PHP execution
- [ ] File size limits enforced
- [ ] Stripped metadata from images (EXIF can leak GPS)

### Skill
```
/wordpress-penetration-testing
Review file upload handling in my plugin:
- MIME type validation (whitelist-based)
- wp_handle_upload usage
- .htaccess protection in upload dir
- Size limits
- Path traversal prevention in filename
- EXIF stripping for images
```

---

## 11. Performance Under Load

### What breaks
Plugin works for 10 posts. User has 10,000 posts → queries time out, site dies.

### How Orbit catches it

```bash
# Seed wp-env with 10,000 posts
wp-env run cli wp post generate --count=10000 --post_type=post

# Then run your gauntlet
bash scripts/gauntlet.sh
bash scripts/db-profile.sh
bash scripts/editor-perf.sh
```

### Red flags in reports
- Queries that return 10,000+ rows without `LIMIT`
- `get_posts(['numberposts' => -1])` — nobody needs infinite
- Missing pagination in admin list tables
- `WP_Query` without `no_found_rows => true` when pagination isn't needed
- Meta queries without `meta_key` index hint

---

## 12. Browser / Device Coverage

### What breaks
Tests pass on Chrome. Safari / Firefox / Edge users report issues.

### Orbit's approach

Playwright runs cross-browser out of the box. Add projects to `playwright.config.js`:

```js
projects: [
  { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
  { name: 'firefox',  use: { ...devices['Desktop Firefox'] } },
  { name: 'webkit',   use: { ...devices['Desktop Safari'] } },
  { name: 'mobile-safari', use: { ...devices['iPhone 13'] } },
],
```

```bash
npx playwright test --project=firefox --project=webkit
```

---

## 13. Offline / Bad Network

### What breaks
Plugin assumes the API is always reachable. User's on flaky WiFi → indefinite spinner or white screen.

### How Orbit tests

```js
test('gracefully handles API timeout', async ({ page, context }) => {
  // Simulate API being down
  await context.route('**/api.external.com/**', route => route.abort());

  await page.goto('/wp-admin/admin.php?page=my-plugin');
  await expect(page.locator('.error-message')).toBeVisible();
});

test('works offline for cached pages', async ({ page, context }) => {
  await page.goto('/');
  await context.setOffline(true);
  await page.goto('/about/');  // from service worker cache if any
});
```

---

## 14. WP Debug / PHP Error Log — Zero Warnings

### What breaks
Users with `WP_DEBUG=true` + log viewers see 100 lines of PHP warnings from your plugin → reputation damage.

### Orbit enforces this

`.wp-env.json` has `WP_DEBUG: true, WP_DEBUG_LOG: true`. After a gauntlet run:

```bash
wp-env run cli bash -c "cat /wordpress/wp-content/debug.log"
# Must be empty or only contain other plugins' noise
```

Add to gauntlet as a failure condition:

```bash
DEBUG_LOG=$(wp-env run cli cat /wordpress/wp-content/debug.log 2>/dev/null)
MY_NOISE=$(echo "$DEBUG_LOG" | grep -c "my-plugin")
[ "$MY_NOISE" -gt 0 ] && fail "PHP warnings from my-plugin: $MY_NOISE"
```

---

## 15. Asset Versioning — Cache Busting

### What breaks
You ship v2.0 with new CSS. Users still see v1.0 CSS because the URL didn't change. Layout broken.

### How Orbit catches it

```bash
# Before + after — compare CSS URLs
wp-env run cli wp eval 'global $wp_styles; var_dump($wp_styles->registered);' | grep my-plugin
# Look for "ver" parameter matching current plugin version
```

### Fix
```php
wp_enqueue_style( 'my-plugin', MY_PLUGIN_URL . 'style.css', [], MY_PLUGIN_VERSION );
//                                                                ^^^^^^^^^^^^^^^^^^^
// Bump this on every release
```

---

## 16. Licensing / Pro Activation Flow

### What breaks
Pro plugin requires license activation. Works on dev. Staging has different domain → activation fails silently.

### Test pattern

```js
test('license activation flow', async ({ page }) => {
  await page.goto('/wp-admin/admin.php?page=my-plugin-license');
  await page.fill('input[name="license_key"]', 'TEST-KEY-12345');
  await page.click('button:has-text("Activate")');
  await expect(page.locator('.license-status-active')).toBeVisible();
});
```

Cover: activate, deactivate, expired, domain-mismatch, rate-limited.

---

## 17. Release-Day Checklist — The Non-Code Parts

- [ ] Version bumped in main plugin file header, `readme.txt`, any JS config
- [ ] `readme.txt` "Tested up to" matches latest stable WP
- [ ] `readme.txt` has proper changelog entry for this version
- [ ] POT file regenerated (gauntlet Step 5 does this)
- [ ] `composer.json` version bumped if published
- [ ] `package.json` version bumped
- [ ] Git tag created AFTER the gauntlet passes
- [ ] GitHub release notes copied from changelog
- [ ] SVN commit prepared if releasing to wordpress.org
- [ ] Pro zip rebuilt with new version number in filename
- [ ] Update server (EDD SL, Freemius) version bumped
- [ ] Email sequence to users drafted

---

## 18. Post-Release Monitoring

What breaks after release that tests couldn't predict:
- User's PHP 7.2 that you didn't test
- Specific WP version combination
- Theme conflict you never saw
- Scale issue (100k posts, 10k users)

### Orbit's post-release helpers

```bash
# Quick compat check on user's reported env
bash scripts/create-test-site.sh --plugin ~/plugins/my-plugin --port 8895 --php 7.4 --wp 6.2
WP_TEST_URL=http://localhost:8895 bash scripts/gauntlet.sh --mode quick

# Reproduce their exact state
wp-env run cli wp db import their-db-dump.sql
wp-env run cli wp plugin activate their-plugins.txt   # line-separated slugs
```

---

## Using Skills to Cover Real-World Cases

```
/antigravity-skill-orchestrator
Run the "real-world QA" audit on my plugin at ~/plugins/my-plugin:
1. Uninstall cleanup (options, tables, cron, caps)
2. Upgrade path from v1 → current
3. Multisite compatibility
4. Plugin conflicts (WC, Elementor, Yoast)
5. GDPR export + erase handlers
6. REST endpoint permissions
7. File upload safety
8. Performance under 10k posts
9. Cross-browser (Firefox + Safari)
10. i18n completeness + RTL
Give a prioritized fix list.
```

---

## Summary

| Case | Automated? | Skill to use |
|---|---|---|
| Uninstall cleanup | Semi (wp-cli) | `/wordpress-plugin-development` |
| Upgrade path | Yes (batch-test) | `/wordpress-plugin-development` |
| Multisite | Yes (wp-env) | `/wordpress-plugin-development` |
| Plugin conflicts | Yes (add to .wp-env.json) | `/wordpress-plugin-development` |
| Staging URL | Yes (WP_TEST_URL env) | `/webapp-uat` |
| i18n | Partial (POT + skill) | `/wordpress-plugin-development` |
| Cron | Yes (wp-cli) | `/performance-engineer` |
| GDPR | Semi (manual + skill) | `/wordpress-penetration-testing` |
| REST auth | Yes (Playwright) | `/wordpress-penetration-testing` |
| File uploads | Skill | `/wordpress-penetration-testing` |
| Performance @ scale | Yes (seed + gauntlet) | `/performance-engineer` |
| Cross-browser | Yes (Playwright) | `/webapp-uat` |
| Offline/bad net | Yes (Playwright routes) | `/e2e-testing-patterns` |
| WP_DEBUG log | Yes (auto-check) | `/wordpress-plugin-development` |
| Asset versioning | Yes (wp-cli audit) | `/performance-engineer` |
| License flow | Yes (Playwright) | `/wordpress-plugin-development` |
| Release checklist | Manual | [checklists/pre-release-checklist.md](../checklists/pre-release-checklist.md) |
| Post-release reproduction | Yes (custom wp-env) | `/debugging-strategies` |
