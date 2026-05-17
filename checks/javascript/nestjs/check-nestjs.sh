#!/usr/bin/env bash
# checks/javascript/nestjs/check-nestjs.sh
# NestJS RTFM patterns: controller separation, DI, DTOs, guards, config
# Source: learn.nestjs.com training patterns (stable since NestJS v7)
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../../lib/shell/init.sh" 2>/dev/null || true
cpm_check_enabled "js-nestjs" || exit 0
set -o nounset -o pipefail

REPO="${1:-.}"
[ -f "$REPO/package.json" ] && grep -q "@nestjs/core\|@nestjs/common" "$REPO/package.json" || exit 0

FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-35s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }
error()   { printf "  \033[31merror\033[0m    %-35s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

SRC="$REPO/src"
[ -d "$SRC" ] || exit 0

# --- 1. Business logic in controllers (array ops, DB calls) ---
CTRL_FILES=$(find "$SRC" -name "*.controller.ts" -not -path "*/node_modules/*" 2>/dev/null)
if [ -n "$CTRL_FILES" ]; then
  BAD=$(echo "$CTRL_FILES" | xargs grep -ln "\.find(\|\.filter(\|\.map(\|\.reduce(\|\.splice(\|\.push(\|\.save(\|\.delete(\|\.remove(\|\.update(" 2>/dev/null | grep -v "Service\|service" || true)
  [ -n "$BAD" ] && error "nestjs-controller-logic" "Business logic in controller — delegate to service"
fi

# --- 2. Untyped @Body() (no DTO) ---
if [ -n "$CTRL_FILES" ]; then
  BAD=$(echo "$CTRL_FILES" | xargs grep -n "@Body() body\b\|@Body() body:" 2>/dev/null | grep -v "Dto\|DTO" || true)
  [ -n "$BAD" ] && error "nestjs-untyped-body" "@Body() without DTO type — use CreateXxxDto/UpdateXxxDto"
fi

# --- 3. new Service() instead of DI ---
BAD=$(find "$SRC" -name "*.ts" -not -name "*.spec.ts" -not -name "*.test.ts" -not -path "*/node_modules/*" \
  -exec grep -ln "new [A-Z].*Service\|new [A-Z].*Repository\|new [A-Z].*Provider" {} \; 2>/dev/null || true)
[ -n "$BAD" ] && error "nestjs-no-di" "Manual instantiation (new Service) — use constructor injection"

# --- 4. synchronize: true without env guard ---
BAD=$(find "$SRC" -name "*.ts" -not -path "*/node_modules/*" \
  -exec grep -ln "synchronize.*true" {} \; 2>/dev/null || true)
if [ -n "$BAD" ]; then
  # Check if it's guarded by env check
  UNGUARDED=$(echo "$BAD" | xargs grep -L "process.env\|NODE_ENV\|configService\|ConfigService" 2>/dev/null || true)
  [ -n "$UNGUARDED" ] && error "nestjs-synchronize-prod" "synchronize: true without env guard — dangerous in production"
fi

# --- 5. process.env in services/controllers (use ConfigService) ---
SVC_CTRL=$(find "$SRC" -name "*.service.ts" -o -name "*.controller.ts" | grep -v node_modules 2>/dev/null)
if [ -n "$SVC_CTRL" ]; then
  BAD=$(echo "$SVC_CTRL" | xargs grep -ln "process\.env\." 2>/dev/null || true)
  [ -n "$BAD" ] && finding "nestjs-process-env" "Direct process.env in service/controller — use ConfigService"
fi

# --- 6. @Res() usage (platform-dependent) ---
if [ -n "$CTRL_FILES" ]; then
  BAD=$(echo "$CTRL_FILES" | xargs grep -ln "@Res()" 2>/dev/null || true)
  [ -n "$BAD" ] && finding "nestjs-res-decorator" "@Res() makes code platform-dependent — use NestJS response handling"
fi

# --- 7. Auth logic in middleware (should be Guards) ---
MW_FILES=$(find "$SRC" -name "*.middleware.ts" -not -path "*/node_modules/*" 2>/dev/null)
if [ -n "$MW_FILES" ]; then
  BAD=$(echo "$MW_FILES" | xargs grep -ln "authorization\|isAuthenticated\|jwt\|Bearer\|token" 2>/dev/null || true)
  [ -n "$BAD" ] && finding "nestjs-auth-in-middleware" "Auth logic in middleware — use @UseGuards() instead"
fi

# --- 8. console.log in controllers (use interceptors/logger) ---
if [ -n "$CTRL_FILES" ]; then
  BAD=$(echo "$CTRL_FILES" | xargs grep -ln "console\.\(log\|warn\|error\|time\)" 2>/dev/null || true)
  [ -n "$BAD" ] && finding "nestjs-console-in-ctrl" "console.log in controller — use Logger or interceptor"
fi

# --- 9. DTOs without class-validator decorators ---
DTO_FILES=$(find "$SRC" -name "*.dto.ts" -not -path "*/node_modules/*" 2>/dev/null)
if [ -n "$DTO_FILES" ]; then
  BAD=$(echo "$DTO_FILES" | xargs grep -L "@Is\|@Min\|@Max\|@Length\|@IsOptional\|@ValidateNested\|@Type\|@ApiProperty" 2>/dev/null || true)
  [ -n "$BAD" ] && error "nestjs-dto-no-validation" "DTO without validation decorators — add class-validator decorators"
fi

# --- 10. Missing module per feature (controller without co-located module) ---
CTRL_DIRS=$(echo "$CTRL_FILES" | xargs -I{} dirname {} 2>/dev/null | sort -u || true)
if [ -n "$CTRL_DIRS" ]; then
  for dir in $CTRL_DIRS; do
    [ "$dir" = "$SRC" ] && continue  # app root is fine
    if ! ls "$dir"/*.module.ts >/dev/null 2>&1; then
      finding "nestjs-missing-module" "Controller in $dir without co-located module"
      break
    fi
  done
fi

# --- 11. forRoot() with inline process.env (use forRootAsync) ---
BAD=$(find "$SRC" -name "*.module.ts" -not -path "*/node_modules/*" \
  -exec grep -ln "forRoot(" {} \; 2>/dev/null | \
  xargs grep -l "process\.env" 2>/dev/null || true)
[ -n "$BAD" ] && finding "nestjs-forroot-env" "forRoot() with process.env — use forRootAsync() to avoid race conditions"

# --- 12. No rate limiting (@nestjs/throttler) ---
if ! grep -q "@nestjs/throttler" "$REPO/package.json" 2>/dev/null; then
  finding "nestjs-no-rate-limit" "No @nestjs/throttler — API vulnerable to brute force/DoS"
fi

# --- 13. CORS wildcard in production ---
BAD=$(find "$SRC" -name "main.ts" -not -path "*/node_modules/*" \
  -exec grep -ln "origin.*\*\|origin.*true" {} \; 2>/dev/null | \
  grep -v "development\|NODE_ENV" || true)
[ -n "$BAD" ] && error "nestjs-cors-wildcard" "CORS origin: '*' or true without env guard — insecure in production"

# --- 14. No Helmet (security headers) ---
if ! grep -q "helmet" "$REPO/package.json" 2>/dev/null; then
  finding "nestjs-no-helmet" "No helmet package — missing security headers (X-Frame-Options, etc.)"
fi

# --- 15. Circular dependency (forwardRef usage = smell) ---
FWDREF=$(find "$SRC" -name "*.ts" -not -path "*/node_modules/*" \
  -exec grep -ln "forwardRef" {} \; 2>/dev/null | wc -l | tr -d ' ')
[ "$FWDREF" -gt 2 ] && finding "nestjs-circular-deps" "Multiple forwardRef() usages ($FWDREF) — refactor circular dependencies"

# --- 16. Entity exposed directly from controller (no response DTO) ---
if [ -n "$CTRL_FILES" ]; then
  BAD=$(echo "$CTRL_FILES" | xargs grep -ln "\.entity\b\|Entity}" 2>/dev/null | head -1 || true)
  [ -n "$BAD" ] && finding "nestjs-entity-in-ctrl" "Entity imported in controller — use response DTOs to avoid leaking internal fields"
fi

# --- 17. No global ValidationPipe ---
MAIN_TS=$(find "$SRC" -maxdepth 1 -name "main.ts" -o -name "main.ts" 2>/dev/null | head -1)
[ -z "$MAIN_TS" ] && MAIN_TS="$REPO/src/main.ts"
if [ -f "$MAIN_TS" ] && ! grep -q "ValidationPipe\|validationPipe" "$MAIN_TS" 2>/dev/null; then
  error "nestjs-no-validation-pipe" "No global ValidationPipe in main.ts — DTOs won't validate at runtime"
fi

# --- 18. Raw SQL in services (outside migrations) ---
SVC_FILES=$(find "$SRC" -name "*.service.ts" -not -path "*/node_modules/*" -not -path "*/migration*" 2>/dev/null)
if [ -n "$SVC_FILES" ]; then
  BAD=$(echo "$SVC_FILES" | xargs grep -ln "CREATE TABLE\|DROP TABLE\|ALTER TABLE\|raw(\|query(" 2>/dev/null | head -1 || true)
  [ -n "$BAD" ] && finding "nestjs-raw-sql" "Raw SQL in service — use TypeORM/Prisma methods or migrations"
fi

# --- 19. @Global() module overuse ---
GLOBALS=$(find "$SRC" -name "*.module.ts" -not -path "*/node_modules/*" \
  -exec grep -ln "@Global()" {} \; 2>/dev/null | wc -l | tr -d ' ')
[ "$GLOBALS" -gt 2 ] && finding "nestjs-global-overuse" "$GLOBALS @Global() modules — overuse pollutes DI scope"

# --- 20. No test files for services ---
SVC_COUNT=$(find "$SRC" -name "*.service.ts" -not -path "*/node_modules/*" 2>/dev/null | wc -l | tr -d ' ')
SPEC_COUNT=$(find "$SRC" -name "*.spec.ts" -o -name "*.test.ts" 2>/dev/null | grep -v node_modules | wc -l | tr -d ' ')
if [ "$SVC_COUNT" -gt 3 ] && [ "$SPEC_COUNT" -eq 0 ]; then
  finding "nestjs-no-tests" "$SVC_COUNT services but no test files — use @nestjs/testing"
fi

# --- Summary ---
if [ "$FINDINGS" -eq 0 ]; then
  printf "  \033[32m✓\033[0m  NestJS patterns: all checks passed\n"
fi
exit 0
