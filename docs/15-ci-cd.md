# CI/CD Integration

> Run Orbit automatically on every push, pull request, and release. This guide covers GitHub Actions setup, automated release gates, caching strategies, and matrix builds.

---

**You are here:** Before reading this guide, you should have Orbit running locally and at least one gauntlet run completed. This guide is for teams (or solo developers) who want Orbit to run automatically on every push, without having to remember to run it manually. If you have not yet run the gauntlet locally, start with the getting-started guide and come back here once you have a working local setup.

---

## Jargon buster

CI/CD documentation is full of terms that assume prior knowledge. Here is what everything means before you read any further:

- **GitHub Actions** — an automation system built into GitHub that runs scripts when things happen (like pushing code). Think of it as a robot employee that wakes up every time you push code, runs Orbit, and tells you pass/fail.
- **CI (Continuous Integration)** — the practice of automatically testing every change before it touches your main branch. CI catches problems immediately, while the code change is still fresh in your mind.
- **Workflow** — a YAML file (stored in `.github/workflows/`) that defines what runs and when. Each workflow is triggered by an event like a push, a pull request, or a scheduled time.
- **Job** — one isolated unit of work within a workflow. Jobs can run in parallel with each other. For example, a "static analysis" job and a "Playwright tests" job can run at the same time.
- **Step** — one command or action within a job. Steps run in sequence inside a job — each step must finish before the next one starts.
- **Artifact** — a file (like a report) that gets saved after a workflow run and can be downloaded from GitHub. Orbit uploads its HTML reports as artifacts so your team can review them without running Orbit locally.
- **Matrix build** — running the same job multiple times with different variables (like different PHP versions). Instead of writing four separate jobs for PHP 7.4, 8.0, 8.1, and 8.2, you write one job and tell GitHub Actions to run it four times.
- **Secrets** — encrypted values stored in GitHub that your workflow can use without exposing them in code. Your `ANTHROPIC_API_KEY` is a secret — it appears as `${{ secrets.ANTHROPIC_API_KEY }}` in the workflow but is never visible in the repository.
- **Caching** — saving downloaded packages between runs so you do not re-download them every time. Without caching, each run would spend 3–4 minutes re-installing npm packages. With caching, it takes seconds.
- **Self-hosted runner** — your own server acting as the CI machine instead of GitHub's servers. Useful if you need Docker already warm or want faster disk I/O.
- **`fail-fast: false`** — a matrix build setting that means "if PHP 7.4 fails, keep testing 8.0, 8.1, 8.2 anyway — I want to see all results." Without this, GitHub Actions stops the entire matrix the moment any one version fails.
- **Release gate** — a checkpoint at the border that your code must pass before it can cross into a release tag. If the gate fails, the release cannot proceed.

---

## Why CI catches things local development doesn't

When you test locally, you test in your environment — with your installed packages, your PHP version, your database, and your habits. CI tests in a clean, fresh environment that has none of your customizations. It runs the exact same way every time, with no developer bias, no "oh I know that warning is fine," and no skipped steps because you are in a hurry. A bug that only appears on PHP 7.4 will never surface on your PHP 8.1 development machine — but CI running the matrix will catch it immediately.

---

## Table of Contents

1. [Overview](#1-overview)
2. [Quickstart: Single Workflow](#2-quickstart-single-workflow)
3. [Pull Request Checks](#3-pull-request-checks)
4. [Full Release Gate Workflow](#4-full-release-gate-workflow)
5. [PHP Version Matrix in CI](#5-php-version-matrix-in-ci)
6. [Playwright in CI](#6-playwright-in-ci)
7. [Caching Strategy](#7-caching-strategy)
8. [Artifacts and Reports](#8-artifacts-and-reports)
9. [Scheduled Audits](#9-scheduled-audits)
10. [Status Badges](#10-status-badges)
11. [Secrets and Environment Variables](#11-secrets-and-environment-variables)
12. [GitLab CI / Other Platforms](#12-gitlab-ci--other-platforms)
13. [Troubleshooting CI](#13-troubleshooting-ci)

---

## 1. Overview

Orbit fits into CI at three levels:

| Level | When it runs | What it runs | Time |
|---|---|---|---|
| **Quick lint** | Every push | PHP lint + PHPCS | ~30s |
| **PR check** | Every pull request | Quick gauntlet (Steps 1–6) | ~3 min |
| **Release gate** | Tag push or manual | Full gauntlet + skill audits | ~15 min |
| **Scheduled audit** | Nightly | Full gauntlet + PHP matrix | ~30 min |

The table above shows the trade-off between speed and thoroughness. Every push gets a fast 30-second check that catches syntax errors immediately. Pull requests get a deeper check that takes a few minutes. Releases get the full audit that can take 15–30 minutes. You are not paying for the full audit on every single commit — only when it matters.

### What CI gets you

- Broken PHP syntax never reaches `main`
- Playwright failures block merge before anyone reviews the PR
- Skill audits run on every release candidate — no more "we forgot to check security"
- Reports uploaded as artifacts — download and open `index.html` without running locally
- PHP compatibility regressions caught before release, not after

### Architecture

The diagram below shows how the three main workflow files relate to each other. Each is triggered by a different event. They can run independently — a push to a feature branch triggers only the quick check, not the release gate.

```
Push to PR branch
    │
    ▼
[quick-check.yml] ← runs every push
    ├── PHP lint (10s)
    ├── PHPCS (20s)
    └── Pass? → PR is reviewable

Merge PR → PR check passes
    │
    ▼
[pr-check.yml] ← runs on PR open/sync
    ├── wp-env start
    ├── Playwright (smoke)
    ├── PHPStan
    └── FAIL → PR blocked

Push git tag v*.*.*
    │
    ▼
[release-gate.yml] ← runs on tag push
    ├── Full gauntlet (all 11 steps)
    ├── Skill audits (6 Claude skills)
    ├── PHP matrix (7.4 + 8.0 + 8.1 + 8.2)
    ├── Upload reports as artifacts
    └── FAIL → Release blocked
```

---

## 2. Quickstart: Single Workflow

If you want one workflow that covers everything, start here. Add this to your plugin repo at `.github/workflows/orbit.yml`.

This is a single YAML file that runs on every push to `main` or `develop`, and on every pull request targeting `main`. It installs all dependencies, runs the quick gauntlet, and uploads the reports as a downloadable artifact. This is the right starting point if you have never set up CI before — get this working first, then add the more advanced workflows from the sections below.

```yaml
name: Orbit QA

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  orbit:
    runs-on: ubuntu-latest
    timeout-minutes: 20

    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: '8.1'
          extensions: mbstring, xml, zip
          tools: composer, cs2pr

      - name: Checkout Orbit
        uses: actions/checkout@v4
        with:
          repository: adityaarsharma/orbit
          path: orbit

      - name: Install Orbit dependencies
        working-directory: orbit
        run: |
          npm ci
          composer install --no-interaction

      - name: Install PHPCS + standards
        working-directory: orbit
        run: bash setup/install-phpcs.sh

      - name: Install Playwright browsers
        working-directory: orbit
        run: npx playwright install --with-deps chromium

      - name: Run quick gauntlet
        working-directory: orbit
        env:
          PLUGIN_PATH: ${{ github.workspace }}
        run: |
          bash scripts/gauntlet.sh \
            --plugin "$PLUGIN_PATH" \
            --mode quick \
            --report-dir reports

      - name: Upload reports
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: orbit-reports
          path: orbit/reports/
          retention-days: 14
```

The `if: always()` on the upload step means reports are saved even if the gauntlet failed — which is exactly when you need them most.

This gives you: PHP lint, PHPCS, PHPStan, Asset check, i18n check, and Playwright smoke tests on every push and PR.

---

## 3. Pull Request Checks

For teams: block merges until Orbit passes. Create `.github/workflows/pr-check.yml` in your plugin repo.

This workflow has two jobs that reflect a practical optimization: static analysis (PHP lint, PHPCS, PHPStan) runs first because it is fast and does not need Docker. The Playwright job — which needs a running WordPress environment — only starts if static analysis passes. This means a simple syntax error does not waste 10 minutes waiting for Docker to spin up.

```yaml
name: PR Quality Check

on:
  pull_request:
    branches: [main, develop]
    types: [opened, synchronize, reopened]

jobs:
  # Job 1: Static analysis (fast, no Docker)
  static:
    name: Static Analysis
    runs-on: ubuntu-latest
    timeout-minutes: 5

    steps:
      - uses: actions/checkout@v4

      - name: Setup PHP 8.1
        uses: shivammathur/setup-php@v2
        with:
          php-version: '8.1'
          tools: composer, phpcs, phpstan

      - name: Checkout Orbit
        uses: actions/checkout@v4
        with:
          repository: adityaarsharma/orbit
          path: orbit

      - name: Install standards
        working-directory: orbit
        run: bash setup/install-phpcs.sh

      - name: PHP Lint
        run: find . -name "*.php" -not -path "*/vendor/*" -not -path "*/node_modules/*" | xargs php -l

      - name: PHPCS (errors only)
        working-directory: orbit
        run: |
          vendor/bin/phpcs \
            --standard=WordPress \
            --severity=10 \
            --report=checkstyle \
            ${{ github.workspace }} \
            | cs2pr

      - name: PHPStan
        working-directory: orbit
        run: |
          vendor/bin/phpstan analyse \
            --configuration=phpstan.neon \
            --no-progress \
            ${{ github.workspace }}

  # Job 2: Functional tests (Docker required)
  functional:
    name: Playwright Tests
    runs-on: ubuntu-latest
    timeout-minutes: 15
    needs: static  # Only run if static passes

    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Checkout Orbit
        uses: actions/checkout@v4
        with:
          repository: adityaarsharma/orbit
          path: orbit

      - name: Cache node_modules
        uses: actions/cache@v4
        with:
          path: orbit/node_modules
          key: ${{ runner.os }}-node-${{ hashFiles('orbit/package-lock.json') }}
          restore-keys: ${{ runner.os }}-node-

      - name: Install dependencies
        working-directory: orbit
        run: npm ci

      - name: Install Playwright
        working-directory: orbit
        run: npx playwright install --with-deps chromium

      - name: Start wp-env
        working-directory: orbit
        run: |
          cat > .wp-env.json << EOF
          {
            "plugins": ["${{ github.workspace }}"],
            "port": 8881,
            "config": {
              "WP_DEBUG": true,
              "WP_DEBUG_LOG": true
            }
          }
          EOF
          npx wp-env start

      - name: Run Playwright
        working-directory: orbit
        env:
          WP_TEST_URL: http://localhost:8881
        run: |
          npx playwright test \
            --project=chromium \
            --reporter=github

      - name: Upload Playwright report
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: playwright-report-pr-${{ github.event.pull_request.number }}
          path: orbit/reports/playwright-html/
          retention-days: 7

      - name: Stop wp-env
        if: always()
        working-directory: orbit
        run: npx wp-env stop
```

### Required status checks

In your GitHub repo settings → Branches → Branch protection rules:
1. Require status checks to pass before merging
2. Add: `Static Analysis` and `Playwright Tests`
3. Require branches to be up to date

Now PRs cannot merge if Orbit fails.

---

## 4. Full Release Gate Workflow

This runs on tag push and is the definitive green light for a release. It is the most thorough check in the pipeline — it runs the full gauntlet including skill audits, parses the results, and explicitly fails if there are any Critical or High findings. Think of it as the checkpoint at the border that your code must pass before it can cross into a release tag.

Create `.github/workflows/release-gate.yml`:

```yaml
name: Release Gate

on:
  push:
    tags:
      - 'v*.*.*'
  workflow_dispatch:
    inputs:
      plugin_ref:
        description: 'Branch or commit to test'
        required: true
        default: 'main'

jobs:
  release-gate:
    name: Full Gauntlet + Skill Audits
    runs-on: ubuntu-latest
    timeout-minutes: 45

    steps:
      - name: Checkout plugin
        uses: actions/checkout@v4
        with:
          ref: ${{ github.event.inputs.plugin_ref || github.ref }}

      - name: Setup PHP 8.1
        uses: shivammathur/setup-php@v2
        with:
          php-version: '8.1'
          extensions: mbstring, xml, zip, intl
          tools: composer

      - name: Setup Node.js 20
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Checkout Orbit
        uses: actions/checkout@v4
        with:
          repository: adityaarsharma/orbit
          path: orbit

      - name: Cache Orbit node_modules
        uses: actions/cache@v4
        with:
          path: orbit/node_modules
          key: ${{ runner.os }}-orbit-node-${{ hashFiles('orbit/package-lock.json') }}

      - name: Cache Orbit composer
        uses: actions/cache@v4
        with:
          path: orbit/vendor
          key: ${{ runner.os }}-orbit-composer-${{ hashFiles('orbit/composer.lock') }}

      - name: Install Orbit dependencies
        working-directory: orbit
        run: |
          npm ci
          composer install --no-interaction --prefer-dist

      - name: Install PHPCS standards
        working-directory: orbit
        run: bash setup/install-phpcs.sh

      - name: Install Playwright browsers
        working-directory: orbit
        run: npx playwright install --with-deps

      - name: Install Claude Code (for skill audits)
        run: npm install -g @anthropic-ai/claude-code

      - name: Run full gauntlet
        working-directory: orbit
        env:
          PLUGIN_PATH: ${{ github.workspace }}
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
          CI: true
        run: |
          bash scripts/gauntlet.sh \
            --plugin "$PLUGIN_PATH" \
            --report-dir reports

      - name: Parse gauntlet result
        id: gauntlet
        working-directory: orbit
        run: |
          # Extract pass/fail/warn counts from report
          REPORT=$(ls reports/qa-report-*.md | tail -1)
          PASSED=$(grep -E "✓ Passed:" "$REPORT" | grep -oE "[0-9]+" | head -1)
          FAILED=$(grep -E "✗ Failed:" "$REPORT" | grep -oE "[0-9]+" | head -1)
          WARNED=$(grep -E "⚠ Warnings:" "$REPORT" | grep -oE "[0-9]+" | head -1)
          echo "passed=$PASSED" >> $GITHUB_OUTPUT
          echo "failed=$FAILED" >> $GITHUB_OUTPUT
          echo "warned=$WARNED" >> $GITHUB_OUTPUT
          echo "### Gauntlet Results" >> $GITHUB_STEP_SUMMARY
          echo "| Result | Count |" >> $GITHUB_STEP_SUMMARY
          echo "|---|---|" >> $GITHUB_STEP_SUMMARY
          echo "| ✓ Passed | $PASSED |" >> $GITHUB_STEP_SUMMARY
          echo "| ⚠ Warnings | $WARNED |" >> $GITHUB_STEP_SUMMARY
          echo "| ✗ Failed | $FAILED |" >> $GITHUB_STEP_SUMMARY

      - name: Check for critical skill findings
        working-directory: orbit
        run: |
          # Count Critical + High across all skill reports
          CRITICAL=$(grep -r "Critical)" reports/skill-audits/*.md 2>/dev/null | wc -l || echo 0)
          HIGH=$(grep -r "High)" reports/skill-audits/*.md 2>/dev/null | wc -l || echo 0)
          echo "Critical findings: $CRITICAL"
          echo "High findings: $HIGH"
          if [ "$CRITICAL" -gt 0 ]; then
            echo "::error::Release blocked: $CRITICAL Critical findings in skill audits"
            exit 1
          fi
          if [ "$HIGH" -gt 0 ]; then
            echo "::error::Release blocked: $HIGH High findings in skill audits"
            exit 1
          fi

      - name: Fail if gauntlet failed
        if: steps.gauntlet.outputs.failed != '0'
        run: |
          echo "::error::Gauntlet failed with ${{ steps.gauntlet.outputs.failed }} failures"
          exit 1

      - name: Upload all reports
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: orbit-release-reports-${{ github.ref_name }}
          path: orbit/reports/
          retention-days: 30

      - name: Create release summary
        if: success()
        run: |
          echo "## Release Gate Passed ✓" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "Tag: \`${{ github.ref_name }}\`" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "All checks passed. Safe to publish." >> $GITHUB_STEP_SUMMARY
```

### Workflow dispatch (manual trigger)

You can trigger the full release gate on any branch without creating a tag first. This is useful during development when you want skill audits to run on demand without committing to a release.

Run the full gate on any branch without tagging:

1. Go to GitHub → Actions → Release Gate
2. Click "Run workflow"
3. Enter branch name: `feature/my-new-feature`
4. Click "Run workflow"

Use this during development to run skill audits on demand.

---

## 5. PHP Version Matrix in CI

Test against all supported PHP versions in parallel using a matrix strategy. This is the CI version of the local PHP matrix from `docs/09-multi-plugin.md` — the same concept, but running on GitHub's servers automatically on every tag push and every Monday morning.

The `fail-fast: false` setting is important here. Without it, if PHP 7.4 fails, GitHub Actions would cancel all the other matrix jobs immediately. With `fail-fast: false`, all four PHP versions run to completion — giving you a complete picture of where compatibility breaks.

```yaml
name: PHP Compatibility Matrix

on:
  push:
    tags: ['v*.*.*']
  schedule:
    - cron: '0 2 * * 1'  # Every Monday at 2am UTC

jobs:
  php-matrix:
    name: PHP ${{ matrix.php }} / WP ${{ matrix.wp }}
    runs-on: ubuntu-latest
    timeout-minutes: 20

    strategy:
      fail-fast: false  # Run all versions even if one fails
      matrix:
        php: ['7.4', '8.0', '8.1', '8.2']
        wp: ['6.4', '6.5', '6.6']
        exclude:
          # PHP 7.4 dropped in WP 6.5+? Adjust based on your requirements
          - php: '7.4'
            wp: '6.6'

    steps:
      - uses: actions/checkout@v4

      - name: Setup PHP ${{ matrix.php }}
        uses: shivammathur/setup-php@v2
        with:
          php-version: ${{ matrix.php }}
          extensions: mbstring, xml, zip

      - name: Setup Node.js 20
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Checkout Orbit
        uses: actions/checkout@v4
        with:
          repository: adityaarsharma/orbit
          path: orbit

      - name: Install dependencies
        working-directory: orbit
        run: |
          npm ci
          composer install --no-interaction

      - name: Install PHPCS standards
        working-directory: orbit
        run: bash setup/install-phpcs.sh

      - name: Install Playwright chromium
        working-directory: orbit
        run: npx playwright install --with-deps chromium

      - name: Create wp-env config for PHP ${{ matrix.php }}
        working-directory: orbit
        run: |
          cat > .wp-env.json << EOF
          {
            "core": "WordPress/WordPress#tags/${{ matrix.wp }}",
            "plugins": ["${{ github.workspace }}"],
            "phpVersion": "${{ matrix.php }}",
            "port": 8881,
            "config": {
              "WP_DEBUG": true,
              "WP_DEBUG_LOG": true
            }
          }
          EOF

      - name: Run quick gauntlet
        working-directory: orbit
        env:
          PLUGIN_PATH: ${{ github.workspace }}
          CI: true
        run: |
          bash scripts/gauntlet.sh \
            --plugin "$PLUGIN_PATH" \
            --mode quick \
            --report-dir "reports/php${{ matrix.php }}-wp${{ matrix.wp }}"

      - name: Upload matrix reports
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: matrix-php${{ matrix.php }}-wp${{ matrix.wp }}
          path: orbit/reports/php${{ matrix.php }}-wp${{ matrix.wp }}/
          retention-days: 14

  matrix-summary:
    name: Matrix Summary
    needs: php-matrix
    runs-on: ubuntu-latest
    if: always()

    steps:
      - name: Generate matrix summary
        run: |
          echo "## PHP Compatibility Matrix" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "| PHP | WP 6.4 | WP 6.5 | WP 6.6 |" >> $GITHUB_STEP_SUMMARY
          echo "|---|---|---|---|" >> $GITHUB_STEP_SUMMARY
          echo "| 7.4 | ${{ needs.php-matrix.result }} | ${{ needs.php-matrix.result }} | — |" >> $GITHUB_STEP_SUMMARY
          echo "| 8.0 | ${{ needs.php-matrix.result }} | ${{ needs.php-matrix.result }} | ${{ needs.php-matrix.result }} |" >> $GITHUB_STEP_SUMMARY
          echo "| 8.1 | ${{ needs.php-matrix.result }} | ${{ needs.php-matrix.result }} | ${{ needs.php-matrix.result }} |" >> $GITHUB_STEP_SUMMARY
          echo "| 8.2 | ${{ needs.php-matrix.result }} | ${{ needs.php-matrix.result }} | ${{ needs.php-matrix.result }} |" >> $GITHUB_STEP_SUMMARY
```

### What changes between PHP versions

The table below is your reference when the matrix fails on a specific PHP version and you are not sure what to look for. If PHP 7.4 passes but PHP 8.0 fails, start by looking at the changes in the 7.4 → 8.0 row. PHPCompatibilityWP (run in Step 2 of the gauntlet) will flag most of these automatically — this table helps you understand why.

| PHP Change | What breaks |
|---|---|
| 7.4 → 8.0 | `count(null)` fatal, `each()` removed, `create_function()` removed, type coercion changes |
| 8.0 → 8.1 | Passing `null` to non-nullable args deprecated, `readonly` properties added (syntax change) |
| 8.1 → 8.2 | Dynamic property creation deprecated, `true`/`false` as standalone types |
| Any | `preg_replace()` with `/e` modifier removed in 7.0 (legacy code may still use it) |

PHPCompatibilityWP ruleset catches most of these as PHPCS warnings in Step 2.

---

## 6. Playwright in CI

Playwright needs a running WordPress instance. In CI, use `wp-env` with Docker.

### Self-hosted runner (recommended for speed)

If you have a self-hosted runner with Docker installed:

```yaml
runs-on: self-hosted  # instead of ubuntu-latest
```

Benefits:
- Docker already warm — `wp-env start` takes 30s instead of 2min
- No Docker pull cost on every run
- Faster disk I/O for wp-env volumes

### GitHub-hosted runner

On `ubuntu-latest`, Docker is available but images need to pull. The `timeout 300` command gives Docker up to 5 minutes to start — which is usually enough even on a cold pull. The `|| (npx wp-env logs && exit 1)` part prints the logs if it fails, which makes debugging much easier.

```yaml
- name: Check Docker
  run: docker info

- name: Start wp-env
  working-directory: orbit
  run: |
    # Increase timeout for cold Docker pulls
    timeout 300 npx wp-env start || (npx wp-env logs && exit 1)
```

### Playwright environment variables

```yaml
- name: Run Playwright
  working-directory: orbit
  env:
    WP_TEST_URL: http://localhost:8881
    WP_ADMIN_USER: admin
    WP_ADMIN_PASS: password
    CI: true
  run: npx playwright test --project=chromium
```

### Headed vs headless

Playwright always runs headless in CI — no display is needed. The `CI=true` environment variable automatically enables headless mode in most Playwright configs. You do not need to configure this separately.

To explicitly force headless:

```yaml
- name: Run Playwright
  working-directory: orbit
  run: |
    npx playwright test \
      --project=chromium \
      --headed=false \
      --workers=1  # Reduce workers in CI to avoid flakiness
```

### Retry on flaky tests

```yaml
- name: Run Playwright with retries
  working-directory: orbit
  env:
    WP_TEST_URL: http://localhost:8881
  run: |
    npx playwright test \
      --project=chromium \
      --retries=2 \
      --reporter=github,html
```

`--retries=2` means each failing test gets 2 retry attempts before being counted as a failure. This eliminates timing-related flakiness from CI.

### Sharding for large test suites

If you have 50+ tests and want parallel execution across multiple machines:

```yaml
jobs:
  playwright-shard:
    strategy:
      matrix:
        shard: [1/4, 2/4, 3/4, 4/4]

    steps:
      - name: Run Playwright shard
        run: npx playwright test --shard=${{ matrix.shard }}

      - name: Upload shard results
        uses: actions/upload-artifact@v4
        with:
          name: playwright-results-${{ strategy.job-index }}
          path: blob-report/

  merge-reports:
    needs: playwright-shard
    steps:
      - name: Download all shards
        uses: actions/download-artifact@v4
        with:
          path: all-blob-reports
          pattern: playwright-results-*

      - name: Merge reports
        run: npx playwright merge-reports --reporter=html ./all-blob-reports
```

---

## 7. Caching Strategy

CI runs get expensive and slow without caching. Every time a workflow runs without caching, it re-downloads the same packages from the internet. Caching saves those packages between runs so downloads only happen when something actually changes.

Cache everything that doesn't change between runs:

### Node modules cache

The `hashFiles('orbit/package-lock.json')` part means the cache key changes whenever `package-lock.json` changes — so if you add a new npm package, the cache is invalidated and packages are re-downloaded fresh. Otherwise, the cached version is used.

```yaml
- name: Cache node_modules
  uses: actions/cache@v4
  id: node-cache
  with:
    path: |
      orbit/node_modules
      ~/.npm
    key: ${{ runner.os }}-node-${{ hashFiles('orbit/package-lock.json') }}
    restore-keys: |
      ${{ runner.os }}-node-

- name: Install node dependencies
  if: steps.node-cache.outputs.cache-hit != 'true'
  working-directory: orbit
  run: npm ci
```

### Composer cache

```yaml
- name: Get composer cache directory
  id: composer-cache
  run: echo "dir=$(composer config cache-files-dir)" >> $GITHUB_OUTPUT

- name: Cache composer packages
  uses: actions/cache@v4
  with:
    path: ${{ steps.composer-cache.outputs.dir }}
    key: ${{ runner.os }}-composer-${{ hashFiles('orbit/composer.lock') }}
    restore-keys: ${{ runner.os }}-composer-

- name: Install composer dependencies
  working-directory: orbit
  run: composer install --no-interaction --prefer-dist --optimize-autoloader
```

### Playwright browser cache

```yaml
- name: Cache Playwright browsers
  uses: actions/cache@v4
  id: playwright-cache
  with:
    path: ~/.cache/ms-playwright
    key: ${{ runner.os }}-playwright-${{ hashFiles('orbit/package-lock.json') }}

- name: Install Playwright browsers
  if: steps.playwright-cache.outputs.cache-hit != 'true'
  working-directory: orbit
  run: npx playwright install --with-deps chromium
```

### wp-env Docker image cache

Docker layer caching in GitHub Actions requires Docker Buildx:

```yaml
- name: Set up Docker Buildx
  uses: docker/setup-buildx-action@v3

- name: Cache Docker layers
  uses: actions/cache@v4
  with:
    path: /tmp/.buildx-cache
    key: ${{ runner.os }}-buildx-${{ github.sha }}
    restore-keys: |
      ${{ runner.os }}-buildx-
```

For wp-env specifically, you can pre-pull the WordPress Docker image:

```yaml
- name: Pre-pull wp-env images
  run: |
    docker pull wordpress:latest
    docker pull mariadb:10.8
```

### Expected cache impact

The table below shows the real-world time savings from caching. The total savings of about 3 minutes per run adds up quickly — on a team making 20 pushes a day, that is 60 minutes of waiting time saved daily.

| Step | Without cache | With cache |
|---|---|---|
| `npm ci` | 45s | 5s |
| `composer install` | 30s | 8s |
| Playwright install | 60s | 10s |
| Docker image pull | 90s | 15s |
| **Total savings** | ~225s | ~38s |

Roughly 3 minutes saved per run.

---

## 8. Artifacts and Reports

Upload reports as GitHub Actions artifacts so anyone on the team can download and view them without running Orbit locally.

The `if: always()` condition means reports are uploaded even if the gauntlet failed. This is intentional — when a run fails, the reports are the most important thing to have access to. Without `always()`, a failing run would produce no downloadable artifacts.

### Upload all reports

```yaml
- name: Upload Orbit reports
  if: always()  # Upload even if gauntlet failed
  uses: actions/upload-artifact@v4
  with:
    name: orbit-reports-${{ github.run_number }}
    path: |
      orbit/reports/qa-report-*.md
      orbit/reports/skill-audits/
      orbit/reports/playwright-html/
      orbit/reports/uat-report-*.html
      orbit/reports/lighthouse/
      orbit/reports/db-profile-*.txt
    retention-days: 30
```

### Upload only on failure

```yaml
- name: Upload failure artifacts
  if: failure()
  uses: actions/upload-artifact@v4
  with:
    name: failure-report-pr-${{ github.event.pull_request.number }}
    path: orbit/reports/playwright-html/
    retention-days: 7
```

### Download and view reports locally

Once a workflow run has completed, you can download the reports using the GitHub CLI. The first command downloads everything; the second opens the HTML reports in your browser.

```bash
# Using GitHub CLI
gh run download <run-id> --name orbit-reports-42

# Then open
open orbit-reports-42/skill-audits/index.html
npx playwright show-report orbit-reports-42/playwright-html
```

### Post report summary to PR comment

Use a GitHub Action to comment on the PR with the gauntlet summary:

```yaml
- name: Comment on PR with results
  if: github.event_name == 'pull_request'
  uses: actions/github-script@v7
  with:
    script: |
      const fs = require('fs');
      const glob = require('@actions/glob');

      // Find the report
      const globber = await glob.create('orbit/reports/qa-report-*.md');
      const files = await globber.glob();
      if (!files.length) return;

      const report = fs.readFileSync(files[0], 'utf8');

      // Extract summary lines
      const summaryMatch = report.match(/## Summary[\s\S]*?(?=\n##|$)/);
      const summary = summaryMatch ? summaryMatch[0] : 'No summary found';

      // Post comment
      github.rest.issues.createComment({
        issue_number: context.issue.number,
        owner: context.repo.owner,
        repo: context.repo.repo,
        body: `## Orbit QA Results\n\n\`\`\`\n${summary}\n\`\`\`\n\n[View full report](${context.payload.repository.html_url}/actions/runs/${context.runId})`
      });
```

### Publish Playwright HTML report to GitHub Pages

For teams that want a permanent URL to every test run:

```yaml
- name: Deploy Playwright report to GitHub Pages
  if: github.ref == 'refs/heads/main'
  uses: peaceiris/actions-gh-pages@v3
  with:
    github_token: ${{ secrets.GITHUB_TOKEN }}
    publish_dir: orbit/reports/playwright-html
    destination_dir: playwright/${{ github.run_number }}
```

After a few runs, reports are browsable at:
`https://yourorg.github.io/your-plugin/playwright/42/index.html`

---

## 9. Scheduled Audits

Run a full audit every night so you catch issues before they pile up. This is especially useful for catching things that are not triggered by code changes — like a WordPress core update that introduces a new deprecation affecting your plugin, or a security vulnerability in a dependency.

```yaml
name: Nightly Full Audit

on:
  schedule:
    - cron: '0 3 * * *'  # 3am UTC every day
  workflow_dispatch:

jobs:
  nightly-audit:
    runs-on: ubuntu-latest
    timeout-minutes: 60

    steps:
      - uses: actions/checkout@v4
        with:
          ref: main  # Always audit main branch

      - name: Setup tools
        uses: shivammathur/setup-php@v2
        with:
          php-version: '8.1'
          tools: composer

      - uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Checkout Orbit
        uses: actions/checkout@v4
        with:
          repository: adityaarsharma/orbit
          path: orbit

      - name: Install everything
        working-directory: orbit
        run: |
          npm ci
          composer install --no-interaction
          bash setup/install-phpcs.sh
          npx playwright install --with-deps

      - name: Install Claude Code
        run: npm install -g @anthropic-ai/claude-code

      - name: Run full gauntlet with skill audits
        working-directory: orbit
        env:
          PLUGIN_PATH: ${{ github.workspace }}
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
          CI: true
        run: |
          bash scripts/gauntlet.sh \
            --plugin "$PLUGIN_PATH" \
            --report-dir reports/nightly

      - name: Upload nightly reports
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: nightly-${{ github.run_number }}-${{ github.ref_name }}
          path: orbit/reports/nightly/
          retention-days: 90

      - name: Notify Slack on failure
        if: failure()
        uses: 8398a7/action-slack@v3
        with:
          status: failure
          text: "Nightly audit FAILED on `${{ github.repository }}`. Check reports: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}"
          webhook_url: ${{ secrets.SLACK_WEBHOOK_URL }}
```

### Scheduled cron tips

Cron expressions follow the format: minute, hour, day-of-month, month, day-of-week. All times are UTC. Use the table below to set your preferred schedule.

| Schedule | Cron expression |
|---|---|
| Every night at 3am UTC | `0 3 * * *` |
| Every Monday at 6am UTC | `0 6 * * 1` |
| Every day before business hours | `0 7 * * 1-5` |
| Twice a week (Mon + Thu) | `0 3 * * 1,4` |

---

## 10. Status Badges

Add Orbit badges to your plugin README:

```markdown
![Orbit QA](https://github.com/yourorg/your-plugin/actions/workflows/orbit.yml/badge.svg)
![PHP Matrix](https://github.com/yourorg/your-plugin/actions/workflows/php-matrix.yml/badge.svg)
```

These badges show the current pass/fail status of your workflows.

### Dynamic badge from gauntlet output

For a badge showing the actual pass count, you can use shields.io with a Gist endpoint:

```yaml
- name: Update status badge
  if: github.ref == 'refs/heads/main'
  uses: schneegans/dynamic-badges-action@v1.7.0
  with:
    auth: ${{ secrets.GIST_TOKEN }}
    gistID: your-gist-id-here
    filename: orbit-badge.json
    label: Orbit
    message: "${{ steps.gauntlet.outputs.passed }} passed"
    color: ${{ steps.gauntlet.outputs.failed == '0' && 'brightgreen' || 'red' }}
```

Result: `![Orbit](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/you/GIST_ID/raw/orbit-badge.json)`

---

## 11. Secrets and Environment Variables

### Required secrets

Secrets are encrypted values that your workflow can access without exposing them in your code. They are set once in GitHub and referenced in workflows as `${{ secrets.NAME }}`. Never put actual API keys or passwords directly in your workflow YAML files.

| Secret | Purpose | Where to get it |
|---|---|---|
| `ANTHROPIC_API_KEY` | Claude Code skill audits (Step 11) | console.anthropic.com |
| `SLACK_WEBHOOK_URL` | Failure notifications | Slack → App → Incoming Webhooks |
| `GIST_TOKEN` | Dynamic badge updates | GitHub → Settings → Tokens (gist scope) |

Only `ANTHROPIC_API_KEY` is required if you want skill audits to run in CI. The other two are optional — for notifications and badges respectively.

### Optional secrets

| Secret | Purpose |
|---|---|
| `WP_ADMIN_USER` | WordPress admin username (default: admin) |
| `WP_ADMIN_PASS` | WordPress admin password (default: password) |
| `LIGHTHOUSE_CI_TOKEN` | Lighthouse CI server token |

### Setting secrets

These commands add secrets to your repository using the GitHub CLI. You only need to do this once per secret. After setting a secret, it is immediately available to all workflows in that repository.

```bash
# Using GitHub CLI
gh secret set ANTHROPIC_API_KEY --body "sk-ant-..."
gh secret set SLACK_WEBHOOK_URL --body "https://hooks.slack.com/..."

# Set for all repos in an org (requires org admin)
gh secret set ANTHROPIC_API_KEY --org yourorg --body "sk-ant-..."
```

### Using secrets in workflows

```yaml
env:
  ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
```

### Skill audits without ANTHROPIC_API_KEY

If you want to run CI without paying for API calls, skip Step 11:

```yaml
- name: Run gauntlet (no skill audits)
  run: |
    bash scripts/gauntlet.sh \
      --plugin "$PLUGIN_PATH" \
      --skip-step 11
```

Or set a flag in your qa.config.json:

```json
{
  "ci": {
    "skipSkillAudits": true
  }
}
```

Skill audits still run locally before release — you just skip them in the quick PR check to save API costs.

> **Q: Do I need CI at all if I'm solo?**
> CI is valuable even for solo developers — arguably more so, because there is no teammate to catch mistakes before they reach main. The key benefit is not team coordination; it is the fresh environment. Your local machine has accumulated months of configuration. CI runs on a clean machine every time, which means it catches things like "this only works because I have a global composer package installed" or "this fails on PHP 7.4 but I develop on 8.1." Start with the simple single-workflow setup from Section 2. You can add the full release gate later.

> **Q: Does every push run skill audits? That would cost a lot in API calls.**
> No. Skill audits (the Claude-powered security, performance, and accessibility checks) only run in the full release gate, which triggers on tag pushes. PR checks run PHPStan and Playwright only — no API calls. You can also skip skill audits in the release gate using `--skip-step 11` if you want to control costs. A reasonable approach: run skill audits manually before release using `open reports/skill-audits/index.html` locally, and only use CI for the automated checks.

> **Q: What happens to the workflow if I don't have an ANTHROPIC_API_KEY secret set?**
> The gauntlet step that runs skill audits will fail because the `claude` command will be unable to authenticate. This will cause the entire release gate workflow to fail. To avoid this, either set the secret (recommended for release gates) or use `--skip-step 11` in the gauntlet command to skip skill audits entirely in CI. The simpler PR check workflow does not use the API key at all, so it will work fine without it.

---

## 12. GitLab CI / Other Platforms

### GitLab CI

Create `.gitlab-ci.yml` in your plugin repo:

```yaml
stages:
  - static
  - test
  - release

variables:
  ORBIT_PATH: "$CI_PROJECT_DIR/orbit"

.orbit-setup: &orbit-setup
  before_script:
    - apt-get update -qq && apt-get install -y -qq git curl
    - curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    - apt-get install -y nodejs
    - npm install -g @anthropic-ai/claude-code
    - git clone https://github.com/adityaarsharma/orbit.git orbit
    - cd orbit && npm ci && composer install --no-interaction
    - bash setup/install-phpcs.sh
    - npx playwright install --with-deps chromium

php-lint:
  stage: static
  image: php:8.1-cli
  script:
    - find . -name "*.php" -not -path "*/vendor/*" | xargs php -l

phpcs:
  stage: static
  <<: *orbit-setup
  script:
    - cd orbit && vendor/bin/phpcs --standard=WordPress $CI_PROJECT_DIR

playwright:
  stage: test
  services:
    - docker:dind
  variables:
    DOCKER_HOST: tcp://docker:2375
    DOCKER_TLS_CERTDIR: ""
  <<: *orbit-setup
  script:
    - cd orbit
    - echo '{"plugins": ["'"$CI_PROJECT_DIR"'"], "port": 8881}' > .wp-env.json
    - npx wp-env start
    - WP_TEST_URL=http://localhost:8881 npx playwright test --project=chromium
  artifacts:
    when: always
    paths:
      - orbit/reports/playwright-html/
    expire_in: 2 weeks

release-gate:
  stage: release
  only:
    - tags
  <<: *orbit-setup
  script:
    - cd orbit
    - ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY bash scripts/gauntlet.sh --plugin $CI_PROJECT_DIR
  artifacts:
    paths:
      - orbit/reports/
    expire_in: 90 days
```

### Bitbucket Pipelines

```yaml
# bitbucket-pipelines.yml
image: node:20

pipelines:
  pull-requests:
    '**':
      - step:
          name: Orbit PR Check
          services:
            - docker
          script:
            - apt-get update && apt-get install -y php8.1 composer
            - git clone https://github.com/adityaarsharma/orbit.git
            - cd orbit && npm ci && composer install
            - bash setup/install-phpcs.sh
            - npx playwright install --with-deps chromium
            - echo '{"plugins": [".."], "port": 8881}' > .wp-env.json
            - npx wp-env start
            - bash scripts/gauntlet.sh --plugin .. --mode quick
          artifacts:
            - orbit/reports/**

  tags:
    v*.*.*:
      - step:
          name: Release Gate
          script:
            # Full gauntlet on tag
            - bash scripts/gauntlet.sh --plugin ..
```

### CircleCI

```yaml
# .circleci/config.yml
version: 2.1

orbs:
  node: circleci/node@5.1
  php: circleci/php@1.1

jobs:
  orbit-check:
    machine:
      image: ubuntu-2204:current
    steps:
      - checkout
      - node/install:
          node-version: '20'
      - php/install-php:
          version: '8.1'
      - run:
          name: Clone Orbit
          command: git clone https://github.com/adityaarsharma/orbit.git
      - run:
          name: Setup
          command: |
            cd orbit
            npm ci
            composer install
            bash setup/install-phpcs.sh
            npx playwright install --with-deps chromium
      - run:
          name: Run Gauntlet
          command: |
            cd orbit
            bash scripts/gauntlet.sh --plugin $CIRCLE_WORKING_DIRECTORY --mode quick
      - store_artifacts:
          path: orbit/reports
          destination: orbit-reports

workflows:
  version: 2
  build-test:
    jobs:
      - orbit-check
```

---

## 13. Troubleshooting CI

### `wp-env start` hangs or times out

**Cause**: Docker pull taking too long, or port conflict.

```yaml
- name: Debug wp-env startup
  working-directory: orbit
  run: |
    # Add timeout and show logs on failure
    timeout 180 npx wp-env start 2>&1 || {
      echo "=== wp-env logs ==="
      npx wp-env logs
      echo "=== Docker containers ==="
      docker ps -a
      echo "=== Docker images ==="
      docker images
      exit 1
    }
```

**Fix**: Pre-pull Docker images before starting wp-env:

```yaml
- name: Pre-pull Docker images
  run: |
    docker pull wordpress:latest
    docker pull mariadb:latest
```

### Playwright `page.goto()` timeout

**Cause**: WordPress is starting but not ready when the test runs.

```yaml
- name: Wait for WordPress
  run: |
    timeout 60 bash -c 'until curl -sf http://localhost:8881/ > /dev/null; do sleep 2; done'
    echo "WordPress is ready"
```

Also add to your playwright.config.js:

```javascript
export default {
  use: {
    navigationTimeout: 30000,  // 30s for slow CI environments
    actionTimeout: 15000,
  },
  retries: process.env.CI ? 2 : 0,
};
```

### `claude` command not found (skill audits fail)

**Cause**: Claude Code CLI not installed or not in PATH.

```yaml
- name: Install Claude Code
  run: |
    npm install -g @anthropic-ai/claude-code
    which claude  # Verify it's in PATH
    claude --version
```

### PHPCS standards not found

**Cause**: `phpcs --config-set installed_paths` points to a path that doesn't exist in CI.

```yaml
- name: Install and configure PHPCS
  working-directory: orbit
  run: |
    bash setup/install-phpcs.sh
    # Verify standards
    vendor/bin/phpcs -i
    # Should show: WordPress, WordPress-Core, WordPress-Extra, etc.
```

If standards show as missing, run the install script with absolute paths:

```bash
PHPCS_PATH=$(pwd)/vendor/bin/phpcs
$PHPCS_PATH --config-set installed_paths $(pwd)/vendor/wp-coding-standards/wpcs
```

### PHPStan "out of memory"

**Cause**: PHPStan's memory limit too low for large plugins.

```yaml
- name: PHPStan
  run: |
    php -d memory_limit=1G vendor/bin/phpstan analyse \
      --configuration=phpstan.neon \
      --memory-limit=1G \
      ${{ github.workspace }}
```

### Actions timeout before gauntlet finishes

**Cause**: Default GitHub Actions timeout is 6 hours, but individual job timeouts can be set lower. Full gauntlet with skill audits takes 15–30 minutes.

```yaml
jobs:
  full-gauntlet:
    timeout-minutes: 45  # Set to 1.5× expected time
```

### Skill audits exceed API rate limits

**Cause**: Running 6 parallel Claude Code processes, each making multiple API calls, can hit rate limits.

**Fix**: Add delay between skill invocations:

```yaml
- name: Run skill audits with throttle
  run: |
    bash scripts/gauntlet.sh \
      --plugin "$PLUGIN_PATH" \
      --skill-delay 5  # 5 seconds between skill invocations
```

Or run skills sequentially instead of in parallel:

```yaml
- name: Run skill audits sequentially
  env:
    ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
  run: |
    for skill in wp-standards security performance database accessibility code-quality; do
      claude "/$skill Audit ${{ github.workspace }}" > reports/skill-audits/${skill}.md
      sleep 3
    done
```

---

**Next**: Back to [GETTING-STARTED.md](../GETTING-STARTED.md) — or jump to any guide in the [documentation map](../GETTING-STARTED.md#documentation-map).
