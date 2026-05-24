#!/usr/bin/env bash
#
# check-obsolete-deps.sh — Warn when code uses packages that have native replacements.
#
# Powered by flupke audit data. Each finding includes the native alternative.
# These packages add weight, supply chain risk, and maintenance burden for zero benefit.
#
# @see https://github.com/rkristelijn/flupke

set -o nounset -o pipefail
findings_add() { printf "  %-8s %-30s %s\n" "$1" "$3" "$4"; }

REPO="${1:-.}"
[[ -f "$REPO/package.json" ]] || exit 0

# ═══ OBSOLETE: native replacement exists since Node 18 / ES2022 ═══
declare -A OBSOLETE=(
  [isarray]="Array.isArray() — native since ES5"
  [inherits]="class extends — native since ES6"
  [safe-buffer]="Buffer.from/alloc — native since Node 6"
  [function-bind]="Function.prototype.bind — native since ES5"
  [has-symbols]="typeof Symbol === 'function' — native since ES6"
  [has-flag]="process.argv.includes('--flag') — native"
  [path-is-absolute]="path.isAbsolute() — native since Node 0.11"
  [util-deprecate]="util.deprecate() — native since Node 0.8"
  [rimraf]="fs.rm({recursive:true}) — native since Node 14"
  [mkdirp]="fs.mkdir({recursive:true}) — native since Node 10"
  [concat-map]="Array.flatMap() — native since ES2019"
  [is-number]="typeof n === 'number' && isFinite(n)"
  [slash]="path.replace(/\\\\\\\\/g, '/') — one line"
  [is-plain-object]="Object.getPrototypeOf(v) === Object.prototype"
  [is-glob]="/[*?{}[\\\\]()]/.test(str) — one regex"
  [has-proto]="'__proto__' in {} — one expression"
  [hasown]="Object.hasOwn() — native since ES2022"
  [es-errors]="TypeError/RangeError etc — native since forever"
  [es-define-property]="Object.defineProperty — native since ES5"
  [gopd]="Object.getOwnPropertyDescriptor — native since ES5"
  [define-data-property]="Object.defineProperty — native since ES5"
  [set-function-length]="Object.defineProperty(fn,'length',{value:n})"
  [call-bind]="Function.prototype.call.bind() — native"
  [classnames]="[a,b&&'c'].filter(Boolean).join(' ') — one line"
  [path-exists]="fs.access() wrapped — 2 lines"
)

# ═══ HEAVY: lighter alternative exists ═══
declare -A HEAVY=(
  [lodash]="Use native Array/Object methods (or lodash-es for tree-shaking)"
  [moment]="Use date-fns (tree-shakeable) or native Intl.DateTimeFormat"
  [chalk]="Use picocolors (6x smaller, same API)"
  [request]="Use native fetch() — built into Node 18+"
  [underscore]="Use native Array/Object methods"
  [bluebird]="Use native Promise — no polyfill needed"
  [q]="Use native Promise + async/await"
  [async]="Use native async/await + Promise.all"
  [node-uuid]="Use crypto.randomUUID() — native since Node 19"
  [uuid]="Use crypto.randomUUID() — native since Node 19"
  [node-fetch]="Use native fetch() — built into Node 18+"
  [cross-fetch]="Use native fetch() — built into Node 18+"
  [axios]="Consider native fetch() — no dep needed for simple requests"
  [glob]="Use fs.glob() — native since Node 22 (or fast-glob)"
  [minimatch]="Use picomatch (faster, maintained)"
  [string-width]="@flupke/string-width — zero deps, same API"
  [strip-ansi]="@flupke/strip-ansi — zero deps, one regex"
  [wrap-ansi]="@flupke/wrap-ansi — zero deps"
  [yargs-parser]="@flupke/yargs-parser — zero deps, 16 LOC"
)

FOUND=0

# Check package.json dependencies
deps=$(cat "$REPO/package.json" | grep -o '"[^"]*":' | tr -d '":' | sort -u)

for pkg in "${!OBSOLETE[@]}"; do
  if echo "$deps" | grep -qx "$pkg"; then
    findings_add "warning" "package.json" "obsolete-dep:$pkg" "${OBSOLETE[$pkg]} — remove $pkg, use native"
    FOUND=$((FOUND + 1))
  fi
done

for pkg in "${!HEAVY[@]}"; do
  if echo "$deps" | grep -qx "$pkg"; then
    findings_add "info" "package.json" "heavy-dep:$pkg" "${HEAVY[$pkg]}"
    FOUND=$((FOUND + 1))
  fi
done

# Also check lockfile for transitive obsolete deps
if [[ -f "$REPO/package-lock.json" ]]; then
  for pkg in "${!OBSOLETE[@]}"; do
    if grep -q "\"node_modules/$pkg\"" "$REPO/package-lock.json" 2>/dev/null; then
      # Only warn if not already a direct dep (transitive = inherited)
      if ! echo "$deps" | grep -qx "$pkg"; then
        findings_add "info" "package-lock.json" "transitive-obsolete:$pkg" "Inherited via dependency — consider npm overrides: \"$pkg\": \"npm:@flupke/$pkg@^1.0.0\""
        FOUND=$((FOUND + 1))
      fi
    fi
  done
fi

if [[ $FOUND -eq 0 ]]; then
  echo "  ✓ No obsolete or unnecessarily heavy dependencies found"
fi
