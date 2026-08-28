#!/usr/bin/env bash
# checks/universal/quality/check-security-headers.sh
# @see ADR-129
# Security headers: HSTS, Referrer-Policy, Permissions-Policy, X-Content-Type-Options, X-Frame-Options
source "$(dirname "$0")/../../../lib/shell/check.sh"
cpm_check_enabled "security-headers" || exit 0
set -o nounset -o pipefail

REPO="${1:-.}"

# IS_WEB detectie
IS_WEB=false
[ -f "$REPO/index.html" ] && IS_WEB=true
[ -d "$REPO/public" ] && IS_WEB=true
[ -d "$REPO/app" ] && [ -f "$REPO/package.json" ] && IS_WEB=true
[ -f "$REPO/next.config.ts" ] || [ -f "$REPO/next.config.js" ] || [ -f "$REPO/next.config.mjs" ] && IS_WEB=true
[ -f "$REPO/angular.json" ] && IS_WEB=true
[ -f "$REPO/vite.config.ts" ] && IS_WEB=true
[ -f "$REPO/nuxt.config.ts" ] && IS_WEB=true
[ "$IS_WEB" = false ] && exit 0

# Collect all server config files that can set HTTP headers
CONFIG_FILES=""
for candidate in \
  "$REPO/nginx.conf" \
  "$REPO/conf/nginx.conf" \
  "$REPO/config/nginx.conf" \
  "$REPO/.htaccess" \
  "$REPO/public/.htaccess" \
  "$REPO/vercel.json" \
  "$REPO/netlify.toml" \
  "$REPO/_headers" \
  "$REPO/public/_headers" \
  "$REPO/web.config" \
  "$REPO/Caddyfile" \
  "$REPO/caddy.json" \
  "$REPO/next.config.js" \
  "$REPO/next.config.ts" \
  "$REPO/next.config.mjs" \
  "$REPO/nuxt.config.ts" \
  "$REPO/nuxt.config.js"; do
  [ -f "$candidate" ] && CONFIG_FILES="${CONFIG_FILES}${candidate}
"
done

# Also search for deeper nginx/apache configs
DEEP_CONFIGS=$(find "$REPO" -maxdepth 3 \( \
  -name "nginx.conf" -o -name "nginx*.conf" -o \
  -name ".htaccess" -o -name "httpd.conf" -o \
  -name "Caddyfile" -o -name "_headers" -o \
  -name "web.config" \
  \) 2>/dev/null | grep -v "node_modules\|\.next\|dist\|build\|vendor" || true)
if [ -n "$DEEP_CONFIGS" ]; then
  CONFIG_FILES="${CONFIG_FILES}${DEEP_CONFIGS}
"
fi

# Deduplicate
CONFIG_FILES=$(echo "$CONFIG_FILES" | sort -u | grep -v '^$' || true)

# Also check middleware/server files for programmatic header setting
SERVER_FILES=$(find "$REPO" -maxdepth 4 \( \
  -name "middleware.ts" -o -name "middleware.js" -o \
  -name "server.ts" -o -name "server.js" -o \
  -name "app.ts" -o -name "app.js" -o \
  -name "helmet*" \
  \) 2>/dev/null | grep -v "node_modules\|\.next\|dist\|build\|vendor" || true)

# Check for helmet (sets all security headers by default)
HAS_HELMET=false
if [ -f "$REPO/package.json" ]; then
  grep -q '"helmet"' "$REPO/package.json" 2>/dev/null && HAS_HELMET=true
fi
# If helmet is installed, it sets all headers by default — skip all checks
[ "$HAS_HELMET" = true ] && exit 0

# No config files and no server files — nothing to check
ALL_FILES="${CONFIG_FILES}${SERVER_FILES}"
[ -z "$ALL_FILES" ] && exit 0

# Helper: search across all config + server files for a pattern
header_found() {
  local pattern="$1"
  # Search config files
  if [ -n "$CONFIG_FILES" ]; then
    echo "$CONFIG_FILES" | xargs grep -liE "$pattern" 2>/dev/null | head -1 | grep -q . && return 0
  fi
  # Search server/middleware files
  if [ -n "$SERVER_FILES" ]; then
    echo "$SERVER_FILES" | xargs grep -liE "$pattern" 2>/dev/null | head -1 | grep -q . && return 0
  fi
  return 1
}

# Pick a representative file for findings
REPORT_FILE=$(echo "$CONFIG_FILES" | head -1 || true)
[ -z "$REPORT_FILE" ] && REPORT_FILE=$(echo "$SERVER_FILES" | head -1 || true)
[ -z "$REPORT_FILE" ] && REPORT_FILE="$REPO"

# --- Rule 1: security-no-hsts ---
if ! header_found "Strict-Transport-Security|strict.transport.security|hsts"; then
  findings_add "warning" "$REPORT_FILE" "security-no-hsts" \
    "No Strict-Transport-Security (HSTS) header — browsers will allow HTTP downgrade attacks" \
    "Add header: Strict-Transport-Security: max-age=31536000; includeSubDomains" \
    "https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Strict-Transport-Security"
fi

# --- Rule 2: security-no-referrer-policy ---
if ! header_found "Referrer-Policy|referrer.policy|referrerPolicy"; then
  findings_add "warning" "$REPORT_FILE" "security-no-referrer-policy" \
    "No Referrer-Policy header — full URLs may leak to third parties via Referer header" \
    "Add header: Referrer-Policy: strict-origin-when-cross-origin" \
    "https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Referrer-Policy"
fi

# --- Rule 3: security-no-permissions-policy ---
if ! header_found "Permissions-Policy|permissions.policy|permissionsPolicy|Feature-Policy|feature.policy|featurePolicy"; then
  findings_add "warning" "$REPORT_FILE" "security-no-permissions-policy" \
    "No Permissions-Policy header — third-party scripts can access camera, mic, geolocation" \
    "Add header: Permissions-Policy: camera=(), microphone=(), geolocation=()" \
    "https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Permissions-Policy"
fi

# --- Rule 4: security-no-x-content-type ---
if ! header_found "X-Content-Type-Options|x.content.type.options|contentTypeOptions|nosniff"; then
  findings_add "warning" "$REPORT_FILE" "security-no-x-content-type" \
    "No X-Content-Type-Options header — browsers may MIME-sniff responses into executable content" \
    "Add header: X-Content-Type-Options: nosniff" \
    "https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/X-Content-Type-Options"
fi

# --- Rule 5: security-no-x-frame ---
if ! header_found "X-Frame-Options|x.frame.options|xFrameOptions|frame-ancestors|frameAncestors"; then
  findings_add "warning" "$REPORT_FILE" "security-no-x-frame" \
    "No X-Frame-Options or CSP frame-ancestors — page can be embedded in malicious iframes (clickjacking)" \
    "Add header: X-Frame-Options: DENY (or CSP frame-ancestors 'none')" \
    "https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/X-Frame-Options"
fi
