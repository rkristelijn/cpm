#!/usr/bin/env bash
# checks/javascript/nestjs/check-nestjs-advanced.sh
# NestJS advanced anti-patterns: ValidationPipe, DTOs, exception filters, rate limiting
set -o nounset -o pipefail

REPO="${1:-.}"
[ -f "$REPO/package.json" ] && grep -q '"@nestjs/core"' "$REPO/package.json" || exit 0

findings_add() { printf "  %-8s %-28s %s\n" "$1" "$3" "$4"; }

SRC=""
[ -d "$REPO/src" ] && SRC="$REPO/src/"
[ -d "$REPO/apps" ] && SRC="$SRC $REPO/apps/"
[ -z "$SRC" ] && exit 0

# No ValidationPipe globally registered
while IFS= read -r file; do
  if grep -qE "main\.ts" "$file" 2>/dev/null; then
    if ! grep -qE "ValidationPipe" "$file" 2>/dev/null; then
      findings_add "warning" "nestjs-no-validation-pipe" "No ValidationPipe globally registered" \
        "Add app.useGlobalPipes(new ValidationPipe()) in main.ts" \
        "https://docs.nestjs.com/techniques/validation"
    fi
  fi
done < <(find $REPO -name "main.ts" 2>/dev/null)

# Missing class-validator decorators on DTOs
while IFS= read -r file; do
  if grep -qE "class\s+\w+Dto" "$file" 2>/dev/null && ! grep -qE "@IsString|@IsNumber|@IsEmail|@Min|@Max|@IsOptional" "$file" 2>/dev/null; then
    findings_add "warning" "nestjs-dto-no-validation" "DTO without class-validator decorators" \
      "Add @IsString(), @IsEmail(), etc. decorators to DTO properties" \
      "https://docs.nestjs.com/techniques/validation#using-the-decorator"
  fi
done < <(find $SRC -name "*.ts" 2>/dev/null)

# No exception filter (unhandled errors leak)
if ! grep -qE "ExceptionFilter|useGlobalFilters" "$SRC" 2>/dev/null; then
  findings_add "warning" "nestjs-no-exception-filter" "No exception filter found" \
    "Implement @Catch() ExceptionFilter for consistent error handling" \
    "https://docs.nestjs.com/exception-filters"
fi

# Circular dependency (forwardRef needed)
while IFS= read -r file; do
  if grep -qE "Circular dependency|cannot resolve" "$file" 2>/dev/null || grep -qE "@Injectable\(\).*forwardRef" "$file" 2>/dev/null; then
    findings_add "warning" "nestjs-circular-dep" "Potential circular dependency detected" \
      "Use @Inject(forwardRef(() => OtherService)) to resolve circular deps" \
      "https://docs.nestjs.com/fundamentals/circular-dependency"
  fi
done < <(find $SRC -name "*.ts" 2>/dev/null)

# No rate limiting (ThrottlerGuard)
if ! grep -qE "ThrottlerModule|ThrottlerGuard" "$SRC" 2>/dev/null; then
  findings_add "warning" "nestjs-no-rate-limit" "No rate limiting configured" \
    "Add ThrottlerModule for API rate limiting" \
    "https://docs.nestjs.com/security/rate-limiting"
fi

# Repository injected in controller (should be in service)
while IFS= read -r file; do
  if grep -qE "@Controller" "$file" 2>/dev/null && grep -qE "@Injectable.*Repository" "$file" 2>/dev/null; then
    findings_add "warning" "nestjs-repo-in-controller" "Repository injected in controller" \
      "Inject repository in service, not controller. Controller should call service" \
      "https://docs.nestjs.com/recipes/crud#create-the-service"
  fi
done < <(find $SRC -name "*.ts" 2>/dev/null)

# No health check endpoint
if ! grep -qE "@Get.*health|@Get.*live|@Get.*ready" "$SRC" 2>/dev/null; then
  findings_add "warning" "nestjs-no-health-check" "No health check endpoint found" \
    "Add /health endpoint using @nestjs/terminus" \
    "https://docs.nestjs.com/recipes/terminus"
fi

# Missing Swagger/OpenAPI decorators
if ! grep -qE "@ApiTags|@ApiOperation|@ApiResponse" "$SRC" 2>/dev/null; then
  findings_add "warning" "nestjs-no-swagger" "No Swagger/OpenAPI decorators found" \
    "Add @ApiTags(), @ApiOperation() for API documentation" \
    "https://docs.nestjs.com/openapi/introduction"
fi

# Hardcoded CORS origin
while IFS= read -r file; do
  if grep -qE "origin:\s*['\"][^*]+['\"]" "$file" 2>/dev/null && ! grep -qE "process\.env|NODE_ENV" "$file" 2>/dev/null; then
    findings_add "warning" "nestjs-hardcoded-cors" "Hardcoded CORS origin" \
      "Use environment variable for CORS origin: origin: process.env.CORS_ORIGIN" \
      "https://docs.nestjs.com/security/cors"
  fi
done < <(find $REPO -name "*.ts" 2>/dev/null | grep -v node_modules)

# No ConfigService usage (hardcoded env)
while IFS= read -r file; do
  if grep -qE "process\.env\.[A-Z_]+" "$file" 2>/dev/null && ! grep -qE "ConfigService" "$file" 2>/dev/null; then
    findings_add "warning" "nestjs-no-config-service" "Direct process.env access instead of ConfigService" \
      "Use private readonly configService = inject(ConfigService)" \
      "https://docs.nestjs.com/techniques/configuration"
  fi
done < <(find $SRC -name "*.ts" 2>/dev/null)

echo "  ✓ NestJS advanced patterns checked"