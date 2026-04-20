#!/usr/bin/env bash
# PlugOrbit — Create a fully automated WordPress test site
# Uses @wordpress/env (Docker) to spin up a WP site with your plugin pre-installed.
# No Local WP GUI needed — fully scriptable.
#
# Usage:
#   bash scripts/create-test-site.sh                        # uses qa.config.json
#   bash scripts/create-test-site.sh --plugin /path/to/plugin --port 8881

set -e

PLUGIN_PATH=""
PORT="8881"

while [[ "$#" -gt 0 ]]; do
  case $1 in
    --plugin) PLUGIN_PATH="$2"; shift ;;
    --port)   PORT="$2";        shift ;;
  esac
  shift
done

if [ -z "$PLUGIN_PATH" ] && [ -f "qa.config.json" ]; then
  PLUGIN_PATH=$(python3 -c "import json; print(json.load(open('qa.config.json'))['plugin']['path'])")
fi

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'

[ -z "$PLUGIN_PATH" ] || [ ! -d "$PLUGIN_PATH" ] && {
  echo -e "${RED}Plugin path not found: $PLUGIN_PATH${NC}"
  exit 1
}

if ! command -v wp-env &>/dev/null; then
  echo -e "${RED}wp-env not installed. Run: npm install -g @wordpress/env${NC}"
  exit 1
fi

if ! command -v docker &>/dev/null; then
  echo -e "${RED}Docker is required for wp-env. Install Docker Desktop first.${NC}"
  exit 1
fi

SITE_DIR=".wp-env-site"
mkdir -p "$SITE_DIR"
cd "$SITE_DIR"

cat > .wp-env.json << EOF
{
  "core": "WordPress/WordPress#trunk",
  "plugins": [
    "$PLUGIN_PATH",
    "https://downloads.wordpress.org/plugin/query-monitor.zip"
  ],
  "port": $PORT,
  "config": {
    "WP_DEBUG": true,
    "WP_DEBUG_LOG": true,
    "WP_DEBUG_DISPLAY": false,
    "SAVEQUERIES": true
  }
}
EOF

echo ""
echo -e "${BOLD}Creating automated test site...${NC}"
echo "Plugin: $PLUGIN_PATH"
echo "URL:    http://localhost:$PORT"
echo ""

wp-env start

echo ""
echo -e "${GREEN}✓ Test site ready:${NC} http://localhost:$PORT"
echo -e "${GREEN}✓ Admin:${NC} http://localhost:$PORT/wp-admin (admin / password)"
echo ""
echo "Stop site:      wp-env stop"
echo "Destroy site:   wp-env destroy"
echo "Reset database: wp-env clean all"
echo "Run WP-CLI:     wp-env run cli wp <command>"
echo ""
echo "For Local WP (GUI-based, richer DX for manual testing): see docs/local-wp-setup.md"
