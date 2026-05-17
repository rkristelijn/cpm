#!/usr/bin/env bash
# checks/javascript/check-axios.sh
# Axios best practices: timeout, interceptors, env vars, retry, error handling
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/shell/init.sh" 2>/dev/null || true
cpm_check_enabled "js-axios" || exit 0
set -o nounset -o pipefail

REPO="${1:-.}"
[ -f "$REPO/package.json" ] && grep -q '"axios"' "$REPO/package.json" || exit 0

FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

SRC=""
[ -d "$REPO/src" ] && SRC="$REPO/src/"
[ -d "$REPO/app" ] && SRC="$SRC $REPO/app/"
[ -z "$SRC" ] && exit 0

# --- No timeout configured (hangs forever on slow servers) ---
CREATE_AXIOS=$(cpm_grep -rn "axios\.create\|new Axios" $SRC 2>/dev/null | head -3 || true)
if [ -n "$CREATE_AXIOS" ]; then
  NO_TIMEOUT=$(echo "$CREATE_AXIOS" | grep -v "timeout" | head -3 || true)
  [ -n "$NO_TIMEOUT" ] && finding "axios-no-timeout" "Axios instance without timeout — requests hang on slow servers"
fi

# --- No response interceptor for error handling ---
INTERCEPTOR_FILES=$(cpm_grep -rl "axios\.create\|axios\.instance" $SRC 2>/dev/null || true)
if [ -n "$INTERCEPTOR_FILES" ]; then
  NO_INTERCEPTOR=$(echo "$INTERCEPTOR_FILES" | xargs grep -L "\.interceptors\.response" 2>/dev/null | head -3 || true)
  [ -n "$NO_INTERCEPTOR" ] && finding "axios-no-interceptor" "No response interceptor — errors may go unhandled"
fi

# --- Hardcoded base URLs (should use env vars) ---
HARDCODED_URL=$(cpm_grep -rn "baseURL.*['\"]https*://[a-zA-Z0-9./-]+['\"]" $SRC 2>/dev/null | \
  grep -v "process\.env\|import\.meta\.env\|VITE_\|NEXT_PUBLIC_" | head -5 || true)
if [ -n "$HARDCODED_URL" ]; then
  finding "axios-hardcoded-url" "Hardcoded base URL — use environment variables for different environments"
fi

# --- No retry logic for network errors ---
RETRY_FILES=$(cpm_grep -rl "axios" $SRC 2>/dev/null | grep -v "\.test\.\|\.spec\." || true)
if [ -n "$RETRY_FILES" ]; then
  NO_RETRY=$(echo "$RETRY_FILES" | xargs grep -L "axios-retry\|retry\|retryDelay" 2>/dev/null | head -3 || true)
  [ -n "$NO_RETRY" ] && finding "axios-no-retry" "No retry logic — network errors fail immediately"
fi

# --- Catching errors without checking error.response vs error.request ---
CATCH_NO_CHECK=$(cpm_grep -rn "\.catch\([^)]*error\)" $SRC 2>/dev/null | \
  grep -v "error\.response\|error\.request\|error\.message" | head -5 || true)
if [ -n "$CATCH_NO_CHECK" ]; then
  finding "axios-error-handling" "catch without error.response/request check — may hide network vs server errors"
fi

[ "$FINDINGS" -eq 0 ] && echo "  ✓ Axios patterns OK"
exit 0