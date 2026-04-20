# Playwright Test Templates

Copy any template into a new directory named after your plugin and customize.

```bash
# Example — Elementor addon
cp -r tests/playwright/templates/elementor-addon tests/playwright/my-elementor-plugin
# Then edit the spec files: replace CSS selectors, admin URLs, widget names
```

## Available Templates

| Template | For Plugin Type | Key Tests |
|---|---|---|
| `elementor-addon/` | Elementor widget/extension | Widget panel, editor render, frontend output |
| `gutenberg-block/` | Gutenberg block plugin | Block inserter, save+reload, block.json validation |
| `seo-plugin/` | SEO plugin | Meta tag output, sitemap, schema injection, admin UI |
| `woocommerce/` | WooCommerce extension | Store page render, checkout flow, WC hook compat |
| `theme/` | WordPress theme | Theme activation, customizer, block templates, FSE |
| `generic-plugin/` | Any WP plugin | Admin menu, settings save, frontend smoke, no PHP errors |

## How Templates Work

Each template uses `process.env.WP_TEST_URL` so they work with any test site. Set via `.env.test` (created by `setup/init.sh`) or inline:

```bash
WP_TEST_URL=http://my-plugin-test.local npx playwright test tests/playwright/my-plugin/
```

## Common Assertions (all templates share)

- **No console errors** from your plugin's namespace
- **No 404s** on plugin-enqueued assets
- **No PHP notices/warnings** visible in output
- **Accessibility** via @axe-core/playwright — WCAG 2.1 AA
- **Visual regression** — `toHaveScreenshot()` on the key views
