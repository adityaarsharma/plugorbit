#!/usr/bin/env bash
# Orbit — Plugin Ownership Transfer Detection
#
# Defends against the April 2026 EssentialPlugin supply-chain attack pattern:
# attacker buys plugin via Flippa/etc., pushes a backdoored "update" weeks or
# months later. Users see "update available" and click without noticing the
# author changed.
#
# This script reads the git history of the main plugin file and flags when
# the Author / Author URI / plugin Name header changes between releases.
#
# Run before every release. If the plugin was recently acquired, verify
# the transition is legitimate before users see an update notification.

set -e

PLUGIN_PATH="${1:-}"
[ -z "$PLUGIN_PATH" ] && { echo "Usage: $0 /path/to/plugin"; exit 1; }
[ ! -d "$PLUGIN_PATH" ] && { echo "Not a dir: $PLUGIN_PATH"; exit 1; }
[ ! -d "$PLUGIN_PATH/.git" ] && {
  echo "Not a git repo — can't trace ownership history"
  exit 0
}

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

# Find main plugin file (first .php with "Plugin Name:" header)
MAIN_FILE_REL=$(cd "$PLUGIN_PATH" && grep -lE "^\s*\*?\s*Plugin Name:" ./*.php 2>/dev/null | head -1 | sed 's|^\./||')
if [ -z "$MAIN_FILE_REL" ]; then
  echo "No main plugin file found — skipping ownership trace"
  exit 0
fi

# Extract Author + Author URI + Plugin Name at every commit that touched this file
echo "Tracing ownership history for: $MAIN_FILE_REL"
echo ""

HISTORY_FILE=$(mktemp)
trap "rm -f $HISTORY_FILE" EXIT

cd "$PLUGIN_PATH"
# For each commit, extract the three fields at that point
git log --all --format='%H|%ci|%s' --follow -- "$MAIN_FILE_REL" | while IFS='|' read -r hash date subject; do
  CONTENT=$(git show "$hash:$MAIN_FILE_REL" 2>/dev/null | head -50 || true)
  AUTHOR=$(echo "$CONTENT" | grep -iE "^\s*\*?\s*Author:" | head -1 | sed -E 's/.*Author:\s*//' | tr -d '\r' | head -c 100)
  AUTHOR_URI=$(echo "$CONTENT" | grep -iE "^\s*\*?\s*Author URI:" | head -1 | sed -E 's/.*Author URI:\s*//' | tr -d '\r' | head -c 100)
  NAME=$(echo "$CONTENT" | grep -iE "^\s*\*?\s*Plugin Name:" | head -1 | sed -E 's/.*Plugin Name:\s*//' | tr -d '\r' | head -c 100)
  VERSION=$(echo "$CONTENT" | grep -iE "^\s*\*?\s*Version:" | head -1 | sed -E 's/.*Version:\s*//' | tr -d ' \r' | head -c 30)
  [ -z "$AUTHOR$NAME" ] && continue
  SHORT_HASH=${hash:0:8}
  echo "$date | v${VERSION:-?} | ${SHORT_HASH} | Author=${AUTHOR:-?} | URI=${AUTHOR_URI:-?} | Name=${NAME:-?}" >> "$HISTORY_FILE"
done

if [ ! -s "$HISTORY_FILE" ]; then
  echo "No Plugin Name history found in git log"
  exit 0
fi

# Detect distinct (Author, Author URI, Plugin Name) tuples
AUTHORS=$(awk -F'|' '{gsub(/^ +| +$/, "", $4); print $4}' "$HISTORY_FILE" | sort -u | grep -v '^Author=\?$')
AUTHOR_URIS=$(awk -F'|' '{gsub(/^ +| +$/, "", $5); print $5}' "$HISTORY_FILE" | sort -u | grep -v '^URI=\?$')
NAMES=$(awk -F'|' '{gsub(/^ +| +$/, "", $6); print $6}' "$HISTORY_FILE" | sort -u | grep -v '^Name=\?$')

AUTHOR_COUNT=$(echo "$AUTHORS" | grep -c .)
URI_COUNT=$(echo "$AUTHOR_URIS" | grep -c .)
NAME_COUNT=$(echo "$NAMES" | grep -c .)

FAIL=0
WARN=0

if [ "$AUTHOR_COUNT" -gt 1 ]; then
  echo -e "${RED}✗ Author header changed over history — $AUTHOR_COUNT distinct authors:${NC}"
  echo "$AUTHORS" | sed 's/^/   /'
  FAIL=1
fi

if [ "$URI_COUNT" -gt 1 ]; then
  echo -e "${RED}✗ Author URI changed over history — $URI_COUNT distinct URIs:${NC}"
  echo "$AUTHOR_URIS" | sed 's/^/   /'
  FAIL=1
fi

if [ "$NAME_COUNT" -gt 1 ]; then
  echo -e "${YELLOW}⚠ Plugin Name renamed over history — $NAME_COUNT distinct names:${NC}"
  echo "$NAMES" | sed 's/^/   /'
  WARN=1
fi

if [ "$FAIL" -eq 1 ]; then
  echo ""
  echo "Last 5 commits affecting plugin header:"
  tail -5 "$HISTORY_FILE" | sed 's/^/   /'
  echo ""
  echo "If ownership change is LEGITIMATE:"
  echo "  1. Document it in readme.txt == Upgrade Notice == for users"
  echo "  2. Notify WordPress.org plugin review team"
  echo "  3. Email existing users via site admin notice before update"
  echo ""
  echo "If ownership change is NOT legitimate (e.g. someone committed changes"
  echo "to your fork without intent to merge), revert those header changes."
  echo ""
  echo -e "${RED}Ownership transfer: FAIL (manual review required)${NC}"
  exit 1
fi

if [ "$WARN" -eq 1 ]; then
  echo -e "${YELLOW}Ownership transfer: WARN (plugin renamed, confirm intentional)${NC}"
  exit 0
fi

echo -e "${GREEN}✓ Ownership stable: 1 author, 1 URI, 1 name across $(wc -l < "$HISTORY_FILE" | tr -d ' ') commits${NC}"
exit 0
