# Database Profiling Guide
> Catch N+1 queries, slow queries, and autoload bloat before they reach production

---

## Tools

| Tool | What It Catches | How to Use |
|---|---|---|
| **Query Monitor** | All DB queries, slow queries, duplicates, N+1s | Install plugin, view in admin bar |
| **MySQL performance_schema** | Queries >50ms threshold | `wp-env run cli wp db query "SET GLOBAL performance_schema=ON"` |
| **SAVEQUERIES** | Total query count per request | Already enabled in `.wp-env-site/.wp-env.json` |
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

`create-test-site.sh` auto-installs Query Monitor. To use:

1. Visit `http://localhost:8881/wp-admin` → log in as `admin` / `password`
2. You'll see the Query Monitor bar at the top of every page
3. Visit any frontend page (Query Monitor stays visible since you're logged in)
4. Click the bar → **Queries** tab
5. Sort by **Time (ms)** — fix anything >50ms
6. Look for **[duplicates]** marker — fix N+1s
7. Filter by **Component** — see which plugin is responsible

---

## Slow Queries via performance_schema

MySQL's `performance_schema` tracks query latency automatically:

```bash
# Enable it (one-time per container)
wp-env run cli wp db query "SET GLOBAL performance_schema=ON"

# Top 10 slowest queries
wp-env run cli wp db query "
  SELECT SQL_TEXT, EXEC_COUNT, TOTAL_LATENCY
  FROM performance_schema.events_statements_summary_by_digest
  WHERE SCHEMA_NAME = DATABASE()
  ORDER BY TOTAL_LATENCY DESC LIMIT 10
"

# Or run the automated profiler
bash scripts/db-profile.sh
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
bash scripts/db-profile.sh
mv reports/db-profile-*.txt reports/db-old.txt

# Reset DB + install new version
wp-env clean all
wp-env run cli wp plugin install /path/to/new-plugin.zip --activate --force

# New version profile
bash scripts/db-profile.sh
mv reports/db-profile-*.txt reports/db-new.txt

# Diff
diff reports/db-old.txt reports/db-new.txt
```

Any increase in query count is a regression to investigate.
