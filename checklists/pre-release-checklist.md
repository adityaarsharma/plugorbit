# Pre-Release Checklist
> Run every item before tagging a release for The Plus Addons, NexterWP, or any POSIMYTH plugin.

---

## Code Quality

- [ ] `bash scripts/gauntlet.sh --plugin /path/to/plugin` — zero failures
- [ ] PHP lint: no syntax errors in any `.php` file
- [ ] PHPCS: zero `ERROR` level violations
- [ ] PHPStan: no level-5 type errors
- [ ] Version numbers synced in all 3 places (plugin header, constant, readme.txt)
- [ ] CHANGELOG updated with `## [X.Y.Z] - YYYY-MM-DD` section

## Database

- [ ] Query count per page not regressed vs previous release (`bash scripts/db-profile.sh`)
- [ ] No queries >100ms on key pages
- [ ] No N+1 query patterns (same query firing in a loop)
- [ ] New `wp_options` entries have correct `autoload` setting

## Performance

- [ ] Lighthouse performance score ≥ 75 (target: 85+)
- [ ] No CSS/JS 404s
- [ ] JS bundle size not increased >10% without justification
- [ ] New assets enqueued conditionally (not on every page)
- [ ] No synchronous external HTTP calls blocking page render

## Security

- [ ] All user-facing inputs sanitized (`sanitize_text_field`, `absint`, etc.)
- [ ] All outputs escaped (`esc_html`, `esc_attr`, `wp_kses_post`)
- [ ] All forms and AJAX handlers have nonce verification
- [ ] All REST endpoints have `permission_callback`
- [ ] No direct DB queries without `$wpdb->prepare()`
- [ ] No `eval()`, `system()`, `exec()`, `shell_exec()` usage

## Functional Tests

- [ ] Playwright suite: 0 failing tests
- [ ] Admin panel loads without PHP fatal errors
- [ ] Plugin activates cleanly on a fresh WordPress install
- [ ] Plugin deactivates cleanly (no fatal on deactivation hook)
- [ ] Plugin uninstalls cleanly (data removed if opted in)

## UI/UX

- [ ] [UI/UX Checklist](ui-ux-checklist.md) reviewed
- [ ] No horizontal scroll at 375px, 768px, 1440px
- [ ] No broken images
- [ ] Hit areas ≥ 44×44px on mobile

## Compatibility

- [ ] Tested on PHP 7.4, 8.0, 8.1, 8.2
- [ ] Tested on WordPress latest - 1 version
- [ ] Tested with conflicting plugins active: Rank Math, Yoast, WooCommerce, Elementor
- [ ] No fatal errors with `WP_DEBUG=true`

## Release Process

- [ ] Branch: `release/vX.Y.Z` (never push directly to main)
- [ ] GitHub Actions: all checks green
- [ ] Plugin zip: root folder is correct name (e.g. `the-plus-addons-for-elementor/`)
- [ ] Zip tested: fresh install → activate → spot-check
- [ ] Release notes written (non-technical, user-focused)

---

**Sign-off**: Only release when all `[ ]` above are checked. For hotfix releases, minimum required: PHP lint, activation test, deactivation test.
