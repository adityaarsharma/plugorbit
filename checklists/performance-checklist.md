# Performance Checklist

## Core Web Vitals Targets

| Metric | Target | Warning | Bad |
|---|---|---|---|
| LCP (Largest Contentful Paint) | < 2.5s | 2.5–4s | > 4s |
| FCP (First Contentful Paint) | < 1.8s | 1.8–3s | > 3s |
| TBT (Total Blocking Time) | < 200ms | 200–600ms | > 600ms |
| CLS (Cumulative Layout Shift) | < 0.1 | 0.1–0.25 | > 0.25 |
| TTI (Time to Interactive) | < 3.8s | 3.8–7.3s | > 7.3s |

## Asset Loading

- [ ] CSS files are enqueued conditionally (only on pages that use the plugin/widget)
- [ ] JS files are enqueued conditionally (`is_singular()`, specific post types, etc.)
- [ ] Assets use versioned filenames or `filemtime()` for cache busting
- [ ] No assets loaded from external CDNs without fallback
- [ ] Render-blocking CSS in `<head>` is minimal — critical CSS only
- [ ] Non-critical JS uses `defer` or `async`

## Images

- [ ] All plugin-provided images have `width` and `height` attributes (prevents CLS)
- [ ] Plugin images use WebP format where possible
- [ ] No images larger than they appear on screen (oversized)
- [ ] Lazy loading on below-fold images (`loading="lazy"`)

## Database (see database-profiling.md)

- [ ] No autoloaded options >10KB
- [ ] No queries firing on every page load that could be cached
- [ ] Expensive queries wrapped in transients

## PHP Performance

- [ ] No synchronous HTTP requests on frontend page load (`wp_remote_get()` blocks)
- [ ] No file I/O operations on every request
- [ ] Heavy operations run via `wp_cron` or REST API, not inline
- [ ] Object caching used where available (`wp_cache_get/set`)

## Running Lighthouse Locally

```bash
# Against wp-env site
lighthouse http://localhost:8881 \
  --output=html \
  --output-path=reports/lighthouse/report.html \
  --chrome-flags="--headless"

# Open report
open reports/lighthouse/report.html
```

## Running via DataForSEO (staging/production)

Use the DataForSEO Lighthouse MCP tool for public URLs:
```
mcp__dfs-mcp__on_page_lighthouse with url: https://staging.theplusaddons.com
```
