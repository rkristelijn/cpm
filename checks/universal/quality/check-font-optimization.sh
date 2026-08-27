#!/usr/bin/env bash
# checks/universal/quality/check-font-optimization.sh
# @see ADR-129
# Font optimization: woff2, font-display, preload, subsetting, CLS prevention
source "$(dirname "$0")/../../../lib/shell/check.sh"
cpm_check_enabled "font-optimization" || exit 0
set -o nounset -o pipefail

REPO="${1:-.}"

# IS_WEB detection
IS_WEB=false
[ -f "$REPO/index.html" ] && IS_WEB=true
[ -d "$REPO/public" ] && IS_WEB=true
[ -d "$REPO/app" ] && [ -f "$REPO/package.json" ] && IS_WEB=true
[ -f "$REPO/next.config.ts" ] || [ -f "$REPO/next.config.js" ] || [ -f "$REPO/next.config.mjs" ] && IS_WEB=true
[ -f "$REPO/angular.json" ] && IS_WEB=true
[ -f "$REPO/vite.config.ts" ] && IS_WEB=true
[ -f "$REPO/nuxt.config.ts" ] && IS_WEB=true
[ "$IS_WEB" = false ] && exit 0

# Exclude pattern for find
EXCLUDE_DIRS="node_modules\|\.next\|dist\|build\|vendor\|coverage\|\.git\|__pycache__\|\.cache\|target\|out"

# Collect CSS/SCSS files
CSS_FILES=$(find "$REPO" -type f \( -name "*.css" -o -name "*.scss" -o -name "*.less" \) 2>/dev/null | \
  grep -v "$EXCLUDE_DIRS" | grep -v "\.min\." || true)

# Collect HTML-like template files
HTML_FILES=$(find "$REPO" -type f \( \
  -name "*.html" -o -name "*.htm" -o -name "*.jsx" -o -name "*.tsx" \
  -o -name "*.vue" -o -name "*.svelte" \
  \) 2>/dev/null | grep -v "$EXCLUDE_DIRS" || true)

# Extract all @font-face blocks into a temp variable for reuse
FONT_FACE_FILES=""
if [ -n "$CSS_FILES" ]; then
  FONT_FACE_FILES=$(echo "$CSS_FILES" | xargs grep -l "@font-face" 2>/dev/null || true)
fi

# --- Rule 1: font-no-woff2 — @font-face without woff2 format ---
check_no_woff2() {
  [ -z "$FONT_FACE_FILES" ] && return

  while IFS= read -r file; do
    [ -f "$file" ] || continue
    # Extract @font-face blocks and check for woff2
    # Use awk to find @font-face blocks that don't mention woff2
    local blocks_without_woff2
    blocks_without_woff2=$(awk '
      /@font-face/{in_block=1; block=""; start=NR}
      in_block{block=block "\n" $0}
      in_block && /\}/ {
        in_block=0
        if (block !~ /woff2/) print start
      }
    ' "$file" 2>/dev/null || true)

    if [ -n "$blocks_without_woff2" ]; then
      local linenum
      linenum=$(echo "$blocks_without_woff2" | head -1)
      findings_add "warning" "$file:$linenum" "font-no-woff2" \
        "@font-face without woff2 format — woff2 is 30% smaller than woff and supported by all modern browsers" \
        "Add woff2 as the first src format: src: url('font.woff2') format('woff2')" \
        "https://web.dev/articles/reduce-webfont-size#web_font_formats"
      return  # one finding is enough
    fi
  done <<< "$FONT_FACE_FILES"
}

# --- Rule 2: font-no-display — @font-face without font-display ---
check_no_display() {
  [ -z "$FONT_FACE_FILES" ] && return

  while IFS= read -r file; do
    [ -f "$file" ] || continue
    local blocks_without_display
    blocks_without_display=$(awk '
      /@font-face/{in_block=1; block=""; start=NR}
      in_block{block=block "\n" $0}
      in_block && /\}/ {
        in_block=0
        if (block !~ /font-display/) print start
      }
    ' "$file" 2>/dev/null || true)

    if [ -n "$blocks_without_display" ]; then
      local linenum
      linenum=$(echo "$blocks_without_display" | head -1)
      findings_add "warning" "$file:$linenum" "font-no-display" \
        "@font-face without font-display — causes invisible text (FOIT) while font loads" \
        "Add font-display: swap; (or optional) to @font-face blocks" \
        "https://web.dev/articles/font-display"
      return
    fi
  done <<< "$FONT_FACE_FILES"
}

# --- Rule 3: font-too-many — More than 3 font families loaded ---
check_too_many_families() {
  [ -z "$CSS_FILES" ] && return

  # Collect unique font-family names from @font-face declarations
  local families
  families=$(echo "$CSS_FILES" | xargs grep -h "font-family" 2>/dev/null | \
    sed -n "s/.*font-family[[:space:]]*:[[:space:]]*['\"]\\{0,1\\}\([^'\";}]*\\).*/\1/p" | \
    sed 's/[[:space:]]*$//' | sort -u || true)
  [ -z "$families" ] && return

  # Filter out generic families (serif, sans-serif, monospace, etc.)
  families=$(echo "$families" | grep -viE "^(serif|sans-serif|monospace|cursive|fantasy|system-ui|inherit|initial|unset)$" || true)
  [ -z "$families" ] && return

  local count
  count=$(echo "$families" | wc -l | tr -d ' ')
  if [ "$count" -gt 3 ]; then
    local family_list
    family_list=$(echo "$families" | head -5 | tr '\n' ', ' | sed 's/,$//')
    findings_add "warning" "$REPO" "font-too-many" \
      "$count font families loaded ($family_list) — each family adds HTTP requests and render-blocking time" \
      "Limit to 2-3 font families; use system fonts for body text where possible" \
      "https://web.dev/articles/font-best-practices#be_cautious_when_using_preload"
  fi
}

# --- Rule 4: font-too-many-weights — More than 6 weight/style variants ---
check_too_many_weights() {
  [ -z "$FONT_FACE_FILES" ] && return

  # Count @font-face blocks (each represents one weight/style variant)
  local variant_count=0
  while IFS= read -r file; do
    [ -f "$file" ] || continue
    local count
    count=$(grep -c "@font-face" "$file" 2>/dev/null || true)
    variant_count=$((variant_count + ${count:-0}))
  done <<< "$FONT_FACE_FILES"

  if [ "$variant_count" -gt 6 ]; then
    findings_add "warning" "$REPO" "font-too-many-weights" \
      "$variant_count font weight/style variants loaded — each adds ~20-100KB of download" \
      "Limit to regular + bold (+ italic if needed); use font-synthesis for missing variants" \
      "https://web.dev/articles/reduce-webfont-size#limit_the_character_set"
  fi
}

# --- Rule 5: font-no-preload — No <link rel="preload" as="font"> ---
check_no_preload() {
  # Only check if fonts are used
  [ -z "$FONT_FACE_FILES" ] && return
  [ -z "$HTML_FILES" ] && return

  local has_preload=false
  echo "$HTML_FILES" | xargs grep -l 'rel="preload".*as="font"\|rel="preload".*type="font' 2>/dev/null | head -1 | grep -q . && has_preload=true

  # Also check for preload in JSX (Next.js, etc.)
  if [ "$has_preload" = false ]; then
    echo "$HTML_FILES" | xargs grep -l "rel=\"preload\"" 2>/dev/null | \
      xargs grep -l "as=\"font\"" 2>/dev/null | head -1 | grep -q . && has_preload=true
  fi

  # Check for next/font (Next.js auto-handles preloading)
  if [ "$has_preload" = false ]; then
    local js_files
    js_files=$(find "$REPO" -type f \( -name "*.js" -o -name "*.ts" -o -name "*.jsx" -o -name "*.tsx" \) 2>/dev/null | \
      grep -v "$EXCLUDE_DIRS" || true)
    if [ -n "$js_files" ]; then
      echo "$js_files" | xargs grep -l "next/font\|@next/font" 2>/dev/null | head -1 | grep -q . && has_preload=true
    fi
  fi

  if [ "$has_preload" = false ]; then
    findings_add "warning" "$REPO" "font-no-preload" \
      "No <link rel=\"preload\" as=\"font\"> — fonts are discovered late, delaying text rendering" \
      "Add to <head>: <link rel=\"preload\" href=\"font.woff2\" as=\"font\" type=\"font/woff2\" crossorigin>" \
      "https://web.dev/articles/codelab-preload-web-fonts"
  fi
}

# --- Rule 6: font-third-party — Fonts from external CDN ---
check_third_party() {
  local all_files
  all_files=""
  [ -n "$CSS_FILES" ] && all_files="$CSS_FILES"
  [ -n "$HTML_FILES" ] && all_files="${all_files:+$all_files
}$HTML_FILES"
  [ -z "$all_files" ] && return

  local cdn_refs
  cdn_refs=$(echo "$all_files" | xargs grep -n "fonts\.googleapis\.com\|fonts\.gstatic\.com\|use\.typekit\.net" 2>/dev/null || true)
  [ -z "$cdn_refs" ] && return

  local first_ref
  first_ref=$(echo "$cdn_refs" | head -1)
  local file linenum
  file=$(echo "$first_ref" | cut -d: -f1)
  linenum=$(echo "$first_ref" | cut -d: -f2)

  findings_add "warning" "$file:$linenum" "font-third-party" \
    "Fonts loaded from external CDN — adds DNS lookup, connection, and blocks rendering on third-party availability" \
    "Self-host fonts: download from Google Fonts and serve from your domain with proper Cache-Control headers" \
    "https://web.dev/articles/font-best-practices#self-host_your_web_fonts"
}

# --- Rule 7: font-large-file — Font files >100KB (not subsetted) ---
check_large_font() {
  local font_files
  font_files=$(find "$REPO" -type f \( -name "*.woff2" -o -name "*.woff" -o -name "*.ttf" -o -name "*.otf" \) 2>/dev/null | \
    grep -v "$EXCLUDE_DIRS" || true)
  [ -z "$font_files" ] && return

  while IFS= read -r file; do
    [ -f "$file" ] || continue
    local size
    size=$(wc -c < "$file" 2>/dev/null | tr -d ' ')
    if [ "$size" -gt 102400 ]; then
      local size_kb=$((size / 1024))
      findings_add "warning" "$file" "font-large-file" \
        "Font file is ${size_kb}KB (>100KB) — likely not subsetted, contains unused glyphs" \
        "Subset with: pyftsubset font.ttf --unicodes=\"U+0000-00FF\" --flavor=woff2 (latin only)" \
        "https://web.dev/articles/reduce-webfont-size#unicode-range_subsetting"
    fi
  done <<< "$font_files"
}

# --- Rule 8: font-no-size-adjust — @font-face without size-adjust for CLS ---
check_no_size_adjust() {
  [ -z "$FONT_FACE_FILES" ] && return

  local has_adjustment=false
  # Check if any @font-face block has size-adjust or ascent-override
  echo "$FONT_FACE_FILES" | xargs grep -l "size-adjust\|ascent-override\|descent-override\|line-gap-override" 2>/dev/null | \
    head -1 | grep -q . && has_adjustment=true

  # Also check for next/font which handles this automatically
  if [ "$has_adjustment" = false ]; then
    local js_files
    js_files=$(find "$REPO" -type f \( -name "*.js" -o -name "*.ts" -o -name "*.jsx" -o -name "*.tsx" \) 2>/dev/null | \
      grep -v "$EXCLUDE_DIRS" || true)
    if [ -n "$js_files" ]; then
      echo "$js_files" | xargs grep -l "next/font\|@next/font" 2>/dev/null | head -1 | grep -q . && has_adjustment=true
    fi
  fi

  if [ "$has_adjustment" = false ]; then
    local first_file
    first_file=$(echo "$FONT_FACE_FILES" | head -1)
    findings_add "warning" "$first_file" "font-no-size-adjust" \
      "@font-face without size-adjust or ascent-override — web font swap causes layout shift (CLS)" \
      "Add size-adjust to @font-face to match fallback font metrics, or use next/font which does this automatically" \
      "https://web.dev/articles/css-size-adjust"
  fi
}

# --- Run all checks ---
check_no_woff2
check_no_display
check_too_many_families
check_too_many_weights
check_no_preload
check_third_party
check_large_font
check_no_size_adjust
