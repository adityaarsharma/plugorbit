# Power Tools — Make Every Claude Code Session Smarter

PlugOrbit works on vanilla tooling, but these power-ups turn it into a senior-team-grade QA station. Install everything with:

```bash
bash scripts/install-power-tools.sh
```

---

## Claude Code Add-Ons

### claude-mem — persistent memory across sessions

Install via Claude Code:
```
/plugin install claude-mem
```

**Why**: Every plugin audit you run becomes searchable context for the next one. "What did we fix in v2.3?" gets answered from memory instead of re-reading code.

### ccusage — token spend tracker

```bash
npm install -g ccusage
ccusage today  # see today's token spend
```

**Why**: Claude Code token cost sneaks up. ccusage shows you per-session spend so you catch runaway prompts.

---

## PHP Quality Tools

| Tool | What It Does | Install |
|---|---|---|
| **PHP_CodeSniffer + WPCS + VIP + PHPCompatibility** | Coding standards, security sniffs, PHP version compat | `composer global require squizlabs/php_codesniffer wp-coding-standards/wpcs automattic/vipwpcs phpcompatibility/phpcompatibility-wp` |
| **PHPStan + WordPress ext** | Static analysis, catches bugs phpcs can't see | `composer global require phpstan/phpstan szepeviktor/phpstan-wordpress` |
| **Psalm** | Alternative static analyzer (different strengths than PHPStan) | `composer global require vimeo/psalm` |
| **Rector** | Automated PHP refactoring — upgrade PHP 7 → 8, modernize syntax | `composer global require rector/rector` |
| **PHPBench** | Micro-benchmarks — measure actual perf of your hot paths | `composer global require phpbench/phpbench` |

---

## JS / CSS Quality

| Tool | What It Does | Install |
|---|---|---|
| **Playwright** | E2E browser automation | `npm i -g @playwright/test && npx playwright install` |
| **Lighthouse + LHCI** | Performance / a11y / SEO scoring | `npm i -g lighthouse @lhci/cli` |
| **ESLint + WP config** | JS linting w/ WP rules | `npm i -g eslint @wordpress/eslint-plugin` |
| **Stylelint + WP config** | CSS linting | `npm i -g stylelint @wordpress/stylelint-config` |
| **axe-core CLI** | Accessibility scanner | `npm i -g @axe-core/cli` |

---

## WordPress-Specific

| Tool | What It Does | Install |
|---|---|---|
| **WP-CLI** | Everything WP from terminal | `curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && sudo mv wp-cli.phar /usr/local/bin/wp` |
| **@wordpress/env** | Docker-based WP sites, fully scriptable — create/destroy test sites with one command | `npm i -g @wordpress/env` |
| **wp-now** | Zero-config WP that runs from any plugin/theme folder in seconds | `npm i -g @wp-now/wp-now` |
| **WPScan** | WordPress vulnerability scanner (checks for known CVEs) | `gem install wpscan` |

---

## Claude Code Skills to Install

Open Claude Code, these skills are likely already installed globally (`~/.claude/skills/`). If missing, install from the skill registry:

```
/skill install wordpress
/skill install wordpress-plugin-development
/skill install wordpress-penetration-testing
/skill install wordpress-theme-development
/skill install wordpress-woocommerce-development
/skill install performance-engineer
/skill install database-optimizer
/skill install ui-ux-designer
/skill install production-code-audit
/skill install accessibility-compliance-accessibility-audit
/skill install antigravity-design-expert
/skill install antigravity-workflows
/skill install antigravity-skill-orchestrator
```

Full skill→task mapping in [../SKILLS.md](../SKILLS.md).

---

## Good-to-Have GitHub Projects

Worth adding to your workflow as you grow:

- **[10up/engineering-best-practices](https://github.com/10up/Engineering-Best-Practices)** — the gold standard for WP engineering
- **[Automattic/vip-go-mu-plugins](https://github.com/Automattic/vip-go-mu-plugins)** — see how enterprise WP handles security + perf
- **[WordPress/plugin-check](https://github.com/WordPress/plugin-check)** — the same tool WordPress.org uses to validate submissions
- **[WordPress/gutenberg](https://github.com/WordPress/gutenberg)** — read their `test/` dir for E2E patterns
- **[wp-cli/wp-cli](https://github.com/wp-cli/wp-cli)** — master it, save hours per day
- **[roots/wordpress-no-content](https://github.com/roots/wordpress-no-content)** — clean WP for reproducible test sites

---

## Verifying Everything Works

```bash
phpcs --version
phpstan --version
playwright --version
lighthouse --version
wp --version
wp-env --version
axe --version
```

If any command is "not found", re-run `bash scripts/install-power-tools.sh`.
