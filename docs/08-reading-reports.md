# Reading Reports — Complete Guide

> How to interpret every report Orbit generates, what each number means, and exactly what action to take.

---

**New to reading QA reports? Start here.**

After running the Orbit gauntlet, you will have several report files sitting in your `reports/` folder. This guide walks through each one and tells you exactly what the numbers mean, which ones to look at first, and what to do based on what you see.

> **Analogy: The QA report is your plugin's health check report from a doctor.**
> Just like a medical report uses symbols and numbers to tell you which results are normal and which need attention, the Orbit QA report uses symbols (`✓`, `⚠`, `✗`) and severity levels (Critical, High, Medium, Low) to tell you which parts of your plugin are healthy and which need treatment. And just like a doctor's report, not every finding requires emergency surgery — some are just notes for a future checkup.

> **Q: I have 14 Medium findings — should I fix them all before release?**
> Not necessarily. Medium findings are things that should be addressed but are not blockers. The rule of thumb: if you can fix a Medium finding in under 30 minutes, fix it now and include it in this release. If it would take longer, log it in your backlog and defer it to the next sprint. Never let Medium findings prevent a release that has zero Critical and zero High findings.

> **Q: My Playwright test failed but the feature works when I test it manually — why?**
> This is one of the most common beginner questions. The usual causes are: (1) a timing issue — the test clicked a button before the element was fully loaded; (2) a selector that was too broad and matched the wrong element; (3) the test was running with a different screen size or state than your manual test. Open the Playwright trace viewer (explained in Section 4) to rewind to the exact moment of failure and see what the browser actually looked like. Nine times out of ten, the trace makes the cause immediately obvious.

---

## Jargon Buster

Before reading the reports, here are the technical terms you will encounter and what they mean in plain language:

- **Spec file** — a JavaScript file containing tests. Each file is one "spec" (specification). Multiple specs form a test suite.
- **Test suite** — a collection of related tests grouped together, usually for one plugin or one feature area.
- **Assertion** — a check inside a test. `expect(x).toBe(y)` is an assertion. If the assertion fails, the test fails. Assertions are what give tests their value — without them, a test just runs code without verifying anything.
- **Visual regression** — a type of test that detects unintended visual changes by comparing screenshots pixel-by-pixel. If something looks different from the approved baseline, the test fails.
- **Snapshot** — the saved "golden" screenshot used as the reference in visual regression tests. Also called a baseline.
- **Baseline** — the approved state of something (a screenshot, a query count, a performance score) that future runs are compared against. You set a baseline when you first run a test and are satisfied with the result.
- **Trace** — a recording of everything Playwright did during a test: every click, every navigation, every network request, and a DOM snapshot at each step. Invaluable for debugging failed tests.
- **WCAG** (Web Content Accessibility Guidelines) — the international standard for web accessibility. WCAG 2.2 AA is the level Orbit tests against.
- **ARIA** (Accessible Rich Internet Applications) — HTML attributes that provide semantic information to screen readers. Missing ARIA labels are a common accessibility failure.
- **axe-core** — the open-source accessibility scanning library Orbit uses. It automatically checks pages for WCAG violations.
- **Lighthouse score** — a 0–100 score from Google's Lighthouse tool measuring performance, accessibility, best practices, and SEO. Higher is better. 90+ is good, below 75 needs investigation.
- **TBT (Total Blocking Time)** — the total time the browser's main thread was blocked and unable to respond to user input during page load. High TBT makes pages feel sluggish. Under 200ms is good.
- **LCP (Largest Contentful Paint)** — the time until the largest visible element (usually a hero image or heading) appears on screen. This is what users perceive as "when the page loaded." Under 2.5 seconds is good.
- **CLS (Cumulative Layout Shift)** — a measure of how much the page layout shifts unexpectedly as it loads. A button that jumps when an image loads above it causes CLS. Under 0.1 is good.
- **Autoloaded options** — WordPress options stored in the `wp_options` table with `autoload = yes` are loaded into memory on every single page request, even if they are not needed. Large autoloaded options slow down every page on your site.

---

## Table of Contents

1. [Report Overview](#1-report-overview)
2. [Gauntlet Markdown Report](#2-gauntlet-markdown-report)
3. [Skill Audit HTML Report](#3-skill-audit-html-report)
4. [Playwright HTML Report](#4-playwright-html-report)
5. [UAT / PM Video Report](#5-uat--pm-video-report)
6. [Lighthouse JSON Report](#6-lighthouse-json-report)
7. [DB Profile Text Report](#7-db-profile-text-report)
8. [Batch Report](#8-batch-report)
9. [Severity Decision Framework](#9-severity-decision-framework)
10. [Release Sign-off Checklist](#10-release-sign-off-checklist)

---

## 1. Report Overview

After a full gauntlet run, here's where everything lives:

```
reports/
├── qa-report-20240115-143022.md         ← gauntlet summary (all 11 steps)
├── skill-audits/
│   ├── index.html                       ← tabbed HTML — open this first
│   ├── wp-standards.md                  ← raw markdown from skill 1
│   ├── security.md                      ← raw markdown from skill 2
│   ├── performance.md                   ← raw markdown from skill 3
│   ├── database.md                      ← raw markdown from skill 4
│   ├── accessibility.md                 ← raw markdown from skill 5
│   └── code-quality.md                  ← raw markdown from skill 6
├── playwright-html/
│   └── index.html                       ← Playwright test results
├── screenshots/
│   └── flows-compare/
│       ├── pair-01-dashboard-a.png      ← your plugin
│       ├── pair-01-dashboard-b.png      ← competitor
│       └── ...
├── videos/
│   ├── pair-01-dashboard-a.webm
│   └── ...
├── uat-report-20240115-143022.html      ← PM-friendly video + screenshots
├── lighthouse/
│   └── lh-20240115-143022.json         ← Lighthouse raw data
└── db-profile-20240115-143022.txt      ← database query profile
```

The most important report to open first is `reports/skill-audits/index.html`. It gives you the highest-level view of what is wrong and how serious it is. If you have Critical or High findings there, that is where you should focus before looking at anything else.

### Opening everything at once

These three commands open the three most important reports in your browser. Run them after every gauntlet to do your full review:

```bash
open reports/skill-audits/index.html    # AI audit (most important)
npx playwright show-report reports/playwright-html  # functional tests
open reports/uat-report-*.html          # video comparison
```

---

## 2. Gauntlet Markdown Report

**File**: `reports/qa-report-TIMESTAMP.md`
**Open with**: Any markdown viewer or `cat reports/qa-report-*.md`

### Structure

```markdown
# Orbit Gauntlet Report
**Plugin**: my-plugin
**Date**: Mon Jan 15 14:30:22 2024
**Mode**: full / local
**Path**: /Users/you/plugins/my-plugin

---

## Step 1: PHP Lint
- ✓ No PHP syntax errors

## Step 2: PHPCS / WPCS
- ✗ PHPCS: 3 errors, 7 warnings

## Step 6: Playwright
- ✓ Playwright: 18 passed, 0 failed
- HTML report: reports/playwright-html/index.html

...

## Summary
- ✓ Passed: 8
- ⚠ Warnings: 2
- ✗ Failed: 1
```

### How to read it

The gauntlet report is your quick overview — it shows one line per step so you can immediately see which steps passed and which failed. Think of it like the results summary you see at the top of a doctor's report before the detailed findings.

| Symbol | Meaning | Action |
|---|---|---|
| `✓` | Passed | No action needed |
| `⚠` | Warning — passed but has issues | Review, fix if < 30 min |
| `✗` | Failed — blocks release | Fix before releasing |

The table above is your key for reading every symbol in this report. A single `✗` anywhere in the report means the plugin should not be released in its current state. All `✗` failures must be resolved and the gauntlet re-run before tagging a release.

**If any `✗` appears**: Do not release. Fix all failures first.

**What to do next after reading this report:** Scan the Summary section at the bottom. If you see any `✗`, note which steps failed and go open the detailed report for that step. For PHP lint or PHPCS failures, the error messages will be in the log file. For Playwright failures, open the Playwright HTML report (Section 4). For skill audit failures, open the skill audit HTML report (Section 3).

---

## 3. Skill Audit HTML Report

**File**: `reports/skill-audits/index.html`
**Open with**: `open reports/skill-audits/index.html`

This is the most important report. Six tabbed sections, one per skill audit.

> **Analogy: Severity levels are like traffic lights.**
> Critical (red) means stop everything — do not pass go, do not release. High (orange) also blocks release but is less urgent than Critical. Medium (yellow) means proceed with caution — look at it, fix it if quick, log it if not. Low (green) means note it and move on — it's not hurting anyone right now.

### Header

At the top, severity counts across all 6 audits:

```
Orbit Skill Audit Report
Plugin: my-plugin  ·  Generated: 2024-01-15 14:30  ·  6 skills run

[3 Critical] [7 High] [14 Medium] [22 Low]
```

This header is the fastest way to know whether you have a release-blocking situation. If you see any number in the Critical or High boxes, the plugin is not ready to ship.

**Interpretation**:
- Any `Critical` or `High` → block release
- Review every `Critical` today, even if it means delaying

### Reading a finding

Each finding looks like:

```
## XSS via Reflected Input (Critical)

**File**: includes/class-admin.php:47
**Affected**: Admin panel settings page

**Bad**:
    echo '<h2>' . $_GET['message'] . '</h2>';

**Fixed**:
    echo '<h2>' . esc_html( wp_unslash( $_GET['message'] ) ) . '</h2>';

**CVSS**: 6.1 (Medium) — requires victim to visit crafted URL
```

Every finding includes a file path with a line number, a description of what is wrong, the problematic code, and the corrected version. The work is mostly done for you — you just need to apply the fix.

**How to act on it**:
1. Open the file at the line number
2. Apply the fix shown
3. Re-run the gauntlet to verify

### Severity color coding

> **Analogy:** Think of severity like urgency levels at a hospital emergency room. Critical is the patient who needs surgery right now. High is admitted today. Medium is scheduled for a follow-up appointment. Low is "take these vitamins and come back in six months."

| Color | Severity | Action |
|---|---|---|
| 🔴 Red | Critical | Block release. Fix today. |
| 🟠 Orange | High | Block release. Fix in this PR. |
| 🟡 Yellow | Medium | Fix if < 30 min. Log otherwise. |
| 🟢 Green | Low / Info | Log in tech debt. |

The color coding is consistent throughout the skill audit report — every finding's severity badge uses these same colors. If you scan down the page and only see green and yellow, you are in good shape. Red or orange anywhere means stop and fix before moving on.

### Tab by tab: what each skill focuses on

**WP Standards tab**: Escaping, nonces, capability checks, i18n, WP API usage

**Security tab**: Exploitable vulnerabilities — XSS, SQLi, CSRF, auth bypass

**Performance tab**: Hook callbacks, N+1 queries, asset loading, caching gaps

**Database tab**: Prepared statements, indexes, autoload bloat, query patterns

**Accessibility tab**: WCAG 2.2 AA — labels, contrast, keyboard nav, ARIA

**Code Quality tab**: Dead code, complexity, error handling, type safety

Each tab covers a distinct area of concern. For most WordPress plugins, the Security tab and WP Standards tab are the most likely to have Critical or High findings. Check those first. The Accessibility and Code Quality tabs more commonly surface Medium and Low findings.

**What to do next after reading this report:** For each Critical and High finding, open the referenced file and apply the suggested fix. Re-run `orbit gauntlet` after fixing to verify the finding is resolved. For Medium findings, copy them into your issue tracker or tech debt log.

---

## 4. Playwright HTML Report

**File**: `reports/playwright-html/index.html`
**Open with**: `npx playwright show-report reports/playwright-html`

The Playwright report opens in your browser with a full test results view. This is where you go to understand which functional tests passed and which failed, and to debug failures in detail.

### Layout

```
Test Results — 18 passed, 2 failed, 0 skipped
Duration: 45s

✗ FAILED
  ✗ my-plugin › admin panel loads without errors
     Expected "PHP Warning" not to match /PHP Warning/i
     Screenshot: [attachment]
     Trace: [link]

✓ PASSED
  ✓ plugin activates without errors
  ✓ settings save and persist
  ✓ frontend loads without errors
  ...
```

The summary line at the top ("18 passed, 2 failed") is what you look at first. Any number other than zero in the "failed" column needs investigation before release.

### Debugging a failed test

> **Analogy: The Playwright trace viewer is a flight recorder for your test.**
> Just like an airplane's black box records everything that happened during a flight so investigators can reconstruct events, the Playwright trace viewer records every action your test took, every network request it made, and what the browser looked like at each step. When a test fails, you can rewind to exactly the moment it failed and see what the browser was actually showing — which makes debugging much faster than trying to reproduce the issue manually.

1. **Click the failed test** → expands with:
   - Error message (exact assertion that failed)
   - Screenshot at the point of failure
   - Video if running in `video` project
   - Trace file (time-travel debugger)

2. **Open the Trace viewer**:
   - Click "Trace" link in the report
   - Or: `npx playwright show-trace test-results/.../trace.zip`
   - Every action has a DOM snapshot — step through like a debugger

3. **Re-run in debug mode** — this command opens Playwright Inspector, which lets you step through the test line by line and see what the browser is doing at each step:

```bash
npx playwright test tests/playwright/my-plugin/ --debug
# Playwright Inspector opens — step line by line
```

4. **Watch it run** — this command runs the test in a visible browser at slow speed (1 second per action) so you can see exactly what happens:

```bash
npx playwright test tests/playwright/my-plugin/ --headed --slowMo=1000
```

### Reading the timeline

In the Trace viewer:
- Each row is a test action (click, fill, goto, etc.)
- Click any row → see the DOM state at that moment
- "Before" and "After" snapshots for every action
- Network requests tab shows all XHR/fetch

### Screenshot diffs

For visual regression failures:
1. Click the failing snapshot test
2. You'll see 3 panels: **Expected** | **Actual** | **Diff**
3. Pink areas in Diff = what changed

If the change is intentional (you deliberately updated the UI), update the baseline with this command so future tests compare against the new design:

```bash
npx playwright test --update-snapshots
```

**What to do next after reading this report:** For each failed test, click through to the trace and screenshot. Identify whether the failure is a real bug in your plugin or a fragile test that needs updating. If it is a real bug, fix the plugin code. If the test is catching an intentional change, update the snapshot or selector. Re-run the specific failing test (`npx playwright test tests/playwright/my-plugin/core.spec.js`) to verify it passes before running the full suite again.

---

## 5. UAT / PM Video Report

**File**: `reports/uat-report-TIMESTAMP.html`
**Open with**: `open reports/uat-report-*.html`

This report is designed for product managers and clients — no code, just visual proof.

### Structure

```
UAT Report — 2024-01-15
═══════════════════════

PAIR 1 — Dashboard
┌─────────────────────┬─────────────────────┐
│    Our Plugin       │     Competitor      │
│ [screenshot pair]   │  [screenshot pair]  │
│ [video  pair  ]     │  [video  pair  ]    │
└─────────────────────┴─────────────────────┘

PAIR 2 — Meta Templates
[...]
```

### How pairs work

Screenshots are matched by the `PAIR-NN-slug-a/b.png` naming convention:
- `pair-01-dashboard-a.png` always appears next to `pair-01-dashboard-b.png`
- `a` = your plugin (left column)
- `b` = competitor (right column)

Videos auto-rename via `test.afterEach` in the SEO spec template.

### Who this report is for

- **PM / Product**: "Does our plugin look better than the competition?"
- **Founder review**: "Here's the QA evidence before we tag v2.0"
- **Client sign-off**: Visual evidence that features work as expected

This report requires no technical knowledge to read. Share the HTML file directly with anyone who needs to approve a release. The side-by-side layout makes it immediately obvious where your plugin is stronger or weaker than a competitor, without requiring the viewer to install or use either plugin themselves.

**What to do next after reading this report:** Walk through each pair with the product or marketing team. If any pair shows your plugin in an obviously worse state, that is a product gap worth investigating. If the report is being used for a release review, all pairs should show your plugin working correctly (no error messages, no blank screens, complete UI) before signing off.

---

## 6. Lighthouse JSON Report

**File**: `reports/lighthouse/lh-TIMESTAMP.json`
**Open with**: Parse with Python or use the Lighthouse viewer

Lighthouse is Google's tool for measuring web performance, accessibility, best practices, and SEO. The scores are 0–100, where higher is better. These scores directly affect how Google ranks your plugin's demo pages and how fast real users perceive your plugin.

### Key fields

```json
{
  "categories": {
    "performance": { "score": 0.82 },      // 82/100
    "accessibility": { "score": 0.94 },
    "best-practices": { "score": 0.88 },
    "seo": { "score": 0.91 }
  },
  "audits": {
    "first-contentful-paint": { "numericValue": 1240 },   // 1.24s
    "largest-contentful-paint": { "numericValue": 2100 }, // 2.1s
    "total-blocking-time": { "numericValue": 340 },       // 340ms
    "cumulative-layout-shift": { "numericValue": 0.02 },
    "speed-index": { "numericValue": 1800 }
  }
}
```

The scores are stored as decimals (0.82 = 82/100). The individual audit values are in milliseconds for time-based metrics. LCP of 2100ms means the largest element appeared in 2.1 seconds — that is within the acceptable range (under 2.5s is good, under 4s is acceptable). TBT of 340ms is borderline — the target is under 200ms for a good score.

### Reading scores

| Score | Rating |
|---|---|
| 90–100 | 🟢 Good |
| 75–89 | 🟡 Needs improvement |
| < 75 | 🔴 Poor — investigate |

A Performance score below 75 means the plugin is noticeably slowing down the page it is installed on. This is the range where users start complaining about slowness. A score below 60 triggers a gauntlet failure.

### Gauntlet thresholds

| Metric | Default threshold | Action if below |
|---|---|---|
| Performance | 75 | Warn in gauntlet |
| Performance | 60 | Fail in gauntlet |
| Accessibility | 85 | Warn in gauntlet |

These thresholds are what the gauntlet uses to decide whether to pass or warn. You can adjust them in the gauntlet configuration, but the defaults reflect reasonable minimums for a production WordPress plugin.

### Extracting score quickly

When you just want to see the numbers without opening a JSON viewer, this command parses the JSON file and prints the four category scores:

```bash
python3 -c "
import json
with open('$(ls reports/lighthouse/lh-*.json | tail -1)') as f:
    d = json.load(f)
for cat, data in d['categories'].items():
    print(f'{cat}: {int(data[\"score\"]*100)}/100')
"
```

### Visualizing the report

For a full visual Lighthouse report with explanations of every metric, use this command to convert the raw JSON to a human-readable HTML report:

```bash
# Convert JSON to HTML and open in browser
lighthouse --output=html \
  --output-path=reports/lighthouse/report.html \
  --config-path=reports/lighthouse/lh-latest.json

open reports/lighthouse/report.html
```

**What to do next after reading this report:** If Performance is below 75, look at the "Opportunities" and "Diagnostics" sections in the HTML report. They list specific issues like "render-blocking resources" or "unused JavaScript" with estimated savings. The highest-impact fixes are shown first. Common plugin-related causes include loading scripts on pages where they are not needed, or loading large JavaScript bundles that are not code-split.

---

## 7. DB Profile Text Report

**File**: `reports/db-profile-TIMESTAMP.txt`
**Open with**: `cat reports/db-profile-*.txt`

The database profile shows how many SQL queries each page is making and how long they take. WordPress runs queries every time it loads a page, and each plugin can add more. Too many queries slow down every page load for every visitor.

> **Analogy: The DB profile is a receipt showing how many database queries each page made.**
> Imagine you go to a restaurant and your receipt has 50 line items for a single hamburger — one charge for the bun, one for each sesame seed, one for the patty, one for each milliliter of ketchup. That is the database equivalent of a WordPress page that runs 50 queries when it should run 10. Each query takes time, and they add up. A well-optimized plugin is like a restaurant that puts everything on one line: "Hamburger — $12."

### Structure

```
=== Orbit DB Profile — 2024-01-15 14:30 ===
Plugin: my-plugin
WP URL: http://localhost:8881

--- Homepage ---
Queries: 28
Time:    142ms
---

--- Single Post ---
Queries: 24
Time:    118ms
---

--- Admin Panel ---
Queries: 67        ← WARNING: > 50
Time:    289ms
---

--- Slow Queries (>50ms) ---
[None found]
---

--- Autoloaded Options (top 10 by size) ---
option_name             | size
my_plugin_settings      | 2.1KB
my_plugin_cache         | 48.3KB  ← WARNING: should not be autoloaded
```

### Interpreting query counts

| Page | Acceptable | Warning | Bad |
|---|---|---|---|
| Homepage | < 30 | 30–60 | > 60 |
| Single post/page | < 25 | 25–50 | > 50 |
| Archive | < 40 | 40–80 | > 80 |
| Admin panel | < 50 | 50–100 | > 100 |

The table above gives you the benchmarks for judging whether your query counts are healthy. These are not arbitrary numbers — they reflect the typical baseline WordPress queries plus a reasonable budget for plugins to add on top. If your plugin alone is pushing counts into the warning range, that is a sign of inefficient data fetching.

### What to fix

**High query count** → Look for N+1 patterns. See [docs/database-profiling.md](database-profiling.md).

An N+1 pattern is when you run one query to get a list of items, then run one more query for each item in the list. For example: one query to get all posts, then one query per post to get the post's meta. The fix is to use a single query that fetches all the meta at once.

**Slow queries** → Add indexes or rewrite the query. See examples in [docs/database-profiling.md](database-profiling.md).

**Large autoloaded options** → Add `false` as third parameter to `update_option()` for large data.

A large autoloaded option is a performance tax on every single page load across the entire site, even pages that have nothing to do with your plugin. The `my_plugin_cache` entry in the example above (48.3KB) should definitely not be autoloaded — cache data has no reason to be loaded on every request.

### Compare before/after

When you have made changes to fix a performance issue, use this workflow to measure the improvement. The `diff` command at the end shows you exactly which query counts changed:

```bash
# Baseline (before your change)
bash scripts/db-profile.sh
cp reports/db-profile-*.txt reports/db-before.txt

# After your change
bash scripts/db-profile.sh
cp reports/db-profile-*.txt reports/db-after.txt

# Diff
diff reports/db-before.txt reports/db-after.txt
```

**What to do next after reading this report:** If any page's query count is in the Warning or Bad range, investigate that page's code path. Add `define('SAVEQUERIES', true)` to `wp-config.php`, visit the page, then check `$wpdb->queries` to see the full list of queries and where they are called from. Fix the most expensive queries first — slow queries and N+1 patterns have the biggest impact.

---

## 8. Batch Report

**File**: `reports/batch-TIMESTAMP.md`
**Open with**: Any markdown viewer

When running `batch-test.sh`, each plugin gets a row. This report is useful when you are maintaining multiple plugins and want a single view of which ones are healthy and which need attention.

```markdown
# Orbit Batch Report
Date: 2024-01-15
Plugins: 4
Concurrency: 2

| Plugin | Status | Pass | Warn | Fail | Log |
|---|---|---|---|---|---|
| my-plugin-free | ✓ | 9 | 2 | 0 | [log](batch-logs/my-plugin-free-20240115.log) |
| my-plugin-pro | ✗ | 7 | 3 | 2 | [log](batch-logs/my-plugin-pro-20240115.log) |
| other-plugin | ✓ | 11 | 0 | 0 | [log](batch-logs/other-plugin-20240115.log) |
| legacy-plugin | ⚠ | 6 | 5 | 0 | [log](batch-logs/legacy-plugin-20240115.log) |
```

### Interpreting batch results

| Status | Meaning |
|---|---|
| `✓` | Gauntlet passed |
| `⚠` | Passed with warnings — review the log |
| `✗` | Failed — open log file to see which step |

The batch report table gives you a birds-eye view. In the example above, `my-plugin-pro` has 2 failures and needs immediate attention. `legacy-plugin` has 5 warnings — it passed, but those warnings should be scheduled for cleanup. `other-plugin` is the healthiest, with zero warnings.

For any plugin with `✗` status, click the log link (or run the command below) to see the full gauntlet output and identify which specific step failed.

### Viewing a specific plugin's log

This command shows the complete gauntlet output for one plugin, so you can read through it the same way you would read a single-plugin gauntlet report:

```bash
cat reports/batch-logs/my-plugin-pro-20240115.log
# Shows full gauntlet output for just that plugin
```

**What to do next after reading this report:** Any plugin with `✗` status should have a ticket created and assigned to a developer. Any plugin with `⚠` status should have its warnings reviewed in the next sprint. Plugins with `✓` and zero warnings are ready to release.

---

## 9. Severity Decision Framework

Use this decision tree for every skill audit finding. When you are not sure what to do with a particular finding, walk through this tree from the top:

```
Finding received
      │
      ▼
Is it Critical or High?
      │
    YES ──────────────→ Block release. Fix now.
      │                 File a bug. Assign to developer.
      │
      NO
      │
      ▼
Is it Medium?
      │
    YES ──────────────→ Can it be fixed in < 30 min?
      │                       │
      │                     YES → Fix now, include in this release
      │                       │
      │                      NO → Log in backlog. Defer to next sprint.
      │
      NO
      │
      ▼
Low / Info
      │
      └──────────────→ Log in tech debt list. Defer.
                        Don't block the release.
```

### Critical examples (always block)

These are examples of findings that are always release-blocking, regardless of how unlikely they seem to be exploited:

- SQL injection anywhere
- XSS in admin or frontend with no auth required
- REST endpoint exposing private data without auth
- PHP file upload with no MIME validation
- Hardcoded credentials or API keys in source

### High examples (block release)

- CSRF on any state-changing form
- Missing nonce on AJAX handlers that modify data
- Capability check missing on admin actions
- Stored XSS that requires admin to trigger
- Memory usage growth that crashes after 20 widgets

### Medium examples (fix if quick)

- Unnecessary asset loading on every page
- Missing `alt` text on admin UI images
- Autoloaded option that's > 10KB
- Missing `is_wp_error()` check (could cause cryptic failures)
- Cyclomatic complexity > 15 (hard to test)

### Low examples (log and defer)

- Function/class naming improvement
- Missing docblock on a private method
- Unused import/variable
- Minor spacing inconsistency in output HTML

---

## 10. Release Sign-off Checklist

After reviewing all reports, walk through this list before tagging a release. Every box must be checked. If any box cannot be checked, identify what needs to be fixed and re-run the relevant report after fixing.

```
GAUNTLET
[ ] Gauntlet exit code: 0
[ ] Zero ✗ failures in qa-report-*.md
[ ] All warnings reviewed and accepted or fixed

SKILL AUDITS (reports/skill-audits/index.html)
[ ] Zero Critical findings
[ ] Zero High findings
[ ] Medium findings logged in backlog
[ ] Security tab: no XSS, CSRF, SQLi, auth bypass

PLAYWRIGHT (reports/playwright-html)
[ ] Zero failed tests
[ ] Visual snapshots reviewed for regressions
[ ] Accessibility tests passing

PERFORMANCE (reports/lighthouse/)
[ ] Performance score ≥ 75
[ ] No render-blocking resources flagged

DATABASE (reports/db-profile-*.txt)
[ ] Query count per page within thresholds
[ ] No slow queries > 100ms
[ ] No large autoloaded options

PRE-RELEASE CHECKLIST
[ ] Version bumped in plugin header
[ ] Version bumped in readme.txt
[ ] CHANGELOG updated
[ ] Tested on: PHP 7.4, 8.0, 8.1, 8.2
[ ] Tested on: Latest WP and WP-1
[ ] Tested with conflict plugins active
```

When all boxes are checked → tag the release.

If you get to release day and find a Critical finding you missed, or a Playwright test that started failing without explanation, do not rush to ship. The gauntlet exists to protect users from plugins that break their sites. A delayed release is recoverable. A plugin that causes data loss or security vulnerabilities on thousands of sites is not.

---

**Next**: [docs/09-multi-plugin.md](09-multi-plugin.md) — testing multiple plugins at once.
