#!/usr/bin/env bash
# PlugOrbit — Database Query Profiler via wp-env
# Requires: wp-env site running, Query Monitor plugin active (auto-installed by create-test-site.sh)
# Usage:
#   bash scripts/db-profile.sh
#   WP_TEST_URL=http://localhost:8881 TEST_PAGES="/,/shop/,/blog/" bash scripts/db-profile.sh

set -e

WP_URL="${WP_TEST_URL:-http://localhost:8881}"
PAGES="${TEST_PAGES:-/,/sample-page/}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
REPORT="reports/db-profile-$TIMESTAMP.txt"

# Load from qa.config.json if available
if [ -f "qa.config.json" ]; then
  WP_URL=$(python3 -c "import json; print(json.load(open('qa.config.json'))['environment']['testUrl'])" 2>/dev/null || echo "$WP_URL")
fi

mkdir -p reports

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'

echo ""
echo -e "${BOLD}PlugOrbit Database Query Profiler${NC}"
echo "URL: $WP_URL"
echo "========================================" | tee "$REPORT"

# Check wp-env is reachable
if ! command -v wp-env &>/dev/null; then
  echo -e "${RED}wp-env not installed. Run: npm install -g @wordpress/env${NC}"
  exit 1
fi

# Sanity: is the site up?
if ! curl -sf "$WP_URL" -o /dev/null; then
  echo -e "${RED}Site not reachable at $WP_URL${NC}"
  echo "Start it: bash scripts/create-test-site.sh"
  exit 1
fi

# Resolve wp-env working directory
WP_ENV_DIR=""
if [ -d ".wp-env-site" ]; then
  WP_ENV_DIR=".wp-env-site"
elif [ -f ".wp-env.json" ]; then
  WP_ENV_DIR="."
else
  echo -e "${YELLOW}No wp-env config found. Falling back to HTTP-based profiling.${NC}"
fi

# Run wp-cli inside wp-env
run_wp() {
  if [ -n "$WP_ENV_DIR" ]; then
    (cd "$WP_ENV_DIR" && wp-env run cli wp "$@" 2>/dev/null)
  else
    echo ""
  fi
}

WP_VERSION=$(run_wp core version)
echo "WordPress: ${WP_VERSION:-unknown}" | tee -a "$REPORT"
echo "Date: $(date)" >> "$REPORT"
echo "" >> "$REPORT"

# Ensure Query Monitor is active
if [ -n "$WP_ENV_DIR" ]; then
  QM_ACTIVE=$(run_wp plugin is-active query-monitor && echo "yes" || echo "no")
  if [ "$QM_ACTIVE" = "no" ]; then
    echo "Installing Query Monitor..."
    run_wp plugin install query-monitor --activate
  fi
fi

echo "Page,Query Count,Load Time (ms),Notes" | tee -a "$REPORT"

IFS=',' read -ra PAGE_LIST <<< "$PAGES"
for PAGE in "${PAGE_LIST[@]}"; do
  PAGE=$(echo "$PAGE" | xargs)
  [ -z "$PAGE" ] && continue
  FULL_URL="$WP_URL$PAGE"

  # Measure via HTTP — inject a tiny probe via Query Monitor's /wp-json/ endpoint (if available)
  # Fallback: time the request itself
  START=$(python3 -c "import time; print(int(time.time() * 1000))")
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$FULL_URL")
  END=$(python3 -c "import time; print(int(time.time() * 1000))")
  LOAD_MS=$((END - START))

  # Count queries via wp-cli after a page load (approximate — reads wp_postmeta tracking)
  QUERY_COUNT="?"
  if [ -n "$WP_ENV_DIR" ]; then
    QUERY_COUNT=$(run_wp eval "
      define('SAVEQUERIES', true);
      global \$wpdb;
      \$req = wp_remote_get('$FULL_URL');
      echo count(\$wpdb->queries);
    " 2>/dev/null | head -1 || echo "?")
  fi

  NOTES=""
  [ "$HTTP_CODE" != "200" ] && NOTES="⚠ HTTP $HTTP_CODE"
  [ "$QUERY_COUNT" != "?" ] && [ "$QUERY_COUNT" -gt 60 ] && NOTES="$NOTES ⚠ HIGH queries"
  [ "$LOAD_MS" -gt 500 ] && NOTES="$NOTES ⚠ SLOW load"

  echo "$PAGE,$QUERY_COUNT,$LOAD_MS,$NOTES" | tee -a "$REPORT"
done

echo "" >> "$REPORT"
echo "--- Slow Queries (via wp-env MySQL) ---" >> "$REPORT"

if [ -n "$WP_ENV_DIR" ]; then
  # Enable slow log inside container
  SLOW_QUERIES=$(run_wp db query "
    SELECT SQL_TEXT, EXEC_COUNT, TOTAL_LATENCY
    FROM performance_schema.events_statements_summary_by_digest
    WHERE SCHEMA_NAME = DATABASE()
    ORDER BY TOTAL_LATENCY DESC LIMIT 10
  " 2>/dev/null || echo "")

  if [ -n "$SLOW_QUERIES" ]; then
    echo "$SLOW_QUERIES" >> "$REPORT"
  else
    echo "(performance_schema not enabled — run: wp-env run cli wp db query \"SET GLOBAL performance_schema=ON\")" >> "$REPORT"
  fi
fi

echo ""
echo -e "${GREEN}DB profile saved to: $REPORT${NC}"
echo ""
echo "Tips for reducing query count:"
echo "  - Pre-warm postmeta cache: update_postmeta_cache(\$post_ids)"
echo "  - Use get_posts + 'update_meta_cache' => true"
echo "  - Cache expensive results in transients"
echo "  - Run /database-optimizer skill for AI-assisted analysis"
