#!/usr/bin/env bash
# checks/universal/quality/check-social-meta.sh
# @see ADR-129
# Social media meta tags: Open Graph completeness, Twitter Card, locale
source "$(dirname "$0")/../../../lib/shell/check.sh"
cpm_check_enabled "social-meta" || exit 0
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

# Find HTML/JSX/TSX files (skip build artifacts)
FILES=$(find "$REPO" \( -name "*.html" -o -name "*.htm" -o -name "*.jsx" -o -name "*.tsx" \) \
  -not -path "*/node_modules/*" -not -path "*/.next/*" -not -path "*/dist/*" \
  -not -path "*/build/*" -not -path "*/vendor/*" -not -path "*/coverage/*" \
  -not -path "*/.git/*" 2>/dev/null || true)
[ -z "$FILES" ] && exit 0

# Find files that have og:title (these are pages with OG tags)
OG_FILES=$(echo "$FILES" | xargs grep -li "og:title" 2>/dev/null || true)
[ -z "$OG_FILES" ] && exit 0

# --- Rule 1: og-no-type — has og:title but missing og:type ---
while IFS= read -r file; do
  [ -z "$file" ] && continue
  if ! grep -qi "og:type" "$file" 2>/dev/null; then
    findings_add "warning" "$file" "og-no-type" \
      "Has og:title but missing og:type — social platforms default to 'website'" \
      "Add <meta property=\"og:type\" content=\"website\" /> (or article, product)" \
      "https://ogp.me/#types"
  fi
done <<< "$OG_FILES"

# --- Rule 2: og-no-twitter-card — no twitter:card in pages with OG tags ---
while IFS= read -r file; do
  [ -z "$file" ] && continue
  if ! grep -qi "twitter:card" "$file" 2>/dev/null; then
    findings_add "warning" "$file" "og-no-twitter-card" \
      "Has OG tags but no twitter:card — Twitter/X shows plain link instead of card" \
      "Add <meta name=\"twitter:card\" content=\"summary_large_image\" />" \
      "https://developer.x.com/en/docs/twitter-for-websites/cards"
  fi
done <<< "$OG_FILES"

# --- Rule 3: og-no-locale — multi-language site without og:locale ---
# Detect multi-language: hreflang attributes or i18n directories
IS_MULTILANG=false
echo "$FILES" | xargs grep -li "hreflang" 2>/dev/null | head -1 | grep -q . && IS_MULTILANG=true
[ -d "$REPO/locales" ] || [ -d "$REPO/i18n" ] || [ -d "$REPO/translations" ] && IS_MULTILANG=true
[ -f "$REPO/i18n.config.ts" ] || [ -f "$REPO/i18n.config.js" ] && IS_MULTILANG=true
[ -f "$REPO/next-i18next.config.js" ] && IS_MULTILANG=true

if [ "$IS_MULTILANG" = true ]; then
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    if ! grep -qi "og:locale" "$file" 2>/dev/null; then
      findings_add "warning" "$file" "og-no-locale" \
        "Multi-language site without og:locale — social platforms can't determine content language" \
        "Add <meta property=\"og:locale\" content=\"en_US\" /> (match page language)" \
        "https://ogp.me/#optional"
    fi
  done <<< "$OG_FILES"
fi

# --- Rule 4: og-no-url — has og:title but missing og:url ---
while IFS= read -r file; do
  [ -z "$file" ] && continue
  if ! grep -qi "og:url" "$file" 2>/dev/null; then
    findings_add "warning" "$file" "og-no-url" \
      "Has og:title but missing og:url — social platforms may use wrong canonical URL" \
      "Add <meta property=\"og:url\" content=\"https://example.com/page\" />" \
      "https://ogp.me/#metadata"
  fi
done <<< "$OG_FILES"
