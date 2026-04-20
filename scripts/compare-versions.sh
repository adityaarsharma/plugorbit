#!/usr/bin/env bash
# Compare two plugin zip versions — code, performance, DB queries, visual diff
# Usage: bash scripts/compare-versions.sh --old plugin-v1.zip --new plugin-v2.zip --url http://tpa-test.local

set -e

OLD_ZIP=""; NEW_ZIP=""; BASE_URL="http://localhost:8888"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
REPORT="reports/compare-$TIMESTAMP.md"

while [[ "$#" -gt 0 ]]; do
  case $1 in
    --old) OLD_ZIP="$2"; shift ;;
    --new) NEW_ZIP="$2"; shift ;;
    --url) BASE_URL="$2"; shift ;;
  esac
  shift
done

[ -z "$OLD_ZIP" ] || [ -z "$NEW_ZIP" ] && {
  echo "Usage: $0 --old v1.zip --new v2.zip [--url http://site.local]"
  exit 1
}

mkdir -p reports/compare tmp/old tmp/new

OLD_NAME=$(basename "$OLD_ZIP" .zip)
NEW_NAME=$(basename "$NEW_ZIP" .zip)

cat > "$REPORT" << EOF
# Plugin Version Comparison
**Old**: $OLD_NAME
**New**: $NEW_NAME
**Date**: $(date)
**URL**: $BASE_URL

---

EOF

echo "Comparing: $OLD_NAME → $NEW_NAME"
echo "========================================"

# ── PHPCS comparison ──────────────────────────────────────────────────────────
echo ""
echo "[ Code Quality Comparison ]"

unzip -q "$OLD_ZIP" -d tmp/old/
unzip -q "$NEW_ZIP" -d tmp/new/

if command -v phpcs &>/dev/null; then
  OLD_ERRORS=$(phpcs --standard="$(pwd)/config/phpcs.xml" --extensions=php \
    --ignore=vendor,node_modules --report=summary tmp/old/ 2>&1 | \
    grep -oP '\d+(?= ERROR)' | head -1 || echo "0")
  NEW_ERRORS=$(phpcs --standard="$(pwd)/config/phpcs.xml" --extensions=php \
    --ignore=vendor,node_modules --report=summary tmp/new/ 2>&1 | \
    grep -oP '\d+(?= ERROR)' | head -1 || echo "0")
  OLD_WARNS=$(phpcs --standard="$(pwd)/config/phpcs.xml" --extensions=php \
    --ignore=vendor,node_modules --report=summary tmp/old/ 2>&1 | \
    grep -oP '\d+(?= WARNING)' | head -1 || echo "0")
  NEW_WARNS=$(phpcs --standard="$(pwd)/config/phpcs.xml" --extensions=php \
    --ignore=vendor,node_modules --report=summary tmp/new/ 2>&1 | \
    grep -oP '\d+(?= WARNING)' | head -1 || echo "0")

  echo "PHPCS Errors:    $OLD_ERRORS → $NEW_ERRORS   $([ "$NEW_ERRORS" -le "$OLD_ERRORS" ] && echo '✓' || echo '✗')"
  echo "PHPCS Warnings:  $OLD_WARNS → $NEW_WARNS"

  cat >> "$REPORT" << EOF
## Code Quality

| Check | $OLD_NAME | $NEW_NAME | Delta |
|---|---|---|---|
| PHPCS Errors | $OLD_ERRORS | $NEW_ERRORS | $(echo "$NEW_ERRORS - $OLD_ERRORS" | bc) |
| PHPCS Warnings | $OLD_WARNS | $NEW_WARNS | $(echo "$NEW_WARNS - $OLD_WARNS" | bc) |

EOF
fi

# ── Asset size comparison ─────────────────────────────────────────────────────
echo ""
echo "[ Asset Size Comparison ]"

OLD_JS=$(find tmp/old/ -name "*.js" -not -path "*/node_modules/*" | xargs wc -c 2>/dev/null | tail -1 | awk '{print $1}' || echo "0")
NEW_JS=$(find tmp/new/ -name "*.js" -not -path "*/node_modules/*" | xargs wc -c 2>/dev/null | tail -1 | awk '{print $1}' || echo "0")
OLD_CSS=$(find tmp/old/ -name "*.css" | xargs wc -c 2>/dev/null | tail -1 | awk '{print $1}' || echo "0")
NEW_CSS=$(find tmp/new/ -name "*.css" | xargs wc -c 2>/dev/null | tail -1 | awk '{print $1}' || echo "0")

JS_DELTA=$(echo "$NEW_JS - $OLD_JS" | bc)
CSS_DELTA=$(echo "$NEW_CSS - $OLD_CSS" | bc)

echo "JS bundle:  $(echo "scale=1; $OLD_JS/1024" | bc)KB → $(echo "scale=1; $NEW_JS/1024" | bc)KB  (Δ $(echo "scale=1; $JS_DELTA/1024" | bc)KB)"
echo "CSS bundle: $(echo "scale=1; $OLD_CSS/1024" | bc)KB → $(echo "scale=1; $NEW_CSS/1024" | bc)KB  (Δ $(echo "scale=1; $CSS_DELTA/1024" | bc)KB)"

cat >> "$REPORT" << EOF
## Asset Size

| Asset | $OLD_NAME | $NEW_NAME | Delta |
|---|---|---|---|
| JS | $(echo "scale=1; $OLD_JS/1024" | bc)KB | $(echo "scale=1; $NEW_JS/1024" | bc)KB | $(echo "scale=1; $JS_DELTA/1024" | bc)KB |
| CSS | $(echo "scale=1; $OLD_CSS/1024" | bc)KB | $(echo "scale=1; $NEW_CSS/1024" | bc)KB | $(echo "scale=1; $CSS_DELTA/1024" | bc)KB |

EOF

# ── Playwright visual diff ────────────────────────────────────────────────────
echo ""
echo "[ Visual Regression ]"
echo "Run Playwright tests against old version first (set WP_PLUGIN_VERSION=old), then new."
echo "Diffs will appear in: playwright-report/diff/"
echo ""
echo "  WP_PLUGIN_VERSION=old npx playwright test --update-snapshots"
echo "  # (install new zip, restore snapshot)"
echo "  WP_PLUGIN_VERSION=new npx playwright test"

cat >> "$REPORT" << EOF
## Visual Regression
Run Playwright twice (old → baseline, new → compare):
\`\`\`bash
WP_PLUGIN_VERSION=old npx playwright test --update-snapshots
# install new zip + restore Local WP snapshot
WP_PLUGIN_VERSION=new npx playwright test
\`\`\`
Diffs output to \`playwright-report/diff/\`

EOF

# ── Cleanup ───────────────────────────────────────────────────────────────────
rm -rf tmp/old tmp/new

echo ""
echo "========================================"
echo "Comparison report: $REPORT"
