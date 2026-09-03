#!/usr/bin/env bash
# cpm:ignore-file SCA-028 — detector/test source: contains the patterns it checks for
#
# check-patterns.sh — Detect design, rendering, and performance patterns from patterns.dev
#
# Checks for:
# 1. JS Design Patterns (anti-patterns: singleton abuse, god objects)
# 2. Performance Patterns (missing dynamic imports, no code splitting)
# 3. React Patterns (HOC vs hooks, prop drilling, render props)
# 4. Rendering Patterns (hydration issues, missing streaming)
# 5. Vue Patterns (options vs composition, missing async components)
#
# @see https://www.patterns.dev/
# @see docs/adrs/adr-013-product-positioning.md

set -o nounset -o pipefail
_LIB="$(dirname "$0")/../../../lib/shell"
if [[ -f "$_LIB/findings.sh" ]]; then
  source "$_LIB/init.sh" 2>/dev/null || true
  source "$_LIB/findings.sh" 2>/dev/null || true
  findings_init "check-patterns" 2>/dev/null || true
  # Also print to stdout for visibility
  _orig_findings_add=$(declare -f findings_add)
  findings_add() {
    local sev="$1" file="$2" rule="$3" msg="$4"
    printf "  %-8s %-28s %s\n" "$sev" "$rule" "$msg"
    # Call original if available
    command -v _findings_add_orig >/dev/null 2>&1 && _findings_add_orig "$@"
  }
else
  findings_add() { printf "  %-8s %-28s %s\n" "$1" "$3" "$4"; }
fi

REPO="${1:-.}"

# Detect framework
HAS_REACT=false; HAS_NEXT=false; HAS_VUE=false; HAS_NUXT=false; HAS_ANGULAR=false
[[ -f "$REPO/package.json" ]] || exit 0
grep -q '"react"' "$REPO/package.json" 2>/dev/null && HAS_REACT=true
grep -q '"next"' "$REPO/package.json" 2>/dev/null && HAS_NEXT=true
grep -q '"vue"' "$REPO/package.json" 2>/dev/null && HAS_VUE=true
grep -q '"nuxt"' "$REPO/package.json" 2>/dev/null && HAS_NUXT=true
grep -q '"@angular/core"' "$REPO/package.json" 2>/dev/null && HAS_ANGULAR=true

SRC="$REPO/src"
[[ -d "$REPO/app" ]] && SRC="$REPO/app"

# ═══ 1. JS DESIGN PATTERNS ═══

# Singleton abuse: module-level mutable state exported
singleton_count=$(grep -rl "let instance\|const instance\|module\.exports.*new " "$SRC" --include="*.ts" --include="*.js" 2>/dev/null | grep -v node_modules | grep -v test | wc -l | tr -d " ")
if [[ $singleton_count -gt 3 ]]; then
  findings_add "warning" "." "singleton-overuse" "Found $singleton_count singleton patterns — consider dependency injection" "Use DI container or factory pattern" "https://www.patterns.dev/vanilla/singleton-pattern"
fi

# God object: file with >10 exported functions
find "$SRC" -type f \( -name "*.ts" -o -name "*.js" \) 2>/dev/null | grep -v node_modules | grep -v test | while read -r f; do
  exports=$(grep -c "^export " "$f" 2>/dev/null || true)
  exports=${exports:-0}
  if [[ "$exports" -gt 15 ]]; then
    findings_add "warning" "$f" "god-module" "Module exports $exports items — split into focused modules" "Apply Module Pattern: one responsibility per file" "https://www.patterns.dev/vanilla/module-pattern"
  fi
done

# Missing observer pattern where events would be better (tight coupling)
direct_calls=$(grep -rn "parent\.\|props\.on[A-Z]\|this\.emit\|EventEmitter" "$SRC" --include="*.ts" --include="*.tsx" --include="*.js" 2>/dev/null | grep -v node_modules | grep -v test | wc -l | tr -d " ")

# ═══ 2. PERFORMANCE PATTERNS ═══

# No dynamic imports (everything statically loaded)
dynamic_imports=$(grep -r "import(" "$SRC" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" 2>/dev/null | grep -v node_modules | grep -v test | wc -l | tr -d " ")
static_imports=$(grep -r "^import " "$SRC" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" 2>/dev/null | grep -v node_modules | grep -v test | wc -l | tr -d " ")
if [[ $static_imports -gt 50 && $dynamic_imports -eq 0 ]]; then
  findings_add "warning" "." "no-dynamic-imports" "No dynamic imports found ($static_imports static) — no code splitting" "Use import() for routes and heavy components" "https://www.patterns.dev/vanilla/dynamic-import"
fi

# No route-based splitting (all routes in one bundle)
if [[ "$HAS_REACT" == "true" || "$HAS_VUE" == "true" ]]; then
  lazy_routes=$(grep -r "lazy(\|React\.lazy\|defineAsyncComponent\|() => import(" "$SRC" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" --include="*.vue" 2>/dev/null | grep -v node_modules | wc -l | tr -d " ")
  route_files=$(grep -rl "Route\|router\.\|createRouter\|useRouter" "$SRC" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" 2>/dev/null | grep -v node_modules | wc -l | tr -d " ")
  if [[ $route_files -gt 3 && $lazy_routes -eq 0 ]]; then
    findings_add "warning" "." "no-route-splitting" "Routes found but no lazy loading — entire app loads at once" "Use React.lazy() or defineAsyncComponent() for routes" "https://www.patterns.dev/vanilla/route-based-splitting"
  fi
fi

# No preload/prefetch hints
if [[ -d "$REPO/public" || -d "$REPO/app" ]]; then
  preload=$(grep -r "rel=\"preload\"\|rel=\"prefetch\"\|<link.*preload\|next/script.*strategy" "$REPO" --include="*.html" --include="*.tsx" --include="*.jsx" 2>/dev/null | grep -v node_modules | wc -l | tr -d " ")
  if [[ $preload -eq 0 && $static_imports -gt 30 ]]; then
    findings_add "info" "." "no-preload-hints" "No preload/prefetch hints — consider preloading critical resources" "Add <link rel='preload'> for fonts, critical CSS" "https://www.patterns.dev/vanilla/preload"
  fi
fi

# Bundle size: large dependencies that should be tree-shaken or replaced
if [[ -f "$REPO/package.json" ]]; then
  grep -q '"lodash"' "$REPO/package.json" 2>/dev/null && \
    findings_add "warning" "package.json" "heavy-dep-lodash" "lodash imported (70KB) — use lodash-es or native methods" "Import specific: lodash/get, or use native Array/Object" "https://www.patterns.dev/vanilla/tree-shaking"
  grep -q '"moment"' "$REPO/package.json" 2>/dev/null && \
    findings_add "warning" "package.json" "heavy-dep-moment" "moment.js imported (300KB) — use date-fns or Temporal" "Replace with date-fns (tree-shakeable) or native Intl" "https://www.patterns.dev/vanilla/tree-shaking"
fi

# ═══ 3. REACT PATTERNS ═══

if [[ "$HAS_REACT" == "true" ]]; then
  # HOC pattern (legacy, should use hooks)
  hoc_count=$(grep -rn "export default.*with[A-Z]\|function with[A-Z]\|const with[A-Z].*=.*Component" "$SRC" --include="*.tsx" --include="*.jsx" --include="*.ts" --include="*.js" 2>/dev/null | grep -v node_modules | grep -v test | wc -l | tr -d " ")
  if [[ $hoc_count -gt 2 ]]; then
    findings_add "warning" "." "hoc-pattern-legacy" "Found $hoc_count HOC patterns (withXxx) — prefer custom hooks" "Migrate HOCs to custom hooks for better composability" "https://www.patterns.dev/react/hoc-pattern"
  fi

  # Render props (legacy pattern)
  render_props=$(grep -rn "render={.*=>.*}\|children={.*=>.*}" "$SRC" --include="*.tsx" --include="*.jsx" 2>/dev/null | grep -v node_modules | grep -v test | wc -l | tr -d " ")
  if [[ $render_props -gt 3 ]]; then
    findings_add "info" "." "render-props-legacy" "Found $render_props render prop patterns — consider hooks" "Custom hooks provide same flexibility with less nesting" "https://www.patterns.dev/react/render-props-pattern"
  fi

  # Prop drilling (passing props through >3 levels)
  prop_drilling=$(grep -rn "props\.\w*\.\w*\.\w*\|{.*{.*{.*}" "$SRC" --include="*.tsx" --include="*.jsx" 2>/dev/null | grep -v node_modules | grep -v test | wc -l | tr -d " ")
  if [[ $prop_drilling -gt 5 ]]; then
    findings_add "warning" "." "prop-drilling" "Possible prop drilling detected — use Context or state management" "Apply Provider Pattern or use zustand/jotai" "https://www.patterns.dev/react/hooks-pattern"
  fi

  # useEffect with fetch (should be server component or React Query)
  use_effect_fetch=$(grep -rn "useEffect.*fetch\|useEffect.*axios\|useEffect.*get(" "$SRC" --include="*.tsx" --include="*.jsx" --include="*.ts" 2>/dev/null | grep -v node_modules | grep -v test | wc -l | tr -d " ")
  if [[ $use_effect_fetch -gt 3 ]]; then
    findings_add "warning" "." "useeffect-fetch" "Found $use_effect_fetch useEffect+fetch patterns — use server components or React Query" "Data fetching in useEffect causes waterfalls and loading states" "https://www.patterns.dev/react/client-side-rendering"
  fi
fi

# ═══ 4. RENDERING PATTERNS (Next.js / React) ═══

if [[ "$HAS_NEXT" == "true" ]]; then
  # 'use client' on pages (should be leaf components only)
  client_pages=$(find "$REPO/app" -name "page.tsx" -o -name "page.jsx" 2>/dev/null | xargs grep -l "'use client'\|\"use client\"" 2>/dev/null | wc -l | tr -d " ")
  if [[ $client_pages -gt 0 ]]; then
    findings_add "warning" "." "client-page" "$client_pages page(s) marked 'use client' — extract interactive parts" "Keep pages as server components, push 'use client' to leaf components" "https://www.patterns.dev/react/react-server-components"
  fi

  # No loading.tsx (no streaming/suspense)
  loading_files=$(find "$REPO/app" -name "loading.tsx" -o -name "loading.jsx" 2>/dev/null | wc -l | tr -d " ")
  if [[ $loading_files -eq 0 ]]; then
    findings_add "info" "." "no-streaming" "No loading.tsx files — missing streaming SSR boundaries" "Add loading.tsx for instant navigation with Suspense" "https://www.patterns.dev/react/streaming-ssr"
  fi

  # getServerSideProps (legacy Pages Router pattern in App Router project)
  if [[ -d "$REPO/app" ]]; then
    legacy_ssr=$(grep -rl "getServerSideProps\|getStaticProps" "$REPO" --include="*.ts" --include="*.tsx" 2>/dev/null | grep -v node_modules | wc -l | tr -d " ")
    if [[ $legacy_ssr -gt 0 ]]; then
      findings_add "warning" "." "legacy-data-fetching" "Found getServerSideProps/getStaticProps in App Router project — use async server components" "In App Router, fetch directly in server components" "https://www.patterns.dev/react/server-side-rendering"
    fi
  fi
fi

# ═══ 5. VUE PATTERNS ═══

if [[ "$HAS_VUE" == "true" || "$HAS_NUXT" == "true" ]]; then
  # Options API (legacy, should use Composition API)
  options_api=$(grep -rn "export default {" "$SRC" --include="*.vue" 2>/dev/null | grep -v node_modules | wc -l | tr -d " ")
  composition_api=$(grep -rn "<script setup\|defineComponent.*setup" "$SRC" --include="*.vue" --include="*.ts" 2>/dev/null | grep -v node_modules | wc -l | tr -d " ")
  if [[ $options_api -gt 5 && $composition_api -eq 0 ]]; then
    findings_add "warning" "." "vue-options-api" "Using Options API ($options_api components) — migrate to Composition API" "Composition API provides better TypeScript support and reusability" "https://www.patterns.dev/vue/composables"
  fi

  # No async components
  async_components=$(grep -rn "defineAsyncComponent\|() => import(" "$SRC" --include="*.vue" --include="*.ts" --include="*.js" 2>/dev/null | grep -v node_modules | wc -l | tr -d " ")
  vue_components=$(find "$SRC" -name "*.vue" 2>/dev/null | grep -v node_modules | wc -l | tr -d " ")
  if [[ $vue_components -gt 20 && $async_components -eq 0 ]]; then
    findings_add "warning" "." "vue-no-async" "No async components in $vue_components .vue files — all loaded upfront" "Use defineAsyncComponent() for heavy/below-fold components" "https://www.patterns.dev/vue/async-components"
  fi

  # No provide/inject (prop drilling in Vue)
  provide_inject=$(grep -rn "provide(\|inject(" "$SRC" --include="*.vue" --include="*.ts" 2>/dev/null | grep -v node_modules | wc -l | tr -d " ")
  props_count=$(grep -rn "defineProps\|props:" "$SRC" --include="*.vue" 2>/dev/null | grep -v node_modules | wc -l | tr -d " ")
  if [[ $props_count -gt 30 && $provide_inject -eq 0 ]]; then
    findings_add "info" "." "vue-no-provide-inject" "Heavy props usage ($props_count) but no provide/inject — possible prop drilling" "Use provide/inject or Pinia for deeply shared state" "https://www.patterns.dev/vue/provide-inject"
  fi

  # Nuxt: no useFetch/useAsyncData
  if [[ "$HAS_NUXT" == "true" ]]; then
    nuxt_fetch=$(grep -rn "useFetch\|useAsyncData\|useLazyFetch" "$SRC" --include="*.vue" --include="*.ts" 2>/dev/null | grep -v node_modules | wc -l | tr -d " ")
    raw_fetch=$(grep -rn "fetch(\|axios\.\|\$fetch" "$SRC" --include="*.vue" --include="*.ts" 2>/dev/null | grep -v node_modules | grep -v test | wc -l | tr -d " ")
    if [[ $raw_fetch -gt 5 && $nuxt_fetch -eq 0 ]]; then
      findings_add "warning" "." "nuxt-no-usefetch" "Using raw fetch ($raw_fetch) instead of useFetch/useAsyncData" "Nuxt composables handle SSR hydration and caching automatically" "https://www.patterns.dev/vue/data-fetching"
    fi
  fi
fi

# ═══ 6. GENERAL ANTI-PATTERNS ═══

# Barrel files (index.ts re-exporting everything — kills tree shaking)
barrel_files=0
while IFS= read -r f; do
  exports=$(grep -c "export.*from\|export {" "$f" 2>/dev/null || true)
  [[ "${exports:-0}" -gt 10 ]] && barrel_files=$((barrel_files + 1))
done < <(find "$SRC" -type f \( -name "index.ts" -o -name "index.js" \) 2>/dev/null | grep -v node_modules | grep -v test)
if [[ $barrel_files -gt 3 ]]; then
  findings_add "warning" "." "barrel-files" "Found $barrel_files barrel files (index.ts with >10 re-exports) — hurts tree shaking" "Import directly from source files instead of barrel indexes" "https://www.patterns.dev/vanilla/tree-shaking"
fi

# No virtualization for large lists
large_maps=$(grep -rn "\.map(" "$SRC" --include="*.tsx" --include="*.jsx" 2>/dev/null | grep -v node_modules | grep -v test | wc -l | tr -d ' ')
large_maps=${large_maps:-0}
virtualized=$(grep -r "react-window\|react-virtual\|@tanstack/virtual\|vue-virtual-scroller" "$REPO/package.json" 2>/dev/null | wc -l | tr -d ' ')
virtualized=${virtualized:-0}
if [[ $large_maps -gt 10 && $virtualized -eq 0 ]]; then
  findings_add "info" "." "no-virtualization" "Many list renders ($large_maps .map calls) but no virtualization library" "Use @tanstack/virtual or react-window for long lists" "https://www.patterns.dev/vanilla/list-virtualization"
fi
