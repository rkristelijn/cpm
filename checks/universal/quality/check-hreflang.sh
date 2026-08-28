#!/usr/bin/env bash
# checks/universal/quality/check-hreflang.sh
# @see ADR-129
# Internationalization: hreflang tags, x-default fallback, RTL support, charset position
source "$(dirname "$0")/../../../lib/shell/check.sh"
cpm_check_enabled "hreflang" || exit 0
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

# --- Detect multi-language project ---
IS_I18N=false
I18N_INDICATOR=""

# i18n config files
for cfg in \
  "$REPO/next-i18next.config.js" "$REPO/next-i18next.config.ts" \
  "$REPO/i18n.ts" "$REPO/i18n.js" "$REPO/i18n.config.ts" "$REPO/i18n.config.js" \
  "$REPO/src/i18n.ts" "$REPO/src/i18n.js" "$REPO/src/i18n/index.ts" \
  "$REPO/.i18nrc" "$REPO/.i18nrc.json" "$REPO/lingui.config.ts" "$REPO/lingui.config.js"; do
  if [ -f "$cfg" ]; then
    IS_I18N=true
    I18N_INDICATOR="${cfg#$REPO/}"
    break
  fi
done

# Locale/messages directories
if [ "$IS_I18N" = false ]; then
  for dir in "$REPO/locales" "$REPO/locale" "$REPO/messages" "$REPO/translations" \
    "$REPO/src/locales" "$REPO/src/locale" "$REPO/src/messages" "$REPO/src/translations" \
    "$REPO/public/locales" "$REPO/public/locale"; do
    if [ -d "$dir" ]; then
      # Must have at least 2 language subdirs or files
      LANG_COUNT=$(find "$dir" -maxdepth 1 \( -type d -o -name "*.json" -o -name "*.yaml" -o -name "*.yml" \) \
        -not -name "$(basename "$dir")" 2>/dev/null | wc -l | tr -d ' ')
      if [ "$LANG_COUNT" -ge 2 ]; then
        IS_I18N=true
        I18N_INDICATOR="${dir#$REPO/}"
        break
      fi
    fi
  done
fi

# i18n packages in package.json
if [ "$IS_I18N" = false ] && [ -f "$REPO/package.json" ]; then
  if grep -qE '"(next-i18next|react-i18next|i18next|vue-i18n|@angular/localize|@ngx-translate|react-intl|formatjs|lingui)"' "$REPO/package.json" 2>/dev/null; then
    IS_I18N=true
    I18N_INDICATOR="package.json (i18n dependency)"
  fi
fi

# Multiple [lang] or /[locale]/ directories in app router
if [ "$IS_I18N" = false ]; then
  LANG_DIRS=$(find "$REPO/app" -maxdepth 1 -type d -name "[a-z][a-z]" -o -name "[a-z][a-z]-[A-Z][A-Z]" 2>/dev/null | wc -l | tr -d ' ')
  if [ "${LANG_DIRS:-0}" -ge 2 ]; then
    IS_I18N=true
    I18N_INDICATOR="app/ directory (multiple lang dirs)"
  fi
fi

# Not a multi-language project — nothing to check
[ "$IS_I18N" = false ] && exit 0

# --- Collect HTML files ---
HTML_FILES=$(find "$REPO" \( -name "*.html" -o -name "*.htm" \) \
  -not -path "*/node_modules/*" -not -path "*/.next/*" -not -path "*/dist/*" \
  -not -path "*/build/*" -not -path "*/vendor/*" -not -path "*/.git/*" \
  -not -path "*/coverage/*" 2>/dev/null || true)

# Also check JSX/TSX for React head components
JSX_FILES=$(find "$REPO" \( -name "*.tsx" -o -name "*.jsx" \) \
  -not -path "*/node_modules/*" -not -path "*/.next/*" -not -path "*/dist/*" \
  -not -path "*/build/*" -not -path "*/.git/*" 2>/dev/null || true)

ALL_HEAD_FILES="$HTML_FILES"
[ -n "$JSX_FILES" ] && ALL_HEAD_FILES="$ALL_HEAD_FILES
$JSX_FILES"
ALL_HEAD_FILES=$(echo "$ALL_HEAD_FILES" | grep -v '^$' || true)

# --- Rule 1: i18n-no-hreflang — Multi-language site without hreflang link tags ---
HAS_HREFLANG=false

# Check HTML files
if [ -n "$HTML_FILES" ]; then
  echo "$HTML_FILES" | xargs grep -l 'hreflang' 2>/dev/null | head -1 | grep -q . && HAS_HREFLANG=true
fi

# Check JSX/TSX for hreflang in Head/next/head
if [ "$HAS_HREFLANG" = false ] && [ -n "$JSX_FILES" ]; then
  echo "$JSX_FILES" | xargs grep -l 'hreflang' 2>/dev/null | head -1 | grep -q . && HAS_HREFLANG=true
fi

# Check for framework-level hreflang (next.config i18n.locales generates them)
if [ "$HAS_HREFLANG" = false ]; then
  for ncfg in "$REPO/next.config.ts" "$REPO/next.config.js" "$REPO/next.config.mjs"; do
    if [ -f "$ncfg" ] && grep -q 'i18n' "$ncfg" 2>/dev/null && grep -q 'locales' "$ncfg" 2>/dev/null; then
      HAS_HREFLANG=true
      break
    fi
  done
fi

if [ "$HAS_HREFLANG" = false ]; then
  findings_add "warning" "$I18N_INDICATOR" "i18n-no-hreflang" \
    "Multi-language site without hreflang tags — search engines can't determine language targeting" \
    "Add <link rel=\"alternate\" hreflang=\"xx\" href=\"...\"> for each language variant" \
    "https://developers.google.com/search/docs/specialty/international/localized-versions"
fi

# --- Rule 2: i18n-no-self-hreflang — Hreflang tags present but no self-referencing tag ---
if [ "$HAS_HREFLANG" = true ] && [ -n "$HTML_FILES" ]; then
  # Check if any HTML file with hreflang has a self-referencing tag
  # A self-referencing hreflang points to the current page's own URL+language
  HREFLANG_FILES=$(echo "$HTML_FILES" | xargs grep -l 'hreflang' 2>/dev/null || true)
  if [ -n "$HREFLANG_FILES" ]; then
    FOUND_SELF=false
    while IFS= read -r hf; do
      [ -z "$hf" ] && continue
      # Count unique hreflang values — if there's a self-ref, the page's own lang should be in the set
      HREFLANG_COUNT=$(grep -oE 'hreflang="[^"]*"' "$hf" 2>/dev/null | sort -u | wc -l | tr -d ' ')
      HREF_COUNT=$(grep -c 'rel="alternate".*hreflang\|hreflang.*rel="alternate"' "$hf" 2>/dev/null || echo "0")
      # If page has lang attribute, check it matches one of the hreflang values
      PAGE_LANG=$(grep -oE '<html[^>]*lang="([^"]*)"' "$hf" 2>/dev/null | grep -oE 'lang="[^"]*"' | head -1 | tr -d '"' | sed 's/lang=//' || true)
      if [ -n "$PAGE_LANG" ]; then
        if grep -qE "hreflang=\"$PAGE_LANG\"" "$hf" 2>/dev/null; then
          FOUND_SELF=true
          break
        fi
      fi
      # If we have multiple hreflang tags, likely has self-ref (heuristic)
      [ "$HREFLANG_COUNT" -ge 2 ] && FOUND_SELF=true && break
    done <<< "$HREFLANG_FILES"

    if [ "$FOUND_SELF" = false ]; then
      FIRST_HF=$(echo "$HREFLANG_FILES" | head -1)
      REL_HF="${FIRST_HF#$REPO/}"
      findings_add "warning" "$REL_HF" "i18n-no-self-hreflang" \
        "Hreflang tags present but no self-referencing tag — Google requires each page to reference itself" \
        "Add a hreflang tag pointing to the current page's own URL and language" \
        "https://developers.google.com/search/docs/specialty/international/localized-versions#guidelines"
    fi
  fi
fi

# --- Rule 3: i18n-no-x-default — Hreflang set without x-default fallback ---
if [ "$HAS_HREFLANG" = true ]; then
  HAS_XDEFAULT=false

  if [ -n "$HTML_FILES" ]; then
    echo "$HTML_FILES" | xargs grep -l 'x-default' 2>/dev/null | head -1 | grep -q . && HAS_XDEFAULT=true
  fi
  if [ "$HAS_XDEFAULT" = false ] && [ -n "$JSX_FILES" ]; then
    echo "$JSX_FILES" | xargs grep -l 'x-default' 2>/dev/null | head -1 | grep -q . && HAS_XDEFAULT=true
  fi

  if [ "$HAS_XDEFAULT" = false ]; then
    findings_add "warning" "$I18N_INDICATOR" "i18n-no-x-default" \
      "Hreflang set without x-default fallback — users with unsupported languages see arbitrary version" \
      "Add <link rel=\"alternate\" hreflang=\"x-default\" href=\"...\"> pointing to your default/fallback URL" \
      "https://developers.google.com/search/docs/specialty/international/localized-versions#xdefault"
  fi
fi

# --- Rule 4: i18n-no-dir-rtl — RTL language content without dir="rtl" ---
RTL_LANGS="ar|he|fa|ur|yi|arc|dv|ku|ps|sd|ug"

# Check if project supports any RTL language
HAS_RTL_LANG=false
RTL_EVIDENCE=""

# Check locale directories for RTL languages
for dir in "$REPO/locales" "$REPO/locale" "$REPO/messages" "$REPO/translations" \
  "$REPO/src/locales" "$REPO/src/locale" "$REPO/src/messages" "$REPO/public/locales"; do
  if [ -d "$dir" ]; then
    RTL_MATCH=$(find "$dir" -maxdepth 1 \( -type d -o -type f \) 2>/dev/null | \
      grep -oE "/(ar|he|fa|ur|yi)\b" | head -1 || true)
    if [ -n "$RTL_MATCH" ]; then
      HAS_RTL_LANG=true
      RTL_EVIDENCE="${dir#$REPO/}$RTL_MATCH"
      break
    fi
  fi
done

# Check i18n config for RTL locales
if [ "$HAS_RTL_LANG" = false ] && [ -n "$ALL_HEAD_FILES" ]; then
  RTL_CFG_MATCH=$(echo "$ALL_HEAD_FILES" | xargs grep -lE "\"(ar|he|fa|ur)\"|'(ar|he|fa|ur)'" 2>/dev/null | head -1 || true)
  if [ -n "$RTL_CFG_MATCH" ]; then
    HAS_RTL_LANG=true
    RTL_EVIDENCE="${RTL_CFG_MATCH#$REPO/}"
  fi
fi

if [ "$HAS_RTL_LANG" = true ]; then
  HAS_DIR_RTL=false
  if [ -n "$HTML_FILES" ]; then
    echo "$HTML_FILES" | xargs grep -lE 'dir="rtl"|dir=.rtl.' 2>/dev/null | head -1 | grep -q . && HAS_DIR_RTL=true
  fi
  if [ "$HAS_DIR_RTL" = false ] && [ -n "$JSX_FILES" ]; then
    echo "$JSX_FILES" | xargs grep -lE 'dir="rtl"|dir=.rtl.|dir={.*rtl' 2>/dev/null | head -1 | grep -q . && HAS_DIR_RTL=true
  fi
  # Check CSS for direction: rtl
  CSS_FILES=$(find "$REPO" \( -name "*.css" -o -name "*.scss" \) \
    -not -path "*/node_modules/*" -not -path "*/dist/*" -not -path "*/.git/*" 2>/dev/null || true)
  if [ "$HAS_DIR_RTL" = false ] && [ -n "$CSS_FILES" ]; then
    echo "$CSS_FILES" | xargs grep -lE 'direction\s*:\s*rtl|\[dir="rtl"\]|\[dir=rtl\]' 2>/dev/null | head -1 | grep -q . && HAS_DIR_RTL=true
  fi

  if [ "$HAS_DIR_RTL" = false ]; then
    findings_add "warning" "$RTL_EVIDENCE" "i18n-no-dir-rtl" \
      "RTL language content detected but no dir=\"rtl\" attribute — text renders left-to-right incorrectly" \
      "Add dir=\"rtl\" to <html> or container elements for RTL languages (ar, he, fa, ur)" \
      "https://developer.mozilla.org/en-US/docs/Web/HTML/Global_attributes/dir"
  fi
fi

# --- Rule 5: i18n-charset-not-first — <meta charset> not first element in <head> ---
if [ -n "$HTML_FILES" ]; then
  while IFS= read -r htmlfile; do
    [ -z "$htmlfile" ] && continue
    # Extract the content between <head> and the first few elements
    HEAD_CONTENT=$(sed -n '/<head/,/<\/head>/p' "$htmlfile" 2>/dev/null | head -20 || true)
    [ -z "$HEAD_CONTENT" ] && continue

    # Check if file has a charset meta
    echo "$HEAD_CONTENT" | grep -qi 'charset' || continue

    # Find the first non-empty tag after <head>
    FIRST_TAG=$(echo "$HEAD_CONTENT" | grep -oE '<(meta|link|title|script|style)[^>]*>' | head -1 || true)
    [ -z "$FIRST_TAG" ] && continue

    # If the first tag is NOT a charset meta, it's wrong
    if ! echo "$FIRST_TAG" | grep -qi 'charset'; then
      REL_HTML="${htmlfile#$REPO/}"
      findings_add "warning" "$REL_HTML" "i18n-charset-not-first" \
        "<meta charset> is not the first element in <head> — browser may misinterpret encoding for first 1024 bytes" \
        "Move <meta charset=\"UTF-8\"> to be the first child of <head>, before any other tags" \
        "https://developer.mozilla.org/en-US/docs/Web/HTML/Element/meta#charset"
      break  # one finding per project is enough
    fi
  done <<< "$HTML_FILES"
fi
