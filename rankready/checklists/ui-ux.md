# RankReady Admin — UI/UX Checklist
> Covers the v0.6+ admin panel: 6-tab layout (Dashboard, Content AI, Authority, AI Crawlers, Settings, Advanced)

Run before every release that touches admin UI.

---

## Layout & Spacing

- [ ] **Concentric border radius** — `.rr-card` (8px) → inner `.rr-stat` / `.rr-info-item` (6px) → buttons (4px)
- [ ] **No horizontal overflow** — at 375px, 768px, 1440px (check Elementor sidebar width ~320px too)
- [ ] **Consistent spacing scale** — gaps/padding follow 4px or 8px grid
- [ ] **Min hit area 44×44px** — dashboard feature card links, tab buttons, form buttons

## Visual Depth

- [ ] **Shadows on cards** — `.rr-card`, `.rr-stat`, `.rr-info-item` use `box-shadow`, not solid borders
- [ ] **No tinted neutral borders** for depth — use `rgba(0,0,0,0.08)` outline only on images/media

## Typography

- [ ] **Font smoothing** — `.rr-wrap { -webkit-font-smoothing: antialiased; }` in admin.css
- [ ] **Heading text-wrap** — `.rr-title`, `.rr-card-title` use `text-wrap: balance`
- [ ] **Stat numbers** — `.rr-stat-number` uses `font-variant-numeric: tabular-nums`

## Interactions

- [ ] **Tab transitions** — `.rr-tab-content` fades in with `rr-fade-up` animation (opacity + translateY)
- [ ] **No `transition: all`** — specific properties listed in all transition rules
- [ ] **Collapsible Display Options** — `.rr-details` `<details>/<summary>` opens smoothly, arrow rotates

## Forms & Inputs

- [ ] **All inputs have visible labels** — no placeholder-only labels in Settings or Content AI tabs
- [ ] **API key field** — `#rr_api_key` is type="password" or has masking behavior
- [ ] **Save actions show success state** — not silent (Settings options-updated notice visible)
- [ ] **Destructive actions need confirmation** — "Delete all data on uninstall" toggle has warning context
- [ ] **Toggle switches have text labels** — auto-generate toggles labeled "Enable / Disable"

## Dashboard Tab

- [ ] **4 stat cards visible** — Posts with Summary, Posts with FAQ, Total Summaries, Total FAQs
- [ ] **6 feature cards visible** — Content AI, Authority, AI Crawlers, Settings, Advanced, Plugin Info
- [ ] **API key warning banner** shows when OpenAI key is missing
- [ ] **Feature card links** navigate to the correct tab on click

## Content AI Tab

- [ ] **Section divider** separates AI Summary from FAQ Generator
- [ ] **Display Options collapsible** — closed by default, expands to show label/position/style fields
- [ ] **Two save buttons** — one per settings form (Summary settings, FAQ settings)

## Authority Tab

- [ ] **Section divider** separates Author Box from Schema Automation
- [ ] **Author Box form** shows all EEAT fields (name, bio, credentials, social links)

## AI Crawlers Tab

- [ ] **Robots.txt controls** — per-crawler toggles labeled with bot names (not just codes)
- [ ] **LLMs.txt status** — shows current state (enabled/disabled + URL)

## Settings Tab

- [ ] **`#rr_api_key`** field present and labeled
- [ ] **DataForSEO fields** present (if configured)

## Advanced Tab

- [ ] **Headless API section** — CORS allowlist, revalidation webhook fields labeled clearly
- [ ] **Health Check** — shows results in a readable format, not raw JSON
- [ ] **Plugin Info** — version, active features list visible

## Automated Coverage

The following checks run automatically via Playwright:

- `tests/admin.spec.js` — all 6 tabs load, no fatal errors, legacy redirects, collapsible, LLMs.txt endpoint
