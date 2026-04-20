#!/usr/bin/env bash
# WordPress QA Master — Full Pre-Release Gauntlet
# Usage: bash scripts/gauntlet.sh --plugin /path/to/plugin [--env local|ci] [--mode full|quick]

set -e

PLUGIN_PATH=""
ENV="local"
MODE="full"
REPORT_DIR="reports"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
REPORT_FILE="$REPORT_DIR/qa-report-$TIMESTAMP.md"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'

ok()     { echo -e "${GREEN}✓ $1${NC}"; }
warn()   { echo -e "${YELLOW}⚠ $1${NC}"; }
fail()   { echo -e "${RED}✗ $1${NC}"; }
header() { echo -e "\n${BOLD}[ $1 ]${NC}"; }
log()    { echo "$1" >> "$REPORT_FILE"; }

# Parse args
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --plugin) PLUGIN_PATH="$2"; shift ;;
    --env)    ENV="$2"; shift ;;
    --mode)   MODE="$2"; shift ;;
  esac
  shift
done

[ -z "$PLUGIN_PATH" ] && { echo "Usage: $0 --plugin /path/to/plugin"; exit 1; }
[ ! -d "$PLUGIN_PATH" ] && { echo "Plugin path not found: $PLUGIN_PATH"; exit 1; }

mkdir -p "$REPORT_DIR"
PLUGIN_NAME=$(basename "$PLUGIN_PATH")

# Init report
cat > "$REPORT_FILE" << EOF
# WordPress QA Gauntlet Report
**Plugin**: $PLUGIN_NAME
**Date**: $(date)
**Mode**: $MODE / $ENV
**Path**: $PLUGIN_PATH

---

EOF

echo ""
echo -e "${BOLD}WordPress QA Master — Pre-Release Gauntlet${NC}"
echo -e "Plugin: ${YELLOW}$PLUGIN_NAME${NC} | Mode: $MODE | Env: $ENV"
echo "================================================"

PASS=0; WARN=0; FAIL=0

# ── STEP 1: PHP LINT ──────────────────────────────────────────────────────────
header "Step 1: PHP Lint"
log "## Step 1: PHP Lint"

PHP_ERRORS=$(find "$PLUGIN_PATH" -name "*.php" \
  -not -path "*/vendor/*" -not -path "*/node_modules/*" \
  -exec php -l {} \; 2>&1 | grep -v "No syntax errors" | grep -v "^$" || true)

if [ -z "$PHP_ERRORS" ]; then
  ok "PHP lint — no syntax errors"
  log "- ✓ No PHP syntax errors"
  ((PASS++))
else
  fail "PHP lint — ERRORS FOUND:"
  echo "$PHP_ERRORS"
  log "- ✗ PHP syntax errors:\n\`\`\`\n$PHP_ERRORS\n\`\`\`"
  ((FAIL++))
fi

# ── STEP 2: WORDPRESS CODING STANDARDS ───────────────────────────────────────
header "Step 2: WordPress Coding Standards (PHPCS)"
log "## Step 2: PHPCS / WPCS"

if command -v phpcs &>/dev/null; then
  PHPCS_OUT=$(phpcs \
    --standard="$(pwd)/config/phpcs.xml" \
    --extensions=php \
    --ignore=vendor,node_modules \
    --report=summary \
    "$PLUGIN_PATH" 2>&1 || true)

  ERROR_COUNT=$(echo "$PHPCS_OUT" | grep -oP '\d+(?= ERROR)' | head -1 || echo "0")
  WARN_COUNT=$(echo "$PHPCS_OUT"  | grep -oP '\d+(?= WARNING)' | head -1 || echo "0")

  if [ "$ERROR_COUNT" -eq 0 ] && [ "$WARN_COUNT" -lt 10 ]; then
    ok "PHPCS — $ERROR_COUNT errors, $WARN_COUNT warnings"
    log "- ✓ PHPCS: $ERROR_COUNT errors, $WARN_COUNT warnings"
    ((PASS++))
  elif [ "$ERROR_COUNT" -gt 0 ]; then
    fail "PHPCS — $ERROR_COUNT errors, $WARN_COUNT warnings"
    log "- ✗ PHPCS: $ERROR_COUNT errors, $WARN_COUNT warnings"
    ((FAIL++))
  else
    warn "PHPCS — $WARN_COUNT warnings (review needed)"
    log "- ⚠ PHPCS: $WARN_COUNT warnings"
    ((WARN++))
  fi
else
  warn "phpcs not installed — skipping. Run: composer global require squizlabs/php_codesniffer"
  log "- ⚠ PHPCS: skipped (not installed)"
  ((WARN++))
fi

# ── STEP 3: PHPSTAN STATIC ANALYSIS ──────────────────────────────────────────
header "Step 3: PHPStan Static Analysis"
log "## Step 3: PHPStan"

if command -v phpstan &>/dev/null; then
  PHPSTAN_OUT=$(phpstan analyse \
    --configuration="$(pwd)/config/phpstan.neon" \
    --no-progress \
    "$PLUGIN_PATH/includes" 2>&1 || true)

  if echo "$PHPSTAN_OUT" | grep -q "No errors"; then
    ok "PHPStan — no errors"
    log "- ✓ PHPStan: clean"
    ((PASS++))
  else
    PHPSTAN_ERRORS=$(echo "$PHPSTAN_OUT" | tail -5)
    warn "PHPStan — issues found (review)"
    log "- ⚠ PHPStan:\n\`\`\`\n$PHPSTAN_ERRORS\n\`\`\`"
    ((WARN++))
  fi
else
  warn "phpstan not installed — skipping"
  log "- ⚠ PHPStan: skipped"
  ((WARN++))
fi

# ── STEP 4: ASSET WEIGHT ─────────────────────────────────────────────────────
header "Step 4: Asset Weight Audit"
log "## Step 4: Asset Weight"

JS_SIZE=$(find "$PLUGIN_PATH" -name "*.js" -not -path "*/node_modules/*" \
  -not -name "*.min.js" 2>/dev/null | xargs wc -c 2>/dev/null | tail -1 | awk '{print $1}' || echo "0")
CSS_SIZE=$(find "$PLUGIN_PATH" -name "*.css" -not -path "*/node_modules/*" 2>/dev/null \
  | xargs wc -c 2>/dev/null | tail -1 | awk '{print $1}' || echo "0")
JS_MB=$(echo "scale=2; $JS_SIZE/1048576" | bc 2>/dev/null || echo "?")
CSS_KB=$(echo "scale=0; $CSS_SIZE/1024" | bc 2>/dev/null || echo "?")

ok "JS total: ${JS_MB}MB | CSS total: ${CSS_KB}KB"
log "- JS total: ${JS_MB}MB | CSS total: ${CSS_KB}KB"
((PASS++))

# ── STEP 5: PLAYWRIGHT FUNCTIONAL TESTS ──────────────────────────────────────
header "Step 5: Playwright Functional + Visual Tests"
log "## Step 5: Playwright"

if command -v npx &>/dev/null && [ -f "playwright.config.js" -o -f "tests/playwright/playwright.config.js" ]; then
  PLAYWRIGHT_OUT=$(npx playwright test tests/playwright/ \
    --reporter=line 2>&1 || true)

  PASSED=$(echo "$PLAYWRIGHT_OUT" | grep -oP '\d+(?= passed)' | head -1 || echo "0")
  FAILED=$(echo "$PLAYWRIGHT_OUT" | grep -oP '\d+(?= failed)' | head -1 || echo "0")

  if [ "$FAILED" -eq 0 ]; then
    ok "Playwright — $PASSED tests passed"
    log "- ✓ Playwright: $PASSED passed, 0 failed"
    ((PASS++))
  else
    fail "Playwright — $FAILED failed (out of $((PASSED+FAILED)))"
    log "- ✗ Playwright: $FAILED failed, $PASSED passed"
    ((FAIL++))
  fi
else
  warn "Playwright tests not configured — skipping"
  log "- ⚠ Playwright: skipped (not configured)"
  ((WARN++))
fi

# ── STEP 6: LIGHTHOUSE PERFORMANCE ───────────────────────────────────────────
if [ "$MODE" = "full" ]; then
  header "Step 6: Lighthouse Performance"
  log "## Step 6: Lighthouse"

  WP_LOCAL_URL="${WP_TEST_URL:-http://localhost:8888}"

  if command -v lighthouse &>/dev/null; then
    mkdir -p reports/lighthouse
    LHCI_OUT=$(lighthouse "$WP_LOCAL_URL" \
      --output=json \
      --output-path="reports/lighthouse/lh-$TIMESTAMP.json" \
      --chrome-flags="--headless --no-sandbox" \
      --quiet 2>&1 || true)

    if [ -f "reports/lighthouse/lh-$TIMESTAMP.json" ]; then
      SCORE=$(python3 -c "
import json
with open('reports/lighthouse/lh-$TIMESTAMP.json') as f:
    d = json.load(f)
print(int(d['categories']['performance']['score']*100))
" 2>/dev/null || echo "?")

      if [ "$SCORE" != "?" ] && [ "$SCORE" -ge 80 ]; then
        ok "Lighthouse performance: $SCORE/100"
        log "- ✓ Lighthouse: $SCORE/100"
        ((PASS++))
      elif [ "$SCORE" != "?" ]; then
        warn "Lighthouse performance: $SCORE/100 (target: 80+)"
        log "- ⚠ Lighthouse: $SCORE/100"
        ((WARN++))
      fi
    fi
  else
    warn "Lighthouse not installed — skipping"
    log "- ⚠ Lighthouse: skipped"
    ((WARN++))
  fi
fi

# ── STEP 7: DB PROFILING (local only) ─────────────────────────────────────────
if [ "$MODE" = "full" ] && [ "$ENV" = "local" ]; then
  header "Step 7: Database Profiling"
  log "## Step 7: Database"
  bash scripts/db-profile.sh 2>/dev/null || warn "DB profiling failed — see docs/database-profiling.md"
  log "- See reports/db-profile-$TIMESTAMP.txt"
fi

# ── FINAL REPORT ──────────────────────────────────────────────────────────────
header "Results"
log "---"
log "## Summary"
log "- ✓ Passed: $PASS"
log "- ⚠ Warnings: $WARN"
log "- ✗ Failed: $FAIL"

echo ""
echo "================================="
echo -e "${BOLD}Results${NC}: ${GREEN}$PASS passed${NC} | ${YELLOW}$WARN warnings${NC} | ${RED}$FAIL failed${NC}"
echo "Report: $REPORT_FILE"
echo ""

if [ "$FAIL" -gt 0 ]; then
  echo -e "${RED}✗ GAUNTLET FAILED — do not release${NC}"
  exit 1
elif [ "$WARN" -gt 0 ]; then
  echo -e "${YELLOW}⚠ GAUNTLET PASSED WITH WARNINGS — review before release${NC}"
  exit 0
else
  echo -e "${GREEN}✓ GAUNTLET PASSED — ready to release${NC}"
  exit 0
fi
