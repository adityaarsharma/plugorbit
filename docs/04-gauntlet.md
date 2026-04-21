# The Gauntlet — All 11 Steps Explained

> Every step in `gauntlet.sh`, what it checks, what failure looks like, and exactly how to fix it.

**New to this?** Think of the gauntlet like a pre-flight checklist that a pilot runs through before takeoff. Pilots don't skip steps because they're in a hurry — each item on the list catches a specific class of failure that could be catastrophic in the air. The gauntlet works the same way: each step catches a different class of bug that would hurt your users if it shipped. You run all 11 before every release.

---

## Table of Contents

1. [Running the Gauntlet](#1-running-the-gauntlet)
2. [Step 1 — PHP Lint](#2-step-1--php-lint)
3. [Step 2 — WordPress Coding Standards (PHPCS)](#3-step-2--wordpress-coding-standards-phpcs)
4. [Step 3 — PHPStan Static Analysis](#4-step-3--phpstan-static-analysis)
5. [Step 4 — Asset Weight Audit](#5-step-4--asset-weight-audit)
6. [Step 5 — i18n / POT File Check](#6-step-5--i18n--pot-file-check)
7. [Step 6 — Playwright Tests](#7-step-6--playwright-tests)
8. [Step 7 — Lighthouse Performance](#8-step-7--lighthouse-performance)
9. [Step 8 — Database Profiling](#9-step-8--database-profiling)
10. [Step 9 — Competitor Comparison](#10-step-9--competitor-comparison)
11. [Step 10 — UI / Frontend Performance](#11-step-10--ui--frontend-performance)
12. [Step 11 — Claude Skill Audits](#12-step-11--claude-skill-audits)
13. [Reading the Final Report](#13-reading-the-final-report)
14. [CI Mode vs Local Mode](#14-ci-mode-vs-local-mode)

---

## 1. Running the Gauntlet

The commands below are how you start the gauntlet. Use the full run before every release. Use the quick run during active development when you just want fast feedback on your code changes.

```bash
# Full run (all 11 steps) — recommended before every release
bash scripts/gauntlet.sh --plugin ~/plugins/my-plugin

# Quick run (Steps 1–6 only) — for rapid development iteration
bash scripts/gauntlet.sh --plugin ~/plugins/my-plugin --mode quick

# With qa.config.json present (no --plugin needed)
cd ~/Claude/orbit
bash scripts/gauntlet.sh

# Against a specific environment
bash scripts/gauntlet.sh --plugin ~/plugins/my-plugin --env ci

# Point at staging
WP_TEST_URL=https://staging.example.com bash scripts/gauntlet.sh --plugin ~/plugins/my-plugin
```

### Flags

The table below lists every flag you can pass to `gauntlet.sh`. If you're not sure which to use, the defaults are sensible for local development.

| Flag | Values | Default | Description |
|---|---|---|---|
| `--plugin` | path | (from config) | Absolute path to plugin folder |
| `--mode` | `full`, `quick` | `full` | `quick` skips Steps 7–11 |
| `--env` | `local`, `ci` | `local` | `ci` disables interactive prompts |

**When to use `--mode quick` vs `--mode full`:** Quick mode runs only Steps 1–6 and takes about 1–2 minutes. It's useful during active development when you want fast feedback after making changes. Full mode runs all 11 steps including Lighthouse, database profiling, and AI skill audits — this takes 5–10 minutes and should be run before every release. If you're about to tag a version, always use full mode.

> **Q: Can I skip individual steps?**
> Not directly — the gauntlet is designed to run as a complete pipeline. The closest option is `--mode quick`, which skips the slower steps (7–11). If a specific step is irrelevant to your plugin type, the gauntlet will note it as not applicable rather than fail.

> **Q: What happens if a step fails?**
> The gauntlet records the failure, continues running all remaining steps (so you see the full picture), and exits with code `1` at the end. You'll see a summary of what failed. Fix all failures before releasing. The reports folder will contain detailed output for each step.

### Exit codes

The exit code tells automated systems (like CI/CD pipelines) whether the gauntlet passed or failed. If you're running this manually, look at the summary output instead.

| Code | Meaning |
|---|---|
| `0` | All passed (or passed with warnings) |
| `1` | One or more failures — **do not release** |

---

## 2. Step 1 — PHP Lint

**Why does this step exist?** PHP Lint catches syntax errors — broken code that will prevent your plugin from loading at all. If you skip this step and ship a syntax error, every user who installs your plugin will see a white screen of death (or a fatal error) the moment WordPress tries to load it. Skipping PHP Lint is like publishing a blog post without running spellcheck — the damage is immediate and visible to everyone.

> **Analogy:** PHP Lint is spell-check, but for PHP syntax. It doesn't care if your code is well-written or secure — it just checks that PHP can parse it at all. A spelling mistake in a blog post is embarrassing; a syntax error in a plugin breaks the site.

**What it does**: Runs `php -l` on every `.php` file in the plugin (excluding `vendor/`, `node_modules/`). Catches parse errors and syntax mistakes.

The command below is what the gauntlet runs internally. You don't need to run it manually unless you're debugging a specific file.

**Command used**:
```bash
find "$PLUGIN_PATH" -name "*.php" \
  -not -path "*/vendor/*" -not -path "*/node_modules/*" \
  -exec php -l {} \;
```

**Pass condition**: Zero syntax errors.

Here's what failure looks like and what it means — this error tells you exactly which file and line contains the syntax problem.

**Example failure**:
```
Parse error: syntax error, unexpected '}' in /plugins/my-plugin/includes/class-settings.php on line 47
```

**What to do:** Open the file at the reported line. Common causes:
- Missing `;` at end of statement
- Unmatched `{` or `}`
- Curly-quoted strings from copying from Google Docs (use real apostrophes)

**Tip**: Add PHP lint as a pre-commit hook so this never reaches the gauntlet. This command runs automatically every time you `git commit`, and blocks the commit if there's a syntax error:
```bash
# .git/hooks/pre-commit
find . -name "*.php" -not -path "*/vendor/*" -exec php -l {} \; | grep -v "No syntax errors"
```

---

## 3. Step 2 — WordPress Coding Standards (PHPCS)

**Why does this step exist?** PHPCS catches security vulnerabilities and WordPress API misuse that won't cause an immediate crash but will put your users at risk or get your plugin rejected from the WordPress.org repository. If you skip this step and ship a missing nonce check, an attacker can trick an admin into deleting data they didn't intend to delete. If you ship an unescaped output, an attacker can inject malicious scripts into your admin pages.

> **Analogy:** PHPCS is like ESLint for PHP — a style guide enforcer. Your code might work fine without it, but it catches patterns that are written the wrong way and creates real security or compatibility problems down the line.

**Jargon explained:**
- **Nonce** — a one-time security token that WordPress generates for forms and AJAX requests. When you submit a form, WordPress checks that the nonce matches what it issued — this proves the request came from your site, not from an attacker. A missing nonce check means an attacker can forge that request.
- **Capability check** — verifying that the current user has permission to do what they're trying to do. `current_user_can('manage_options')` is how WordPress asks "is this person an admin?" Skipping this check means any logged-in user (subscriber, contributor) can perform admin-only actions.
- **XSS (Cross-Site Scripting)** — injecting malicious JavaScript into a page that other users see. If your plugin echoes `$_GET['message']` without escaping it, an attacker can craft a URL that injects a script into your admin pages.
- **SQLi (SQL Injection)** — tricking the database into running attacker-supplied commands. If your plugin builds SQL queries by concatenating user input directly into the query string, an attacker can escape the query and run their own SQL commands on your database.

**What it does**: Runs PHP_CodeSniffer with the full WordPress + VIP + PHPCompatibility ruleset (`config/phpcs.xml`). Catches security issues, API misuse, escaping violations, nonce missing, and PHP version compatibility issues.

**Rules always active** (never excluded):
- `WordPress.Security.EscapeOutput` — every output must be escaped
- `WordPress.Security.NonceVerification` — every form/AJAX must verify nonce
- `WordPress.DB.PreparedSQL` — no raw SQL
- `WordPress.WP.Capabilities` — capability checks must use standard caps
- `PHPCompatibilityWP` — PHP 7.4+ compatibility

**Pass condition**: Zero `ERROR` level violations. Up to 9 warnings allowed (warns but passes).

Here's what failure looks like and what it means — each line tells you the exact file, line number, severity level, and what rule was violated.

**Example failure output**:
```
FILE: /plugins/my-plugin/includes/class-admin.php
----------------------------------------------------------------------
FOUND 3 ERRORS AND 1 WARNING AFFECTING 4 LINES
----------------------------------------------------------------------
 23 | ERROR | Missing nonce verification
 45 | ERROR | All output should be run through an escaping function
 67 | ERROR | Use $wpdb->prepare() or similar to prevent possible SQL injection
 91 | WARNING | Detected usage of a non-sanitized input variable
```

**What to do:** Fix each ERROR before releasing. Warnings can be reviewed and documented if they are intentional. Here are fixes for the three most common error types:

```php
// Line 23 — Missing nonce
// BAD
if ( isset( $_POST['action'] ) ) {
    // process form
}

// GOOD
if ( isset( $_POST['action'] ) && check_admin_referer( 'my_action_nonce' ) ) {
    // process form
}

// Line 45 — Missing escape
// BAD
echo $_GET['message'];

// GOOD
echo esc_html( $_GET['message'] );

// Line 67 — Unprepared SQL
// BAD
$wpdb->query( "DELETE FROM $wpdb->posts WHERE ID = " . $_GET['id'] );

// GOOD
$wpdb->query(
    $wpdb->prepare( "DELETE FROM $wpdb->posts WHERE ID = %d", intval( $_GET['id'] ) )
);
```

When you need more detail than the gauntlet summary provides, run PHPCS manually with the commands below. The first gives you the full list of violations. The second attempts to auto-fix the safe ones (like spacing issues) — it won't touch security-related violations, those require manual fixes.

**Running PHPCS manually with full output**:
```bash
phpcs \
  --standard=config/phpcs.xml \
  --extensions=php \
  --ignore=vendor,node_modules \
  --report=full \
  ~/plugins/my-plugin

# Attempt auto-fix (safe transformations only)
phpcbf \
  --standard=config/phpcs.xml \
  --extensions=php \
  --ignore=vendor,node_modules \
  ~/plugins/my-plugin
```

---

## 4. Step 3 — PHPStan Static Analysis

**Why does this step exist?** PHPStan catches logic bugs — code that is syntactically valid and passes coding standards, but contains impossible situations that will crash at runtime. A common example: calling a method on a variable that could be `null`. PHPCS can't catch this because the syntax is fine. PHPStan reads your code without running it and reasons about every possible value each variable could have. If you skip this step, users may hit fatal errors on specific data conditions that your testing never covered.

> **Analogy:** PHPStan is a logic checker. PHPCS is the grammar teacher — PHPStan is the editor who reads your code and says "wait, on line 42, this variable could be null and you're trying to call a method on it. That will crash." It finds the impossible situations that only reveal themselves when a real user hits an unusual data condition.

**What it does**: Static analysis for type errors, undefined variables, impossible conditions, and logic bugs that PHPCS doesn't catch.

**Level**: Level 5 by default (catches the most common real bugs without too much noise).

Here's what failure looks like and what it means — each line identifies a specific logical problem the tool found by reading your code statically, without running it.

**Example failures**:
```
Line 42: Call to method get_value() on possibly null value of type WP_Post|null
Line 78: Parameter $post of method save() has invalid type My_Plugin\Post
Line 103: Function my_plugin_get_item() should return string but return statement is missing
```

**What to do:** Each PHPStan finding points to a real code path where something unexpected could happen. Here are fixes for the two most common patterns:

```php
// Line 42 — Null check missing
// BAD
$post = get_post( $id );
echo $post->post_title;  // $post could be null

// GOOD
$post = get_post( $id );
if ( ! $post instanceof WP_Post ) {
    return;
}
echo esc_html( $post->post_title );

// Line 103 — Missing return
// BAD
function my_plugin_get_item( $id ) {
    if ( $id > 0 ) {
        return get_post( $id );
    }
    // No return for the else case — PHPStan catches this
}

// GOOD
function my_plugin_get_item( $id ) {
    if ( $id > 0 ) {
        return get_post( $id );
    }
    return null;
}
```

When you want to run PHPStan directly, use the commands below. The second command adds `--debug` for more verbose output when the error messages aren't clear enough.

**Running PHPStan manually**:
```bash
phpstan analyse \
  --configuration=config/phpstan.neon \
  --level=5 \
  ~/plugins/my-plugin/includes

# More verbose output
phpstan analyse --configuration=config/phpstan.neon --level=5 --debug ~/plugins/my-plugin/includes
```

**PHPStan is a warning** in the gauntlet (won't fail a release) but should be reviewed. Level-5 errors represent real bugs.

---

## 5. Step 4 — Asset Weight Audit

**Why does this step exist?** Large JavaScript and CSS files slow down every page your plugin touches. A plugin that adds 2MB of JavaScript to the WordPress admin will make the admin noticeably sluggish for all users, even on pages that have nothing to do with your plugin. This step doesn't fail the gauntlet — it establishes a baseline so you can spot accidental bundle bloat between releases before it ships.

**What it does**: Counts total KB/MB of all `.js` and `.css` files in the plugin (excluding `node_modules/` and `.min.js` build artifacts).

**This is informational** — it never fails the gauntlet, but it establishes a baseline. Compare across releases to catch accidental bundle bloat.

Here's what the output looks like — a simple summary of your total asset size. The goal is to track this number over time so you notice when it jumps unexpectedly.

**Example output**:
```
✓ JS total: 0.84MB | CSS total: 156KB
```

**Red flags** — if you see any of these, investigate before releasing:
- JS > 1MB without a complex interactive feature justifying it
- CSS > 500KB for a simple UI
- A release bumps bundle size by >10% without explanation

**What to do if your bundle is too large:** The commands below help you identify what's taking up space and remove what isn't being used.

**Reducing bundle size**:
```bash
# See what's in your JS bundle
npx source-map-explorer ~/plugins/my-plugin/assets/js/main.js

# Find unused CSS
npx purgecss \
  --css ~/plugins/my-plugin/assets/css/frontend.css \
  --content http://localhost:8881

# Orbit skill prompt
claude "/performance-engineer Analyze asset bloat for ~/plugins/my-plugin. Check: unused JS (source-map), purge CSS, code splitting opportunities."
```

---

## 6. Step 5 — i18n / POT File Check

**Why does this step exist?** If your plugin ships without proper internationalization, it cannot be translated into other languages. For a plugin on WordPress.org, this is a critical miss — the global WordPress community depends on translation. More practically, hardcoded strings also cause issues with some hosting environments that expect properly wrapped text. Skipping this step means your plugin will never be usable outside English-speaking markets.

> **Jargon explained:** `i18n` is short for "internationalization" (there are 18 letters between the `i` and the `n`). A `.pot` file is a template that translators use to create translations for your plugin. If the `.pot` file doesn't generate or is missing strings, translators can't translate your plugin.

**What it does**:
1. Runs `wp i18n make-pot` to generate a fresh `.pot` file
2. Counts translatable strings
3. Scans for `echo '...'` patterns not wrapped in `__()` or `_e()`

**Pass condition**: POT file generates successfully. Warns if unwrapped strings are found.

Here's what failure looks like and what it means — this error almost always means your plugin header is missing the text domain declaration.

**Example failure**:
```
⚠ POT generation failed — check plugin header + text domain
```

**What to do:** Your plugin header must declare the text domain. Add or fix these lines at the top of your main plugin file:
```php
/**
 * Plugin Name: My Plugin
 * Text Domain: my-plugin
 * Domain Path: /languages
 */
```

And `Text Domain` must match every `__( 'string', 'my-plugin' )` call exactly.

Here's what the warning looks like — this means translatable strings exist in your code that aren't wrapped in the WordPress translation functions, so they'll stay in English regardless of the user's language setting.

**Example warning**:
```
⚠ 14 possibly untranslated echo strings — review
```

**What to do:** Wrap all user-facing strings in the appropriate WordPress translation functions:
```php
// BAD
echo 'Save Changes';
echo "Settings saved.";

// GOOD
echo esc_html__( 'Save Changes', 'my-plugin' );
echo esc_html__( 'Settings saved.', 'my-plugin' );
```

To run the i18n check manually or investigate specific files, use the commands below. The first generates the `.pot` file. The second finds echo statements that aren't wrapped in translation functions.

**Running the i18n check manually**:
```bash
# From inside your plugin directory
wp i18n make-pot . languages/my-plugin.pot

# Check for untranslated strings
grep -rE "echo\s+['\"]" . --include="*.php" \
  --exclude-dir=vendor --exclude-dir=node_modules \
  | grep -vE "(__\(|_e\(|esc_html__|esc_attr__|_x\(|_n\()"
```

---

## 7. Step 6 — Playwright Tests

**Why does this step exist?** Playwright tests are automated browser tests — they open a real browser, log in to WordPress, and simulate what a user actually does: clicking buttons, filling forms, checking that elements appear on screen. PHP Lint and PHPCS check your source code, but they can't tell you whether the admin panel loads correctly or whether saving settings actually works. If you skip this step, you're releasing without any functional verification that your plugin does what it's supposed to do.

**What it does**: Runs the full Playwright test suite for your plugin — functional tests, visual snapshots, and accessibility checks.

**Test projects run** (from `playwright.config.js`):
- `setup` — logs in once, saves cookies to `.auth/wp-admin.json`
- `chromium` — all functional tests (authenticated as admin)
- `visual` — full-page screenshots for visual regression
- `video` (if flow specs exist) — records every test as video

**Pass condition**: Zero failed tests.

Here's what failure looks like and what it means — the output tells you which test file failed, which specific test within it, and usually includes a screenshot of what the browser saw at the moment of failure.

**Example failure output**:
```
✗ Playwright — 2 failed, 14 passed

  FAILED tests/playwright/my-plugin/core.spec.js:
    ✗ admin panel loads without errors (expected to find .my-plugin-dashboard, not found)
    ✗ settings save persists (timeout waiting for success notice)
```

**What to do:** Open the HTML report first — it has screenshots and traces that show you exactly what happened. Then use the debug commands below to re-run the failing test with more visibility.

**Debug a Playwright failure**:

```bash
# Open the HTML report — click failed test to see screenshot + trace
npx playwright show-report reports/playwright-html

# Re-run in debug mode (opens inspector)
npx playwright test tests/playwright/my-plugin/core.spec.js --debug

# Re-run with visible browser (no headless)
npx playwright test tests/playwright/my-plugin/core.spec.js --headed --slowMo=1000

# Run just the failing test
npx playwright test -g "admin panel loads"
```

**Auth issues** — if tests redirect to login instead of running, your saved authentication cookie has expired. Delete it and re-run the setup project to get a fresh one:
```bash
# Delete stale auth file and re-run setup
rm .auth/wp-admin.json
npx playwright test --project=setup
```

**View visual comparison after snapshot failure**:
```bash
npx playwright show-report reports/playwright-html
# Click the failed snapshot test
# → Shows baseline / actual / diff side-by-side
```

**Update snapshots** when intentional UI changes are made — this tells Playwright to accept the current state of the UI as the new baseline:
```bash
npx playwright test --update-snapshots
```

**Flow tests and video recording**: If you have tests in `tests/playwright/flows/`, the gauntlet also runs the `video` project, recording every test and generating a PM-friendly HTML report at `reports/uat-report-TIMESTAMP.html`.

---

## 8. Step 7 — Lighthouse Performance

**Why does this step exist?** Lighthouse measures how fast your plugin makes WordPress pages load — specifically the metrics Google uses for Core Web Vitals. A plugin with a low Lighthouse score is actively hurting the SEO and user experience of every site that installs it. Users may not immediately blame your plugin, but they'll notice the site is slow, and they'll eventually look at what changed. If you skip this step, you might ship a plugin that tanks Lighthouse scores by 20+ points for every site it's installed on.

**What it does**: Runs Google Lighthouse against the test site homepage. Measures Core Web Vitals + overall performance score.

**Mode**: Only runs in `--mode full`. Skipped in `--mode quick`.

> **Q: Why is Lighthouse skipped in quick mode?**
> Lighthouse requires a full browser run against a live WordPress environment and takes about 30–60 seconds. During active development, that wait isn't worth it. Before every release, it absolutely is.

**Pass condition**: Performance score ≥ 75 (warn). Fail if < 60.

Here's what the output looks like — a simple score between 0 and 100. Above 80 is good. Below 75 is a warning. Below 60 is a failure.

**Example output**:
```
✓ Lighthouse performance: 82/100
```

Here's what failure looks like and what it means — a score below 75 means your plugin is measurably slowing down page loads in a way that affects real users.

**Example failure**:
```
⚠ Lighthouse performance: 58/100 (target: 80+)
```

**What tanks Lighthouse scores** — these are the most common causes:
- JS files not deferred/async (`wp_enqueue_script` without `true` for footer)
- Render-blocking CSS in `<head>` that isn't needed above the fold
- Missing `width`/`height` on `<img>` tags (causes CLS)
- Large images not optimized
- Plugin adding CSS/JS on pages that don't need it

**What to do:** The two most impactful fixes are loading scripts in the footer and only loading assets on pages that actually use your plugin.

**Fix — load assets in footer**:
```php
// BAD
wp_enqueue_script( 'my-plugin', MY_PLUGIN_URL . 'app.js', ['jquery'] );
//                                                          ^^^^^^^ — in header

// GOOD
wp_enqueue_script( 'my-plugin', MY_PLUGIN_URL . 'app.js', ['jquery'], MY_PLUGIN_VERSION, true );
//                                                                                         ^^^^ — in footer
```

**Fix — conditional asset loading**:
```php
function my_plugin_assets() {
    // Only load on pages that actually use the shortcode
    global $post;
    if ( is_a( $post, 'WP_Post' ) && has_shortcode( $post->post_content, 'my_plugin' ) ) {
        wp_enqueue_style( 'my-plugin', MY_PLUGIN_URL . 'style.css', [], MY_PLUGIN_VERSION );
        wp_enqueue_script( 'my-plugin', MY_PLUGIN_URL . 'app.js', [], MY_PLUGIN_VERSION, true );
    }
}
add_action( 'wp_enqueue_scripts', 'my_plugin_assets' );
```

To run Lighthouse manually and open the full report in your browser, use the command below:

**Running Lighthouse manually**:
```bash
lighthouse http://localhost:8881 \
  --output=html \
  --output-path=reports/lighthouse-manual.html \
  --chrome-flags="--headless --no-sandbox"

open reports/lighthouse-manual.html
```

---

## 9. Step 8 — Database Profiling

**Why does this step exist?** Most WordPress performance problems come from the database. A plugin that runs 80 queries to render the admin panel is going to make every admin page sluggish, even if each individual query is fast. This step measures how many queries your plugin generates per page and flags any that are slow (over 50ms). If you skip this step, you might ship a plugin with an N+1 query pattern that causes serious performance degradation at scale.

> **Jargon explained:** An **N+1 query** is a database anti-pattern where a loop runs one database query per item instead of one query for all items. For example, if you have 50 posts and your code runs `get_post_meta()` inside a `foreach` loop, that's 50 separate database queries instead of 1. At 50 posts it's slow. At 500 posts it's a crisis.

**What it does**: Measures query count per page type and captures slow queries (>50ms) using MySQL `performance_schema` and WordPress `SAVEQUERIES`.

**Mode**: Only runs in `--mode full --env local`. Skipped in CI (no real MySQL) and `--mode quick`.

**Output**: `reports/db-profile-TIMESTAMP.txt`

**Pass condition**: Informational only. Gauntlet warns if query counts exceed thresholds in `qa.config.json`.

Here's what the output looks like — a table showing query counts and total query time per page type. The admin panel number is flagged as a warning because it's unusually high.

**Example output**:
```
Homepage:        28 queries | 142ms total
Single post:     24 queries | 118ms
Admin panel:     67 queries | 289ms   ← WARNING
```

**What to do:** If the admin panel is generating significantly more queries than the homepage, investigate what hooks your plugin is running on `admin_init` and whether any of them are triggering N+1 query patterns.

**Red flags**: See [docs/database-profiling.md](database-profiling.md) for full guidance.

To run the database profile manually and read the output file, use the commands below:

**Running DB profile manually**:
```bash
bash scripts/db-profile.sh
cat reports/db-profile-*.txt
```

---

## 10. Step 9 — Competitor Comparison

**Why does this step exist?** Before releasing, it's valuable to see how your plugin compares to the market leaders in your category — not just in code quality but in UI flow and feature completeness. This step installs competitor plugins in a sandboxed environment and runs standardized flow tests against both, generating side-by-side screenshots and a report you can share with a product manager.

**What it does**: If `qa.config.json` has a `competitors` list, installs the competitor plugins in wp-env and runs the comparison flow tests from `tests/playwright/flows/`.

**Pass condition**: Comparison tests complete. Generates screenshots + UAT HTML report.

Here's what the output looks like — a simple confirmation that the analysis ran and a pointer to the generated reports:

**Example output**:
```
✓ Competitor analysis complete — see reports/competitor-*.md
```

**Setting up competitor comparison** — follow these four steps in order:

1. Add competitor slugs to `qa.config.json`:
```json
"competitors": ["wordpress-seo", "rank-math-seo"]
```

2. Copy the SEO test template:
```bash
cp -r tests/playwright/templates/seo-plugin tests/playwright/flows/seo-compare
```

3. Run the discovery test first to get exact nav URLs:
```bash
npx playwright test tests/playwright/flows/seo-compare/core.spec.js -g "Discovery" --headed
```

4. Fill in the pair tests with the discovered URLs.

Full competitor testing guide: [docs/07-test-templates.md](07-test-templates.md)

---

## 11. Step 10 — UI / Frontend Performance

**Why does this step exist?** For Elementor addons, a slow editor experience is a dealbreaker — users will uninstall a widget that takes 2 seconds to insert. For all plugins, frontend page load time directly affects the user experience of every visitor to every site running your plugin. This step measures performance in the actual runtime environment (Elementor editor or frontend browser), not just the code. If you skip it, you might ship widgets that make the Elementor editor feel sluggish or frontend pages that are measurably slower than they should be.

**What it does**: Measures editor performance (Elementor or Gutenberg) or frontend page load time depending on `plugin.type` in config.

**For Elementor addons** (`type: "elementor-addon"`):
- Runs `scripts/editor-perf.sh`
- Measures: editor ready time, widget insert time, memory per widget
- Output: `reports/editor-perf-TIMESTAMP.json`

**For Gutenberg blocks** (`type: "gutenberg-blocks"`):
- Measures block insert latency via Playwright
- Measures React render performance

**For all other plugins**:
- Measures frontend page load time via `curl`
- Reports: total load time + TTFB (Time to First Byte)

Here's what the output looks like for an Elementor addon — it shows both the overall editor ready time and the performance of each individual widget:

**Example output (Elementor)**:
```
✓ Editor performance measured — see reports/editor-perf-20240115-143022.json
  Editor ready: 2840ms | Panel populated: 410ms
  Slowest widget: Hero Section — 950ms insert, 420ms render
```

**Red flags** — investigate any of these before releasing:
- Editor ready > 6 seconds
- Any widget insert > 1.5 seconds
- Memory growth > 250MB over 20 widgets

See [docs/deep-performance.md](deep-performance.md) for detailed interpretation.

---

## 12. Step 11 — Claude Skill Audits

**Why does this step exist?** No automated linter can replicate the judgment of an expert reviewing your code with full domain knowledge. This step runs six AI agents in parallel — each one is a specialist in a different area (security, performance, accessibility, etc.) — and each one reads your entire plugin codebase and writes a detailed audit report. These reports often catch issues that the other ten steps miss, especially architectural problems and subtle security vulnerabilities.

> **Analogy:** Skills are like hiring six specialist consultants to review your code simultaneously. You wouldn't ask your frontend developer to audit your database security — you'd bring in someone who's specifically a database security expert. Each skill brings that specialist-level focus. And a Critical finding from a skill is like a doctor saying "surgery required today" — not "we'll watch it." You fix Critical findings before releasing, full stop.

> **Q: What is a skill, exactly?**
> A skill is a markdown file that gives Claude Code expert-level knowledge in a specific domain. When you invoke `/wordpress-penetration-testing`, Claude Code loads the penetration testing knowledge base and applies it to your plugin code. It's the difference between asking a generalist "is this code secure?" and asking a specialist who knows every WordPress-specific attack vector.

> **Q: Do skills cost money?**
> Yes — each skill invocation is an API call to Claude. Running all 6 skills in parallel costs a small amount (typically a few cents per run, depending on plugin size). This is worth it before every release. During active development, run individual skills only when you suspect a specific issue.

> **Q: How long do skills take?**
> All 6 run in parallel and typically complete in 3–6 minutes depending on plugin size and current API response times.

**What it does**: Launches 6 Claude Code skill agents in parallel, each reading your plugin code and writing a markdown audit report.

**Mode**: Only runs in `--mode full` when `claude` CLI is installed.

**Timeline**: 3–6 minutes (all 6 run simultaneously).

### The 6 skills

The diagram below shows the flow: your plugin PHP files are read by all 6 skills simultaneously, each writing a separate report. All 6 reports are then compiled into a single tabbed HTML report.

```
Plugin PHP files
        │
   ┌────┴────────────────────────────────────────────────────┐
   │                                                          │
   ▼                                                          ▼
/wordpress-plugin-development              /wordpress-penetration-testing
WP standards, hooks, escaping,             OWASP Top 10: XSS, CSRF, SQLi,
nonces, capabilities, i18n                 auth bypass, path traversal
   │                                                          │
   ▼                                                          ▼
/performance-engineer                      /database-optimizer
Hook weight, N+1 queries,                  Prepared statements, autoload
blocking assets, expensive loops           bloat, indexes, transient misuse
   │                                                          │
   ▼                                                          ▼
/accessibility-compliance-                 /code-review-excellence
accessibility-audit                        Dead code, complexity,
WCAG 2.2 AA — admin UI + frontend          error handling, type safety
   │                                                          │
   └──────────────────────┬──────────────────────────────────┘
                          │
                          ▼
        reports/skill-audits/
        ├── wp-standards.md
        ├── security.md
        ├── performance.md
        ├── database.md
        ├── accessibility.md
        ├── code-quality.md
        └── index.html    ← dark-mode tabbed HTML report
```

### Example output

Here's what the gauntlet prints after skills complete — including a warning if Critical findings were found that need to be reviewed before release:

```
✓ Skill audits complete — 6 reports written
✓ Skill audit HTML report: reports/skill-audits/index.html
⚠ Critical findings found — review reports/skill-audits/security.md before release
```

**What to do if you see "Critical findings found":** Open the HTML report immediately. A Critical finding means the skill identified something that poses a serious risk to your users or your plugin's integrity. Do not tag a release until all Critical findings are reviewed and either fixed or explicitly documented as false positives with justification.

### Opening the HTML report

Run this command to open the tabbed HTML report in your browser:

```bash
open reports/skill-audits/index.html
```

The report has 6 tabs (one per skill) with:
- Severity summary at the top (Critical / High / Medium / Low counts)
- Color-coded findings with file:line references
- Code examples showing the bad pattern + the fix

### Running skills manually (without gauntlet)

If you want to run skills without running the full gauntlet — for example, you just changed the database layer and want a quick database security check — use the commands below. The `&` at the end of each line runs them in parallel, and `wait` at the end holds until all six finish.

```bash
P=~/plugins/my-plugin

# All 6 in parallel
claude "/wordpress-plugin-development Audit $P — WP standards, hooks, escaping. Output markdown." > reports/skill-audits/wp-standards.md &
claude "/wordpress-penetration-testing Security audit $P — OWASP Top 10. Output markdown." > reports/skill-audits/security.md &
claude "/performance-engineer Analyze $P — hook weight, N+1, assets. Output markdown." > reports/skill-audits/performance.md &
claude "/database-optimizer Review $P — queries, indexes, autoload. Output markdown." > reports/skill-audits/database.md &
claude "/accessibility-compliance-accessibility-audit Audit $P admin UI + frontend. Output markdown." > reports/skill-audits/accessibility.md &
claude "/code-review-excellence Review $P — quality, complexity. Output markdown." > reports/skill-audits/code-quality.md &
wait
```

### Skills deep-dive

→ [docs/05-skills.md](05-skills.md) for what each skill finds, real vulnerability examples, and how to run add-on skills for specific plugin types.

---

## 13. Reading the Final Report

After the gauntlet completes, you'll see a summary like this. The key numbers are "passed", "warnings", and "failed" — and links to each report type so you know where to look for details.

After the gauntlet, you'll see:

```
=================================
Results: 9 passed | 2 warnings | 0 failed

Reports generated:
  MD report:      /Users/you/Claude/orbit/reports/qa-report-20240115-143022.md
  Playwright:     /Users/you/Claude/orbit/reports/playwright-html/index.html
  Screenshots:    /Users/you/Claude/orbit/reports/screenshots/
  Videos:         /Users/you/Claude/orbit/reports/videos/
  Skill audits:   /Users/you/Claude/orbit/reports/skill-audits/index.html

View Playwright:   npx playwright show-report reports/playwright-html
View skill audits: open reports/skill-audits/index.html

⚠ GAUNTLET PASSED WITH WARNINGS — review before release
```

### When to release

The table below is your decision guide. The rule is simple: if the gauntlet failed, you don't release. If it passed with warnings, you review the warnings and fix Critical/High skill findings first. If it passed cleanly, you're good to tag.

| Result | Decision |
|---|---|
| `✓ GAUNTLET PASSED` | Safe to tag and release |
| `⚠ GAUNTLET PASSED WITH WARNINGS` | Review warnings. Fix Critical/High from skill audits first. |
| `✗ GAUNTLET FAILED` | **Do not release.** Fix failures first. |

**What counts as "warnings reviewed"?** For each warning, you should either fix the underlying issue or write a brief explanation of why the warning is a false positive or an acceptable trade-off. Don't dismiss warnings without looking at them — some warnings (especially in skill audits) represent real risks that are just below the automatic failure threshold.

---

## 14. CI Mode vs Local Mode

### Local (default)

When you run the gauntlet locally, you get the full experience: all 11 steps, database profiling against your local MySQL container, video recording of tests, and skill audits via the Claude CLI.

- All 11 steps run
- DB profiling enabled (uses local MySQL container)
- Video recording enabled
- Skill audits enabled (Claude CLI)
- Browser opens are suppressed

### CI mode

When you run in CI mode (e.g., inside GitHub Actions), the gauntlet adapts to the constraints of a CI environment. Run CI mode with this command:

```bash
bash scripts/gauntlet.sh --plugin ~/plugins/my-plugin --env ci
```

Changes in CI mode:
- Steps 8 (DB profiling) skipped (no persistent MySQL in most CI)
- Workers set to 1 for Playwright (less parallelism for stability)
- HTML reports still generated (artifact-friendly)
- Exit codes respected (non-zero fails the CI job)

See [docs/15-ci-cd.md](15-ci-cd.md) for full GitHub Actions integration.

---

**Next**: [docs/05-skills.md](05-skills.md) — deep-dive into all 6 core skills and 5 add-on skills.
