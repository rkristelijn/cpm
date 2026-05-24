#!/usr/bin/env bash
# check-v8-perf.sh — Detect JavaScript patterns that cause V8 deoptimization.
#
# Based on research into V8 TurboFan behavior (Node 8+/Chrome 56+).
# Only flags patterns with proven, measurable performance impact.
#
# Checks:
# 1. new Function() — prevents optimization of entire scope
# 2. delete operator — forces hidden class transition (slow mode)
# 3. arguments leaking — prevents function optimization
# 4. with statement — dynamic scoping kills all optimization
# 5. Sparse arrays — forces V8 into dictionary mode
#
# @see https://v8.dev/docs/turbofan
# @see https://mathiasbynens.be/notes/shapes-ics
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/shell/init.sh" 2>/dev/null || true
cpm_check_enabled "v8-perf" 2>/dev/null || true

[[ -f "package.json" ]] || exit 0

source "$(dirname "$0")/../../lib/shell/search.sh" 2>/dev/null || {
  cpm_search_files() { grep -rn "$1" "$2" "${@:3}" 2>/dev/null || true; }
}

SRC="${CPM_SRC:-src}"
[[ -d "$SRC" ]] || SRC="."
FINDINGS=0
JS_GLOB='--include=*.ts --include=*.js --include=*.tsx --include=*.jsx'

search_src() {
  grep -rn "$1" "$SRC" --include="*.ts" --include="*.js" --include="*.tsx" --include="*.jsx" 2>/dev/null \
    | grep -v node_modules | grep -v '/test/' | grep -v '.spec.' | grep -v '.test.' || true
}

# ═══ 1. new Function() — prevents optimization of containing scope ═══
results=$(search_src 'new Function(')
if [[ -n "$results" ]]; then
  count=$(echo "$results" | wc -l | tr -d ' ')
  echo "  [fail] $count use(s) of new Function() — prevents V8 optimization of containing scope"
  echo "$results" | head -5 | sed 's/^/    /'
  FINDINGS=$((FINDINGS + 1))
fi

# ═══ 2. delete operator — forces object into dictionary mode ═══
results=$(search_src 'delete ')
if [[ -n "$results" ]]; then
  count=$(echo "$results" | wc -l | tr -d ' ')
  if [[ $count -gt 2 ]]; then
    echo "  [warn] $count use(s) of 'delete' — forces V8 hidden class transition (slow mode)"
    echo "         Fix: set to undefined/null, or destructure with rest"
    echo "$results" | head -3 | sed 's/^/    /'
    FINDINGS=$((FINDINGS + 1))
  fi
fi

# ═══ 3. arguments leaking — prevents function optimization ═══
results=$(search_src 'arguments')
if [[ -n "$results" ]]; then
  # Filter to actual leaking patterns
  leaks=$(echo "$results" | grep -E 'slice\.call\(arguments|Array\.from\(arguments|\.apply\(.*, *arguments' || true)
  if [[ -n "$leaks" ]]; then
    count=$(echo "$leaks" | wc -l | tr -d ' ')
    echo "  [warn] $count arguments leak(s) — use rest parameters (...args) instead"
    echo "$leaks" | head -3 | sed 's/^/    /'
    FINDINGS=$((FINDINGS + 1))
  fi
fi

# ═══ 4. with statement — kills all optimization in scope ═══
results=$(search_src 'with (')
if [[ -n "$results" ]]; then
  count=$(echo "$results" | wc -l | tr -d ' ')
  echo "  [fail] $count use(s) of 'with' statement — completely prevents V8 optimization"
  echo "$results" | head -3 | sed 's/^/    /'
  FINDINGS=$((FINDINGS + 1))
fi

# ═══ 5. Sparse arrays — forces V8 into dictionary elements mode ═══
results=$(search_src 'new Array(')
if [[ -n "$results" ]]; then
  # Only flag large pre-allocations without .fill()
  sparse=$(echo "$results" | grep -E 'new Array\([0-9]{4,}\)' | grep -v '\.fill' || true)
  if [[ -n "$sparse" ]]; then
    count=$(echo "$sparse" | wc -l | tr -d ' ')
    echo "  [info] $count large sparse array(s) — use Array(n).fill() or grow with push()"
    echo "$sparse" | head -3 | sed 's/^/    /'
    FINDINGS=$((FINDINGS + 1))
  fi
fi

# ═══ 6. Object.defineProperty in hot paths — slower than direct assignment ═══
results=$(search_src 'Object.defineProperty')
if [[ -n "$results" ]]; then
  count=$(echo "$results" | wc -l | tr -d ' ')
  if [[ $count -gt 5 ]]; then
    echo "  [info] $count Object.defineProperty call(s) — slower than direct assignment in hot paths"
    echo "         Only use when you need non-enumerable/non-writable descriptors"
    FINDINGS=$((FINDINGS + 1))
  fi
fi

# ═══ 7. JSON.parse/stringify in loops ═══
results=$(search_src 'JSON\.')
if [[ -n "$results" ]]; then
  in_loops=$(echo "$results" | grep -E 'for.*JSON\.|\.map\(.*JSON\.|\.forEach\(.*JSON\.' || true)
  if [[ -n "$in_loops" ]]; then
    count=$(echo "$in_loops" | wc -l | tr -d ' ')
    echo "  [warn] $count JSON.parse/stringify in loop(s) — cache outside the loop"
    echo "$in_loops" | head -3 | sed 's/^/    /'
    FINDINGS=$((FINDINGS + 1))
  fi
fi

# Summary
if [[ $FINDINGS -eq 0 ]]; then
  echo "  [pass] No V8 deoptimization patterns found"
fi

exit 0
