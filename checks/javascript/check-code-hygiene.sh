#!/usr/bin/env bash
# checks/javascript/check-code-hygiene.sh
# @see ADR-129
# Code hygiene: anti-slop, file size discipline, naming, imports, consistency
set -o nounset -o pipefail

REPO="${1:-.}"
[ -f "$REPO/package.json" ] || exit 0

FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

SRC=""
[ -d "$REPO/src" ] && SRC="$REPO/src"
[ -d "$REPO/app" ] && SRC="${SRC:+$SRC }$REPO/app"
[ -z "$SRC" ] && exit 0

# 1. Component file >200 lines (split it)
LARGE=$(find $SRC -name "*.tsx" -not -path "*/node_modules/*" -exec wc -l {} \; 2>/dev/null | awk '$1 > 200 {print $2}' | head -1 || true)
[ -n "$LARGE" ] && finding "file-too-large" "$(basename "$LARGE") exceeds 200 lines — split into smaller components"

# 2. More than 5 useState in one component
MANY_STATE=$(grep -rl "useState" $SRC --include="*.tsx" 2>/dev/null | grep -v node_modules | while read -r f; do
  COUNT=$(grep -c "useState" "$f" 2>/dev/null)
  [ "${COUNT:-0}" -gt 5 ] && echo "$f" && break
done | head -1)
[ -n "${MANY_STATE:-}" ] && finding "too-many-usestate" ">5 useState in $(basename "$MANY_STATE") — use useReducer or extract custom hook"

# 3. Console.log left in code
if grep -rn "console\.\(log\|debug\|info\)" $SRC --include="*.tsx" --include="*.ts" 2>/dev/null | grep -v node_modules | grep -v "//.*console\|test\|spec" | head -1 | grep -q .; then
  finding "console-left-in" "console.log in source — remove or replace with proper logger"
fi

# 4. TODO/FIXME/HACK in source (technical debt)
TODO_COUNT=$(grep -rn "TODO\|FIXME\|HACK\|XXX" $SRC --include="*.tsx" --include="*.ts" 2>/dev/null | grep -v node_modules | wc -l)
TODO_COUNT=$(echo "$TODO_COUNT" | tr -d ' ')
[ "${TODO_COUNT:-0}" -gt 5 ] && finding "excessive-todos" "$TODO_COUNT TODO/FIXME markers — address or create issues"

# 5. any type usage in TypeScript
if grep -rn ": any\b\|as any\b\|<any>" $SRC --include="*.ts" --include="*.tsx" 2>/dev/null | grep -v node_modules | grep -v "// eslint-disable\|test\|spec\|\.d\.ts" | head -1 | grep -q .; then
  finding "typescript-any" "'any' type used — defeats TypeScript's purpose, use unknown or specific type"
fi

# 6. Non-null assertion (!) overuse
BANG_COUNT=$(grep -rn "[a-zA-Z]\!" $SRC --include="*.ts" --include="*.tsx" 2>/dev/null | grep -v node_modules | grep -v "!=" | wc -l)
BANG_COUNT=$(echo "$BANG_COUNT" | tr -d ' ')
[ "${BANG_COUNT:-0}" -gt 10 ] && finding "non-null-assertion" "$BANG_COUNT non-null assertions (!) — handle null cases properly"

# 7. Nested ternaries (unreadable)
if grep -rn "?.*?.*:" $SRC --include="*.tsx" 2>/dev/null | grep -v node_modules | grep "?.*?.*?.*:" | head -1 | grep -q .; then
  finding "nested-ternary" "Nested ternary — extract to variable or use if/else for readability"
fi

# 8. Magic numbers (bare numbers > 1 in logic)
if grep -rn "=== [2-9][0-9]*\|> [2-9][0-9]*\|< [2-9][0-9]*" $SRC --include="*.tsx" --include="*.ts" 2>/dev/null | grep -v node_modules | grep -v "test\|spec\|\.length\|status\|port\|timeout\|1000\|60\|24\|365" | head -1 | grep -q .; then
  finding "magic-number" "Magic number in logic — extract to named constant"
fi

# 9. Default export mixed with named exports
if grep -rl "export default" $SRC --include="*.tsx" --include="*.ts" 2>/dev/null | grep -v node_modules | \
  xargs grep -l "export const\|export function\|export interface" 2>/dev/null | head -1 | grep -q .; then
  finding "mixed-exports" "Mixed default + named exports — pick one style per file"
fi

# 10. Barrel files (index.ts re-exporting everything)
BARRELS=$(find $SRC -name "index.ts" -not -path "*/node_modules/*" 2>/dev/null | xargs grep -l "export \*" 2>/dev/null | wc -l)
BARRELS=${BARRELS:-0}
[ "$BARRELS" -gt 3 ] && finding "barrel-files" "$BARRELS barrel re-export files — hurts tree-shaking and build speed"

# 11. Relative imports going up 3+ levels
if grep -rn "from '\.\./\.\./\.\.\|from \"\.\./\.\./\.\." $SRC --include="*.tsx" --include="*.ts" 2>/dev/null | grep -v node_modules | head -1 | grep -q .; then
  finding "deep-relative-import" "Import goes up 3+ levels (../../..) — use path alias @/"
fi

# 12. Unused imports (imported but not used in file)
# Heuristic: import { X } but X not found elsewhere in file
# Skip — too complex for shell, rely on eslint/tsc

# 13. Event handler not named handle* or on*
if grep -rn "onClick={[a-z]" $SRC --include="*.tsx" 2>/dev/null | grep -v node_modules | grep -v "onClick={handle\|onClick={on\|onClick={() =>\|onClick={props\.\|onClick={toggle\|onClick={set\|onClick={open\|onClick={close\|onClick={nav" | head -1 | grep -q .; then
  finding "handler-naming" "Event handler not named handle*/on* — follow React naming conventions"
fi

# 14. Hardcoded API URLs
HTTP_PATTERN='fetch.*http://\|fetch.*https://\|axios.*http'
if grep -rn "$HTTP_PATTERN" $SRC --include="*.tsx" --include="*.ts" 2>/dev/null | grep -v node_modules | grep -v "test\|spec\|mock\|localhost" | head -1 | grep -q .; then
  finding "hardcoded-api-url" "Hardcoded API URL — use environment variable or config"
fi

# 15. No error boundary around lazy-loaded components
if grep -rn "React.lazy\|dynamic(" $SRC --include="*.tsx" 2>/dev/null | grep -v node_modules | head -1 | grep -q .; then
  if ! grep -rq "Suspense\|ErrorBoundary" $SRC --include="*.tsx" 2>/dev/null; then
    finding "lazy-no-boundary" "Lazy/dynamic component without Suspense/ErrorBoundary — will crash on load failure"
  fi
fi

# 16. useEffect with object/array dependency (infinite loop risk)
if grep -rn "useEffect.*\[.*{.*}\|useEffect.*\[.*\[" $SRC --include="*.tsx" 2>/dev/null | grep -v node_modules | head -1 | grep -q .; then
  finding "effect-object-dep" "Object/array in useEffect deps — creates new reference each render, use useMemo"
fi

# 17. Spreading props blindly ({...props} on DOM element)
if grep -rn "{\.\.\.props}" $SRC --include="*.tsx" 2>/dev/null | grep -v node_modules | head -1 | grep -q .; then
  finding "spread-props-dom" "Spreading {...props} to DOM — passes unknown attributes, be explicit"
fi

# 18. String concatenation for className (use clsx/classnames)
if grep -rn "className={\`\|className={.*+" $SRC --include="*.tsx" 2>/dev/null | grep -v node_modules | grep -v "clsx\|classnames\|cx(" | head -1 | grep -q .; then
  finding "string-classname" "String concatenation for className — use clsx() for conditional classes"
fi

# 19. Async function without try/catch or .catch
ASYNC_NO_CATCH=$(grep -rl "async " $SRC --include="*.ts" --include="*.tsx" 2>/dev/null | grep -v node_modules | grep -v "test\|spec" | \
  xargs grep -L "try\|\.catch\|onError\|throwOnError" 2>/dev/null | head -1 || true)
[ -n "$ASYNC_NO_CATCH" ] && finding "async-no-catch" "async function without error handling in $(basename "$ASYNC_NO_CATCH")"

# 20. Env vars accessed without validation
if grep -rn "process\.env\.\|import\.meta\.env\." $SRC --include="*.ts" --include="*.tsx" 2>/dev/null | grep -v node_modules | grep -v "test\|spec\|\.d\.ts" | head -1 | grep -q .; then
  if ! grep -rq "z\.string\|z\.object\|joi\|yup\|env\.mjs\|env\.ts\|@t3-oss/env" $SRC --include="*.ts" --include="*.tsx" "$REPO/package.json" 2>/dev/null; then
    finding "env-no-validation" "process.env used without validation — use zod/t3-env for type-safe env"
  fi
fi

# 21. Component without display name (harder to debug)
ANON=$(grep -rn "export default function(" $SRC --include="*.tsx" 2>/dev/null | grep -v node_modules | head -1 || true)
[ -n "$ANON" ] && finding "anonymous-export" "Anonymous default export function — name it for better stack traces"

# 22. Duplicate dependency in package.json (same package in deps + devDeps)
if [ -f "$REPO/package.json" ]; then
  DUPES=$(node -e "const p=require('./$REPO/package.json');const d=Object.keys(p.dependencies||{});const v=Object.keys(p.devDependencies||{});const dup=d.filter(x=>v.includes(x));if(dup.length)console.log(dup.join(','))" 2>/dev/null || true)
  [ -n "$DUPES" ] && finding "duplicate-deps" "Package in both deps and devDeps: $DUPES"
fi

# 23. Missing strict mode in tsconfig
if [ -f "$REPO/tsconfig.json" ]; then
  if ! grep -q "\"strict\": true\|\"strict\":true" "$REPO/tsconfig.json" 2>/dev/null; then
    finding "tsconfig-no-strict" "tsconfig.json without strict: true — allows unsafe code"
  fi
fi

# 24. No .env.example (teammates don't know required vars)
if [ -f "$REPO/.env" ] || grep -rq "process\.env\.\|NEXT_PUBLIC_" $SRC --include="*.ts" --include="*.tsx" 2>/dev/null; then
  if [ ! -f "$REPO/.env.example" ] && [ ! -f "$REPO/.env.local.example" ]; then
    finding "no-env-example" "No .env.example — teammates can't set up without guessing env vars"
  fi
fi

# 25. package.json scripts missing common commands
if [ -f "$REPO/package.json" ]; then
  SCRIPTS=$(cat "$REPO/package.json" | grep -o '"scripts"' || true)
  if [ -n "$SCRIPTS" ]; then
    grep -q '"lint"' "$REPO/package.json" || finding "no-lint-script" "No 'lint' script in package.json"
    grep -q '"test"' "$REPO/package.json" || finding "no-test-script" "No 'test' script in package.json"
  fi
fi

# =============================================
# NAMING CONVENTIONS
# =============================================

# 26. Common abbreviations that should be full words
ABBREVS="btn\b\|mgr\b\|impl\b\|usr\b\|ctx\b\|cfg\b\|msg\b\|dlg\b\|tmp\b\|arr\b\|obj\b\|num\b\|str\b\|val\b\|elem\b\|idx\b"
if grep -rn "$ABBREVS" $SRC --include="*.ts" --include="*.tsx" 2>/dev/null | \
  grep -v node_modules | grep -v "test\|spec\|\.d\.ts\|// \|/\*\|import\|from " | head -1 | grep -q .; then
  finding "naming-abbreviation" "Abbreviated variable names (btn, mgr, ctx, etc) — use full descriptive words"
fi

# 27. Boolean without is/has/can/should prefix
if grep -rn ": boolean\|: Boolean" $SRC --include="*.ts" --include="*.tsx" 2>/dev/null | \
  grep -v node_modules | grep -v "is[A-Z]\|has[A-Z]\|can[A-Z]\|should[A-Z]\|was[A-Z]\|will[A-Z]\|did[A-Z]\|enabled\|disabled\|visible\|hidden\|loading\|open\|closed\|active\|selected\|checked\|required\|optional\|valid\|dirty" | \
  grep -v "test\|spec\|interface\|type " | head -1 | grep -q .; then
  finding "naming-boolean-prefix" "Boolean without is/has/can/should prefix — unclear if it's a flag or value"
fi

# 28. File name doesn't match default export
if [ -d "$REPO/src" ]; then
  MISMATCH=""
  for f in $(find $SRC -name "*.tsx" -not -path "*/node_modules/*" -not -name "page.tsx" -not -name "layout.tsx" -not -name "index.tsx" -not -name "loading.tsx" -not -name "error.tsx" -not -name "not-found.tsx" -not -name "template.tsx" -not -name "*.test.*" 2>/dev/null | head -10); do
    FILENAME=$(basename "$f" .tsx)
    EXPORT_NAME=$(grep -m1 "export default function\|export default class" "$f" 2>/dev/null | grep -oE "(function|class) [A-Z][a-zA-Z]+" | awk '{print $2}')
    if [ -n "$EXPORT_NAME" ] && [ "$FILENAME" != "$EXPORT_NAME" ]; then
      MISMATCH="$f ($FILENAME ≠ $EXPORT_NAME)"
      break
    fi
  done
  [ -n "$MISMATCH" ] && finding "naming-file-mismatch" "File doesn't match export: $MISMATCH"
fi

# 29. Commented-out code blocks (>3 consecutive commented lines that look like code)
if [ -d "$REPO/src" ]; then
  for f in $(find $SRC -name "*.ts" -o -name "*.tsx" 2>/dev/null | grep -v node_modules | head -20); do
    COMMENT_BLOCK=$(grep -n "^\s*//" "$f" 2>/dev/null | awk -F: '
      NR==1{prev=$1; start=$1; count=1; next}
      $1==prev+1{count++; prev=$1; next}
      {if(count>=4) print start"-"prev; start=$1; prev=$1; count=1}
      END{if(count>=4) print start"-"prev}
    ' | head -1 || true)
    if [ -n "$COMMENT_BLOCK" ]; then
      # Verify it looks like code (has = ; { } ( ) not just text)
      START=$(echo "$COMMENT_BLOCK" | cut -d- -f1)
      END=$(echo "$COMMENT_BLOCK" | cut -d- -f2)
      if sed -n "${START},${END}p" "$f" 2>/dev/null | grep -q "[=;{}()]"; then
        finding "commented-out-code" "Commented-out code block in $(basename "$f"):$COMMENT_BLOCK — delete or restore"
        break
      fi
    fi
  done
fi

[ "$FINDINGS" -eq 0 ] && printf "  \033[32m✓\033[0m  Code hygiene: all checks passed\n"
exit 0
