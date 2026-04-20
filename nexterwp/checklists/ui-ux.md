# NexterWP — UI/UX Checklist
> Covers admin panel, Gutenberg blocks, and block editor UI.

Run before every release that touches admin UI or block editor components.

---

## Layout & Spacing

- [ ] **No horizontal overflow** — at 375px, 768px, 1440px
- [ ] **Consistent spacing scale** — gaps/padding follow 4px or 8px grid
- [ ] **Min hit area 44×44px** — all clickable elements (buttons, toggles, icon buttons)
- [ ] **Concentric border radius** — nested elements use `outer-radius = inner-radius + padding`

## Visual Depth

- [ ] **Shadows over borders** — use `box-shadow` for depth, not solid borders
- [ ] **Image outlines** — `outline: 1px solid rgba(0,0,0,0.08)` on any media

## Typography

- [ ] **Font smoothing** — `body { -webkit-font-smoothing: antialiased; }` in admin styles
- [ ] **Heading text-wrap** — headings use `text-wrap: balance`

## Interactions

- [ ] **Scale on press = 0.96** — buttons/cards use exactly `transform: scale(0.96)` on `:active`
- [ ] **No `transition: all`** — specific properties listed in all transition rules
- [ ] **Interruptible hover states** — CSS transitions not keyframe animations

## Forms & Inputs

- [ ] **All inputs have visible labels** — no placeholder-only labels
- [ ] **Error states are clear** — red border + message, not just color change
- [ ] **Success feedback** — save actions show a success state (not silent)
- [ ] **Destructive actions need confirmation** — delete/reset require confirm dialog

## Gutenberg Block Panels

- [ ] **Block controls in correct Inspector section** — Style, Settings, Advanced tabs used correctly
- [ ] **Block doesn't break on empty/default state** — no white-screen with zero content
- [ ] **Block toolbar buttons labeled** — `aria-label` present on all toolbar items
- [ ] **Placeholder state looks designed** — empty block shows a helpful UI, not a blank box
- [ ] **Responsive controls labeled clearly** — Desktop/Tablet/Mobile icons present for all size/spacing controls

## Automated Coverage

The following checks run automatically via Playwright:

- `tests/admin.spec.js` — activation, block editor load, JS errors, PHP fatal errors
