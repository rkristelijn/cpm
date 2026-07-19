#!/usr/bin/env bash
# checks/javascript/check-api-patterns.sh
# @see ADR-129
# API route patterns, data fetching discipline, SSR correctness, security hygiene
set -o nounset -o pipefail

REPO="${1:-.}"
[ -f "$REPO/package.json" ] || exit 0

FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }
error()   { printf "  \033[31merror\033[0m    %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

SRC=""
[ -d "$REPO/src" ] && SRC="$REPO/src"
[ -d "$REPO/app" ] && SRC="${SRC:+$SRC }$REPO/app"
[ -z "$SRC" ] && exit 0

IS_NEXTJS=$(grep -q '"next"' "$REPO/package.json" 2>/dev/null && echo 1 || echo 0)

# =============================================
# API ROUTE PATTERNS
# =============================================

# 1. Route handler without input validation
ROUTES=$(find $SRC -name "route.ts" -o -name "route.tsx" 2>/dev/null | grep -v node_modules || true)
if [ -n "$ROUTES" ]; then
  NO_VALIDATE=$(echo "$ROUTES" | xargs grep -L "zod\|z\.\|validate\|schema\|parse(" 2>/dev/null | head -1 || true)
  [ -n "$NO_VALIDATE" ] && finding "api-no-validation" "Route handler without input validation — use zod schema"
fi

# 2. Route handler without proper error responses
if [ -n "$ROUTES" ]; then
  NO_ERROR=$(echo "$ROUTES" | xargs grep -L "status.*4\|status.*5\|NextResponse.*4\|NextResponse.*5" 2>/dev/null | head -1 || true)
  [ -n "$NO_ERROR" ] && finding "api-no-error-response" "Route handler only returns success — handle and return 4xx/5xx errors"
fi

# 3. Route handler leaking stack traces
if echo "$ROUTES" | xargs grep -n "error\.message\|error\.stack\|JSON.stringify.*error" 2>/dev/null | grep -v node_modules | head -1 | grep -q . 2>/dev/null; then
  finding "api-leaks-error" "Error details returned to client — return generic message, log server-side"
fi

# 4. No rate limiting on API routes
if [ -n "$ROUTES" ]; then
  if ! grep -rq "rateLimit\|rate-limit\|upstash\|bottleneck" $SRC --include="*.ts" 2>/dev/null; then
    finding "api-no-rate-limit" "No rate limiting on API routes — vulnerable to abuse"
  fi
fi

# 5. GET handler that mutates data
if [ -n "$ROUTES" ]; then
  GET_MUTATE=$(echo "$ROUTES" | xargs grep -l "export.*GET" 2>/dev/null | \
    xargs grep -l "delete\|update\|insert\|create\|push\|write" 2>/dev/null | head -1 || true)
  [ -n "$GET_MUTATE" ] && error "api-get-mutates" "GET handler appears to mutate data — use POST/PUT/DELETE"
fi

# 6. Route handler without Content-Type header
if [ -n "$ROUTES" ]; then
  if echo "$ROUTES" | xargs grep -n "new Response(" 2>/dev/null | grep -v "NextResponse\|json\|Content-Type" | head -1 | grep -q . 2>/dev/null; then
    finding "api-no-content-type" "Response without Content-Type — clients may misparse the response"
  fi
fi

# =============================================
# DATA FETCHING DISCIPLINE
# =============================================

# 7. fetch() without timeout (hangs forever)
if grep -rn "fetch(" $SRC --include="*.ts" --include="*.tsx" 2>/dev/null | grep -v node_modules | grep -v "AbortController\|signal\|timeout" | head -1 | grep -q .; then
  finding "fetch-no-timeout" "fetch() without AbortController/timeout — can hang indefinitely"
fi

# 8. Data fetching in useEffect instead of RSC/RQ
if grep -rn "useEffect.*fetch(\|useEffect.*axios" $SRC --include="*.tsx" 2>/dev/null | grep -v node_modules | head -1 | grep -q .; then
  finding "effect-fetch" "Data fetching in useEffect — use Server Components or TanStack Query"
fi

# 9. Loading state managed manually with useState
if grep -rn "setLoading\|setIsLoading\|useState.*loading" $SRC --include="*.tsx" 2>/dev/null | grep -v node_modules | head -1 | grep -q .; then
  finding "manual-loading-state" "Manual loading state — use Suspense, useTransition, or TanStack Query isLoading"
fi

# 10. No loading indicator for async operations
if grep -rl "useMutation\|fetch(" $SRC --include="*.tsx" 2>/dev/null | grep -v node_modules | \
  xargs grep -L "Loading\|Spinner\|CircularProgress\|isPending\|isLoading\|Skeleton" 2>/dev/null | head -1 | grep -q . 2>/dev/null; then
  finding "no-loading-indicator" "Async operation without loading indicator — users don't know it's working"
fi

# =============================================
# SSR / HYDRATION
# =============================================

# 11. Date/time rendering without hydration guard
if grep -rn "new Date()\|Date.now()\|toLocaleString\|toLocaleDateString" $SRC --include="*.tsx" 2>/dev/null | grep -v node_modules | grep -v "useEffect\|useState\|mounted\|client" | head -1 | grep -q .; then
  finding "date-hydration" "Date rendering may cause hydration mismatch — wrap in useEffect or suppress"
fi

# 12. Math.random() in component render (hydration mismatch)
if grep -rn "Math.random()" $SRC --include="*.tsx" 2>/dev/null | grep -v node_modules | grep -v "useEffect\|useMemo\|useState\|useId" | head -1 | grep -q .; then
  finding "random-in-render" "Math.random() during render — causes hydration mismatch, use useId()"
fi

# 13. window/document access without typeof check
if grep -rn "window\.\|document\.\|localStorage\|sessionStorage" $SRC --include="*.tsx" --include="*.ts" 2>/dev/null | \
  grep -v node_modules | grep -v "typeof window\|typeof document\|useEffect\|'use client'" | head -1 | grep -q .; then
  finding "browser-api-raw" "Browser API without typeof guard — crashes during SSR"
fi

# =============================================
# SECURITY HYGIENE
# =============================================

# 14. Secrets in client code
if grep -rn "NEXT_PUBLIC.*SECRET\|NEXT_PUBLIC.*KEY\|NEXT_PUBLIC.*TOKEN\|NEXT_PUBLIC.*PASSWORD" $SRC --include="*.ts" --include="*.tsx" 2>/dev/null | grep -v node_modules | head -1 | grep -q .; then
  error "secret-in-public-env" "Secret in NEXT_PUBLIC_ env var — exposed to browser"
fi

# 15. dangerouslySetInnerHTML without sanitization
if grep -rn "dangerouslySetInnerHTML" $SRC --include="*.tsx" 2>/dev/null | grep -v node_modules | grep -v "DOMPurify\|sanitize\|dompurify\|isomorphic-dompurify" | head -1 | grep -q .; then
  error "xss-dangeroushtml" "dangerouslySetInnerHTML without DOMPurify — XSS vulnerability"
fi

# 16. eval() or Function() constructor
if grep -rn "eval(\|new Function(" $SRC --include="*.ts" --include="*.tsx" 2>/dev/null | grep -v node_modules | head -1 | grep -q .; then
  error "eval-usage" "eval()/new Function() — code injection risk"
fi

# 17. SQL/query string concatenation
if grep -rn "sql\`.*\${" $SRC --include="*.ts" 2>/dev/null | grep -v node_modules | head -1 | grep -q .; then
  finding "sql-interpolation" "Template literal in SQL — use parameterized queries"
fi

# 18. CORS wildcard in route handler
if grep -rn "Access-Control-Allow-Origin.*\*" $SRC --include="*.ts" 2>/dev/null | grep -v node_modules | head -1 | grep -q .; then
  finding "cors-wildcard" "CORS allows all origins — restrict to specific domains"
fi

# =============================================
# TESTING DISCIPLINE
# =============================================

# 19. No test files exist
TEST_COUNT=$(find $SRC -name "*.test.*" -o -name "*.spec.*" 2>/dev/null | grep -v node_modules | wc -l)
TEST_COUNT=$(echo "$TEST_COUNT" | tr -d ' ')
[ "${TEST_COUNT:-0}" -eq 0 ] && finding "no-tests" "No test files found — add unit tests"

# 20. Test file without assertions
if [ "${TEST_COUNT:-0}" -gt 0 ]; then
  NO_ASSERT=$(find $SRC -name "*.test.*" -o -name "*.spec.*" 2>/dev/null | grep -v node_modules | \
    xargs grep -L "expect\|assert\|should\|toBe\|toEqual\|toHave" 2>/dev/null | head -1 || true)
  [ -n "$NO_ASSERT" ] && finding "test-no-assertion" "Test file without assertions: $(basename "$NO_ASSERT")"
fi

# 21. Component without corresponding test
COMP_COUNT=$(find $SRC -name "*.tsx" -not -name "*.test.*" -not -name "*.spec.*" -not -path "*/node_modules/*" 2>/dev/null | wc -l)
COMP_COUNT=$(echo "$COMP_COUNT" | tr -d ' ')
if [ "${COMP_COUNT:-0}" -gt 0 ] && [ "${TEST_COUNT:-0}" -gt 0 ]; then
  RATIO=$((TEST_COUNT * 100 / COMP_COUNT))
  [ "$RATIO" -lt 30 ] && finding "low-test-coverage" "Only $RATIO% of components have tests — aim for >80%"
fi

# =============================================
# DEPENDENCY DISCIPLINE
# =============================================

# 22. Moment.js (deprecated, huge bundle)
if grep -q "\"moment\"" "$REPO/package.json" 2>/dev/null; then
  finding "dep-moment" "moment.js is deprecated and 300kb — use date-fns or dayjs"
fi

# 23. lodash full import (should use lodash-es or individual)
if grep -rn "from 'lodash'\|require('lodash')" $SRC --include="*.ts" --include="*.tsx" 2>/dev/null | grep -v node_modules | head -1 | grep -q .; then
  finding "dep-lodash-full" "Full lodash import (70kb) — use lodash-es or import individual functions"
fi

# 24. axios when fetch is sufficient (unnecessary dep)
if grep -q "\"axios\"" "$REPO/package.json" 2>/dev/null; then
  if [ "$IS_NEXTJS" = "1" ]; then
    finding "dep-axios-nextjs" "axios in Next.js — native fetch is enhanced with caching, axios bypasses it"
  fi
fi

# 25. Multiple state management libs
STATE_LIBS=0
grep -q "redux\|@reduxjs" "$REPO/package.json" 2>/dev/null && STATE_LIBS=$((STATE_LIBS+1))
grep -q "zustand" "$REPO/package.json" 2>/dev/null && STATE_LIBS=$((STATE_LIBS+1))
grep -q "jotai" "$REPO/package.json" 2>/dev/null && STATE_LIBS=$((STATE_LIBS+1))
grep -q "recoil" "$REPO/package.json" 2>/dev/null && STATE_LIBS=$((STATE_LIBS+1))
grep -q "mobx" "$REPO/package.json" 2>/dev/null && STATE_LIBS=$((STATE_LIBS+1))
[ "$STATE_LIBS" -gt 1 ] && finding "multiple-state-libs" "$STATE_LIBS state management libraries — pick one"

[ "$FINDINGS" -eq 0 ] && printf "  \033[32m✓\033[0m  API & security patterns: all checks passed\n"
exit 0
