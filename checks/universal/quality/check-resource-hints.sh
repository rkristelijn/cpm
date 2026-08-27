#!/usr/bin/env bash
# checks/universal/quality/check-resource-hints.sh
# @see ADR-129
# Resource hint optimization: dns-prefetch, preconnect, preload, prefetch, modulepreload, CSS ordering
source "$(dirname "$0")/../../../lib/shell/check.sh"
cpm_check_enabled "resource-hints" || exit 0
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

# Find HTML files
HTML_FILES=$(find "$REPO" -name "*.html" -o -name "*.htm" 2>/dev/null | \
  grep -v "node_modules\|\.next\|dist\|build\|vendor\|coverage\|\.min\." || true)
[ -z "$HTML_FILES" ] && exit 0

# --- Rule 1: no-dns-prefetch ---
# Check if external domains are referenced but no dns-prefetch hints exist
HAS_EXTERNAL=$(echo "$HTML_FILES" | xargs grep -lE \
  'https?://[a-zA-Z0-9]' 2>/dev/null | head -1 || true)
if [ -n "$HAS_EXTERNAL" ]; then
  HAS_DNS_PREFETCH=$(echo "$HTML_FILES" | xargs grep -l 'rel="dns-prefetch"' 2>/dev/null | head -1 || true)
  if [ -z "$HAS_DNS_PREFETCH" ]; then
    # Find a sample external domain for the message
    SAMPLE_DOMAIN=$(echo "$HTML_FILES" | xargs grep -ohE 'https?://[a-zA-Z0-9.-]+' 2>/dev/null | \
      grep -v "localhost\|127\.0\.0\.1\|schema\.org" | sort -u | head -1 || true)
    findings_add "warning" "$HAS_EXTERNAL" "no-dns-prefetch" \
      "External domains referenced but no <link rel=\"dns-prefetch\"> hints found${SAMPLE_DOMAIN:+ (e.g. $SAMPLE_DOMAIN)}" \
      "Add <link rel=\"dns-prefetch\" href=\"//example.com\"> for external domains in <head>" \
      "https://web.dev/articles/preconnect-and-dns-prefetch"
  fi
fi

# --- Rule 2: no-preconnect ---
# Check for critical third-party origins (CDN, API, fonts) without preconnect
CRITICAL_ORIGINS=$(echo "$HTML_FILES" | xargs grep -ohE \
  'https?://(cdn\.|fonts\.|api\.|ajax\.|static\.)[a-zA-Z0-9.-]+' 2>/dev/null | \
  sort -u || true)
if [ -n "$CRITICAL_ORIGINS" ]; then
  HAS_PRECONNECT=$(echo "$HTML_FILES" | xargs grep -l 'rel="preconnect"' 2>/dev/null | head -1 || true)
  if [ -z "$HAS_PRECONNECT" ]; then
    SAMPLE=$(echo "$CRITICAL_ORIGINS" | head -1)
    FIRST_FILE=$(echo "$HTML_FILES" | xargs grep -l "$SAMPLE" 2>/dev/null | head -1 || true)
    findings_add "warning" "${FIRST_FILE:-$REPO}" "no-preconnect" \
      "Critical third-party origins without <link rel=\"preconnect\"> (e.g. $SAMPLE)" \
      "Add <link rel=\"preconnect\" href=\"$SAMPLE\" crossorigin> in <head>" \
      "https://web.dev/articles/preconnect-and-dns-prefetch"
  fi
fi

# --- Rule 3: no-font-preload ---
# Check if web fonts are loaded but not preloaded
HAS_FONT_LOAD=$(echo "$HTML_FILES" | xargs grep -lE \
  'fonts\.googleapis\.com|\.woff2?|\.ttf|\.otf|@font-face' 2>/dev/null | head -1 || true)
if [ -n "$HAS_FONT_LOAD" ]; then
  HAS_FONT_PRELOAD=$(echo "$HTML_FILES" | xargs grep -lE \
    'rel="preload"[^>]*as="font"|as="font"[^>]*rel="preload"' 2>/dev/null | head -1 || true)
  if [ -z "$HAS_FONT_PRELOAD" ]; then
    findings_add "warning" "$HAS_FONT_LOAD" "no-font-preload" \
      "Web fonts loaded but not preloaded — causes flash of invisible text (FOIT)" \
      "Add <link rel=\"preload\" href=\"font.woff2\" as=\"font\" type=\"font/woff2\" crossorigin>" \
      "https://web.dev/articles/codelab-preload-web-fonts"
  fi
fi

# --- Rule 4: no-prefetch-hints ---
# Check SPA/MPA without any prefetch hints for navigation
IS_SPA=false
[ -f "$REPO/package.json" ] && grep -qE "react|vue|angular|svelte|next|nuxt" "$REPO/package.json" 2>/dev/null && IS_SPA=true
# Multi-page apps with multiple HTML files also benefit from prefetch
HTML_COUNT=$(echo "$HTML_FILES" | wc -l | tr -d ' ')
[ "$HTML_COUNT" -gt 1 ] && IS_SPA=true

if [ "$IS_SPA" = true ]; then
  HAS_PREFETCH=$(echo "$HTML_FILES" | xargs grep -lE \
    'rel="prefetch"|rel="prerender"' 2>/dev/null | head -1 || true)
  # Also check for JS-based prefetching (router prefetch, link prefetch)
  JS_PREFETCH=$(cpm_search_files "prefetch\|prerender" "$REPO" \
    --include "*.js" --include "*.ts" --include "*.jsx" --include "*.tsx" \
    2>/dev/null | grep -v "node_modules\|\.next\|dist\|build\|vendor" | head -1 || true)
  if [ -z "$HAS_PREFETCH" ] && [ -z "$JS_PREFETCH" ]; then
    FIRST_HTML=$(echo "$HTML_FILES" | head -1)
    findings_add "info" "$FIRST_HTML" "no-prefetch-hints" \
      "No <link rel=\"prefetch\"> hints — consider prefetching likely next navigations" \
      "Add <link rel=\"prefetch\" href=\"/next-page.html\"> for anticipated navigations" \
      "https://web.dev/articles/link-prefetch"
  fi
fi

# --- Rule 5: css-order-after-script ---
# CSS <link> tags should come before <script> tags in <head>
for htmlfile in $HTML_FILES; do
  # Extract <head> content
  HEAD_CONTENT=$(sed -n '/<head/,/<\/head>/p' "$htmlfile" 2>/dev/null || true)
  [ -z "$HEAD_CONTENT" ] && continue

  # Find line numbers of last <script> and first <link rel="stylesheet"> after it
  LAST_SCRIPT_LINE=$(echo "$HEAD_CONTENT" | grep -n '<script' 2>/dev/null | tail -1 | cut -d: -f1 || true)
  [ -z "$LAST_SCRIPT_LINE" ] && continue

  # Check if any CSS link appears after the last script
  CSS_AFTER_SCRIPT=$(echo "$HEAD_CONTENT" | tail -n +"$LAST_SCRIPT_LINE" | \
    grep -n 'rel="stylesheet"\|rel='\''stylesheet'\''' 2>/dev/null | head -1 || true)
  if [ -n "$CSS_AFTER_SCRIPT" ]; then
    findings_add "warning" "$htmlfile" "css-order-after-script" \
      "CSS <link> tag placed after <script> in <head> — CSS should load before JS for optimal rendering" \
      "Move <link rel=\"stylesheet\"> before any <script> tags in <head>" \
      "https://web.dev/articles/render-blocking-resources"
    break  # Report once
  fi
done

# --- Rule 6: no-modulepreload ---
# Check for ES modules without modulepreload hints
HAS_ES_MODULES=$(echo "$HTML_FILES" | xargs grep -lE \
  'type="module"|type='\''module'\''' 2>/dev/null | head -1 || true)
if [ -n "$HAS_ES_MODULES" ]; then
  HAS_MODULEPRELOAD=$(echo "$HTML_FILES" | xargs grep -l 'rel="modulepreload"' 2>/dev/null | head -1 || true)
  if [ -z "$HAS_MODULEPRELOAD" ]; then
    findings_add "warning" "$HAS_ES_MODULES" "no-modulepreload" \
      "ES modules used without <link rel=\"modulepreload\"> — module dependencies load sequentially" \
      "Add <link rel=\"modulepreload\" href=\"/module.js\"> for critical module dependencies" \
      "https://developer.mozilla.org/en-US/docs/Web/HTML/Attributes/rel/modulepreload"
  fi
fi
