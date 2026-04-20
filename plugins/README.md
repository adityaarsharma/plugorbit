# Plugin Zips — Drop Box

PlugOrbit reads plugin zips from this folder for comparison runs, Pro-vs-Free diffs, and competitor analysis.

## Folder Structure

```
plugins/
├── free/         # Auto-downloaded free zips from wordpress.org (by slug)
├── pro/          # YOU manually drop your Pro / paid zips here
└── README.md     # This file
```

## How It Works

### `plugins/free/` — automatic

Run the puller to fetch every slug listed in `qa.config.json`:

```bash
bash scripts/pull-plugins.sh
```

It reads `competitors` from your config, hits `https://api.wordpress.org/plugins/info/1.0/{slug}.json`, downloads the latest stable zip, and saves it as:

```
plugins/free/<slug>/<slug>-<version>.zip
```

### `plugins/pro/` — manual

Pro / paid plugins aren't on wordpress.org, so PlugOrbit can't download them. Drop them here yourself:

```
plugins/pro/
├── my-plugin-pro-2.4.zip
├── competitor-pro-1.9.zip
└── ...
```

Reference them in `qa.config.json`:

```json
{
  "plugin": {
    "proZip": "plugins/pro/my-plugin-pro-2.4.zip"
  }
}
```

### Naming convention

`<slug>-<version>.zip` — enables automatic version diffs. Example:

```
my-plugin-2.3.0.zip
my-plugin-2.4.0.zip
```

Then:

```bash
bash scripts/compare-versions.sh \
  --old plugins/free/my-plugin/my-plugin-2.3.0.zip \
  --new plugins/free/my-plugin/my-plugin-2.4.0.zip
```

## Gitignore

This folder is `.gitignore`d — zips never get committed. Only this README and `.gitkeep` files are tracked.
