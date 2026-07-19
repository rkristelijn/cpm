#!/usr/bin/env bash
# checks/javascript/check-module-system.sh
# @see ADR-129
# ESM vs CommonJS: detect mixed modules, missing config, anti-patterns
set -o nounset -o pipefail

REPO="${1:-.}"
PKG="$REPO/package.json"
[ -f "$PKG" ] || exit 0

FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }
error()   { printf "  \033[31merror\033[0m    %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

SRC=""
[ -d "$REPO/src" ] && SRC="$REPO/src"
[ -d "$REPO/app" ] && SRC="${SRC:+$SRC }$REPO/app"
[ -z "$SRC" ] && exit 0

buf=$(cat "$PKG")
IS_ESM=$(echo "$buf" | grep -q '"type".*"module"' && echo 1 || echo 0)
IS_TS=$([ -f "$REPO/tsconfig.json" ] && echo 1 || echo 0)

# 1. require() in ESM project (will crash at runtime)
if [ "$IS_ESM" = "1" ]; then
  if grep -rn "\brequire(" $SRC --include="*.js" --include="*.mjs" 2>/dev/null | grep -v node_modules | grep -v "createRequire\|// " | head -1 | grep -q .; then
    error "esm-has-require" "require() in 'type: module' project — will crash. Use import or createRequire()"
  fi
fi

# 2. No "type" field in package.json (ambiguous, defaults to CJS)
if ! echo "$buf" | grep -q '"type"'; then
  if [ "$IS_TS" = "1" ] || grep -rq "^import \|^export " $SRC --include="*.js" 2>/dev/null; then
    finding "no-type-field" "No 'type' in package.json — add \"type\": \"module\" for ESM (recommended)"
  fi
fi

# 3. module.exports in TypeScript/ESM (should use export)
if grep -rn "module\.exports\|exports\." $SRC --include="*.ts" --include="*.tsx" 2>/dev/null | grep -v node_modules | grep -v "\.d\.ts\|// " | head -1 | grep -q .; then
  error "cjs-in-typescript" "module.exports in TypeScript — use export/export default"
fi

# 4. Mixed import and require in same file
MIXED=$(grep -rl "^import " $SRC --include="*.js" --include="*.ts" 2>/dev/null | \
  xargs grep -l "require(" 2>/dev/null | grep -v node_modules | grep -v "createRequire\|\.d\.ts" | head -1 || true)
[ -n "$MIXED" ] && finding "mixed-module-syntax" "Both import and require() in $(basename "$MIXED") — pick one module system"

# 5. Dynamic require() that could be import()
if grep -rn "require(" $SRC --include="*.ts" --include="*.tsx" --include="*.js" 2>/dev/null | grep -v node_modules | grep -v "\.d\.ts\|createRequire\|// " | head -1 | grep -q .; then
  if [ "$IS_TS" = "1" ]; then
    finding "require-in-ts" "require() in TypeScript project — use import (static) or import() (dynamic)"
  fi
fi

# 6. Default export + named exports in same file (confusing interop)
if grep -rl "export default" $SRC --include="*.ts" --include="*.tsx" 2>/dev/null | grep -v node_modules | \
  xargs grep -l "^export \(const\|function\|class\|interface\|type\)" 2>/dev/null | head -1 | grep -q . 2>/dev/null; then
  finding "mixed-export-style" "Default + named exports in same file — prefer named-only for clearer imports"
fi

# 7. Import without file extension in ESM Node (required in pure ESM)
if [ "$IS_ESM" = "1" ] && [ "$IS_TS" != "1" ]; then
  if grep -rn "from '\./\|from \"\.\/" $SRC --include="*.js" --include="*.mjs" 2>/dev/null | grep -v "\.\(js\|mjs\|json\)'" | grep -v node_modules | head -1 | grep -q .; then
    finding "esm-no-extension" "Import without .js extension in ESM — Node requires explicit extensions"
  fi
fi

# 8. __dirname/__filename in ESM (not available, use import.meta)
if [ "$IS_ESM" = "1" ]; then
  if grep -rn "__dirname\|__filename" $SRC --include="*.js" --include="*.mjs" 2>/dev/null | grep -v node_modules | head -1 | grep -q .; then
    error "esm-dirname" "__dirname/__filename not available in ESM — use import.meta.url + fileURLToPath()"
  fi
fi

# 9. tsconfig module setting mismatch
if [ "$IS_TS" = "1" ]; then
  TSCONFIG="$REPO/tsconfig.json"
  # Check if Next.js project (should use NodeNext or Bundler)
  if grep -q '"next"' "$PKG" 2>/dev/null; then
    if grep -q '"module".*"commonjs"\|"module".*"esnext"' "$TSCONFIG" 2>/dev/null; then
      finding "ts-module-mismatch" "tsconfig module should be 'NodeNext' or 'Bundler' for Next.js (not commonjs/esnext)"
    fi
  fi
fi

# 10. Barrel index.ts re-exporting everything (kills tree-shaking)
BARREL_COUNT=$(find $SRC -name "index.ts" -not -path "*/node_modules/*" 2>/dev/null | \
  xargs grep -l "export \*" 2>/dev/null | wc -l)
BARREL_COUNT=$(echo "$BARREL_COUNT" | tr -d ' ')
[ "${BARREL_COUNT:-0}" -gt 5 ] && finding "barrel-exports" "$BARREL_COUNT barrel files with 'export *' — kills tree-shaking, use explicit exports"

# 11. Side-effect imports without comment (import './style.css' is fine, but import './init' is suspicious)
if grep -rn "^import '\./\|^import \"\.\/" $SRC --include="*.ts" --include="*.tsx" 2>/dev/null | grep -v "\.css\|\.scss\|\.less\|// " | grep -v node_modules | head -1 | grep -q .; then
  finding "side-effect-import" "Side-effect import (import './file') — add comment explaining why, or use explicit exports"
fi

# 12. Top-level await without proper context
if grep -rn "^await \|^const.*= await " $SRC --include="*.ts" --include="*.js" 2>/dev/null | grep -v node_modules | grep -v "test\|spec" | head -1 | grep -q .; then
  if [ "$IS_ESM" != "1" ] && [ "$IS_TS" != "1" ]; then
    finding "top-level-await" "Top-level await requires ESM (\"type\": \"module\") or TypeScript"
  fi
fi

[ "$FINDINGS" -eq 0 ] && printf "  \033[32m✓\033[0m  Module system: all good\n"
exit 0
