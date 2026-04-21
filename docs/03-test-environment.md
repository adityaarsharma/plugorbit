# Test Environment Setup

> How to spin up a real WordPress site for testing — automatically, reproducibly, and without touching your live site.

Before Orbit can run any tests, it needs a WordPress site to test against. This document explains how to create one that's completely isolated from your live or staging site — a throwaway environment you can destroy and rebuild in seconds. Everything that happens here stays here.

---

## Table of Contents

1. [Two Tools: wp-env vs wp-now](#1-two-tools-wp-env-vs-wp-now)
2. [The Orbit Wrapper: create-test-site.sh](#2-the-orbit-wrapper-create-test-sitesh)
3. [Raw wp-env Usage](#3-raw-wp-env-usage)
4. [wp-now: Zero-Config Quick Start](#4-wp-now-zero-config-quick-start)
5. [Daily Site Management](#5-daily-site-management)
6. [WP-CLI Inside wp-env](#6-wp-cli-inside-wp-env)
7. [Database Access](#7-database-access)
8. [Multisite Testing](#8-multisite-testing)
9. [Multi-PHP Version Matrix](#9-multi-php-version-matrix)
10. [Loading Test Fixtures](#10-loading-test-fixtures)
11. [Plugin Conflict Testing](#11-plugin-conflict-testing)
12. [Troubleshooting](#12-troubleshooting)

---

## 1. Two Tools: wp-env vs wp-now

Orbit supports two ways to run a local WordPress test site. Understanding the difference will save you a lot of confusion.

> **Analogy:** `wp-env` is like renting a fully equipped kitchen — it takes a few minutes to set up, but you get a real stove, real refrigerator, real running water. `wp-now` is like a microwave in a hotel room — ready in five seconds, fine for heating something up, but you can't cook a proper meal in it. Use the kitchen for serious testing; use the microwave for quick checks.

- **wp-env** (pronounced "WordPress environment") runs inside Docker (a container system that creates isolated, self-contained software environments on your machine). It uses a real MySQL database — the same kind your production site uses — which means database-level tests, query profiling, and multi-plugin conflict testing all work exactly as they would in the real world.

- **wp-now** runs without Docker. It uses SQLite (a lightweight database format that lives in a single file) instead of MySQL. This makes it extremely fast to start — about 5 seconds — but it means anything that depends on MySQL-specific behavior won't work correctly.

| Feature | wp-env | wp-now |
|---|---|---|
| Backed by | Docker (real MySQL) | PHP WASM (in-process SQLite) |
| Setup time | ~60 sec first run | ~5 sec |
| DB profiling | ✓ Full MySQL support | ✗ SQLite only |
| Multiple PHP versions | ✓ One config per version | ✗ Single version |
| CI-friendly | ✓ Fully headless | ✓ |
| Requires Docker | ✓ Yes | ✗ No |
| Best for | Full gauntlet, release audits | Quick sanity checks |

**Which one should you use?** The table makes it clear: use `wp-env` for anything that feeds into a real release decision — full gauntlet runs, pre-release audits, performance benchmarks, database profiling. Use `wp-now` only for the quickest possible sanity check: "Does this activate without a fatal error?"

> **Q: Do I need Docker installed?** Yes, to use `wp-env`. Docker Desktop is free for individuals and most small teams. Download it from docker.com, install it, and make sure it's running (you'll see the Docker icon in your menu bar or taskbar) before running any `wp-env` commands. If Docker isn't running, `wp-env start` will hang indefinitely.

**Rule of thumb**: Use `wp-env` for the gauntlet. Use `wp-now` for "does this activate?" checks.

---

## 2. The Orbit Wrapper: create-test-site.sh

The recommended way to start a test site. It handles everything automatically.

If you're new to Orbit, start here. This script does all the setup work for you — you don't need to understand `.wp-env.json` files, Docker commands, or WP-CLI (WordPress Command Line Interface, a tool for managing WordPress from the terminal) to get a working test site. Just point it at your plugin and let it run.

```bash
bash scripts/create-test-site.sh --plugin ~/plugins/my-plugin --port 8881
```

What it does:
1. Creates `.wp-env-site/` with a `.wp-env.json` configured for your plugin
2. Adds Query Monitor for DB profiling
3. Enables `WP_DEBUG`, `WP_DEBUG_LOG`, `SAVEQUERIES` automatically
4. Starts wp-env Docker containers
5. Installs plugins listed in `qa.config.json > companions`
6. Creates an admin user (`admin` / `password`)
7. Prints the site URL and credentials

> **Jargon buster:** `WP_DEBUG` is a WordPress setting that makes PHP errors show up in a log file instead of silently disappearing. `SAVEQUERIES` tells WordPress to keep a record of every database query it runs on each page — this is what allows Orbit to count and profile your plugin's database usage. These are safe to enable on a local test site but should never be enabled on a production site.

### Options

These flags let you customize the test site beyond the defaults. You don't need to use all of them — the only required one is `--plugin`.

```bash
bash scripts/create-test-site.sh \
  --plugin ~/plugins/my-plugin \    # required: path to plugin
  --port 8881 \                     # port for the test site (default: 8881)
  --site my-site \                  # internal site name (default: auto from plugin slug)
  --php 8.2 \                       # PHP version (7.4, 8.0, 8.1, 8.2 — default: latest)
  --wp 6.4 \                        # WordPress version (default: latest)
  --mode full                       # full = Query Monitor + debug enabled; quick = minimal
```

**What these flags actually change:**

- `--php 7.4` — Spins up a test site running PHP 7.4 specifically. Use this when you need to verify your plugin works on older PHP versions, since many shared hosting environments still run PHP 7.4. If you don't specify this, you get the latest stable PHP.
- `--wp 6.4` — Pins WordPress to version 6.4. Useful for testing against the version listed in your plugin's "Requires at least" header, or for reproducing a bug report from a user on an older WordPress version.
- `--mode full` vs `--mode quick` — `full` installs Query Monitor (a plugin that shows database queries, hooks, and errors in the admin bar) and enables all debug settings. `quick` gives you a bare-minimum site that starts faster, good for simple activation checks.

> **Q: What is Query Monitor?** Query Monitor is a free WordPress plugin that turns the admin toolbar into a diagnostics panel. When active, you can see exactly how many database queries each page ran, which hooks fired, any PHP errors, and more. Orbit installs it automatically in `--mode full` so it can read this data during testing.

### Output

When the script finishes, you'll see something like this. The site is ready to use as soon as this output appears.

```
✓ wp-env started
✓ Plugin activated: my-plugin
✓ Query Monitor activated
✓ WP_DEBUG enabled

Site ready at: http://localhost:8881
Admin:         http://localhost:8881/wp-admin
Username:      admin
Password:      password
```

**You're done when:** You see the "Site ready at" line. Open `http://localhost:8881/wp-admin` in your browser, log in with `admin` / `password`, and confirm your plugin is active in the Plugins list.

---

## 3. Raw wp-env Usage

If you want more control, manage wp-env directly.

This section is for when you need something the Orbit wrapper doesn't do — a custom theme, a specific file mapping, or a non-standard WordPress configuration. It requires a `.wp-env.json` file, which is a configuration file that tells wp-env exactly how to set up the WordPress environment.

> **Analogy:** `.wp-env.json` is the blueprint for your test site. The architect (you) draws up the blueprint, and wp-env is the construction crew that builds it. You only need to write the blueprint once. From then on, `wp-env start` rebuilds the same site every time from the same blueprint.

### Basic .wp-env.json

This is the minimum configuration. It installs your plugin, adds Query Monitor for database profiling, and turns on WordPress debug logging so errors don't silently disappear.

```json
{
  "core": "WordPress/WordPress#trunk",
  "plugins": [
    "/path/to/your/plugin",
    "https://downloads.wordpress.org/plugin/query-monitor.zip"
  ],
  "port": 8881,
  "config": {
    "WP_DEBUG": true,
    "WP_DEBUG_LOG": true,
    "SAVEQUERIES": true,
    "WP_DEBUG_DISPLAY": false
  }
}
```

> **Q: What does `WordPress/WordPress#trunk` mean?** This tells wp-env to pull the very latest development version of WordPress (the `trunk` branch on GitHub). Use `WordPress/WordPress#tags/6.4` if you want a specific stable release instead. For regular testing, `trunk` keeps you up to date with changes coming in the next WordPress release.

The command to start the site after creating this file:

```bash
# Start the site
wp-env start

# Site is at http://localhost:8881
# Admin at http://localhost:8881/wp-admin — admin / password
```

### Specific WordPress version

Use this when you need to test against a particular WordPress release — for example, to reproduce a bug reported on 6.4, or to verify compatibility with the version in your plugin's "Requires at least" header.

```json
{
  "core": "WordPress/WordPress#tags/6.4",
  "plugins": ["/path/to/my-plugin"],
  "port": 8881
}
```

### WordPress.org plugin as companion

You can pull companion plugins directly from WordPress.org using their download URL. No manual downloading required — wp-env fetches and installs them automatically when it starts.

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

### Specific theme

Use this when your plugin's behavior depends on the active theme — for example, if it registers template files or modifies theme output. TwentyTwentyFour is a block-based FSE (Full Site Editing) theme, good for testing Gutenberg-facing features.

```json
{
  "themes": [
    "https://downloads.wordpress.org/theme/twentytwentyfour.zip"
  ]
}
```

### Mappings (symlink a local file)

Mappings let you mount a local file or folder into the WordPress install inside Docker. Think of it like sharing a folder between your computer and the Docker container — changes you make to the local folder instantly appear inside the site, and vice versa.

```json
{
  "mappings": {
    "wp-content/uploads/my-test-data": "/path/to/local/test-data"
  }
}
```

> **Q: When would I use mappings?** If you have test images, sample import files, or fixture data on your local machine that your plugin needs to process, mappings let you put them inside the WordPress uploads folder without copying files manually.

---

## 4. wp-now: Zero-Config Quick Start

For instant testing without Docker:

wp-now is the fastest possible way to see your plugin running inside WordPress. There's no setup, no configuration file, no Docker required. You just run the command from your plugin's folder and a browser-accessible WordPress site appears in seconds.

```bash
cd ~/plugins/my-plugin
wp-now start

# → http://localhost:8881
# Runs PHP-WASM with SQLite. No setup required.
```

> **Jargon buster:** PHP-WASM means PHP running as WebAssembly — a technology that lets PHP execute directly in a process on your machine without needing a traditional server setup. It's the magic that makes wp-now so fast, but it also means some low-level PHP and MySQL behavior differs from a real server.

### wp-now with a specific WP version

```bash
wp-now start --wp=6.4
```

### Limitations

These limitations are important to understand so you don't make release decisions based on wp-now tests:

- No real MySQL — DB profiling doesn't work
- No WP-CLI MySQL access
- Session doesn't persist on restart
- Not suitable for multi-plugin conflict testing

**Why does this matter?** If you use wp-now for your main testing and everything looks fine, you may still have database query problems, MySQL-specific SQL errors, or conflict issues that only appear in a real WordPress environment. Always run the full gauntlet with `wp-env` before releasing.

> **Q: If wp-now has so many limitations, why use it at all?** Speed. When you're making rapid changes — writing a new filter, adjusting output, fixing a small bug — running `wp-now start` and reloading a page takes 10 seconds total. Waiting for `wp-env` to spin up takes a minute or more. Use wp-now for the "does this break anything obvious?" check while you're coding, then switch to wp-env for the real test run.

---

## 5. Daily Site Management

These are the commands you'll use every day. Once you've created your test site, you don't need to recreate it from scratch each time — just start and stop the Docker containers.

```bash
# Start (or restart) the site
wp-env start

# Stop (pause Docker containers, keep data)
wp-env stop

# Destroy (wipe everything — clean slate)
wp-env destroy

# Reset DB to factory state (keep containers)
wp-env clean all
wp-env clean db       # just DB
wp-env clean uploads  # just uploads

# View container logs
wp-env logs
wp-env logs --watch   # follow live

# Restart without losing data
wp-env stop && wp-env start
```

**When to use each command:**

- `wp-env start` — Use this every morning when you sit down to work. It starts the Docker containers if they're stopped. If they're already running, it's a no-op.
- `wp-env stop` — Use this when you're done for the day or need to free up memory. Your database and uploaded files are preserved — next time you `start`, everything is exactly as you left it.
- `wp-env destroy` — Use this when you want a completely fresh start. All content, settings, and installed plugins are wiped. The next `wp-env start` will rebuild from your `.wp-env.json` blueprint.
- `wp-env clean db` — Use this between test runs when you want a clean database but don't want to wait for Docker containers to rebuild. Faster than `destroy` + `start`.
- `wp-env logs --watch` — Use this when something is failing and you need to see PHP errors or server output in real time. Open this in a second terminal window while you test in the first.

> **Q: I stopped my computer mid-session and now wp-env isn't responding. What do I do?** Run `wp-env stop` first, then `wp-env start`. If that doesn't help, run `wp-env destroy` and `wp-env start` to get a clean slate. Docker containers can sometimes get into a bad state after hard shutdowns.

---

## 6. WP-CLI Inside wp-env

WP-CLI (WordPress Command Line Interface) is a powerful tool for managing WordPress from the terminal — installing plugins, creating users, generating content, running database queries, and more. Inside wp-env, you access it through `wp-env run cli wp ...`.

Think of WP-CLI as a remote control for WordPress. Instead of clicking through the admin panel, you type a command and WordPress executes it instantly.

All WP-CLI commands work via `wp-env run cli wp ...`:

```bash
# Plugin management
wp-env run cli wp plugin list
wp-env run cli wp plugin activate my-plugin
wp-env run cli wp plugin deactivate my-plugin
wp-env run cli wp plugin install woocommerce --activate
wp-env run cli wp plugin install my-plugin.zip --activate --force  # upgrade
```

The `--force` flag on the last command tells WP-CLI to overwrite the currently installed version. This is how you simulate an upgrade from the command line.

```bash
# User management
wp-env run cli wp user list
wp-env run cli wp user create editor editor@test.com --role=editor --user_pass=password
wp-env run cli wp user create subscriber sub@test.com --role=subscriber --user_pass=password
```

Creating users with different roles lets you test whether your plugin behaves correctly for non-admin users. Many security vulnerabilities in WordPress plugins come from forgetting to check user capabilities before running privileged operations.

```bash
# Content seeding
wp-env run cli wp post create --post_title="Test Post" --post_status=publish
wp-env run cli wp post generate --count=100
wp-env run cli wp post generate --count=10000 --post_type=product  # stress test
wp-env run cli wp post generate --count=200 --post_type=my_cpt
```

Generating posts at scale lets you test how your plugin performs under realistic data volumes. A plugin that runs fine on a 10-post site can degrade significantly on a site with 10,000 posts if it's doing unoptimized database queries.

```bash
# Options
wp-env run cli wp option list --search="my_plugin_*"
wp-env run cli wp option get blogname
wp-env run cli wp option update blogname "Test Site"

# Theme
wp-env run cli wp theme activate twentytwentyfour
wp-env run cli wp theme install storefront --activate

# Transients
wp-env run cli wp transient delete --all
```

> **Jargon buster:** Transients are WordPress's built-in caching system. They're temporary data stored in the database with an expiration time. Deleting all transients (`wp transient delete --all`) is useful when testing caching-related bugs — it forces WordPress to regenerate all cached data fresh.

```bash
# Cron
wp-env run cli wp cron event list
wp-env run cli wp cron event run my_plugin_daily
```

WordPress cron (scheduled tasks) doesn't run on a real clock — it runs when someone visits the site. In a test environment with no real visitors, you need to trigger cron manually using these commands.

```bash
# WP config
wp-env run cli wp config set WP_DEBUG true --type=constant
wp-env run cli wp config get

# DB
wp-env run cli wp db cli            # interactive MySQL shell
wp-env run cli wp db query "SELECT option_name, length(option_value) FROM wp_options WHERE autoload='yes' ORDER BY 2 DESC LIMIT 10"
wp-env run cli wp db export backup.sql
wp-env run cli wp db import restore.sql

# Shell into container
wp-env run cli bash
wp-env run wordpress bash           # WP container shell
```

> **Q: When would I need to shell into the container?** Mostly for debugging. If a file isn't where you expect it, a log file you need to read, or a PHP process you need to inspect — shelling into the container gives you a terminal prompt inside the Docker environment where WordPress is running. It's like SSH-ing into a server.

---

## 7. Database Access

Your test site runs a real MySQL database (the same database software that powers most WordPress sites in production). Orbit uses this database to measure query counts, profile slow queries, and check for database-related bugs.

### Via WP-CLI (easiest)

The simplest way to get a live MySQL prompt connected to your test site's database:

```bash
wp-env run cli wp db cli   # interactive MySQL prompt
```

Once you're in, you can run any SQL query you like. Type `exit` to leave.

### Via External Client (TablePlus, Sequel Ace, DBeaver)

If you prefer a visual database GUI rather than a command-line prompt, you can connect any MySQL client to your wp-env database. First get the connection details:

```bash
# Get the connection details
wp-env run cli wp config get DB_HOST DB_NAME DB_USER DB_PASSWORD --format=table
```

Use those details in TablePlus or any MySQL client.

> **Q: Why would I use a GUI instead of the command line?** For browsing data, comparing table contents before and after a test, or investigating database structure. A visual tool makes it much easier to see all the rows in a table, edit data directly, and navigate relationships. The command line is faster for one-off queries; the GUI is better for exploration.

### Enable performance_schema for query profiling

This unlocks MySQL's built-in query profiling tool, which records detailed statistics about every query that runs — including how long each one took. The `performance_schema` is MySQL's equivalent of a flight recorder for database activity.

```bash
wp-env run cli wp db query "SET GLOBAL performance_schema = ON"

# Top 10 slowest queries
wp-env run cli wp db query "
SELECT DIGEST_TEXT, EXEC_COUNT, TOTAL_LATENCY
FROM performance_schema.events_statements_summary_by_digest
WHERE SCHEMA_NAME = DATABASE()
ORDER BY TOTAL_LATENCY DESC
LIMIT 10
"
```

This query shows you the 10 slowest SQL statements that ran since you enabled the performance schema. If your plugin is causing slow page loads, this is often how you find the exact query responsible.

---

## 8. Multisite Testing

WordPress Multisite (also called WordPress Network) is a feature that lets a single WordPress installation run multiple sites — each with its own content, settings, and users, but sharing the same WordPress codebase and plugin files. This is used by universities, agencies, and media companies to manage dozens or hundreds of sites from one place.

If your plugin claims multisite support, you need to test it here. Multisite introduces complexity that single-site testing doesn't cover — network-level permissions, per-site settings isolation, and plugin activation at the network level versus the individual site level.

```bash
# Convert single site to multisite
wp-env run cli wp core multisite-convert --title="Test Network"

# Create additional sites
wp-env run cli wp site create --slug=site2 --title="Second Site"
wp-env run cli wp site list

# Network-activate your plugin
wp-env run cli wp plugin activate my-plugin --network

# Test the second site
WP_TEST_URL=http://localhost:8881/site2 npx playwright test
```

> **Jargon buster:** Playwright is the browser automation tool Orbit uses to simulate a real user clicking through your plugin's interface. When you run `npx playwright test`, it opens a headless Chrome browser, navigates to the URL you specify, and runs a series of scripted interactions to verify your plugin behaves correctly.

### Multisite .wp-env.json

To start with multisite already configured (rather than converting after the fact), use this config:

```json
{
  "core": "WordPress/WordPress#trunk",
  "plugins": ["/path/to/my-plugin"],
  "port": 8881,
  "config": {
    "WP_ALLOW_MULTISITE": true,
    "MULTISITE": true,
    "SUBDOMAIN_INSTALL": false,
    "DOMAIN_CURRENT_SITE": "localhost",
    "PATH_CURRENT_SITE": "/",
    "SITE_ID_CURRENT_SITE": 1,
    "BLOG_ID_CURRENT_SITE": 1
  }
}
```

> **Q: What's the difference between `SUBDOMAIN_INSTALL: false` and `true`?** With `false`, subsites use path-based URLs like `localhost/site2`. With `true`, they use subdomain-based URLs like `site2.localhost`. For local testing, path-based (`false`) is much easier to set up — subdomain-based requires local DNS configuration.

---

## 9. Multi-PHP Version Matrix

Different hosting environments run different PHP versions. PHP 7.4 is still widely used on budget shared hosting. PHP 8.2 is the modern standard. Your plugin needs to work on all of them without syntax errors, deprecation warnings, or behavioral differences.

> **Analogy:** Testing across PHP versions is like checking that your car manual is readable in English, Spanish, and French. The content is the same; the "language" (PHP version) differs. A PHP 8.0 `match` expression is a syntax error in PHP 7.4. A PHP 7.4 `each()` function is deprecated in PHP 8.0. The matrix catches these mismatches before your users do.

Test your plugin on PHP 7.4, 8.0, 8.1, and 8.2 simultaneously.

### Manual approach (4 terminal tabs)

This approach runs four independent wp-env environments, each on a different PHP version, each on a different port. Open four terminal tabs and run one block in each:

```bash
# Terminal 1 — PHP 7.4
mkdir -p ~/.wp-env-sites/php74 && cd ~/.wp-env-sites/php74
cat > .wp-env.json <<'EOF'
{ "plugins": ["/path/to/my-plugin"], "phpVersion": "7.4", "port": 8881 }
EOF
wp-env start

# Terminal 2 — PHP 8.0
mkdir -p ~/.wp-env-sites/php80 && cd ~/.wp-env-sites/php80
cat > .wp-env.json <<'EOF'
{ "plugins": ["/path/to/my-plugin"], "phpVersion": "8.0", "port": 8882 }
EOF
wp-env start

# Terminal 3 — PHP 8.1
mkdir -p ~/.wp-env-sites/php81 && cd ~/.wp-env-sites/php81
cat > .wp-env.json <<'EOF'
{ "plugins": ["/path/to/my-plugin"], "phpVersion": "8.1", "port": 8883 }
EOF
wp-env start

# Terminal 4 — PHP 8.2
mkdir -p ~/.wp-env-sites/php82 && cd ~/.wp-env-sites/php82
cat > .wp-env.json <<'EOF'
{ "plugins": ["/path/to/my-plugin"], "phpVersion": "8.2", "port": 8884 }
EOF
wp-env start
```

### Run gauntlet against each version

Once all four environments are running, this loop runs Orbit's quick test mode against each one in sequence. The `WP_TEST_URL` environment variable tells Orbit which port to connect to for each run.

```bash
for PORT in 8881 8882 8883 8884; do
  PHP_VER=$(( PORT - 8877 ))  # 4→7.4, 5→8.0, 6→8.1, 7→8.2
  echo "=== Testing on port $PORT ==="
  WP_TEST_URL=http://localhost:$PORT \
    bash scripts/gauntlet.sh --plugin ~/plugins/my-plugin --mode quick
done
```

### Batch PHP matrix (one command)

If you'd rather not manage four terminal tabs, Orbit's batch script handles the whole matrix automatically:

```bash
bash scripts/batch-test.sh \
  --plugins ~/plugins/my-plugin \
  --mode matrix \
  --php-versions "7.4,8.0,8.1,8.2"
```

Results appear in `reports/batch-TIMESTAMP.md` with a pass/fail per PHP version.

> **Q: Do I need to run the full matrix before every release?** For major or minor releases (version bumps like 1.0 → 1.1 or 2.0), yes. For patch releases (1.0.0 → 1.0.1) that only fix a single bug, you can often limit to the PHP versions your support team is actively seeing issues on. But any change to PHP code should ideally pass the full matrix before shipping.

**You're done when:** The batch report shows pass for all four PHP versions. A single failure on any version means there's a compatibility issue you need to fix before releasing.

---

## 10. Loading Test Fixtures

A "fixture" is a set of sample data — posts, users, products, settings — that you load into your test site to simulate a realistic environment. Testing on a blank WordPress install with zero content doesn't reflect how your plugin behaves on real user sites.

Seed your site with realistic data before testing.

### Generate posts at scale

These commands use WP-CLI to generate content programmatically. You don't need to create posts manually.

```bash
# 100 regular posts
wp-env run cli wp post generate --count=100

# 10,000 posts (stress test)
wp-env run cli wp post generate --count=10000

# WooCommerce products
wp-env run cli wp post generate --count=500 --post_type=product

# Custom post type
wp-env run cli wp post generate --count=200 --post_type=my_cpt
```

> **Q: Why would I generate 10,000 posts?** To find performance problems that only appear at scale. A plugin that adds 3 database queries per page load is fine with 100 posts. With 10,000 posts, those same queries might start doing full-table scans instead of using indexes — turning a 5ms query into a 2-second one. Scale testing catches this early.

### Import a database dump from production

If you have access to a real database export from a production or staging site, importing it gives you the most realistic test environment possible — real content, real settings, real plugin data.

```bash
# Export from production
wp db export production-backup.sql

# Import into wp-env
wp-env run cli wp db import /path/to/production-backup.sql

# Search-replace URLs
wp-env run cli wp search-replace 'https://yoursite.com' 'http://localhost:8881' --all-tables
```

The `search-replace` command is critical after importing. WordPress stores its own URL in the database, and every internal link, every image reference, every serialized option contains that URL. Without search-replace, your local test site would still be trying to load images from your production server.

> **Q: Is it safe to import production data into a local test environment?** Be careful with user data, especially emails and passwords. If your production database has real user accounts, those users might receive unexpected emails if your local environment triggers WordPress emails (password resets, comment notifications, etc.). Consider using a staging export that has had emails anonymized, or disabling email delivery in your local wp-env config.

### Create specific users for testing

Testing with only an admin user misses a whole category of bugs. Many plugin vulnerabilities and broken experiences only appear when a lower-privileged user tries to do something.

```bash
wp-env run cli wp user create admin2 admin2@test.com --role=administrator --user_pass=password
wp-env run cli wp user create editor editor@test.com --role=editor --user_pass=password
wp-env run cli wp user create subscriber sub@test.com --role=subscriber --user_pass=password
wp-env run cli wp user create shop_manager manager@test.com --role=shop_manager --user_pass=password
```

Create at least a subscriber-level user and test your plugin's frontend output while logged in as that user. If your plugin shows admin-only content to subscribers, or breaks the frontend for non-logged-in visitors, you'll catch it here.

### Activate specific pages

Some plugins require specific WordPress pages to exist — WooCommerce needs a Shop page, a Cart page, a Checkout page. This block creates those pages and connects them to WooCommerce's settings automatically.

```bash
# Create pages your plugin needs
wp-env run cli wp post create \
  --post_type=page \
  --post_title="Shop" \
  --post_status=publish \
  --post_content="[woocommerce_shop]"

wp-env run cli wp option update woocommerce_shop_page_id $(wp-env run cli wp post list --post_type=page --name=shop --field=ID)
```

---

## 11. Plugin Conflict Testing

The goal of conflict testing is to prove your plugin coexists peacefully with the most popular WordPress plugins your users are likely to have active at the same time.

Stress-test your plugin alongside popular conflict risks:

```bash
# Install the "conflict suite"
wp-env run cli wp plugin install \
  woocommerce \
  elementor \
  wordpress-seo \
  contact-form-7 \
  wpml \
  --activate

# Run your gauntlet — all these plugins active simultaneously
bash scripts/gauntlet.sh --plugin ~/plugins/my-plugin
```

If the gauntlet passes with all these active, you're safe for 90% of real-world installs.

### Common conflict sources

This table explains why each plugin is a known conflict risk and what specific things to check. Use it as a diagnostic guide when your gauntlet fails with one of these plugins active.

| Plugin | Why it conflicts | What to check |
|---|---|---|
| WooCommerce | `wc_` function prefix, cart hooks | `woocommerce_loaded` hook timing |
| Elementor | `elementor/loaded` action, widget registration | Use `elementor/widgets/register`, not `init` |
| Yoast SEO | `wpseo_` option prefix, `the_title` filter weight | Filter priority clashes |
| Rank Math | Schema output, canonical URL filters | Duplicate schema types in `<head>` |
| WPML | Language handling in queries, URLs | Hardcoded `get_locale()` calls |
| Beaver Builder | Similar widget API to Elementor | Class name collisions |

**Reading this table:** The "Why it conflicts" column tells you the general danger zone. The "What to check" column tells you the specific line or pattern in your code that's most likely to cause the conflict.

For example: if your plugin registers Elementor widgets on the `init` WordPress hook and Elementor itself hasn't finished loading yet at that point, your widget registration silently fails and the widget never appears. The fix is to use `elementor/widgets/register` instead, which fires after Elementor is fully ready.

> **Q: My plugin passes in isolation but fails when one of these conflict plugins is active. How do I debug it?** Start by disabling the conflict plugins one at a time until the failure disappears — that identifies which plugin is causing the conflict. Then run `wp-env logs --watch` with both plugins active and look for PHP errors or warnings. Usually the conflict appears as a fatal error, a warning about an already-defined function, or a JavaScript error in the browser console.

**Why does this matter?** Conflict bugs are particularly damaging because they're nearly impossible for users to diagnose on their own. They activate your plugin, activate another plugin, and suddenly something breaks — and they don't know which plugin is responsible. Running conflict testing before release gives you confidence that you won't be blamed for another plugin's behavior, and that your plugin isn't accidentally breaking theirs.

---

## 12. Troubleshooting

Something went wrong. Here's how to diagnose and fix the most common problems.

### wp-env start hangs

If the command runs for more than 2–3 minutes without producing the "Site ready" output, Docker is likely the culprit.

```bash
# Check Docker is running
docker info

# Nuclear option — destroy and restart
wp-env destroy
wp-env start
```

`docker info` will either return a list of Docker system information (meaning Docker is running and healthy) or an error message saying it can't connect to the Docker daemon (meaning Docker isn't running — open Docker Desktop and wait for it to start fully before trying again).

### Port already in use

This error means another process on your machine is already listening on port 8881 — either another wp-env instance, a different local development tool, or sometimes a previous wp-env run that didn't shut down cleanly.

```bash
lsof -i :8881       # see what's on port 8881
# Use a different port:
# Change "port" in .wp-env.json to 8882
```

The `lsof` command lists all processes using port 8881. If you see `wp-env` in the output, run `wp-env stop` to clean it up. If you see something else, either stop that process or change wp-env to use a different port number.

### Site loads but plugin not active

Your test site is running but your plugin isn't appearing in the admin panel or isn't doing anything on the frontend.

```bash
wp-env run cli wp plugin list | grep my-plugin
wp-env run cli wp plugin activate my-plugin
```

The first command checks whether WordPress even knows your plugin exists. If it doesn't appear in the list at all, the problem is with the path in your `.wp-env.json` — WordPress can't find the plugin files. If it appears but shows "inactive", the second command activates it.

### "Plugin could not be activated because it triggered a fatal error"

WordPress activated your plugin but immediately encountered a PHP error, so it automatically deactivated it. WordPress hides the actual error message in the admin UI to avoid breaking the page. This command reveals it:

```bash
wp-env run cli wp eval 'ini_set("display_errors", 1); include ABSPATH . "wp-admin/includes/plugin.php"; activate_plugin("my-plugin/my-plugin.php");'
# Shows the actual PHP fatal
```

The output will contain the exact PHP error — file path, line number, and error message. That's what you need to fix.

### Changes to .wp-env.json not taking effect

You edited `.wp-env.json` to add a new companion plugin or change the PHP version, but after running `wp-env start`, nothing changed.

```bash
wp-env stop
wp-env start --update  # re-pulls config
```

By default, `wp-env start` reuses cached containers. The `--update` flag forces it to re-read the config file and apply any changes.

### Plugin not found after updating path

You moved your plugin folder to a different location and updated the path in `.wp-env.json`, but wp-env still can't find it.

```bash
# Destroy and recreate (path must be in .wp-env.json before start)
wp-env destroy && wp-env start
```

wp-env mounts your plugin folder into Docker when the container is first created. If you change the path after the container exists, the old mount persists. Destroying the container and creating it fresh with the new path is the reliable fix.

> **Q: Will destroying the container lose my test data?** Yes — `wp-env destroy` wipes the database and all content in the test site. If you have important test data you want to keep, export the database first with `wp-env run cli wp db export backup.sql` before running destroy.

---

**Next**: [docs/04-gauntlet.md](04-gauntlet.md) — understand all 11 gauntlet steps in depth.
