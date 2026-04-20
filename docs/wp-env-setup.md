# wp-env / wp-now Setup Guide

PlugOrbit uses **fully automated** WordPress test sites — no GUI apps, no click-through setup.

## Two Tools, Two Use Cases

| Tool | Backed By | Best For |
|---|---|---|
| `@wordpress/env` | Docker | Full PlugOrbit gauntlet, CI parity, multi-version matrix |
| `wp-now` | PHP WASM | Instant single-plugin sanity checks, no Docker |

Install both with the power tools script:

```bash
bash scripts/install-power-tools.sh
```

Or individually:

```bash
npm install -g @wordpress/env @wp-now/wp-now
```

---

## Prerequisites

### For `wp-env`
- **Docker Desktop** — [download here](https://www.docker.com/products/docker-desktop/)
- Docker must be running before `wp-env start`

### For `wp-now`
- Nothing beyond Node.js 18+

---

## Quick Start

### Option 1 — PlugOrbit wrapper (recommended)

```bash
bash scripts/create-test-site.sh --plugin ~/plugins/my-plugin --port 8881
```

This:
1. Creates `.wp-env-site/.wp-env.json` with your plugin + Query Monitor pre-installed
2. Starts the Docker containers
3. Enables `WP_DEBUG`, `SAVEQUERIES`, `WP_DEBUG_LOG`
4. Prints admin URL + credentials

Site ready at: `http://localhost:8881`
Admin: `http://localhost:8881/wp-admin` → `admin` / `password`

### Option 2 — Raw wp-env

```bash
mkdir my-test-site && cd my-test-site

cat > .wp-env.json <<EOF
{
  "core": "WordPress/WordPress#trunk",
  "plugins": [
    "../my-plugin",
    "https://downloads.wordpress.org/plugin/query-monitor.zip"
  ],
  "port": 8881
}
EOF

wp-env start
```

### Option 3 — wp-now (zero config)

```bash
cd ~/plugins/my-plugin
wp-now start
# → http://localhost:8881
```

wp-now auto-detects the plugin from the folder and loads it.

---

## Daily Commands

```bash
wp-env start                        # start / restart site
wp-env stop                         # pause
wp-env destroy                      # nuke everything
wp-env clean all                    # reset DB to clean state
wp-env run cli wp plugin list       # run any wp-cli command
wp-env run cli wp option get siteurl
wp-env logs                         # tail container logs
wp-env logs --watch                 # follow logs live
```

---

## Multi-Version Matrix

Test your plugin against multiple PHP / WordPress combinations:

```json
{
  "core": "WordPress/WordPress#tags/6.3",
  "phpVersion": "7.4",
  "plugins": ["../my-plugin"]
}
```

Create one config per combo in separate folders. Spin each up on a different port:

```bash
(cd site-php74-wp63 && wp-env start)   # port 8881
(cd site-php82-wp64 && wp-env start)   # port 8882
(cd site-php83-trunk && wp-env start)  # port 8883
```

Then run the gauntlet against each:

```bash
for port in 8881 8882 8883; do
  WP_TEST_URL=http://localhost:$port bash scripts/gauntlet.sh --plugin ~/plugins/my-plugin
done
```

---

## WP-CLI Inside wp-env

Any wp-cli command works via `wp-env run cli wp ...`:

```bash
wp-env run cli wp user create qa qa@example.com --role=editor --user_pass=password
wp-env run cli wp post create --post_type=page --post_title="Test" --post_status=publish
wp-env run cli wp plugin activate my-plugin
wp-env run cli wp theme activate twentytwentyfour
wp-env run cli wp search-replace 'old.com' 'new.com'
wp-env run cli wp db export backup.sql
wp-env run cli wp eval 'var_dump(get_option("blogname"));'
```

---

## Database Access

### Via WP-CLI

```bash
wp-env run cli wp db cli              # interactive MySQL shell
wp-env run cli wp db query "SELECT * FROM wp_options LIMIT 5"
wp-env run cli wp db export           # dump DB
```

### Via External Client

```bash
wp-env run cli wp config get DB_HOST DB_NAME DB_USER DB_PASSWORD
# Then connect TablePlus / Sequel Ace / phpMyAdmin to the reported host:port
```

---

## Troubleshooting

**`wp-env start` hangs or fails**
```bash
docker ps                  # is Docker running?
wp-env destroy && wp-env start   # nuclear reset
```

**Port 8881 already in use**
```bash
lsof -i :8881              # find what's using it
# Or change port in .wp-env.json → "port": 8882
```

**Plugin not installing**
- Path must be relative to `.wp-env.json` location
- Use `../my-plugin` not `~/plugins/my-plugin`

**Want Local WP's "Site Shell" equivalent?**
```bash
wp-env run cli bash        # shell into the container
```

---

## When to Use What

| Need | Use |
|---|---|
| Full PlugOrbit gauntlet | `wp-env` via `create-test-site.sh` |
| Quick 30-second sanity check | `wp-now` |
| DB profiling / query monitoring | `wp-env` (has MySQL container) |
| Multi-version matrix | `wp-env` (one config per combo) |
| Zero-config for plugin development | `wp-now` |
| "Claude Code Skill wants to test something" | `wp-env` (scriptable, predictable port) |
