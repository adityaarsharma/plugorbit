# Local WP Setup Guide
> Full local WordPress environment with real MySQL database for QA testing

---

## Why Local WP (not Docker / InstaWP)

- **Real MySQL** — full database profiling, slow query log, Query Monitor
- **Snapshots** — restore to clean state before each test run in 5 seconds
- **WP-CLI built in** — automate plugin installs, database resets
- **Free** — no API costs, works offline
- **Multiple sites simultaneously** — one per plugin under test

---

## Install Local WP

Download from: https://localwp.com/

Install and open the app. No config needed.

---

## Create Test Sites

### Site 1: The Plus Addons

1. Click **+** (new site)
2. Name: `tpa-test`
3. PHP: `8.1` | Web server: `nginx` | MySQL: `8.0`
4. WordPress admin: `admin` / `password`
5. Click **Finish**

### Site 2: NexterWP

Same process, name: `nexterwp-test`

You'll get:
- `http://tpa-test.local` (or similar)
- `http://nexterwp-test.local`

---

## Install Required Plugins via WP-CLI

Local WP gives you shell access. Click **Open Site Shell** or use WP-CLI directly:

```bash
# For TPA site — set your Local WP site path
export WP_TPA="$HOME/Local Sites/tpa-test/app/public"
export WP_NWP="$HOME/Local Sites/nexterwp-test/app/public"

# Install Query Monitor (required for DB profiling)
wp --path="$WP_TPA" plugin install query-monitor --activate
wp --path="$WP_NWP" plugin install query-monitor --activate

# Install Elementor (required for TPA)
wp --path="$WP_TPA" plugin install elementor --activate

# Install your plugins (replace paths with actual zip locations)
wp --path="$WP_TPA" plugin install ~/Downloads/the-plus-addons.zip --activate --force
wp --path="$WP_NWP" theme  install ~/Downloads/nexterwp.zip --activate --force
wp --path="$WP_NWP" plugin install ~/Downloads/nexter-blocks.zip --activate --force
wp --path="$WP_NWP" plugin install ~/Downloads/nexter-extension.zip --activate --force
```

---

## Enable MySQL Slow Query Log

In Local WP:
1. Click your site → **Database** tab
2. Toggle **Enable Slow Query Log**
3. Threshold: `0.05` seconds

Log location: `~/Library/Application Support/Local/run/*/mysql/mysqld.log`

---

## Take a Clean Snapshot

After fresh install + plugins activated:

1. Right-click your site in Local WP
2. **Snapshots** → **Save Snapshot**
3. Name it: `clean-vX.Y.Z`

**Before every test run**: restore this snapshot to get a fresh database.

---

## Configure Environment Variables

```bash
# Add to your ~/.zshrc or ~/.bash_profile
export WP_TPA_PATH="$HOME/Local Sites/tpa-test/app/public"
export WP_NWP_PATH="$HOME/Local Sites/nexterwp-test/app/public"
export WP_TPA_URL="http://tpa-test.local"
export WP_NWP_URL="http://nexterwp-test.local"
export WP_ADMIN_USER="admin"
export WP_ADMIN_PASS="password"
```

---

## Run Playwright Against Local WP

```bash
# TPA tests
WP_TEST_URL=http://tpa-test.local npx playwright test tests/playwright/tpa/

# NexterWP tests
WP_TEST_URL=http://nexterwp-test.local npx playwright test tests/playwright/nexterwp/

# All tests (with visual regression)
WP_TEST_URL=http://tpa-test.local npx playwright test --update-snapshots  # first run baseline
WP_TEST_URL=http://tpa-test.local npx playwright test                      # compare
```

---

## Test a New Release

```bash
# 1. Restore clean snapshot in Local WP UI
# 2. Install new plugin zip
wp --path="$WP_TPA_PATH" plugin install ~/Downloads/the-plus-addons-v2.zip --activate --force

# 3. Run gauntlet
WP_TEST_URL=http://tpa-test.local bash scripts/gauntlet.sh \
  --plugin ~/Downloads/the-plus-addons-v2-unzipped/ \
  --env local

# 4. Check report
open reports/qa-report-*.md
```

---

## Troubleshooting

**WP-CLI can't connect**: Check site is running in Local WP (green indicator).

**Tests fail on `tpa-test.local`**: Check Local WP is using the correct port. Run `wp --path="$WP_TPA_PATH" option get siteurl`.

**Snapshot restore is slow**: Normal on first restore, subsequent ones are fast.

**Query Monitor not showing data**: Ensure you're logged in as admin and debug bar is enabled.
