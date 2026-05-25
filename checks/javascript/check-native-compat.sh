#!/usr/bin/env bash
# checks/javascript/check-native-compat.sh
# @see ADR-129
# Detects usage of native APIs that may not be available in the target runtime.
# Reads Node version from .nvmrc/package.json and flags incompatible API usage.
# Also checks for Cloudflare Workers / Vercel Edge runtime limitations.
source "$(dirname "$0")/../../lib/shell/check.sh"

REPO="${1:-.}"

[ -f "$REPO/package.json" ] || exit 0

# --- Detect target Node version ---
NODE_VER=0
if [ -f "$REPO/.nvmrc" ]; then
  NODE_VER=$(sed 's/^v//' "$REPO/.nvmrc" | cut -d. -f1)
elif [ -f "$REPO/.node-version" ]; then
  NODE_VER=$(sed 's/^v//' "$REPO/.node-version" | cut -d. -f1)
else
  NODE_VER=$(grep -oE '"node":\s*"[^"]*"' "$REPO/package.json" 2>/dev/null | grep -oE '[0-9]+' | head -1)
fi
[ -z "$NODE_VER" ] && NODE_VER=0

# --- Detect edge runtime ---
IS_EDGE=false
IS_CF=false
if [ -f "$REPO/wrangler.toml" ] || [ -f "$REPO/wrangler.jsonc" ]; then
  IS_CF=true; IS_EDGE=true
elif grep -rq "runtime.*=.*'edge'\|runtime.*edge" "$REPO" \
  --include="*.ts" --include="*.js" 2>/dev/null; then
  IS_EDGE=true
fi

# --- Find JS/TS files ---
JS_FILES=$(find "$REPO" -type f \( -name "*.js" -o -name "*.ts" -o -name "*.mjs" -o -name "*.tsx" -o -name "*.jsx" \) \
  -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/dist/*" -not -path "*/.next/*" 2>/dev/null)
[ -z "$JS_FILES" ] && exit 0

# --- Helper: check if an API pattern is used ---
check_api() {
  local pattern="$1" min_ver="$2" desc="$3"
  [ "$NODE_VER" -ge "$min_ver" ] 2>/dev/null && return 0
  local match
  match=$(echo "$JS_FILES" | xargs grep -l "$pattern" 2>/dev/null | head -1 || true)
  [ -z "$match" ] && return 0
  local linenum
  linenum=$(grep -n "$pattern" "$match" 2>/dev/null | head -1 | cut -d: -f1 || true)
  if [ "$min_ver" -ge 99 ] 2>/dev/null; then
    findings_add "error" "$match:$linenum" "unstable-api" "$desc"
  else
    findings_add "warning" "$match:$linenum" "node-compat" "$desc (target: Node $NODE_VER)"
  fi
}

# --- Check API compatibility against Node version ---
if [ "$NODE_VER" -gt 0 ]; then
  check_api "structuredClone"      17 "structuredClone() requires Node 17+"
  check_api "Object\.hasOwn"       16 "Object.hasOwn() requires Node 16.9+"
  check_api "\.findLast("          18 "findLast() requires Node 18+"
  check_api "\.toSorted("          20 "toSorted() requires Node 20+"
  check_api "\.toReversed("        20 "toReversed() requires Node 20+"
  check_api "\.toSpliced("         20 "toSpliced() requires Node 20+"
  check_api "Object\.groupBy"      21 "Object.groupBy() requires Node 21+"
  check_api "Map\.groupBy"         21 "Map.groupBy() requires Node 21+"
  check_api "Promise\.withResolvers" 22 "Promise.withResolvers() requires Node 22+"
  check_api "crypto\.randomUUID"   15 "crypto.randomUUID() requires Node 15.6+"
  check_api "fs\.glob"             22 "fs.glob() requires Node 22+"
  check_api "Temporal\."           99 "Temporal API is not yet stable in any Node version"

  # fetch() — only flag if no polyfill present
  if [ "$NODE_VER" -lt 18 ]; then
    local_fetch_files=$(echo "$JS_FILES" | xargs grep -l "fetch(" 2>/dev/null || true)
    if [ -n "$local_fetch_files" ]; then
      match=$(echo "$local_fetch_files" | xargs grep -L "node-fetch\|cross-fetch\|whatwg-fetch" 2>/dev/null | head -1 || true)
      if [ -n "$match" ]; then
        linenum=$(grep -n "fetch(" "$match" 2>/dev/null | head -1 | cut -d: -f1 || true)
        findings_add "warning" "$match:$linenum" "node-compat" "Native fetch() requires Node 18+ (target: Node $NODE_VER)"
      fi
    fi
  fi
fi

# --- Check edge runtime compatibility ---
if [ "$IS_EDGE" = true ]; then
  # Find files that opt into edge runtime
  EDGE_FILES=$(echo "$JS_FILES" | xargs grep -l "runtime.*edge\|export.*runtime" 2>/dev/null || true)
  EDGE_FILES="$EDGE_FILES $(echo "$JS_FILES" | grep -E "middleware\.(ts|js)" 2>/dev/null || true)"

  if [ -n "$EDGE_FILES" ]; then
    check_edge() {
      local pattern="$1" desc="$2"
      local match
      match=$(echo "$EDGE_FILES" | tr ' ' '\n' | sort -u | xargs grep -l "$pattern" 2>/dev/null | head -1)
      [ -z "$match" ] && return 0
      local linenum
      linenum=$(grep -n "$pattern" "$match" 2>/dev/null | head -1 | cut -d: -f1)
      findings_add "error" "$match:$linenum" "edge-compat" "$desc"
    }

    check_edge "require('fs')\|from 'fs'\|from 'node:fs'"  "fs module not available in edge runtime"
    check_edge "child_process"                              "child_process not available in edge runtime"
    check_edge "__dirname\|__filename"                      "__dirname/__filename not available in edge/ESM"
    check_edge "eval("                                     "eval() blocked in edge runtime"
    check_edge "new Function("                             "new Function() blocked in edge runtime"
  fi
fi

# --- Summary (findings_finish handles exit via trap) ---
