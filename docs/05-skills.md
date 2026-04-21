# Claude Skills — Complete Reference

> All 6 mandatory core skills + 5 add-on skills. What each one finds, real vulnerability examples with bad→fixed code, and exactly how to invoke them.

**New to skills?** A skill is a markdown file that gives Claude Code expert-level domain knowledge in a specific area. When you invoke `/wordpress-penetration-testing`, Claude Code loads a penetration testing knowledge base — built specifically around WordPress plugin vulnerabilities — and applies it to your plugin code. It's the difference between asking a generalist "does this look secure?" and asking a specialist who knows every WordPress-specific attack vector by name.

Think of it like hiring six different consultant firms to audit your plugin simultaneously. One firm specializes in security penetration testing. Another in performance engineering. Another in accessibility compliance. Each brings deep expertise the others don't have — and issues that slip past one specialist get caught by another.

---

## Table of Contents

1. [How Skills Work](#1-how-skills-work)
2. [Core Skill 1 — WordPress Plugin Development](#2-core-skill-1--wordpress-plugin-development)
3. [Core Skill 2 — WordPress Penetration Testing](#3-core-skill-2--wordpress-penetration-testing)
4. [Core Skill 3 — Performance Engineer](#4-core-skill-3--performance-engineer)
5. [Core Skill 4 — Database Optimizer](#5-core-skill-4--database-optimizer)
6. [Core Skill 5 — Accessibility Compliance](#6-core-skill-5--accessibility-compliance)
7. [Core Skill 6 — Code Review Excellence](#7-core-skill-6--code-review-excellence)
8. [Add-on: antigravity-design-expert](#8-add-on-antigravity-design-expert)
9. [Add-on: wordpress-theme-development](#9-add-on-wordpress-theme-development)
10. [Add-on: wordpress-woocommerce-development](#10-add-on-wordpress-woocommerce-development)
11. [Add-on: api-security-testing](#11-add-on-api-security-testing)
12. [Add-on: php-pro](#12-add-on-php-pro)
13. [Choosing Skills by Plugin Type](#13-choosing-skills-by-plugin-type)
14. [Skill Deduplication Reference](#14-skill-deduplication-reference)
15. [Custom Skill Prompts](#15-custom-skill-prompts)

---

## 1. How Skills Work

Skills are Claude Code specialists — markdown files at `~/.claude/skills/` that give Claude Code expert-level domain knowledge. When you invoke a skill with `/skill-name`, Claude Code loads that domain knowledge and applies it to whatever you're auditing.

> **Q: What is a skill exactly?**
> A skill is a pre-written expert prompt that loads specialized knowledge into Claude Code before it reads your code. Without a skill, Claude Code is a capable generalist. With the `/wordpress-penetration-testing` skill, it becomes a security auditor who knows WordPress-specific attack vectors, common plugin vulnerabilities, and how to express findings at CVSS severity levels. Skills don't change what Claude Code can do — they change how deeply it understands the domain it's reviewing.

> **Q: Do skills cost money?**
> Yes — each skill invocation makes API calls to Claude. Running all 6 core skills on a medium-sized plugin typically costs a few cents per run. The cost is worth it before every release. During development, run individual skills only when you suspect a specific issue in that domain.

> **Q: How long do skills take?**
> When run in parallel (which the gauntlet does automatically), all 6 core skills typically complete in 3–6 minutes. Plugin size affects this — larger codebases take longer because there's more code to read and reason about.

The commands below show how the gauntlet invokes a skill and how you can invoke one directly yourself. Note that skills always write output to a file — they should never output only to the terminal, because the HTML report generator needs the markdown files to build the tabbed report.

```bash
# How the gauntlet invokes a skill
claude "/wordpress-penetration-testing
Security audit the WordPress plugin at: /path/to/plugin
Check: XSS, CSRF, SQLi, auth bypass, path traversal.
Rate each finding Critical / High / Medium / Low.
Output a full markdown report with a severity summary table at the top." \
  > reports/skill-audits/security.md

# How you invoke a skill directly
claude "/wordpress-penetration-testing Audit ~/plugins/my-plugin — OWASP Top 10"
```

Skills always write to files. Never output-only-to-terminal — that breaks the HTML report generator.

---

## 2. Core Skill 1 — WordPress Plugin Development

**Skill**: `/wordpress-plugin-development`
**Report**: `reports/skill-audits/wp-standards.md`

**What this skill catches:** This skill checks whether your plugin follows WordPress coding conventions and uses the WordPress API correctly. It catches issues that PHPCS might flag but not explain — like using `$_SESSION` when you should use transients, or having an `uninstall.php` that doesn't clean up everything your plugin creates. If you skip this skill, you risk shipping a plugin that works fine but violates WordPress.org guidelines, fails a VIP review, or leaves orphaned data behind when uninstalled.

### What it checks

The table below lists every category this skill reviews and what it looks for within each one. After reviewing the report, pay special attention to anything in the Escaping and Nonces rows — those are the categories most likely to contain Critical or High severity findings.

| Category | Checks |
|---|---|
| Escaping | Every output: `esc_html`, `esc_attr`, `esc_url`, `wp_kses_post` |
| Nonces | Forms, AJAX handlers, REST endpoints |
| Capabilities | `current_user_can()` before every privileged action |
| i18n | Text domain consistency, wrapped strings, `date_i18n()` vs `date()` |
| Hooks | Priority conflicts, `__return_false` misuse, `the_content` filter abuse |
| WP APIs | Using `$_SESSION` instead of transients, `file_get_contents` instead of `wp_remote_get` |
| Plugin header | Version numbers, text domain, PHP requirement |
| Uninstall | `uninstall.php` covers options, tables, cron, capabilities |
| Naming | Functions/classes/options prefixed with plugin slug |

**What action to take after reading this table:** For each category with findings, open the referenced file and line in the report. Missing escapes and missing nonces are the two most critical — fix those first. Hook conflicts and naming issues can be scheduled for a follow-up sprint if there are no Critical/High items left.

**Jargon explained:**
- **Nonce** — a one-time security token that WordPress generates for forms and AJAX requests. When a user submits a form, WordPress checks that the nonce in the form matches what it issued — this proves the request was intentional and came from your site, not from an attacker crafting a fake request.
- **Capability check** — verifying that the current user has permission to do what they're trying to do. `current_user_can('manage_options')` asks "is this user an admin?" Skipping this means any logged-in user — including subscribers — can perform admin-only actions.

### Real findings examples

**Missing escape — severity: High**

> **What a real user experiences if you skip this:** An attacker saves malicious JavaScript into a plugin option. Every admin who visits the settings page runs that script. Their session cookies get stolen, and the attacker gains admin access to the site.

```php
// BAD — found in admin-page.php:47
echo '<h2>' . get_option('my_plugin_title') . '</h2>';

// FIXED
echo '<h2>' . esc_html( get_option( 'my_plugin_title' ) ) . '</h2>';
```

**Missing capability check — severity: Critical**

> **A Critical finding is like a doctor saying "surgery required today."** This is not a "we'll watch it" situation. Any logged-in user on the site — a subscriber, a customer in WooCommerce, anyone with an account — can delete data by visiting the right URL. Fix this before releasing.

> **What a real user experiences if you skip this:** A subscriber-level user discovers the action URL and deletes all plugin data. Or an attacker creates a low-privilege account specifically to exploit this.

```php
// BAD — any logged-in user can delete data
add_action( 'admin_post_my_plugin_delete', function() {
    $id = intval( $_GET['id'] );
    delete_option( 'my_plugin_item_' . $id );
    wp_redirect( admin_url( 'admin.php?page=my-plugin' ) );
    exit;
});

// FIXED
add_action( 'admin_post_my_plugin_delete', function() {
    if ( ! current_user_can( 'manage_options' ) ) {
        wp_die( esc_html__( 'You do not have permission to do this.', 'my-plugin' ) );
    }
    check_admin_referer( 'my_plugin_delete_' . intval( $_GET['id'] ) );

    $id = intval( $_GET['id'] );
    delete_option( 'my_plugin_item_' . $id );

    wp_redirect( admin_url( 'admin.php?page=my-plugin' ) );
    exit;
});
```

### Invoke directly

Use this command when you want to run just this skill without running the full gauntlet — for example, after making changes to admin pages or AJAX handlers:

```bash
claude "/wordpress-plugin-development
Audit the WordPress plugin at: ~/plugins/my-plugin
Focus on: escaping, nonces, capability checks, i18n, uninstall cleanup.
Output markdown with severity table at top. File:line references required." \
  > reports/skill-audits/wp-standards.md
```

---

## 3. Core Skill 2 — WordPress Penetration Testing

**Skill**: `/wordpress-penetration-testing`
**Report**: `reports/skill-audits/security.md`

**What this skill catches:** This skill conducts a security audit using the OWASP Top 10 framework, focused specifically on WordPress plugin vulnerabilities. It goes deeper than PHPCS on security — it looks for attack chains, not just individual violations. If you skip this skill, you may ship a plugin with a SQL injection vulnerability or a missing REST API permission callback that allows unauthenticated data exposure.

**Jargon explained:**
- **XSS (Cross-Site Scripting)** — injecting malicious JavaScript into a page that other users see. Reflected XSS uses a URL parameter; stored XSS saves the malicious code to the database so it runs every time anyone loads that page.
- **CSRF (Cross-Site Request Forgery)** — tricking a logged-in user's browser into making requests they didn't intend. An attacker sends a link that, when clicked by a logged-in admin, performs an action on the WordPress site — like deleting content or changing settings — without the admin realizing it.
- **SQLi (SQL Injection)** — tricking the database into running attacker-supplied commands. If your plugin builds SQL queries by concatenating user input directly into the query string (e.g., `"WHERE id = " . $_GET['id']`), an attacker can close the original query and append their own SQL commands.
- **SSRF (Server-Side Request Forgery)** — using your server as a proxy to make requests to internal systems. If your plugin accepts a URL parameter and passes it to `wp_remote_get()` without validation, an attacker can use it to probe your server's internal network.

### What it checks — OWASP Top 10 for WordPress

The table below maps each vulnerability class to what the skill specifically looks for in your plugin code. After reviewing the report, prioritize any Critical or High findings in the XSS, SQLi, and Auth bypass rows — those are the most commonly exploited.

| Vulnerability | What it looks for |
|---|---|
| **XSS** (Reflected, Stored, DOM) | `echo $_GET[...]`, unsanitized option values in output, JS `innerHTML` with WP data |
| **CSRF** | Forms missing `wp_nonce_field()`, AJAX missing `check_ajax_referer()` |
| **SQLi** | `$wpdb->query()` without `prepare()`, string concatenation in SQL |
| **Auth bypass** | Missing `permission_callback` on REST routes, `is_user_logged_in()` instead of `current_user_can()` |
| **Path traversal** | `file_get_contents()` with user input, `include` with `$_GET` |
| **Object injection** | `unserialize()` on user-controlled data |
| **Privilege escalation** | `update_user_meta()` with user-supplied role, capability assignment from input |
| **SSRF** | `wp_remote_get()` with unsanitized URL parameter |
| **File upload RCE** | Missing MIME type validation, no `.htaccess` protection |
| **Insecure Direct Object Reference** | Accessing other users' data without ownership check |

**What action to take after reviewing this table:** For every finding the skill marks as Critical or High, fix it before releasing — no exceptions. Medium findings should be logged as issues and scheduled for the next release cycle. Low findings are informational and can be batched.

### Real findings examples

**SQL injection — severity: Critical**

> **What a real user experiences if you skip this:** An attacker discovers the search endpoint and crafts a search keyword that contains SQL syntax. They extract the entire WordPress database — including all user email addresses, hashed passwords, and any stored private data.

```php
// BAD — found in class-search.php:112
function my_plugin_search( $keyword ) {
    global $wpdb;
    return $wpdb->get_results(
        "SELECT * FROM {$wpdb->prefix}my_plugin_items WHERE name LIKE '%" . $keyword . "%'"
    );
}

// FIXED
function my_plugin_search( $keyword ) {
    global $wpdb;
    return $wpdb->get_results(
        $wpdb->prepare(
            "SELECT * FROM {$wpdb->prefix}my_plugin_items WHERE name LIKE %s",
            '%' . $wpdb->esc_like( sanitize_text_field( $keyword ) ) . '%'
        )
    );
}
```

**Missing REST permission callback — severity: Critical**

> **What a real user experiences if you skip this:** Any visitor — not even logged in — can call `/wp-json/my-plugin/v1/export` and download all your plugin's data. This is a data exposure vulnerability that can lead to GDPR violations and user trust destruction.

```php
// BAD — any visitor can call this endpoint
register_rest_route( 'my-plugin/v1', '/export', [
    'methods'  => 'GET',
    'callback' => 'my_plugin_export_all_data',
]);

// FIXED
register_rest_route( 'my-plugin/v1', '/export', [
    'methods'             => 'GET',
    'callback'            => 'my_plugin_export_all_data',
    'permission_callback' => function() {
        return current_user_can( 'export' );
    },
]);
```

**Stored XSS via meta — severity: High**

> **What a real user experiences if you skip this:** A contributor saves a post with a specially crafted widget title. Every admin who views that post's edit screen runs the injected JavaScript — their session is hijacked and the attacker gets admin access.

```php
// BAD — meta value echoed without escape
function my_plugin_render_widget() {
    $title = get_post_meta( get_the_ID(), '_mp_widget_title', true );
    echo '<h3>' . $title . '</h3>';  // XSS if meta was saved from user input
}

// FIXED
function my_plugin_render_widget() {
    $title = get_post_meta( get_the_ID(), '_mp_widget_title', true );
    echo '<h3>' . esc_html( $title ) . '</h3>';
}
```

### Invoke directly

Use this command to run a focused security audit on your plugin. Customize the "Check:" list to focus on the attack surfaces most relevant to what you recently changed:

```bash
claude "/wordpress-penetration-testing
Security audit the WordPress plugin at: ~/plugins/my-plugin
Check: XSS (reflected + stored + DOM), CSRF, SQLi, auth bypass, path traversal,
object injection, privilege escalation, SSRF, file upload RCE, IDOR.
OWASP Top 10 for WordPress. Rate each finding Critical / High / Medium / Low with CVSS context.
List every finding with file:line. Include code diff for Critical/High.
Output full markdown with severity summary table at the top." \
  > reports/skill-audits/security.md
```

---

## 4. Core Skill 3 — Performance Engineer

**Skill**: `/performance-engineer`
**Report**: `reports/skill-audits/performance.md`

**What this skill catches:** This skill identifies performance problems at the code level — patterns that cause slow pages even though the code "works." The most common issue is N+1 queries (database calls inside loops). Another is synchronous external HTTP calls that block every page load. If you skip this skill, you might ship a plugin that causes noticeable slowness on any site with more than a few dozen posts.

> **Jargon explained:** An **N+1 query** is a loop that runs one database query per item, instead of one query for all items. If you have 50 posts and call `get_post_meta()` inside a `foreach` loop, that's 50 database queries. WordPress provides `update_postmeta_cache()` specifically to solve this — it loads all the meta for all posts in one query, then serves subsequent `get_post_meta()` calls from memory (cache). The fix is usually two lines of code, but the performance impact is enormous at scale.

### What it checks

The table below lists what the performance skill looks for. Pay particular attention to the N+1 Queries and External HTTP rows — those are the most common causes of plugin-induced slowness in production environments.

| Area | Checks |
|---|---|
| **Hook callbacks** | Expensive logic on `init`, `wp_head`, `wp_footer`, `shutdown` |
| **N+1 queries** | DB calls inside loops — should use `update_postmeta_cache()` |
| **Asset loading** | CSS/JS loaded on every page vs conditionally |
| **Blocking resources** | Scripts in `<head>` not deferred |
| **Expensive loops** | `get_posts(['numberposts' => -1])`, unbounded `WP_Query` |
| **External HTTP on page load** | Synchronous `wp_remote_get()` in `init` or `wp_head` |
| **Object caching** | Missing transients around expensive computations |
| **Autoload** | Large data stored in autoloaded options |

**What action to take after reviewing this table:** N+1 query findings and blocking external HTTP findings should be fixed before release — they directly impact every page load. Asset loading and autoload findings can be prioritized based on plugin size and the data volumes involved.

### Real findings examples

**N+1 queries — severity: High**

> **What a real user experiences if you skip this:** On a site with 50 posts, the plugin generates 50 database queries where 1 would do. On a site with 500 posts, it generates 500 queries. Admins notice the listing page is slow; hosting providers flag abnormal database activity.

```php
// BAD — 50 queries for 50 posts
$posts = get_posts([ 'numberposts' => 50 ]);
foreach ( $posts as $post ) {
    $featured = get_post_meta( $post->ID, '_mp_featured', true ); // 50 queries!
}

// FIXED — 1 query total
$posts    = get_posts([ 'numberposts' => 50 ]);
$post_ids = wp_list_pluck( $posts, 'ID' );
update_postmeta_cache( $post_ids ); // primes the cache — 1 query

foreach ( $posts as $post ) {
    $featured = get_post_meta( $post->ID, '_mp_featured', true ); // hits cache, 0 queries
}
```

**Blocking external HTTP — severity: High**

> **What a real user experiences if you skip this:** Every page load on the site waits for your external API to respond. If the API is slow or down, every page on the site hangs. Users see a blank screen for 5–30 seconds, or get a gateway timeout error.

```php
// BAD — blocks every page load if API is slow
add_action( 'init', function() {
    $data = wp_remote_get( 'https://api.example.com/config' );
    // process $data...
});

// FIXED — cache for 1 hour, only fetch when cache is empty
add_action( 'init', function() {
    $data = get_transient( 'mp_api_config' );
    if ( false === $data ) {
        $response = wp_remote_get( 'https://api.example.com/config' );
        if ( ! is_wp_error( $response ) ) {
            $data = wp_remote_retrieve_body( $response );
            set_transient( 'mp_api_config', $data, HOUR_IN_SECONDS );
        }
    }
});
```

---

## 5. Core Skill 4 — Database Optimizer

**Skill**: `/database-optimizer`
**Report**: `reports/skill-audits/database.md`

**What this skill catches:** This skill focuses specifically on how your plugin interacts with the WordPress database — not just security (that's covered by the penetration testing skill) but efficiency and correctness. It finds missing indexes on custom tables, large data stored in autoloaded options, and queries that run without any row limit. If you skip this skill, you might ship a plugin that causes full-table scans on sites with large databases, or that loads megabytes of data into memory on every single page request.

> **Jargon explained:** **Autoload** refers to WordPress options that are loaded into memory on every page request. By default, `add_option()` and `update_option()` mark data as autoloaded. This is fine for small values (a boolean flag, a version number). But if your plugin stores a large array or serialized object as an autoloaded option, that entire blob is loaded into memory on every page load — even on pages that have nothing to do with your plugin.

### What it checks

The table below shows what the database skill examines. The Autoload Bloat and N+1 Patterns rows are the two most common sources of database-related performance problems in plugins.

| Area | Checks |
|---|---|
| **Prepared statements** | All `$wpdb` calls use `prepare()` |
| **N+1 patterns** | Same query inside a loop |
| **Custom tables** | Missing indexes on foreign keys and search columns |
| **Autoload bloat** | Options > 10KB with `autoload = yes` |
| **Transient patterns** | Missing transients around expensive queries |
| **Unbounded queries** | `LIMIT` missing, `SELECT *` without column filtering |
| **Raw SQL** | Direct SQL strings instead of `$wpdb->insert()`, `$wpdb->update()` |

**What action to take after reviewing this table:** Findings in Prepared Statements are security issues and must be fixed before releasing. Findings in Autoload Bloat and N+1 Patterns are performance issues — fix before releasing if the data size is significant. Missing indexes should be fixed in the next release at minimum; they cause progressively worse performance as the table grows.

### Real findings examples

**Autoload bloat — severity: Medium**

> **What a real user experiences if you skip this:** Every page load on the site adds 200KB of memory overhead from your plugin's data, even on pages that never use your plugin. On shared hosting, this can push memory limits. On high-traffic sites, it wastes RAM on every request.

```php
// BAD — stores a big array in autoloaded options (loaded on every request)
update_option( 'my_plugin_all_data', $huge_array );
//             loads 200KB on every page load

// FIXED — mark large data as non-autoload
update_option( 'my_plugin_all_data', $huge_array, false );
//                                                 ^^^^^ — autoload = no
```

**Missing index on custom table — severity: High**

> **What a real user experiences if you skip this:** On a site with 10,000 users, every query that looks up data by `user_id` scans the entire table. What should take 1ms takes 200ms. Admin pages that use your plugin become slow, and on large sites the database load can affect the entire WordPress installation.

```php
// BAD — table created without index on frequently queried column
function my_plugin_create_table() {
    global $wpdb;
    $wpdb->query( "CREATE TABLE {$wpdb->prefix}mp_items (
        id bigint(20) NOT NULL AUTO_INCREMENT,
        user_id bigint(20) NOT NULL,
        status varchar(20) DEFAULT 'active',
        created_at datetime NOT NULL,
        PRIMARY KEY (id)
        -- Missing index on user_id! Every user lookup is a full table scan
    ) {$wpdb->get_charset_collate()}" );
}

// FIXED
$wpdb->query( "CREATE TABLE {$wpdb->prefix}mp_items (
    id bigint(20) NOT NULL AUTO_INCREMENT,
    user_id bigint(20) NOT NULL,
    status varchar(20) DEFAULT 'active',
    created_at datetime NOT NULL,
    PRIMARY KEY (id),
    KEY user_id (user_id),      -- index for user lookups
    KEY status (status)         -- index for status filtering
) {$wpdb->get_charset_collate()}" );
```

---

## 6. Core Skill 5 — Accessibility Compliance

**Skill**: `/accessibility-compliance-accessibility-audit`
**Report**: `reports/skill-audits/accessibility.md`
**Standard**: WCAG 2.2 AA

**What this skill catches:** This skill checks whether your plugin's UI — both the admin settings pages and any frontend output — can be used by people with disabilities. This includes screen reader users, keyboard-only users, and users with visual impairments who rely on sufficient color contrast. On WordPress.org, accessibility violations can prevent plugin approval. More importantly, if you skip this skill, you're shipping a plugin that excludes an estimated 15% of users who depend on accessible interfaces.

### What it checks

The table below covers the main accessibility areas the skill reviews. The Labels, Screen Readers, and Keyboard rows are the most commonly violated — especially for plugins that add custom UI elements without following HTML accessibility conventions.

| Area | Checks |
|---|---|
| **Admin UI** | Labels on form fields, keyboard navigation through settings panels |
| **Block output** | ARIA roles on custom blocks, heading hierarchy |
| **Color contrast** | Text/background ratio ≥ 4.5:1 (AA) |
| **Focus management** | Focus visible on all interactive elements, skip links |
| **Screen readers** | `aria-label` on icon-only buttons, live regions for dynamic updates |
| **Images** | `alt` text on all `<img>`, decorative images with `alt=""` |
| **Forms** | `for`/`id` pairing on labels, error messages associated with fields |
| **Keyboard** | All interactive elements reachable and operable via Tab / Enter / Space |
| **Motion** | `prefers-reduced-motion` respected for animations |

**What action to take after reviewing this table:** Missing labels and icon-only buttons without `aria-label` are the most common Critical or High findings — fix these before releasing. Color contrast issues may require design changes; schedule those with your designer. Motion issues are usually a one-line CSS fix.

### Real findings examples

**Missing label — severity: High**

> **What a real user experiences if you skip this:** A screen reader user tabs to your API key input field and hears "text input" with no indication of what the field is for. They cannot use your plugin's settings page. Screen reader users represent millions of WordPress users globally.

```php
// BAD — screen reader has no idea what this input is for
echo '<input type="text" name="mp_api_key" value="">';

// FIXED
echo '<label for="mp_api_key">' . esc_html__( 'API Key', 'my-plugin' ) . '</label>';
echo '<input type="text" id="mp_api_key" name="mp_api_key"
      aria-describedby="mp_api_key_desc" value="">';
echo '<p id="mp_api_key_desc">' . esc_html__( 'Enter your API key from the dashboard.', 'my-plugin' ) . '</p>';
```

**Icon-only button — severity: High**

> **What a real user experiences if you skip this:** A screen reader user tabs to your delete button and hears "button" — nothing else. They don't know if clicking it will delete something, confirm something, or open a menu. They can't safely use your plugin.

```php
// BAD — screen reader announces "button" with no label
echo '<button class="mp-delete-btn"><span class="dashicons dashicons-trash"></span></button>';

// FIXED
echo '<button class="mp-delete-btn" aria-label="' . esc_attr__( 'Delete item', 'my-plugin' ) . '">
    <span class="dashicons dashicons-trash" aria-hidden="true"></span>
</button>';
```

---

## 7. Core Skill 6 — Code Review Excellence

**Skill**: `/code-review-excellence`
**Report**: `reports/skill-audits/code-quality.md`

**What this skill catches:** This skill reviews overall code quality — the things that don't fail immediately but create fragility, maintenance burden, and hidden bugs over time. It finds dead code that confuses future developers, missing error handling that causes silent failures, and overly complex functions that are impossible to test. If you skip this skill, you might ship code that works today but becomes a maintenance nightmare in six months.

### What it checks

The table below shows the code quality dimensions this skill reviews. The Error Handling row is the most likely to contain findings that affect real users — missing error handling causes silent failures that are hard to debug.

| Area | Checks |
|---|---|
| **Dead code** | Commented-out code blocks, unused functions/classes, unreachable branches |
| **Cyclomatic complexity** | Functions with >10 branches (hard to test, easy to break) |
| **Error handling** | `is_wp_error()` checks after `wp_remote_get()`, graceful fallbacks |
| **Type safety** | Missing type hints, implicit type coercion bugs |
| **Readability** | Magic numbers, unclear variable names, missing docblocks on public APIs |
| **PHP 8.x compatibility** | Deprecated functions, null-safe operator opportunities |
| **DRY violations** | Copy-pasted blocks that should be extracted into functions |
| **Test coverage gaps** | Branches with no corresponding test coverage |

**What action to take after reviewing this table:** Missing error handling findings are the highest priority — fix those before releasing. Complexity findings are important for long-term maintenance; schedule refactoring for functions with complexity scores above 10. Dead code and DRY violations are lower priority but should be cleaned up to keep the codebase maintainable.

### Real findings examples

**Missing error handling — severity: High**

> **What a real user experiences if you skip this:** Your plugin calls an external API. On one specific day, that API returns an error. Because there's no `is_wp_error()` check, PHP tries to call `wp_remote_retrieve_body()` on a `WP_Error` object — this returns an empty string. `json_decode('')` returns null. Your next line tries to access a property on null and throws a fatal error. Users see a white screen or a PHP error in their admin area.

```php
// BAD — if API returns WP_Error, code crashes on next line
$response = wp_remote_get( 'https://api.example.com/data' );
$body     = wp_remote_retrieve_body( $response );
$data     = json_decode( $body );

// FIXED
$response = wp_remote_get( 'https://api.example.com/data' );
if ( is_wp_error( $response ) ) {
    // Log and return a safe default
    error_log( 'My Plugin: API request failed: ' . $response->get_error_message() );
    return [];
}

$body = wp_remote_retrieve_body( $response );
$data = json_decode( $body, true );
if ( JSON_ERROR_NONE !== json_last_error() ) {
    error_log( 'My Plugin: Invalid JSON from API: ' . json_last_error_msg() );
    return [];
}
```

**High complexity — severity: Medium**

> **What a real user experiences if you skip this:** Future developers (including you, six months from now) can't understand or safely modify the function. Bugs get introduced when edge cases are missed. The function can't be unit-tested because there are too many paths through it.

```php
// BAD — 14 nested conditions, impossible to unit-test
function my_plugin_process( $data ) {
    if ( isset( $data['type'] ) ) {
        if ( $data['type'] === 'post' ) {
            if ( isset( $data['id'] ) && $data['id'] > 0 ) {
                if ( current_user_can( 'edit_post', $data['id'] ) ) {
                    if ( get_post_status( $data['id'] ) === 'publish' ) {
                        // ... more nesting ...
```

```php
// FIXED — extract conditions into named functions
function my_plugin_process( $data ) {
    if ( ! my_plugin_is_valid_post_data( $data ) ) {
        return new WP_Error( 'invalid_data', 'Invalid data' );
    }
    if ( ! my_plugin_user_can_edit( $data['id'] ) ) {
        return new WP_Error( 'forbidden', 'Not allowed' );
    }
    return my_plugin_do_process( $data );
}
```

---

## 8. Add-on: antigravity-design-expert

**Skill**: `/antigravity-design-expert`
**When to use**: Elementor addons, UI-heavy plugins, landing page builders

**What this skill catches:** Beyond the 6 core skills, this add-on reviews the design quality and UI polish of your plugin's frontend output. It checks whether interactive elements are large enough to tap on mobile, whether animations are smooth and respect accessibility preferences, and whether spacing follows a consistent grid. If you skip this for Elementor addons, you might ship widgets with poor mobile touch targets or jarring animations.

**What it adds** (beyond the 6 core skills):

The table below shows the design-specific checks this skill adds. These checks are not covered by any of the 6 core skills — they require specialized knowledge of touch targets, animation performance, and visual hierarchy.

| Check | Detail |
|---|---|
| **Hit areas** | All interactive elements ≥ 44×44px (iOS HIG + WCAG 2.5.5) |
| **Concentric radius** | Nested border-radius values follow the `outer - padding` formula |
| **Visual hierarchy** | Typography scale, spacing rhythm, color usage consistency |
| **GSAP / animation quality** | `will-change` usage, 60fps frame budget, `prefers-reduced-motion` |
| **Spacing** | 8px grid system consistency |
| **Mobile polish** | Touch target sizing, tap highlight removal, scroll behavior |

**What action to take after reviewing this table:** Hit area violations are the most common finding and directly affect mobile usability — fix before releasing. Animation performance findings (frame budget, `will-change` misuse) are important for the Elementor editor experience. Visual hierarchy findings are lower priority but affect perceived quality.

**Invoke** this skill with the command below. Include specific areas to focus on in the prompt for more targeted findings:

```bash
claude "/antigravity-design-expert
Design audit the Elementor addon at: ~/plugins/my-elementor-plugin
Check: 44px hit areas, concentric border radius, spacing consistency,
animation performance (60fps, will-change), mobile tap targets.
Rate each finding: Critical / High / Medium / Low.
Output full markdown with severity table." \
  > reports/skill-audits/design.md
```

---

## 9. Add-on: wordpress-theme-development

**Skill**: `/wordpress-theme-development`
**When to use**: Gutenberg block plugins, FSE themes, Gutenberg-first plugins

**What this skill catches:** This add-on understands the Gutenberg block system and Full Site Editing — conventions and requirements that the core WordPress plugin development skill doesn't cover in depth. It checks whether your blocks are registered using `block.json` (the modern, required approach), whether they properly declare which block supports they use, and whether server-rendered blocks use the correct pattern. Skip this for block plugins and you risk WordPress.org rejection for non-standard block registration.

**What it adds**:

The table below covers the Gutenberg-specific checks this skill performs. The `block.json` row is the most commonly violated — many older plugins still register blocks using the PHP-only method which is no longer recommended.

| Check | Detail |
|---|---|
| **block.json** | All blocks use `block.json`, not PHP-only registration |
| **block supports** | `supports.color`, `supports.typography`, `supports.spacing` declared |
| **Template hierarchy** | Custom templates follow WP template hierarchy rules |
| **FSE / theme.json** | `theme.json` `color.palette`, `typography.fontSizes` properly declared |
| **Block transforms** | Transform from/to related block types |
| **Editor vs frontend** | Editor-only CSS/JS not loaded on frontend |
| **Server-side rendering** | `render_callback` for dynamic blocks, not just `save` |

**What action to take after reviewing this table:** `block.json` compliance is required for modern WordPress and should be fixed before releasing. Editor vs frontend asset separation is a performance issue that affects every page using your blocks. Server-side rendering findings may require architectural changes — scope accordingly.

**Invoke**:
```bash
claude "/wordpress-theme-development
Audit the Gutenberg block plugin at: ~/plugins/my-blocks
Check: block.json completeness, block supports, FSE patterns, server-side rendering.
Output markdown with severity table." \
  > reports/skill-audits/gutenberg.md
```

---

## 10. Add-on: wordpress-woocommerce-development

**Skill**: `/wordpress-woocommerce-development`
**When to use**: Any plugin that hooks into WooCommerce

**What this skill catches:** WooCommerce has its own hook system, its own data model (products, orders, customers), and its own security requirements for payment processing. The core WordPress skills don't have this specialized knowledge. If your plugin hooks into WooCommerce and you skip this skill, you might ship code that uses deprecated WooCommerce functions, bypasses WooCommerce's payment gateway security layer, or breaks when WooCommerce updates its template files.

**What it adds**:

The table below shows the WooCommerce-specific checks this skill performs. The Gateway Security row is the most critical — payment gateway callback validation is a mandatory security requirement for any plugin that touches payment flows.

| Check | Detail |
|---|---|
| **WC hooks** | Using correct WC action/filter names, not WP core hooks for WC events |
| **Gateway security** | Payment gateway callback verification, order status checks |
| **Template overrides** | Templates in `templates/woocommerce/` follow WC conventions |
| **Cart / checkout safety** | Nonces on cart actions, sanitized quantities |
| **Product meta** | Correct use of `wc_get_product()` vs `get_post()` |
| **WC version compatibility** | Deprecated WC function usage flagged |
| **REST API** | WC REST API custom endpoints follow WC auth patterns |

**What action to take after reviewing this table:** Gateway Security findings are Critical by definition — fix immediately. WC version compatibility findings should be fixed before the next WooCommerce major release. Template override findings affect upgrade compatibility; address in the current release cycle.

**Invoke**:
```bash
claude "/wordpress-woocommerce-development
Audit the WooCommerce extension at: ~/plugins/my-woo-plugin
Check: WC hooks, gateway security, template overrides, cart safety.
Output markdown with severity table." \
  > reports/skill-audits/woocommerce.md
```

---

## 11. Add-on: api-security-testing

**Skill**: `/api-security-testing`
**When to use**: REST API plugins, headless WordPress setups

**What this skill catches:** This add-on goes deeper on REST API security than the penetration testing core skill. It checks every registered REST endpoint for proper authentication, validates that all parameters have sanitization callbacks, and looks for information leakage in error responses. Skip this for API-heavy plugins and you risk unauthenticated data exposure, user enumeration vulnerabilities, or endpoints that can be abused without rate limiting.

**What it adds**:

The table below covers the API-specific security checks this skill adds. The Endpoint Auth and Input Validation rows are the most commonly violated in plugins that add REST API functionality.

| Check | Detail |
|---|---|
| **Endpoint auth** | Every endpoint has `permission_callback`, not just `__return_true` |
| **Input validation** | `sanitize_callback` on all registered REST params |
| **Rate limiting** | Expensive endpoints have nonce or throttle protection |
| **CORS** | `Access-Control-Allow-Origin` headers correctly scoped |
| **Response leakage** | Error messages don't expose stack traces or user data |
| **JWT / OAuth** | If used: token validation, expiry, refresh flow |
| **Enumeration** | `/wp-json/wp/v2/users` disclosure check |

**What action to take after reviewing this table:** Endpoint Auth findings are Critical — fix before releasing. Response Leakage findings expose internal information to attackers; fix in the current release. CORS findings may require coordination with your frontend team. Enumeration findings (users endpoint) often need to be addressed at the server or theme level rather than the plugin.

**Invoke**:
```bash
claude "/api-security-testing
Audit all REST endpoints in: ~/plugins/my-rest-plugin
Check: auth on every route, input sanitization, rate limiting, CORS, response leakage.
Output markdown with severity table." \
  > reports/skill-audits/api-security.md
```

---

## 12. Add-on: php-pro

**Skill**: `/php-pro`
**When to use**: Complex OOP plugins, PHP 8.x modernization, strict typing

**What this skill catches:** This add-on reviews your PHP code for opportunities to use modern PHP 8.x features that improve type safety, reduce boilerplate, and make the code easier to reason about. It won't find security vulnerabilities — that's the penetration testing skill's job. Instead, it identifies places where you're writing PHP 7.x-style code that could be cleaner and safer with PHP 8.x patterns like typed properties, readonly classes, and native enums. Use this skill when you're targeting PHP 8.0+ and want to modernize your codebase.

**What it adds**:

The table below shows the PHP 8.x modernization patterns this skill looks for. These are not bug fixes — they're improvements that make the code more explicit, safer, and easier to maintain over time.

| Check | Detail |
|---|---|
| **Typed properties** | PHP 8.0+ typed class properties used where appropriate |
| **Null-safe operator** | `$obj?->method()` instead of nested null checks |
| **Named arguments** | Long function calls use named arguments for clarity |
| **Match expressions** | `match()` used instead of `switch` where applicable |
| **Readonly properties** | VO/DTO classes use `readonly` |
| **Fibers** | Async patterns using PHP 8.1 Fibers where appropriate |
| **Enum types** | Status strings replaced by PHP 8.1 enums |
| **Constructor promotion** | `public function __construct( private string $name )` style |

**What action to take after reviewing this table:** These findings are recommendations, not failures. Prioritize Typed Properties and Null-safe Operator findings first — they reduce bugs. Enum Types findings are the most impactful for long-term maintainability. Fibers findings are advanced — only pursue those if you have a specific async use case.

**Invoke**:
```bash
claude "/php-pro
Modernize the PHP code in: ~/plugins/my-plugin/includes
Upgrade patterns to PHP 8.x: typed properties, match expressions, constructor promotion, null-safe.
Output markdown with file:line references." \
  > reports/skill-audits/php-modern.md
```

---

## 13. Choosing Skills by Plugin Type

Not every plugin needs every add-on skill. The table below maps your plugin type to the recommended skill set. Every plugin always runs the core 6. Add-on skills are layered on top based on what your plugin does.

| Plugin type | Core 6 | Add-on skills |
|---|---|---|
| General / utility plugin | ✓ All 6 | — |
| Elementor addon | ✓ All 6 | `antigravity-design-expert` |
| Gutenberg blocks | ✓ All 6 | `wordpress-theme-development` |
| WooCommerce extension | ✓ All 6 | `wordpress-woocommerce-development` |
| FSE theme | ✓ All 6 | `wordpress-theme-development` |
| REST API / headless | ✓ All 6 | `api-security-testing` |
| Complex PHP / DDD | ✓ All 6 | `php-pro` |
| Elementor + WooCommerce | ✓ All 6 | `antigravity-design-expert` + `wordpress-woocommerce-development` |
| Gutenberg + REST API | ✓ All 6 | `wordpress-theme-development` + `api-security-testing` |

**How to use this table:** Find your plugin type in the left column. Add the skills listed in the Add-on column to your gauntlet invocation or skill audit commands. If your plugin spans multiple types (e.g., a Gutenberg plugin with a REST API), add all relevant add-ons.

---

## 14. Skill Deduplication Reference

Multiple skills with similar-sounding names exist in the skill ecosystem. This table tells you which specific skill to use for each task and which alternatives to avoid — the "skip" column lists skills that sound relevant but are either too generic, outdated, or produce lower-quality output for WordPress plugin auditing.

| Task | ✓ Use | ✗ Skip |
|---|---|---|
| WP plugin audit | `/wordpress-plugin-development` | `/wordpress` (too generic) |
| Security | `/wordpress-penetration-testing` | `/security-audit`, `/security-scanning-security-sast` |
| Performance | `/performance-engineer` | `/performance-optimizer`, `/performance-profiling` |
| Database | `/database-optimizer` | `/database`, `/database-admin`, `/database-architect` |
| Accessibility | `/accessibility-compliance-accessibility-audit` | `/accessibility-review`, `/wcag-audit-patterns` |
| Code review | `/code-review-excellence` | `/code-review-ai-ai-review`, `/code-reviewer`, `/code-review-checklist` |
| E2E testing | `/playwright-skill` | `/e2e-testing`, `/playwright-java` |
| WooCommerce | `/wordpress-woocommerce-development` | `/woocommerce` |
| Design | `/antigravity-design-expert` | `/ui-ux-designer`, `/design-expert` |

**Why does this matter?** The skills in the "Skip" column are either too generic (they don't have WordPress-specific knowledge) or are designed for different contexts. Always use the exact skill name from the "Use" column for WordPress plugin work.

---

## 15. Custom Skill Prompts

You can give skills additional context to get more targeted findings. The examples below show how to narrow a skill's focus to a specific file, vulnerability type, or architectural question — rather than running a full audit of the entire plugin.

```bash
# Focused on a specific vulnerability type
claude "/wordpress-penetration-testing
Audit only the REST API endpoints in ~/plugins/my-plugin/includes/api/
Focus exclusively on: permission_callback completeness, input sanitization, rate limiting.
List every register_rest_route call and whether it has proper auth.
Output: table of endpoints with auth status."

# Focused on a known problem area
claude "/database-optimizer
Review only the WP_Query calls in ~/plugins/my-plugin/includes/
I suspect N+1 queries in the listing view. Find every get_post_meta inside a loop.
Show: file:line, query count estimate, fix with update_postmeta_cache."

# Comparing two approaches
claude "/code-review-excellence
Review ~/plugins/my-plugin/includes/class-cache.php
I'm considering replacing the current array-based cache with transients.
Assess: current approach's weaknesses, transient benefits for this use case,
migration risk. Output: recommendation with pros/cons table."

# Full audit with report format specified
claude "/wordpress-plugin-development
Audit ~/plugins/my-plugin
Output format:
## Critical Issues (block release)
## High Issues (fix in this PR)
## Medium Issues (fix next sprint)
## Low / Info (log for later)
Each with: description, file:line, bad code, fixed code."
```

**When to use custom prompts:** Custom prompts are most useful when you've already run the full gauntlet and identified a specific area of concern, or when you've made targeted changes and want to verify just that area without spending API credits on a full re-audit. They're also useful for getting a skill to answer an architectural question (like the cache comparison example above) rather than just listing violations.

---

**Next**: [docs/07-test-templates.md](07-test-templates.md) — complete test templates for every plugin type.
