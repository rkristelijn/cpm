#!/usr/bin/env bash
# checks/universal/quality/check-html.sh
# @see ADR-129
# HTML anti-patterns: accessibility, SEO, performance, deprecated tags
source "$(dirname "$0")/../../../lib/shell/check.sh"
cpm_check_enabled "html-quality" || exit 0
set -o nounset -o pipefail

REPO="${1:-.}"

# Find HTML files (skip node_modules, dist, build)
HTML_FILES=$(find "$REPO" -name "*.html" -o -name "*.htm" 2>/dev/null | \
  grep -v "node_modules\|\.next\|dist\|build\|vendor\|coverage" || true)
[ -z "$HTML_FILES" ] && exit 0

FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

# --- Missing alt on images ---
echo "$HTML_FILES" | xargs grep -l "<img " 2>/dev/null | \
  xargs grep -n "<img " 2>/dev/null | grep -v "alt=" | head -1 | grep -q . && \
  finding "html-img-no-alt" "<img> without alt attribute — inaccessible to screen readers"

# --- Missing lang attribute ---
echo "$HTML_FILES" | xargs grep -l "<html" 2>/dev/null | \
  xargs grep "<html" 2>/dev/null | grep -v "lang=" | head -1 | grep -q . && \
  finding "html-no-lang" "<html> without lang attribute — screen readers use wrong pronunciation"

# --- Missing viewport meta ---
echo "$HTML_FILES" | xargs grep -l "<head" 2>/dev/null | \
  xargs grep -L "viewport" 2>/dev/null | head -1 | grep -q . && \
  finding "html-no-viewport" "No viewport meta tag — mobile browsers show zoomed-out desktop version"

# --- Scripts without defer/async in head ---
echo "$HTML_FILES" | xargs grep -n "<script " 2>/dev/null | \
  grep -v "defer\|async\|type=\"module\"\|</head" | grep "<head" -A999 2>/dev/null | \
  grep "<script " | grep -v "defer\|async" | head -1 | grep -q . 2>/dev/null && \
  finding "html-script-blocking" "<script> in <head> without defer/async — blocks page rendering"

# --- target="_blank" without rel="noopener" ---
echo "$HTML_FILES" | xargs grep -n 'target="_blank"' 2>/dev/null | \
  grep -v "noopener\|noreferrer" | head -1 | grep -q . && \
  finding "html-blank-no-noopener" "target=\"_blank\" without rel=\"noopener\" — security risk (tabnabbing)"

# --- Deprecated tags ---
echo "$HTML_FILES" | xargs grep -inE "<center>|<font |<marquee|<blink" 2>/dev/null | head -1 | grep -q . && \
  finding "html-deprecated-tags" "Deprecated HTML tags (<center>, <font>, <marquee>) — use CSS instead"

# --- Missing width/height on img (CLS) ---
echo "$HTML_FILES" | xargs grep -n "<img " 2>/dev/null | \
  grep -v "width=\|height=\|style=" | head -1 | grep -q . && \
  finding "html-img-no-dimensions" "<img> without width/height — causes layout shift (CLS)"

# --- Inline event handlers (onclick, onload, etc.) ---
echo "$HTML_FILES" | xargs grep -inE "onclick=|onload=|onsubmit=|onchange=" 2>/dev/null | head -1 | grep -q . && \
  finding "html-inline-handlers" "Inline event handlers (onclick=) — use addEventListener in JS"

# --- Multiple h1 tags ---
MULTI_H1=$(echo "$HTML_FILES" | xargs grep -c "<h1" 2>/dev/null | awk -F: '$2 > 1' | head -1 || true)
[ -n "$MULTI_H1" ] && finding "html-multiple-h1" "Multiple <h1> tags in one page — use one h1 for SEO"

# --- Empty title tag ---
echo "$HTML_FILES" | xargs grep -l "<title" 2>/dev/null | \
  xargs grep -E "<title>\s*</title>|<title></title>" 2>/dev/null | head -1 | grep -q . && \
  finding "html-empty-title" "Empty <title> tag — critical for SEO and browser tabs"

# --- Missing Open Graph tags (og:title, og:image) ---
OG_FILES=$(echo "$HTML_FILES" | xargs grep -l "<head" 2>/dev/null || true)
if [ -n "$OG_FILES" ]; then
  echo "$OG_FILES" | xargs grep -L "og:title\|og:image" 2>/dev/null | head -1 | grep -q . && \
    finding "html-no-og-tags" "No Open Graph tags (og:title, og:image) — broken social media previews"
fi

# --- Missing meta description ---
if [ -n "$OG_FILES" ]; then
  echo "$OG_FILES" | xargs grep -L 'name="description"' 2>/dev/null | head -1 | grep -q . && \
    finding "html-no-meta-desc" "No meta description — search engines show random page text"
fi

# --- Missing canonical URL ---
if [ -n "$OG_FILES" ]; then
  echo "$OG_FILES" | xargs grep -L 'rel="canonical"' 2>/dev/null | head -1 | grep -q . && \
    finding "html-no-canonical" "No canonical URL — risk of duplicate content in search engines"
fi

# --- Missing Content-Security-Policy ---
if [ -n "$OG_FILES" ]; then
  echo "$OG_FILES" | xargs grep -L "Content-Security-Policy\|content-security-policy" 2>/dev/null | head -1 | grep -q . && \
    finding "html-no-csp" "No Content-Security-Policy — vulnerable to XSS injection"
fi

# --- http:// resources (mixed content) ---
echo "$HTML_FILES" | xargs grep -n 'src="http://\|href="http://' 2>/dev/null | \
  grep -v "localhost\|127\.0\.0\.1" | head -1 | grep -q . && \
  finding "html-mixed-content" "http:// resource in HTML — mixed content, use https://"

# --- user-scalable=no (blocks zoom, accessibility issue) ---
echo "$HTML_FILES" | xargs grep -n "user-scalable=no\|user-scalable=0" 2>/dev/null | head -1 | grep -q . && \
  finding "html-no-zoom" "user-scalable=no in viewport — blocks zoom for visually impaired users"

# --- Multiple <main> tags ---
MULTI_MAIN=$(echo "$HTML_FILES" | xargs grep -c "<main" 2>/dev/null | awk -F: '$2 > 1' | head -1 || true)
[ -n "$MULTI_MAIN" ] && finding "html-multiple-main" "Multiple <main> tags — only one allowed per page"

# --- No <main> landmark ---
echo "$HTML_FILES" | xargs grep -l "<body\|<html" 2>/dev/null | \
  xargs grep -L "<main" 2>/dev/null | head -1 | grep -q . && \
  finding "html-no-main" "No <main> landmark — screen readers can't find primary content"

# --- <section> without heading ---
SECTION_FILES=$(echo "$HTML_FILES" | xargs grep -l "<section" 2>/dev/null || true)
if [ -n "$SECTION_FILES" ]; then
  # Simple heuristic: section without h2-h6 nearby
  echo "$SECTION_FILES" | xargs grep -A3 "<section" 2>/dev/null | \
    grep -c "<h[2-6]" 2>/dev/null | grep -q "^0$" && \
    finding "html-section-no-heading" "<section> without heading — use <div> for styling-only containers"
fi

[ "$FINDINGS" -eq 0 ] && echo "  ✓ HTML quality OK"
exit 0
