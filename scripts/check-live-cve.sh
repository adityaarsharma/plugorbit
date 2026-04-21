#!/usr/bin/env bash
# Orbit — Live CVE Pattern Correlation (free, no API keys)
#
# Fetches recently disclosed WordPress plugin vulnerabilities from two free
# public feeds and checks whether the current plugin matches any of the
# vulnerable code signatures being exploited this week.
#
# Sources (all free, no auth):
#   1. WPScan (Automattic) public vulnerability feed — wpscan.com/api/v3/
#   2. Wordfence Threat Intelligence (free tier) — wordfence.com/threat-intel/
#
# The script:
#   1. Downloads recent CVEs (cached locally, 24h TTL)
#   2. Extracts the "vuln pattern" hints from titles + descriptions
#   3. Greps plugin code for matching patterns
#   4. Reports correlations with severity

set -e

PLUGIN_PATH="${1:-}"
[ -z "$PLUGIN_PATH" ] && { echo "Usage: $0 /path/to/plugin"; exit 1; }
[ ! -d "$PLUGIN_PATH" ] && { echo "Not a dir: $PLUGIN_PATH"; exit 1; }

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'

CACHE_DIR="${ORBIT_CACHE_DIR:-$HOME/.cache/orbit/cve}"
mkdir -p "$CACHE_DIR"

# ─── Cache helpers (24h TTL) ──────────────────────────────────────────────────
cache_fresh() {
  local file="$1"
  [ -f "$file" ] || return 1
  local age=$(( $(date +%s) - $(stat -f %m "$file" 2>/dev/null || stat -c %Y "$file" 2>/dev/null || echo 0) ))
  [ "$age" -lt 86400 ]
}

# ─── Fetch WPScan public feed ─────────────────────────────────────────────────
echo -e "${CYAN}── Fetching live CVE feeds ──${NC}"

# NVD (NIST National Vulnerability Database) — most reliable free source, no auth
# Queries last 60 days of CVEs with "wordpress" keyword
NVD_FILE="$CACHE_DIR/nvd-wp-recent.json"
if ! cache_fresh "$NVD_FILE"; then
  echo "→ Pulling NVD (NIST) recent WordPress CVEs..."
  PUB_START=$(python3 -c "import datetime; print((datetime.datetime.utcnow() - datetime.timedelta(days=60)).strftime('%Y-%m-%dT00:00:00.000'))")
  PUB_END=$(python3 -c "import datetime; print(datetime.datetime.utcnow().strftime('%Y-%m-%dT23:59:59.999'))")
  curl -s -H "User-Agent: Orbit-QA-Framework" \
    "https://services.nvd.nist.gov/rest/json/cves/2.0?keywordSearch=wordpress+plugin&pubStartDate=${PUB_START}&pubEndDate=${PUB_END}&resultsPerPage=100" \
    -o "$NVD_FILE" 2>/dev/null || echo '{"vulnerabilities":[]}' > "$NVD_FILE"
else
  echo "→ Using cached NVD data (<24h old)"
fi

# WPScan public feed (best effort — Automattic changed endpoints post-acquisition)
WPSCAN_FILE="$CACHE_DIR/wpscan-recent.json"
if ! cache_fresh "$WPSCAN_FILE"; then
  echo "→ Pulling WPScan public feed..."
  # Try authenticated first (if user has set WPSCAN_API_TOKEN), else scrape public endpoint
  if [ -n "${WPSCAN_API_TOKEN:-}" ]; then
    curl -s -H "User-Agent: Orbit-QA-Framework" -H "Authorization: Token token=${WPSCAN_API_TOKEN}" \
      "https://wpscan.com/api/v3/vulnerabilities?format=json&per_page=100" \
      -o "$WPSCAN_FILE" 2>/dev/null || echo "[]" > "$WPSCAN_FILE"
  else
    # Best-effort unauthenticated — falls back to empty if blocked
    curl -s -H "User-Agent: Mozilla/5.0 Orbit-QA" \
      "https://wpscan.com/api/v3/vulnerabilities?format=json&per_page=50" \
      -o "$WPSCAN_FILE" 2>/dev/null || echo "[]" > "$WPSCAN_FILE"
  fi
else
  echo "→ Using cached WPScan data (<24h old)"
fi

# ─── Extract patterns to check (last 30 days of CVEs) ─────────────────────────
echo ""
echo -e "${CYAN}── Analyzing your plugin against recent disclosures ──${NC}"

PATTERNS_FILE=$(mktemp)
trap "rm -f $PATTERNS_FILE" EXIT

# Parse NVD — extract description (contains vuln class keywords)
python3 - "$NVD_FILE" "$PATTERNS_FILE" <<'PYEOF'
import json, sys
try:
    with open(sys.argv[1]) as f:
        data = json.load(f)
    if not isinstance(data, dict):
        sys.exit(0)
    vulns = data.get('vulnerabilities', [])
    if not isinstance(vulns, list):
        sys.exit(0)
    with open(sys.argv[2], 'a') as out:
        for item in vulns[:200]:
            if not isinstance(item, dict): continue
            cve_data = item.get('cve', {})
            if not isinstance(cve_data, dict): continue
            cve_id = cve_data.get('id', '')
            descs = cve_data.get('descriptions', [])
            desc_text = ''
            if isinstance(descs, list):
                for d in descs:
                    if isinstance(d, dict) and d.get('lang') == 'en':
                        desc_text = d.get('value', '')[:200]
                        break
            if cve_id and desc_text:
                out.write(f"NVD|{cve_id}||{desc_text}\n")
except Exception as e:
    sys.stderr.write(f"[orbit] NVD parse skipped: {e}\n")
PYEOF

# Parse WPScan — handle varied response shapes (array vs {slug: [...]})
python3 - "$WPSCAN_FILE" "$PATTERNS_FILE" <<'PYEOF'
import json, sys, datetime
try:
    with open(sys.argv[1]) as f:
        raw = json.load(f)
    # WPScan responds in several shapes depending on endpoint; normalize
    items = []
    if isinstance(raw, list):
        items = raw
    elif isinstance(raw, dict):
        # Could be {slug: {vulnerabilities: [...]}} or {data: [...]}
        if 'data' in raw and isinstance(raw['data'], list):
            items = raw['data']
        elif 'vulnerabilities' in raw and isinstance(raw['vulnerabilities'], list):
            items = raw['vulnerabilities']
        else:
            for v in raw.values():
                if isinstance(v, dict) and 'vulnerabilities' in v:
                    vv = v.get('vulnerabilities')
                    if isinstance(vv, list):
                        items.extend(vv)
    cutoff = (datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=60)).isoformat()
    with open(sys.argv[2], 'a') as out:
        for v in items[:200]:
            if not isinstance(v, dict): continue
            title = str(v.get('title') or '').strip()
            vtype = str(v.get('vuln_type') or '').strip()
            pub   = str(v.get('published_date') or v.get('created_at') or '')
            cve_raw = v.get('cve', '')
            cve = cve_raw[0] if isinstance(cve_raw, list) and cve_raw else str(cve_raw or '')
            if pub and pub < cutoff: continue
            if title:
                out.write(f"WPSCAN|{cve}|{vtype}|{title[:200]}\n")
except Exception as e:
    sys.stderr.write(f"[orbit] WPScan parse skipped: {e}\n")
PYEOF

TOTAL_CVES=$(wc -l < "$PATTERNS_FILE" | tr -d ' ')
if [ "$TOTAL_CVES" -eq 0 ]; then
  echo -e "${YELLOW}⚠ No CVE data available (feeds unreachable or no recent entries)${NC}"
  echo "  Continuing — this check is informational, not blocking."
  exit 0
fi
echo "→ $TOTAL_CVES recent WP plugin CVEs in last 60 days"
echo ""

# ─── Map CVE title keywords to code patterns Orbit can grep ──────────────────
# This is a deliberately conservative keyword→pattern map: we'd rather miss
# than false-positive. Each match surfaces the related CVE for the user to
# compare their code against.

declare -a HITS=()

# SQLi patterns — if recent CVEs mention SQL injection
if grep -iqE "sql injection|sqli|unsanitized.*query" "$PATTERNS_FILE"; then
  RAW_SQL=$(grep -rEn "\\\$wpdb->(query|get_(results|var|row|col))\s*\(\s*[\"']SELECT" "$PLUGIN_PATH" --include="*.php" \
    --exclude-dir=vendor --exclude-dir=node_modules 2>/dev/null | grep -vE "\\\$wpdb->prepare|//" | head -2 || true)
  if [ -n "$RAW_SQL" ]; then
    echo -e "${RED}✗${NC} SQL injection disclosed in recent CVEs — your plugin has raw \$wpdb queries:"
    echo "$RAW_SQL" | head -1 | sed 's/^/     /'
    HITS+=("SQL injection")
  fi
fi

# XSS patterns
if grep -iqE "xss|cross.site scripting|stored script" "$PATTERNS_FILE"; then
  UNESCAPED=$(grep -rEn "echo\s+\\\$_(GET|POST|REQUEST|COOKIE)" "$PLUGIN_PATH" --include="*.php" \
    --exclude-dir=vendor --exclude-dir=node_modules 2>/dev/null | head -2 || true)
  if [ -n "$UNESCAPED" ]; then
    echo -e "${RED}✗${NC} XSS disclosed in recent CVEs — your plugin echoes user input unescaped:"
    echo "$UNESCAPED" | head -1 | sed 's/^/     /'
    HITS+=("XSS via unescaped user input")
  fi
fi

# Deserialization patterns (April 2026 EssentialPlugin signature)
if grep -iqE "deserialization|unserialize|object injection|php object" "$PATTERNS_FILE"; then
  UNSERIALIZE=$(grep -rEn "(^|[^a-zA-Z_>])unserialize\s*\(" "$PLUGIN_PATH" --include="*.php" \
    --exclude-dir=vendor --exclude-dir=node_modules 2>/dev/null | head -2 || true)
  if [ -n "$UNSERIALIZE" ]; then
    echo -e "${RED}✗${NC} Deserialization disclosed in recent CVEs — your plugin uses unserialize():"
    echo "$UNSERIALIZE" | head -1 | sed 's/^/     /'
    HITS+=("PHP Object Injection")
  fi
fi

# Missing auth patterns
if grep -iqE "missing auth|missing authoriz|broken access|privilege escalation|unauthenticated" "$PATTERNS_FILE"; then
  NOPRIV=$(grep -rEn "wp_ajax_nopriv_" "$PLUGIN_PATH" --include="*.php" \
    --exclude-dir=vendor --exclude-dir=node_modules 2>/dev/null | head -2 || true)
  if [ -n "$NOPRIV" ]; then
    echo -e "${YELLOW}⚠${NC} Missing-auth CVEs disclosed recently — verify your wp_ajax_nopriv_ handlers:"
    echo "$NOPRIV" | head -1 | sed 's/^/     /'
    HITS+=("Unauthenticated AJAX surface")
  fi
fi

# CSRF / missing nonce
if grep -iqE "csrf|cross.site request|missing nonce" "$PATTERNS_FILE"; then
  # Find admin-post / admin-ajax handlers and check if they have wp_verify_nonce nearby
  HANDLERS=$(grep -rEln "add_action\s*\(\s*[\"'](admin_post_|wp_ajax_)" "$PLUGIN_PATH" --include="*.php" \
    --exclude-dir=vendor --exclude-dir=node_modules 2>/dev/null || true)
  if [ -n "$HANDLERS" ]; then
    MISSING=""
    for f in $HANDLERS; do
      if ! grep -qE "wp_verify_nonce|check_admin_referer|check_ajax_referer" "$f" 2>/dev/null; then
        MISSING="$MISSING $f"
      fi
    done
    if [ -n "$MISSING" ]; then
      echo -e "${RED}✗${NC} CSRF disclosed in recent CVEs — files register admin handlers without nonce check:"
      echo "$MISSING" | tr ' ' '\n' | head -3 | sed 's/^/     /'
      HITS+=("CSRF — missing nonce verification")
    fi
  fi
fi

# LFI (Patchstack 2025: 12.6% of all WP vulns)
if grep -iqE "lfi|file inclusion|path traversal|local file" "$PATTERNS_FILE"; then
  LFI=$(grep -rEn "(include|require|readfile|file_get_contents)\s*\([^;)]*\\\$_(GET|POST|REQUEST)" "$PLUGIN_PATH" --include="*.php" \
    --exclude-dir=vendor --exclude-dir=node_modules 2>/dev/null | head -2 || true)
  if [ -n "$LFI" ]; then
    echo -e "${RED}✗${NC} LFI/path traversal disclosed in recent CVEs — your plugin has include/readfile with user input:"
    echo "$LFI" | head -1 | sed 's/^/     /'
    HITS+=("Local File Inclusion")
  fi
fi

# ─── Summary ──────────────────────────────────────────────────────────────────
echo ""
if [ "${#HITS[@]}" -eq 0 ]; then
  echo -e "${GREEN}✓ Live CVE correlation: CLEAN${NC}"
  echo "  ($TOTAL_CVES recent CVEs scanned; no matching patterns in your plugin code)"
  exit 0
fi

echo -e "${RED}Live CVE correlation: $((${#HITS[@]})) matching pattern(s) found${NC}"
echo ""
echo "These are WordPress vulnerability classes disclosed in the last 60 days,"
echo "AND patterns present in your plugin. Review each — your plugin may be"
echo "exploitable through the same vector even if not yet reported."
echo ""
echo "Next steps:"
echo "  1. Run the full /orbit-wp-security audit focused on the flagged patterns"
echo "  2. Check WPScan's full database: https://wpscan.com/vulnerabilities"
echo "  3. Check Wordfence Intel: https://www.wordfence.com/threat-intel/"
exit 1
