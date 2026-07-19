#!/usr/bin/env bash
# checks/javascript/check-you-dont-need.sh
# @see ADR-129
# "You Don't Need" — detects packages with native/modern replacements.
# Sources:
# - https://github.com/you-dont-need/You-Dont-Need-Lodash-Underscore
# - https://github.com/you-dont-need/You-Dont-Need-Momentjs
# - Node.js native replacements (18+, 20+, 22+)
# - Deprecated/abandoned packages
set -o nounset -o pipefail

REPO="${1:-.}"
PKG="$REPO/package.json"
[ -f "$PKG" ] || exit 0

FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }
error()   { printf "  \033[31merror\033[0m    %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

buf=$(cat "$PKG")
SRC=""
[ -d "$REPO/src" ] && SRC="$REPO/src"
[ -d "$REPO/app" ] && SRC="${SRC:+$SRC }$REPO/app"

# =============================================
# DEPRECATED / DEAD PROJECTS (error — must remove)
# =============================================

# Build tools (superseded by npm scripts, vite, turbopack)
grep -q '"grunt"' "$PKG" 2>/dev/null && error "dead-grunt" "grunt is dead — use npm scripts or Makefile"
grep -q '"gulp"' "$PKG" 2>/dev/null && error "dead-gulp" "gulp is dead — use npm scripts or Makefile"
grep -q '"bower"' "$PKG" 2>/dev/null && error "dead-bower" "bower has been dead since 2017 — use npm"
grep -q '"browserify"' "$PKG" 2>/dev/null && error "dead-browserify" "browserify — use Vite, esbuild, or Webpack 5"

# HTTP clients (deprecated)
grep -q '"request"' "$PKG" 2>/dev/null && error "dead-request" "request is deprecated since 2020 — use native fetch()"
grep -q '"superagent"' "$PKG" 2>/dev/null && finding "dead-superagent" "superagent is unmaintained — use native fetch() or ky"

# Date/time
grep -q '"moment"' "$PKG" 2>/dev/null && error "dead-moment" "moment.js deprecated (300kb) — use date-fns (7kb), dayjs (2kb), or Intl API"
grep -q '"moment-timezone"' "$PKG" 2>/dev/null && error "dead-moment-tz" "moment-timezone deprecated — use Intl.DateTimeFormat with timeZone option"

# CSS preprocessors (for new projects)
grep -q '"node-sass"' "$PKG" 2>/dev/null && error "dead-node-sass" "node-sass deprecated — use sass (dart-sass) or CSS-in-JS/Tailwind"
grep -q '"less"' "$PKG" 2>/dev/null && finding "dead-less" "less is rarely used in modern stacks — consider CSS Modules or Tailwind"

# Utility belts
grep -q '"underscore"' "$PKG" 2>/dev/null && finding "dead-underscore" "underscore.js — use native ES6+ or lodash-es if needed"
grep -q '"jquery"' "$PKG" 2>/dev/null && error "dead-jquery" "jQuery in a React/Next.js project — use React refs and native DOM"

# Testing
grep -q '"istanbul"' "$PKG" 2>/dev/null && finding "dead-istanbul" "istanbul — renamed to nyc, or use vitest/c8 for coverage"
grep -q '"karma"' "$PKG" 2>/dev/null && finding "dead-karma" "karma test runner abandoned — use vitest or jest"
grep -q '"enzyme"' "$PKG" 2>/dev/null && error "dead-enzyme" "enzyme abandoned, doesn't support React 18+ — use @testing-library/react"

# =============================================
# NODE.JS NATIVE REPLACEMENTS (Node 18+)
# =============================================

# node-fetch → global fetch (Node 18+)
if grep -q '"node-fetch"' "$PKG" 2>/dev/null; then
  finding "native-fetch" "node-fetch — native fetch() available since Node 18 (global, no import needed)"
fi

# uuid → crypto.randomUUID (Node 19+)
if grep -q '"uuid"' "$PKG" 2>/dev/null; then
  if [ -n "$SRC" ] && grep -rq "v4\|uuidv4\|uuid()" $SRC --include="*.ts" --include="*.tsx" 2>/dev/null; then
    finding "native-uuid" "uuid package — use crypto.randomUUID() (native since Node 19)"
  fi
fi

# chalk → util.styleText (Node 21+)
if grep -q '"chalk"' "$PKG" 2>/dev/null; then
  finding "native-chalk" "chalk — use util.styleText() (native since Node 21) or keep for Node <21"
fi

# rimraf → fs.rm({ recursive: true }) (Node 14+)
if grep -q '"rimraf"' "$PKG" 2>/dev/null; then
  finding "native-rimraf" "rimraf — use fs.rm(path, { recursive: true, force: true }) (native since Node 14)"
fi

# mkdirp → fs.mkdir({ recursive: true }) (Node 10+)
if grep -q '"mkdirp"' "$PKG" 2>/dev/null; then
  finding "native-mkdirp" "mkdirp — use fs.mkdir(path, { recursive: true }) (native since Node 10)"
fi

# glob → fs.glob (Node 22+)
if grep -q '"glob"' "$PKG" 2>/dev/null; then
  finding "native-glob" "glob package — use fs.glob() (native since Node 22) or fast-glob"
fi

# dotenv → --env-file flag (Node 20.6+)
if grep -q '"dotenv"' "$PKG" 2>/dev/null; then
  finding "native-dotenv" "dotenv — use 'node --env-file=.env app.js' (native since Node 20.6)"
fi

# strip-ansi → util.stripVTControlCharacters (Node 16+)
if grep -q '"strip-ansi"' "$PKG" 2>/dev/null; then
  finding "native-strip-ansi" "strip-ansi — use util.stripVTControlCharacters() (native since Node 16)"
fi

# =============================================
# LODASH: YOU (PROBABLY) DON'T NEED IT
# =============================================

if grep -q '"lodash"' "$PKG" 2>/dev/null && [ -n "$SRC" ]; then
  # Check WHAT lodash functions are actually used
  LODASH_FUNCS=$(grep -rh "from 'lodash'\|_\.\|lodash\." $SRC --include="*.ts" --include="*.tsx" 2>/dev/null | \
    grep -oE '_\.[a-zA-Z]+\|lodash\.[a-zA-Z]+\|{ [a-zA-Z, ]+ }' | sort -u | head -10 || true)

  # Count unique lodash function usage
  USAGE_COUNT=$(grep -rn "from 'lodash\|_\.\|lodash\." $SRC --include="*.ts" --include="*.tsx" 2>/dev/null | grep -v node_modules | wc -l)
  USAGE_COUNT=$(echo "$USAGE_COUNT" | tr -d ' ')

  if [ "${USAGE_COUNT:-0}" -le 5 ]; then
    finding "lodash-for-few" "lodash used only $USAGE_COUNT times — copy the functions you need instead of 72kb dep"
  fi

  # Functions with trivial native equivalents
  if [ -n "$SRC" ]; then
    grep -rq "_.get\b\|lodash.*get\b" $SRC --include="*.ts" --include="*.tsx" 2>/dev/null && \
      finding "lodash-get" "_.get() — use optional chaining: obj?.a?.b?.c"
    grep -rq "_.isNil\|_.isNull\|_.isUndefined" $SRC --include="*.ts" --include="*.tsx" 2>/dev/null && \
      finding "lodash-isnil" "_.isNil/isNull/isUndefined — use value == null or value === undefined"
    grep -rq "_.map\b\|_.filter\b\|_.find\b\|_.reduce\b\|_.forEach\b" $SRC --include="*.ts" --include="*.tsx" 2>/dev/null && \
      finding "lodash-array-methods" "_.map/filter/find/reduce — use native array methods (ES5+)"
    grep -rq "_.includes\b" $SRC --include="*.ts" --include="*.tsx" 2>/dev/null && \
      finding "lodash-includes" "_.includes — use Array.includes() or String.includes() (ES6)"
    grep -rq "_.assign\b\|_.extend\b" $SRC --include="*.ts" --include="*.tsx" 2>/dev/null && \
      finding "lodash-assign" "_.assign/extend — use Object.assign() or spread { ...a, ...b }"
    grep -rq "_.keys\b\|_.values\b\|_.entries\b" $SRC --include="*.ts" --include="*.tsx" 2>/dev/null && \
      finding "lodash-object" "_.keys/values/entries — use Object.keys/values/entries (ES6)"
    grep -rq "_.flatten\b\|_.flatMap\b" $SRC --include="*.ts" --include="*.tsx" 2>/dev/null && \
      finding "lodash-flatten" "_.flatten/flatMap — use Array.flat()/flatMap() (ES2019)"
    grep -rq "_.uniq\b" $SRC --include="*.ts" --include="*.tsx" 2>/dev/null && \
      finding "lodash-uniq" "_.uniq — use [...new Set(array)] (ES6)"
    grep -rq "_.cloneDeep\b" $SRC --include="*.ts" --include="*.tsx" 2>/dev/null && \
      finding "lodash-clonedeep" "_.cloneDeep — use structuredClone() (Node 17+, all modern browsers)"
    grep -rq "_.isEmpty\b" $SRC --include="*.ts" --include="*.tsx" 2>/dev/null && \
      finding "lodash-isempty" "_.isEmpty — use !obj || Object.keys(obj).length === 0"
  fi
fi

# lodash full import instead of cherry-pick
if [ -n "$SRC" ]; then
  if grep -rn "from 'lodash'" $SRC --include="*.ts" --include="*.tsx" 2>/dev/null | grep -v "lodash/" | grep -v "lodash-es" | grep -v node_modules | head -1 | grep -q .; then
    finding "lodash-barrel-import" "import from 'lodash' (72kb) — use 'lodash-es' or 'lodash/specific-function'"
  fi
fi

# =============================================
# OTHER "YOU DON'T NEED" PATTERNS
# =============================================

# classnames/clsx for simple cases
if grep -q '"classnames"\|"clsx"' "$PKG" 2>/dev/null && [ -n "$SRC" ]; then
  CLSX_USES=$(grep -rn "clsx\|classnames\|cx(" $SRC --include="*.tsx" 2>/dev/null | grep -v node_modules | wc -l)
  CLSX_USES=$(echo "$CLSX_USES" | tr -d ' ')
  if [ "${CLSX_USES:-0}" -le 3 ]; then
    finding "clsx-for-few" "clsx/classnames used only $CLSX_USES times — use template literal: \`\${a} \${b && 'c'}\`"
  fi
fi

# is-* type checking packages (use typeof)
grep -q '"is-number"\|"is-string"\|"is-boolean"\|"is-array"\|"is-object"\|"is-function"' "$PKG" 2>/dev/null && \
  finding "native-typeof" "is-number/string/etc packages — use typeof or Array.isArray()"

# left-pad (infamously unnecessary)
grep -q '"left-pad"' "$PKG" 2>/dev/null && error "dead-leftpad" "left-pad — use String.padStart() (ES2017)"

# object-assign (polyfill for ES6)
grep -q '"object-assign"' "$PKG" 2>/dev/null && finding "native-object-assign" "object-assign — use Object.assign() or spread (native since ES6)"

# array-flatten
grep -q '"array-flatten"\|"flatten"' "$PKG" 2>/dev/null && finding "native-flatten" "array-flatten — use Array.flat() (ES2019)"

# promise polyfills
grep -q '"bluebird"\|"q"\|"promise-polyfill"' "$PKG" 2>/dev/null && \
  finding "native-promise" "Promise polyfill/library — native Promise available since Node 4/ES6"

# path-exists, fs-exists, path-is-absolute
grep -q '"path-exists"\|"fs-exists"\|"path-is-absolute"' "$PKG" 2>/dev/null && \
  finding "native-fs-exists" "path-exists/fs-exists — use fs.access() or fs.stat()"

# string-width (mostly for CLI tools, fine there)
# No warning — legitimate use in CLIs

[ "$FINDINGS" -eq 0 ] && printf "  \033[32m✓\033[0m  No unnecessary dependencies found\n"
exit 0
