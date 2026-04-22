# Changelog

All notable changes to Orbit follow [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format.

---

## [Unreleased]

---

## [2.4.0] — 2026-04-22 — "PM UX Quality"

Three new PM-perspective checks that close the gap between "does it work" and "does it feel right." All checks are **warn severity** — PMs decide, never hard-blocks.

### Added
- **`tests/playwright/pm/spell-check.spec.js`** — crawls every plugin admin page, extracts all visible UI text (labels, buttons, tooltips, notices, headings, placeholders), checks against a 60-entry built-in typo dictionary, optionally deepens with `cspell`. Output: `reports/pm-ux/spell-check-findings.json`.
- **`tests/playwright/pm/guided-ux.spec.js`** — scores the plugin's onboarding quality 0–10 across 7 signals (wizard, welcome screen, tooltips, inline help, placeholder text, empty-state messaging, help tab). Benchmarks against Yoast SEO (8/10), RankMath (9/10), WooCommerce (8/10), WPForms (9/10), Gravity Forms (8/10), Jetpack (7/10), AIOSEO (8/10). Output: `reports/pm-ux/guided-ux-score.json`.
- **`tests/playwright/pm/label-audit.spec.js`** — flags 9 anti-pattern classes (vague buttons, double negatives, WP jargon, ambiguous toggles, inconsistent save labels, ALL CAPS abuse, etc.), benchmarks terminology against `config/pm-ux/competitor-terms.json`, and checks logical ordering of select/radio option groups. Output: `reports/pm-ux/label-audit-findings.json`.
- **`config/pm-ux/competitor-terms.json`** — 10-competitor UI terminology database (Yoast SEO, RankMath, Elementor, WooCommerce, WPForms, Gravity Forms, MonsterInsights, Jetpack, ContactForm7, AIOSEO). Covers nav labels, button labels, field labels, error messages, toggle labels, section headings. Each entry lists the industry-standard term, which competitors use it, and the anti-patterns to avoid.
- **`config/pm-ux/cspell.json`** — cspell configuration with WP-ecosystem allowlist (wordpress, elementor, gutenberg, nonce, transient, wpdb, and 30+ plugin-specific terms).
- **`scripts/pm-ux-audit.sh`** — orchestrates all 3 Playwright PM specs, reads JSON outputs, prints a summary, generates the HTML report. Usage: `bash scripts/pm-ux-audit.sh [--url http://localhost:8881] [--slug plugin-slug]`.
- **`scripts/generate-pm-ux-report.py`** — Python HTML report generator, consistent with the existing `generate-uat-report.py` pattern. Three sections (spell-check, guided UX, label audit), color-coded summary cards, competitor comparison table.
- **Gauntlet Step 12** — `scripts/gauntlet.sh` now runs the PM UX Audit as Step 12 in `full` + `local` mode. Exits 0 (issues are PM-flagged warnings, not CI failures).
- **`VISION.md`** updated with PM UX Quality row in the coverage matrix.

---

## [2.3.0] — 2026-04-21 — "Unique Layer"

First two capabilities nobody else ships. Both are **free forever** — uses NVD + WPScan public feeds, no API keys, no paid tier.

### Added
- **`scripts/check-ownership-transfer.sh`** — reads plugin main-file git history, flags when Author / Author URI / Plugin Name headers change between commits. Defends against the April 2026 EssentialPlugin attack vector (attacker buys plugin → pushes backdoored update weeks later). First static detection in the WP ecosystem.
- **`scripts/check-live-cve.sh`** — pulls NVD (NIST National Vulnerability Database) + WPScan public feeds for last 60 days of WordPress CVEs, correlates against plugin code. Caches 24h. Optional `WPSCAN_API_TOKEN` for higher-rate auth. Turns Orbit from release-time tool into continuous security posture tool.
- Both scripts wired into gauntlet release mode (`--mode full|release`).

### Verified
- `check-live-cve.sh` self-tested: 100 recent WP CVEs ingested, correctly correlated 5 deliberate vulns in test plugin (XSS, SQLi, nopriv AJAX, unserialize, missing nonce) with real CVE matches.
- `check-ownership-transfer.sh` self-tested: correctly skipped on non-plugin repos, flags Author/URI/Name header drift across git history.

---

## [2.2.0] — 2026-04-21 — "Mature Release"

The release where Orbit closes every deep-research gap. Covers WP.org
plugin-check canonical rules, Patchstack 2025 top-5 vuln classes, WP 6.5→7.0
features, PHP 8.0→8.5 compatibility, and the April 2026 EssentialPlugin
supply-chain attack patterns.

### Added — Foundation
- `VISION.md` — anchor doc with 6 perspectives (Dev/QA/PM/PA/Designer/End User), 7 smart principles, evergreen research loop
- `docs/22-what-orbit-does.md` — shareable overview
- `docs/21-evergreen-security.md` — living attack-pattern log, 90-day research cadence (SHIPPED / RESEARCHING / WATCHING)
- `docs/20-auto-test-generation.md` — how Orbit reads plugin code
- `docs/19-business-logic-guide.md` — plugin-specific testing on top of Orbit
- `docs/18-release-checklist.md` — complete pre-tag gate for all 6 roles
- `docs/17-whats-new.md` — v2 demo doc
- `docs/16-master-audit.md` — master audit + antigravity skill mappings
- `.github/workflows/ci.yml` — lean self-validation workflow + brand-leakage enforcement
- `.githooks/pre-commit` + `install-pre-commit-hook.sh`

### Added — Release gate checks (9 new scripts)
- `check-plugin-header.sh` · `check-readme-txt.sh` · `check-version-parity.sh`
- `check-license.sh` · `check-block-json.sh` · `check-hpos-declaration.sh`
- `check-wp-compat.sh` — WP function version gate against declared "Requires at least"
- `check-php-compat.sh` — PHP 8.0-8.5: removed functions, implicit nullable, property hooks, `array_find` family, `mb_trim`, E_STRICT removal
- `check-modern-wp.sh` — Script Modules, Interactivity API, Plugin Dependencies, Site Health, Block Bindings, custom updater detection, external menu links

### Added — Dev workflow
- `scaffold-tests.sh` — reads plugin code, generates `qa.config.json` + 40-80 scenarios + draft spec
- `gauntlet-dry-run.sh` · `generate-reports-index.py`
- `/orbit-scaffold-tests` custom skill — AI-augmented scenario writer (via `--deep`)

### Added — Playwright projects (14 new specs)
- UX states: `empty-states` · `error-states` · `loading-states` · `form-validation`
- Lifecycle: `uninstall-cleanup` · `update-path` · `block-deprecation`
- Accessibility: `keyboard-nav` · `admin-color-schemes` · `rtl-layout`
- Network: `multisite-activation` · `app-passwords`
- Modern: `wp7-connectors` · `plugin-conflict` (top-20 matrix)
- PM/PA: `user-journey` · `onboarding-ftue` · `analytics-events`
- Visual: `visual-regression-release` (diff vs previous git tag)
- Performance: `bundle-size` (per-page JS/CSS enforcement)
- Cross-browser projects: `firefox` · `webkit`

### Added — Custom Claude skills (4 WP-native)
- `/orbit-wp-security` — **22 vulnerability patterns** (+5 for April 2026):
  - #18 `unserialize()` on HTTP responses (EssentialPlugin attack)
  - #19 `permission_callback => __return_true` on sensitive routes
  - #20 `register_setting()` missing `sanitize_callback`
  - #21 callable property injection gadget chain
  - #22 external admin menu URLs
- `/orbit-wp-performance` — 14 patterns (+script loading strategy, Script Modules dynamic deps, block metadata bulk registration, per-page CSS weight)
- `/orbit-wp-database` — `$wpdb`, dbDelta, autoload, uninstall cleanup
- `/orbit-wp-standards` — review-mode WP coding standards
- `deep-research` skill — rewritten Claude-native (WebSearch + WebFetch)

### Changed
- Replaced 4 mismatched community skills in AGENTS.md:
  - `/wordpress-penetration-testing` (attacker tool) → `/security-auditor` + `/security-scanning-security-sast`
  - `/performance-engineer` (cloud infra) → `/orbit-wp-performance` + `/web-performance-optimization`
  - `/database-optimizer` (enterprise DBA) → `/orbit-wp-database`
  - `/wordpress-plugin-development` (scaffolder) → `/orbit-wp-standards`
- Gauntlet Step 11: per-PID `wait` loop + per-skill `.err` file (was silent failure on Claude CLI errors)
- `check-zip-hygiene.sh` expanded: AI dev dirs (`.cursor`, `.aider`, `.continue`, `.claude`, `.windsurf`, `.codex`, `.fleet`, `.zed`, `.github/copilot-*`), OS artifacts, editor backups, obfuscation (hex + `chr()` chains), `ALLOW_UNFILTERED_UPLOADS`
- Gauntlet: new release gate wiring for all 9 release-metadata checks

### Removed
- `.github/workflows/gauntlet.yml` — overbuilt for the framework repo itself; full gauntlet workflow now lives as a copy-paste template in `docs/15-ci-cd.md` for users' plugin repos

### Fixed (identified by 3-agent review + self-testing)
- Orphaned `/orbit-wp-security` skill — AGENTS.md referenced it, gauntlet.sh invoked `/security-auditor` instead
- `wait $P1 $P2 ...` returning only last PID's status → multiple failures reported as success
- `2>/dev/null` swallowing Claude CLI errors
- `check-translation.sh` / `check-object-cache.sh` / `check-zip-hygiene.sh` — empty-var arithmetic crash under `set -e` (`grep -c \|\| echo 0` producing `"0\n0"`)
- `uninstall-cleanup.spec.js` — wp-cli `--search` uses `*` glob, not `%` SQL wildcard (was: test always passed)
- `keyboard-nav.spec.js` — focus-indicator check always-true no-op (`style.border !== 'none'`)
- `plugin-conflict.spec.js` — debug.log path was host path; fixed to use `WP_CONTENT_DIR` inside container
- `wp7-connectors.spec.js` — rewritten against real WP 7.0 API (`WP_Ability` class + `abilities_api_init` + `wp_execute_ability`) — previous version invented fake functions and always skipped (false green)
- `scaffold-tests.sh` — same `grep -c` anti-pattern + Python boolean heredoc fixes
- `base64_decode` / `base64_encode` moved from hard-fail to WARN (WP core uses these legitimately)
- `deep-research` skill — no longer requires external Gemini API / Python dependency

### Security
- **Evergreen research loop established.** `docs/21-evergreen-security.md` is the living record. Next quarterly pass: July 2026.

---

## [2.1.0] — 2026-04-20

### Fixed (Critical — brand content in public repo)
- `setup/playground-blueprint.json` — replaced "POSIMYTH QA Test Site" with "Orbit QA Test Site" (C-01)
- `checklists/pre-release-checklist.md` — removed product-specific brand names; checklist is now generic for any WordPress plugin (C-02)
- `checklists/ui-ux-checklist.md` — removed "TPA" and "NexterWP" section headings; sections are now generic Elementor / Gutenberg (C-02)
- `scripts/gauntlet.sh` — removed hardcoded `NEXTER-VS-RANKMATH-UAT.html` reference; output now globs any `uat-report-*.html` (C-04)

### Fixed (High priority)
- `scripts/generate-uat-report.py` — `FLOW_DATA`, `RICE`, and `FEATURES` are now empty by default; all plugin-specific PM data must be supplied via the new `--flow-data <file.json>` argument (C-03 / H)
- `package.json` — replaced macOS-only `open` in `npm run uat` with cross-platform `npx open-cli` (H-01)
- `scripts/generate-uat-report.py` — `scan_pairs()` regex fixed from `(?:-\w+)?` to `(?:-[\w-]+)?` so extras with hyphens (e.g. `pair-01-dashboard-a-scroll-down.png`) are matched correctly (H-03)
- `tests/playwright/helpers.js` — `gotoAdmin()` now uses `waitForLoadState('networkidle')` + 800ms buffer instead of a fixed 2500ms `waitForTimeout` (H-04)
- `tests/playwright/helpers.js` — moved `require('path')` and `require('fs')` from mid-file to the top of the module (H-07)

### Removed
- `scripts/generate-uat-report.sh` — redundant shell wrapper around the Python script; use `python3 scripts/generate-uat-report.py` directly or `npm run uat` (H-06)

### Added
- `qa.config.example.json` — documented config schema with comments; copy to `qa.config.json` (gitignored) and fill in your plugin details (H-02)
- `setup/plugins/plugin-example.setup.json` — template for per-plugin setup files used by `setup/plugin-setup.js`
- `scripts/generate-uat-report.py --flow-data` — new CLI argument pointing to a JSON file containing `FLOW_DATA`, `RICE`, `FEATURES`, and `IA_RECS` for a specific plugin comparison

---

## [2.0.0] — 2026-04-19

### Added
- **PAIR-NN-slug-a/b naming convention** — screenshots and videos are now named `pair-NN-{slug}-{a|b}[-extra].{ext}`. The slug is the pairing key, not the index. Eliminates the index-mismatch bug where Social was shown beside Titles in the UAT report.
- `snapPair(page, pairNum, slug, side, snapDir, extra)` helper in `helpers.js` — enforces the naming contract at capture time.
- `scan_pairs()` in `generate-uat-report.py` — pairs screenshots/videos by slug instead of sequential index. Replaces the old `grp()` function.
- `afterEach` video auto-renaming hook in `tests/playwright/templates/seo-plugin/core.spec.js` — parses test title format `"PAIR-N | slug | a|b | Description"` and copies Playwright's auto-generated video to the correct `pair-NN-slug-a/b.webm` name.
- `--label-a` / `--label-b` CLI args for `generate-uat-report.py` — plugin display names are now configurable from the command line.
- `scripts/gauntlet.sh` Step 6b — auto-detects `tests/playwright/flows/*.spec.js` and runs them with `--project=video`, then calls `generate-uat-report.py`.
- `npm run uat` and `npm run uat:ci` scripts in `package.json`.
- Deep PM HTML report (`generate-uat-report.py`) with per-flow analysis, RICE backlog, IA navigation recommendations, and feature comparison table.

### Changed
- `generate-uat-report.py` rewritten to use `scan_pairs()` slug-based matching.
- `core.spec.js` template rewritten with full PAIR structure and video auto-renaming.

---

## [1.0.0] — 2026-04-17

### Added
- Initial Orbit framework: `gauntlet.sh`, Playwright setup, `helpers.js`, checklists, report generator.
