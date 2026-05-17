#!/usr/bin/env bash
# checks/javascript/check-runtime-pin.sh
# Verify Node.js version is pinned and not EOL
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/shell/init.sh" 2>/dev/null || true
cpm_check_enabled "js-runtime-pin" || exit 0
set -o nounset -o pipefail

REPO="${1:-.}"
[ -f "$REPO/package.json" ] || exit 0

FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }
error()   { printf "  \033[31merror\033[0m    %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

# Check .nvmrc or .node-version exists
NVMRC=""
[ -f "$REPO/.nvmrc" ] && NVMRC="$REPO/.nvmrc"
[ -f "$REPO/.node-version" ] && NVMRC="$REPO/.node-version"

if [ -z "$NVMRC" ]; then
  finding "no-nvmrc" "No .nvmrc or .node-version — Node version not pinned for team"
else
  # Check it contains an exact version (not lts/*, node, latest)
  CONTENT=$(cat "$NVMRC" | tr -d '[:space:]')
  if echo "$CONTENT" | grep -qiE '^(lts|node|latest|stable)'; then
    finding "nvmrc-not-pinned" ".nvmrc uses '$CONTENT' — pin to exact version (e.g. 20.11.0)"
  fi
fi

# Check EOL
NODE_VER=0
[ -n "$NVMRC" ] && NODE_VER=$(sed 's/^v//' "$NVMRC" | cut -d. -f1)

if [ "$NODE_VER" -gt 0 ] 2>/dev/null && [ "$NODE_VER" -lt 20 ]; then
  error "node-eol" "Node.js $NODE_VER is EOL — upgrade to 20+"
fi

# Check engines field matches .nvmrc
if [ -n "$NVMRC" ] && [ "$NODE_VER" -gt 0 ] 2>/dev/null; then
  ENGINES=$(grep -oE '"node"[[:space:]]*:[[:space:]]*"[^"]+"' "$REPO/package.json" 2>/dev/null | grep -oE '[0-9]+' | head -1)
  if [ -n "$ENGINES" ] && [ "$ENGINES" != "$NODE_VER" ]; then
    finding "engines-nvmrc-mismatch" "engines.node ($ENGINES) doesn't match .nvmrc ($NODE_VER)"
  fi
fi

# --- .npmrc checks ---
if [ -f "$REPO/.npmrc" ]; then
  # Secrets in .npmrc (auth tokens committed to repo)
  if grep -qE '(_authToken|_auth|//registry.*:)' "$REPO/.npmrc" 2>/dev/null; then
    if ! grep -q '${' "$REPO/.npmrc"; then
      error "npmrc-hardcoded-token" ".npmrc contains hardcoded auth token — use env var: \${NPM_TOKEN}"
    fi
  fi
  # save-exact not set (leads to unpinned deps)
  grep -q "save-exact=true" "$REPO/.npmrc" || finding "npmrc-no-save-exact" ".npmrc: save-exact not set — new installs will use ^ ranges"
fi

# --- .nvmrc auto-switch hint ---
if [ -n "$NVMRC" ] && [ ! -f "$REPO/.npmrc" ]; then
  finding "no-npmrc" "No .npmrc — consider adding save-exact=true and engine-strict=true"
fi

[ "$FINDINGS" -eq 0 ] && echo "  ✓ Runtime & config OK"
exit 0
