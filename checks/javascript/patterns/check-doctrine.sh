#!/usr/bin/env bash
#
# check-doctrine.sh — Framework doctrine engine
#
# Detects: "building against the framework instead of with it"
#
# Not linting. Not style. This checks whether you understand
# the mental model of your framework and follow its invariants.
#
# Metrics:
#   React:   effect density (effects per component)
#   Vue:     reactive graph complexity (watchers per component)
#   Angular: subscription leaks (subscriptions per component)
#   NestJS:  abstraction depth (layers per request)
#   Next.js: boundary crossings (client/server leaks)
#
# @see https://react.dev/learn/you-might-not-need-an-effect
# @see https://vuejs.org/guide/extras/reactivity-in-depth.html
# @see https://nextjs.org/docs/app

set -o nounset -o pipefail
findings_add() { printf "  %-8s %-30s %s\n" "$1" "$3" "$4"; }

REPO="${1:-.}"
[[ -f "$REPO/package.json" ]] || exit 0

SRC="$REPO/src"
[[ -d "$REPO/app" ]] && SRC="$REPO/app"
[[ ! -d "$SRC" ]] && SRC="$REPO"

# Detect framework
HAS_REACT=false; HAS_NEXT=false; HAS_VUE=false; HAS_ANGULAR=false; HAS_NEST=false
grep -q '"react"' "$REPO/package.json" 2>/dev/null && HAS_REACT=true
grep -q '"next"' "$REPO/package.json" 2>/dev/null && HAS_NEXT=true
grep -q '"vue"' "$REPO/package.json" 2>/dev/null && HAS_VUE=true
grep -q '"@angular/core"' "$REPO/package.json" 2>/dev/null && HAS_ANGULAR=true
grep -q '"@nestjs/core"' "$REPO/package.json" 2>/dev/null && HAS_NEST=true

# ═══════════════════════════════════════════════════════════════
# REACT DOCTRINE: referential rendering + composition
# Invariant: UI = f(state). Effects are escape hatches, not tools.
# ═══════════════════════════════════════════════════════════════

if [[ "$HAS_REACT" == "true" ]]; then
  # --- Effect density ---
  components=$(find "$SRC" -type f \( -name "*.tsx" -o -name "*.jsx" \) 2>/dev/null | grep -v node_modules | grep -v test | wc -l | tr -d ' ')
  effects=$(grep -r "useEffect" "$SRC" --include="*.tsx" --include="*.jsx" 2>/dev/null | grep -v node_modules | grep -v test | wc -l | tr -d ' ')
  components=${components:-1}
  if [[ $components -gt 0 ]]; then
    density=$((effects * 100 / components))
    if [[ $density -gt 150 ]]; then
      findings_add "error" "." "effect-density-critical" "Effect density: ${density}% ($effects effects / $components components) — you're fighting React"
    elif [[ $density -gt 80 ]]; then
      findings_add "warning" "." "effect-density-high" "Effect density: ${density}% — many effects are likely derived state or event handlers"
    fi
  fi

  # --- Derived state in effects (the #1 React anti-pattern) ---
  derived_state=$(grep -rn "useEffect.*\n.*set[A-Z]" "$SRC" --include="*.tsx" --include="*.jsx" 2>/dev/null | grep -v node_modules | grep -v test | wc -l | tr -d ' ')
  # Better: look for setState inside useEffect with deps that could be computed
  sync_effects=$(grep -B1 -A3 "useEffect" "$SRC"/**/*.tsx "$SRC"/**/*.jsx 2>/dev/null | grep -c "set[A-Z].*(" || true)
  if [[ ${sync_effects:-0} -gt 5 ]]; then
    findings_add "warning" "." "derived-state-in-effect" "~$sync_effects setState calls inside useEffect — likely derived state (just compute it)"
  fi

  # --- State duplication from props ---
  state_from_props=$(grep -rn "useState(props\.\|useState(.*props" "$SRC" --include="*.tsx" --include="*.jsx" 2>/dev/null | grep -v node_modules | grep -v test | wc -l | tr -d ' ')
  if [[ ${state_from_props:-0} -gt 2 ]]; then
    findings_add "warning" "." "state-duplication" "$state_from_props useState(props.x) — duplicating props into state causes sync bugs"
  fi

  # --- Unnecessary memoization ---
  memo_count=$(grep -rn "useMemo\|useCallback\|React\.memo" "$SRC" --include="*.tsx" --include="*.jsx" 2>/dev/null | grep -v node_modules | grep -v test | wc -l | tr -d ' ')
  if [[ ${memo_count:-0} -gt $((components / 2)) && $components -gt 10 ]]; then
    findings_add "info" "." "over-memoization" "$memo_count memoizations in $components components — React Compiler will handle this"
  fi

  # --- Abstraction inversion: custom fetch over React Query/SWR ---
  has_query=$(grep -r "react-query\|@tanstack/react-query\|swr" "$REPO/package.json" 2>/dev/null | wc -l | tr -d ' ')
  custom_fetch_hooks=$(grep -rn "function use.*Fetch\|const use.*Fetch\|function use.*Query\|const use.*Data" "$SRC" --include="*.ts" --include="*.tsx" 2>/dev/null | grep -v node_modules | grep -v test | wc -l | tr -d ' ')
  if [[ ${custom_fetch_hooks:-0} -gt 2 && ${has_query:-0} -gt 0 ]]; then
    findings_add "warning" "." "abstraction-inversion" "Custom fetch hooks ($custom_fetch_hooks) wrapping React Query — use it directly"
  fi
fi

# ═══════════════════════════════════════════════════════════════
# NEXT.JS DOCTRINE: server/client boundaries
# Invariant: server-first, push client to leaves, no waterfalls
# ═══════════════════════════════════════════════════════════════

if [[ "$HAS_NEXT" == "true" && -d "$REPO/app" ]]; then
  # --- Boundary crossings: internal API calls from server ---
  internal_api=$(grep -rn "fetch.*['\"]\/api\|fetch.*localhost" "$REPO/app" --include="*.ts" --include="*.tsx" 2>/dev/null | grep -v node_modules | grep -v test | grep -v "use client" | wc -l | tr -d ' ')
  if [[ ${internal_api:-0} -gt 0 ]]; then
    findings_add "warning" "." "internal-api-call" "$internal_api fetch('/api/...') from server components — access DB directly instead"
  fi

  # --- Client component explosion ---
  client_files=$(grep -rl "'use client'\|\"use client\"" "$REPO/app" --include="*.tsx" --include="*.ts" 2>/dev/null | grep -v node_modules | wc -l | tr -d ' ')
  total_files=$(find "$REPO/app" -type f -name "*.tsx" 2>/dev/null | grep -v node_modules | wc -l | tr -d ' ')
  if [[ ${total_files:-1} -gt 10 ]]; then
    client_pct=$((${client_files:-0} * 100 / total_files))
    if [[ $client_pct -gt 60 ]]; then
      findings_add "warning" "." "client-explosion" "${client_pct}% of components are 'use client' — push interactivity to leaf components"
    fi
  fi

  # --- Fetch waterfalls (sequential awaits in server components) ---
  waterfall=$(grep -rn "await.*\nawait" "$REPO/app" --include="*.ts" --include="*.tsx" 2>/dev/null | grep -v node_modules | grep -v "use client" | wc -l | tr -d ' ')
  if [[ ${waterfall:-0} -gt 5 ]]; then
    findings_add "warning" "." "fetch-waterfall" "Sequential awaits in server components — use Promise.all() for parallel data fetching"
  fi
fi

# ═══════════════════════════════════════════════════════════════
# VUE DOCTRINE: transparent reactivity
# Invariant: reactive graph should be shallow and predictable
# ═══════════════════════════════════════════════════════════════

if [[ "$HAS_VUE" == "true" ]]; then
  vue_files=$(find "$SRC" -name "*.vue" 2>/dev/null | grep -v node_modules | wc -l | tr -d ' ')

  # --- Watch abuse (watchers per component) ---
  watchers=$(grep -r "watch(" "$SRC" --include="*.vue" --include="*.ts" 2>/dev/null | grep -v node_modules | grep -v test | wc -l | tr -d ' ')
  if [[ ${vue_files:-1} -gt 0 ]]; then
    watch_density=$((${watchers:-0} * 100 / ${vue_files:-1}))
    if [[ $watch_density -gt 100 ]]; then
      findings_add "warning" "." "watch-abuse" "Watch density: ${watch_density}% ($watchers watchers / $vue_files components) — use computed instead"
    fi
  fi

  # --- Deep watchers (reactive graph explosion) ---
  deep_watch=$(grep -rn "watch(.*deep.*true\|{ deep: true }" "$SRC" --include="*.vue" --include="*.ts" 2>/dev/null | grep -v node_modules | wc -l | tr -d ' ')
  if [[ ${deep_watch:-0} -gt 3 ]]; then
    findings_add "warning" "." "deep-watch-explosion" "$deep_watch deep watchers — causes reactive graph explosion, flatten your state"
  fi

  # --- Side effects in computed ---
  computed_effects=$(grep -A5 "computed(" "$SRC" --include="*.vue" --include="*.ts" 2>/dev/null | grep -c "fetch\|axios\|console\|emit\|router" || true)
  if [[ ${computed_effects:-0} -gt 0 ]]; then
    findings_add "error" "." "computed-side-effects" "Side effects in computed() — computed must be pure (use watch for effects)"
  fi

  # --- Giant composables (>100 lines) ---
  find "$SRC" -type f -name "use*.ts" 2>/dev/null | grep -v node_modules | while read -r f; do
    lines=$(wc -l < "$f" | tr -d ' ')
    if [[ $lines -gt 100 ]]; then
      findings_add "warning" "$f" "giant-composable" "Composable is $lines lines — split into focused composables"
    fi
  done
fi

# ═══════════════════════════════════════════════════════════════
# ANGULAR DOCTRINE: DI + declarative architecture
# Invariant: everything through DI, observables managed by framework
# ═══════════════════════════════════════════════════════════════

if [[ "$HAS_ANGULAR" == "true" ]]; then
  # --- Subscription leaks ---
  subscribes=$(grep -rn "\.subscribe(" "$SRC" --include="*.ts" 2>/dev/null | grep -v node_modules | grep -v test | grep -v spec | wc -l | tr -d ' ')
  unsubscribes=$(grep -rn "unsubscribe\|takeUntil\|takeUntilDestroyed\|async pipe\|DestroyRef" "$SRC" --include="*.ts" --include="*.html" 2>/dev/null | grep -v node_modules | wc -l | tr -d ' ')
  if [[ ${subscribes:-0} -gt 5 && ${unsubscribes:-0} -lt $((subscribes / 2)) ]]; then
    findings_add "error" "." "subscription-leak" "$subscribes .subscribe() but only $unsubscribes cleanup patterns — memory leaks"
  fi

  # --- Manual DI instead of inject() ---
  constructor_inject=$(grep -rn "constructor(" "$SRC" --include="*.ts" 2>/dev/null | grep -v node_modules | grep -v test | grep "private\|protected\|public\|readonly" | wc -l | tr -d ' ')
  inject_fn=$(grep -rn "= inject(" "$SRC" --include="*.ts" 2>/dev/null | grep -v node_modules | wc -l | tr -d ' ')
  if [[ ${constructor_inject:-0} -gt 10 && ${inject_fn:-0} -eq 0 ]]; then
    findings_add "info" "." "no-inject-function" "Using constructor DI only — inject() is more tree-shakeable and testable"
  fi
fi

# ═══════════════════════════════════════════════════════════════
# NESTJS DOCTRINE: layered enterprise architecture
# Invariant: thin controllers, business in services, validation at boundary
# ═══════════════════════════════════════════════════════════════

if [[ "$HAS_NEST" == "true" ]]; then
  # --- Abstraction depth (layers per request) ---
  controllers=$(find "$SRC" -name "*.controller.ts" 2>/dev/null | grep -v node_modules | wc -l | tr -d ' ')
  services=$(find "$SRC" -name "*.service.ts" 2>/dev/null | grep -v node_modules | wc -l | tr -d ' ')
  repos=$(find "$SRC" -name "*.repository.ts" 2>/dev/null | grep -v node_modules | wc -l | tr -d ' ')
  mappers=$(find "$SRC" -name "*.mapper.ts" -o -name "*.transformer.ts" 2>/dev/null | grep -v node_modules | wc -l | tr -d ' ')
  dtos=$(find "$SRC" -name "*.dto.ts" 2>/dev/null | grep -v node_modules | wc -l | tr -d ' ')

  if [[ ${controllers:-0} -gt 0 ]]; then
    layers_per_ctrl=$(( (${services:-0} + ${repos:-0} + ${mappers:-0}) / ${controllers:-1} ))
    if [[ $layers_per_ctrl -gt 5 ]]; then
      findings_add "warning" "." "enterprise-poisoning" "Abstraction depth: $layers_per_ctrl layers per controller — CRUD doesn't need 7 layers"
    fi
  fi

  # --- Pass-through services (service just calls repository) ---
  pass_through=$(find "$SRC" -name "*.service.ts" 2>/dev/null | grep -v node_modules | while read -r f; do
    methods=$(grep -c "async \|public " "$f" 2>/dev/null || true)
    delegates=$(grep -c "this\.\w*Repository\.\|this\.\w*Service\." "$f" 2>/dev/null || true)
    [[ ${methods:-0} -gt 0 && ${delegates:-0} -ge ${methods:-0} ]] && echo "$f"
  done | wc -l | tr -d ' ')
  if [[ ${pass_through:-0} -gt 3 ]]; then
    findings_add "warning" "." "pass-through-services" "$pass_through services just delegate to repository — remove unnecessary layer"
  fi

  # --- DTO hell ---
  if [[ ${dtos:-0} -gt $((${controllers:-0} * 4)) && ${controllers:-0} -gt 3 ]]; then
    findings_add "info" "." "dto-hell" "$dtos DTOs for $controllers controllers — consider shared DTOs or class inheritance"
  fi
fi

# ═══════════════════════════════════════════════════════════════
# UNIVERSAL: async anti-patterns
# ═══════════════════════════════════════════════════════════════

# Sequential awaits that could be parallel
seq_awaits=$(grep -B0 -A1 "await " "$SRC" --include="*.ts" --include="*.tsx" --include="*.js" -r 2>/dev/null | grep -c "^.*await.*\n.*await" || true)
# Simpler: count files with multiple sequential awaits
multi_await_files=$(find "$SRC" -type f \( -name "*.ts" -o -name "*.tsx" \) 2>/dev/null | grep -v node_modules | grep -v test | while read -r f; do
  count=$(grep -c "^[[:space:]]*await " "$f" 2>/dev/null || true)
  [[ ${count:-0} -gt 4 ]] && echo "$f"
done | wc -l | tr -d ' ')
if [[ ${multi_await_files:-0} -gt 5 ]]; then
  findings_add "info" "." "sequential-awaits" "$multi_await_files files with 5+ sequential awaits — consider Promise.all() for independent operations"
fi

# Fire-and-forget promises (no await, no .catch)
fire_forget=$(grep -rn "[^await] \w*()" "$SRC" --include="*.ts" --include="*.tsx" 2>/dev/null | grep -v node_modules | grep -v test | grep "async\|Promise\|fetch" | grep -v "await\|\.then\|\.catch" | wc -l | tr -d ' ')

echo ""
echo "  Framework doctrine check complete."
