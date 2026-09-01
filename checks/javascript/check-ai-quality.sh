#!/usr/bin/env bash
# cpm:ignore-file SCA-028 — detector/test source: contains the patterns it checks for
#
# check-ai-quality.sh — Detect AI-generated code problems
#
# "Is this code a senior developer would accept in a PR?"
#
# Catches what TypeScript and ESLint miss:
# - Phantom imports (package not in package.json)
# - Dead exports (exported but never imported)
# - Missing error handling (async without try/catch)
# - Convention drift (inconsistent naming/structure)
# - Unnecessary abstractions (interface with 1 impl)
# - Stale boilerplate (wrong tooling patterns)

set -o nounset -o pipefail
findings_add() { printf "  %-8s %-32s %s\n" "$1" "$3" "$4"; }

REPO="${1:-.}"
[[ -f "$REPO/package.json" ]] || exit 0

SRC="$REPO/src"
[[ -d "$REPO/app" ]] && SRC="$REPO/app"
[[ ! -d "$SRC" ]] && SRC="$REPO"

# ═══ 1. PHANTOM IMPORTS — importing packages not in package.json ═══
if [[ -f "$REPO/package.json" ]]; then
  declared_deps=$(cat "$REPO/package.json" | grep -o '"[^"]*":' | tr -d '":' | sort -u)

  # Node builtins that don't need to be in package.json
  builtins="assert buffer child_process cluster console crypto dgram dns domain events fs http http2 https inspector module net os path perf_hooks process punycode querystring readline repl stream string_decoder sys timers tls trace_events tty url util v8 vm worker_threads zlib"

  phantom_count=0
  grep -rh "from ['\"]" "$SRC" --include="*.ts" --include="*.tsx" --include="*.js" 2>/dev/null | \
    grep -v node_modules | grep -v "from ['\"]\." | grep -v "from ['\"]node:" | \
    sed "s/.*from ['\"]//;s/['\"].*//" | sed 's|/.*||' | \
    grep "^[a-z]" | sort -u | while read -r pkg; do
      [[ -z "$pkg" || ${#pkg} -lt 2 ]] && continue
      # Skip builtins
      echo "$builtins" | grep -qw "$pkg" && continue
      # Skip if declared
      echo "$declared_deps" | grep -qx "$pkg" && continue
      # Skip common type packages (often transitive)
      [[ "$pkg" == "csstype" ]] && continue
      phantom_count=$((phantom_count + 1))
      [[ $phantom_count -le 3 ]] && findings_add "error" "." "phantom-import:$pkg" "Imports '$pkg' but it's not in package.json — install it or remove"
  done
fi

# ═══ 2. MISSING ERROR HANDLING — async without try/catch ═══
async_fns=$(grep -rn "async " "$SRC" --include="*.ts" --include="*.tsx" --include="*.js" 2>/dev/null | grep -v node_modules | grep -v test | grep -v "\.d\.ts" | wc -l | tr -d ' ')
try_catch=$(grep -rn "try {" "$SRC" --include="*.ts" --include="*.tsx" --include="*.js" 2>/dev/null | grep -v node_modules | grep -v test | wc -l | tr -d ' ')
catch_handlers=$(grep -rn "\.catch(\|catch (e\|catch(e" "$SRC" --include="*.ts" --include="*.tsx" --include="*.js" 2>/dev/null | grep -v node_modules | grep -v test | wc -l | tr -d ' ')
total_handling=$((${try_catch:-0} + ${catch_handlers:-0}))

if [[ ${async_fns:-0} -gt 10 ]]; then
  ratio=$((total_handling * 100 / ${async_fns:-1}))
  if [[ $ratio -lt 20 ]]; then
    findings_add "warning" "." "missing-error-handling" "Only ${ratio}% of async functions have error handling ($total_handling handlers / $async_fns async fns)"
  fi
fi

# ═══ 3. DEAD EXPORTS — exported but never imported within project ═══
dead_exports=0
grep -rh "^export function \|^export const \|^export class " "$SRC" --include="*.ts" --include="*.tsx" --include="*.js" 2>/dev/null | \
  grep -v node_modules | grep -v test | grep -v "index\." | \
  sed 's/export function //;s/export const //;s/export class //;s/[({<].*//' | \
  tr -d ' ' | sort -u | head -50 | while read -r name; do
    [[ -z "$name" || ${#name} -lt 3 ]] && continue
    # Check if imported anywhere
    usages=$(grep -r "import.*$name\|{ $name\|{$name\|, $name" "$SRC" --include="*.ts" --include="*.tsx" --include="*.js" 2>/dev/null | grep -v node_modules | grep -v "export" | wc -l | tr -d ' ')
    if [[ ${usages:-0} -eq 0 ]]; then
      dead_exports=$((dead_exports + 1))
    fi
done
if [[ ${dead_exports:-0} -gt 10 ]]; then
  findings_add "warning" "." "dead-exports" "$dead_exports exported symbols never imported — dead code (AI often generates unused helpers)"
fi

# ═══ 4. CONVENTION DRIFT — inconsistent naming in project ═══

# File naming: check if project mixes kebab-case and camelCase
kebab_files=$(find "$SRC" -type f \( -name "*-*" \) \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" \) 2>/dev/null | grep -v node_modules | grep -v test | wc -l | tr -d ' ')
camel_files=$(find "$SRC" -type f \( -name "*[a-z][A-Z]*" \) \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" \) 2>/dev/null | grep -v node_modules | grep -v test | wc -l | tr -d ' ')
total_named=$((${kebab_files:-0} + ${camel_files:-0}))
if [[ $total_named -gt 20 ]]; then
  if [[ ${kebab_files:-0} -gt 5 && ${camel_files:-0} -gt 5 ]]; then
    minority=$((kebab_files < camel_files ? kebab_files : camel_files))
    findings_add "info" "." "mixed-file-naming" "Mixed file naming: $kebab_files kebab-case + $camel_files camelCase — pick one convention"
  fi
fi

# ═══ 5. UNNECESSARY ABSTRACTIONS — AI overengineering ═══

# Interfaces with only 1 implementation
interfaces=$(grep -rn "^export interface \|^interface " "$SRC" --include="*.ts" 2>/dev/null | grep -v node_modules | grep -v test | grep -v "\.d\.ts" | wc -l | tr -d ' ')
# Single-method classes (should be a function)
single_method_classes=$(find "$SRC" -type f -name "*.ts" 2>/dev/null | grep -v node_modules | grep -v test | while read -r f; do
  classes=$(grep -c "^export class \|^class " "$f" 2>/dev/null || true)
  methods=$(grep -c "^\s*\(async \)\?\w\+(" "$f" 2>/dev/null || true)
  [[ ${classes:-0} -gt 0 && ${methods:-0} -le 2 ]] && echo "$f"
done | wc -l | tr -d ' ')
if [[ ${single_method_classes:-0} -gt 5 ]]; then
  findings_add "info" "." "single-method-classes" "$single_method_classes classes with ≤2 methods — use plain functions instead"
fi

# Empty/pass-through files
empty_files=$(find "$SRC" -type f \( -name "*.ts" -o -name "*.js" \) 2>/dev/null | grep -v node_modules | grep -v test | while read -r f; do
  lines=$(grep -cv "^$\|^//\|^/\*\|^\*\|^import\|^export" "$f" 2>/dev/null || true)
  [[ ${lines:-0} -le 2 ]] && echo "$f"
done | wc -l | tr -d ' ')
if [[ ${empty_files:-0} -gt 5 ]]; then
  findings_add "info" "." "empty-files" "$empty_files files with ≤2 lines of logic — likely boilerplate or unnecessary wrappers"
fi

# ═══ 6. STALE BOILERPLATE — wrong tooling for this project ═══

# Webpack config in a Vite project
if grep -q '"vite"' "$REPO/package.json" 2>/dev/null; then
  if [[ -f "$REPO/webpack.config.js" || -f "$REPO/webpack.config.ts" ]]; then
    findings_add "warning" "." "stale-webpack" "Webpack config in a Vite project — remove webpack, it's not used"
  fi
fi

# CRA patterns in Next.js
if grep -q '"next"' "$REPO/package.json" 2>/dev/null; then
  if grep -q '"react-scripts"' "$REPO/package.json" 2>/dev/null; then
    findings_add "warning" "." "stale-cra" "react-scripts in a Next.js project — remove CRA dependency"
  fi
  # BrowserRouter in Next.js (should use next/navigation)
  if grep -rq "BrowserRouter\|react-router" "$SRC" --include="*.tsx" --include="*.ts" 2>/dev/null; then
    findings_add "warning" "." "stale-router" "react-router in Next.js — use next/navigation and file-based routing"
  fi
fi

# Express in a NestJS project
if grep -q '"@nestjs/core"' "$REPO/package.json" 2>/dev/null; then
  if grep -rq "app\.get(\|app\.post(\|app\.use(" "$SRC" --include="*.ts" 2>/dev/null | grep -v node_modules | grep -qv "test"; then
    findings_add "info" "." "raw-express-in-nest" "Raw Express patterns in NestJS — use @Controller decorators"
  fi
fi

# ═══ 7. CONSOLE.LOG LEFT IN CODE ═══
console_logs=$(grep -rn "console\.log\|console\.debug\|console\.info" "$SRC" --include="*.ts" --include="*.tsx" --include="*.js" 2>/dev/null | grep -v node_modules | grep -v test | grep -v "logger\|debug\|\.config" | wc -l | tr -d ' ')
if [[ ${console_logs:-0} -gt 15 ]]; then
  findings_add "info" "." "console-log-pollution" "$console_logs console.log statements — use a proper logger or remove before production"
fi

# ═══ 8. TODO/FIXME/HACK density ═══
todos=$(grep -rn "TODO\|FIXME\|HACK\|XXX\|TEMP\|WORKAROUND" "$SRC" --include="*.ts" --include="*.tsx" --include="*.js" 2>/dev/null | grep -v node_modules | grep -v test | wc -l | tr -d ' ')
if [[ ${todos:-0} -gt 20 ]]; then
  findings_add "info" "." "high-todo-density" "$todos TODO/FIXME/HACK comments — technical debt accumulating"
fi

echo ""
echo "  AI quality check complete."
