#!/usr/bin/env bash
# checks/javascript/vue/check-vue-a11y.sh
# Accessibility (a11y) anti-patterns for Electron + Vue 3 + Element Plus
# @see https://www.w3.org/WAI/ARIA/apg/
# @see https://www.electronjs.org/docs/latest/tutorial/accessibility
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../../lib/shell/init.sh" 2>/dev/null || true
cpm_check_enabled "js-vue-a11y" || exit 0
set -o nounset -o pipefail

REPO="${1:-.}"
cpm_has_dep "vue" "$REPO" || exit 0

FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-36s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

SRC=$(cpm_find_src "$REPO")
[ -z "$SRC" ] && exit 0

VUE_FILES=$(find $SRC -name "*.vue" -not -path "*/node_modules/*" 2>/dev/null || true)
TS_FILES=$(find $SRC \( -name "*.ts" -o -name "*.js" \) -not -path "*/node_modules/*" 2>/dev/null || true)
ALL_FILES="$VUE_FILES $TS_FILES"
[ -z "$VUE_FILES" ] && exit 0

# --- ELECTRON A11Y ---

# 1. role="application" on root (traps screen reader in forms mode)
if echo "$VUE_FILES" | xargs grep -n 'role="application"' 2>/dev/null | grep -iE "app\.vue|layout|main" | head -1 | grep -q .; then
  finding "a11y-role-application-root" "role=application on root — traps screen reader, use only on canvas/editor"
fi

# 2. Custom titlebar without toolbar semantics
TITLEBAR_FILES=$(echo "$VUE_FILES" | xargs grep -liE "titlebar\|title-bar\|window-controls" 2>/dev/null || true)
if [ -n "$TITLEBAR_FILES" ]; then
  NO_ROLE=$(echo "$TITLEBAR_FILES" | xargs grep -L 'role="toolbar"' 2>/dev/null | head -1 || true)
  [ -n "$NO_ROLE" ] && finding "a11y-titlebar-no-role" "Custom titlebar without role=toolbar — invisible to assistive tech"
fi

# 3. globalShortcut without aria-keyshortcuts announcement
if echo "$TS_FILES" | xargs grep -l "globalShortcut\|registerAccelerator\|Accelerator" 2>/dev/null | head -1 | grep -q .; then
  if ! echo "$VUE_FILES" | xargs grep -l "aria-keyshortcuts" 2>/dev/null | head -1 | grep -q .; then
    finding "a11y-shortcuts-not-announced" "Keyboard shortcuts without aria-keyshortcuts — screen readers can't discover them"
  fi
fi

# 4. BrowserWindow without focus management
if echo "$TS_FILES" | xargs grep -l "new BrowserWindow" 2>/dev/null | head -1 | grep -q .; then
  if ! echo "$ALL_FILES" | xargs grep -lE "focus-trap|focusTrap|useFocusTrap|\.focus\(\)" 2>/dev/null | head -1 | grep -q .; then
    finding "a11y-no-focus-management" "BrowserWindow without focus trap/management — keyboard users get lost"
  fi
fi

# --- VUE 3 DYNAMIC CONTENT ---

# 5. v-if content without aria-live (invisible updates)
VIF_FILES=$(echo "$VUE_FILES" | xargs grep -l "v-if\|v-show" 2>/dev/null | grep -v node_modules || true)
if [ -n "$VIF_FILES" ]; then
  NO_LIVE=$(echo "$VIF_FILES" | xargs grep -L "aria-live\|role=\"alert\"\|role=\"status\"" 2>/dev/null | wc -l | tr -d ' ')
  VIF_TOTAL=$(echo "$VIF_FILES" | wc -l | tr -d ' ')
  if [ "${NO_LIVE:-0}" -gt "$((VIF_TOTAL * 3 / 4))" ] && [ "${VIF_TOTAL:-0}" -gt 5 ]; then
    finding "a11y-no-aria-live" "Dynamic content (v-if/v-show) without aria-live regions — updates invisible to SR"
  fi
fi

# 6. Router view transitions not announced
if echo "$VUE_FILES" | xargs grep -l "router-view\|RouterView" 2>/dev/null | head -1 | grep -q .; then
  if ! echo "$ALL_FILES" | xargs grep -lE "aria-live.*route\|announce.*route\|useRoute.*announce" 2>/dev/null | head -1 | grep -q .; then
    finding "a11y-route-not-announced" "Route changes not announced — add aria-live region for page transitions"
  fi
fi

# 7. Modal/dialog without focus trap
MODAL_FILES=$(echo "$VUE_FILES" | xargs grep -liE "el-dialog\|el-drawer\|modal\|dialog" 2>/dev/null | grep -v node_modules || true)
if [ -n "$MODAL_FILES" ]; then
  NO_TRAP=$(echo "$MODAL_FILES" | xargs grep -L "focus-trap\|focusTrap\|trap-focus\|lock-scroll" 2>/dev/null | head -1 || true)
  [ -n "$NO_TRAP" ] && finding "a11y-modal-no-focus-trap" "Modal/dialog without focus trap — keyboard users can tab behind overlay"
fi

# --- ELEMENT PLUS SPECIFIC ---

# 8. el-dropdown items without aria-current for active state
if echo "$VUE_FILES" | xargs grep -l "el-dropdown" 2>/dev/null | head -1 | grep -q .; then
  if ! echo "$VUE_FILES" | xargs grep -l "aria-current" 2>/dev/null | head -1 | grep -q .; then
    finding "a11y-dropdown-no-current" "el-dropdown without aria-current — active selection not conveyed to SR"
  fi
fi

# 9. el-tree / sidebar without proper tree roles
TREE_FILES=$(echo "$VUE_FILES" | xargs grep -liE "el-tree\|file-tree\|sidebar.*tree\|tree.*sidebar" 2>/dev/null || true)
if [ -n "$TREE_FILES" ]; then
  NO_EXPANDED=$(echo "$TREE_FILES" | xargs grep -L "aria-expanded" 2>/dev/null | head -1 || true)
  [ -n "$NO_EXPANDED" ] && finding "a11y-tree-no-expanded" "Tree/sidebar without aria-expanded — collapse state invisible to SR"
fi

# 10. el-tabs without accessible name
if echo "$VUE_FILES" | xargs grep -l "el-tabs" 2>/dev/null | head -1 | grep -q .; then
  if ! echo "$VUE_FILES" | xargs grep -n "el-tabs" 2>/dev/null | grep -q "aria-label"; then
    finding "a11y-tabs-no-label" "el-tabs without aria-label — tab group purpose unclear to SR"
  fi
fi

# --- EDITOR / CONTENTEDITABLE ---

# 11. contenteditable without role=textbox
if echo "$VUE_FILES" | xargs grep -l "contenteditable" 2>/dev/null | head -1 | grep -q .; then
  if ! echo "$VUE_FILES" | xargs grep -n "contenteditable" 2>/dev/null | grep -q 'role="textbox"'; then
    finding "a11y-contenteditable-no-role" "contenteditable without role=textbox — SR doesn't recognize as input"
  fi
fi

# 12. contenteditable without aria-multiline
if echo "$VUE_FILES" | xargs grep -l "contenteditable" 2>/dev/null | head -1 | grep -q .; then
  if ! echo "$VUE_FILES" | xargs grep -n "contenteditable" 2>/dev/null | grep -q "aria-multiline"; then
    finding "a11y-contenteditable-no-multiline" "contenteditable without aria-multiline — SR can't convey multiline behavior"
  fi
fi

# 13. contenteditable without aria-label or aria-labelledby
if echo "$VUE_FILES" | xargs grep -l "contenteditable" 2>/dev/null | head -1 | grep -q .; then
  if ! echo "$VUE_FILES" | xargs grep -n "contenteditable" 2>/dev/null | grep -qE "aria-label|aria-labelledby"; then
    finding "a11y-contenteditable-no-label" "contenteditable without aria-label — unnamed editable region"
  fi
fi

# --- IMAGES & ICONS ---

# 14. <img> without alt
if echo "$VUE_FILES" | xargs grep -n "<img" 2>/dev/null | grep -v "alt=" | grep -v "node_modules" | head -1 | grep -q .; then
  finding "a11y-img-no-alt" "img without alt attribute — image invisible/confusing to SR users"
fi

# 15. Icon buttons without accessible label
ICON_BTNS=$(echo "$VUE_FILES" | xargs grep -nE "<(el-button|button).*icon|<.*-icon.*\/>" 2>/dev/null | grep -v "aria-label\|title=\|sr-only\|visually-hidden" | grep -v node_modules || true)
if [ -n "$ICON_BTNS" ] && echo "$ICON_BTNS" | head -1 | grep -q .; then
  finding "a11y-icon-btn-no-label" "Icon-only button without aria-label — button purpose unknown to SR"
fi

# --- KEYBOARD ---

# 16. Click handlers without keyboard equivalent
CLICK_ONLY=$(echo "$VUE_FILES" | xargs grep -n "@click" 2>/dev/null | grep -v "@keydown\|@keyup\|@keypress\|button\|el-button\|<a \|router-link\|<input\|<select" | grep -v node_modules || true)
if echo "$CLICK_ONLY" | wc -l | grep -qE "^[1-9][0-9]"; then
  finding "a11y-click-no-keyboard" "Many @click handlers on non-interactive elements — add @keydown for keyboard access"
fi

# 17. tabindex > 0 (disrupts natural tab order)
if echo "$VUE_FILES" | xargs grep -nE 'tabindex="[1-9]' 2>/dev/null | grep -v node_modules | head -1 | grep -q .; then
  finding "a11y-tabindex-positive" "tabindex > 0 disrupts natural tab order — use 0 or -1 only"
fi

# 18. Outline removed (focus indicator invisible)
CSS_FILES=$(find $SRC \( -name "*.css" -o -name "*.scss" -o -name "*.less" \) -not -path "*/node_modules/*" 2>/dev/null || true)
if [ -n "$CSS_FILES" ]; then
  if echo "$CSS_FILES" | xargs grep -n "outline.*none\|outline.*0" 2>/dev/null | grep -v "// a11y\|/\* a11y\|focus-visible" | head -1 | grep -q .; then
    finding "a11y-outline-removed" "outline: none without focus-visible replacement — keyboard users can't see focus"
  fi
fi

# --- COLOR & CONTRAST ---

# 19. Color-only state indication (disabled, error, active)
if echo "$VUE_FILES" | xargs grep -nE "color.*error|color.*danger|:style.*color" 2>/dev/null | grep -v "icon\|aria-\|role=" | grep -v node_modules | wc -l | grep -qE "^[5-9]|^[0-9]{2}"; then
  finding "a11y-color-only-state" "State conveyed by color alone — add icon, text, or aria-invalid for color-blind users"
fi

# 20. prefers-reduced-motion not respected
if echo "$CSS_FILES $VUE_FILES" | xargs grep -l "animation\|transition" 2>/dev/null | head -3 | grep -q .; then
  if ! echo "$CSS_FILES" | xargs grep -l "prefers-reduced-motion" 2>/dev/null | head -1 | grep -q .; then
    finding "a11y-no-reduced-motion" "Animations without prefers-reduced-motion — motion-sensitive users affected"
  fi
fi

if [ $FINDINGS -eq 0 ]; then
  echo "  ✓ Vue accessibility checked"
else
  echo ""
  echo "  $FINDINGS Vue accessibility finding(s)"
fi
