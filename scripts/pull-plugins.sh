#!/usr/bin/env bash
# Orbit — Auto-download free plugin zips from wordpress.org
# Reads slugs from qa.config.json → downloads latest stable zip per slug
# Saves to: plugins/free/<slug>/<slug>-<version>.zip
#
# Usage:
#   bash scripts/pull-plugins.sh              # uses qa.config.json
#   bash scripts/pull-plugins.sh --slugs "elementor,jetpack,yoast-seo"

set -e

SLUGS=""
DEST="plugins/free"

while [[ "$#" -gt 0 ]]; do
  case $1 in
    --slugs) SLUGS="$2"; shift ;;
    --dest)  DEST="$2";  shift ;;
  esac
  shift
done

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'

# Load from qa.config.json if --slugs not given
if [ -z "$SLUGS" ] && [ -f "qa.config.json" ]; then
  SLUGS=$(python3 -c "
import json
d = json.load(open('qa.config.json'))
comps = d.get('competitors', [])
own = d.get('plugin', {}).get('slug', '')
all_slugs = [s for s in comps if s]
if own and own not in all_slugs:
    all_slugs.append(own)
print(','.join(all_slugs))
" 2>/dev/null || echo "")
fi

if [ -z "$SLUGS" ]; then
  echo -e "${RED}No slugs specified and qa.config.json not found.${NC}"
  echo "Usage: $0 --slugs \"elementor,jetpack,yoast-seo\""
  exit 1
fi

mkdir -p "$DEST"

echo ""
echo -e "${BOLD}Orbit — Pulling free plugin zips from wordpress.org${NC}"
echo "Slugs: $SLUGS"
echo "Destination: $DEST/"
echo "========================================================"

IFS=',' read -ra SLUG_ARR <<< "$SLUGS"
SUCCESS=0; FAILED=0; SKIPPED=0

for SLUG in "${SLUG_ARR[@]}"; do
  SLUG=$(echo "$SLUG" | xargs)
  [ -z "$SLUG" ] && continue

  echo ""
  echo -e "${YELLOW}→ $SLUG${NC}"

  INFO=$(curl -sf "https://api.wordpress.org/plugins/info/1.0/${SLUG}.json" 2>/dev/null || echo "{}")
  VERSION=$(echo "$INFO" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('version',''))" 2>/dev/null || echo "")
  DOWNLOAD=$(echo "$INFO" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('download_link',''))" 2>/dev/null || echo "")

  if [ -z "$VERSION" ] || [ -z "$DOWNLOAD" ]; then
    echo -e "  ${RED}✗ not found on wordpress.org (is it a Pro-only plugin?)${NC}"
    ((FAILED++))
    continue
  fi

  mkdir -p "$DEST/$SLUG"
  ZIP_PATH="$DEST/$SLUG/${SLUG}-${VERSION}.zip"

  if [ -f "$ZIP_PATH" ]; then
    echo -e "  ${GREEN}✓ already have v${VERSION} — skipping${NC}"
    ((SKIPPED++))
    continue
  fi

  echo "  Downloading v$VERSION..."
  if curl -sfL "$DOWNLOAD" -o "$ZIP_PATH" 2>/dev/null; then
    SIZE=$(du -h "$ZIP_PATH" | awk '{print $1}')
    echo -e "  ${GREEN}✓ saved: $ZIP_PATH ($SIZE)${NC}"
    ((SUCCESS++))
  else
    echo -e "  ${RED}✗ download failed${NC}"
    ((FAILED++))
  fi
done

echo ""
echo "========================================================"
echo -e "${GREEN}Downloaded: $SUCCESS${NC} | ${YELLOW}Skipped (already have): $SKIPPED${NC} | ${RED}Failed: $FAILED${NC}"
echo ""
echo "Pro / paid plugins are NOT on wordpress.org — drop them manually into:"
echo "  plugins/pro/"
echo ""
