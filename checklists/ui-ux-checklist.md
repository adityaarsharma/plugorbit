# UI/UX Quality Checklist
> Based on jakubkrehel/make-interfaces-feel-better + WordPress product design standards

Run this checklist before every release for admin panels, widget settings, and block editors.

---

## Layout & Spacing

- [ ] **Concentric border radius** — nested elements use `outer-radius = inner-radius + padding`. E.g. if card has `border-radius: 12px` with `8px` padding, inner button should be `4px`.
- [ ] **Optical alignment** — icons, play buttons, and asymmetric elements are visually centered (not just geometrically). Especially check icon-only buttons.
- [ ] **No horizontal overflow** — at all breakpoints (375px, 768px, 1440px). Test with `document.documentElement.scrollWidth > clientWidth`.
- [ ] **Consistent spacing scale** — gaps/padding follow 4px or 8px grid. No random pixel values.
- [ ] **Min hit area 44×44px** — every clickable element: buttons, toggles, links, icon buttons.

---

## Visual Depth

- [ ] **Shadows over borders** — use layered `box-shadow` for depth, not solid borders where possible. Shadows adapt across backgrounds.
  ```css
  /* Good */
  box-shadow: 0 1px 2px rgba(0,0,0,0.04), 0 4px 12px rgba(0,0,0,0.08);
  /* Avoid for depth */
  border: 1px solid #e0e0e0;
  ```
- [ ] **Image outlines** — product/widget images have a subtle 1px outline: `outline: 1px solid rgba(0,0,0,0.08)` (light mode) or `rgba(255,255,255,0.1)` (dark mode). No tinted neutrals.

---

## Typography

- [ ] **Font smoothing at root** — `body { -webkit-font-smoothing: antialiased; }` in the admin stylesheet.
- [ ] **Heading text-wrap** — headings use `text-wrap: balance`. Body uses `text-wrap: pretty`.
- [ ] **Tabular numbers** — any counter, price, stat, or dynamically updating number uses `font-variant-numeric: tabular-nums` to prevent layout shifts.
- [ ] **No orphans** — single words dangling on last line of paragraphs. Use `text-wrap: pretty` or manual `&nbsp;` for critical headings.

---

## Interactions & Animation

- [ ] **Scale on press = 0.96** — all buttons/cards that respond to press use exactly `transform: scale(0.96)`. Not 0.95 (too heavy), not 0.98 (no feedback).
  ```css
  button:active { transform: scale(0.96); transition: transform 80ms ease; }
  ```
- [ ] **No `transition: all`** — always list specific properties: `transition: transform 200ms ease, opacity 200ms ease`.
- [ ] **Interruptible hover states** — use CSS transitions (not keyframe animations) for hover/focus so users can exit mid-animation.
- [ ] **Staggered enter animations** — when multiple items appear, each delays ~80-100ms: `animation-delay: calc(var(--i) * 80ms)`.
- [ ] **Subtle exits** — exit animations use `translateY(4px)` and `opacity: 0`, not dramatic movement.
- [ ] **Skip animation on initial render** — don't animate elements already visible on page load.
- [ ] **`will-change` only for GPU properties** — only `transform`, `opacity`, `filter`. Never `will-change: all`.

---

## Forms & Inputs (Admin Panels / Settings)

- [ ] **All inputs have visible labels** — no placeholder-only labels. Screen reader accessible.
- [ ] **Error states are clear** — red border + message, not just color change.
- [ ] **Success feedback** — save actions show a success state (not silent).
- [ ] **Toggle switches have text labels** — "Enable / Disable" not just a toggle with no context.
- [ ] **Destructive actions need confirmation** — delete, reset, deactivate require a confirm dialog.

---

## Product-Specific: Page Builder Widget Panels (Plugin A)

- [ ] **Widget settings panel doesn't overflow** on narrow Page Builder sidebar (320px wide).
- [ ] **Section tabs navigable by keyboard** (Tab key cycles through).
- [ ] **Responsive controls labeled clearly** — Desktop/Tablet/Mobile icons are present for all size/spacing controls.
- [ ] **Color pickers use correct defaults** — not empty/blank on first use.
- [ ] **Dynamic content selects are searchable** — long lists have search input.

---

## Product-Specific: Gutenberg Block Panels (Plugin A)

- [ ] **Block controls in correct Inspector section** — Style, Settings, Advanced tabs used correctly.
- [ ] **Block doesn't break on empty/default state** — no white-screen with zero content.
- [ ] **Block toolbar buttons labeled** — `aria-label` present on all toolbar items.
- [ ] **Placeholder state looks designed** — empty block shows a helpful UI, not a blank box.

---

## Complex Widget / Flow Quality Gates

Ask these questions before shipping a new feature:

- Is the flow obvious to a developer seeing it for the first time?
- Can a user complete the main task in under 3 clicks?
- Does the UI explain *why* an option is disabled (tooltip, notice)?
- Are unnecessary options hidden until needed (progressive disclosure)?
- Does complexity add real user value, or is it developer-minded design?

**Red flags:**
- More than 5 top-level tabs in a settings panel
- Settings with no description or help text
- Options that only matter to <5% of users shown prominently
- Modal dialogs that open other modal dialogs

---

## Automated Coverage

The following UI checks run automatically in Playwright:

- `responsive.spec.js` — horizontal overflow, hit area size, viewport screenshots
- `core.spec.js` — JS console errors, 404 assets, load time budget
- `axe-core` — WCAG 2.1 AA color contrast, labels, roles
