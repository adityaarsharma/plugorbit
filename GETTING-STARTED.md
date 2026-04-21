# Orbit — WordPress Plugin QA Framework

> The fastest way to go from "I think this plugin is ready" to "I know it is."
> Orbit runs static analysis, browser tests, performance benchmarks, security scans,
> and AI skill audits — all from one command.

If you've never used Orbit before, think of it like a car pre-trip checklist — except instead of 10 manual items you tick off yourself, Orbit runs 11 automated checks in sequence and hands you a complete report at the end. You point it at your plugin folder and let it do the work.

---

## What Orbit Does in 60 Seconds

The diagram below shows the full pipeline from start to finish. When you run the `gauntlet.sh` script, it moves through each step automatically. You don't need to trigger them one by one.

```
Your Plugin
    │
    ▼
bash scripts/gauntlet.sh --plugin ~/plugins/my-plugin
    │
    ├─ Step 1  PHP Lint          → zero syntax errors required
    ├─ Step 2  PHPCS / WPCS      → WP coding standards, security rules
    ├─ Step 3  PHPStan           → static analysis, type safety
    ├─ Step 4  Asset Weight      → JS/CSS bundle size audit
    ├─ Step 5  i18n / POT        → translatable strings check
    ├─ Step 6  Playwright        → functional + visual + accessibility tests
    ├─ Step 7  Lighthouse        → performance score (target: 80+)
    ├─ Step 8  DB Profiling      → query count + slow query detection
    ├─ Step 9  Competitor        → side-by-side feature comparison
    ├─ Step 10 UI Performance    → editor load time (Elementor/Gutenberg)
    └─ Step 11 Claude Skill Audits (6 parallel AI agents, 3-6 min)
               ├─ WP Standards  → hooks, escaping, nonces, i18n
               ├─ Security      → OWASP Top 10 for WordPress
               ├─ Performance   → N+1s, blocking assets, hook weight
               ├─ Database      → queries, indexes, autoload bloat
               ├─ Accessibility → WCAG 2.2 AA
               └─ Code Quality  → complexity, dead code, error handling
    │
    ▼
reports/
├── qa-report-TIMESTAMP.md           ← full markdown report
├── playwright-html/index.html       ← visual test report
├── skill-audits/index.html          ← tabbed AI audit report
├── uat-report-TIMESTAMP.html        ← PM-friendly video + screenshot report
└── lighthouse/lh-TIMESTAMP.json     ← performance data
```

**One command. Zero manual steps. Release with confidence.**

All reports are saved locally in a `reports/` folder. You get a full markdown summary, an interactive HTML report from Playwright (a browser automation tool that simulates real user interactions), an AI-generated audit, and a Lighthouse performance score. Each one targets a different audience: developers, QA engineers, and project managers.

---

## 5-Minute Quick Start

If you just want to try Orbit immediately, these five commands are all you need. Run them in order — each one depends on the previous completing successfully.

This clones the Orbit repository to your machine. A repository is like a project folder tracked by Git (a version control system). `git clone` copies the entire project to `~/Claude/orbit` on your computer.

```bash
# 1. Clone Orbit
git clone https://github.com/adityaarsharma/orbit.git ~/Claude/orbit
cd ~/Claude/orbit
```

This runs Orbit's all-in-one setup script. It installs every tool Orbit needs — JavaScript packages, PHP analysis libraries, browser binaries, and more. You only need to do this once.

```bash
# 2. Install all tools in one shot
bash setup/install.sh
```

This spins up a temporary WordPress site inside Docker (a system that runs isolated environments called containers — think of it as a disposable test WordPress site that lives in a box on your computer and disappears when you're done). The plugin you specify gets automatically installed and activated on that site.

```bash
# 3. Start a test WordPress site for your plugin
bash scripts/create-test-site.sh --plugin ~/plugins/my-plugin --port 8881
```

This is the main event. It runs all 11 checks against your plugin in sequence and generates the reports.

```bash
# 4. Run the full gauntlet
bash scripts/gauntlet.sh --plugin ~/plugins/my-plugin
```

This opens the human-readable reports in your browser so you can review the results.

```bash
# 5. Open reports
open reports/skill-audits/index.html
npx playwright show-report reports/playwright-html
```

That's it. Your plugin now has a complete quality audit.

**You're done with the quick start when** you can see the skill audits HTML file open in your browser and the Playwright report launches without errors.

> **Q: Do I need to understand all 11 steps before I run the gauntlet?** No. Run it first, read the reports, and then dive into the documentation for any area that surfaces issues. Most developers find it more useful to see real results from their own plugin before reading theory.

---

## Documentation Map

The table below is your navigation guide to the full Orbit documentation. Find the task you want to do in the left column, then follow the link in the right column. You don't need to read every doc — go to the one that matches where you are in the process.

| What you need | Where to go |
|---|---|
| **New here? What is everything?** — plain English explainer for every tool in the diagram | [docs/00-concepts.md](docs/00-concepts.md) |
| **Full installation** — every tool, verification, skill setup | [docs/01-installation.md](docs/01-installation.md) |
| **Configure Orbit** for your plugin — qa.config.json reference | [docs/02-configuration.md](docs/02-configuration.md) |
| **Test environment** — wp-env, Docker, WP-CLI, multisite | [docs/03-test-environment.md](docs/03-test-environment.md) |
| **Gauntlet deep-dive** — all 11 steps explained with examples | [docs/04-gauntlet.md](docs/04-gauntlet.md) |
| **Claude Skills** — all 6 core + 5 add-on skills, what they find | [docs/05-skills.md](docs/05-skills.md) |
| **Writing Playwright tests** — recipes for every plugin type | [docs/writing-tests.md](docs/writing-tests.md) |
| **Test templates** — Elementor, Gutenberg, SEO, WooCommerce, REST | [docs/07-test-templates.md](docs/07-test-templates.md) |
| **Reading reports** — how to interpret every report type | [docs/08-reading-reports.md](docs/08-reading-reports.md) |
| **Multi-plugin workflows** — batch testing, PHP matrix | [docs/09-multi-plugin.md](docs/09-multi-plugin.md) |
| **Real-world QA cases** — 18 edge cases most checklists miss | [docs/real-world-qa.md](docs/real-world-qa.md) |
| **Deep performance** — beyond Lighthouse, editor perf, bundle analysis | [docs/deep-performance.md](docs/deep-performance.md) |
| **Database profiling** — N+1s, slow queries, autoload bloat | [docs/database-profiling.md](docs/database-profiling.md) |
| **Role guides** — Developer, QA, PM, Designer workflows | [docs/13-roles.md](docs/13-roles.md) |
| **Common WP mistakes** — 17 patterns Orbit catches automatically | [docs/common-wp-mistakes.md](docs/common-wp-mistakes.md) |
| **CI/CD integration** — GitHub Actions, automated release gates | [docs/15-ci-cd.md](docs/15-ci-cd.md) |
| **Power tools** — extend Orbit with extra tooling | [docs/power-tools.md](docs/power-tools.md) |

**Recommended reading order for beginners:** Start with [docs/00-concepts.md](docs/00-concepts.md) — it explains every tool in the diagram in plain English. Then `01-installation.md` → `02-configuration.md` → `04-gauntlet.md`. The rest you can read on demand when you need it.

---

## Which Command Do You Need?

Not every situation calls for the full 11-step gauntlet. The commands below let you run only what you need. Use the full gauntlet before every release. Use the quick mode during active development when you want faster feedback.

This runs every check — the right choice before tagging a release or submitting to the WordPress plugin repository.

```bash
# Full pre-release audit (all 11 steps)
bash scripts/gauntlet.sh --plugin /path/to/plugin
```

This skips the heavier steps (7–11) and is faster to run. Good for a sanity check while you're actively writing code.

```bash
# Quick sanity check (skips Steps 7–11)
bash scripts/gauntlet.sh --plugin /path/to/plugin --mode quick
```

If you only want to run the browser-based functional tests without the full gauntlet, use this. `WP_TEST_URL` tells Playwright (the browser testing tool) where your WordPress test site is running.

```bash
# Just Playwright tests
WP_TEST_URL=http://localhost:8881 npx playwright test
```

This runs only the AI skill audits in parallel. Each audit is a separate Claude Code session acting as a specialist — one for security, one for performance, and so on. The `&` at the end of each line means they run simultaneously rather than one after another, which saves time.

```bash
# Just skill audits (6 parallel AI agents)
P=/path/to/plugin
claude "/wordpress-penetration-testing Security audit $P" > reports/skill-audits/security.md &
claude "/performance-engineer Analyze $P" > reports/skill-audits/performance.md &
wait
```

If you maintain multiple plugins, this tests them all at once rather than one by one.

```bash
# Test multiple plugins simultaneously
bash scripts/batch-test.sh --plugins-dir ~/plugins
```

Use this when you want to run browser tests against a staging server instead of your local WordPress environment.

```bash
# Point at staging instead of local
WP_TEST_URL=https://staging.example.com bash scripts/gauntlet.sh --plugin /path/to/plugin
```

---

## Prerequisites at a Glance

Before Orbit can run, these tools need to be installed on your machine. The table below shows what each tool is used for and the minimum version required. Don't worry about installing them manually — `bash setup/install.sh` handles everything automatically. This table is here so you understand what's being installed and why.

| Tool | Required For | Min Version |
|---|---|---|
| Node.js | Playwright, wp-env, npm scripts | 18+ |
| Docker Desktop | wp-env test sites | Latest |
| PHP CLI | PHP lint (Step 1) | 7.4+ |
| Composer | PHPCS, PHPStan | Latest |
| WP-CLI | i18n check (Step 5), DB work | Latest |
| Claude Code CLI | Skill audits (Step 11) | Latest |
| Git | Pulling Orbit | Latest |

To explain each one briefly:
- **Node.js** — the JavaScript runtime that powers Playwright (browser tests) and wp-env (the test WordPress environment)
- **Docker Desktop** — the container system that runs your isolated WordPress test site; think of it as a lightweight virtual machine
- **PHP CLI** — runs PHP directly from your terminal so Orbit can lint and analyze your plugin's PHP code
- **Composer** — PHP's package manager, similar to npm for JavaScript; Orbit uses it to install PHPCS and PHPStan
- **WP-CLI** — a command-line tool for managing WordPress; Orbit uses it to check translation strings and interact with the test database
- **Claude Code CLI** — the AI tool that powers Step 11's skill audits
- **Git** — used to download and update Orbit itself

> **Q: What if I already have some of these installed?** That's fine. `install.sh` will detect existing installations and skip them. It won't overwrite your existing versions.

All installed by `bash setup/install.sh`. See [docs/01-installation.md](docs/01-installation.md) for details.

---

## The 6 Mandatory Claude Skills

Orbit uses **Claude Code skills** — think of them as AI specialists you bring in to review specific aspects of your code. Each skill is a `.md` file that gives Claude Code a specialized role and a set of things to look for. When the gauntlet reaches Step 11, all 6 run in parallel, each one reading your plugin code and producing a structured report.

They always run via `AGENTS.md` which Claude Code reads automatically.

The table below lists all 6 mandatory skills, what each one looks for, and why it matters. After reading this, you'll know exactly what kind of feedback to expect from each audit.

| # | Skill | What it finds |
|---|---|---|
| 1 | `/wordpress-plugin-development` | WP API misuse, escaping gaps, nonce missing |
| 2 | `/wordpress-penetration-testing` | XSS, CSRF, SQLi, auth bypass, path traversal |
| 3 | `/performance-engineer` | Hook weight, N+1s, blocking scripts |
| 4 | `/database-optimizer` | Raw SQL, autoload bloat, missing indexes |
| 5 | `/accessibility-compliance-accessibility-audit` | WCAG 2.2 AA violations |
| 6 | `/code-review-excellence` | Dead code, complexity, error handling |

A few terms worth knowing:
- **XSS (Cross-Site Scripting)** — a security vulnerability where an attacker can inject malicious JavaScript into your plugin's output
- **CSRF (Cross-Site Request Forgery)** — an attack where a malicious site tricks a logged-in user's browser into making unauthorized requests
- **SQLi (SQL Injection)** — a vulnerability where user input can manipulate your database queries
- **N+1 queries** — a performance anti-pattern where your plugin runs one database query per item in a list instead of fetching everything at once
- **Autoload bloat** — when too much data is stored in WordPress options with autoload enabled, slowing down every page load
- **WCAG 2.2 AA** — the internationally recognized accessibility standard that your plugin's UI should meet

**Why does this matter?** Skipping the AI skill audits means you only catch bugs that your tests explicitly check for. The skill audits read your code the way an experienced senior developer would — catching patterns and risks that automated tests don't cover.

Full skill deep-dive: [docs/05-skills.md](docs/05-skills.md)

---

## Severity Triage

After the gauntlet runs, every issue in the reports is tagged with a severity level. The table below tells you exactly what action to take for each level. Use this as your decision-making guide when reviewing results — not every issue blocks a release.

| Level | Action |
|---|---|
| **Critical** | Block release. Fix today. |
| **High** | Block release. Fix in this PR. |
| **Medium** | Fix if < 30 min. Otherwise log in tech debt. |
| **Low / Info** | Log. Defer. |

**Critical** means the issue is a security vulnerability, data loss risk, or something that will break the plugin for users. Do not ship with any Critical issues open.

**High** means something that will significantly impact users or your plugin's reputation — a performance problem that makes the editor slow, or a standards violation that could get your plugin flagged on WordPress.org. Fix it before merging.

**Medium** is the judgment call zone. If you can fix it in under half an hour, do it now. If it requires significant refactoring, log it and come back.

**Low / Info** is background noise — things that are worth knowing but won't hurt your users. Track them in your issue backlog.

> **Q: What if everything comes back as Critical on my first run?** Don't panic. It's normal for an existing plugin to surface a lot of findings the first time. Work through them by severity level, one at a time.

---

## Project Structure

This is a map of every important file and folder in Orbit. You don't need to know all of it on day one — but when you need to find something specific, this is where to look.

```
orbit/
├── GETTING-STARTED.md           ← you are here
├── AGENTS.md                    ← Claude reads this — hard-codes 6 mandatory skills
├── SKILLS.md                    ← skill reference + deduplication guide
├── scripts/
│   ├── gauntlet.sh              ← main entry point — runs all 11 steps
│   ├── batch-test.sh            ← parallel multi-plugin testing
│   ├── create-test-site.sh      ← spins up wp-env + installs plugin
│   ├── db-profile.sh            ← database query profiling
│   ├── editor-perf.sh           ← Elementor/Gutenberg editor load timing
│   ├── competitor-compare.sh    ← side-by-side plugin comparison
│   └── generate-uat-report.py   ← HTML report generator
├── tests/playwright/
│   ├── playwright.config.js     ← 7 test projects
│   ├── auth.setup.js            ← WP admin login → saves cookies
│   ├── helpers.js               ← assertPageReady, gotoAdmin, discoverNavLinks, snapPair
│   └── templates/               ← ready-to-copy test specs
├── config/
│   ├── phpcs.xml                ← WordPress coding standards config
│   └── phpstan.neon             ← PHPStan config
├── setup/install.sh             ← one-command installer
├── checklists/pre-release-checklist.md
├── docs/                        ← all documentation (you are here)
└── qa.config.example.json       ← plugin config template
```

The most important files for a first-time user:
- `scripts/gauntlet.sh` — this is what you run; everything else is called by it
- `setup/install.sh` — run this once to install everything
- `qa.config.example.json` — copy this and fill it in for your plugin (covered in `docs/02-configuration.md`)
- `tests/playwright/templates/` — ready-made test files you can copy and adapt

---

**Next step**: [docs/01-installation.md](docs/01-installation.md) — complete installation guide.
