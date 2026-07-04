#!/usr/bin/env bash
# checks/php/laravel/check-laravel-security.sh
# @see ADR-148
# Laravel OWASP-aligned security: CORS, CSRF, headers, uploads, rate limiting
set -o nounset -o pipefail

REPO="${1:-.}"
grep -q "laravel/framework" "$REPO/composer.json" 2>/dev/null || exit 0

FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }
error()   { printf "  \033[31merror\033[0m    %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

PHP_FILES=$(find "$REPO" -name "*.php" -not -path "*/vendor/*" -not -path "*/node_modules/*" 2>/dev/null)
[ -z "$PHP_FILES" ] && exit 0

# --- 1. CORS wildcard ---
if grep -rq "CORS_ALLOW_ALL_ORIGINS.*true\|allow_all_origins.*true" "$REPO/config/" 2>/dev/null; then
  error "laravel-cors-wildcard" "CORS allows all origins — restrict to specific domains"
fi

# --- 2. Blade XSS: {!! !!} with user/request data ---
BLADE_FILES=$(find "$REPO" -name "*.blade.php" -not -path "*/vendor/*" 2>/dev/null)
if [ -n "$BLADE_FILES" ]; then
  echo "$BLADE_FILES" | xargs grep -ln "{!!" 2>/dev/null | head -3 | while IFS= read -r f; do
    finding "laravel-unescaped-blade" "$f: {!! !!} used — ensure no user input is rendered raw"
  done
fi

# --- 3. No rate limiting on auth routes ---
ROUTE_FILES=$(find "$REPO" -path "*/routes/*.php" 2>/dev/null | grep -v vendor)
if [ -n "$ROUTE_FILES" ]; then
  if echo "$ROUTE_FILES" | xargs grep -l "login\|register\|password" 2>/dev/null | \
     xargs grep -L "throttle\|RateLimiter\|ThrottleRequests" 2>/dev/null | head -1 | grep -q .; then
    finding "laravel-no-rate-limit" "Auth routes without throttle middleware — brute force risk"
  fi
fi

# --- 4. No security headers middleware ---
if ! grep -rq "Strict-Transport-Security\|HSTS\|spatie/laravel-csp\|SecureHeaders" "$REPO/config/" "$REPO/app/" 2>/dev/null; then
  finding "laravel-no-security-headers" "No HSTS/CSP headers configured — missing security headers"
fi

# --- 5. CSRF exceptions too broad ---
CSRF_FILE=$(find "$REPO" -path "*VerifyCsrfToken*" -o -path "*csrf*" 2>/dev/null | grep -v vendor | head -1)
if [ -n "$CSRF_FILE" ] && grep -q "'\*'" "$CSRF_FILE" 2>/dev/null; then
  error "laravel-csrf-wildcard" "CSRF protection disabled with wildcard — all routes unprotected"
fi

# --- 6. Unsafe file uploads ---
echo "$PHP_FILES" | xargs grep -ln "getClientOriginalName\|getClientOriginalExtension" 2>/dev/null | head -1 | grep -q . && \
  finding "laravel-unsafe-upload" "getClientOriginalName() used — attacker can control filename, use hashName()"

# --- 7. Session config insecure ---
if [ -f "$REPO/.env" ]; then
  grep -q "SESSION_SECURE_COOKIE=false" "$REPO/.env" 2>/dev/null && \
    finding "laravel-insecure-session" "SESSION_SECURE_COOKIE=false — cookies sent over HTTP"
fi
if grep -q "SESSION_DRIVER=file" "$REPO/.env" 2>/dev/null; then
  if grep -q "SESSION_SECURE_COOKIE=false\|^#.*SESSION_SECURE" "$REPO/.env" 2>/dev/null; then
    finding "laravel-session-config" "File sessions without secure cookies — consider Redis + HTTPS"
  fi
fi

# --- 8. No encryption for sensitive env values ---
if [ -f "$REPO/.env" ]; then
  grep -qE "^(STRIPE_SECRET|AWS_SECRET|MAILGUN_SECRET|PUSHER_APP_SECRET)=" "$REPO/.env" 2>/dev/null && \
    error "laravel-secrets-in-env" "Secrets in committed .env — use vault or encrypted env"
fi

# --- 9. Laravel version EOL (from composer.lock) ---
if [ -f "$REPO/composer.lock" ]; then
  LARAVEL_VER=$(grep -A2 '"name": "laravel/framework"' "$REPO/composer.lock" 2>/dev/null | grep '"version"' | grep -oE '[0-9]+\.[0-9]+' | head -1)
  if [ -n "$LARAVEL_VER" ]; then
    MAJOR=$(echo "$LARAVEL_VER" | cut -d. -f1)
    [ "$MAJOR" -le 10 ] && error "laravel-eol" "Laravel $LARAVEL_VER is EOL — upgrade to 12+"
    [ "$MAJOR" -eq 11 ] && finding "laravel-eol-soon" "Laravel 11 security support ends Mar 2026 — plan upgrade"
  fi
fi

# --- 10. Default admin route ---
if [ -n "$ROUTE_FILES" ]; then
  echo "$ROUTE_FILES" | xargs grep -q "Route.*admin.*without.*auth\|prefix.*admin" 2>/dev/null && \
    echo "$ROUTE_FILES" | xargs grep -l "prefix.*admin" 2>/dev/null | \
    xargs grep -L "middleware.*auth\|->middleware" 2>/dev/null | head -1 | grep -q . && \
    finding "laravel-admin-no-auth" "Admin routes without auth middleware"
fi

[ "$FINDINGS" -eq 0 ] && echo "  ✓ Laravel security OK"
exit 0
