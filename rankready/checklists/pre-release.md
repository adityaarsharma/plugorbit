# RankReady — Pre-Release Checklist
> Run every item before tagging a release for the RankReady plugin.

---

## Code Quality

- [ ] PHP lint: `find ~/Claude/RankReady/rankready -name "*.php" -not -path "*/vendor/*" -exec php -l {} \;` — zero errors
- [ ] phpcs security sniffs — zero `ERROR` level violations (see CLAUDE.md for full command)
- [ ] Version numbers synced in all 3 places: `rankready.php` header, `RR_VERSION` constant, `readme.txt Stable tag`
- [ ] CHANGELOG.md updated with `## [X.Y.Z] - YYYY-MM-DD` section
- [ ] `readme.txt` Changelog block updated with `= X.Y.Z =` section

## RankReady-Specific Checks

- [ ] Plugin folder enforcer active — `upgrader_source_selection` filter present in `rankready.php`
- [ ] PUC configured with `enableReleaseAssets()` — updates pull the zip asset, not the source zip
- [ ] `rr_delete_on_uninstall` defaults to `'off'` — deactivation never deletes data
- [ ] Revalidation webhook uses `hash_equals()` for secret comparison
- [ ] All OpenAI/DataForSEO API keys never appear in REST responses or admin notices

## GitHub Release

- [ ] Branch: `main` only (never a feature branch)
- [ ] GitHub Actions: all checks green before tagging
- [ ] Tag format: `vX.Y.Z` (matches `git tag vX.Y.Z`)
- [ ] Release zip: `rankready-X.Y.Z.zip` with single root folder `rankready/`
- [ ] Verify: `unzip -l rankready-X.Y.Z.zip | head -5` shows `rankready/` as root

## Playwright Smoke Tests

- [ ] Run: `cd ~/Claude/wordpress-qa-master/rankready && npx playwright test`
- [ ] 0 failing tests
- [ ] Dashboard loads with 4 stat cards, 6 feature cards
- [ ] All 6 tabs render without fatal errors
- [ ] Legacy tab slugs redirect correctly (summary → content, api → settings, author → authority)
- [ ] LLMs.txt endpoint returns 200 text/plain
- [ ] Settings tab shows `#rr_api_key` field

## Database

- [ ] No N+1 query patterns (same meta query firing in a loop)
- [ ] New `wp_options` entries have correct `autoload` setting
- [ ] `$wpdb->prepare()` used for all dynamic SQL

## Security

- [ ] All `$_POST`, `$_GET` inputs: `wp_unslash()` + appropriate sanitize function
- [ ] All outputs: `esc_html`, `esc_attr`, `esc_url`, or `wp_kses` — matched to context
- [ ] All admin forms have nonce verification
- [ ] All REST routes have real `permission_callback` (not `__return_true` on mutating routes)
- [ ] No `eval()`, `system()`, `exec()`, `shell_exec()` usage

## Functional Tests (Manual)

- [ ] Fresh install on clean WordPress — activate cleanly, no fatal errors
- [ ] Admin panel loads all 6 tabs without PHP notices (WP_DEBUG=true)
- [ ] AI Summary generates successfully (test OpenAI key required)
- [ ] FAQ generates successfully
- [ ] LLMs.txt page accessible at `/llms.txt`
- [ ] Deactivate — only clears crons and transients, no data deleted
- [ ] Reactivate — all settings and generated content preserved

## Compatibility

- [ ] Tested on PHP 8.1, 8.2 (minimum target: 7.4)
- [ ] Tested with Rank Math active (schema coexistence)
- [ ] Tested with Yoast SEO active
- [ ] No fatal errors with `WP_DEBUG=true` and `WP_DEBUG_DISPLAY=true`

---

**Sign-off**: Only release when all `[ ]` above are checked.  
For hotfix releases, minimum required: PHP lint, activation test, version sync, GitHub Action green.
