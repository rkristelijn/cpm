#!/usr/bin/env bash
# checks/javascript/nextjs/check-security.sh (extended)
# NextJS security best practices from automater/serverHardening + OWASP
# Source: https://github.com/rkristelijn/automater + OWASP Secure Headers
set -o nounset -o pipefail

REPO="${1:-.}"
[ -f "$REPO/package.json" ] && grep -q '"next"' "$REPO/package.json" || exit 0

FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }
error()   { printf "  \033[31merror\033[0m    %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

# Find next.config
NEXT_CFG=$(find "$REPO" -maxdepth 1 -name "next.config*" -not -path "*/node_modules/*" 2>/dev/null | head -1)

if [ -n "$NEXT_CFG" ]; then
  # --- poweredByHeader should be false ---
  grep -q "poweredByHeader.*false" "$NEXT_CFG" || \
    finding "next-powered-by" "poweredByHeader not disabled — leaks framework info"

  # --- Security headers (OWASP) ---
  grep -q "X-Frame-Options" "$NEXT_CFG" || \
    finding "next-no-xframe" "No X-Frame-Options header — clickjacking risk"

  grep -q "X-Content-Type-Options" "$NEXT_CFG" || \
    finding "next-no-nosniff" "No X-Content-Type-Options header — MIME sniffing risk"

  grep -q "Referrer-Policy" "$NEXT_CFG" || \
    finding "next-no-referrer" "No Referrer-Policy header — referrer leakage"

  grep -q "Content-Security-Policy" "$NEXT_CFG" || \
    finding "next-no-csp" "No Content-Security-Policy — XSS risk"

  grep -q "Permissions-Policy" "$NEXT_CFG" || \
    finding "next-no-permissions" "No Permissions-Policy — browser features unrestricted"
else
  finding "next-no-config" "No next.config found — using all defaults (no security headers)"
fi

# --- No biome/eslint/prettier (code quality) ---
if ! grep -q "biome\|eslint\|prettier" "$REPO/package.json" 2>/dev/null; then
  finding "next-no-linter" "No linter/formatter configured — inconsistent code quality"
fi

# --- Environment variables exposed to client ---
SRC="$REPO/src"
[ ! -d "$SRC" ] && SRC="$REPO/app"
if [ -d "$SRC" ]; then
  # Check for non-NEXT_PUBLIC_ env vars used in client components
  CLIENT_FILES=$(grep -rl "^'use client'\|^\"use client\"" "$SRC" --include="*.tsx" --include="*.ts" 2>/dev/null || true)
  if [ -n "$CLIENT_FILES" ]; then
    BAD=$(echo "$CLIENT_FILES" | xargs grep -l "process\.env\." 2>/dev/null | xargs grep "process\.env\." 2>/dev/null | grep -v "NEXT_PUBLIC_" | head -1 || true)
    [ -n "$BAD" ] && error "next-server-env-leak" "Server env var in 'use client' component — only NEXT_PUBLIC_ vars are safe"
  fi
fi

[ "$FINDINGS" -eq 0 ] && printf "  \033[32m✓\033[0m  NextJS security: all checks passed\n"
exit 0
