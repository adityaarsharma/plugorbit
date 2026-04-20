# NexterWP — Pre-Release Checklist
> Run every item before tagging a release for NexterWP / Nexter Blocks / Nexter Extension.

---

## Code Quality

- [ ] PHP lint: zero syntax errors across all `.php` files
- [ ] PHPCS: zero `ERROR` level violations (WordPress standards)
- [ ] Version numbers synced: plugin header, version constant, readme.txt Stable tag
- [ ] CHANGELOG updated with `## [X.Y.Z] - YYYY-MM-DD` section

## Database

- [ ] Query count not regressed vs previous release
- [ ] No N+1 query patterns
- [ ] New `wp_options` entries have correct `autoload` setting

## Performance

- [ ] No CSS/JS 404s
- [ ] JS bundle size not increased >10% without justification
- [ ] New assets enqueued conditionally (not on every page)

## Security

- [ ] All user inputs sanitized
- [ ] All outputs escaped
- [ ] All forms and AJAX handlers have nonce verification
- [ ] All REST endpoints have `permission_callback`
- [ ] No direct DB queries without `$wpdb->prepare()`

## Playwright Smoke Tests

- [ ] Run: `cd ~/Claude/wordpress-qa-master/nexterwp && npx playwright test`
- [ ] 0 failing tests
- [ ] Plugin activates cleanly
- [ ] Block editor loads without errors
- [ ] No PHP fatal errors on key admin pages

## Functional Tests (Manual)

- [ ] Fresh install on clean WordPress — activate cleanly
- [ ] Block editor: Nexter blocks appear in block inserter
- [ ] Front-end: no JS errors on rendered pages
- [ ] Deactivate cleanly (no fatal on deactivation hook)
- [ ] No fatal errors with `WP_DEBUG=true`

## Compatibility

- [ ] Tested on PHP 8.1, 8.2
- [ ] Tested on WordPress latest and latest - 1
- [ ] Tested with Rank Math active
- [ ] Tested with Yoast SEO active

## Release Process

- [ ] GitHub Actions: all checks green
- [ ] Plugin zip: root folder is correct name
- [ ] Zip tested: fresh install → activate → spot-check

---

**Sign-off**: Only release when all `[ ]` above are checked.
