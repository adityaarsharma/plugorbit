#!/usr/bin/env bash
# PlugOrbit — Interactive First-Run Setup
# Creates qa.config.json tailored to your plugin type
# Usage: bash setup/init.sh

set -e

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

clear
echo ""
echo -e "${BOLD}${CYAN}"
echo "  ██████╗ ██╗     ██╗   ██╗ ██████╗ ██████╗ ██████╗ ██████╗ ██╗████████╗"
echo "  ██╔══██╗██║     ██║   ██║██╔════╝██╔═══██╗██╔══██╗██╔══██╗██║╚══██╔══╝"
echo "  ██████╔╝██║     ██║   ██║██║  ███╗██║   ██║██████╔╝██████╔╝██║   ██║   "
echo "  ██╔═══╝ ██║     ██║   ██║██║   ██║██║   ██║██╔══██╗██╔══██╗██║   ██║   "
echo "  ██║     ███████╗╚██████╔╝╚██████╔╝╚██████╔╝██║  ██║██████╔╝██║   ██║   "
echo "  ╚═╝     ╚══════╝ ╚═════╝  ╚═════╝  ╚═════╝ ╚═╝  ╚═╝╚═════╝ ╚═╝   ╚═╝  "
echo -e "${NC}"
echo -e "${BOLD}  WordPress Plugin QA — Intelligent Setup${NC}"
echo "  ─────────────────────────────────────────"
echo ""
echo "  I'll ask a few questions to configure your QA pipeline."
echo "  This creates qa.config.json — everything adapts to your plugin type."
echo ""

# ── Plugin Name ───────────────────────────────────────────────────────────────
echo -e "${YELLOW}Q1. What is your plugin name?${NC}"
read -r -p "  Plugin name: " PLUGIN_NAME
echo ""

# ── Plugin Slug ───────────────────────────────────────────────────────────────
PLUGIN_SLUG=$(echo "$PLUGIN_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
read -r -p "  Plugin slug (folder name) [$PLUGIN_SLUG]: " SLUG_INPUT
PLUGIN_SLUG="${SLUG_INPUT:-$PLUGIN_SLUG}"
echo ""

# ── Plugin Type ───────────────────────────────────────────────────────────────
echo -e "${YELLOW}Q2. What type of plugin is this?${NC}"
echo "   1) Elementor Addon (widget/extension for Elementor)"
echo "   2) Gutenberg Blocks Plugin"
echo "   3) WordPress Theme"
echo "   4) SEO Plugin"
echo "   5) WooCommerce Extension"
echo "   6) General WordPress Plugin"
echo "   7) Page Builder (Beaver, Divi, etc.)"
read -r -p "  Choose [1-7]: " PLUGIN_TYPE_NUM

case $PLUGIN_TYPE_NUM in
  1) PLUGIN_TYPE="elementor-addon" ;;
  2) PLUGIN_TYPE="gutenberg-blocks" ;;
  3) PLUGIN_TYPE="theme" ;;
  4) PLUGIN_TYPE="seo-plugin" ;;
  5) PLUGIN_TYPE="woocommerce-extension" ;;
  6) PLUGIN_TYPE="general" ;;
  7) PLUGIN_TYPE="page-builder" ;;
  *) PLUGIN_TYPE="general" ;;
esac
echo ""

# ── Plugin Path ───────────────────────────────────────────────────────────────
echo -e "${YELLOW}Q3. Where is your plugin source code?${NC}"
DEFAULT_PATH="$HOME/plugins/$PLUGIN_SLUG"
read -r -p "  Plugin path [$DEFAULT_PATH]: " PLUGIN_PATH_INPUT
PLUGIN_PATH="${PLUGIN_PATH_INPUT:-$DEFAULT_PATH}"
echo ""

# ── Test Site Port (wp-env) ───────────────────────────────────────────────────
echo -e "${YELLOW}Q4. What port should your wp-env test site run on?${NC}"
echo -e "   (We'll create the site automatically via Docker — no GUI needed.)"
DEFAULT_PORT="8881"
read -r -p "  Port [$DEFAULT_PORT]: " PORT_INPUT
WP_PORT="${PORT_INPUT:-$DEFAULT_PORT}"
WP_URL="http://localhost:$WP_PORT"
echo ""

# ── Competitors ───────────────────────────────────────────────────────────────
echo -e "${YELLOW}Q6. Who are your top competitors? (comma-separated wordpress.org slugs)${NC}"
echo "   Example: elementor,wpbakery,divi"
case $PLUGIN_TYPE in
  elementor-addon)   COMPETITOR_HINT="essential-addons-for-elementor-free,premium-addons-for-elementor" ;;
  gutenberg-blocks)  COMPETITOR_HINT="ultimate-blocks,kadence-blocks,spectra" ;;
  seo-plugin)        COMPETITOR_HINT="wordpress-seo,all-in-one-seo-pack,rankmath-seo" ;;
  woocommerce-extension) COMPETITOR_HINT="woocommerce,automatewoo,yith-woocommerce-wishlist" ;;
  theme)             COMPETITOR_HINT="astra,generatepress,hello-elementor" ;;
  *)                 COMPETITOR_HINT="" ;;
esac
[ -n "$COMPETITOR_HINT" ] && echo -e "   Suggested: ${CYAN}$COMPETITOR_HINT${NC}"
read -r -p "  Competitors: " COMPETITORS
echo ""

# ── Pro Version ───────────────────────────────────────────────────────────────
echo -e "${YELLOW}Q7. Do you have a Pro version to compare against Free?${NC}"
read -r -p "  Has Pro version? [y/N]: " HAS_PRO_INPUT
HAS_PRO="false"
PRO_ZIP=""
if [[ "$HAS_PRO_INPUT" =~ ^[Yy] ]]; then
  HAS_PRO="true"
  read -r -p "  Pro zip path (leave blank to set later): " PRO_ZIP_INPUT
  PRO_ZIP="${PRO_ZIP_INPUT:-}"
fi
echo ""

# ── Team Roles ────────────────────────────────────────────────────────────────
echo -e "${YELLOW}Q8. Who will use this pipeline? (select all that apply)${NC}"
echo "   d) Developers  q) QA testers  p) Product managers  a) All"
read -r -p "  Roles [a]: " ROLES_INPUT
ROLES="${ROLES_INPUT:-a}"
echo ""

# ── Notification ─────────────────────────────────────────────────────────────
echo -e "${YELLOW}Q9. Slack webhook URL for test result notifications? (optional)${NC}"
read -r -p "  Slack webhook URL [skip]: " SLACK_WEBHOOK
echo ""

# ── Write config ─────────────────────────────────────────────────────────────
cat > qa.config.json << EOF
{
  "plugin": {
    "name": "$PLUGIN_NAME",
    "slug": "$PLUGIN_SLUG",
    "type": "$PLUGIN_TYPE",
    "path": "$PLUGIN_PATH",
    "hasPro": $HAS_PRO,
    "proZip": "$PRO_ZIP"
  },
  "environment": {
    "testUrl": "$WP_URL",
    "wpEnvPort": $WP_PORT,
    "adminUser": "admin",
    "adminPass": "password"
  },
  "competitors": [$(echo "$COMPETITORS" | tr ',' '\n' | sed 's/^ *//;s/ *$//' | grep -v '^$' | sed 's/.*/    "&"/' | paste -sd ',' -)
  ],
  "team": {
    "roles": "$ROLES",
    "slackWebhook": "$SLACK_WEBHOOK"
  },
  "thresholds": {
    "lighthouse": { "performance": 75, "accessibility": 85 },
    "dbQueriesPerPage": 60,
    "jsBundleKb": 500,
    "cssBundleKb": 200
  },
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

# ── .env.test for Playwright ──────────────────────────────────────────────────
cat > .env.test << EOF
WP_TEST_URL=$WP_URL
WP_ENV_PORT=$WP_PORT
PLUGIN_TYPE=$PLUGIN_TYPE
EOF

echo ""
echo "  ─────────────────────────────────────────"
echo -e "${GREEN}  Setup complete!${NC} Config saved to: qa.config.json"
echo ""
echo "  Next steps:"
echo ""
echo "  1. Install power tools (one-time):"
echo "     bash scripts/install-power-tools.sh"
echo ""
echo "  2. Make sure Docker Desktop is running, then:"
echo "     bash scripts/create-test-site.sh --plugin $PLUGIN_PATH --port $WP_PORT"
echo "     → site ready at $WP_URL"
echo ""
echo "  3. Run the full gauntlet:"
echo "     bash scripts/gauntlet.sh"
echo ""

if [ -n "$COMPETITORS" ]; then
  echo "  Competitor analysis:"
  echo "     bash scripts/pull-plugins.sh             # downloads free zips"
  echo "     bash scripts/competitor-compare.sh       # analyzes them"
  echo ""
fi

echo ""
echo "  Full docs: https://github.com/adityaarsharma/wordpress-qa-master"
echo ""
