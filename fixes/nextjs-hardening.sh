#!/usr/bin/env bash
# fixes/nextjs-hardening.sh — Auto-fix Next.js server hardening
# Adds poweredByHeader: false and security headers to next.config.ts
# Version-scoped: only applies to Next.js 14-16
set -o errexit -o nounset -o pipefail

REPO="${1:-.}"

# Detect Next.js version from package.json
get_next_major() {
  local pkg="$REPO/package.json"
  [ -f "$pkg" ] || return 1
  grep -o '"next"[^,]*' "$pkg" | grep -oE '[0-9]+' | head -1
}

# Find next.config file
find_config() {
  for ext in ts mjs js; do
    [ -f "$REPO/next.config.$ext" ] && echo "$REPO/next.config.$ext" && return
  done
  return 1
}

NEXT_MAJOR=$(get_next_major) || { echo "  ✗ No Next.js in package.json"; exit 1; }
CONFIG=$(find_config) || { echo "  ✗ No next.config found"; exit 1; }

# Version gate
if [ "$NEXT_MAJOR" -lt 14 ] || [ "$NEXT_MAJOR" -gt 16 ]; then
  echo "  ⚠ Next.js $NEXT_MAJOR detected — fix only verified for 14-16, skipping"
  exit 0
fi

echo "  Next.js $NEXT_MAJOR — applying server hardening to $(basename "$CONFIG")"

# Check what's missing
NEEDS_POWERED_BY=false
NEEDS_HEADERS=false
grep -q "poweredByHeader" "$CONFIG" || NEEDS_POWERED_BY=true
grep -q "headers" "$CONFIG" || NEEDS_HEADERS=true

if [ "$NEEDS_POWERED_BY" = false ] && [ "$NEEDS_HEADERS" = false ]; then
  echo "  ✓ Already hardened"
  exit 0
fi

# Build the patch content
PATCH=""
if [ "$NEEDS_POWERED_BY" = true ]; then
  PATCH="${PATCH}  poweredByHeader: false,"$'\n'
fi
if [ "$NEEDS_HEADERS" = true ]; then
  PATCH="${PATCH}  async headers() {
    return [
      {
        source: '/(.*)',
        headers: [
          { key: 'X-Frame-Options', value: 'DENY' },
          { key: 'X-Content-Type-Options', value: 'nosniff' },
          { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
          { key: 'Permissions-Policy', value: 'camera=(), microphone=(), geolocation=()' },
        ],
      },
    ];
  },"$'\n'
fi

# Apply patch — insert after the opening of nextConfig object
# Pattern: find "NextConfig = {" or "nextConfig = {" or "module.exports = {" and insert after
if grep -q "NextConfig = {" "$CONFIG"; then
  sed -i.bak '/NextConfig = {/a\
'"$(echo "$PATCH" | sed 's/$/\\/' | sed '$ s/\\$//')" "$CONFIG"
elif grep -q "nextConfig = {" "$CONFIG"; then
  sed -i.bak '/nextConfig = {/a\
'"$(echo "$PATCH" | sed 's/$/\\/' | sed '$ s/\\$//')" "$CONFIG"
elif grep -q "module.exports = {" "$CONFIG"; then
  sed -i.bak '/module.exports = {/a\
'"$(echo "$PATCH" | sed 's/$/\\/' | sed '$ s/\\$//')" "$CONFIG"
else
  echo "  ✗ Could not find config object pattern in $CONFIG"
  exit 1
fi

rm -f "${CONFIG}.bak"

if [ "$NEEDS_POWERED_BY" = true ]; then echo "  ✓ Added poweredByHeader: false"; fi
if [ "$NEEDS_HEADERS" = true ]; then echo "  ✓ Added security headers (X-Frame-Options, X-Content-Type-Options, Referrer-Policy, Permissions-Policy)"; fi
