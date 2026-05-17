#!/usr/bin/env bash
# checks/javascript/nextjs/check-security.sh
# Security: hardcoded secrets, unvalidated actions, env leaks, middleware
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../../lib/shell/init.sh" 2>/dev/null || true
cpm_check_enabled "nextjs-security" || exit 0
set -o nounset -o pipefail

REPO="${1:-.}"
[ -f "$REPO/package.json" ] && grep -q '"next"' "$REPO/package.json" || exit 0

FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }
error()   { printf "  \033[31merror\033[0m    %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

# Hardcoded secrets
cpm_grep -rn "sk_live\|sk_test\|ghp_\|gho_\|AKIA[A-Z0-9]" "$REPO/app/" "$REPO/src/" 2>/dev/null | \
  grep -v ".env" | head -1 | grep -q . && \
  error "hardcoded-secret" "Hardcoded secret/API key — use environment variables"

# Server env var in client component
CLIENT=$(cpm_grep -rl "'use client'\|\"use client\"" "$REPO/app/" "$REPO/src/" 2>/dev/null || true)
if [ -n "$CLIENT" ]; then
  echo "$CLIENT" | xargs grep -l "process\.env\." 2>/dev/null | \
    xargs grep "process\.env\." 2>/dev/null | grep -v "NEXT_PUBLIC" | head -1 | grep -q . && \
    error "secret-in-client" "Server env var in client component — will be undefined or leaked"
fi

# Server Actions without validation
ACTIONS=$(cpm_grep -rl "'use server'\|\"use server\"" "$REPO/app/" "$REPO/src/" 2>/dev/null || true)
if [ -n "$ACTIONS" ]; then
  echo "$ACTIONS" | xargs grep -L "zod\|yup\|validate\|parse\|safeParse\|schema\|auth\|session" 2>/dev/null | \
    head -1 | grep -q . && \
    finding "unvalidated-action" "Server Action without input validation — anyone can call with any data"
fi

# No server-only package
if [ -d "$REPO/src/lib" ] || [ -d "$REPO/app/lib" ] || [ -d "$REPO/lib" ]; then
  grep -q '"server-only"' "$REPO/package.json" || \
    finding "no-server-only" "No 'server-only' package — prevents accidental client import of server utils"
fi

# Middleware without matcher (runs on static assets)
MW=$(find "$REPO" -maxdepth 1 -name "middleware.*" 2>/dev/null | head -1)
if [ -n "$MW" ]; then
  grep -q "matcher" "$MW" || finding "middleware-no-matcher" "Middleware without matcher — runs on static assets too"
  grep -qE "lodash|moment|dayjs" "$MW" && finding "heavy-middleware" "Heavy imports in middleware — adds latency to every request"
fi

# poweredByHeader not disabled
NEXTCFG=$(find "$REPO" -maxdepth 1 -name "next.config.*" | head -1)
[ -n "$NEXTCFG" ] && ! grep -q "poweredByHeader" "$NEXTCFG" && \
  finding "no-powered-by" "poweredByHeader not disabled — leaks framework info"

# No security headers
[ -n "$NEXTCFG" ] && ! grep -q "headers" "$NEXTCFG" && \
  finding "no-security-headers" "No security headers (X-Frame-Options, CSP, X-Content-Type-Options)"

[ "$FINDINGS" -eq 0 ] && echo "  ✓ Next.js security OK"
exit 0
