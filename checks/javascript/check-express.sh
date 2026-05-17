#!/usr/bin/env bash
# checks/javascript/check-express.sh
# Express MVC best practices from product-domain services pattern
# Pattern: router → controller → service → repository (testable layers)
set -o nounset -o pipefail

REPO="${1:-.}"
[ -f "$REPO/package.json" ] && grep -q '"express"' "$REPO/package.json" || exit 0
# Skip if NestJS (has its own check)
grep -q "@nestjs" "$REPO/package.json" 2>/dev/null && exit 0

FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }
error()   { printf "  \033[31merror\033[0m    %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

SRC="$REPO/src"
[ -d "$SRC" ] || exit 0

# --- 1. No server hardening (x-powered-by disabled) ---
if ! grep -rq "disable.*x-powered-by\|helmet" "$SRC" --include="*.ts" --include="*.js" 2>/dev/null; then
  finding "express-no-hardening" "No x-powered-by disable or helmet — leaks framework info"
fi

# --- 2. Business logic in route handlers (fat routes) ---
ROUTE_FILES=$(find "$SRC" -name "*.router.ts" -o -name "*.routes.ts" -o -name "routes.ts" | grep -v node_modules 2>/dev/null)
if [ -n "$ROUTE_FILES" ]; then
  BAD=$(echo "$ROUTE_FILES" | xargs grep -l "\.find(\|\.save(\|\.create(\|\.delete(\|await.*Repository" 2>/dev/null | head -1 || true)
  [ -n "$BAD" ] && error "express-fat-routes" "DB/business logic in router — delegate to controller → service"
fi

# --- 3. No error handling middleware ---
if ! grep -rq "err.*req.*res.*next\|ErrorHandler\|handleAllErrors" "$SRC" --include="*.ts" --include="*.js" 2>/dev/null; then
  error "express-no-error-handler" "No centralized error handling middleware"
fi

# --- 4. Untyped req.body (no validation) ---
BAD=$(find "$SRC" -name "*.controller.ts" -o -name "*.ts" | grep -v node_modules | \
  xargs grep -l "req.body as\|req\.body\." 2>/dev/null | \
  xargs grep -L "validate\|schema\|isValid\|Joi\|zod\|class-validator" 2>/dev/null | head -1 || true)
[ -n "$BAD" ] && finding "express-no-validation" "req.body used without validation — add schema validation (Joi/Zod)"

# --- 5. console.log instead of logger ---
CTRL_SVC=$(find "$SRC" -name "*.controller.ts" -o -name "*.service.ts" | grep -v node_modules 2>/dev/null)
if [ -n "$CTRL_SVC" ]; then
  BAD=$(echo "$CTRL_SVC" | xargs grep -l "console\.\(log\|error\|warn\)" 2>/dev/null | wc -l | tr -d ' ')
  [ "$BAD" -gt 2 ] && finding "express-console-log" "console.log in $BAD files — use structured logger (pino/winston)"
fi

# --- 6. No health endpoint ---
if ! grep -rq "/health\|/healthz\|/ready" "$SRC" --include="*.ts" --include="*.js" 2>/dev/null; then
  finding "express-no-health" "No /health endpoint — orchestrators can't check liveness"
fi

# --- 7. No test files ---
TESTS=$(find "$SRC" -name "*.spec.ts" -o -name "*.test.ts" | grep -v node_modules | wc -l | tr -d ' ')
SRC_FILES=$(find "$SRC" -name "*.ts" -not -name "*.spec.ts" -not -name "*.test.ts" | grep -v node_modules | wc -l | tr -d ' ')
if [ "$SRC_FILES" -gt 5 ] && [ "$TESTS" -eq 0 ]; then
  finding "express-no-tests" "$SRC_FILES source files but no tests"
fi

# --- 8. Async route handlers without catch ---
if [ -n "$ROUTE_FILES" ]; then
  BAD=$(echo "$ROUTE_FILES" | xargs grep -l "async.*req.*res" 2>/dev/null | \
    xargs grep -L "\.catch\|try\|asyncHandler\|express-async" 2>/dev/null | head -1 || true)
  [ -n "$BAD" ] && error "express-unhandled-async" "Async route handler without .catch() — unhandled promise rejection crashes server"
fi

[ "$FINDINGS" -eq 0 ] && printf "  \033[32m✓\033[0m  Express patterns: all checks passed\n"
exit 0
