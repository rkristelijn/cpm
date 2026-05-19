#!/usr/bin/env bash
# checks/universal/docs/check-web-essentials.sh
# Web essentials: robots.txt, sitemap.xml, security.txt, humans.txt
source "$(dirname "$0")/../../../lib/shell/check.sh"
cpm_check_enabled "web-essentials" || exit 0
set -o nounset -o pipefail

REPO="${1:-.}"

# Only check if this looks like a web project (has HTML, or is a JS framework project)
IS_WEB=false
[ -f "$REPO/index.html" ] && IS_WEB=true
[ -d "$REPO/public" ] && IS_WEB=true
[ -d "$REPO/app" ] && [ -f "$REPO/package.json" ] && IS_WEB=true
[ -f "$REPO/next.config.ts" ] || [ -f "$REPO/next.config.js" ] || [ -f "$REPO/next.config.mjs" ] && IS_WEB=true
[ -f "$REPO/angular.json" ] && IS_WEB=true
[ -f "$REPO/vite.config.ts" ] && IS_WEB=true
[ "$IS_WEB" = false ] && exit 0

FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

# Look in public/ or root for static files
PUB="$REPO"
[ -d "$REPO/public" ] && PUB="$REPO/public"

# --- robots.txt ---
if [ ! -f "$PUB/robots.txt" ] && [ ! -f "$REPO/app/robots.txt" ] && [ ! -f "$REPO/app/robots.ts" ]; then
  finding "no-robots-txt" "No robots.txt — search engines have no crawl guidance"
else
  # Check if robots.txt blocks everything (common staging leftover)
  ROBOTS=$(find "$PUB" "$REPO/app" -name "robots.txt" 2>/dev/null | head -1)
  if [ -n "$ROBOTS" ] && grep -q "Disallow: /$" "$ROBOTS" 2>/dev/null; then
    if grep -q "User-agent: \*" "$ROBOTS" 2>/dev/null; then
      finding "robots-blocks-all" "robots.txt blocks all crawlers (Disallow: /) — site invisible to search"
    fi
  fi
  # Check for sitemap reference in robots.txt
  if [ -n "$ROBOTS" ] && ! grep -qi "sitemap" "$ROBOTS" 2>/dev/null; then
    finding "robots-no-sitemap" "robots.txt without Sitemap reference"
  fi
fi

# --- sitemap.xml ---
if [ ! -f "$PUB/sitemap.xml" ] && [ ! -f "$REPO/app/sitemap.xml" ] && [ ! -f "$REPO/app/sitemap.ts" ]; then
  finding "no-sitemap" "No sitemap.xml — search engines may miss pages"
fi

# --- favicon ---
HAS_FAVICON=false
[ -f "$PUB/favicon.ico" ] || [ -f "$PUB/favicon.svg" ] && HAS_FAVICON=true
find "$PUB" -name "favicon*" 2>/dev/null | head -1 | grep -q . && HAS_FAVICON=true
[ "$HAS_FAVICON" = false ] && finding "no-favicon" "No favicon — browser tabs show generic icon"

# --- .well-known/security.txt (RFC 9116) ---
if [ ! -f "$PUB/.well-known/security.txt" ] && [ ! -f "$REPO/.well-known/security.txt" ]; then
  finding "no-security-txt" "No .well-known/security.txt — security researchers can't report vulnerabilities"
fi

[ "$FINDINGS" -eq 0 ] && echo "  ✓ Web essentials OK"
exit 0
