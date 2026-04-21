# Installation Guide

> Complete setup from zero to running your first gauntlet. Every tool, every step, verified.

This guide walks you through installing everything Orbit needs on your machine. By the end, you'll have all tools installed, verified, and ready to run your first full audit. Set aside about 10–15 minutes — most of that time is waiting for downloads.

If you hit a problem at any step, jump to [Section 6: Troubleshooting](#6-troubleshooting-installation) before asking for help. Most common issues are covered there.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [One-Command Install](#2-one-command-install)
3. [Manual Installation (step by step)](#3-manual-installation)
4. [Installing Claude Code Skills](#4-installing-claude-code-skills)
5. [Verify Everything Works](#5-verify-everything-works)
6. [Troubleshooting Installation](#6-troubleshooting-installation)
7. [Updating Orbit](#7-updating-orbit)

---

## 1. Prerequisites

Before running anything, you need these tools on your machine. This section installs all of them in one block of commands — read through once so you know what's happening, then run the block for your operating system.

> **Q: Do I need all of these right now?** Most of them, yes. The only optional ones are Docker (only required for Steps 6–8, the browser and database tests) and Claude Code CLI (only required for Step 11, the AI audits). The static analysis steps (1–3) work fine without either. That said, the recommended approach is to install everything upfront so the full gauntlet can run.

### macOS (recommended)

Homebrew (the package manager for macOS) makes installing all of these straightforward. If you don't have Homebrew, the first command installs it. The rest install the core tools in one shot.

```bash
# Install Homebrew if missing
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Core requirements
brew install node@20 php composer git
brew install --cask docker

# WP-CLI
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
sudo mv wp-cli.phar /usr/local/bin/wp
```

The WP-CLI block downloads the tool as a `.phar` file (a self-contained PHP archive), makes it executable, and moves it to `/usr/local/bin/wp` so you can call `wp` from anywhere in your terminal.

### Ubuntu / Debian

On Linux, you install Node.js via a setup script from the NodeSource registry (which ensures you get version 20, not an older one from your system's default packages), then install PHP, Docker, and WP-CLI separately.

```bash
# Node.js 20
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# PHP + Composer
sudo apt-get install -y php php-cli php-xml php-mbstring
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer

# Docker
sudo apt-get install -y docker.io docker-compose
sudo usermod -aG docker $USER  # allow running without sudo

# WP-CLI
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar && sudo mv wp-cli.phar /usr/local/bin/wp
```

The `sudo usermod -aG docker $USER` line adds your user account to the `docker` group so you can run Docker commands without typing `sudo` every time. This change takes effect on your next login or after running `newgrp docker`.

### Minimum versions required

The table below shows the lowest version of each tool that Orbit supports. After installing, you can check your version with the command in the right column.

| Tool | Minimum | Check command |
|---|---|---|
| Node.js | 18.x | `node --version` |
| PHP | 7.4 | `php --version` |
| Composer | 2.x | `composer --version` |
| Docker | 24+ | `docker --version` |
| WP-CLI | 2.8+ | `wp --version` |
| Git | 2.x | `git --version` |

If any command returns a version number lower than the minimum shown, update that tool before continuing. Running with older versions can cause subtle failures that are hard to diagnose.

**You're done with prerequisites when** all six `--version` commands return a number at or above the minimums in this table.

---

## 2. One-Command Install

Once prerequisites are in place, this three-line block clones Orbit to your machine and runs the automated installer. This is the recommended path for most users.

The first line copies the Orbit project to `~/Claude/orbit` on your computer. The second line moves your terminal session into that folder. The third runs the installer.

```bash
git clone https://github.com/adityaarsharma/orbit.git ~/Claude/orbit
cd ~/Claude/orbit
bash setup/install.sh
```

`install.sh` handles everything below in one pass — you don't need to run any of these individually unless something fails:
- npm packages (`@playwright/test`, `@wordpress/env`, `lighthouse`, etc.)
- Playwright browser binaries (Chromium, Firefox, WebKit — the three browser engines used for cross-browser testing)
- PHP Composer packages (PHP_CodeSniffer, WPCS, VIP standards, PHPStan)
- wp-env global install (the Docker-based WordPress test environment)
- wp-now global install (a zero-config alternative for quick local WordPress testing)
- Claude Code skills verification

Takes about 3–5 minutes the first time (mostly browser downloads). The progress will print to your terminal as it goes.

**You're done with this step when** the script finishes without printing any error messages in red. A few warnings in yellow are normal and can usually be ignored.

> **Q: What's the difference between wp-env and wp-now?** Both spin up a local WordPress site for testing. `wp-env` (a tool maintained by the WordPress core team) uses Docker and is the more powerful option — it supports multisite, custom PHP configs, and persistent data between runs. `wp-now` is simpler and faster to start, but less configurable. Orbit uses `wp-env` for the gauntlet and `wp-now` as a fallback for quick checks.

---

## 3. Manual Installation

If `install.sh` fails for any step, here is every piece individually. Run only the sections for what failed — you don't need to redo things that installed successfully.

### 3.1 Node packages

This installs all of Orbit's JavaScript dependencies. `npm install` reads the `package.json` file in the Orbit folder and downloads exactly the packages listed there. Then `npx playwright install` downloads the actual browser binaries that Playwright (the browser automation framework — it controls Chrome, Firefox, and Safari to simulate what a real user would do) needs to run tests.

```bash
cd ~/Claude/orbit
npm install

# Install Playwright browsers (chromium, firefox, webkit)
npx playwright install
npx playwright install-deps  # system libs (Linux only)
```

The `install-deps` command is only needed on Linux — it installs system-level libraries (like fonts and audio codecs) that the browser binaries depend on.

### 3.2 Global npm tools

These tools need to be installed globally (available anywhere on your system, not just inside the Orbit folder) because the gauntlet scripts call them by name from different directories.

```bash
npm install -g @wordpress/env          # wp-env — Docker-based WP test sites
npm install -g @wp-now/wp-now          # wp-now — zero-config instant WP
npm install -g lighthouse              # performance audits
npm install -g @lhci/cli               # Lighthouse CI
```

- **@wordpress/env** — creates and manages Docker-based WordPress test environments
- **@wp-now/wp-now** — spins up a WordPress site instantly without any Docker configuration
- **lighthouse** — Google's open-source tool for auditing web page performance, accessibility, and SEO
- **@lhci/cli** — the Lighthouse CI version, which generates structured JSON reports suitable for automated analysis

### 3.3 PHP Quality Tools (via Composer)

Composer (PHP's dependency manager, similar to npm for JavaScript) installs the PHP code analysis tools Orbit uses in Steps 1–3. This block installs everything globally so the tools are available from any directory.

```bash
# Install all PHP tools globally
composer global require \
  squizlabs/php_codesniffer \
  wp-coding-standards/wpcs \
  automattic/vipwpcs \
  phpcompatibility/phpcompatibility-wp \
  phpstan/phpstan \
  szepeviktor/phpstan-wordpress
```

What each package does:
- **php_codesniffer** (PHPCS) — checks your PHP code against a set of coding rules and flags anything that doesn't comply
- **wpcs** (WordPress Coding Standards) — the WordPress-specific ruleset for PHPCS; covers formatting, escaping, nonces, and more
- **vipwpcs** — Automattic's stricter ruleset used for WordPress VIP (enterprise-tier) plugins; catches security issues WPCS misses
- **phpcompatibility-wp** — checks whether your code is compatible with the range of PHP versions you claim to support
- **phpstan** — a static analysis tool (a program that reads your code without running it and finds type errors, undefined variables, and logical issues)
- **phpstan-wordpress** — WordPress-specific type stubs for PHPStan so it understands WordPress functions and doesn't flag them as unknown

After installing, you need to tell PHPCS where to find the standards you just installed. This command registers the paths:

```bash
# Register WPCS + VIP standards with phpcs
phpcs --config-set installed_paths \
  ~/.composer/vendor/wp-coding-standards/wpcs,\
  ~/.composer/vendor/automattic/vipwpcs,\
  ~/.composer/vendor/phpcompatibility/phpcompatibility-wp

# Verify standards loaded
phpcs -i
# Should include: WordPress, WordPress-Core, WordPress-Docs, WordPress-Extra, WordPressVIPMinimum, PHPCompatibilityWP
```

Run `phpcs -i` after registering. If you see `WordPress`, `WordPressVIPMinimum`, and `PHPCompatibilityWP` in the output, the standards registered correctly.

> **Q: Why do I need to register paths separately? Can't PHPCS find them automatically?** PHPCS doesn't know where Composer installed things by default. The `--config-set installed_paths` command is a one-time registration step. Once it's done, you never have to do it again (unless you reinstall PHPCS).

### 3.4 Claude Code CLI

Claude Code (the AI coding tool that powers Orbit's Step 11 skill audits) is installed as a global npm package.

```bash
# Install Claude Code globally
npm install -g @anthropic-ai/claude-code

# Verify
claude --version
```

Claude Code is required for Step 11 (skill audits). Without it, the gauntlet still runs Steps 1–10 and produces all the other reports — you just won't get the AI-generated code review.

### 3.5 PHPStan config

PHPStan (the PHP static analysis tool — it reads your code and infers what each variable and function should contain, then flags places where the types don't match) requires a configuration file to know what level of strictness to apply and which WordPress stubs to use.

The `config/phpstan.neon` file already exists in Orbit. It runs PHPStan at level 5 with WordPress stubs. If your plugin has a custom `phpstan.neon`, point the gauntlet to it:

```bash
# Override in gauntlet.sh by passing config path
PHPSTAN_CONFIG=/path/to/your/phpstan.neon bash scripts/gauntlet.sh --plugin /path/to/plugin
```

Level 5 is a good balance between thoroughness and noise for most WordPress plugins. Level 0 finds almost nothing; level 9 is very strict and can produce many false positives in plugin code.

---

## 4. Installing Claude Code Skills

Skills are `.md` files installed into `~/.claude/skills/`. Think of them like specialist job descriptions — each file tells Claude Code how to behave as a particular type of auditor (security expert, database optimizer, accessibility reviewer, etc.). When Orbit's gauntlet reaches Step 11, it calls each skill by name and Claude Code adopts that specialist role for the review.

### Recommended: Antigravity CLI installer

This single command downloads and installs all skills from the awesome-agent-skills registry into the right folder automatically.

```bash
npx antigravity-awesome-skills
```

This installs all skills from the awesome-agent-skills registry into `~/.claude/skills/`. It usually takes under a minute. After it finishes, verify the mandatory skills are present (see below).

### Manual install

If the CLI installer doesn't work for your setup, you can clone the skills repository and create symlinks (shortcuts that point to the original files) instead of copying them. The advantage of symlinks is that when you update the repository later, the skills update automatically.

```bash
# Clone the skills repo
git clone https://github.com/VoltAgent/awesome-agent-skills ~/Claude/awesome-agent-skills

# Symlink into Claude's skills directory
mkdir -p ~/.claude/skills
ln -sf ~/Claude/awesome-agent-skills/skills/* ~/.claude/skills/
```

### Verify each mandatory skill is installed

After installation, run this block to confirm all 6 required skills are present. Each line checks for one skill file and prints a checkmark if it's there.

```bash
ls ~/.claude/skills/wordpress-plugin-development       && echo "✓ WP Standards"
ls ~/.claude/skills/wordpress-penetration-testing      && echo "✓ Security"
ls ~/.claude/skills/performance-engineer               && echo "✓ Performance"
ls ~/.claude/skills/database-optimizer                 && echo "✓ Database"
ls ~/.claude/skills/accessibility-compliance-accessibility-audit && echo "✓ Accessibility"
ls ~/.claude/skills/code-review-excellence             && echo "✓ Code Quality"
```

All 6 should print `✓`. If any are missing, install them individually:

```bash
# Install individually from Claude Code
/skill install wordpress-plugin-development
/skill install wordpress-penetration-testing
/skill install performance-engineer
/skill install database-optimizer
/skill install accessibility-compliance-accessibility-audit
/skill install code-review-excellence
```

**You're done with skills installation when** all 6 lines above print a checkmark without any "No such file" errors.

> **Q: What happens if I skip installing the skills?** Steps 1–10 of the gauntlet run fine without them. Step 11 will fail with a "skill not found" error, but Orbit will still complete and generate all other reports. You can add the skills later and re-run just Step 11.

### Add-on skills (install based on plugin type)

Beyond the 6 mandatory skills, there are additional specialist skills for specific plugin types. Install the ones that match what your plugin does. These are optional but add more targeted analysis.

```bash
# Elementor addon plugins
ls ~/.claude/skills/antigravity-design-expert

# Gutenberg / FSE theme plugins
ls ~/.claude/skills/wordpress-theme-development

# WooCommerce plugins
ls ~/.claude/skills/wordpress-woocommerce-development

# REST API / headless plugins
ls ~/.claude/skills/api-security-testing

# Complex PHP / OOP plugins
ls ~/.claude/skills/php-pro
```

If any of these return a "No such file" error and you need that skill, run `npx antigravity-awesome-skills` again to sync the latest skill registry.

---

## 5. Verify Everything Works

Run this full verification block after installation. It checks every tool in one pass and prints a clear `✓` or `✗` for each one. This is the definitive test that your installation is complete and working.

```bash
echo "=== Orbit Installation Verification ==="
echo ""

# Node
node --version && echo "✓ Node.js" || echo "✗ Node.js missing"
npm --version  && echo "✓ npm" || echo "✗ npm missing"

# PHP
php --version  && echo "✓ PHP" || echo "✗ PHP missing"
phpcs --version && echo "✓ PHPCS" || echo "✗ PHPCS missing — run: composer global require squizlabs/php_codesniffer"
phpstan --version 2>/dev/null && echo "✓ PHPStan" || echo "✗ PHPStan missing"

# WP tools
wp --version   && echo "✓ WP-CLI" || echo "✗ WP-CLI missing"
wp-env --version && echo "✓ wp-env" || echo "✗ wp-env missing — run: npm i -g @wordpress/env"

# Playwright
npx playwright --version && echo "✓ Playwright" || echo "✗ Playwright missing"

# Lighthouse
lighthouse --version 2>/dev/null && echo "✓ Lighthouse" || echo "⚠ Lighthouse missing — optional, run: npm i -g lighthouse"

# Claude Code
claude --version 2>/dev/null && echo "✓ Claude Code" || echo "⚠ Claude Code missing — optional for skills"

# Docker
docker info &>/dev/null && echo "✓ Docker running" || echo "✗ Docker not running — start Docker Desktop"

echo ""
echo "=== PHPCS Standards ==="
phpcs -i 2>/dev/null | grep -E "WordPress|VIPMinimum|PHPCompatibility" || echo "✗ WPCS standards not registered"
```

Expected output (all green):
```
✓ Node.js
✓ npm
✓ PHP
✓ PHPCS
✓ PHPStan
✓ WP-CLI
✓ wp-env
✓ Playwright
✓ Lighthouse
✓ Claude Code
✓ Docker running

=== PHPCS Standards ===
WordPress, WordPress-Core, WordPress-Docs, WordPress-Extra
WordPressVIPMinimum
PHPCompatibilityWP
```

**You're done with installation when** this script outputs all checkmarks and the PHPCS Standards section lists WordPress, WordPressVIPMinimum, and PHPCompatibilityWP.

If you see `⚠` (warning) next to Lighthouse or Claude Code, those are optional and won't block Steps 1–5. If you see `✗` (cross) next to anything else, go to Section 6 for the fix.

> **Q: Do I need Docker running right now just to verify the installation?** Yes, the Docker check requires Docker Desktop to be open and running. On macOS, open the Docker Desktop app from your Applications folder. On Linux, run `sudo systemctl start docker`. Once Docker is running, re-run the verification block.

---

## 6. Troubleshooting Installation

### Docker not running

Docker Desktop needs to be running in the background before wp-env can create test sites. It's not enough to have it installed — the application has to be active.

```bash
# macOS — open Docker Desktop app first
open -a Docker

# Ubuntu
sudo systemctl start docker
sudo systemctl enable docker
```

After running one of these, wait 10–15 seconds for Docker to fully start, then run `docker info` to confirm it's responsive.

### PHPCS "No coding standards found"

This error means the PHPCS standards registration step didn't run or used the wrong paths. Re-run it with the correct Composer home directory:

```bash
# Re-run standards registration
phpcs --config-set installed_paths \
  $(composer global config home)/vendor/wp-coding-standards/wpcs,\
  $(composer global config home)/vendor/automattic/vipwpcs,\
  $(composer global config home)/vendor/phpcompatibility/phpcompatibility-wp

phpcs -i  # verify
```

Using `$(composer global config home)` instead of hardcoding `~/.composer` ensures the path is correct regardless of where Composer is configured on your machine.

### Playwright browsers missing

If Playwright tests fail with "browser not found" or "executable doesn't exist" errors, the browser binaries weren't downloaded during installation. Run these commands to fetch them:

```bash
npx playwright install
npx playwright install-deps  # Linux only
```

Playwright maintains its own copies of Chrome, Firefox, and WebKit (the Safari engine) separate from any browsers you have installed. This ensures tests run the same way on every machine.

### wp-env "port already in use"

This error means something else (another WordPress test site, a different local development tool, or another process) is already using the port wp-env wants. Find what's using it and either stop that process or change the port:

```bash
lsof -i :8881         # find what's using port 8881
# Change port in create-test-site.sh call: --port 8882
```

`lsof -i :8881` lists every process listening on port 8881. The process name in the output will tell you what to stop.

### Claude Code "skill not found"

This means the skill file isn't in `~/.claude/skills/`. Check what's there and re-run the skills installer:

```bash
# Check skills directory
ls ~/.claude/skills/ | grep wordpress

# Re-install from registry
npx antigravity-awesome-skills
```

### PHP version too old (7.2 or lower)

Orbit requires PHP 7.4+ for the CLI tools (PHPCS, PHPStan). This is only about the PHP version that runs in your terminal — your production server can run any version. The CLI tools just need 7.4+ to function correctly.

```bash
# macOS — install multiple PHP versions
brew install php@8.2
brew link php@8.2 --force
php --version  # should show 8.2.x
```

Homebrew lets you have multiple PHP versions installed simultaneously. `brew link` switches which version is active in your terminal.

### npm install fails on Apple Silicon

If you're on a Mac with an M1, M2, or M3 chip and `npm install` fails with architecture-related errors, try clearing the cache and forcing an Intel-compatible install:

```bash
# Clear npm cache and reinstall
npm cache clean --force
arch -x86_64 npm install  # fallback for Intel-only packages
```

The `arch -x86_64` prefix runs the command in Intel emulation mode (via Rosetta 2), which resolves issues with packages that don't have native ARM builds.

---

## 7. Updating Orbit

When a new version of Orbit is released, pull the latest code and re-run the installer. The installer is safe to run multiple times — it updates what changed and skips what's already current.

```bash
cd ~/Claude/orbit
git pull origin main
npm install          # pick up any new dependencies
bash setup/install.sh  # re-run to update tools
```

`git pull` fetches the latest changes from GitHub and merges them into your local copy. `npm install` then syncs your JavaScript dependencies with the updated `package.json`. Running `install.sh` again ensures any new PHP tools or Playwright browser versions are also updated.

### Updating skills

How you update skills depends on how you installed them:

```bash
# If installed via Antigravity CLI
npx antigravity-awesome-skills

# If installed via symlink
cd ~/Claude/awesome-agent-skills
git pull origin main
# Symlinks update automatically
```

If you used the symlink method, pulling the repository is all you need — because symlinks point to the original files rather than copies, the skills in `~/.claude/skills/` update the moment the repository updates.

> **Q: How often should I update Orbit and the skills?** Before each major release cycle is a good cadence. Skills especially evolve as new WordPress security patterns and coding standards emerge. Running on outdated skills means the AI audits might miss recently-documented vulnerability patterns.

---

## What's Next

You've finished installation. Here's where to go depending on what you want to do next:

- [docs/02-configuration.md](02-configuration.md) — Set up `qa.config.json` to tell Orbit about your specific plugin (plugin name, test URLs, which steps to skip, etc.)
- [docs/03-test-environment.md](03-test-environment.md) — Spin up your first WordPress test site with wp-env and verify your plugin runs correctly inside it
- [docs/04-gauntlet.md](04-gauntlet.md) — Run your first full audit and learn what each of the 11 steps is actually checking
