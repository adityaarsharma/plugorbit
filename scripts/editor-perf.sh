#!/usr/bin/env bash
# PlugOrbit — Elementor / Gutenberg Editor Performance Harness
# Measures editor ready time, widget insert latency, memory growth.
#
# Usage:
#   bash scripts/editor-perf.sh                    # reads qa.config.json
#   bash scripts/editor-perf.sh --url http://localhost:8881 --editor elementor

set -e

WP_URL="${WP_TEST_URL:-http://localhost:8881}"
EDITOR="elementor"   # or "gutenberg"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
REPORT="reports/editor-perf-$TIMESTAMP.json"

while [[ "$#" -gt 0 ]]; do
  case $1 in
    --url)    WP_URL="$2";  shift ;;
    --editor) EDITOR="$2";  shift ;;
  esac
  shift
done

if [ -f "qa.config.json" ]; then
  WP_URL=$(python3 -c "import json; print(json.load(open('qa.config.json'))['environment']['testUrl'])" 2>/dev/null || echo "$WP_URL")
  PLUGIN_TYPE=$(python3 -c "import json; print(json.load(open('qa.config.json'))['plugin']['type'])" 2>/dev/null || echo "")
  [ "$PLUGIN_TYPE" = "elementor-addon" ] && EDITOR="elementor"
  [ "$PLUGIN_TYPE" = "gutenberg-blocks" ] && EDITOR="gutenberg"
fi

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'

mkdir -p reports tests/playwright/editor-perf

echo ""
echo -e "${BOLD}PlugOrbit — Editor Performance Harness${NC}"
echo "URL: $WP_URL | Editor: $EDITOR"
echo "========================================"

# Write a minimal Playwright spec on the fly
cat > tests/playwright/editor-perf/run.spec.js <<'SPEC'
const { test } = require('@playwright/test');
const fs = require('fs');
const path = require('path');

const WP_URL  = process.env.WP_TEST_URL || 'http://localhost:8881';
const EDITOR  = process.env.EDITOR || 'elementor';
const REPORT  = process.env.REPORT_PATH;

test('measure editor perf', async ({ page }) => {
  const result = {
    url: WP_URL,
    editor: EDITOR,
    editorReadyMs: null,
    panelPopulatedMs: null,
    widgets: [],
    consoleErrors: [],
    consoleWarnings: 0,
    memoryStart: null,
    memoryEnd: null,
  };

  page.on('console', m => {
    if (m.type() === 'error')   result.consoleErrors.push(m.text());
    if (m.type() === 'warning') result.consoleWarnings++;
  });

  const startTime = Date.now();

  if (EDITOR === 'elementor') {
    await page.goto(`${WP_URL}/wp-admin/post-new.php?post_type=page`);
    await page.waitForLoadState('networkidle');

    const switchBtn = page.locator('#elementor-switch-mode-button');
    if (await switchBtn.isVisible().catch(() => false)) await switchBtn.click();

    await page.waitForSelector('#elementor-panel', { timeout: 30000 });
    result.editorReadyMs = Date.now() - startTime;

    const panelStart = Date.now();
    await page.waitForSelector('#elementor-panel-elements-wrapper .elementor-element', { timeout: 15000 });
    result.panelPopulatedMs = Date.now() - panelStart;

    result.memoryStart = await page.evaluate(() => performance.memory?.usedJSHeapSize || 0);

    // Enumerate widgets in panel and insert each (cap at 10 for timing)
    const widgetNames = await page.$$eval('#elementor-panel-elements-wrapper .elementor-element', els =>
      els.slice(0, 10).map(e => e.getAttribute('data-element_type') || e.textContent?.trim().slice(0, 40)).filter(Boolean)
    );

    for (const name of widgetNames) {
      const insertStart = Date.now();
      try {
        await page.locator(`#elementor-panel-elements-wrapper .elementor-element:has-text("${name}")`).first().click({ timeout: 5000 });
        await page.waitForTimeout(500);
      } catch (e) { continue; }
      const insertMs = Date.now() - insertStart;
      const mem = await page.evaluate(() => performance.memory?.usedJSHeapSize || 0);
      result.widgets.push({ name, insertMs, memoryMB: +((mem - result.memoryStart) / 1048576).toFixed(1) });
    }

    result.memoryEnd = await page.evaluate(() => performance.memory?.usedJSHeapSize || 0);

  } else {
    // Gutenberg
    await page.goto(`${WP_URL}/wp-admin/post-new.php`);
    await page.waitForSelector('.edit-post-header', { timeout: 30000 });
    result.editorReadyMs = Date.now() - startTime;

    const close = page.locator('button[aria-label="Close"]');
    if (await close.isVisible().catch(() => false)) await close.click();

    const panelStart = Date.now();
    await page.click('button[aria-label="Toggle block inserter"]');
    await page.waitForSelector('.block-editor-inserter__block-list', { timeout: 10000 });
    result.panelPopulatedMs = Date.now() - panelStart;

    result.memoryStart = await page.evaluate(() => performance.memory?.usedJSHeapSize || 0);

    const blockNames = await page.$$eval('.block-editor-block-types-list__item', els =>
      els.slice(0, 10).map(e => e.getAttribute('aria-label') || e.textContent?.trim().slice(0, 40)).filter(Boolean)
    );

    for (const name of blockNames) {
      const insertStart = Date.now();
      try {
        await page.locator(`.block-editor-block-types-list__item:has-text("${name}")`).first().click({ timeout: 5000 });
        await page.waitForTimeout(400);
      } catch (e) { continue; }
      const insertMs = Date.now() - insertStart;
      const mem = await page.evaluate(() => performance.memory?.usedJSHeapSize || 0);
      result.widgets.push({ name, insertMs, memoryMB: +((mem - result.memoryStart) / 1048576).toFixed(1) });
    }

    result.memoryEnd = await page.evaluate(() => performance.memory?.usedJSHeapSize || 0);
  }

  result.totalMemoryGrowthMB = +((result.memoryEnd - result.memoryStart) / 1048576).toFixed(1);

  fs.mkdirSync(path.dirname(REPORT), { recursive: true });
  fs.writeFileSync(REPORT, JSON.stringify(result, null, 2));
  console.log('Report:', REPORT);
});
SPEC

# Run it
REPORT_PATH="$REPORT" WP_TEST_URL="$WP_URL" EDITOR="$EDITOR" \
  npx playwright test tests/playwright/editor-perf/run.spec.js --reporter=line

if [ -f "$REPORT" ]; then
  echo ""
  echo -e "${GREEN}Report saved:${NC} $REPORT"
  echo ""
  echo -e "${BOLD}Summary:${NC}"
  python3 -c "
import json
d = json.load(open('$REPORT'))
print(f\"  Editor ready:      {d['editorReadyMs']}ms\")
print(f\"  Panel populated:   {d['panelPopulatedMs']}ms\")
print(f\"  Total mem growth:  {d['totalMemoryGrowthMB']}MB\")
print(f\"  Console errors:    {len(d['consoleErrors'])}\")
print(f\"  Console warnings:  {d['consoleWarnings']}\")
print(f\"  Widgets measured:  {len(d['widgets'])}\")
print()
slow = [w for w in d['widgets'] if w['insertMs'] > 800]
if slow:
    print(f\"  ⚠ SLOW widgets (>800ms insert):\")
    for w in slow: print(f\"      {w['name']}: {w['insertMs']}ms / {w['memoryMB']}MB\")
heavy = [w for w in d['widgets'] if w['memoryMB'] > 30]
if heavy:
    print(f\"  ⚠ MEMORY-HEAVY widgets (>30MB):\")
    for w in heavy: print(f\"      {w['name']}: {w['memoryMB']}MB\")
"
  echo ""
  echo "Next: feed this to /performance-engineer for analysis (see docs/deep-performance.md)"
fi
