#!/usr/bin/env bash
# checks/javascript/check-i18n.sh
# i18next/react-i18next best practices: no hardcoded strings, fallback lang, namespaces
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/shell/init.sh" 2>/dev/null || true
cpm_check_enabled "js-i18n" || exit 0
set -o nounset -o pipefail

REPO="${1:-.}"
[ -f "$REPO/package.json" ] && grep -q 'i18next\|react-i18next' "$REPO/package.json" || exit 0

FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

# Find source dirs
SRC=""
[ -d "$REPO/src" ] && SRC="$REPO/src/"
[ -d "$REPO/apps" ] && SRC="$SRC $REPO/apps/"
[ -z "$SRC" ] && exit 0

# --- Hardcoded user-facing strings in JSX (English text without t()) ---
HARDCODED=$(cpm_grep -rn ">[A-Z][a-zA-Z]+ [a-z]+ [a-z]+<" $SRC 2>/dev/null | \
  grep -v "t(\|i18n(\|{{\|{\s*'" | head -5 || true)
if [ -n "$HARDCODED" ]; then
  finding "i18n-hardcoded" "Hardcoded English strings in JSX — wrap with t('key') for i18n"
fi

# --- No fallback language configured ---
if [ -f "$REPO/src/i18n.js" ] || [ -f "$REPO/src/i18n.ts" ]; then
  I18N_FILE=$(find "$REPO/src" -maxdepth 1 -name "i18n.*" 2>/dev/null | head -1)
  if [ -n "$I18N_FILE" ] && ! grep -q "fallbackLng\|fallbackLanguage" "$I18N_FILE" 2>/dev/null; then
    finding "i18n-no-fallback" "No fallbackLng configured — users see untranslated keys on missing translations"
  fi
fi

# --- No namespace separation (all keys in one file) ---
if [ -d "$REPO/public/locales" ] || [ -d "$REPO/src/locales" ]; then
  LOCALE_DIR=$(find "$REPO" -maxdepth 2 -type d -name "locales" 2>/dev/null | head -1)
  if [ -n "$LOCALE_DIR" ]; then
    NS_COUNT=$(find "$LOCALE_DIR" -name "*.json" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$NS_COUNT" -eq 1 ]; then
      finding "i18n-no-namespace" "Only one translation file — consider namespaces (common, auth, errors)"
    fi
  fi
fi

# --- Missing translation files for configured languages ---
if [ -f "$REPO/src/i18n.js" ] || [ -f "$REPO/src/i18n.ts" ]; then
  I18N_FILE=$(find "$REPO/src" -maxdepth 1 -name "i18n.*" 2>/dev/null | head -1)
  if [ -n "$I18N_FILE" ]; then
    LANGUAGES=$(grep -oE "['\"](en|de|fr|es|nl)['\"]" "$I18N_FILE" 2>/dev/null | sort -u || true)
    if [ -n "$LANGUAGES" ]; then
      for LANG in $LANGUAGES; do
        LANG_DIR=$(find "$REPO" -maxdepth 3 -type d -name "${LANG//\"/}" 2>/dev/null | head -1)
        [ -z "$LANG_DIR" ] && finding "i18n-missing-lang" "Translation dir missing for $LANG — create ${LANG//\"/}/translation.json"
      done
    fi
  fi
fi

# --- t() calls with string literals not in translation files ---
if cpm_grep -rn "t('[^']*'\|t(\"[^\"]*\"" $SRC 2>/dev/null | head -10 | grep -q .; then
  : # t() calls found - would need full translation file analysis
fi

# --- No i18next-parser or extraction tool ---
if [ -f "$REPO/package.json" ]; then
  if ! grep -q "i18next-parser\|i18next-extract\|ngx-i18next-parser" "$REPO/package.json" 2>/dev/null; then
    finding "i18n-no-extractor" "No i18next-parser configured — manual key management is error-prone"
  fi
fi

# --- Inline default values without extraction ---
if cpm_grep -rn "t\(.*defaultValue" $SRC 2>/dev/null | head -1 | grep -q .; then
  finding "i18n-inline-default" "t() with inline defaultValue — extract to translation files instead"
fi

[ "$FINDINGS" -eq 0 ] && echo "  ✓ i18n patterns OK"
exit 0