# Accessibility Checks (120 rules)

cpm includes 120 accessibility checks that detect WCAG 2.2 violations, ARIA misuse, keyboard traps, and visual accessibility issues in HTML, CSS, and component code. These checks are engine-agnostic — they map to rules from axe-core, pa11y, and cpm's own pattern matching.

Every finding includes a WCAG success criterion reference (or BP for best practice) so you know exactly which standard applies and at what conformance level (A, AA, AAA).

## Severity levels

| Severity | Meaning |
|----------|---------|
| `error` | Definite accessibility barrier — must fix |
| `warning` | Likely accessibility issue — should fix |
| `info` | Best practice or potential issue — consider fixing |

## Engine

All checks use `cpm` as the engine. Checks that wrap external tools (axe-core, pa11y) are noted where applicable.

## Categories

| Category | Rules | Range |
|----------|-------|-------|
| [HTML Structure & Document](#html-structure--document) | 12 | A11Y-001 – A11Y-012 |
| [Images & Media](#images--media) | 16 | A11Y-013 – A11Y-028 |
| [Interactive Elements & Keyboard](#interactive-elements--keyboard) | 16 | A11Y-029 – A11Y-044 |
| [Forms](#forms) | 13 | A11Y-045 – A11Y-057 |
| [Landmarks](#landmarks) | 9 | A11Y-058 – A11Y-066 |
| [ARIA Usage](#aria-usage) | 20 | A11Y-067 – A11Y-086 |
| [ARIA Widget Patterns](#aria-widget-patterns) | 7 | A11Y-087 – A11Y-093 |
| [CSS & Visual](#css--visual) | 13 | A11Y-094 – A11Y-106 |
| [Content & Semantics](#content--semantics) | 14 | A11Y-107 – A11Y-120 |
| **Total** | **120** | |

---

### HTML Structure & Document

Foundation checks for valid document structure, language declaration, and semantic HTML hierarchy.

| Rule ID | Title | Severity | Engine | WCAG |
|---------|-------|----------|--------|------|
| A11Y-001 | `html-no-lang` — `<html>` missing `lang` attribute | error | cpm | 3.1.1 A |
| A11Y-002 | `html-lang-invalid` — Invalid `lang` value | warning | cpm | 3.1.1 A |
| A11Y-003 | `no-document-title` — Missing `<title>` element | error | cpm | 2.4.2 A |
| A11Y-004 | `meta-viewport-no-scale` — `user-scalable=no` blocks zoom | error | cpm | 1.4.4 AA |
| A11Y-005 | `meta-viewport-max-scale` — `maximum-scale` too restrictive | warning | cpm | 1.4.4 AA |
| A11Y-006 | `duplicate-id` — Duplicate `id` attributes | warning | cpm | 4.1.1 A |
| A11Y-007 | `heading-order-skip` — Skipped heading levels (e.g., h1 → h3) | warning | cpm | 1.3.1 A |
| A11Y-008 | `empty-heading` — Heading with no text content | warning | cpm | 1.3.1 A |
| A11Y-009 | `p-as-heading` — `<p>` styled as heading (bold/large font) | info | cpm | 1.3.1 A |
| A11Y-010 | `list-invalid-children` — `<ul>`/`<ol>` with non-`<li>` children | warning | cpm | 1.3.1 A |
| A11Y-011 | `dl-invalid-structure` — Invalid definition list structure | warning | cpm | 1.3.1 A |
| A11Y-012 | `table-missing-headers` — Data table without `<th>` elements | warning | cpm | 1.3.1 A |

**Why:** Screen readers rely on correct document structure to navigate. Missing `lang` breaks pronunciation, skipped headings break outline navigation, and invalid list/table structure confuses assistive technology.

**Fix:** Use semantic HTML elements in their correct hierarchy. Set `lang` on `<html>`, use sequential headings, and mark data table headers with `<th>`.

---

### Images & Media

Checks that all non-text content has text alternatives, and media elements provide captions or transcripts.

| Rule ID | Title | Severity | Engine | WCAG |
|---------|-------|----------|--------|------|
| A11Y-013 | `img-missing-alt` — `<img>` without `alt` attribute | error | cpm | 1.1.1 A |
| A11Y-014 | `img-alt-is-filename` — Alt text is just the filename | warning | cpm | 1.1.1 A |
| A11Y-015 | `img-empty-alt-in-link` — Empty alt on image inside link | error | cpm | 1.1.1 A |
| A11Y-016 | `input-image-missing-alt` — `<input type="image">` without `alt` | error | cpm | 1.1.1 A |
| A11Y-017 | `area-missing-alt` — `<area>` without alt text | error | cpm | 1.1.1 A |
| A11Y-018 | `svg-missing-title` — SVG without `<title>` or `aria-label` | warning | cpm | 1.1.1 A |
| A11Y-019 | `svg-missing-role-img` — Meaningful SVG without `role="img"` | info | cpm | 4.1.2 A |
| A11Y-020 | `svg-decorative-not-hidden` — Decorative SVG not `aria-hidden` | info | cpm | 1.1.1 A |
| A11Y-021 | `button-icon-only-no-label` — Icon button without accessible name | error | cpm | 4.1.2 A |
| A11Y-022 | `link-icon-only-no-label` — Icon link without accessible name | error | cpm | 2.4.4 A |
| A11Y-023 | `canvas-missing-fallback` — `<canvas>` without fallback content | warning | cpm | 1.1.1 A |
| A11Y-024 | `video-missing-captions` — `<video>` without captions track | warning | cpm | 1.2.2 A |
| A11Y-025 | `audio-missing-transcript` — `<audio>` without transcript | warning | cpm | 1.2.1 A |
| A11Y-026 | `video-autoplay-with-audio` — Autoplay video without `muted` | error | cpm | 1.4.2 A |
| A11Y-027 | `object-missing-alt` — `<object>` without text alternative | warning | cpm | 1.1.1 A |
| A11Y-028 | `embed-missing-alt` — `<embed>` without accessible name | warning | cpm | 1.1.1 A |

**Why:** Blind and low-vision users depend entirely on text alternatives. Missing alt text makes images invisible. Auto-playing audio disrupts screen reader users. Captions are essential for deaf and hard-of-hearing users.

**Fix:** Add descriptive `alt` text to images. Use `alt=""` only for truly decorative images. Add `<track kind="captions">` to video. Always include `muted` on autoplay video.

---

### Interactive Elements & Keyboard

Ensures all interactive elements are operable via keyboard, have correct roles, and maintain logical tab order.

| Rule ID | Title | Severity | Engine | WCAG |
|---------|-------|----------|--------|------|
| A11Y-029 | `click-on-div` — `onclick` on `<div>`/`<span>` without `role`/`tabindex` | error | cpm | 4.1.2 A |
| A11Y-030 | `click-without-keydown` — `onClick` without keyboard handler | warning | cpm | 2.1.1 A |
| A11Y-031 | `mousedown-without-keydown` — `onMouseDown` without keyboard alternative | warning | cpm | 2.1.1 A |
| A11Y-032 | `mouseover-without-focus` — `onMouseOver` without `onFocus` | warning | cpm | 2.1.1 A |
| A11Y-033 | `interactive-missing-tabindex` — Interactive role without `tabindex` | warning | cpm | 2.1.1 A |
| A11Y-034 | `positive-tabindex` — `tabindex > 0` disrupts tab order | warning | cpm | 2.4.3 A |
| A11Y-035 | `noninteractive-tabindex` — `tabindex` on non-interactive element | info | cpm | 2.4.3 A |
| A11Y-036 | `anchor-no-href` — `<a>` without `href` attribute | warning | cpm | 2.1.1 A |
| A11Y-037 | `anchor-as-button` — `<a href="#">` used as button | warning | cpm | 4.1.2 A |
| A11Y-038 | `button-as-link` — `<button>` used for navigation | info | cpm | 4.1.2 A |
| A11Y-039 | `nested-interactive` — Interactive elements nested inside each other | error | cpm | 4.1.2 A |
| A11Y-040 | `scrollable-not-focusable` — Scrollable container not keyboard accessible | info | cpm | 2.1.1 A |
| A11Y-041 | `autofocus-misuse` — `autofocus` outside dialog | info | cpm | 3.2.1 A |
| A11Y-042 | `multiple-autofocus` — Multiple `autofocus` elements on page | warning | cpm | 3.2.1 A |
| A11Y-043 | `duplicate-accesskey` — Duplicate `accesskey` values | warning | cpm | BP |
| A11Y-044 | `dblclick-without-keyboard` — `ondblclick` without keyboard alternative | warning | cpm | 2.1.1 A |

**Why:** Everything a mouse can do, a keyboard must be able to do. Many users navigate entirely by keyboard — motor disabilities, power users, screen reader users. Broken tab order or missing keyboard handlers create dead ends.

**Fix:** Use native interactive elements (`<button>`, `<a href>`) instead of `<div>` with click handlers. Add `onKeyDown`/`onKeyUp` alongside mouse events. Never use `tabindex > 0`.

---

### Forms

Validates that form controls have proper labels, error messages are announced, and autocomplete is used correctly.

| Rule ID | Title | Severity | Engine | WCAG |
|---------|-------|----------|--------|------|
| A11Y-045 | `input-missing-label` — Form control without label | error | cpm | 1.3.1 A |
| A11Y-046 | `label-missing-for` — `<label>` without `for` attribute | warning | cpm | 1.3.1 A |
| A11Y-047 | `form-field-multiple-labels` — Multiple labels for one input | info | cpm | 3.3.2 A |
| A11Y-048 | `fieldset-missing-legend` — `<fieldset>` without `<legend>` | warning | cpm | 1.3.1 A |
| A11Y-049 | `autocomplete-invalid` — Invalid `autocomplete` value | warning | cpm | 1.3.5 AA |
| A11Y-050 | `select-missing-label` — `<select>` without label | error | cpm | 1.3.1 A |
| A11Y-051 | `textarea-missing-label` — `<textarea>` without label | error | cpm | 1.3.1 A |
| A11Y-052 | `input-placeholder-only` — Placeholder used as only label | warning | cpm | 1.3.1 A |
| A11Y-053 | `required-no-aria` — Required field without `aria-required` | info | cpm | 3.3.2 A |
| A11Y-054 | `form-no-submit` — Form without submit button | info | cpm | 3.2.2 A |
| A11Y-055 | `reset-button-present` — Reset button present (UX risk) | info | cpm | BP |
| A11Y-056 | `form-error-no-role` — Error message without `role="alert"` | info | cpm | 4.1.3 AA |
| A11Y-057 | `input-type-missing` — Input without `type` attribute | info | cpm | 1.3.1 A |

**Why:** Unlabeled form controls are the #1 accessibility issue on the web. Screen readers announce labels — without them, users don't know what a field is for. Placeholders disappear on input and are not reliable labels.

**Fix:** Associate every `<input>`, `<select>`, and `<textarea>` with a `<label>` via `for`/`id`. Use `aria-required="true"` on required fields. Use `role="alert"` on error messages so screen readers announce them immediately.

---

### Landmarks

Checks that pages use landmark regions (`<main>`, `<nav>`, `<header>`, `<footer>`) correctly for structural navigation.

| Rule ID | Title | Severity | Engine | WCAG |
|---------|-------|----------|--------|------|
| A11Y-058 | `no-main-landmark` — Page has no `<main>` element | info | cpm | 2.4.1 A |
| A11Y-059 | `duplicate-main` — Multiple `<main>` elements | warning | cpm | 1.3.1 A |
| A11Y-060 | `duplicate-banner` — Multiple top-level `<header>` elements | info | cpm | 1.3.1 A |
| A11Y-061 | `duplicate-contentinfo` — Multiple top-level `<footer>` elements | info | cpm | 1.3.1 A |
| A11Y-062 | `landmark-not-unique` — Same landmarks without unique labels | info | cpm | 1.3.1 A |
| A11Y-063 | `skip-link-missing` — No skip navigation link | info | cpm | 2.4.1 A |
| A11Y-064 | `nav-missing-aria-label` — Multiple `<nav>` without `aria-label` | info | cpm | 1.3.1 A |
| A11Y-065 | `main-inside-landmark` — `<main>` nested in another landmark | info | cpm | BP |
| A11Y-066 | `aside-missing-label` — `<aside>` without accessible name | info | cpm | 1.3.1 A |

**Why:** Screen reader users navigate by landmarks — they jump from `<main>` to `<nav>` to `<header>` instead of reading every element. Missing or duplicate landmarks break this navigation pattern. Skip links let keyboard users bypass repeated navigation blocks.

**Fix:** Include exactly one `<main>` per page. Use `aria-label` to distinguish multiple `<nav>` elements (e.g., "Primary navigation", "Footer navigation"). Add a skip link as the first focusable element.

---

### ARIA Usage

Validates correct use of ARIA attributes, roles, and relationships. ARIA misuse is worse than no ARIA.

| Rule ID | Title | Severity | Engine | WCAG |
|---------|-------|----------|--------|------|
| A11Y-067 | `aria-hidden-on-focusable` — `aria-hidden` on focusable element | error | cpm | 4.1.2 A |
| A11Y-068 | `aria-hidden-on-body` — `aria-hidden` on `<body>` | error | cpm | 4.1.2 A |
| A11Y-069 | `aria-invalid-value` — Invalid ARIA attribute value | warning | cpm | 4.1.2 A |
| A11Y-070 | `aria-role-invalid` — Non-existent ARIA role | error | cpm | 4.1.2 A |
| A11Y-071 | `aria-labelledby-missing-ref` — `aria-labelledby` points to non-existent ID | warning | cpm | 1.3.1 A |
| A11Y-072 | `aria-describedby-missing-ref` — `aria-describedby` points to non-existent ID | warning | cpm | 1.3.1 A |
| A11Y-073 | `redundant-role` — Redundant role on native element (e.g., `<button role="button">`) | info | cpm | BP |
| A11Y-074 | `aria-on-unsupported` — ARIA on `<meta>`/`<script>`/`<link>` | warning | cpm | 4.1.2 A |
| A11Y-075 | `aria-label-on-generic` — `aria-label` on non-nameable element | info | cpm | 4.1.2 A |
| A11Y-076 | `presentation-with-focusable` — `role="presentation"` with focusable child | warning | cpm | 4.1.2 A |
| A11Y-077 | `prefer-semantic-over-role` — `<div role="X">` instead of native element | info | cpm | BP |
| A11Y-078 | `interactive-to-noninteractive` — Button given non-interactive role | warning | cpm | 4.1.2 A |
| A11Y-079 | `noninteractive-to-interactive` — Paragraph given button role | warning | cpm | 4.1.2 A |
| A11Y-080 | `no-live-region` — Dynamic content without `aria-live` | info | cpm | 4.1.3 AA |
| A11Y-081 | `checkbox-missing-checked` — `role="checkbox"` without `aria-checked` | warning | cpm | 4.1.2 A |
| A11Y-082 | `heading-missing-level` — `role="heading"` without `aria-level` | warning | cpm | 1.3.1 A |
| A11Y-083 | `dialog-missing-label` — Dialog without accessible name | error | cpm | 4.1.2 A |
| A11Y-084 | `combobox-missing-controls` — Combobox without `aria-controls` | warning | cpm | 4.1.2 A |
| A11Y-085 | `combobox-missing-expanded` — Combobox without `aria-expanded` | warning | cpm | 4.1.2 A |
| A11Y-086 | `accordion-missing-expanded` — Accordion trigger without `aria-expanded` | info | cpm | 4.1.2 A |

**Why:** The first rule of ARIA is "don't use ARIA" — native HTML elements already have the right semantics. When ARIA is needed, incorrect usage (wrong values, broken references, contradictory roles) actively harms accessibility by giving screen readers false information.

**Fix:** Prefer native HTML elements over ARIA roles. Ensure all `aria-labelledby`/`aria-describedby` IDs exist. Never put `aria-hidden="true"` on focusable elements. Use `aria-live="polite"` for dynamic content updates.

---

### ARIA Widget Patterns

Validates that composite ARIA widgets (tabs, menus, trees, grids) follow the required parent-child relationships from the WAI-ARIA Authoring Practices.

| Rule ID | Title | Severity | Engine | WCAG |
|---------|-------|----------|--------|------|
| A11Y-087 | `tablist-missing-tabs` — `tablist` without `tab` children | warning | cpm | 4.1.2 A |
| A11Y-088 | `tab-missing-tablist` — `tab` without `tablist` parent | warning | cpm | 4.1.2 A |
| A11Y-089 | `tabpanel-missing-label` — `tabpanel` without accessible name | warning | cpm | 4.1.2 A |
| A11Y-090 | `menu-missing-menuitem` — `menu` without `menuitem` children | warning | cpm | 4.1.2 A |
| A11Y-091 | `tree-missing-treeitem` — `tree` without `treeitem` children | warning | cpm | 4.1.2 A |
| A11Y-092 | `dialog-no-focusable` — Modal dialog without focusable elements | warning | cpm | 2.1.1 A |
| A11Y-093 | `grid-missing-row` — `grid` without `row` children | warning | cpm | 4.1.2 A |

**Why:** ARIA widget patterns have strict parent-child requirements. A `tablist` without `tab` children, or a `tab` without a `tablist` parent, tells the screen reader to expect a pattern that doesn't exist. This breaks keyboard navigation patterns that users rely on.

**Fix:** Follow the [WAI-ARIA Authoring Practices](https://www.w3.org/WAI/ARIA/apg/) for each widget pattern. Ensure correct parent-child role hierarchy. Every dialog must contain at least one focusable element for keyboard users.

---

### CSS & Visual

Detects CSS patterns that break focus visibility, text resizing, motion safety, and visual accessibility.

| Rule ID | Title | Severity | Engine | WCAG |
|---------|-------|----------|--------|------|
| A11Y-094 | `focus-outline-removed` — `outline: none` without replacement | error | cpm | 2.4.7 AA |
| A11Y-095 | `focus-outline-zero` — `outline: 0` on `:focus` | error | cpm | 2.4.7 AA |
| A11Y-096 | `focus-visibility-hidden` — Focus indicator hidden | warning | cpm | 2.4.7 AA |
| A11Y-097 | `hover-no-focus` — `:hover` content without `:focus` equivalent | warning | cpm | 1.4.13 AA |
| A11Y-098 | `font-size-px` — Font sizes in `px` not relative units | info | cpm | 1.4.4 AA |
| A11Y-099 | `line-height-fixed` — Line height in fixed units | info | cpm | 1.4.12 AA |
| A11Y-100 | `motion-no-reduced-motion` — Animation without `prefers-reduced-motion` | warning | cpm | 2.3.3 AAA |
| A11Y-101 | `color-only-link` — Links only distinguished by color | info | cpm | 1.4.1 A |
| A11Y-102 | `opacity-zero-focusable` — Focusable element with `opacity: 0` | warning | cpm | 2.4.7 AA |
| A11Y-103 | `display-none-focusable` — Focusable element with inline `display: none` | info | cpm | 4.1.2 A |
| A11Y-104 | `important-on-outline` — `!important` on outline property | warning | cpm | 2.4.7 AA |
| A11Y-105 | `text-indent-offscreen` — Negative `text-indent` for hiding text | info | cpm | BP |
| A11Y-106 | `visibility-hidden-focus` — `visibility: hidden` on `:focus` | warning | cpm | 2.4.7 AA |

**Why:** Keyboard users need visible focus indicators — removing `outline` without a replacement makes it impossible to see which element is focused. Fixed font sizes prevent browser zoom. Animations can cause vestibular disorders, seizures, or nausea.

**Fix:** Never remove `outline` without providing a custom `:focus-visible` style. Use `rem`/`em` instead of `px` for font sizes. Wrap animations in `@media (prefers-reduced-motion: no-preference)`. Ensure `:hover` content is also available on `:focus`.

---

### Content & Semantics

Validates that content elements have meaning, deprecated elements are avoided, and interactive elements have accessible names.

| Rule ID | Title | Severity | Engine | WCAG |
|---------|-------|----------|--------|------|
| A11Y-107 | `empty-link` — `<a>` with no text content | error | cpm | 2.4.4 A |
| A11Y-108 | `empty-button` — `<button>` with no text content | error | cpm | 4.1.2 A |
| A11Y-109 | `title-on-div` — `title` attribute on non-interactive element | info | cpm | BP |
| A11Y-110 | `marquee-element` — `<marquee>` element used | error | cpm | 2.2.2 A |
| A11Y-111 | `blink-element` — `<blink>` element used | error | cpm | 2.2.2 A |
| A11Y-112 | `deprecated-b-element` — `<b>` instead of `<strong>` | info | cpm | BP |
| A11Y-113 | `deprecated-i-element` — `<i>` instead of `<em>` | info | cpm | BP |
| A11Y-114 | `target-blank-no-rel` — `target="_blank"` without `rel="noopener"` | warning | cpm | 3.2.5 AAA |
| A11Y-115 | `tabindex-on-body` — `tabindex` on `<body>` element | warning | cpm | BP |
| A11Y-116 | `iframe-missing-title` — `<iframe>` without `title` attribute | error | cpm | 2.4.1 A |
| A11Y-117 | `table-layout-role` — Layout table without `role="presentation"` | info | cpm | 1.3.1 A |
| A11Y-118 | `scope-invalid` — `scope` on non-`<th>` element | warning | cpm | 1.3.1 A |
| A11Y-119 | `empty-table-header` — `<th>` without text content | warning | cpm | 1.3.1 A |
| A11Y-120 | `redundant-title-alt` — `title` and `alt` with same value | info | cpm | BP |

**Why:** Empty links and buttons are announced as "link" or "button" with no context — users don't know where they go or what they do. `<marquee>` and `<blink>` are deprecated and cause readability and seizure risks. Iframes without titles are opaque to screen readers.

**Fix:** Ensure every `<a>` and `<button>` has visible text, `aria-label`, or `aria-labelledby`. Replace `<marquee>`/`<blink>` with CSS animations (with reduced-motion support). Add `title` to every `<iframe>`. Use `<strong>`/`<em>` instead of `<b>`/`<i>` for semantic emphasis.

---

## Summary by severity

| Severity | Count | Description |
|----------|-------|-------------|
| error | 26 | Definite barriers — blocks at `guard` and `enforce` levels |
| warning | 55 | Likely issues — blocks at `enforce` level |
| info | 39 | Best practices — shown at `learn` and `guide` levels |

## Summary by WCAG level

| WCAG Level | Count | Description |
|------------|-------|-------------|
| A | 90 | Minimum conformance — essential accessibility |
| AA | 21 | Standard conformance — required by most regulations (EU, Section 508) |
| AAA | 2 | Enhanced conformance — highest accessibility standard |
| BP | 7 | Best practice — not tied to a specific WCAG criterion |

## Configuration

Enable accessibility checks in `cpm.toml`:

```toml
[checks]
code-web-accessibility-lint = true
```

Skip individual rules:

```toml
[checks.accessibility]
skip = ["A11Y-098", "A11Y-099"]   # allow px font sizes in this project
```

Set conformance target:

```toml
[checks.accessibility]
wcag-level = "AA"    # A | AA | AAA (default: AA)
```

## Compliance mapping

These checks support compliance with:

| Regulation | Relevant checks |
|------------|----------------|
| **EU Accessibility Act (2025)** | All 120 checks |
| **WCAG 2.2 Level A** | 90 checks |
| **WCAG 2.2 Level AA** | 111 checks (A + AA) |
| **Section 508 (US)** | All Level A + AA checks |
| **EN 301 549 (EU)** | All Level A + AA checks |

## References

- [WCAG 2.2 Quick Reference](https://www.w3.org/WAI/WCAG22/quickref/)
- [WAI-ARIA Authoring Practices](https://www.w3.org/WAI/ARIA/apg/)
- [axe-core Rules](https://github.com/dequelabs/axe-core/blob/develop/doc/rule-descriptions.md)
- [pa11y Documentation](https://pa11y.org/)
- @see docs/adrs/adr-013-product-positioning.md (accessibility as core belief)
- @see docs/checks/check-vue-a11y.md (Vue-specific a11y checks)
- @see docs/checks/check-inclusivity.md (inclusive language checks)
- @see docs/checks/check-css.md (CSS quality checks)
