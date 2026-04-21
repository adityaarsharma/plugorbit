# What Is Everything? — Plain English Explainer

> New to Orbit? Never done automated testing before? This is the page that explains every box in the diagram — what it is, why it exists, and what happens if you skip it.
>
> **Who this is for:** First-time QA engineers, product managers, designers, developers who write code but have never set up automated testing, anyone who looked at the Orbit diagram and thought "what does any of this mean?"

---

## The Big Picture First

Before diving into the pieces, here's what Orbit actually does in one sentence:

> **Orbit runs your WordPress plugin through a series of automated checks — the same checks a senior developer, a security expert, a QA engineer, and a performance specialist would do — and produces reports telling you exactly what needs fixing before you release.**

Normally, "QA" means someone manually clicking through your plugin and writing down what they find. That takes days. Orbit does the equivalent in about 15 minutes, every time, without forgetting anything.

Think of it like a car going through a factory inspection line. Each station checks something specific — brakes, lights, emissions, paint. No station cares about the others. They all run in sequence. At the end, you get a report card.

---

## The Four Layers (What the Diagram Shows)

The diagram shows Orbit has four categories of checks. Here's what each category is doing and why it's separate:

```
YOUR PLUGIN CODE
       │
       ├── STATIC ANALYSIS     ← Reads your code without running it
       ├── BROWSER TESTING     ← Actually opens WordPress and clicks things  
       ├── PERFORMANCE         ← Measures speed and database load
       └── AI SKILL AUDITS     ← AI specialists review code for deep issues
```

They're separate because they check completely different things in completely different ways. You can't catch a SQL injection by running the site in a browser. You can't catch a broken page layout by reading PHP files. Each layer finds problems the others would miss.

---

## Layer 1: Static Analysis

**What "static" means:** Your code is analyzed while it's sitting still — not running, not served, not loaded in a browser. Tools read your PHP files like a document and look for problems.

**The analogy:** A proofreader reviewing a recipe before it goes to the kitchen. They're not cooking anything — they're reading the instructions for mistakes.

---

### PHP Lint

**What it is:** The most basic check possible. It reads every `.php` file and verifies the code is valid PHP syntax.

**The analogy:** Spell-check for code. A missing semicolon, an unclosed bracket, a typo in a function name — Lint catches all of these.

**What failure looks like:**
```
Parse error: syntax error, unexpected token "echo" in
/plugins/my-plugin/includes/class-admin.php on line 47
```

**What happens if you skip it:** A single syntax error in PHP causes a fatal white screen of death. Your plugin breaks. Every visitor to the site gets an error. This is the most embarrassing class of bug because it's the most visible and the easiest to catch.

**Time to run:** ~5 seconds.

> **Q: Doesn't my code editor already catch syntax errors?**
> Usually yes — but only if you have a PHP plugin installed and configured. PHP Lint in CI catches things that slip through when you're working fast or when a team member doesn't have the same editor setup.

---

### PHPCS / WPCS

**What it is:** PHPCS stands for **PHP CodeSniffer**. It checks that your code follows a set of coding standards — not just "does it work" but "is it written the right way."

WPCS stands for **WordPress Coding Standards** — the specific ruleset that defines how WordPress plugin code should be written.

**The analogy:** A style guide enforcer. Like a grammar checker that also checks formatting, naming conventions, and "house rules." Your code might work fine but still fail WPCS if you're using double quotes where WordPress expects single quotes, or if you're outputting user input without sanitizing it first.

**What WPCS actually checks:**
- Are you escaping output? (Preventing hackers from injecting HTML into your pages)
- Are you sanitizing input? (Cleaning data before saving it to the database)
- Are you using nonces? (Security tokens that verify form submissions are legitimate)
- Are function names prefixed? (So they don't conflict with other plugins)
- Are you using WordPress's own functions instead of raw PHP equivalents?

**What failure looks like:**
```
my-plugin/includes/class-admin.php:47 | ERROR | Missing output escaping
my-plugin/includes/class-admin.php:89 | ERROR | User input not sanitized
my-plugin/includes/class-rest.php:12  | WARNING | Missing nonce verification
```

**What happens if you skip it:** PHPCS catches security vulnerabilities, not just style. A missing `esc_html()` call is how XSS attacks happen. A missing `sanitize_text_field()` is how database corruption happens. Many WPCS violations are exploitable vulnerabilities, not aesthetic complaints.

> **Q: What's a nonce?**
> A nonce (number used once) is a one-time security token that WordPress uses to verify that a form submission or AJAX request is coming from the right place. Without it, an attacker can trick a logged-in admin's browser into making requests they didn't intend — called a CSRF attack. WPCS flags every form and AJAX handler that's missing nonce verification.

> **Q: What's escaping output?**
> When you print something on a WordPress page — like a user's name or a setting value — you need to "escape" it first. Escaping converts special characters (`<`, `>`, `"`) into safe HTML entities. Without escaping, an attacker who stores `<script>stealYourCookies()</script>` as their username can run JavaScript in your admin panel. WPCS catches every place where you're printing unescaped data.

---

### PHPStan

**What it is:** PHPStan (PHP Static Analysis Tool) is a logic checker. While PHP Lint checks syntax and PHPCS checks style, PHPStan reads your code and looks for situations that can't possibly work — even if the syntax is perfect and the style is correct.

**The analogy:** A code reviewer who reads your logic and says "wait, you're calling a method on a variable that could be null here — that would crash." Or: "You're passing a string to a function that expects an array — that would produce the wrong result." PHPStan finds these without running the code.

**What PHPStan catches:**
- Calling a method on something that could be `null` (→ Fatal error)
- Passing the wrong type of value to a function
- Accessing array keys that might not exist
- Using variables before they're defined
- Functions that claim to return a string but sometimes return `false`

**What failure looks like:**
```
my-plugin/includes/class-query.php:33
  → Method WP_Post::get_the_title() called on possibly null value
my-plugin/includes/class-settings.php:71
  → Function expects string, int|false given
```

**Level 5** is what Orbit runs by default — a balance between useful and not too noisy. Level 0 catches almost nothing; Level 9 is extremely strict.

**What happens if you skip it:** Type errors and null-pointer issues are the second-most-common source of WordPress fatal errors. They often only happen on edge cases — a post that doesn't exist, a setting that hasn't been saved yet, a user with an unusual role. PHPStan finds them before your users do.

> **Q: My plugin has been working fine for months — why would PHPStan find problems?**
> Because "working fine" means "working in the cases you've tested." PHPStan looks at every possible execution path, including the ones you haven't tested. A function that works 99% of the time but crashes when a post is in draft state will get flagged — even if no one in your test environment has ever had a draft post.

---

### i18n Check

**What it is:** i18n stands for **internationalization** (18 letters between the 'i' and the 'n'). The i18n check verifies that all user-visible text in your plugin is wrapped in WordPress translation functions, making it translatable into other languages.

**The analogy:** A translator's assistant going through your plugin and flagging every sentence that wasn't handed to them — every hardcoded "Save Settings" or "Error: please try again" that a Spanish or French user would see in English no matter what.

**What it checks:**
- Every string that users see should be wrapped in `__()`, `_e()`, `esc_html__()`, or similar functions
- The text domain matches your plugin's registered text domain
- Plural forms use `_n()` correctly (e.g., "1 item" vs "3 items")

**What failure looks like:**
```
Translatable string found, not being passed to a localization function
in /includes/class-admin.php on line 94
```

**What happens if you skip it:** Your plugin can never be translated. WordPress.org plugin review requires i18n compliance. If you ever want to sell or list your plugin internationally, strings you hardcoded today can't be translated without going back through every line.

---

## Layer 2: Browser Testing

**What "browser testing" means:** This is where Orbit actually launches a real WordPress site, opens a real browser, and simulates real user interactions — clicking buttons, filling in forms, checking that pages load correctly.

**The analogy:** Hiring a QA intern who follows a script of "click this, check that, screenshot this, compare to last week's screenshot" — but the intern never gets tired, never forgets a step, and runs the entire script in 2 minutes.

---

### Playwright

**What it is:** Playwright is the browser automation framework Orbit uses. It's a tool made by Microsoft that controls a browser (Chromium, Firefox, or WebKit) through code. You write scripts that say "go to this URL, click this button, check that this text appears" and Playwright executes them in a real browser.

**The analogy:** A remote-control browser. You give it a script; it follows the script exactly, every time.

**What Playwright does in Orbit:**
- Opens your plugin's admin page
- Clicks every button and checks nothing breaks
- Saves settings and verifies they persist
- Loads the frontend and checks the output
- Takes screenshots at every stage

**Why it's not just "running the site in your browser":** Because Playwright runs the same script every single time, on a clean WordPress installation, in CI. It catches regressions — when a new code change breaks something that used to work. Your manual testing only covers what you remember to check. Playwright checks everything, every time.

> **Q: What's a "spec file"?**
> A spec file (specification file) is the script Playwright follows. It's a JavaScript file where each `test()` block is one scenario — like "user can save settings" or "widget renders on frontend." You write it once, and Playwright runs it every time you run the gauntlet.

> **Q: Do I have to write Playwright tests from scratch?**
> No. Orbit ships with templates for 6 plugin types. You copy the template, fill in your plugin's details, and you have a working test suite in about 30 minutes.

---

### Functional Testing

**What it means:** Functional tests verify that your plugin does what it's supposed to do. Does the settings page save? Does the widget appear on the frontend? Does activating the plugin set up the right database tables?

**The difference from visual testing:** Functional = "does it work?" Visual = "does it look right?"

---

### Visual Diff

**What it is:** Orbit takes screenshots of your plugin's UI and compares them to a previously saved "baseline" screenshot, pixel by pixel. If anything changed — a button moved, a color shifted, spacing broke — the test fails and shows you a diff image highlighting exactly what changed.

**The analogy:** Placing a transparency over a photo and comparing them. Any difference shows up immediately.

**Why this matters:** CSS regressions are invisible to code review. You can change a class name, break a layout on mobile, or accidentally hide a button — and none of the code-analysis tools will catch it. Visual diff catches it instantly.

**What a visual diff failure looks like:**

```
Expected     Actual      Diff
[screenshot] [screenshot] [pink highlighted areas showing what changed]
```

**Common cause:** You updated a shared CSS file and accidentally changed the button spacing on a page you didn't intend to touch.

---

### axe-core

**What it is:** axe-core is an automated accessibility testing library. Orbit runs it on every page to check for WCAG (Web Content Accessibility Guidelines) violations — the international standard for making websites usable by people with disabilities.

**The analogy:** A screen reader simulator that checks your pages for things that would prevent blind users, keyboard-only users, or users with motor disabilities from using your plugin.

**What it catches:**
- Form fields with no labels (a screen reader says "edit text" with no context)
- Images with no alt text (a screen reader just says "image")
- Buttons with no text (icon-only buttons without `aria-label`)
- Color contrast failures (text that's too light to read)
- Heading levels that skip from H2 to H4 (confuses screen reader navigation)

**Why it matters even if you're not targeting disabled users:** Accessibility violations affect real users, not just screen reader users. Low contrast affects anyone reading in bright sunlight. Missing form labels affect anyone using autofill. Many countries have legal requirements for accessibility. WordPress.org plugin review checks for basic a11y compliance.

> **Q: What is WCAG?**
> WCAG stands for Web Content Accessibility Guidelines. It's an international standard published by the W3C (the organization that defines web standards). WCAG 2.1 AA is the level most commonly required by law and WordPress.org. It has three levels: A (minimum), AA (standard), AAA (maximum). Orbit checks against AA.

---

### Video UAT

**What it is:** UAT stands for **User Acceptance Testing**. Orbit records a video of the browser during each test run — real clicks, real page loads, real interactions. It then combines these videos into a report designed for non-technical stakeholders.

**The analogy:** A screen recording of a QA session, automatically generated on every run, organized into a shareable HTML report.

**Who this is for:** Product managers, founders, clients, designers — anyone who needs visual proof that features work but doesn't read code or understand test output. You open the UAT report and watch the plugin being used, like watching a demo.

**The comparison feature:** If you have a competitor plugin, Orbit records both side by side. The left column is your plugin; the right column is the competitor. This is the "does ours look better?" check.

---

## Layer 3: Performance

**Why performance is its own layer:** Performance problems don't cause errors — they cause slowness. A plugin that makes your admin panel take 5 seconds to load won't fail PHP Lint or Playwright tests. It needs its own dedicated checks.

---

### Lighthouse

**What it is:** Lighthouse is an open-source tool made by Google that analyzes web pages and scores them on Performance, Accessibility, Best Practices, and SEO. It's the same tool behind Google Chrome's "Inspect → Lighthouse" tab.

**The analogy:** A doctor running standard vitals — blood pressure, heart rate, oxygen levels. Lighthouse measures the equivalent for web pages: how fast does it load, does it shift around while loading, is the main content visible quickly?

**The key metrics Lighthouse measures:**

| Metric | What it means | Plain English |
|---|---|---|
| **LCP** (Largest Contentful Paint) | How long until the main content is visible | "When can I see the page?" |
| **FCP** (First Contentful Paint) | How long until anything appears | "When does the blank screen end?" |
| **TBT** (Total Blocking Time) | How long the browser was frozen processing JS | "How long was the page unresponsive?" |
| **CLS** (Cumulative Layout Shift) | How much the page jumps around while loading | "Did the button move when I was about to click it?" |
| **Speed Index** | How quickly the visible content fills in | Overall visual loading speed |

*LCP, FCP, and TBT are the three metrics that affect your Google Search ranking the most.*

**What a score means:**
- 90–100: Good — no action needed
- 75–89: Needs improvement — worth investigating
- Below 75: Poor — Orbit flags this as a warning
- Below 60: Orbit marks this as a failure (blocks release)

> **Q: My plugin is for the admin panel — does Lighthouse matter?**
> For the frontend (your visitors' experience), yes, a lot. For admin-only plugins, the Lighthouse score matters less. But Orbit runs Lighthouse on both frontend and admin URLs. A slow admin panel is a support ticket waiting to happen.

---

### DB Profiling (Database Profiling)

**What it is:** Orbit counts how many database queries each page makes when your plugin is active, and how long they take. It produces a report like "your admin panel made 67 queries in 289ms."

**The analogy:** A water meter on your plugin. You don't see the water (queries) when you use the plugin, but they're happening in the background. Too many of them — or slow ones — add up to a noticeably sluggish site.

**The N+1 problem (the most common database bug):**

Imagine you have a list of 50 posts. Instead of getting all the metadata in one query, your plugin loops through and runs a separate query for each post:

```php
// BAD: 1 query to get posts + 50 queries for meta = 51 queries
$posts = get_posts(['numberposts' => 50]);
foreach ($posts as $post) {
    $value = get_post_meta($post->ID, '_my_key', true);  // 1 query each
}

// GOOD: 1 query to get posts + 1 query for all meta = 2 queries
$posts = get_posts(['numberposts' => 50, 'update_post_meta_cache' => true]);
foreach ($posts as $post) {
    $value = get_post_meta($post->ID, '_my_key', true);  // served from cache
}
```

The first version runs 51 queries. The second runs 2. On a server under load, that difference is the difference between a 200ms page and a 3-second page.

DB Profiling catches this automatically.

**What the report looks like:**
```
--- Admin Panel ---
Queries: 67   ← WARNING: above threshold of 50
Time:    289ms
```

**Autoloaded options:** Every time any WordPress page loads, it runs one query to load all "autoloaded" options from the database. If your plugin stores large amounts of data as autoloaded options, it slows down every single page on the site — even pages that have nothing to do with your plugin. DB Profiling flags large autoloaded options.

---

### TTFB (Time To First Byte)

**What it is:** TTFB measures how long it takes for the server to start sending a response after a browser requests a page. It's the time between "browser sends the request" and "browser receives the first byte of the response."

**The analogy:** The time between ordering food at a restaurant and the waiter coming back from the kitchen. Everything before the food arrives is TTFB — the kitchen needs to receive the order, prepare it, and hand it to the waiter.

**Why it matters for plugins:** A plugin that runs expensive code on every page load (heavy database queries, external HTTP requests, large option reads) increases TTFB for every visitor to the site — even on pages that don't use the plugin. TTFB above 600ms is a signal that something expensive is happening on the server before the page can render.

---

### Asset Weight

**What it is:** Orbit checks how much JavaScript and CSS your plugin loads, and on which pages it loads them. An "asset" is any JS or CSS file your plugin tells WordPress to include.

**Why this matters:** Many WordPress plugins load their scripts and CSS on every single page — the homepage, the blog, the contact form, the checkout — even on pages where the plugin does nothing. This increases the page's download size and parsing time for every visitor.

**The right approach:**
```php
// BAD: loads on every page
add_action('wp_enqueue_scripts', 'my_plugin_load_assets');

// GOOD: only loads when the shortcode is on the page
add_action('wp_enqueue_scripts', function() {
    if (has_shortcode(get_post()->post_content, 'my_plugin')) {
        wp_enqueue_script('my-plugin');
    }
});
```

Orbit checks for scripts and styles that are loading globally when they should be conditional.

---

## Layer 4: AI Skill Audits

**What it is:** This is where Orbit uses Claude (an AI model made by Anthropic) to review your plugin code with the expertise of six different specialists — simultaneously, in parallel.

**The analogy:** Imagine you could hire six senior developers — one who specializes in WordPress security, one in performance, one in databases, one in accessibility, one in WP standards, and one in code quality — and have all six review your entire codebase and write a report, in about 10 minutes, every time you release. That's what Skill Audits do.

**Why AI and not just more static analysis tools?** Static analysis tools check rules. AI checks intent. A tool can tell you "this function is 200 lines long." An AI can tell you "this function does three different things and here's exactly how to split it, with the refactored code." A tool can flag missing nonces. An AI can explain the specific attack scenario that missing nonce enables for your specific plugin.

> **Q: Does this cost money?**
> Yes — Skill Audits make API calls to Anthropic's Claude API. You need an API key from console.anthropic.com. A typical full audit costs roughly $0.10–0.50 depending on plugin size. For most teams, running audits before each release is a few dollars per month.

> **Q: Can I run Orbit without skill audits?**
> Yes. The first 10 steps of the gauntlet run without any API key. Skill audits are Step 11. You can run `--mode quick` to skip them entirely, or run them only before releases.

---

### The 6 Core Skills

---

#### Skill 1: WP Standards (`/wordpress-plugin-development`)

**Specialist persona:** A senior WordPress.org plugin reviewer who has reviewed 5,000 plugins.

**What it checks:** Whether your plugin follows the WordPress Plugin Handbook's guidelines — not just the automated rules PHPCS checks, but the judgment calls. Is your plugin structured correctly? Are you using WordPress APIs instead of reinventing them? Are you following the unwritten conventions that make plugins maintainable?

**What it finds that PHPCS misses:** Patterns that are technically valid PHP and valid WPCS but are still wrong for WordPress — like registering hooks in the wrong place, using `$_POST` directly instead of WordPress's sanitized equivalents, or not checking `is_admin()` before loading admin-only code.

---

#### Skill 2: Security (`/wordpress-penetration-testing`)

**Specialist persona:** A WordPress security researcher focused on OWASP Top 10 vulnerabilities.

**What it checks:** Actively looks for exploitable vulnerabilities — not just missing best practices, but actual attack vectors.

**The most important findings it catches:**

**SQL Injection (SQLi)** — An attacker crafts a value that breaks out of your database query and runs their own commands. This can wipe your entire database or steal all user data.
```php
// VULNERABLE: attacker sends id=1 OR 1=1-- and gets all rows
$results = $wpdb->get_results("SELECT * FROM wp_posts WHERE ID = " . $_GET['id']);

// SAFE: prepared statement with placeholder
$results = $wpdb->get_results($wpdb->prepare("SELECT * FROM wp_posts WHERE ID = %d", intval($_GET['id'])));
```

**XSS (Cross-Site Scripting)** — An attacker stores malicious JavaScript in your database (via a form your plugin provides) and it runs in other users' browsers, stealing sessions or hijacking accounts.

**CSRF (Cross-Site Request Forgery)** — An attacker creates a malicious webpage that tricks a logged-in admin into unknowingly submitting your plugin's forms — changing settings, deleting data, adding admin accounts.

**Auth Bypass** — A REST API endpoint or AJAX action that doesn't check whether the current user has permission to perform the action, allowing anyone (logged out or not) to trigger it.

---

#### Skill 3: Performance (`/performance-engineer`)

**Specialist persona:** A WordPress performance engineer who has optimized hundreds of sites.

**What it checks beyond Lighthouse:** The underlying code patterns that cause performance problems, not just the symptoms. Lighthouse tells you the page is slow. This skill tells you exactly which function is causing it and provides the fixed version.

**What it finds:** N+1 queries with exact fix, blocking HTTP requests (your plugin calling an external API on every page load — if that API is slow, so is your site), hooks running on the wrong action (loading admin assets on the frontend), transient cache opportunities you're missing.

---

#### Skill 4: Database (`/database-optimizer`)

**Specialist persona:** A database architect focused on WordPress's MySQL patterns.

**What it checks:** Not just "how many queries" but the structure of your queries and tables. Are you using indexes on columns you filter by? Are your prepared statements correct? Are you storing data efficiently or bloating the database?

**What it finds:** Missing indexes (a query that scans every row in a large table instead of jumping straight to the matching rows), autoloaded options that should have `false` as their third argument, custom tables without proper schema design.

---

#### Skill 5: Accessibility (`/accessibility-compliance-accessibility-audit`)

**Specialist persona:** A WCAG 2.2 AA accessibility auditor.

**What it checks:** Both the code-level accessibility (proper ARIA attributes, semantic HTML) and the interaction-level accessibility (can you use this plugin with only a keyboard? does it work with a screen reader?).

**The difference from axe-core:** axe-core is automated and fast — catches the obvious violations. This skill catches the nuanced ones: a modal that traps keyboard focus, a color scheme that technically passes contrast ratio but fails in practice, form validation that only communicates errors visually.

---

#### Skill 6: Code Quality (`/code-review-excellence`)

**Specialist persona:** A senior engineer doing a code review focused on maintainability, correctness, and safety.

**What it checks:** Dead code, overly complex functions (cyclomatic complexity — how many branches and loops something has), missing error handling, type safety issues, functions doing too many things at once.

**Why code quality matters for business:** Complex code is expensive to maintain. A function with 25 branches takes 5× longer to read, test, and safely modify. Code quality findings are often the difference between "fixing this bug takes 1 hour" and "fixing this bug takes a week because nobody understands the code anymore."

---

## Putting It Together: The Gauntlet

**What the gauntlet is:** The gauntlet is the single script (`gauntlet.sh`) that runs all 11 steps in sequence and produces all the reports. "Running the gauntlet" means running your plugin through all four layers of checks.

**Where the name comes from:** "Running the gauntlet" is an old phrase for having to pass through a series of challenges in sequence. If you fail one, you don't necessarily stop — but you know about it. At the end, you have a complete picture.

**The 11 steps in order:**

| Step | What it does | Layer | Time |
|---|---|---|---|
| 1 | PHP Lint | Static Analysis | 5s |
| 2 | PHPCS + WPCS | Static Analysis | 15s |
| 3 | PHPStan | Static Analysis | 20s |
| 4 | Asset Weight Check | Performance | 10s |
| 5 | i18n Check | Static Analysis | 10s |
| 6 | Playwright Tests | Browser Testing | 2–5 min |
| 7 | Lighthouse | Performance | 1 min |
| 8 | DB Profiling | Performance | 30s |
| 9 | Competitor Comparison | Browser Testing | 1–2 min |
| 10 | UI Performance | Performance | 30s |
| 11 | AI Skill Audits (×6) | AI Analysis | 5–10 min |

Steps 1–5 need no running WordPress site. Steps 6–11 need wp-env (Docker) running.

**The two modes:**

`--mode quick` — runs Steps 1–6 only. Takes about 3 minutes. Good for quick sanity checks during development.

Full mode (default) — runs all 11 steps. Takes about 15 minutes. Required before every release.

---

## What Is wp-env?

Since wp-env is mentioned throughout Orbit docs but often assumed to be understood:

**wp-env** is a command-line tool made by the WordPress core team that creates a complete, isolated WordPress installation inside Docker containers — with a real MySQL database, real PHP, and real WordPress — in about 2 minutes, with one command.

**The analogy:** A disposable test apartment. You furnish it (install your plugin), do whatever testing you need, then throw it away. The next time you run it, it's brand new. Nothing carries over between test runs unless you specifically set it up that way. Your real WordPress site is never touched.

**Why not just test on your real site?** Because you need a clean, consistent, reproducible environment. "It works on my site" is not QA — your site has years of accumulated content, settings, and other plugins. A clean wp-env catches bugs your real site hides.

> **Q: Do I have to use Docker?**
> For Steps 6–8 (Playwright, Lighthouse, DB Profiling), yes — they need a real running WordPress site. For Steps 1–5 (static analysis), no — they just read your PHP files. If you only want the code-analysis checks and not the browser tests, you can run `--mode quick` without Docker.

---

## What Is Docker?

Since Docker appears throughout these docs:

**Docker** is a tool that runs software in isolated containers. A container is like a very lightweight virtual machine — it has its own operating system, files, and processes, but shares the underlying hardware with your Mac or Linux machine.

**Why wp-env uses Docker:** WordPress needs PHP and MySQL running. Docker provides those without you having to install and configure PHP and MySQL globally on your computer. When you're done, Docker removes them completely — they don't interfere with anything else.

**The analogy:** Renting a fully furnished kitchen to cook in, then handing it back when you're done — rather than buying all the appliances and cooking in your own house.

---

## The Reports — What You Actually Get

After running the gauntlet, Orbit produces:

| Report | Who reads it | What it contains |
|---|---|---|
| `qa-report-*.md` | Developers | Pass/fail for all 11 steps |
| `skill-audits/index.html` | Developers | AI findings with code, severity, fixes |
| `playwright-html/` | Developers, QA | Test results with screenshots and traces |
| `uat-report-*.html` | Product managers, designers | Videos + screenshots, no code |
| `lighthouse/*.json` | Developers | Performance scores and metrics |
| `db-profile-*.txt` | Developers | Query counts per page |

The most important one for **developers**: `skill-audits/index.html` — open it first.
The most important one for **product managers**: `uat-report-*.html` — the only report with no code.
The most important one for **designers**: `playwright-html/` — the visual regression section shows screenshot diffs.

---

## Severity Levels — The Traffic Light System

Every finding from every audit comes with a severity level. Here's what they mean and what to do:

| Level | Color | What it means | What you do |
|---|---|---|---|
| **Critical** | 🔴 Red | Exploitable security vulnerability or data loss risk | Stop. Fix before writing another line of code. Do not release. |
| **High** | 🟠 Orange | Significant bug, security gap, or UX-breaking performance issue | Fix in this release. Blocks release. |
| **Medium** | 🟡 Yellow | Code quality or minor security issue — exploitable under specific conditions | Fix if it takes less than 30 minutes. Otherwise log it. |
| **Low** | 🟢 Green | Style, naming, minor improvement | Log in your backlog. Don't delay the release. |
| **Info** | ⚪ Grey | Observation, suggestion, or informational note | Read it, decide if it's relevant, move on. |

**The release rule:** Any Critical or High finding blocks release. Period. Not "we'll fix it in the next version" — it gets fixed before the tag.

**Why so strict on Critical/High?** Because these are the findings that affect real users:
- Critical SQLi = an attacker can wipe your user's entire database
- Critical XSS = an attacker can steal admin sessions and take over the site
- High CSRF = a user gets tricked into changing their own settings by visiting a malicious link
- High N+1 = every page load runs 60 database queries instead of 2

These are not hypothetical. These are the exact vulnerabilities found in real WordPress plugins that end up on CVE databases and get reported in security advisories.

---

## Summary: Why All of This Together?

Each tool catches a different category of problem:

```
PHP Lint         → "Does the code even parse?"
PHPCS/WPCS       → "Is it written correctly and safely?"
PHPStan          → "Does the logic make sense?"
Playwright       → "Does it actually work in a browser?"
Visual Diff      → "Did anything break visually?"
Lighthouse       → "Is it fast enough for real users?"
DB Profiling     → "Is it hammering the database?"
AI Skills        → "What would a security expert / performance expert / etc. say?"
```

No single tool is enough. A plugin can pass PHP Lint (valid syntax), pass PHPCS (correct style), pass Playwright (works in browser), and still have a SQL injection vulnerability that the AI security skill catches in 30 seconds.

That's why Orbit runs all of them together. The gauntlet isn't excessive — it's the minimum.

---

**Ready to run your first check?** → [GETTING-STARTED.md](../GETTING-STARTED.md)

**Want to install Orbit?** → [docs/01-installation.md](01-installation.md)

**Want to understand the 11 steps in detail?** → [docs/04-gauntlet.md](04-gauntlet.md)

**Want to understand the AI skill reports?** → [docs/05-skills.md](05-skills.md)
