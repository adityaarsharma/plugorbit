# Role-Based Guide

> Your job in Orbit depends on your role. This guide tells each person exactly what to run, what to read, and what to decide.

---

**You are here:** This guide is for teams (or solo developers wearing multiple hats) who want to understand who does what in the Orbit QA process. If you are a solo developer, read all four role sections — you will be doing all of them yourself, and understanding the distinctions will help you prioritize what matters most at each stage of a release. If you are part of a team, jump to your role section and focus there.

---

## Table of Contents

1. [Developer](#1-developer)
2. [QA Engineer](#2-qa-engineer)
3. [Product Manager](#3-product-manager)
4. [Designer / UI Review](#4-designer--ui-review)
5. [Team Workflow: Pre-Release Sequence](#5-team-workflow-pre-release-sequence)

---

## Why each role reads different reports

A PM does not need to know what PHPStan is. A developer does not need to watch UAT videos frame by frame. But a PM absolutely needs to know if there is a SQL injection vulnerability before approving a release — even if they do not know what SQL injection means technically, they need to know its consequence (an attacker could wipe the user's database). This guide gives each role exactly the information they need, filtered to what is actionable for them.

---

## 1. Developer

You own: writing code, fixing issues, running the gauntlet during development, interpreting skill audit findings.

### Daily workflow

These commands represent the standard development loop. Run the test site once at the start of your session, then iterate: write code, run a quick check, fix failures, repeat. Before you commit anything, do a full run.

```bash
# 1. Start your test site (once per session)
bash scripts/create-test-site.sh --plugin ~/plugins/my-plugin --port 8881

# 2. Write/modify code
# ...

# 3. Quick sanity check (Steps 1–6, < 2 min)
bash scripts/gauntlet.sh --plugin ~/plugins/my-plugin --mode quick

# 4. Fix failures, repeat

# 5. Before committing — full run
bash scripts/gauntlet.sh --plugin ~/plugins/my-plugin
```

### Pre-release workflow

Before handing off to QA, run the full gauntlet and open the skill audit HTML report. Fix everything rated Critical or High — these are blockers. Medium and below can be logged and deferred.

```bash
# Full gauntlet
bash scripts/gauntlet.sh --plugin ~/plugins/my-plugin

# Review skill audit findings
open reports/skill-audits/index.html
# Fix all Critical and High findings

# Verify PHP compatibility
# (run PHP matrix if you changed any PHP patterns)

# Sign off
# → All passing → tag the release
```

### Interpreting skill audits

Always check the Security tab first. A Critical security finding is not something you can ship around — it needs to be fixed. Then check WP Standards (which catches issues that will trigger WordPress.org review rejections), then Performance.

The table below tells you exactly what to do with each type of finding. "Low/Info" findings do not block a release, but they should be logged so they are not forgotten.

| Finding | Your action |
|---|---|
| Critical SQLi | Fix immediately. Don't commit until fixed. |
| Missing nonce | Add `check_admin_referer()` or `wp_verify_nonce()` |
| N+1 query | Add `update_postmeta_cache()` before the loop |
| High complexity | Extract sub-functions. Target < 10 branches. |
| Low/Info | Log in TODO comment or Jira. Ship anyway. |

### Playwright test writing

These commands help you write and run browser-based tests. Use `--ui` mode while you are writing tests — it opens a browser so you can see exactly what each test action is doing. Once your tests are working, drop the `--ui` flag for regular runs.

```bash
# Copy the right template
cp -r tests/playwright/templates/elementor-addon tests/playwright/my-plugin

# Run in UI mode while writing
npx playwright test --ui

# Run your tests against local wp-env
WP_TEST_URL=http://localhost:8881 npx playwright test tests/playwright/my-plugin/

# Debug a failing test
npx playwright test tests/playwright/my-plugin/ --debug
```

**Rules**:
- Always call `assertPageReady(page)` at the start of every test
- Always call `discoverNavLinks()` before writing any nav-based test
- Use `gotoAdmin(page, slug)` instead of `page.goto('/wp-admin/...')`
- Never use `page.waitForTimeout()` — use `waitForSelector` or `waitForLoadState`

### Skill prompts for targeted help

You can ask Claude skills targeted questions about specific files or code patterns. These prompts show the format: specify the skill, what to look at, and what output you want. Adjust the file paths and questions to match your actual code.

```bash
# Security review of a specific file you're worried about
claude "/wordpress-penetration-testing
Review only ~/plugins/my-plugin/includes/class-rest-api.php
Every register_rest_route call — does it have permission_callback?
Does permission_callback check the correct capability?
Output: table of routes with auth status."

# Performance question
claude "/performance-engineer
I have a WP_Query that returns 200 posts. Is this approach efficient?

\`\`\`php
$posts = new WP_Query(['posts_per_page' => 200]);
foreach ($posts->posts as $post) {
    $meta = get_post_meta($post->ID, '_my_key', true);
}
\`\`\`

Show me the fixed version with query count comparison."

# PHP modernization
claude "/php-pro
Suggest PHP 8.x improvements for ~/plugins/my-plugin/includes/class-settings.php
Focus on: null-safe operator, match expressions, constructor promotion.
Show before/after for each suggestion."
```

### What you own in reports

The table below clarifies which reports are your responsibility to act on. "Developer action" means this report requires code changes — not just reading and noting.

| Report | Developer action |
|---|---|
| `qa-report-*.md` | Fix all `✗` before tagging |
| `skill-audits/security.md` | Fix Critical + High before release |
| `playwright-html/` | Fix all failed tests |
| `db-profile-*.txt` | Fix any query count regression vs previous version |

---

## 2. QA Engineer

You own: writing and maintaining the test suite, running full audits, verifying fixes, maintaining quality bar.

### Daily workflow

As a QA engineer, your primary tool is the Playwright test suite. Run the full suite against the current plugin state and review results in the browser-based report.

```bash
# Start test site
bash scripts/create-test-site.sh --plugin ~/plugins/my-plugin --port 8881

# Run full test suite
WP_TEST_URL=http://localhost:8881 npx playwright test

# View results
npx playwright show-report reports/playwright-html
```

### Before release

Before a release, QA goes beyond the basic test suite. Run the PHP matrix, test with common conflicting plugins active, and do a dedicated accessibility pass. These steps catch categories of problems that the developer's daily loop does not cover.

```bash
# Full gauntlet
bash scripts/gauntlet.sh --plugin ~/plugins/my-plugin

# PHP compatibility matrix
# (See docs/09-multi-plugin.md for full setup)
for PORT in 8881 8882 8883 8884; do
  WP_TEST_URL=http://localhost:$PORT bash scripts/gauntlet.sh --plugin ~/plugins/my-plugin --mode quick
done

# Plugin conflict test
# Activate all conflict-risk plugins and run
wp-env run cli wp plugin install woocommerce elementor wordpress-seo --activate
bash scripts/gauntlet.sh --plugin ~/plugins/my-plugin

# Accessibility deep check
npx playwright test tests/playwright/my-plugin/a11y.spec.js --headed
```

### Test writing guide

When writing a test for a new feature, start by running the Discovery test to get exact admin page URLs. Do not hardcode URLs — use `gotoAdmin()` so tests stay valid if URL structures change.

```bash
# Template for a new feature area
cp tests/playwright/templates/generic-plugin/core.spec.js \
   tests/playwright/my-plugin/new-feature.spec.js

# Write tests using the discovery flow:
# 1. Run the Discovery test → get exact nav URLs
# 2. Use gotoAdmin() + assertPageReady() for every admin page
# 3. Write assertions for every user-visible behavior
# 4. Add visual snapshot for every screen state

# Run with headed browser to verify selectors
npx playwright test tests/playwright/my-plugin/new-feature.spec.js --headed
```

### Decision matrix: when to add a test

Not every line of code needs a test, but user-facing behavior always does. Use this table to decide whether a new test is worth writing. The key principle: if a real user reported a bug, add a regression test. If no user will ever notice if the code breaks, a test is optional.

| Situation | Add test? |
|---|---|
| Bug was reported by a user | Yes — regression test |
| New feature shipping | Yes — at least smoke-level |
| Config option with 2 states | Yes — test both states |
| Trivial getter/setter | No |
| Code explored in a spike | No — delete the spike |
| Fix to a visual bug | Yes — visual regression snapshot |

A "smoke-level" test means: does the page load, does the main action work, does the result appear? It does not mean exhaustive coverage of every edge case.

### Maintaining test quality

Tests require maintenance just like code does. A flaky test (one that fails sometimes but not always) is a signal that there is a timing issue — something in the test is not waiting long enough for the UI to update. Address flaky tests promptly; a test suite that "usually passes" gives false confidence.

```bash
# Update visual snapshots after intentional UI change
npx playwright test --update-snapshots

# Check test coverage — which features have no test?
npx playwright test --list  # shows all tests
# Compare against feature list in CHANGELOG.md

# Find flaky tests
npx playwright test --repeat-each=5  # run each test 5 times
# Any that fail inconsistently → investigate timing

# Remove obsolete tests
# When a feature is removed, delete the corresponding spec file
```

### What you own in reports

| Report | QA action |
|---|---|
| `playwright-html/` | Own every test — write missing ones, fix flaky ones |
| `skill-audits/accessibility.md` | File issues for Critical/High findings. Verify fixes. |
| `uat-report-*.html` | Share with PM for visual sign-off |
| `batch-TIMESTAMP.md` | Track portfolio-wide quality trends |

---

## 3. Product Manager

You own: release decisions, interpreting what findings mean for users, approving the UAT report.

### What you read (no code required)

You do not need to run any commands to do your job in Orbit. The developer and QA engineer produce reports that you open and review. Start with the UAT report — it shows you videos and screenshots of the plugin working (or not working) as a user would see it.

**Primary**: `reports/uat-report-TIMESTAMP.html`
- Open with `open reports/uat-report-*.html`
- Shows videos + side-by-side screenshots of every flow
- Left column: your plugin. Right column: competitor.
- "Does our plugin look and behave better?"

**Secondary**: Summary from the gauntlet:
```
Results: 9 passed | 2 warnings | 0 failed
⚠ GAUNTLET PASSED WITH WARNINGS — review before release
```

### Release decision matrix

Use this table to make the go/no-go call. The left two columns describe what you were told by the developer and QA engineer. The right column is your decision.

If there is any Critical finding in skill audits, the release is held — no exceptions. A Critical finding means a user's site could be compromised, data lost, or security bypassed. That risk is not acceptable regardless of release pressure.

| Gauntlet result | Skill audits | PM decision |
|---|---|---|
| All passed | No Critical/High | **Green light — tag the release** |
| Warnings only | No Critical/High | **Review warnings with dev, release if minor** |
| Any failures | — | **Hold release until fixed** |
| Any result | Has Critical | **Hold release — security risk to users** |
| Any result | Has High | **Hold release — quality risk** |
| Any result | Medium only | **Dev's call — ship or defer** |

### What Critical/High actually means for users

Skill audit severity ratings use technical terms. This table translates each finding into plain language so you can make an informed release decision without needing to understand the code.

| Skill finding | What it means for a user |
|---|---|
| **Critical: SQLi** | An attacker could wipe the user's database |
| **Critical: XSS** | User's browser could be hijacked — sessions stolen |
| **Critical: Auth bypass** | Anyone can access admin-only features |
| **High: Missing nonce** | CSRF attack — user tricked into changing settings |
| **High: N+1 queries** | User's admin panel takes 5+ seconds to load |
| **High: Autoload bloat** | Every page load on user's site is 200ms slower |
| **Medium: Missing alt text** | Screen reader users can't understand your UI |

### Questions to ask before signing off

1. "Are there any Critical or High findings in the security tab?" → If yes: hold.
2. "Did all Playwright tests pass?" → If no: what feature is broken?
3. "Does the UAT report show all features working as expected?"
4. "Has the PHP compatibility matrix been run?" (for major releases)
5. "Is the CHANGELOG updated for this version?"

### What to ask for after a release

```
After every release, ask the developer for:
1. The qa-report-*.md summary (pass/fail counts)
2. Whether skill audits found Critical or High issues
3. Screenshot of the Playwright HTML report summary
```

---

## 4. Designer / UI Review

You own: visual quality, UX polish, consistency with the design system, and the visual regression baseline.

### What you run

These commands let you see the plugin's UI as a user would, and compare the current state against the approved baseline screenshots.

```bash
# Visual regression suite — check every screen for regressions
npx playwright test tests/playwright/visual/ --headed

# View side-by-side comparison after any visual failure
npx playwright show-report reports/playwright-html
# Click a visual test → see baseline / actual / diff

# UAT video report — watch the flows as a user would
open reports/uat-report-*.html
```

### Setting up the visual baseline

When a new design ships:

The first run creates the baseline — the "correct" version of every screenshot that all future runs compare against. Run this command once after a design is approved and verified, then commit the baseline images to the repository.

```bash
# First run — creates baseline screenshots
WP_TEST_URL=http://localhost:8881 npx playwright test tests/playwright/visual/

# Baselines are saved to:
# tests/playwright/visual/snapshots/*.png
```

After an intentional design change:

When the design is intentionally updated, the old baselines will cause all visual tests to fail — because they are comparing against the old look. Run `--update-snapshots` to accept the new design as the new baseline, then review each updated image to confirm it looks right before committing.

```bash
# Update baselines
npx playwright test tests/playwright/visual/ --update-snapshots
# Review each updated screenshot — confirm the new design is correct
# Commit the updated baselines
git add tests/playwright/visual/
git commit -m "visual: update baselines for new design system"
```

### What to look for in the UAT report

Open `reports/uat-report-*.html` and check:

1. **Hit areas** — Does every button look clickable? At least 44×44px?
2. **Visual hierarchy** — Can you immediately tell what the most important action is?
3. **Spacing consistency** — Are margins/paddings consistent with the design system?
4. **Mobile rendering** — Does the 375px viewport look intentional, not broken?
5. **Animation** — Any janky transitions? (check videos)
6. **Color contrast** — Can you read text clearly on all backgrounds?
7. **Empty states** — Do empty lists/search results look designed, not broken?

### Running the design-specific skill

This skill prompt asks Claude to review your plugin's UI for visual quality issues — things like buttons that are too small to tap, inconsistent spacing, or unclear typography hierarchy. It outputs a ranked list so you know what to fix first.

```bash
# For Elementor addon plugins
claude "/antigravity-design-expert
Review the UI quality of ~/plugins/my-plugin
Check: 44px hit areas, spacing consistency, concentric radius, typography hierarchy.
Output: ranked list of polish issues with screenshots/selectors." \
  > reports/skill-audits/design.md

open reports/skill-audits/design.md
```

### Visual test for every screen state

A complete visual test suite covers every combination of screen and state that a user might encounter. The table below shows the minimum coverage. The "States to snapshot" column is important — an empty state that looks broken will make users think your plugin failed, even if it is working correctly.

| Screen | States to snapshot |
|---|---|
| Admin dashboard | Default, empty, populated, error state |
| Settings page | Default, saved, validation error |
| Frontend widget | Default, custom colors, mobile |
| Modal / drawer | Open, closed, loading |
| Empty states | No posts, no settings, fresh install |

```bash
# Run with full page screenshots
WP_TEST_URL=http://localhost:8881 npx playwright test \
  --project=visual \
  --headed \
  tests/playwright/visual/
```

---

## 5. Team Workflow: Pre-Release Sequence

Who does what, in what order, before tagging a release.

Think of the QA release sequence like a relay race. Each role picks up the baton in order and hands it to the next. The Developer runs the first leg and hands off to QA. QA hands off to the Designer. The Designer hands off to the PM. If you try to skip the Developer leg and go straight to PM sign-off, the race is invalid — the PM cannot make a meaningful release decision without the developer's gauntlet results and the QA engineer's test suite results. Each phase builds on the one before it.

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PHASE 1: DEVELOPER (day of code freeze)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Developer runs:
  bash scripts/gauntlet.sh --plugin ~/plugins/my-plugin

Reviews skill-audits/index.html:
  → Fixes all Critical and High findings
  → Re-runs gauntlet to confirm fixes

Hands off:
  "Gauntlet clean. No Critical/High in skills.
   Playwright: 18/18 passed.
   Reports at reports/skill-audits/index.html"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PHASE 2: QA ENGINEER (day before release)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

QA runs:
  Full Playwright suite + PHP matrix + conflict test
  bash scripts/gauntlet.sh --plugin ~/plugins/my-plugin

Reviews:
  playwright-html/ → all tests pass
  accessibility.md → no Critical a11y issues
  db-profile-*.txt → no query regression

Hands off:
  "QA complete. 22 tests pass.
   PHP matrix: 7.4/8.0/8.1/8.2 all clean.
   UAT report: reports/uat-report-*.html"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PHASE 3: DESIGNER (visual sign-off)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Designer reviews:
  UAT report: open reports/uat-report-*.html
  Visual regression: npx playwright show-report reports/playwright-html

Confirms:
  → UI matches design spec
  → No regressions from previous version
  → Mobile rendering looks intentional

Hands off:
  "Design approved. Visual baselines updated."

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PHASE 4: PM (release decision)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

PM reviews:
  UAT report for feature completeness
  Gauntlet summary: pass/warn/fail counts
  Skill audits: any Critical/High?

Decision:
  All phases green → tag the release
  Any blocker found → back to Developer

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RELEASE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

git tag v2.1.0
git push origin v2.1.0
```

### Minimum for hotfix releases

For urgent bug fixes that must ship same day:

A hotfix skips most of the normal sequence out of necessity. The absolute minimum below is not the goal for every release — it is the floor for emergencies. Full matrix and visual review should still happen in the next scheduled release.

```bash
# Minimum required for a hotfix
bash scripts/gauntlet.sh --plugin ~/plugins/my-plugin --mode quick

# Manual checks:
# [ ] PHP lint passes
# [ ] Plugin activates cleanly
# [ ] The specific bug being fixed is confirmed fixed
# [ ] No new PHP errors in wp-content/debug.log
```

Full matrix and visual review can follow in the next release.

> **Q: I'm a solo developer — do I need to follow all four phases?**
> No, but you should do the work that each phase represents, even if you are the only person doing it. That means: run the full gauntlet before every release (Developer phase), run the PHP matrix and full test suite (QA phase), open the UAT report and check it visually (Designer phase), and make a conscious go/no-go decision based on the results rather than just shipping because you feel good about the code (PM phase). The phases exist to distribute judgment across different perspectives — when you are solo, you provide all four perspectives yourself, ideally with a break between them.

> **Q: What's the minimum I can do and still ship confidently?**
> The absolute minimum for a non-hotfix release: run the full gauntlet (not quick mode), fix all Critical and High findings, verify all Playwright tests pass, and check the PHP matrix at least for your minimum supported PHP version and your maximum. Skipping the visual review and UAT report is acceptable if the release is backend-only (no UI changes). Skipping security findings is never acceptable.

---

**Next**: [docs/15-ci-cd.md](15-ci-cd.md) — GitHub Actions and automated CI/CD integration.
