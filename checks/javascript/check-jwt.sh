#!/usr/bin/env bash
# checks/javascript/check-jwt.sh
# @see ADR-129
# jsonwebtoken security: none algo, no expiry, hardcoded secrets, weak keys
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/shell/init.sh" 2>/dev/null || true
cpm_check_enabled "js-jwt" || exit 0
set -o nounset -o pipefail

REPO="${1:-.}"
[ -f "$REPO/package.json" ] && grep -q '"jsonwebtoken"' "$REPO/package.json" || exit 0

FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

SRC=""
[ -d "$REPO/src" ] && SRC="$REPO/src/"
[ -d "$REPO/app" ] && SRC="$SRC $REPO/app/"
[ -z "$SRC" ] && exit 0

# --- Using 'none' algorithm (allows unsigned tokens) ---
NONE_ALGO=$(cpm_grep -rn "algorithm.*['\"]none['\"]\|algo.*['\"]none['\"]" $SRC 2>/dev/null | head -3 || true)
if [ -n "$NONE_ALGO" ]; then
  finding "jwt-none-algorithm" "'none' algorithm allows unsigned tokens — security vulnerability"
fi

# --- No expiresIn set on sign() ---
NO_EXPIRY=$(cpm_grep -rn "\.sign\([^)]*\{[^}]*\}" $SRC 2>/dev/null | \
  grep -v "expiresIn\|expiresAt\|expiration" | head -3 || true)
if [ -n "$NO_EXPIRY" ]; then
  finding "jwt-no-expiry" "jwt.sign() without expiresIn — tokens never expire, security risk"
fi

# --- Secret/key hardcoded as string literal in sign/verify calls ---
HARDCODED=$(cpm_grep -rn "\.(sign|verify)\([^)]*['\"][a-zA-Z0-9+/=]{8,}['\"]" $SRC 2>/dev/null | \
  grep -v "process\.env\|process\.env\|config\|process\.env" | head -5 || true)
if [ -n "$HARDCODED" ]; then
  finding "jwt-hardcoded-secret" "Secret/key hardcoded as string literal — use environment variables"
fi

# --- Using HS256 with short secret (<32 chars) ---
HS256_SHORT=$(cpm_grep -rn "HS256\|HS384\|HS512" $SRC 2>/dev/null | head -5 || true)
if [ -n "$HS256_SHORT" ]; then
  SHORT_SECRET=$(cpm_grep -rn "['\"][^'\"]{0,31}['\"]" $SRC 2>/dev/null | \
    grep -E "secret|key|password" | head -5 || true)
  [ -n "$SHORT_SECRET" ] && finding "jwt-short-secret" "HS256 with short secret (<32 chars) — vulnerable to brute force"
fi

# --- No issuer/audience verification in verify options ---
NO_VERIFY_OPTS=$(cpm_grep -rn "\.verify\([^)]*\)" $SRC 2>/dev/null | \
  grep -v "issuer\|audience\|algorithms" | head -5 || true)
if [ -n "$NO_VERIFY_OPTS" ]; then
  finding "jwt-no-verify-opts" "jwt.verify() without issuer/audience checks — vulnerable to token confusion"
fi

# --- jwt.decode() used for auth decisions (decode doesn't verify!) ---
DECODE_AUTH=$(cpm_grep -rn "jwt\.decode\|JSON\.parse.*token" $SRC 2>/dev/null | \
  grep -v "\.verify\|// cpm:ignore" | head -5 || true)
if [ -n "$DECODE_AUTH" ]; then
  finding "jwt-decode-auth" "jwt.decode() used for auth — doesn't verify signature. Use jwt.verify()"
fi

[ "$FINDINGS" -eq 0 ] && echo "  ✓ JWT security OK"
exit 0