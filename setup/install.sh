#!/usr/bin/env bash
# WordPress QA Master — 1-click dependency installer
# Usage: bash setup/install.sh

set -e

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

ok()   { echo -e "${GREEN}✓ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠ $1${NC}"; }
fail() { echo -e "${RED}✗ $1${NC}"; exit 1; }
info() { echo -e "  $1"; }

echo ""
echo "WordPress QA Master — Setup"
echo "==========================="
echo ""

# --- Node.js ---
if command -v node &>/dev/null; then
  ok "Node.js $(node -v)"
else
  warn "Node.js not found — installing via nvm"
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
  export NVM_DIR="$HOME/.nvm" && source "$NVM_DIR/nvm.sh"
  nvm install --lts && nvm use --lts
  ok "Node.js $(node -v) installed"
fi

# --- PHP ---
if command -v php &>/dev/null; then
  ok "PHP $(php -v | head -1 | cut -d' ' -f2)"
else
  fail "PHP not found. Install PHP 8.1+ then re-run this script."
fi

# --- Composer ---
if command -v composer &>/dev/null; then
  ok "Composer $(composer --version --no-ansi | cut -d' ' -f3)"
else
  warn "Composer not found — installing"
  curl -sS https://getcomposer.org/installer | php
  sudo mv composer.phar /usr/local/bin/composer
  ok "Composer installed"
fi

# --- WP-CLI ---
if command -v wp &>/dev/null; then
  ok "WP-CLI $(wp --version 2>/dev/null)"
else
  warn "WP-CLI not found — installing"
  curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
  chmod +x wp-cli.phar && sudo mv wp-cli.phar /usr/local/bin/wp
  ok "WP-CLI installed"
fi

# --- Playwright ---
echo ""
info "Installing Playwright..."
npm install -g @playwright/test @wp-playground/cli 2>/dev/null
npx playwright install chromium firefox 2>/dev/null
ok "Playwright + browsers installed"

# --- PHP_CodeSniffer + WPCS + VIP Standards ---
echo ""
info "Installing PHP_CodeSniffer with WordPress + VIP standards..."
composer global require --no-interaction \
  squizlabs/php_codesniffer \
  wp-coding-standards/wpcs \
  automattic/vipwpcs \
  phpcompatibility/phpcompatibility-wp 2>/dev/null
"$(composer global config bin-dir --absolute)/phpcs" \
  --config-set installed_paths \
  "$(composer global config home)/vendor/wp-coding-standards/wpcs,$(composer global config home)/vendor/automattic/vipwpcs" \
  2>/dev/null || true
ok "PHPCS + WPCS + VIP-Coding-Standards installed"

# --- PHPStan ---
info "Installing PHPStan + WordPress stubs..."
composer global require --no-interaction \
  phpstan/phpstan \
  szepeviktor/phpstan-wordpress 2>/dev/null
ok "PHPStan installed"

# --- Lighthouse CLI ---
info "Installing Lighthouse CLI..."
npm install -g @lhci/cli lighthouse 2>/dev/null
ok "Lighthouse CI installed"

# --- axe-core (accessibility) ---
info "Installing axe-core CLI..."
npm install -g @axe-core/cli 2>/dev/null
ok "axe-core installed"

# --- Local project dependencies ---
if [ -f "package.json" ]; then
  info "Installing local npm dependencies..."
  npm install 2>/dev/null
  ok "Local npm deps installed"
else
  info "Initialising package.json..."
  npm init -y 2>/dev/null
  npm install --save-dev @playwright/test @axe-core/playwright 2>/dev/null
  ok "package.json created and deps installed"
fi

# --- Summary ---
echo ""
echo "==========================="
echo -e "${GREEN}Setup complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. Set up Local WP sites: see docs/local-wp-setup.md"
echo "  2. Run your first test: npx playwright test"
echo "  3. Run full gauntlet:   bash scripts/gauntlet.sh --plugin /path/to/plugin"
echo ""
