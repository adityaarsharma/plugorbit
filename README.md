# WordPress QA Master

> Automated QA pipeline for WordPress plugins — code quality, database profiling, performance, functional testing, visual regression, and UI/UX checks. Built for serious plugin teams.

**Covers**: The Plus Addons for Elementor · NexterWP Theme + Blocks + Extension · Any WordPress plugin

---

## What This Covers

| Layer | What It Checks | Tools |
|---|---|---|
| **Code Quality** | PHP syntax, WPCS, VIP standards, PHPStan | phpcs, phpstan, php -l |
| **Security** | XSS, CSRF, SQLi, capability checks, SSRF | phpcs + security sniffs |
| **Database** | Query count, slow queries, N+1s, autoload bloat | Query Monitor, MySQL slow log |
| **Performance** | LCP, FCP, TBT, CLS, TTI, asset weight | Lighthouse CLI, bundle analysis |
| **Functional** | Widget renders, admin panel, editor, REST API | Playwright |
| **Visual Regression** | Pixel diff between releases | Playwright screenshots |
| **UI/UX** | Border radius, hit areas, animations, typography | Checklist + Playwright |
| **Responsive** | Mobile, tablet, desktop rendering | Playwright viewport tests |
| **Accessibility** | WCAG 2.1 AA, keyboard nav, screen reader | axe-core + Playwright |

---

## Quick Start (1-Click Install)

```bash
curl -fsSL https://raw.githubusercontent.com/adityaarsharma/wordpress-qa-master/main/setup/install.sh | bash
```

Or clone and run:

```bash
git clone https://github.com/adityaarsharma/wordpress-qa-master
cd wordpress-qa-master
bash setup/install.sh
```

---

## Two Environments

### Local Testing — Full Power (Local WP)
Full MySQL database, real PHP, snapshot/restore, Query Monitor profiling.
→ See [Local WP Setup Guide](docs/local-wp-setup.md)

### CI Testing — Every PR (GitHub Actions + WP Playground)
Zero-config, runs in GitHub Actions on every push. Uses WordPress Playground (WebAssembly).
→ See [`.github/workflows/qa-full.yml`](.github/workflows/qa-full.yml)

---

## Running the Full Gauntlet

```bash
# Full pre-release gauntlet (run before every release)
bash scripts/gauntlet.sh --plugin /path/to/your-plugin --env local

# Quick check (PR-level, skips DB profiling)
bash scripts/gauntlet.sh --plugin /path/to/your-plugin --mode quick

# Compare two versions
bash scripts/compare-versions.sh --old plugin-v1.zip --new plugin-v2.zip
```

---

## Plugin-Specific Test Suites

### The Plus Addons for Elementor
```bash
npx playwright test tests/playwright/tpa/ --reporter=html
```

### NexterWP (Theme + Blocks + Extension)
```bash
npx playwright test tests/playwright/nexterwp/ --reporter=html
```

### All plugins
```bash
npx playwright test --reporter=html
```

---

## Report Output

Every gauntlet run produces `reports/qa-report-{timestamp}.md`:

```
POSIMYTH QA Report — The Plus Addons v2.x vs v2.y
===================================================
PHP Errors:         0 / 0          ✓
PHPCS Warnings:     12 → 9         ✓ improved
JS Bundle Size:     1.2MB → 1.4MB  ⚠ +200KB, review
DB Queries/page:    43 → 67        ✗ REGRESSION
Lighthouse Score:   84 → 81        ⚠ dropped 3pts
Playwright Tests:   48/48 → 47/48  ✗ 1 FAILING
Visual Diffs:       0 → 2          ⚠ review needed
UI/UX Checks:       14/14 → 14/14  ✓
```

---

## Checklists

- [Pre-Release Checklist](checklists/pre-release-checklist.md)
- [UI/UX Checklist](checklists/ui-ux-checklist.md)
- [Performance Checklist](checklists/performance-checklist.md)
- [Security Checklist](checklists/security-checklist.md)

---

## Folder Structure

```
wordpress-qa-master/
├── setup/
│   ├── install.sh              # 1-click dependency installer
│   └── local-wp-guide.md       # Local WP site setup
├── tests/
│   ├── playwright/
│   │   ├── playwright.config.js
│   │   ├── tpa/                # The Plus Addons tests
│   │   └── nexterwp/           # NexterWP tests
│   └── phpunit/
│       └── bootstrap.php
├── config/
│   ├── phpcs.xml               # PHPCS with WPCS + VIP standards
│   ├── phpstan.neon
│   └── lighthouserc.json
├── scripts/
│   ├── gauntlet.sh             # Full pre-release pipeline
│   ├── compare-versions.sh     # Version A vs B comparison
│   └── db-profile.sh          # Database query profiler
├── .github/workflows/
│   ├── qa-full.yml             # Full QA on release branch
│   └── qa-quick.yml            # Quick check on every PR
├── checklists/
│   ├── pre-release-checklist.md
│   ├── ui-ux-checklist.md
│   ├── performance-checklist.md
│   └── security-checklist.md
└── docs/
    ├── local-wp-setup.md
    └── database-profiling.md
```

---

## Standards This Follows

- [WordPress Coding Standards](https://github.com/WordPress/WordPress-Coding-Standards)
- [WordPress VIP Coding Standards](https://github.com/Automattic/VIP-Coding-Standards)
- [10up Open Source Best Practices](https://10up.github.io/Open-Source-Best-Practices/testing/)
- [WordPress Playground E2E Testing](https://wordpress.github.io/wordpress-playground/guides/e2e-testing-with-playwright/)
- [make-interfaces-feel-better UI principles](https://skills.sh/jakubkrehel/make-interfaces-feel-better/make-interfaces-feel-better)

---

## Claude Code Integration

This repo is designed to run with Claude Code + MCP tools:

```bash
# Claude can run the full gauntlet autonomously
# with Playwright MCP, DB access, and parallel audit agents
claude --allowedTools "Bash,Read,Write,mcp__playwright__*" \
  "Run full QA gauntlet on /path/to/plugin"
```

---

## Coverage Targets

| Metric | Minimum | Target |
|---|---|---|
| PHP unit test coverage | 60% | 80% |
| E2E feature coverage | 80% | 95% |
| Lighthouse performance | 75 | 85+ |
| PHPCS errors | 0 | 0 |
| Security findings (high/critical) | 0 | 0 |
