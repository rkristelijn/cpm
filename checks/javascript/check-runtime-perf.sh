#!/usr/bin/env bash
#
# check-runtime-perf.sh — Detect runtime performance anti-patterns
#
# Not build-time (bundle size) — actual runtime execution problems:
# - Blocking the event loop
# - Memory leaks
# - Unnecessary re-renders
# - Layout thrashing
# - Uncontrolled growth
# - Missing cancellation
#
# These cause: jank, OOM crashes, slow APIs, high TTFB, poor INP

set -o nounset -o pipefail
findings_add() { printf "  %-8s %-32s %s\n" "$1" "$3" "$4"; }

REPO="${1:-.}"
SRC="$REPO/src"
[[ -d "$REPO/app" ]] && SRC="$REPO/app"
[[ ! -d "$SRC" ]] && SRC="$REPO"

# ═══ 1. EVENT LOOP BLOCKING ═══

# Sync fs in request handlers (blocks entire server)
sync_fs=$(grep -rn "readFileSync\|writeFileSync\|readdirSync\|statSync\|existsSync" "$SRC" --include="*.ts" --include="*.js" 2>/dev/null | grep -v node_modules | grep -v test | grep -v "\.config\.\|next\.config\|webpack\|vite\.config\|jest\|vitest" | wc -l | tr -d ' ')
if [[ ${sync_fs:-0} -gt 5 ]]; then
  findings_add "warning" "." "sync-fs-in-runtime" "$sync_fs sync filesystem calls — blocks event loop in production"
fi

# Sync crypto (bcryptSync, pbkdf2Sync, randomBytes without callback)
sync_crypto=$(grep -rn "pbkdf2Sync\|scryptSync\|bcrypt.*Sync\|hashSync\|compareSync" "$SRC" --include="*.ts" --include="*.js" 2>/dev/null | grep -v node_modules | grep -v test | wc -l | tr -d ' ')
if [[ ${sync_crypto:-0} -gt 0 ]]; then
  findings_add "error" "." "sync-crypto" "$sync_crypto sync crypto operations — blocks event loop for 100ms+ per call"
fi

# JSON.parse/stringify on large objects in hot paths
json_in_loop=$(grep -rn "JSON\.\(parse\|stringify\)" "$SRC" --include="*.ts" --include="*.js" 2>/dev/null | grep -v node_modules | grep -v test | wc -l | tr -d ' ')
if [[ ${json_in_loop:-0} -gt 30 ]]; then
  findings_add "info" "." "excessive-json-serialization" "$json_in_loop JSON.parse/stringify calls — consider streaming or caching"
fi

# RegExp without flags in loops (recompiles every iteration)
regex_in_loop=$(grep -rn "new RegExp(" "$SRC" --include="*.ts" --include="*.js" 2>/dev/null | grep -v node_modules | grep -v test | wc -l | tr -d ' ')
if [[ ${regex_in_loop:-0} -gt 10 ]]; then
  findings_add "info" "." "dynamic-regex" "$regex_in_loop dynamic RegExp constructions — hoist outside loops if pattern is static"
fi

# ═══ 2. MEMORY LEAKS ═══

# addEventListener without removeEventListener
add_listener=$(grep -rn "addEventListener\|\.on(" "$SRC" --include="*.ts" --include="*.tsx" --include="*.js" 2>/dev/null | grep -v node_modules | grep -v test | wc -l | tr -d ' ')
remove_listener=$(grep -rn "removeEventListener\|\.off(\|\.removeListener\|AbortController\|cleanup\|return.*=>" "$SRC" --include="*.ts" --include="*.tsx" --include="*.js" 2>/dev/null | grep -v node_modules | grep -v test | wc -l | tr -d ' ')
if [[ ${add_listener:-0} -gt 10 && ${remove_listener:-0} -lt $((add_listener / 3)) ]]; then
  findings_add "warning" "." "event-listener-leak" "$add_listener event listeners but only $remove_listener cleanups — likely memory leak"
fi

# setInterval without clearInterval
set_interval=$(grep -rn "setInterval" "$SRC" --include="*.ts" --include="*.tsx" --include="*.js" 2>/dev/null | grep -v node_modules | grep -v test | wc -l | tr -d ' ')
clear_interval=$(grep -rn "clearInterval" "$SRC" --include="*.ts" --include="*.tsx" --include="*.js" 2>/dev/null | grep -v node_modules | grep -v test | wc -l | tr -d ' ')
if [[ ${set_interval:-0} -gt 2 && ${clear_interval:-0} -lt ${set_interval:-0} ]]; then
  findings_add "warning" "." "interval-leak" "$set_interval setInterval but only $clear_interval clearInterval — timers leak on unmount"
fi

# Growing arrays/maps without bounds (no .delete, no size limit, no eviction)
global_collections=$(grep -rn "^const \w* = new Map\|^const \w* = new Set\|^const \w* = \[\]" "$SRC" --include="*.ts" --include="*.js" 2>/dev/null | grep -v node_modules | grep -v test | grep -v "\.config" | wc -l | tr -d ' ')
if [[ ${global_collections:-0} -gt 10 ]]; then
  findings_add "info" "." "unbounded-collections" "$global_collections module-level collections — ensure they have eviction/size limits"
fi

# ═══ 3. RENDER PERFORMANCE (React/Vue) ═══

# Object/array literals in JSX props (new reference every render)
inline_objects=$(grep -rn "={{" "$SRC" --include="*.tsx" --include="*.jsx" 2>/dev/null | grep -v node_modules | grep -v test | grep -v "style={{" | wc -l | tr -d ' ')
if [[ ${inline_objects:-0} -gt 20 ]]; then
  findings_add "warning" "." "inline-object-props" "$inline_objects inline object props (={{...}}) — creates new reference every render, breaks memo"
fi

# Anonymous functions in JSX (new reference every render)
inline_handlers=$(grep -rn "onClick={() =>\|onChange={() =>\|onSubmit={() =>" "$SRC" --include="*.tsx" --include="*.jsx" 2>/dev/null | grep -v node_modules | grep -v test | wc -l | tr -d ' ')
if [[ ${inline_handlers:-0} -gt 30 ]]; then
  findings_add "info" "." "inline-handlers" "$inline_handlers inline arrow handlers — extract to useCallback if in lists or memoized children"
fi

# Rendering in loops without key or with index as key
index_key=$(grep -rn "key={i}\|key={index}\|key={idx}" "$SRC" --include="*.tsx" --include="*.jsx" 2>/dev/null | grep -v node_modules | grep -v test | wc -l | tr -d ' ')
if [[ ${index_key:-0} -gt 3 ]]; then
  findings_add "warning" "." "index-as-key" "$index_key uses of array index as key — causes incorrect reconciliation on reorder"
fi

# ═══ 4. NETWORK PERFORMANCE ═══

# No AbortController for fetch (can't cancel on unmount)
fetch_calls=$(grep -rn "fetch(" "$SRC" --include="*.ts" --include="*.tsx" --include="*.js" 2>/dev/null | grep -v node_modules | grep -v test | wc -l | tr -d ' ')
abort_usage=$(grep -rn "AbortController\|signal:" "$SRC" --include="*.ts" --include="*.tsx" --include="*.js" 2>/dev/null | grep -v node_modules | grep -v test | wc -l | tr -d ' ')
if [[ ${fetch_calls:-0} -gt 5 && ${abort_usage:-0} -eq 0 ]]; then
  findings_add "info" "." "no-abort-controller" "$fetch_calls fetch calls but no AbortController — can't cancel requests on navigation/unmount"
fi

# No request deduplication (same URL fetched multiple times)
# No response caching headers

# ═══ 5. CSS/LAYOUT PERFORMANCE ═══

# Layout thrashing: reading then writing DOM in sequence
layout_thrash=$(grep -rn "offsetHeight\|offsetWidth\|getBoundingClientRect\|clientHeight\|scrollTop" "$SRC" --include="*.ts" --include="*.tsx" --include="*.js" 2>/dev/null | grep -v node_modules | grep -v test | wc -l | tr -d ' ')
if [[ ${layout_thrash:-0} -gt 10 ]]; then
  findings_add "info" "." "layout-reads" "$layout_thrash DOM layout reads — batch reads before writes to avoid layout thrashing"
fi

# Expensive CSS: box-shadow, filter, backdrop-filter in animations
expensive_css=$(grep -rn "box-shadow\|backdrop-filter\|filter:" "$SRC" --include="*.css" --include="*.scss" 2>/dev/null | grep -v node_modules | grep "animation\|transition\|@keyframes" | wc -l | tr -d ' ')

# ═══ 6. BACKEND PERFORMANCE ═══

# No connection pooling
if grep -rq "createConnection\|new Client\|MongoClient" "$SRC" --include="*.ts" --include="*.js" 2>/dev/null; then
  pool=$(grep -rn "pool\|Pool\|poolSize\|connectionLimit\|max:" "$SRC" --include="*.ts" --include="*.js" 2>/dev/null | grep -v node_modules | grep -v test | wc -l | tr -d ' ')
  if [[ ${pool:-0} -eq 0 ]]; then
    findings_add "warning" "." "no-connection-pool" "Database connections without pooling — creates new connection per request"
  fi
fi

# No request timeout
timeout=$(grep -rn "timeout\|AbortSignal\.timeout\|setTimeout.*reject" "$SRC" --include="*.ts" --include="*.js" 2>/dev/null | grep -v node_modules | grep -v test | wc -l | tr -d ' ')
if [[ ${fetch_calls:-0} -gt 5 && ${timeout:-0} -eq 0 ]]; then
  findings_add "warning" "." "no-request-timeout" "HTTP requests without timeout — can hang indefinitely"
fi

# Unbounded queries (no LIMIT, no pagination)
no_limit=$(grep -rn "\.find(\|\.findAll\|\.findMany\|SELECT.*FROM" "$SRC" --include="*.ts" --include="*.js" --include="*.py" 2>/dev/null | grep -v node_modules | grep -v test | grep -v "limit\|LIMIT\|take\|first\|top" | wc -l | tr -d ' ')
if [[ ${no_limit:-0} -gt 5 ]]; then
  findings_add "warning" "." "unbounded-queries" "$no_limit database queries without LIMIT/pagination — can return millions of rows"
fi

echo ""
echo "  Runtime performance check complete."
