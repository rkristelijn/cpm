#!/usr/bin/env bash
# checks/javascript/check-native-alternatives.sh
# @see ADR-129
# Detects usage of library functions that have native alternatives.
# With --fix: applies safe automatic replacements.
source "$(dirname "$0")/../../lib/shell/check.sh"

REPO="${1:-.}"
FIX=false
[[ "${2:-}" == "--fix" ]] && FIX=true

JS_FILES=$(find "$REPO" -type f \( -name "*.js" -o -name "*.ts" -o -name "*.jsx" -o -name "*.tsx" -o -name "*.mjs" \) \
  -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/dist/*" -not -path "*/build/*" 2>/dev/null)

[ -z "$JS_FILES" ] && exit 0

# === Safe auto-fixable patterns (1:1 replacements) ===
declare -A SAFE_FIXES=(
  ["_.isArray("]="Array.isArray("
  ["_.isNaN("]="Number.isNaN("
  ["_.isFinite("]="Number.isFinite("
  ["_.isInteger("]="Number.isInteger("
  ["_.keys("]="Object.keys("
  ["_.values("]="Object.values("
  ["_.entries("]="Object.entries("
  ["_.fromPairs("]="Object.fromEntries("
  ["_.assign("]="Object.assign("
  ["_.flatten("]="array.flat()"
  ["_.includes("]="array.includes("
  ["_.padStart("]="string.padStart("
  ["_.padEnd("]="string.padEnd("
  ["_.trim("]="string.trim()"
  ["_.repeat("]="string.repeat("
  ["_.startsWith("]="string.startsWith("
  ["_.endsWith("]="string.endsWith("
)

# === Detect-only patterns (need manual review) ===
declare -A DETECT_ONLY=(
  ["_.get("]="Use optional chaining: obj?.a?.b"
  ["_.set("]="No native 1:1 — consider manual refactor"
  ["_.cloneDeep("]="Use structuredClone()"
  ["_.uniq("]="Use [...new Set(array)]"
  ["_.uniqBy("]="Use Map or Set with custom key"
  ["_.groupBy("]="Use Object.groupBy() (ES2024)"
  ["_.debounce("]="No native — keep or use small util"
  ["_.throttle("]="No native — keep or use small util"
  ["_.merge("]="Use structuredClone() + Object.assign() or spread"
  ["_.pick("]="Use destructuring + rest"
  ["_.omit("]="Use destructuring + rest"
  ["_.chunk("]="Use Array.from({length: Math.ceil(arr.length/n)}, ...)"
  ["_.sortBy("]="Use array.toSorted() with comparator"
  ["_.find("]="Use array.find()"
  ["_.filter("]="Use array.filter()"
  ["_.map("]="Use array.map()"
  ["_.reduce("]="Use array.reduce()"
  ["_.some("]="Use array.some()"
  ["_.every("]="Use array.every()"
  ["_.forEach("]="Use array.forEach() or for...of"
  ["moment("]="Use Intl.DateTimeFormat or Temporal API"
  ["moment.duration"]="Use Intl.RelativeTimeFormat"
  [".fromNow("]="Use Intl.RelativeTimeFormat"
  ["require('axios')"]="Use native fetch()"
  ["from 'axios'"]="Use native fetch()"
  ["require('node-fetch')"]="Use native fetch() (Node 18+)"
  ["from 'node-fetch'"]="Use native fetch() (Node 18+)"
  ["require('uuid')"]="Use crypto.randomUUID()"
  ["from 'uuid'"]="Use crypto.randomUUID()"
  ["require('query-string')"]="Use URLSearchParams"
  ["from 'query-string'"]="Use URLSearchParams"
  ["require('deep-clone')"]="Use structuredClone()"
  ["require('rfdc')"]="Use structuredClone()"
)

# --- Check safe-fixable patterns ---
for pattern in "${!SAFE_FIXES[@]}"; do
  native="${SAFE_FIXES[$pattern]}"
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    if grep -qF "$pattern" "$file" 2>/dev/null; then
      linenum=$(grep -nF "$pattern" "$file" | head -1 | cut -d: -f1)
      if [ "$FIX" = true ]; then
        esc_pattern=$(printf '%s\n' "$pattern" | sed 's/[.[*^$()+?{}|\\]/\\&/g')
        esc_native=$(printf '%s\n' "$native" | sed 's/[&/\\]/\\&/g')
        sed -i '' "s|${esc_pattern}|${esc_native}|g" "$file" 2>/dev/null || sed -i "s|${esc_pattern}|${esc_native}|g" "$file" 2>/dev/null
        findings_add "pass" "$file:$linenum" "native-replace" "$pattern → $native"
      else
        findings_add "warning" "$file:$linenum" "use-native" "'$pattern' → $native"
      fi
    fi
  done <<< "$JS_FILES"
done

# --- Check detect-only patterns ---
for pattern in "${!DETECT_ONLY[@]}"; do
  suggestion="${DETECT_ONLY[$pattern]}"
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    if grep -qF "$pattern" "$file" 2>/dev/null; then
      linenum=$(grep -nF "$pattern" "$file" | head -1 | cut -d: -f1)
      findings_add "warning" "$file:$linenum" "prefer-native" "'$pattern' → $suggestion"
    fi
  done <<< "$JS_FILES"
done

# --- Summary (findings_finish handles exit via trap) ---
if [ "$FIX" = true ]; then
  echo "  Tip: use @flupkejs/* packages as drop-in replacements (same API, native internals)"
fi
