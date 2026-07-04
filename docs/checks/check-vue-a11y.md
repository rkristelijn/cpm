# check-vue-a11y

`checks/javascript/vue/check-vue-a11y.sh`

Detects accessibility (a11y) anti-patterns in Electron + Vue 3 + Element Plus applications.

## Usage

```bash
bash checks/javascript/vue/check-vue-a11y.sh .
```

## What it detects

### Electron accessibility

| Finding | Description |
|---|---|
| `a11y-role-application-root` | `role="application"` on root layout traps screen reader in forms mode |
| `a11y-titlebar-no-role` | Custom titlebar without `role="toolbar"` — invisible to assistive tech |
| `a11y-shortcuts-not-announced` | globalShortcut without `aria-keyshortcuts` — SR can't discover shortcuts |
| `a11y-no-focus-management` | No focus trap/management for BrowserWindow — keyboard users get lost |

### Vue 3 dynamic content

| Finding | Description |
|---|---|
| `a11y-no-aria-live` | v-if/v-show content without `aria-live` — updates invisible to SR |
| `a11y-route-not-announced` | Route changes not announced via aria-live region |
| `a11y-modal-no-focus-trap` | Modal/dialog without focus trap — keyboard can tab behind overlay |

### Element Plus components

| Finding | Description |
|---|---|
| `a11y-dropdown-no-current` | el-dropdown without `aria-current` for active selection |
| `a11y-tree-no-expanded` | el-tree/sidebar without `aria-expanded` on collapsible nodes |
| `a11y-tabs-no-label` | el-tabs without `aria-label` — tab group purpose unclear |

### Editor / contenteditable

| Finding | Description |
|---|---|
| `a11y-contenteditable-no-role` | contenteditable without `role="textbox"` |
| `a11y-contenteditable-no-multiline` | contenteditable without `aria-multiline` |
| `a11y-contenteditable-no-label` | contenteditable without `aria-label` or `aria-labelledby` |

### Images & icons

| Finding | Description |
|---|---|
| `a11y-img-no-alt` | `<img>` without `alt` attribute |
| `a11y-icon-btn-no-label` | Icon-only button without `aria-label` |

### Keyboard accessibility

| Finding | Description |
|---|---|
| `a11y-click-no-keyboard` | `@click` on non-interactive elements without `@keydown` equivalent |
| `a11y-tabindex-positive` | `tabindex > 0` disrupts natural tab order |
| `a11y-outline-removed` | `outline: none` without `focus-visible` replacement |

### Color & motion

| Finding | Description |
|---|---|
| `a11y-color-only-state` | State conveyed by color alone (missing icon/text/aria-invalid) |
| `a11y-no-reduced-motion` | Animations without `prefers-reduced-motion` media query |

## Severity

warning

## References

- Source: `checks/javascript/vue/check-vue-a11y.sh`
- [ARIA Authoring Practices Guide](https://www.w3.org/WAI/ARIA/apg/)
- [Electron Accessibility](https://www.electronjs.org/docs/latest/tutorial/accessibility)
- [Vue A11y](https://vuejs.org/guide/best-practices/accessibility.html)
- [Element Plus Accessibility](https://element-plus.org/en-US/guide/accessibility.html)
