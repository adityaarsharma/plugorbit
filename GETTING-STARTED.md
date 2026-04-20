# Orbit — Getting Started

> From zero to running a full plugin QA gauntlet in 15 minutes. Every step is a copy-paste command.

---

## Why Orbit Chooses wp-env (Docker) Over Local WP

Before you spend time setting up, here's the honest reasoning:

### Local WP (Local by Flywheel)
- **GUI-driven site creation** — every new test site needs clicks
- Snapshots are manual (click → save → click → restore)
- Can't script "create 5 sites on 5 PHP versions in parallel"
- Great for manual QA, bad for automation
- We removed it from Orbit because **any** manual click is incompatible with "mass scale, no-brain testing"

### wp-now (PHP-WASM + SQLite)
- Zero setup, instant start
- **BUT** uses emulated PHP and SQLite — not real MySQL
- Query Monitor DB profiling is unreliable
- Lighthouse numbers skewed by WASM overhead
- Fine for smoke tests. Dangerous for release decisions.

### wp-env (Docker + MariaDB) ← Orbit's choice
- **Real MariaDB** — identical to production MySQL for queries, indexes, slow logs, `performance_schema`
- **Real PHP** — 7.4 / 8.0 / 8.1 / 8.2 / 8.3 on demand
- **Real WordPress** — what your users actually run
- **Fully CLI** — no GUI clicks after Docker install
- **Multi-site parallel** — spin up 5 sites for 5 PHP versions in one command
- Same tool **Gutenberg core, Automattic, WordPress VIP** use for their CI

### The Trade-off

Docker Desktop = one-time 5-minute install (~1GB disk, 2GB RAM when running).

You **open Docker Desktop once** to start the daemon. After that you never touch it again — everything is `bash scripts/…` from terminal.

If that one-time install is acceptable, wp-env is the right answer for serious QA. If it's not, use wp-now and accept the limitations.

---

## TL;DR

```bash
# 1. One-time setup (15 min total, mostly downloads)
git clone https://github.com/adityaarsharma/orbit && cd orbit
bash setup/init.sh                       # interactive config
bash scripts/install-power-tools.sh      # all CLIs

# 2. Create your test site (45s, fully automated)
bash scripts/create-test-site.sh --plugin ~/plugins/my-plugin

# 3. First-time auth setup (10s, saves cookies, never repeated)
WP_TEST_URL=http://localhost:8881 npx playwright test --project=setup

# 4. Run the full gauntlet
bash scripts/gauntlet.sh

# 5. Run tests visually (watch them live)
npx playwright test --ui
```

That's it. Everything below is context and troubleshooting.

---

## Step 1 — Prerequisites (One-Time Install)

### Required

| Tool | Why | Install |
|---|---|---|
| **Node.js 18+** | Playwright, wp-env, lighthouse | [nodejs.org](https://nodejs.org) or `brew install node` |
| **PHP 8.0+** | Runs locally for linting | `brew install php` (Mac) |
| **Composer** | PHP package manager | `brew install composer` |
| **Docker Desktop** | Real MySQL + real WP sites via wp-env | [docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop/) |
| **Python 3.8+** | Used by a couple scripts | usually pre-installed |
| **Git** | Cloning this repo | pre-installed |

### About Docker

- One-time install (~1GB download, 5 min)
- Launch Docker Desktop **once** — it runs in the background after
- **You never open the Docker GUI again** — everything is CLI from Orbit
- Docker Desktop auto-starts on login (optional, in Docker Settings)

### Verify Prerequisites

```bash
node --version   # should be v18+
php --version    # should be 8.0+
composer --version
docker --version && docker info | head -3
python3 --version
```

If any are missing, install them before continuing.

---

## Step 2 — Clone Orbit

```bash
cd ~              # or wherever you keep projects
git clone https://github.com/adityaarsharma/orbit
cd orbit
```

---

## Step 3 — Interactive Setup

```bash
bash setup/init.sh
```

Answers it'll ask:
1. **Plugin name** — e.g. `My Awesome Plugin`
2. **Plugin slug** — auto-derived, or override
3. **Plugin type** — 1–7 (Elementor addon / Gutenberg / SEO / Woo / theme / general / page-builder)
4. **Plugin source path** — e.g. `~/plugins/my-awesome-plugin`
5. **wp-env port** — default `8881`
6. **Competitors** — comma-separated wordpress.org slugs (optional but recommended)
7. **Pro version?** — if yes, drop zip in `plugins/pro/` later
8. **Team roles** — dev / qa / pm / all
9. **Slack webhook** — optional for notifications

Creates:
- `qa.config.json` — every other script reads from this
- `.env.test` — Playwright environment

---

## Step 4 — Install All Power Tools

```bash
bash scripts/install-power-tools.sh
```

Installs (skipping anything already present):
- **PHP**: PHPCS + WPCS + VIP + PHPCompatibility, PHPStan, Psalm, Rector, PHPBench
- **JS**: Playwright + Chromium/Firefox/WebKit, Lighthouse + LHCI, ESLint, Stylelint, axe-core CLI
- **WP**: WP-CLI, `@wordpress/env`, `wp-now`
- **Security**: WPScan (if Ruby available)
- **Claude Code helpers**: ccusage; prompt for claude-mem

Takes 3–5 minutes on first run.

---

## Step 5 — Create Your Test Site

This spins up a real WordPress on `http://localhost:8881` with your plugin installed, Query Monitor pre-active, debug mode on.

```bash
# Default — reads qa.config.json, uses wp-env (Docker)
bash scripts/create-test-site.sh

# Or explicit
bash scripts/create-test-site.sh --plugin ~/plugins/my-plugin --port 8881
```

What happens:
1. Orbit writes `.wp-env-site/default/.wp-env.json`
2. `wp-env start` pulls WordPress + MariaDB Docker images (first time: ~2 min)
3. Your plugin mounts as a bind-mount — **edits in your plugin source reflect instantly**
4. Query Monitor auto-installs
5. `WP_DEBUG`, `SAVEQUERIES`, `SCRIPT_DEBUG` on

After ~45s: site at `http://localhost:8881`, admin at `http://localhost:8881/wp-admin` (`admin` / `password`).

### Daily Lifecycle

```bash
cd .wp-env-site/default

wp-env stop         # pause (frees RAM)
wp-env start        # resume
wp-env clean all    # reset DB to fresh state
wp-env destroy      # nuke entirely
```

### Run Any WP-CLI Command

```bash
# From Orbit root
(cd .wp-env-site/default && wp-env run cli wp plugin list)
(cd .wp-env-site/default && wp-env run cli wp user list)
(cd .wp-env-site/default && wp-env run cli wp db query "SELECT * FROM wp_options LIMIT 5")
```

---

## Step 6 — First-Time Auth Setup

Runs ONCE, saves admin cookies to `.auth/wp-admin.json`. **All future tests reuse this — zero re-logins.**

```bash
WP_TEST_URL=http://localhost:8881 npx playwright test --project=setup
```

Done. Cookies valid until you `wp-env clean all`.

---

## Step 7 — Run Tests

### Option A — Full Gauntlet (pre-release)

8 steps in sequence: PHP lint → PHPCS → PHPStan → Asset weight → i18n → Playwright → Lighthouse → DB profiling.

```bash
bash scripts/gauntlet.sh
```

Output: `reports/qa-report-{timestamp}.md`

### Option B — Watch Playwright Tests Run Live (UI Mode — RECOMMENDED while developing)

```bash
npx playwright test --ui
```

Interactive GUI. See every test, click to run, time-travel through DOM snapshots, watch mode auto-reruns on save.

### Option C — Headed Mode (see browser window)

```bash
npx playwright test --headed --slowMo=500
```

### Option D — Just a Specific Test File

```bash
npx playwright test tests/playwright/templates/generic-plugin/core.spec.js
```

### Option E — Debug a Failing Test

```bash
npx playwright test --debug
```

Inspector opens — set breakpoints, step through.

### Option F — View Trace After the Fact

```bash
npx playwright show-trace test-results/.../trace.zip
```

Full forensic replay of a failed test.

### Option G — HTML Report

```bash
npx playwright show-report reports/playwright-html
```

Shows pass/fail per test, screenshots, traces, diffs.

---

## Step 8 — Running at Scale (Multi-Plugin)

Test many plugins at once in parallel:

```bash
# Explicit list
bash scripts/batch-test.sh --plugins "plugin-a,plugin-b,plugin-c"

# Auto-discover every plugin in a folder
bash scripts/batch-test.sh --plugins-dir ~/plugins

# Cap parallelism manually (default = half your CPU cores, capped at 4)
bash scripts/batch-test.sh --plugins-dir ~/plugins --concurrency 3
```

Each plugin gets its own wp-env site on a unique port (8881, 8891, 8901…). Sites run in parallel, sites stop after their gauntlet finishes to free RAM.

Output: `reports/batch-{timestamp}.md` (aggregated pass/warn/fail grid).

---

## Step 9 — Pull Competitor Zips

```bash
bash scripts/pull-plugins.sh
```

Reads `competitors` from `qa.config.json`, downloads latest zips from wordpress.org → `plugins/free/<slug>/<slug>-<version>.zip`.

For Pro plugins, drop zips manually in `plugins/pro/`.

---

## Step 10 — Run Claude Code Skills

The superpower layer. Every skill in [SKILLS.md](SKILLS.md). Examples:

```bash
# Security audit
claude "/wordpress-penetration-testing Audit ~/plugins/my-plugin for OWASP Top 10"

# Performance — Elementor editor
bash scripts/editor-perf.sh
claude "/performance-engineer Analyze reports/editor-perf-*.json for widgets >800ms"

# Admin UI review
claude "/antigravity-design-expert Review ~/plugins/my-plugin/admin/ UI"

# Full orchestrated audit (picks skills automatically)
claude "/antigravity-skill-orchestrator Complete pre-release audit on ~/plugins/my-plugin"
```

---

## Typical Daily Workflows

### Dev — "I just pushed a commit, is it still good?"

```bash
bash scripts/gauntlet.sh --mode quick    # skips Lighthouse + DB profiling
npx playwright test --ui                 # watch UI as you fix
```

### QA — "Pre-release sign-off"

```bash
bash scripts/gauntlet.sh                            # full gauntlet
bash scripts/competitor-compare.sh                  # vs competitors
# open reports/qa-report-*.md and reports/competitor-*.md
# work through checklists/pre-release-checklist.md
```

### Product Manager — "Is this release safe?"

```bash
# Just read the reports — no commands needed
open reports/qa-report-*.md
open reports/competitor-*.md
open reports/batch-*.md
```

### Scale Run — "Test all our plugins at once"

```bash
bash scripts/batch-test.sh --plugins-dir ~/plugins
# open reports/batch-*.md
```

---

## Troubleshooting

### `wp-env start` hangs / fails

```bash
docker ps                       # is Docker daemon running?
cd .wp-env-site/default
wp-env destroy && wp-env start  # nuclear reset
```

### Port 8881 already in use

```bash
lsof -i :8881                   # find what's using it
# Kill it, or pick a new port:
bash scripts/create-test-site.sh --port 8882
```

### Playwright tests fail with "Failed to connect"

- Verify site is up: `curl http://localhost:8881`
- Check `WP_TEST_URL` matches your actual port
- Re-run auth setup: `npx playwright test --project=setup`

### PHPCS / PHPStan "command not found"

```bash
# Add composer global bin to PATH
export PATH="$HOME/.composer/vendor/bin:$PATH"
# Add to ~/.zshrc to persist
```

### Docker eating disk space

```bash
docker system prune -af         # reclaims unused images/containers
docker volume prune -f          # reclaims unused volumes
```

### Want to stop ALL wp-env sites at once

```bash
docker stop $(docker ps -q --filter "name=wordpress") 2>/dev/null
```

---

## How Orbit Protects Your Tokens (Claude Code)

- Reports are **short by default** — tables, not prose
- Playwright tests output minimal JSON, not verbose HTML
- Agent prompts in [SKILLS.md](SKILLS.md) ask for prioritized findings only (critical/high/medium/low)
- Scripts log to files — agents read the file path, not the full content
- `claude-mem` (via power-tools) lets you resume audits without re-reading everything

---

## How Orbit Protects Your PC from Melting

- **Concurrency auto-capped** at half your CPU cores (max 4) in batch mode
- wp-env sites are **stopped after gauntlet** completes (auto-cleanup in batch-test.sh)
- Playwright uses `workers: '50%'` by default
- Docker images cached — second run is instant
- `.wp-env-site/` lives locally, not re-created per run

---

## Next Reads

- [README.md](README.md) — feature overview
- [SKILLS.md](SKILLS.md) — every Claude Code skill, with Antigravity attribution
- [docs/wp-env-setup.md](docs/wp-env-setup.md) — wp-env deep dive
- [docs/deep-performance.md](docs/deep-performance.md) — backend + frontend + editor perf
- [docs/database-profiling.md](docs/database-profiling.md) — DB profiling workflow
- [docs/common-wp-mistakes.md](docs/common-wp-mistakes.md) — 15 coding mistakes senior devs avoid
- [docs/power-tools.md](docs/power-tools.md) — every tool in the kit
- [plugins/README.md](plugins/README.md) — the zip drop-box
- [tests/playwright/templates/README.md](tests/playwright/templates/README.md) — test templates per plugin type
