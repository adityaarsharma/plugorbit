# Database Profiling Guide
> Catch N+1 queries, slow queries, and autoload bloat before they reach production

---

## Tools

| Tool | What It Catches | How to Use |
|---|---|---|
| **Query Monitor** | All DB queries, slow queries, duplicates, N+1s | Install plugin, view in admin bar |
| **MySQL Slow Query Log** | Queries >50ms threshold | Enable in Local WP site settings |
| **SAVEQUERIES** | Total query count per request | Add `define('SAVEQUERIES', true)` to wp-config |
| **`db-profile.sh`** | Automated query count per page | `bash scripts/db-profile.sh` |

---

## What to Check Per Page

### 1. Total Query Count

Good benchmarks for WordPress pages:

| Page Type | Acceptable | Warning | Bad |
|---|---|---|---|
| Homepage | < 30 | 30–60 | > 60 |
| Single post | < 25 | 25–50 | > 50 |
| Archive | < 40 | 40–80 | > 80 |
| Admin panel | < 50 | 50–100 | > 100 |

### 2. N+1 Queries

Sign: same query repeated many times with different IDs.

```sql
-- N+1 example (bad)
SELECT * FROM wp_postmeta WHERE post_id = 1
SELECT * FROM wp_postmeta WHERE post_id = 2
SELECT * FROM wp_postmeta WHERE post_id = 3
-- ... 50 more times

-- Fixed with a single query
SELECT * FROM wp_postmeta WHERE post_id IN (1,2,3,...,50)
```

Query Monitor groups duplicate queries — look for `[X duplicates]` in the DB panel.

### 3. Slow Queries (>50ms)

Common causes in WordPress plugins:
- Querying `wp_postmeta` without an index on `meta_key`
- `LIKE '%value%'` searches (can't use index)
- Missing `post_status = 'publish'` constraint (forces full table scan)
- `ORDER BY RAND()` (full table scan every time)

### 4. Autoload Bloat

Every `wp_options` row with `autoload = yes` loads on every request. Check:

```sql
SELECT option_name, LENGTH(option_value) as size
FROM wp_options
WHERE autoload = 'yes'
ORDER BY size DESC
LIMIT 20;
```

Anything >10KB in autoloaded options is a problem.
Plugin settings that rarely change should use `autoload = 'no'`.

---

## Using Query Monitor

1. Install via WP-CLI: `wp plugin install query-monitor --activate`
2. Load any frontend page or admin page
3. Click the **Query Monitor** bar at the top of the admin area
4. Go to **Queries** tab
5. Sort by **Time (ms)** — fix anything >50ms
6. Look for **[duplicates]** marker — fix N+1s
7. Filter by **Component** — see which plugin is responsible

---

## Using the Slow Query Log

Enable in Local WP → Site → Database → Enable Slow Query Log.

Then check:
```bash
# View recent slow queries
tail -100 "$(find ~/Library/Application\ Support/Local -name mysqld.log 2>/dev/null | head -1)"

# Or run our profiler
bash scripts/db-profile.sh --url http://tpa-test.local \
  --pages "/,/test-page/,/shop/,/wp-admin/admin.php?page=tpa_dashboard"
```

---

## Common Fixes

### N+1 Meta Queries
```php
// Bad — queries postmeta once per post in a loop
foreach ($posts as $post) {
    $meta = get_post_meta($post->ID, 'my_key', true);
}

// Good — fetch all at once
$post_ids = wp_list_pluck($posts, 'ID');
$all_meta = get_post_meta_by_ids($post_ids, 'my_key'); // or use update_post_meta_cache()
update_postmeta_cache($post_ids); // primes the cache
```

### Reduce Autoloaded Options
```php
// Bad — autoloads by default
update_option('my_plugin_settings', $data);

// Good — large or rarely-read settings
update_option('my_plugin_settings', $data, false); // false = no autoload
```

### Cache Expensive Queries
```php
// Wrap expensive DB calls in transients
$result = get_transient('my_plugin_expensive_query');
if (false === $result) {
    $result = $wpdb->get_results(/* expensive query */);
    set_transient('my_plugin_expensive_query', $result, HOUR_IN_SECONDS);
}
```

---

## Version Comparison

Run before and after upgrading your plugin:

```bash
# Baseline (old version)
WP_TEST_URL=http://tpa-test.local bash scripts/db-profile.sh > reports/db-old.txt

# Restore snapshot, install new version
# ...

# New version
WP_TEST_URL=http://tpa-test.local bash scripts/db-profile.sh > reports/db-new.txt

# Diff
diff reports/db-old.txt reports/db-new.txt
```

Any increase in query count is a regression to investigate.
