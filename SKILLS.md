# Skill Commands for Orbit

> Every QA task in Orbit maps to a Claude Code skill. This file is the complete reference — what to type, when to use it, what it does.

## Attribution

Orbit integrates with skills from three open-source repositories. You don't need Google Antigravity installed — these all work directly inside Claude Code once you have them locally.

| Repo | What It Ships | Link |
|---|---|---|
| **Antigravity Skills** (rmyndharis) | 300+ skills ported from Claude Code Agents — the core `antigravity-*` skills | [github.com/rmyndharis/antigravity-skills](https://github.com/rmyndharis/antigravity-skills) |
| **Antigravity Awesome Skills** (sickn33) | 1,400+ skills bundle with installer CLI, works with Claude Code, Cursor, Codex CLI, Gemini CLI | [github.com/sickn33/antigravity-awesome-skills](https://github.com/sickn33/antigravity-awesome-skills) |
| **Awesome Agent Skills** (VoltAgent) | 1,000+ skills from Anthropic, Google Labs, Vercel, Stripe, Cloudflare, Trail of Bits, Sentry, Figma | [github.com/VoltAgent/awesome-agent-skills](https://github.com/VoltAgent/awesome-agent-skills) |

### Install Skills for Claude Code

```bash
# Option 1 — the awesome-skills CLI installer
npx antigravity-awesome-skills

# Option 2 — clone repos directly and symlink into ~/.claude/skills/
git clone https://github.com/rmyndharis/antigravity-skills ~/Claude/antigravity-skills
ln -s ~/Claude/antigravity-skills/skills/* ~/.claude/skills/

# Option 3 — Claude Code's built-in (if supported)
/skill install <skill-name>
```

After install, every skill is invokable with `/skill-name` inside Claude Code. **No Google Antigravity app needed.**

---

## How to Use Skills with This Repo

```bash
# From your plugin directory
claude "/skill-name Do X for this plugin"

# Or from Orbit root, pointing at your plugin
claude "/skill-name Review /path/to/my-plugin for WordPress coding standards"
```

---

## Core Orbit Skills — Quick Reference

### WordPress-Specific (must-install)

| Skill | When to Use |
|---|---|
| `/wordpress` | WP coding standards check, naming, API usage |
| `/wordpress-plugin-development` | Plugin lifecycle, hooks, block.json, REST |
| `/wordpress-penetration-testing` | OWASP Top 10 against the plugin |
| `/wordpress-theme-development` | Theme hierarchy, FSE, customizer |
| `/wordpress-woocommerce-development` | WC hooks, template overrides, gateway security |

### Antigravity Core (community skills, installed locally)

| Skill | When to Use | Source |
|---|---|---|
| `/antigravity-design-expert` | UI/UX review — glassmorphism, concentric radius, 44px hit areas, GSAP motion | [community](https://github.com/rmyndharis/antigravity-skills) |
| `/antigravity-workflows` | Multi-step workflow runner — QA+Browser, Security Audit, SaaS MVP | [community](https://github.com/rmyndharis/antigravity-skills) |
| `/antigravity-skill-orchestrator` | Meta-skill: picks the right skills for a complex task, avoids over-engineering | [community](https://github.com/rmyndharis/antigravity-skills) |

### Quality & Testing (from Antigravity skills)

| Skill | When to Use |
|---|---|
| `/production-code-audit` | Full production-readiness review (security + perf + quality + error handling) |
| `/code-review-ai-ai-review` | AI-assisted code review — catches what humans miss |
| `/code-refactoring-refactor-clean` | Automated refactoring suggestions |
| `/codebase-cleanup-tech-debt` | Surface + prioritize technical debt |
| `/unit-testing-test-generate` | Generate PHPUnit tests for existing code |
| `/tdd-workflows-tdd-cycle` | Red-green-refactor loop |
| `/e2e-testing-patterns` | Playwright test patterns |
| `/lint-and-validate` | Lightweight quality checks across languages |
| `/test-driven-development` | TDD-oriented planning |
| `/webapp-uat` | Full browser UAT with Playwright + WCAG |

### Security (from Antigravity skills)

| Skill | When to Use |
|---|---|
| `/security-auditor` | Security-focused review (complements `/wordpress-penetration-testing`) |
| `/sast-configuration` | Set up static analysis security testing |
| `/security-scanning-security-hardening` | Harden code against common attacks |
| `/security-bluebook-builder` | Build security documentation + audit workflow |

### Performance, DB, UI

| Skill | When to Use |
|---|---|
| `/performance-engineer` | Performance analysis — N+1, caching, hot paths |
| `/database-optimizer` | DB patterns — autoload, postmeta, transients |
| `/ui-ux-designer` | Admin panel + settings UI review |
| `/frontend-design` | UI & interaction quality |
| `/accessibility-compliance-accessibility-audit` | WCAG 2.1/2.2 AA audit |
| `/accessibility-review` | WCAG 2.2 AA compliance |
| `/debugging-strategies` | Systematic troubleshooting when something breaks |

### Dev Workflow

| Skill | When to Use |
|---|---|
| `/backend-architect` | Plan backend architecture |
| `/api-design-principles` | REST API design review |
| `/full-stack-orchestration-full-stack-feature` | End-to-end feature implementation |
| `/context-driven-development` | Context-first dev methodology |
| `/create-pr` | Package work into a clean PR |
| `/cicd-automation-workflow-automate` | CI/CD automation (when you move off local-only) |
| `/github-actions-templates` | GH Actions workflow templates |
| `/incident-response-incident-response` | Incident playbook when production breaks |

---

## QA Task → Skill Recipes

### 1. Code Quality Review (Backend)

```
/wordpress-plugin-development
Review the plugin at [path] for WordPress plugin development best practices:
- Plugin header, activation/deactivation/uninstall hooks
- REST API registration, Gutenberg block patterns
- Sanitization, escaping, nonce usage, capability checks
- Hook priorities, autoloader pattern
```

```
/wordpress
Check [path] against WordPress coding standards:
- Naming conventions (functions, classes, hooks, files)
- PHP DocBlocks, inline documentation
- Proper use of WordPress APIs vs rolling custom solutions
```

### 2. Security Audit

```
/wordpress-penetration-testing
Run a full security audit on [path]:
- XSS via missing esc_html/esc_attr/wp_kses_post
- CSRF via missing nonce verification on forms + AJAX + REST
- SQL injection via missing $wpdb->prepare()
- Auth bypass — check all REST permission_callback
- Privilege escalation — missing current_user_can() checks
- Path traversal in file operations
- SSRF in any URL fetching (wp_remote_get)
```

Combine with a second opinion:

```
/security-auditor
Independently review [path] after /wordpress-penetration-testing flagged N issues.
Prioritize by exploitability and blast radius.
```

### 3. Performance — Backend Code

```
/performance-engineer
Analyze [path] for WordPress performance issues:
- N+1 database queries (same query in a loop)
- Missing object cache usage (wp_cache_get/set)
- Assets enqueued unconditionally on every page
- Synchronous HTTP calls blocking page loads
- Heavy operations not deferred to wp_cron
- Hook priorities on hot paths (init, wp_loaded, wp_head)
- Profile each action: which is the slowest?
```

### 4. Performance — Frontend (JS/CSS)

```
/frontend-design
Profile frontend assets shipped by [path]:
- Bundle size vs functionality used
- Unused CSS selectors
- Render-blocking scripts on critical path
- Defer / async usage on non-critical JS
- Images without width/height (layout shift)
- Font loading strategy (preload, font-display)
```

### 5. Performance — Elementor Editor (UI Editor Perf)

```
/performance-engineer
Profile the Elementor editor experience when my addon [path] is active:
- Time to editor ready (window.elementor ready)
- Time to widget panel populated
- Widget insert → render latency per widget
- Memory growth after inserting 20 widgets
- Check for console.log spam from my plugin
- Any >200ms JS tasks on main thread
Use the editor-perf.sh harness output as input.
```

### 6. Database Optimization

```
/database-optimizer
Review [path] database patterns:
- wp_options autoload flags — large/rarely-read options should be autoload=no
- wp_postmeta query efficiency — missing meta_key index usage
- Bulk operations not using batching
- Transient cleanup — are transients deleted on uninstall?
- Direct DB queries vs WP APIs
- N+1 patterns in WP_Query loops
```

### 7. Admin UI / Settings Panel

```
/antigravity-design-expert
Review the admin UI in [path]/admin/ against these principles:
- Concentric border radius on nested elements (outer = inner + padding)
- Optical alignment for icons and buttons
- Shadows over borders for depth
- Scale on press = 0.96 for interactive elements
- Font smoothing at root
- Tabular numbers on any counters/stats
- Minimum 44x44px hit areas
- No transition:all — list specific properties
```

```
/ui-ux-designer
Review the admin panel and widget settings UI in [path]:
- Progressive disclosure — hide advanced options until needed
- Form labels on all inputs (no placeholder-only labels)
- Error states clear and actionable
- Success feedback on save actions
- Destructive actions require confirmation
- Settings grouped logically, max 5 top-level tabs
- Complex widgets: is the flow obvious? Can a user complete task in <3 clicks?
```

### 8. Full Holistic Plugin Review (Orchestrated)

```
/antigravity-skill-orchestrator
Run a complete pre-release quality check on my WordPress plugin at [path].
I need: security audit + performance review + UI/UX check + database optimization + coding standards + Elementor editor perf.
Orchestrate the right skills in the right order and give me a prioritized findings report.
```

Alternative — single skill that does it all:

```
/production-code-audit
Run a full production readiness audit on [path]:
1. Security vulnerabilities (XSS, CSRF, SQLi, auth)
2. Performance bottlenecks (DB, caching, assets)
3. Code quality (SOLID, WP standards, dead code)
4. Error handling (PHP errors, AJAX error states, REST error responses)
5. Uninstall cleanup (does plugin clean up its data?)
6. Compatibility risks (PHP versions, WP versions, popular plugins)
Flag: critical / high / medium / low with file:line references.
```

### 9. Changelog → Test Plan

```
/wordpress-plugin-development
Read CHANGELOG.md and identify what changed in the latest version.
For each change, suggest the most targeted Playwright test to verify it works:
- New widget/block → test it renders on frontend
- Admin setting added → test it saves correctly
- Performance fix → test DB query count didn't regress
- Security fix → write a test that verifies the patch
Output a test plan with file:line pointers for new test cases.
```

### 10. Browser / E2E Automation

```
/antigravity-workflows
Execute the "QA and Browser Automation" workflow for my WordPress plugin.
Plugin path: [path]
Test site: http://localhost:8881
Run through: admin panel, frontend rendering, Elementor editor, responsive viewports.
Use Playwright MCP for browser control.
```

```
/webapp-uat
Full UAT against http://localhost:8881 for plugin [path]:
- Playwright E2E coverage of main user flows
- WCAG 2.2 AA accessibility
- Screenshot regression
- Error console monitoring
```

### 11. Theme Review (NexterWP-style)

```
/wordpress-theme-development
Review the theme at [path]:
- Theme header, required files (style.css, index.php, functions.php)
- Template hierarchy usage
- Child theme compatibility
- Proper use of wp_enqueue_scripts, add_theme_support
- Customizer API implementation
- WooCommerce compatibility hooks
- Block theme requirements (theme.json, block templates)
```

### 12. WooCommerce / EDD Integration

```
/wordpress-woocommerce-development
Review [path] for WooCommerce/EDD compatibility:
- Hook into WC lifecycle correctly (woocommerce_loaded)
- Not overriding WC templates directly
- Using WC CRUD objects, not direct DB queries
- Payment gateway security if applicable
- Correct capability checks on store actions
```

### 13. Test Generation

```
/unit-testing-test-generate
Generate PHPUnit tests for [path]/includes/class-my-plugin.php.
Cover: public methods, edge cases, error paths, WP hook integration.
Include @group annotations for selective runs.
```

```
/tdd-workflows-tdd-cycle
Use TDD to build feature X in [path].
Red-green-refactor: write failing test first, then minimal impl, then refactor.
Pause after each phase for review.
```

### 14. Refactoring & Tech Debt

```
/code-refactoring-refactor-clean
Refactor [path]/includes/legacy.php:
- Extract methods from functions >50 lines
- Remove dead code (unused functions, commented-out blocks)
- Modernize PHP syntax to PHP 8.1 baseline
- Keep behavior identical (no functional changes)
```

```
/codebase-cleanup-tech-debt
Scan [path] and list all tech debt:
- TODO/FIXME/XXX comments older than 6 months
- Deprecated WP API usage
- PHP 5.x syntax that should move to 8.x
- Duplicated code blocks >20 lines
Prioritize by impact × effort.
```

---

## Pre-Built Antigravity Workflows

### Full QA + Browser Automation

```
/antigravity-workflows
Execute the "QA and Browser Automation" workflow for:
- Plugin: [slug]
- Test site: http://localhost:8881
- Focus: full E2E, visual regression, responsive, a11y
```

### Security Audit Workflow

```
/antigravity-workflows
Execute the "Security Audit for Web App" workflow adapted for WordPress plugins.
Target: [path/to/plugin]
Scope: PHP backend security only (no frontend JS).
```

### Design System Audit

```
/antigravity-workflows
Execute a design system audit on [path]/admin/.
Check: color tokens, spacing scale, type ramp, component inventory, a11y contrast.
```

---

## Claude Code One-Liners

Run these directly from terminal against your plugin:

```bash
# Full security scan
claude "/wordpress-penetration-testing Audit ~/plugins/my-plugin for all OWASP Top 10 vulnerabilities"

# Performance — backend
claude "/performance-engineer Find all N+1 queries and caching issues in ~/plugins/my-plugin/includes/"

# Performance — Elementor editor
claude "/performance-engineer Profile editor startup time for ~/plugins/my-plugin using tests/playwright/editor-perf results"

# Admin UI review
claude "/antigravity-design-expert Review the settings UI in ~/plugins/my-plugin/admin/ against concentric radius, hit areas, motion principles"

# Full parallel audit (4 agents at once)
claude "Run 4 parallel audit agents on ~/plugins/my-plugin:
1. /wordpress-plugin-development — WP standards
2. /wordpress-penetration-testing — security
3. /performance-engineer — performance (backend + editor)
4. /database-optimizer — database
Dispatch all 4 simultaneously, merge findings by severity."

# Orchestrated full audit (agent picks skills)
claude "/antigravity-skill-orchestrator Complete pre-release audit on ~/plugins/my-plugin. Security + perf + UI + DB + editor perf. Give prioritized findings."
```

---

## Adding More Skills

Browse the full catalogs:

- [Antigravity Skills](https://github.com/rmyndharis/antigravity-skills) — 300+
- [Antigravity Awesome Skills](https://github.com/sickn33/antigravity-awesome-skills) — 1,400+
- [Awesome Agent Skills (VoltAgent)](https://github.com/VoltAgent/awesome-agent-skills) — 1,000+ from Anthropic, Vercel, Stripe, Figma, etc.

Browse the live site: [sickn33.github.io/antigravity-awesome-skills](https://sickn33.github.io/antigravity-awesome-skills/)

Install any skill, then add its `/slash-command` to Orbit's workflow. Contributions welcome — open a PR in this repo.
