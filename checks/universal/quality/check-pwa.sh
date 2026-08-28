#!/usr/bin/env bash
# checks/universal/quality/check-pwa.sh
# @see ADR-129
# PWA readiness: manifest, service worker, icons, offline strategy
source "$(dirname "$0")/../../../lib/shell/check.sh"
cpm_check_enabled "pwa" || exit 0
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

# --- Find manifest file ---
MANIFEST=""
for candidate in \
  "$REPO/manifest.json" \
  "$REPO/manifest.webmanifest" \
  "$REPO/public/manifest.json" \
  "$REPO/public/manifest.webmanifest" \
  "$REPO/src/manifest.json" \
  "$REPO/src/manifest.webmanifest" \
  "$REPO/static/manifest.json" \
  "$REPO/static/manifest.webmanifest"; do
  if [ -f "$candidate" ]; then
    MANIFEST="$candidate"
    break
  fi
done

# Also search for dynamically named manifests
if [ -z "$MANIFEST" ]; then
  MANIFEST=$(find "$REPO" -maxdepth 3 -name "manifest.json" -o -name "manifest.webmanifest" \
    2>/dev/null | grep -v "node_modules\|\.next\|dist\|build\|vendor" | head -1 || true)
fi

# --- Rule 1: pwa-no-manifest ---
if [ -z "$MANIFEST" ]; then
  findings_add "warning" "$REPO" "pwa-no-manifest" \
    "No manifest.json or manifest.webmanifest — PWA requires a web app manifest" \
    "Create manifest.json with name, short_name, start_url, display, icons" \
    "https://web.dev/articles/add-manifest"
else
  MANIFEST_CONTENT=$(cat "$MANIFEST")

  # --- Rule 2: pwa-manifest-incomplete ---
  MISSING_FIELDS=""
  for field in name short_name start_url display; do
    if ! echo "$MANIFEST_CONTENT" | grep -q "\"$field\""; then
      MISSING_FIELDS="${MISSING_FIELDS:+$MISSING_FIELDS, }$field"
    fi
  done
  if [ -n "$MISSING_FIELDS" ]; then
    findings_add "warning" "$MANIFEST" "pwa-manifest-incomplete" \
      "Manifest missing required fields: $MISSING_FIELDS" \
      "Add missing fields to manifest: $MISSING_FIELDS" \
      "https://web.dev/articles/add-manifest"
  fi

  # --- Rule 3: pwa-no-icons ---
  HAS_192=false
  HAS_512=false
  echo "$MANIFEST_CONTENT" | grep -q '"192x192"' && HAS_192=true
  echo "$MANIFEST_CONTENT" | grep -q '"512x512"' && HAS_512=true
  if [ "$HAS_192" = false ] || [ "$HAS_512" = false ]; then
    MISSING_ICONS=""
    [ "$HAS_192" = false ] && MISSING_ICONS="192x192"
    [ "$HAS_512" = false ] && MISSING_ICONS="${MISSING_ICONS:+$MISSING_ICONS, }512x512"
    findings_add "warning" "$MANIFEST" "pwa-no-icons" \
      "Manifest missing icon sizes: $MISSING_ICONS — required for PWA installability" \
      "Add icons array with 192x192 and 512x512 PNG icons" \
      "https://web.dev/articles/add-manifest#icons"
  fi

  # --- Rule 4: pwa-no-theme-color ---
  HAS_THEME=false
  HAS_BG=false
  echo "$MANIFEST_CONTENT" | grep -q '"theme_color"' && HAS_THEME=true
  echo "$MANIFEST_CONTENT" | grep -q '"background_color"' && HAS_BG=true
  if [ "$HAS_THEME" = false ] || [ "$HAS_BG" = false ]; then
    MISSING_COLORS=""
    [ "$HAS_THEME" = false ] && MISSING_COLORS="theme_color"
    [ "$HAS_BG" = false ] && MISSING_COLORS="${MISSING_COLORS:+$MISSING_COLORS, }background_color"
    findings_add "warning" "$MANIFEST" "pwa-no-theme-color" \
      "Manifest missing: $MISSING_COLORS — affects splash screen and browser chrome" \
      "Add theme_color and background_color to manifest" \
      "https://web.dev/articles/add-manifest#display"
  fi

  # --- Rule 7: pwa-no-maskable-icon ---
  if ! echo "$MANIFEST_CONTENT" | grep -qi "maskable"; then
    findings_add "warning" "$MANIFEST" "pwa-no-maskable-icon" \
      "No maskable icon in manifest — adaptive icons will be letterboxed on Android" \
      "Add an icon with \"purpose\": \"maskable\" to the icons array" \
      "https://web.dev/articles/maskable-icon"
  fi
fi

# --- Rule 5: pwa-no-service-worker ---
# Search JS/TS files for service worker registration
SW_REGISTRATION=$(cpm_search_files "serviceWorker\.register\|navigator\.serviceWorker" "$REPO" \
  --include "*.js" --include "*.ts" --include "*.jsx" --include "*.tsx" --include "*.html" \
  2>/dev/null | grep -v "node_modules\|\.next\|dist\|build\|vendor" | head -1 || true)

# Also check for framework-level SW plugins (e.g. workbox, next-pwa, vite-plugin-pwa)
SW_PLUGIN=""
if [ -f "$REPO/package.json" ]; then
  SW_PLUGIN=$(grep -E "workbox|next-pwa|vite-plugin-pwa|@angular/service-worker|@nuxtjs/pwa|serwist" \
    "$REPO/package.json" 2>/dev/null | head -1 || true)
fi

if [ -z "$SW_REGISTRATION" ] && [ -z "$SW_PLUGIN" ]; then
  findings_add "warning" "$REPO" "pwa-no-service-worker" \
    "No service worker registration found — PWA requires navigator.serviceWorker.register()" \
    "Register a service worker: navigator.serviceWorker.register('/sw.js')" \
    "https://web.dev/articles/service-workers-registration"
fi

# --- Rule 6: pwa-no-offline ---
# Find service worker files (common names)
SW_FILES=""
for sw_name in sw.js service-worker.js serviceworker.js sw.ts service-worker.ts; do
  found=$(find "$REPO" -maxdepth 4 -name "$sw_name" 2>/dev/null | \
    grep -v "node_modules\|\.next\|dist\|build\|vendor" || true)
  SW_FILES="${SW_FILES}${found:+$found
}"
done

# Also check for workbox config (generates SW with caching)
HAS_WORKBOX_CONFIG=false
for wbconf in workbox-config.js workbox-config.cjs workbox-config.mjs; do
  [ -f "$REPO/$wbconf" ] && HAS_WORKBOX_CONFIG=true
done
# vite-plugin-pwa / next-pwa generate SW automatically
[ -n "$SW_PLUGIN" ] && HAS_WORKBOX_CONFIG=true

if [ -n "$SW_FILES" ] && [ "$HAS_WORKBOX_CONFIG" = false ]; then
  HAS_CACHE=false
  echo "$SW_FILES" | while IFS= read -r swfile; do
    [ -z "$swfile" ] && continue
    if grep -qE "caches\.open|CacheStorage|cache\.put|cache\.addAll|cache\.match" "$swfile" 2>/dev/null; then
      HAS_CACHE=true
    fi
  done || true

  # Re-check — the subshell above doesn't propagate, so grep directly
  CACHE_HIT=$(echo "$SW_FILES" | tr '\n' '\0' | xargs -0 grep -lE \
    "caches\.open|CacheStorage|cache\.put|cache\.addAll|cache\.match" 2>/dev/null | head -1 || true)

  if [ -z "$CACHE_HIT" ]; then
    findings_add "warning" "${SW_FILES%%$'\n'*}" "pwa-no-offline" \
      "Service worker without offline/cache strategy — no caches.open or CacheStorage found" \
      "Add a cache strategy: caches.open('v1').then(cache => cache.addAll(['/']))" \
      "https://web.dev/articles/service-worker-caching-and-http-caching"
  fi
elif [ -z "$SW_FILES" ] && [ "$HAS_WORKBOX_CONFIG" = false ] && [ -n "$SW_REGISTRATION" ]; then
  # Registration exists but no SW file found — might be external or generated
  : # skip — we already warned about no-service-worker if applicable
fi
