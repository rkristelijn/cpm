#!/usr/bin/env bash
# checks/javascript/check-accessibility.sh
# @see ADR-129
# Accessibility (a11y) patterns for React + MUI projects.
# Catches issues that axe-core/Lighthouse would flag in production.
set -o nounset -o pipefail

REPO="${1:-.}"
[ -f "$REPO/package.json" ] && grep -q '"react"' "$REPO/package.json" || exit 0

FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

SRC=""
[ -d "$REPO/src" ] && SRC="$REPO/src"
[ -d "$REPO/app" ] && SRC="${SRC:+$SRC }$REPO/app"
[ -z "$SRC" ] && exit 0

# 1. Images without alt text
if grep -rn "<img\b" $SRC --include="*.tsx" 2>/dev/null | grep -v node_modules | grep -v "alt=" | head -1 | grep -q .; then
  finding "a11y-img-no-alt" "<img> without alt attribute — screen readers can't describe image"
fi

# 2. onClick on non-interactive element (div, span) without role/tabIndex
if grep -rn "onClick=" $SRC --include="*.tsx" 2>/dev/null | grep -v node_modules | grep -v "Button\|button\|Link\|IconButton\|MenuItem\|ListItem\|Tab\|Chip\|Card\|Fab" | grep -v "role=\|tabIndex\|onKeyDown\|onKeyPress" | head -1 | grep -q .; then
  finding "a11y-click-no-keyboard" "onClick on non-interactive element without role/tabIndex/onKeyDown"
fi

# 3. Form inputs without labels
if grep -rn "<input\|<TextField\|<Select\|<Autocomplete" $SRC --include="*.tsx" 2>/dev/null | grep -v node_modules | grep -v "label=\|aria-label\|InputLabel\|FormLabel\|id=.*label" | head -1 | grep -q .; then
  finding "a11y-input-no-label" "Form input without label/aria-label — unusable for screen readers"
fi

# 4. Color as only indicator (no icon/text alongside)
if grep -rn "color=\"error\"\|color=\"success\"\|color=\"warning\"" $SRC --include="*.tsx" 2>/dev/null | grep -v node_modules | grep -v "Icon\|icon\|aria-\|startIcon\|endIcon" | head -1 | grep -q .; then
  finding "a11y-color-only" "Color used as sole indicator — add icon/text for colorblind users"
fi

# 5. Missing lang attribute on html
if grep -rl "<html" $SRC --include="*.tsx" 2>/dev/null | xargs grep -L "lang=" 2>/dev/null | head -1 | grep -q .; then
  finding "a11y-no-lang" "<html> without lang attribute — assistive tech can't determine language"
fi

# 6. Autofocus (disorients screen reader users)
if grep -rn "autoFocus\|autofocus" $SRC --include="*.tsx" 2>/dev/null | grep -v node_modules | head -1 | grep -q .; then
  finding "a11y-autofocus" "autoFocus used — disorients screen reader users, use focused state instead"
fi

# 7. Positive tabIndex (disrupts natural tab order)
if grep -rn "tabIndex=[\"']\?[1-9]" $SRC --include="*.tsx" 2>/dev/null | grep -v node_modules | head -1 | grep -q .; then
  finding "a11y-positive-tabindex" "tabIndex > 0 — disrupts natural tab order, use 0 or -1 only"
fi

# 8. No skip-to-content link
if ! grep -rq "skip.*content\|skip.*nav\|SkipLink\|skipLink" $SRC --include="*.tsx" 2>/dev/null; then
  finding "a11y-no-skip-link" "No skip-to-content link — keyboard users must tab through entire nav"
fi

# 9. IconButton without aria-label
if grep -rn "<IconButton" $SRC --include="*.tsx" 2>/dev/null | grep -v node_modules | grep -v "aria-label\|title=" | head -1 | grep -q .; then
  finding "a11y-icon-no-label" "IconButton without aria-label — button has no accessible name"
fi

# 10. Heading hierarchy skipped (h1 → h3 without h2)
if grep -rn "variant=\"h" $SRC --include="*.tsx" 2>/dev/null | grep -v node_modules | grep -oP 'h[1-6]' | sort -u | tr -d 'h' > /tmp/headings.txt 2>/dev/null; then
  PREV=0
  while read -r LVL; do
    if [ "$PREV" -gt 0 ] && [ "$((LVL - PREV))" -gt 1 ]; then
      finding "a11y-heading-skip" "Heading hierarchy skips level (h$PREV → h$LVL) — confuses screen readers"
      break
    fi
    PREV=$LVL
  done < /tmp/headings.txt
  rm -f /tmp/headings.txt
fi

# 11. No aria-live for dynamic content
if grep -rq "isLoading\|isPending\|Skeleton\|CircularProgress" $SRC --include="*.tsx" 2>/dev/null; then
  if ! grep -rq "aria-live\|aria-busy\|role=\"status\"\|role=\"alert\"" $SRC --include="*.tsx" 2>/dev/null; then
    finding "a11y-no-aria-live" "Dynamic content without aria-live — screen readers won't announce updates"
  fi
fi

# 12. Dialog/Modal without proper focus trap
if grep -rn "<Dialog\|<Modal\|<Drawer" $SRC --include="*.tsx" 2>/dev/null | grep -v node_modules | head -1 | grep -q .; then
  if ! grep -rq "aria-labelledby\|aria-label" $SRC --include="*.tsx" 2>/dev/null; then
    finding "a11y-modal-no-label" "Dialog/Modal without aria-labelledby — not accessible"
  fi
fi

[ "$FINDINGS" -eq 0 ] && printf "  \033[32m✓\033[0m  Accessibility: all checks passed\n"
exit 0
