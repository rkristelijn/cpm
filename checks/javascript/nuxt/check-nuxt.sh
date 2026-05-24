#!/usr/bin/env bash
# checks/javascript/nuxt/check-nuxt.sh
# Nuxt 3 anti-patterns: fetch usage, error.vue, server routes, useState key
set -o nounset -o pipefail

REPO="${1:-.}"
[ -f "$REPO/package.json" ] && grep -q '"nuxt"' "$REPO/package.json" || exit 0

findings_add() { printf "  %-8s %-28s %s\n" "$1" "$3" "$4"; }

# Using raw fetch() instead of useFetch/useAsyncData
while IFS= read -r file; do
  if grep -qE "fetch\s*\(\s*['\"]" "$file" 2>/dev/null && ! grep -qE "useFetch|useAsyncData" "$file" 2>/dev/null; then
    findings_add "warning" "nuxt-raw-fetch" "Using raw fetch() instead of useFetch" \
      "Use useFetch() for automatic hydration, error handling, and type inference" \
      "https://nuxt.com/api/composables/use-fetch"
  fi
done < <(find $REPO -name "*.vue" -o -name "*.ts" 2>/dev/null | grep -v node_modules)

# Missing error.vue
if [ ! -f "$REPO/error.vue" ] && [ ! -f "$REPO/pages/error.vue" ]; then
  findings_add "warning" "nuxt-no-error-vue" "Missing error.vue for error handling" \
    "Create error.vue to handle application errors gracefully" \
    "https://nuxt.com/docs/getting-started/error-handling"
fi

# No server/ directory (missing API routes)
if [ ! -d "$REPO/server" ]; then
  findings_add "warning" "nuxt-no-server-dir" "No server/ directory for API routes" \
    "Consider adding server/api/ for backend functionality" \
    "https://nuxt.com/docs/guide/directory-structure/server"
fi

# useState without key (hydration mismatch)
while IFS= read -r file; do
  if grep -qE "useState\s*\(\s*['\"]" "$file" 2>/dev/null; then
    if grep -qE "useState\s*\(\s*['\"][^'\"]*['\"]\s*\)" "$file" 2>/dev/null; then
      findings_add "warning" "nuxt-usestate-no-key" "useState() called without key parameter" \
        "Provide a unique key: useState('my-key', () => value)" \
        "https://nuxt.com/api/composables/use-state"
    fi
  fi
done < <(find $REPO -name "*.vue" -o -name "*.ts" 2>/dev/null | grep -v node_modules)

# Importing from #imports manually (auto-imported)
while IFS= read -r file; do
  if grep -qE "from ['\"]#imports['\"]" "$file" 2>/dev/null; then
    findings_add "warning" "nuxt-manual-imports" "Manual import from #imports" \
      "#imports is auto-imported. Remove explicit imports" \
      "https://nuxt.com/docs/guide/concepts/auto-imports"
  fi
done < <(find $REPO -name "*.vue" -o -name "*.ts" 2>/dev/null | grep -v node_modules)

# No app.config.ts
if [ ! -f "$REPO/app.config.ts" ] && [ ! -f "$REPO/app.config.js" ]; then
  findings_add "warning" "nuxt-no-app-config" "Missing app.config.ts" \
    "Create app.config.ts for app-level configuration (runtime config)" \
    "https://nuxt.com/docs/guide/directory-structure/app-config"
fi

# Missing NuxtLink (using <a> for internal links)
while IFS= read -r file; do
  if grep -qE "<a[^>]*href=[\"']/" "$file" 2>/dev/null && ! grep -qE "<NuxtLink" "$file" 2>/dev/null; then
    findings_add "warning" "nuxt-raw-anchor" "Using <a> for internal links instead of <NuxtLink>" \
      "Use <NuxtLink to=\"/path\"> for client-side navigation" \
      "https://nuxt.com/api/components/nuxt-link"
  fi
done < <(find $REPO -name "*.vue" 2>/dev/null | grep -v node_modules)

# No middleware/ for auth
if [ ! -d "$REPO/middleware" ]; then
  findings_add "warning" "nuxt-no-middleware" "No middleware/ directory" \
    "Consider adding middleware/ for authentication and route guards" \
    "https://nuxt.com/docs/guide/directory-structure/middleware"
fi

# process.client/server instead of import.meta
while IFS= read -r file; do
  if grep -qE "process\.(client|server)" "$file" 2>/dev/null; then
    findings_add "warning" "nuxt-process-global" "Using process.client/server instead of import.meta" \
      "Use import.meta.client or import.meta.server for SSR-safe checks" \
      "https://nuxt.com/docs/guide/concepts/rendering"
  fi
done < <(find $REPO -name "*.vue" -o -name "*.ts" 2>/dev/null | grep -v node_modules)

echo "  ✓ Nuxt patterns checked"