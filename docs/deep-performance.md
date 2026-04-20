# Deep Performance — Beyond Lighthouse

Lighthouse scores the final rendered page. PlugOrbit goes deeper — into your **backend hooks**, **frontend bundle waste**, and the **editor experience** (Elementor, Gutenberg). Lighthouse says "your page is slow." These tools tell you **which line of code is slow**.

---

## 1. Backend — Which PHP Hook Is Slow?

Lighthouse can't see server-side time. Use **Query Monitor's Hook Timing** panel + WP-CLI profiling.

### Hook Timing via Query Monitor

1. Site active at `http://localhost:8881` (Query Monitor auto-installed)
2. Load the test page while logged in as admin
3. Click the QM bar → **Hooks & Actions** → sort by **Time (ms)**
4. Find your plugin's namespace in the **Component** column

Fix anything of yours taking >50ms on `init`, `wp_loaded`, `wp_head`, `wp_footer`.

### Automated Hook Profiling

```bash
# Inside wp-env (fast, scriptable)
wp-env run cli wp eval '
  add_action("shutdown", function() {
    global $wp_filter;
    $slow = [];
    foreach ($wp_filter as $hook => $obj) {
      foreach ($obj->callbacks as $priority => $cbs) {
        foreach ($cbs as $cb) {
          $name = is_array($cb["function"])
            ? (is_object($cb["function"][0]) ? get_class($cb["function"][0]) : $cb["function"][0]) . "::" . $cb["function"][1]
            : $cb["function"];
          $slow[] = $hook . " → " . $name;
        }
      }
    }
    file_put_contents("/tmp/hooks.txt", implode("\n", array_unique($slow)));
  });
  wp_head();
  wp_footer();
'
```

### Xdebug Profiler (Cachegrind output)

For **per-function timing** — use Xdebug in profile mode:

```bash
# Enable inside wp-env container
wp-env run cli bash -c 'echo "xdebug.mode=profile" >> /usr/local/etc/php/conf.d/xdebug.ini && kill -USR2 1'

# Load a page, then grab the trace
wp-env run cli bash -c 'cp /tmp/cachegrind.out.* /wordpress/wp-content/trace.out'

# View with Qcachegrind (Mac: brew install qcachegrind)
qcachegrind trace.out
```

### PlugOrbit Skill Prompt

```
/performance-engineer
Profile backend hooks for plugin [path]:
- Rank every action/filter callback by time
- Flag any >50ms on init/wp_loaded/wp_head
- Look for sync HTTP, slow DB queries, file I/O on hot paths
- Suggest concrete fixes with file:line references
Input: reports/qa-report-*.md + the QM hooks export
```

---

## 2. Frontend — Beyond Lighthouse Score

Lighthouse gives you LCP/CLS/TBT but not *why*. Go deeper:

### Bundle Analysis — What's Actually in Your JS?

```bash
# Inspect bundle composition
npx source-map-explorer path/to/plugin/assets/js/main.js

# Find unused code
npx unused-files-webpack-plugin ~/plugins/my-plugin
```

### Unused CSS Detection

```bash
# Install once
npm install -g purgecss

# Run against your pages
purgecss \
  --css ~/plugins/my-plugin/assets/css/frontend.css \
  --content "http://localhost:8881" \
  --output reports/unused-css/

# Shows % of CSS that's actually used
```

### Coverage Tool (Chrome DevTools API)

PlugOrbit wires this via Playwright:

```js
// Already in tests/playwright/templates/
await page.coverage.startJSCoverage();
await page.coverage.startCSSCoverage();
await page.goto('http://localhost:8881/');
const [jsCov, cssCov] = await Promise.all([
  page.coverage.stopJSCoverage(),
  page.coverage.stopCSSCoverage(),
]);
// Reports per-file % used
```

### Long Tasks Detection

Block the main thread >50ms = janky scroll, slow interactivity:

```js
// playwright spec
const longTasks = await page.evaluate(() => new Promise(resolve => {
  const tasks = [];
  new PerformanceObserver(list => tasks.push(...list.getEntries())).observe({ entryTypes: ['longtask'] });
  setTimeout(() => resolve(tasks), 3000);
}));
// Flag any task >200ms
```

### PlugOrbit Skill Prompt

```
/frontend-design
Profile frontend assets shipped by [path]:
- JS bundle size vs actual features used (source-map-explorer output)
- Unused CSS % (purgecss output)
- Render-blocking scripts (Playwright trace)
- Long tasks >200ms on main thread
- Missing image width/height (CLS)
- Font loading strategy audit
Suggest splits, defers, and removals with estimated size savings.
```

---

## 3. Elementor Editor Performance

This is where most Elementor addon bugs live — editor feels slow, widgets lag to insert, panel freezes when you have 50 widgets.

### What to Measure

| Metric | Good | Bad | How to Measure |
|---|---|---|---|
| **Editor ready time** | < 3s | > 6s | `window.elementor` ready event |
| **Widget panel populated** | < 500ms after ready | > 1.5s | `elementor.panel` events |
| **Widget insert → render** | < 300ms | > 800ms | Drag-drop then MutationObserver |
| **Memory after 20 widgets** | < 100MB growth | > 250MB | `performance.memory.usedJSHeapSize` |
| **Console spam** | 0 messages from your plugin | Any | `console.on("*")` filter |

### Run the Editor Perf Harness

```bash
bash scripts/editor-perf.sh
```

This Playwright harness:
1. Opens `http://localhost:8881/wp-admin/post-new.php?post_type=page` in Elementor mode
2. Times every phase from page load → widget panel ready
3. Inserts each of your plugin's widgets and times the render
4. Measures memory growth
5. Writes `reports/editor-perf-{timestamp}.json`

### Interpret the Results

```json
{
  "editorReadyMs": 2840,
  "panelPopulatedMs": 410,
  "widgets": [
    { "name": "Mega Menu",   "insertMs": 280, "renderMs": 190, "memoryMB": 12.4 },
    { "name": "Hero Section","insertMs": 950, "renderMs": 420, "memoryMB": 38.1 }
  ],
  "consoleErrors": [],
  "consoleWarnings": 2
}
```

Any `insertMs > 800` or `memoryMB > 30` per widget is a red flag.

### PlugOrbit Skill Prompt

```
/performance-engineer
Analyze Elementor editor perf for plugin [path].
Input: reports/editor-perf-*.json

For each slow widget (>800ms insert):
- Find the widget's PHP `render()` and JS controls
- Flag heavy operations in construction (loops, DB queries, asset loads)
- Suggest lazy-loading for non-critical parts
- Recommend editor-only vs preview-only conditional logic

For memory-heavy widgets (>30MB):
- Look for leaked event listeners
- Check for unbounded caches in the widget JS
- Flag any jQuery plugin loaded that's unused
```

---

## 4. Gutenberg Block Editor Performance

Same principles, different tooling:

### Measure Block Insert Latency

```js
// Playwright spec
const start = performance.now();
await page.click('button[aria-label="Add block"]');
await page.fill('input[placeholder="Search"]', 'My Block');
await page.click(`button:has-text("My Block")`);
await page.waitForSelector(`[data-type*="my-plugin/"]`);
const insertMs = performance.now() - start;
```

### Block Render Performance

Use React DevTools Profiler inside the editor — record a session inserting 10 blocks → exports a flame graph showing which of your components re-render too often.

### PlugOrbit Skill Prompt

```
/performance-engineer
Analyze Gutenberg block perf for plugin [path].
Check:
- block.json transform declarations (should use file: paths for code splitting)
- Editor-only dependencies not loaded on frontend
- useMemo / useCallback usage in heavy InspectorControls
- Over-broad @wordpress/data store subscriptions
- Inline styles vs CSS classes (inline re-renders)
```

---

## 5. Putting It Together — Full Perf Pass

Run everything in sequence:

```bash
# 1. Baseline page perf
lighthouse http://localhost:8881 --output=html --output-path=reports/lh-baseline.html

# 2. Backend hook timing
bash scripts/db-profile.sh                          # DB side
wp-env run cli wp profile stage --all                # if wp-cli-profile installed

# 3. Frontend bundle analysis
npx source-map-explorer ~/plugins/my-plugin/assets/js/*.js
purgecss --css ~/plugins/my-plugin/assets/css/*.css --content http://localhost:8881

# 4. Editor perf (Elementor)
bash scripts/editor-perf.sh

# 5. Claude Code orchestrated analysis
claude "/antigravity-skill-orchestrator
Full performance audit for ~/plugins/my-plugin.
Inputs: reports/lh-baseline.html, reports/db-profile-*.txt, reports/editor-perf-*.json
Give me a ranked fix list with estimated time savings per fix."
```

---

## Thresholds That Block a Release

| Metric | Block? |
|---|---|
| Lighthouse perf < 75 | Warn |
| Lighthouse perf < 60 | Block |
| DB queries > 60/page | Warn |
| Any backend hook > 200ms | Block |
| Any widget insert > 1.5s | Block |
| Memory growth > 250MB over 20 widgets | Block |
| Unused JS > 50% | Warn |
| Long tasks > 500ms on main thread | Block |
