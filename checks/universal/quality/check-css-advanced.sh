#!/usr/bin/env bash
# checks/universal/quality/check-css-advanced.sh
# @see ADR-129
# CSS advanced: @import blocking, stylesheet in body, deep nesting, will-change, universal selector, vendor prefixes
source "$(dirname "$0")/../../../lib/shell/check.sh"
cpm_check_enabled "css-advanced" || exit 0
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

# Find CSS/SCSS/LESS files
CSS_FILES=$(find "$REPO" \( -name "*.css" -o -name "*.scss" -o -name "*.less" \) \
  -not -path "*/node_modules/*" -not -path "*/.next/*" -not -path "*/dist/*" \
  -not -path "*/build/*" -not -path "*/vendor/*" -not -path "*/.git/*" \
  -not -name "*.min.css" 2>/dev/null || true)

# Find HTML files
HTML_FILES=$(find "$REPO" \( -name "*.html" -o -name "*.htm" \) \
  -not -path "*/node_modules/*" -not -path "*/.next/*" -not -path "*/dist/*" \
  -not -path "*/build/*" -not -path "*/vendor/*" -not -path "*/.git/*" 2>/dev/null || true)

# Need at least CSS or HTML files
[ -z "$CSS_FILES" ] && [ -z "$HTML_FILES" ] && exit 0

# --- Rule 1: css-import — @import in CSS files (blocking sequential requests) ---
if [ -n "$CSS_FILES" ]; then
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    IMPORT_LINES=$(grep -n '@import ' "$file" 2>/dev/null | \
      grep -v '^\s*[*/]' || true)
    [ -z "$IMPORT_LINES" ] && continue
    while IFS=: read -r linenum _rest; do
      findings_add "warning" "$file:$linenum" "css-import" \
        "@import creates blocking sequential requests — each import waits for the previous" \
        "Use <link> tags in HTML or bundler imports instead of CSS @import" \
        "https://web.dev/defer-non-critical-css/"
    done <<< "$IMPORT_LINES"
  done <<< "$CSS_FILES"
fi

# --- Rule 2: css-in-body — <link rel="stylesheet"> in <body> instead of <head> ---
if [ -n "$HTML_FILES" ]; then
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    # Extract content after </head> or inside <body>
    body_content=$(sed -n '/<body/,/<\/body>/p' "$file" 2>/dev/null || true)
    [ -z "$body_content" ] && continue
    BODY_CSS=$(echo "$body_content" | grep -n '<link[^>]*rel=.stylesheet' 2>/dev/null | head -1 || true)
    if [ -n "$BODY_CSS" ]; then
      findings_add "warning" "$file" "css-in-body" \
        "<link rel=\"stylesheet\"> in <body> — causes flash of unstyled content (FOUC)" \
        "Move <link rel=\"stylesheet\"> to <head> for render-blocking CSS" \
        "https://developer.mozilla.org/en-US/docs/Web/HTML/Element/link"
    fi
  done <<< "$HTML_FILES"
fi

# --- Rule 3: css-deep-nesting — selectors with >4 levels of nesting ---
if [ -n "$CSS_FILES" ]; then
  # Match selectors like .a .b .c .d .e (5+ space-separated selectors)
  # Also match > combinators: .a > .b > .c > .d > .e
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    DEEP_LINES=$(grep -nE '^\s*[.#a-zA-Z\[][^{]*\s+[.#a-zA-Z\[][^{]*\s+[.#a-zA-Z\[][^{]*\s+[.#a-zA-Z\[][^{]*\s+[.#a-zA-Z\[]' "$file" 2>/dev/null | \
      grep -v '^\s*[*/]' || true)
    [ -z "$DEEP_LINES" ] && continue
    while IFS=: read -r linenum _rest; do
      findings_add "warning" "$file:$linenum" "css-deep-nesting" \
        "CSS selector with >4 levels of nesting — high specificity, hard to override, slower matching" \
        "Flatten selectors using BEM or utility classes" \
        "https://developer.chrome.com/docs/devtools/performance/selector-stats/"
    done <<< "$DEEP_LINES"
  done <<< "$CSS_FILES"

  # Also check SCSS/LESS nesting depth (count nested { braces)
  SCSS_FILES=$(echo "$CSS_FILES" | grep -E '\.(scss|less)$' || true)
  if [ -n "$SCSS_FILES" ]; then
    while IFS= read -r file; do
      [ -z "$file" ] && continue
      # Count max nesting depth by tracking brace depth
      MAX_DEPTH=$(awk '{
        for (i=1; i<=length($0); i++) {
          c = substr($0, i, 1)
          if (c == "{") { depth++; if (depth > max) max = depth }
          if (c == "}") depth--
        }
      } END { print max+0 }' "$file" 2>/dev/null || echo 0)
      if [ "$MAX_DEPTH" -gt 4 ]; then
        findings_add "warning" "$file" "css-deep-nesting" \
          "SCSS/LESS nesting depth $MAX_DEPTH (>4) — compiles to overly specific selectors" \
          "Flatten nesting to max 3 levels; use BEM naming instead" \
          "https://sass-guidelin.es/#selector-nesting"
      fi
    done <<< "$SCSS_FILES"
  fi
fi

# --- Rule 4: css-no-will-change — animated elements without will-change ---
if [ -n "$CSS_FILES" ]; then
  # Files with animation/transition but no will-change
  ANIM_FILES=$(echo "$CSS_FILES" | xargs grep -lE 'animation:|transition:|@keyframes' 2>/dev/null || true)
  if [ -n "$ANIM_FILES" ]; then
    while IFS= read -r file; do
      [ -z "$file" ] && continue
      if ! grep -q 'will-change' "$file" 2>/dev/null; then
        findings_add "info" "$file" "css-no-will-change" \
          "Animations/transitions without will-change — browser may not use GPU compositing" \
          "Add will-change: transform (or opacity) to animated elements for smoother 60fps" \
          "https://developer.mozilla.org/en-US/docs/Web/CSS/will-change"
      fi
    done <<< "$ANIM_FILES"
  fi
fi

# --- Rule 5: css-universal-selector — * selector in non-reset context ---
if [ -n "$CSS_FILES" ]; then
  while IFS= read -r file; do
    [ -z "$file" ] && continue

    # Plain * { ... } selectors
    STAR_LINES=$(grep -n '^\s*\*\s*{' "$file" 2>/dev/null || true)
    if [ -n "$STAR_LINES" ]; then
      while IFS=: read -r linenum _rest; do
        linenum_int=$((linenum))
        context=$(sed -n "${linenum_int},$((linenum_int + 3))p" "$file" 2>/dev/null || true)
        if echo "$context" | grep -qE 'box-sizing|margin:\s*0|padding:\s*0' 2>/dev/null; then
          continue  # This is a CSS reset — acceptable
        fi
        findings_add "warning" "$file:$linenum" "css-universal-selector" \
          "Universal * selector outside of reset context — matches every element, impacts performance" \
          "Target specific elements instead of using *" \
          "https://csswizardry.com/2011/09/writing-efficient-css-selectors/"
      done <<< "$STAR_LINES"
    fi

    # Compound: .something * { ... }
    COMPOUND_LINES=$(grep -nE '[.#a-zA-Z]\s+\*\s*\{' "$file" 2>/dev/null || true)
    if [ -n "$COMPOUND_LINES" ]; then
      while IFS=: read -r linenum _rest; do
        findings_add "warning" "$file:$linenum" "css-universal-selector" \
          "Compound selector with * — forces browser to check all descendants" \
          "Replace .parent * with specific child selectors" \
          "https://csswizardry.com/2011/09/writing-efficient-css-selectors/"
      done <<< "$COMPOUND_LINES"
    fi
  done <<< "$CSS_FILES"
fi

# --- Rule 6: css-redundant-vendor-prefix — vendor prefixes for well-supported properties ---
if [ -n "$CSS_FILES" ]; then
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    REDUNDANT_LINES=$(grep -nE \
      '(-webkit-|-moz-|-ms-)(transform|transition|animation|flex|grid|border-radius|box-shadow|opacity|appearance|user-select)[^-]' \
      "$file" 2>/dev/null | grep -v '^\s*[*/]' || true)
    [ -z "$REDUNDANT_LINES" ] && continue
    while IFS=: read -r linenum _rest; do
      findings_add "info" "$file:$linenum" "css-redundant-vendor-prefix" \
        "Vendor prefix for property that no longer needs it — all modern browsers support unprefixed" \
        "Remove -webkit-/-moz-/-ms- prefix; use Autoprefixer for build-time prefixing" \
        "https://caniuse.com/"
    done <<< "$REDUNDANT_LINES"
  done <<< "$CSS_FILES"
fi
