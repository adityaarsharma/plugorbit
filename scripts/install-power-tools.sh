#!/usr/bin/env bash
# PlugOrbit — Power Tools Installer
# Installs every code-quality tool worth having for serious WP plugin QA.
# Safe to re-run: each tool is checked before install.

set -e

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'

echo ""
echo -e "${BOLD}${CYAN}PlugOrbit Power Tools Installer${NC}"
echo "This installs every quality tool a senior WP plugin dev uses."
echo "==============================================================="

check() { command -v "$1" &>/dev/null; }
say_ok() { echo -e "  ${GREEN}✓ $1${NC}"; }
say_skip() { echo -e "  ${YELLOW}⤸ $1 (already installed)${NC}"; }
say_warn() { echo -e "  ${YELLOW}⚠ $1${NC}"; }

# ── PHP tools via Composer ───────────────────────────────────────────────────
echo ""
echo -e "${BOLD}1. PHP Tools${NC}"

if ! check composer; then
  say_warn "Composer not found — install from getcomposer.org first"
  echo "  macOS: brew install composer"
  exit 1
fi

# PHP_CodeSniffer + WordPress Coding Standards
if check phpcs; then
  say_skip "PHP_CodeSniffer"
else
  composer global require "squizlabs/php_codesniffer=*" -q
  composer global require "wp-coding-standards/wpcs" -q
  composer global require "automattic/vipwpcs" -q
  composer global require "phpcompatibility/phpcompatibility-wp" -q
  say_ok "PHPCS + WPCS + VIP + PHPCompatibility"
fi

# PHPStan (static analysis)
if check phpstan; then
  say_skip "PHPStan"
else
  composer global require "phpstan/phpstan" -q
  composer global require "szepeviktor/phpstan-wordpress" -q
  say_ok "PHPStan + WordPress extension"
fi

# Psalm (alternative to PHPStan)
if check psalm; then
  say_skip "Psalm"
else
  composer global require "vimeo/psalm" -q 2>/dev/null || say_warn "Psalm optional — skip"
  say_ok "Psalm (alt static analyzer)"
fi

# Rector (automated PHP refactoring)
if check rector; then
  say_skip "Rector"
else
  composer global require "rector/rector" -q 2>/dev/null || say_warn "Rector optional"
  say_ok "Rector (auto-refactor)"
fi

# PHPBench (micro-benchmarks)
if check phpbench; then
  say_skip "PHPBench"
else
  composer global require "phpbench/phpbench" -q 2>/dev/null || say_warn "PHPBench optional"
  say_ok "PHPBench (perf benchmarks)"
fi

# ── Node / JS tools ───────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}2. Node / JS Tools${NC}"

if ! check npm; then
  say_warn "npm not found — install Node.js first"
  exit 1
fi

# Playwright
if check playwright; then
  say_skip "Playwright"
else
  npm install -g @playwright/test
  npx playwright install chromium firefox webkit
  say_ok "Playwright + browsers"
fi

# Lighthouse CLI
if check lighthouse; then
  say_skip "Lighthouse"
else
  npm install -g lighthouse @lhci/cli
  say_ok "Lighthouse + LHCI"
fi

# WordPress official CLI dev tools
if check wp-env; then
  say_skip "@wordpress/env"
else
  npm install -g @wordpress/env
  say_ok "@wordpress/env (Docker-based WP sites, fully scriptable)"
fi

if check wp-now; then
  say_skip "wp-now"
else
  npm install -g @wp-now/wp-now
  say_ok "wp-now (zero-config instant WP)"
fi

# ESLint + Stylelint with WP configs
if check eslint; then
  say_skip "ESLint"
else
  npm install -g eslint @wordpress/eslint-plugin stylelint @wordpress/stylelint-config
  say_ok "ESLint + Stylelint (WP configs)"
fi

# axe accessibility CLI
if check axe; then
  say_skip "axe-core CLI"
else
  npm install -g @axe-core/cli
  say_ok "axe-core (a11y scanner)"
fi

# ── WP-CLI ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}3. WordPress CLI${NC}"

if check wp; then
  say_skip "WP-CLI"
else
  curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
  chmod +x wp-cli.phar
  sudo mv wp-cli.phar /usr/local/bin/wp
  say_ok "WP-CLI"
fi

# ── Security ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}4. Security Tools${NC}"

# WPScan (WP vulnerability scanner — needs Ruby)
if check wpscan; then
  say_skip "WPScan"
elif check gem; then
  gem install wpscan 2>/dev/null || say_warn "WPScan optional (needs Ruby gems)"
  say_ok "WPScan"
else
  say_warn "Skipping WPScan (Ruby not installed)"
fi

# ── Claude Code power additions ───────────────────────────────────────────────
echo ""
echo -e "${BOLD}5. Claude Code Power Tools${NC}"
echo -e "${CYAN}These make every Claude Code session smarter${NC}"

# claude-mem (Claude Code memory plugin)
if [ -d "$HOME/.claude/plugins/marketplaces" ] && grep -qr "claude-mem" "$HOME/.claude/plugins/" 2>/dev/null; then
  say_skip "claude-mem"
else
  echo "  → Install claude-mem via: /plugin install claude-mem (from Claude Code)"
  echo "    Gives Claude memory across sessions — remembers every plugin audit you run."
fi

# ccusage (Claude Code usage tracker)
if check ccusage; then
  say_skip "ccusage"
else
  npm install -g ccusage 2>/dev/null || say_warn "ccusage optional"
  say_ok "ccusage (track your Claude Code token spend)"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "==============================================================="
echo -e "${GREEN}Power tools setup complete.${NC}"
echo ""
echo "Verify install:"
echo "  phpcs --version | phpstan --version | playwright --version"
echo "  lighthouse --version | wp --version | wp-env --version"
echo ""
echo "Next: bash scripts/pull-plugins.sh  (download competitor zips)"
echo "Then: bash scripts/gauntlet.sh     (run the full pipeline)"
echo ""
