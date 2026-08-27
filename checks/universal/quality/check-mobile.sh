#!/usr/bin/env bash
# checks/universal/quality/check-mobile.sh
# @see ADR-129
# Mobile-friendliness: small fonts, fixed widths, missing media queries, missing touch targets
source "$(dirname "$0")/../../../lib/shell/check.sh"
cpm_check_enabled "mobile" || exit 0
set -o nounset -o pipefail

REPO="${1:-.}"

# IS_WEB detectie
IS_WEB=false
[ -f "$REPO/index.html" ] && IS_WEB=true
[ -d "$REPO/public" ] && IS_WEB=true
[ -d "$REPO/app" ] && [ -f "$REPO/package.json" ] && IS_WEB=true
[ -f "$REPO/next.config.ts" ] || [ -f "$REPO/next.config.js" ] || [ -f "$REPO/next.config.mjs" ] && IS_WEB=true
[ -f "$REPO/angular.json" ] && IS_WEB=true
[ -f "$REPO/vite.config.ts" ] && IS_WEB=true
[ -f "$REPO/nuxt.config.ts" ] && IS_WEB=true
[ "$IS_WEB" = false ] && exit 0

# --- Collect CSS/SCSS/LESS files ---
CSS_FILES=$(find "$REPO" \( -name "*.css" -o -name "*.scss" -o -name "*.less" \) \
  -not -path "*/node_modules/*" -not -path "*/.next/*" -not -path "*/dist/*" \
  -not -path "*/build/*" -not -path "*/vendor/*" -not -path "*/.git/*" \
  -not -path "*/coverage/*" -not -name "*.min.css" 2>/dev/null || true)
[ -z "$CSS_FILES" ] && exit 0

# --- Rule 1: mobile-font-too-small — Base font-size <16px on body/html ---
# Search for body/html font-size declarations with small pixel values
SMALL_FONT_FOUND=false
while IFS= read -r cssfile; do
  [ -z "$cssfile" ] && continue
  # Match lines with font-size and a pixel value, then filter by context
  while IFS=: read -r linenum line; do
    [ -z "$linenum" ] && continue
    px_val=$(echo "$line" | grep -oE '[0-9]+' | head -1)
    [ -z "$px_val" ] && continue
    if [ "$px_val" -lt 16 ] 2>/dev/null; then
      REL_FILE="${cssfile#$REPO/}"
      findings_add "warning" "$REL_FILE:$linenum" "mobile-font-too-small" \
        "Base font-size ${px_val}px is below 16px — text appears tiny on mobile devices" \
        "Set body/html font-size to at least 16px or use rem units" \
        "https://developer.chrome.com/docs/lighthouse/seo/font-size"
      SMALL_FONT_FOUND=true
      break 2  # one finding per project is enough
    fi
  done < <(grep -nE '(html|body|:root).*font-size\s*:\s*[0-9]+px' "$cssfile" 2>/dev/null || true)

  # Also check: font-size on a line that follows a html/body selector within 5 lines
  if [ "$SMALL_FONT_FOUND" = false ]; then
    while IFS=: read -r linenum line; do
      [ -z "$linenum" ] && continue
      px_val=$(echo "$line" | grep -oE 'font-size\s*:\s*([0-9]+)px' | grep -oE '[0-9]+' || true)
      [ -z "$px_val" ] && continue
      if [ "$px_val" -lt 16 ] 2>/dev/null; then
        # Check if preceding 5 lines contain html/body selector
        start=$((linenum - 5))
        [ "$start" -lt 1 ] && start=1
        if sed -n "${start},${linenum}p" "$cssfile" 2>/dev/null | grep -qE '^\s*(html|body|:root)\s*(\{|,)'; then
          REL_FILE="${cssfile#$REPO/}"
          findings_add "warning" "$REL_FILE:$linenum" "mobile-font-too-small" \
            "Base font-size ${px_val}px is below 16px — text appears tiny on mobile devices" \
            "Set body/html font-size to at least 16px or use rem units" \
            "https://developer.chrome.com/docs/lighthouse/seo/font-size"
          SMALL_FONT_FOUND=true
          break 2
        fi
      fi
    done < <(grep -nE 'font-size\s*:\s*[0-9]+px' "$cssfile" 2>/dev/null || true)
  fi
done <<< "$CSS_FILES"

# --- Rule 2: mobile-fixed-width — Fixed pixel widths >400px without responsive alternatives ---
while IFS= read -r cssfile; do
  [ -z "$cssfile" ] && continue
  # Skip files that already have media queries (they handle responsiveness)
  grep -qE '@media|@container' "$cssfile" 2>/dev/null && continue

  while IFS=: read -r linenum line; do
    [ -z "$linenum" ] && continue
    # Skip max-width and min-width (those are responsive patterns)
    echo "$line" | grep -qE 'max-width|min-width' && continue
    px_val=$(echo "$line" | grep -oE 'width\s*:\s*([0-9]+)px' | grep -oE '[0-9]+' || true)
    [ -z "$px_val" ] && continue
    if [ "$px_val" -gt 400 ] 2>/dev/null; then
      REL_FILE="${cssfile#$REPO/}"
      findings_add "warning" "$REL_FILE:$linenum" "mobile-fixed-width" \
        "Fixed width ${px_val}px without responsive alternatives — overflows on mobile screens" \
        "Use max-width instead of width, or add @media queries for smaller screens" \
        "https://web.dev/articles/responsive-web-design-basics"
      break 2  # one finding per project is enough
    fi
  done < <(grep -nE 'width\s*:\s*[0-9]+px' "$cssfile" 2>/dev/null || true)
done <<< "$CSS_FILES"

# --- Rule 3: mobile-no-media-queries — No @media or @container queries in entire project ---
HAS_MEDIA=false
echo "$CSS_FILES" | xargs grep -lE '@media|@container' 2>/dev/null | head -1 | grep -q . && HAS_MEDIA=true

if [ "$HAS_MEDIA" = false ]; then
  # Also check for CSS-in-JS media queries in JS/TS files
  JS_FILES=$(find "$REPO" \( -name "*.tsx" -o -name "*.jsx" -o -name "*.ts" -o -name "*.js" \) \
    -not -path "*/node_modules/*" -not -path "*/.next/*" -not -path "*/dist/*" \
    -not -path "*/build/*" -not -path "*/.git/*" 2>/dev/null || true)
  if [ -n "$JS_FILES" ]; then
    echo "$JS_FILES" | xargs grep -lE '@media|useMediaQuery|useBreakpoint|matchMedia' 2>/dev/null | head -1 | grep -q . && HAS_MEDIA=true
  fi

  if [ "$HAS_MEDIA" = false ]; then
    FIRST_CSS=$(echo "$CSS_FILES" | head -1)
    REL_CSS="${FIRST_CSS#$REPO/}"
    findings_add "warning" "$REL_CSS" "mobile-no-media-queries" \
      "No @media or @container queries found — layout won't adapt to different screen sizes" \
      "Add @media (max-width: 768px) { ... } breakpoints for mobile/tablet" \
      "https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_media_queries/Using_media_queries"
  fi
fi

# --- Rule 4: mobile-no-touch-action — No touch-action CSS or touch target sizing ---
HAS_TOUCH=false

# Check for touch-action CSS property
echo "$CSS_FILES" | xargs grep -lE 'touch-action' 2>/dev/null | head -1 | grep -q . && HAS_TOUCH=true

# Check for minimum touch target sizing (48px/44px per WCAG)
if [ "$HAS_TOUCH" = false ]; then
  echo "$CSS_FILES" | xargs grep -lE 'min-(width|height)\s*:\s*4[4-9]px|min-(width|height)\s*:\s*[5-9][0-9]px' 2>/dev/null | head -1 | grep -q . && HAS_TOUCH=true
fi

# Check for tap-highlight or touch-specific styles
if [ "$HAS_TOUCH" = false ]; then
  echo "$CSS_FILES" | xargs grep -lE '-webkit-tap-highlight|touch-callout' 2>/dev/null | head -1 | grep -q . && HAS_TOUCH=true
fi

if [ "$HAS_TOUCH" = false ]; then
  # Check if there are interactive elements (buttons, links, inputs) styled in CSS
  HAS_INTERACTIVE=$(echo "$CSS_FILES" | xargs grep -lE '^\s*(button|\.btn|input\[type|a\s*\{|a:|\.link)' 2>/dev/null | head -1 || true)
  if [ -n "$HAS_INTERACTIVE" ]; then
    REL_FILE="${HAS_INTERACTIVE#$REPO/}"
    findings_add "warning" "$REL_FILE" "mobile-no-touch-action" \
      "Interactive elements without touch-action CSS — may cause scroll/zoom issues on mobile" \
      "Add touch-action: manipulation to buttons/links and ensure min 48x48px touch targets" \
      "https://web.dev/articles/accessible-tap-targets"
  fi
fi
