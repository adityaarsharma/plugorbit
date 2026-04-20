#!/usr/bin/env bash
# Database Query Profiler — Local WP via WP-CLI + MySQL slow query log
# Requires: Local WP running, WP-CLI, Query Monitor plugin active
# Usage: bash scripts/db-profile.sh [--url http://tpa-test.local] [--pages "/,/test-page/,/shop/"]

WP_URL="${WP_TEST_URL:-http://tpa-test.local}"
PAGES="${TEST_PAGES:-/,/test-page/,/sample-page/}"
WP_PATH="${WP_PATH:-$HOME/Local\ Sites/tpa-test/app/public}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
REPORT="reports/db-profile-$TIMESTAMP.txt"

mkdir -p reports

echo "Database Query Profiler"
echo "URL: $WP_URL"
echo "========================" | tee "$REPORT"

# Check WP-CLI reachable
if ! wp --path="$WP_PATH" core version &>/dev/null 2>&1; then
  echo "WP-CLI can't reach WordPress at $WP_PATH"
  echo "Ensure Local WP is running and WP_PATH is set correctly."
  echo "Export: export WP_PATH=\"\$HOME/Local Sites/your-site/app/public\""
  exit 1
fi

WP_VERSION=$(wp --path="$WP_PATH" core version)
echo "WordPress: $WP_VERSION" | tee -a "$REPORT"
echo "Date: $(date)" >> "$REPORT"
echo "" >> "$REPORT"

# Check Query Monitor is active
QM_ACTIVE=$(wp --path="$WP_PATH" plugin is-active query-monitor 2>/dev/null && echo "yes" || echo "no")
if [ "$QM_ACTIVE" = "no" ]; then
  echo "Installing Query Monitor..."
  wp --path="$WP_PATH" plugin install query-monitor --activate 2>/dev/null
fi

# Enable query logging via constant
wp --path="$WP_PATH" eval "
define('SAVEQUERIES', true);
global \$wpdb;
\$wpdb->show_errors();
" 2>/dev/null || true

echo "Page,Query Count,Load Time (ms),Slow Queries,Notes" | tee -a "$REPORT"

# Profile each page
IFS=',' read -ra PAGE_LIST <<< "$PAGES"
for PAGE in "${PAGE_LIST[@]}"; do
  PAGE=$(echo "$PAGE" | xargs)  # trim whitespace
  FULL_URL="$WP_URL$PAGE"

  # Get query count via WP-CLI eval
  QUERY_DATA=$(wp --path="$WP_PATH" eval "
    \$_SERVER['REQUEST_URI'] = '$PAGE';
    define('SAVEQUERIES', true);
    require_once ABSPATH . 'wp-settings.php';
    global \$wpdb;
    the_post();
    echo count(\$wpdb->queries) . ',' . (microtime(true) - \$_SERVER['REQUEST_TIME_FLOAT']) * 1000;
  " --url="$FULL_URL" 2>/dev/null || echo "?,?")

  QUERY_COUNT=$(echo "$QUERY_DATA" | cut -d',' -f1)
  LOAD_MS=$(echo "$QUERY_DATA" | cut -d',' -f2 | cut -d'.' -f1)

  # Flag slow pages
  NOTES=""
  if [ "$QUERY_COUNT" != "?" ] && [ "$QUERY_COUNT" -gt 50 ]; then
    NOTES="⚠ HIGH query count"
  fi
  if [ "$LOAD_MS" != "?" ] && [ "$LOAD_MS" -gt 500 ]; then
    NOTES="$NOTES ⚠ SLOW load"
  fi

  echo "$PAGE,$QUERY_COUNT,$LOAD_MS,$NOTES" | tee -a "$REPORT"
done

echo "" >> "$REPORT"
echo "--- Slow Query Log ---" >> "$REPORT"

# Check MySQL slow query log if accessible
SLOW_LOG=$(wp --path="$WP_PATH" eval "echo ini_get('slow_query_log_file');" 2>/dev/null || echo "")
if [ -n "$SLOW_LOG" ] && [ -f "$SLOW_LOG" ]; then
  tail -50 "$SLOW_LOG" >> "$REPORT"
  echo "Slow query log appended from: $SLOW_LOG"
else
  echo "Slow query log: not accessible (enable in Local WP → Site → Database → Enable Slow Query Log)" >> "$REPORT"
fi

echo ""
echo "DB profile saved to: $REPORT"
