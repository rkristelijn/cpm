#!/usr/bin/env bash
# checks/universal/quality/check-html-semantics.sh
# @see ADR-129
# HTML semantics & build hygiene: semantic elements, lazy loading, autoplay, sourcemaps, dev code, charset, theme-color
source "$(dirname "$0")/../../../lib/shell/check.sh"
cpm_check_enabled "html-semantics" || exit 0
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
HTML_FILES=$(find "$REPO" \( -name "*.html" -o -name "*.htm" \) \
  -not -path "*/node_modules/*" -not -path "*/.next/*" -not -path "*/dist/*" \
  -not -path "*/build/*" -not -path "*/vendor/*" -not -path "*/.git/*" 2>/dev/null || true)

# Find JSX/TSX files
JSX_FILES=$(find "$REPO" \( -name "*.jsx" -o -name "*.tsx" \) \
  -not -path "*/node_modules/*" -not -path "*/.next/*" -not -path "*/dist/*" \
  -not -path "*/build/*" -not -path "*/vendor/*" -not -path "*/.git/*" 2>/dev/null || true)

# Find config files (webpack, vite, next, etc.)
CONFIG_FILES=$(find "$REPO" -maxdepth 3 \( \
  -name "webpack.config.*" -o -name "vite.config.*" -o -name "next.config.*" \
  -o -name "rollup.config.*" -o -name "esbuild.config.*" \) \
  -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null || true)

ALL_TEMPLATE_FILES=$(printf '%s\n%s' "$HTML_FILES" "$JSX_FILES" | grep -v '^$' | sort -u || true)

# --- Rule 1: html-no-semantic — HTML without semantic elements ---
if [ -n "$HTML_FILES" ]; then
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    # Only check full HTML documents (with <body> or <html>)
    grep -qi '<body\|<html' "$file" 2>/dev/null || continue
    HAS_SEMANTIC=false
    grep -qiE '<header|<nav|<main|<article|<section|<footer|<aside' "$file" 2>/dev/null && HAS_SEMANTIC=true
    if [ "$HAS_SEMANTIC" = false ]; then
      findings_add "warning" "$file" "html-no-semantic" \
        "HTML document without semantic elements — screen readers and SEO suffer" \
        "Use <header>, <nav>, <main>, <article>, <footer> instead of generic <div>" \
        "https://developer.mozilla.org/en-US/docs/Glossary/Semantics#semantics_in_html"
    fi
  done <<< "$HTML_FILES"
fi

# --- Rule 2: html-iframe-no-lazy — <iframe> without loading="lazy" ---
if [ -n "$ALL_TEMPLATE_FILES" ]; then
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    IFRAME_LINES=$(grep -n '<iframe' "$file" 2>/dev/null | \
      grep -v 'loading="lazy"\|loading=.lazy' || true)
    [ -z "$IFRAME_LINES" ] && continue
    while IFS=: read -r linenum _rest; do
      findings_add "warning" "$file:$linenum" "html-iframe-no-lazy" \
        "<iframe> without loading=lazy — loads immediately even if off-screen" \
        "Add loading=lazy to defer off-screen iframe loading" \
        "https://developer.mozilla.org/en-US/docs/Web/HTML/Element/iframe#loading"
    done <<< "$IFRAME_LINES"
  done <<< "$ALL_TEMPLATE_FILES"
fi

# --- Rule 3: html-autoplay-audio — <video>/<audio> with autoplay but without muted ---
if [ -n "$ALL_TEMPLATE_FILES" ]; then
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    AUTOPLAY_LINES=$(grep -nE '<(video|audio)[^>]*autoplay' "$file" 2>/dev/null | \
      grep -v 'muted' || true)
    [ -z "$AUTOPLAY_LINES" ] && continue
    while IFS=: read -r linenum _rest; do
      findings_add "warning" "$file:$linenum" "html-autoplay-audio" \
        "autoplay without muted — browsers block unmuted autoplay, causes accessibility issues" \
        "Add muted attribute, or remove autoplay and let user initiate playback" \
        "https://developer.chrome.com/blog/autoplay/"
    done <<< "$AUTOPLAY_LINES"
  done <<< "$ALL_TEMPLATE_FILES"
fi

# --- Rule 4: build-sourcemap-prod — source maps configured for production ---
if [ -n "$CONFIG_FILES" ]; then
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    SOURCEMAP_LINES=$(grep -nE "devtool:\s*['\"]?(source-map|eval-source-map|eval|cheap-module-source-map)['\"]?" "$file" 2>/dev/null || true)
    [ -z "$SOURCEMAP_LINES" ] && continue
    while IFS=: read -r linenum _rest; do
      # Check if it's guarded by NODE_ENV or development check
      context_start=$((linenum - 5))
      [ "$context_start" -lt 1 ] && context_start=1
      context=$(sed -n "${context_start},${linenum}p" "$file" 2>/dev/null || true)
      if echo "$context" | grep -qE 'NODE_ENV.*development|isDev|process\.env\.NODE_ENV|development' 2>/dev/null; then
        continue  # Properly guarded by dev check
      fi
      findings_add "warning" "$file:$linenum" "build-sourcemap-prod" \
        "Source maps configured without development guard — exposes source code in production" \
        "Use devtool conditionally: devtool: isDev ? source-map : false" \
        "https://webpack.js.org/configuration/devtool/"
    done <<< "$SOURCEMAP_LINES"
  done <<< "$CONFIG_FILES"
fi

# --- Rule 5: build-dev-code-prod — development-only code patterns ---
if [ -n "$JSX_FILES" ]; then
  # React.StrictMode in production code (not in dev-only files)
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    # Skip test files
    echo "$file" | grep -qE '\.test\.|\.spec\.|__tests__' && continue
    STRICT_LINES=$(grep -n 'React\.StrictMode\|<StrictMode' "$file" 2>/dev/null || true)
    [ -z "$STRICT_LINES" ] && continue
    while IFS=: read -r linenum _rest; do
      findings_add "info" "$file:$linenum" "build-dev-code-prod" \
        "React.StrictMode found — causes double-renders in development, verify intentional" \
        "StrictMode is dev-only in React 18+, but remove if causing confusion" \
        "https://react.dev/reference/react/StrictMode"
    done <<< "$STRICT_LINES"
  done <<< "$JSX_FILES"

  # __DEV__ usage without guard
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    DEV_LINES=$(grep -nE '__DEV__' "$file" 2>/dev/null | \
      grep -vE '^\s*[*/]' || true)
    [ -z "$DEV_LINES" ] && continue
    while IFS=: read -r linenum _rest; do
      findings_add "info" "$file:$linenum" "build-dev-code-prod" \
        "__DEV__ flag found — ensure bundler tree-shakes this in production builds" \
        "Verify __DEV__ is replaced by bundler (Webpack DefinePlugin, Vite define)" \
        "https://webpack.js.org/plugins/define-plugin/"
    done <<< "$DEV_LINES"
  done <<< "$JSX_FILES"
fi

# --- Rule 6: html-no-charset-first — <meta charset> not first in <head> ---
if [ -n "$HTML_FILES" ]; then
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    # Get content between <head> and charset declaration
    head_content=$(sed -n '/<head/,/<meta.*charset/p' "$file" 2>/dev/null || true)
    [ -z "$head_content" ] && continue
    # Check if there's no charset at all
    if ! grep -qi 'charset' "$file" 2>/dev/null; then
      findings_add "warning" "$file" "html-no-charset-first" \
        "No <meta charset> — browser may misinterpret characters" \
        "Add <meta charset=\"UTF-8\"> as first element in <head>" \
        "https://developer.mozilla.org/en-US/docs/Web/HTML/Element/meta#charset"
      continue
    fi
    # Count elements between <head> and charset — if there are other elements, charset isn't first
    BEFORE_CHARSET=$(echo "$head_content" | grep -cE '<(meta|title|link|script|style)' 2>/dev/null || echo 0)
    # Should be 1 (the charset meta itself), more means other elements come first
    if [ "$BEFORE_CHARSET" -gt 1 ]; then
      findings_add "warning" "$file" "html-no-charset-first" \
        "<meta charset> is not the first element in <head> — content before it may be parsed with wrong encoding" \
        "Move <meta charset=\"UTF-8\"> to be the first child of <head>" \
        "https://html.spec.whatwg.org/multipage/semantics.html#charset"
    fi
  done <<< "$HTML_FILES"
fi

# --- Rule 7: html-no-theme-color — no theme-color meta for mobile browser chrome ---
if [ -n "$HTML_FILES" ]; then
  # Check if any HTML file has theme-color (project-wide, only need one)
  HAS_THEME_COLOR=false
  echo "$HTML_FILES" | xargs grep -qi 'name="theme-color"\|name=.theme-color' 2>/dev/null && HAS_THEME_COLOR=true

  # Also check manifest.json/webmanifest
  MANIFEST=$(find "$REPO" \( -name "manifest.json" -o -name "*.webmanifest" \) \
    -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null | head -1 || true)
  [ -n "$MANIFEST" ] && grep -q 'theme_color' "$MANIFEST" 2>/dev/null && HAS_THEME_COLOR=true

  if [ "$HAS_THEME_COLOR" = false ]; then
    # Report on the first HTML file with a <head>
    FIRST_HTML=$(echo "$HTML_FILES" | xargs grep -l '<head' 2>/dev/null | head -1 || true)
    [ -n "$FIRST_HTML" ] && findings_add "info" "$FIRST_HTML" "html-no-theme-color" \
      "No <meta name=\"theme-color\"> — mobile browsers show default chrome color" \
      "Add <meta name=\"theme-color\" content=\"#ffffff\"> to match your brand" \
      "https://developer.mozilla.org/en-US/docs/Web/HTML/Element/meta/name/theme-color"
  fi
fi
