#!/usr/bin/env bash
# checks/universal/quality/check-image-optimization.sh
# @see ADR-129
# Image optimization: WebP/AVIF, lazy loading, srcset, fetchpriority, SVG icons
source "$(dirname "$0")/../../../lib/shell/check.sh"
cpm_check_enabled "image-optimization" || exit 0
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

# Collect HTML-like template files
HTML_FILES=$(find "$REPO" -type f \( \
  -name "*.html" -o -name "*.htm" -o -name "*.jsx" -o -name "*.tsx" \
  -o -name "*.vue" -o -name "*.svelte" \
  \) 2>/dev/null | grep -v "$EXCLUDE_DIRS" || true)

# Collect CSS/SCSS files
CSS_FILES=$(find "$REPO" -type f \( -name "*.css" -o -name "*.scss" -o -name "*.less" \) 2>/dev/null | \
  grep -v "$EXCLUDE_DIRS" | grep -v "\.min\." || true)

# --- Rule 1: img-no-webp — JPEG/PNG without WebP/AVIF equivalents ---
check_no_webp() {
  local raster_images
  raster_images=$(find "$REPO" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" \) 2>/dev/null | \
    grep -v "$EXCLUDE_DIRS" || true)
  [ -z "$raster_images" ] && return

  local missing_modern=0
  while IFS= read -r img; do
    [ -f "$img" ] || continue
    local base="${img%.*}"
    # Check if a WebP or AVIF equivalent exists
    if [ ! -f "${base}.webp" ] && [ ! -f "${base}.avif" ]; then
      missing_modern=$((missing_modern + 1))
    fi
  done <<< "$raster_images"

  if [ "$missing_modern" -gt 0 ]; then
    findings_add "warning" "$REPO" "img-no-webp" \
      "$missing_modern JPEG/PNG image(s) without WebP/AVIF equivalent — modern formats are 25-50% smaller" \
      "Convert with: cwebp image.png -o image.webp or use <picture> with multiple sources" \
      "https://web.dev/articles/serve-images-webp"
  fi
}

# --- Rule 2: img-no-lazy — <img> without loading="lazy" (skip first per file) ---
check_no_lazy() {
  [ -z "$HTML_FILES" ] && return

  while IFS= read -r file; do
    [ -f "$file" ] || continue
    # Get all img lines, skip the first one per file (likely LCP)
    local img_lines
    img_lines=$(grep -n "<img " "$file" 2>/dev/null | tail -n +2 || true)
    [ -z "$img_lines" ] && continue

    echo "$img_lines" | while IFS=: read -r linenum line; do
      if ! echo "$line" | grep -q 'loading='; then
        findings_add "warning" "$file:$linenum" "img-no-lazy" \
          "<img> without loading=\"lazy\" — defers offscreen images to speed up initial load" \
          "Add loading=\"lazy\" to non-hero images" \
          "https://web.dev/articles/browser-level-image-lazy-loading"
        return  # one finding per file is enough
      fi
    done
  done <<< "$HTML_FILES"
}

# --- Rule 3: img-no-srcset — <img> without srcset ---
check_no_srcset() {
  [ -z "$HTML_FILES" ] && return

  local files_with_img
  files_with_img=$(echo "$HTML_FILES" | xargs grep -l "<img " 2>/dev/null || true)
  [ -z "$files_with_img" ] && return

  local count=0
  while IFS= read -r file; do
    [ -f "$file" ] || continue
    local missing
    missing=$(grep -c "<img " "$file" 2>/dev/null | tr -d ' ' || true)
    missing=${missing:-0}
    local has_srcset
    has_srcset=$(grep -c "srcset=" "$file" 2>/dev/null | tr -d ' ' || true)
    has_srcset=${has_srcset:-0}
    if [ "$missing" -gt 0 ] && [ "$has_srcset" -eq 0 ]; then
      count=$((count + 1))
    fi
  done <<< "$files_with_img"

  if [ "$count" -gt 0 ]; then
    findings_add "warning" "$REPO" "img-no-srcset" \
      "$count file(s) with <img> tags but no srcset — serve different sizes for different viewports" \
      "Add srcset and sizes attributes: <img srcset=\"img-480.webp 480w, img-800.webp 800w\" sizes=\"(max-width: 600px) 480px, 800px\">" \
      "https://web.dev/articles/serve-responsive-images"
  fi
}

# --- Rule 4: img-lcp-lazy — fetchpriority/priority AND loading="lazy" conflict ---
check_lcp_lazy_conflict() {
  [ -z "$HTML_FILES" ] && return

  while IFS= read -r file; do
    [ -f "$file" ] || continue
    grep -n "<img " "$file" 2>/dev/null | while IFS=: read -r linenum line; do
      local has_priority=false
      echo "$line" | grep -qE 'fetchpriority=|priority[= ]' && has_priority=true
      local has_lazy=false
      echo "$line" | grep -q 'loading="lazy"' && has_lazy=true

      if [ "$has_priority" = true ] && [ "$has_lazy" = true ]; then
        findings_add "error" "$file:$linenum" "img-lcp-lazy" \
          "<img> has both fetchpriority and loading=\"lazy\" — these conflict; LCP images should not be lazy-loaded" \
          "Remove loading=\"lazy\" from hero/LCP images with fetchpriority" \
          "https://web.dev/articles/lcp-lazy-loading"
      fi
    done
  done <<< "$HTML_FILES"
}

# --- Rule 5: img-no-fetchpriority — First img per page without fetchpriority="high" ---
check_no_fetchpriority() {
  [ -z "$HTML_FILES" ] && return

  while IFS= read -r file; do
    [ -f "$file" ] || continue
    # Get the first <img> in the file (likely hero/LCP)
    local first_img
    first_img=$(grep -n "<img " "$file" 2>/dev/null | head -1 || true)
    [ -z "$first_img" ] && continue

    local linenum
    linenum=$(echo "$first_img" | cut -d: -f1)
    if ! echo "$first_img" | grep -q 'fetchpriority='; then
      findings_add "warning" "$file:$linenum" "img-no-fetchpriority" \
        "First/hero <img> without fetchpriority=\"high\" — tells browser to prioritize LCP image" \
        "Add fetchpriority=\"high\" to the hero/above-the-fold image" \
        "https://web.dev/articles/fetch-priority"
    fi
  done <<< "$HTML_FILES"
}

# --- Rule 6: img-no-decoding — Non-hero images without decoding="async" ---
check_no_decoding() {
  [ -z "$HTML_FILES" ] && return

  while IFS= read -r file; do
    [ -f "$file" ] || continue
    # Skip first img (hero), check the rest
    local other_imgs
    other_imgs=$(grep -n "<img " "$file" 2>/dev/null | tail -n +2 || true)
    [ -z "$other_imgs" ] && continue

    echo "$other_imgs" | while IFS=: read -r linenum line; do
      if ! echo "$line" | grep -q 'decoding='; then
        findings_add "warning" "$file:$linenum" "img-no-decoding" \
          "<img> without decoding=\"async\" — allows browser to decode image off main thread" \
          "Add decoding=\"async\" to non-hero images" \
          "https://developer.mozilla.org/en-US/docs/Web/HTML/Element/img#decoding"
        return  # one finding per file
      fi
    done
  done <<< "$HTML_FILES"
}

# --- Rule 7: img-css-background-hero — CSS background-image for hero/banner ---
check_css_background_hero() {
  [ -z "$CSS_FILES" ] && return

  while IFS= read -r file; do
    [ -f "$file" ] || continue
    grep -n "background-image" "$file" 2>/dev/null | while IFS=: read -r linenum line; do
      # Check if the selector context suggests hero/banner usage
      # Look back a few lines for the selector
      local context
      context=$(sed -n "$((linenum > 5 ? linenum - 5 : 1)),${linenum}p" "$file" 2>/dev/null || true)
      if echo "$context" | grep -qiE "hero|banner|jumbotron|splash|cover|masthead|header.*bg|\.bg-"; then
        findings_add "warning" "$file:$linenum" "img-css-background-hero" \
          "CSS background-image used for hero/banner — not discoverable by browser preloader, hurts LCP" \
          "Use <img> with fetchpriority=\"high\" for LCP images instead of CSS background-image" \
          "https://web.dev/articles/optimize-lcp#optimize_when_the_resource_is_discovered"
      fi
    done
  done <<< "$CSS_FILES"
}

# --- Rule 8: svg-not-optimized — SVG files >10KB (likely unoptimized) ---
check_svg_not_optimized() {
  local svg_files
  svg_files=$(find "$REPO" -type f -name "*.svg" 2>/dev/null | grep -v "$EXCLUDE_DIRS" || true)
  [ -z "$svg_files" ] && return

  while IFS= read -r file; do
    [ -f "$file" ] || continue
    local size
    size=$(wc -c < "$file" 2>/dev/null | tr -d ' ')
    if [ "$size" -gt 10240 ]; then
      local size_kb=$((size / 1024))
      # Check for metadata/comments that suggest it's unoptimized
      local has_metadata=false
      grep -qE '<metadata|<!-- |<desc>|<title>|inkscape:|sodipodi:|xmlns:dc=|xmlns:cc=' "$file" 2>/dev/null && has_metadata=true
      if [ "$has_metadata" = true ]; then
        findings_add "warning" "$file" "svg-not-optimized" \
          "SVG is ${size_kb}KB with metadata/comments — optimize to reduce size by 30-60%" \
          "Run: npx svgo $file or use https://jakearchibald.github.io/svgomg/" \
          "https://web.dev/articles/reduce-network-payloads-using-text-compression"
      fi
    fi
  done <<< "$svg_files"
}

# --- Rule 9: img-no-picture — WebP/AVIF served without <picture> fallback ---
check_no_picture() {
  [ -z "$HTML_FILES" ] && return

  local files_with_modern
  files_with_modern=$(echo "$HTML_FILES" | xargs grep -l '\.webp\|\.avif' 2>/dev/null || true)
  [ -z "$files_with_modern" ] && return

  while IFS= read -r file; do
    [ -f "$file" ] || continue
    # Find references to .webp/.avif that are in <img> src but not inside <picture>
    grep -n '<img ' "$file" 2>/dev/null | grep -E '\.webp|\.avif' | while IFS=: read -r linenum line; do
      # Check if this img is inside a <picture> element by looking back
      local context
      context=$(sed -n "$((linenum > 5 ? linenum - 5 : 1)),${linenum}p" "$file" 2>/dev/null || true)
      if ! echo "$context" | grep -q '<picture'; then
        findings_add "warning" "$file:$linenum" "img-no-picture" \
          "WebP/AVIF image in <img> without <picture> fallback — older browsers won't display it" \
          "Wrap in <picture><source srcset=\"img.webp\" type=\"image/webp\"><img src=\"img.jpg\"></picture>" \
          "https://web.dev/articles/serve-images-webp#use_picture"
        return  # one finding per file
      fi
    done
  done <<< "$files_with_modern"
}

# --- Rule 10: icon-not-svg — Icon files as PNG/JPEG instead of SVG ---
check_icon_not_svg() {
  # Find icon-like raster files (in icons/ dir or with icon in name)
  local icon_rasters
  icon_rasters=$(find "$REPO" -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" \) 2>/dev/null | \
    grep -v "$EXCLUDE_DIRS" | grep -iE "icon|icons/" || true)
  [ -z "$icon_rasters" ] && return

  # Exclude favicons (these are legitimately PNG/ICO)
  icon_rasters=$(echo "$icon_rasters" | grep -viE "favicon|apple-touch-icon|android-chrome|mstile" || true)
  [ -z "$icon_rasters" ] && return

  local count
  count=$(echo "$icon_rasters" | wc -l | tr -d ' ')
  local first_file
  first_file=$(echo "$icon_rasters" | head -1)

  if [ "$count" -gt 0 ]; then
    findings_add "warning" "$first_file" "icon-not-svg" \
      "$count icon file(s) as PNG/JPEG instead of SVG — SVGs scale infinitely and are typically smaller for icons" \
      "Convert icons to SVG format for resolution independence and smaller file sizes" \
      "https://web.dev/articles/image-component#icons"
  fi
}

# --- Run all checks ---
check_no_webp
check_no_lazy
check_no_srcset
check_lcp_lazy_conflict
check_no_fetchpriority
check_no_decoding
check_css_background_hero
check_svg_not_optimized
check_no_picture
check_icon_not_svg
