#!/usr/bin/env bash
# checks/python/fastapi/check-fastapi.sh
# @see ADR-148
# FastAPI security: CORS, auth, debug mode, exposed docs, rate limiting
set -o nounset -o pipefail

REPO="${1:-.}"
grep -rq "fastapi" "$REPO/requirements.txt" "$REPO/pyproject.toml" "$REPO/Pipfile" 2>/dev/null || exit 0

FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }
error()   { printf "  \033[31merror\033[0m    %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

PY_FILES=$(find "$REPO" -name "*.py" -not -path "*/.venv/*" -not -path "*/venv/*" -not -path "*/node_modules/*" 2>/dev/null)
[ -z "$PY_FILES" ] && exit 0

# --- 1. CORS wildcard ---
echo "$PY_FILES" | xargs grep -ln 'allow_origins.*\["\*"\]\|allow_origins=\["\*"\]' 2>/dev/null | head -1 | grep -q . && \
  error "fastapi-cors-wildcard" "CORSMiddleware allows all origins ['*'] — restrict to specific domains"

# --- 2. Debug/reload in Dockerfile ---
if [ -f "$REPO/Dockerfile" ]; then
  grep -q "\-\-reload" "$REPO/Dockerfile" 2>/dev/null && \
    error "fastapi-reload-prod" "--reload flag in Dockerfile — removes in production (auto-restarts, performance hit)"
fi
if [ -f "$REPO/docker-compose.yml" ]; then
  grep -q "\-\-reload" "$REPO/docker-compose.yml" 2>/dev/null && \
    error "fastapi-reload-prod" "--reload in docker-compose — remove for production"
fi

# --- 3. No authentication on routes ---
ROUTE_FILES=$(echo "$PY_FILES" | xargs grep -l "@app\.\|@router\." 2>/dev/null | grep -v test || true)
if [ -n "$ROUTE_FILES" ]; then
  HAS_AUTH=$(echo "$ROUTE_FILES" | xargs grep -l "Depends\|Security\|HTTPBearer\|OAuth2\|get_current_user\|api_key" 2>/dev/null | wc -l | tr -d ' ')
  TOTAL_ROUTE_FILES=$(echo "$ROUTE_FILES" | wc -l | tr -d ' ')
  if [ "$HAS_AUTH" -eq 0 ] && [ "$TOTAL_ROUTE_FILES" -gt 0 ]; then
    finding "fastapi-no-auth" "No authentication found on any route — add Depends() with auth"
  fi
fi

# --- 4. Exposed docs without auth ---
MAIN_FILES=$(echo "$PY_FILES" | xargs grep -l "FastAPI(" 2>/dev/null || true)
if [ -n "$MAIN_FILES" ]; then
  if ! echo "$MAIN_FILES" | xargs grep -q "docs_url=None\|openapi_url=None\|docs_url.*=.*None" 2>/dev/null; then
    finding "fastapi-docs-exposed" "/docs and /redoc are publicly accessible — disable or protect in production"
  fi
fi

# --- 5. No rate limiting ---
if ! grep -rq "slowapi\|ratelimit\|throttle\|RateLimiter" "$REPO/requirements.txt" "$REPO/pyproject.toml" 2>/dev/null; then
  if ! echo "$PY_FILES" | xargs grep -lq "RateLimiter\|Limiter\|throttle" 2>/dev/null; then
    finding "fastapi-no-rate-limit" "No rate limiting detected — vulnerable to abuse/DoS"
  fi
fi

# --- 6. No HTTPS redirect ---
if ! echo "$PY_FILES" | xargs grep -lq "HTTPSRedirectMiddleware\|ssl_redirect\|force_https" 2>/dev/null; then
  finding "fastapi-no-https-redirect" "No HTTPSRedirectMiddleware — HTTP traffic not redirected"
fi

# --- 7. Unsafe file upload (no size/type validation) ---
echo "$PY_FILES" | xargs grep -l "UploadFile" 2>/dev/null | while IFS= read -r f; do
  if ! grep -q "content_type\|MAX.*SIZE\|file\.size\|limit" "$f" 2>/dev/null; then
    finding "fastapi-unsafe-upload" "$f: UploadFile without size/type validation"
    break
  fi
done

# --- 8. SQL injection via f-strings ---
echo "$PY_FILES" | xargs grep -n 'execute.*f"\|execute.*f'"'" 2>/dev/null | head -1 | grep -q . && \
  error "fastapi-sql-injection" "SQL execute() with f-string — use parameterized queries"

[ "$FINDINGS" -eq 0 ] && echo "  ✓ FastAPI security OK"
exit 0
