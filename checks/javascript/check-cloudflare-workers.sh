#!/usr/bin/env bash
# checks/javascript/check-cloudflare-workers.sh
# Cloudflare Workers + OpenNext anti-patterns
# Reference: https://opennext.js.org/cloudflare
set -o nounset -o pipefail

REPO="${1:-.}"

# Only run if project uses Cloudflare (wrangler config exists)
HAS_WRANGLER=false
[ -f "$REPO/wrangler.toml" ] || [ -f "$REPO/wrangler.jsonc" ] || [ -f "$REPO/wrangler.json" ] && HAS_WRANGLER=true
[ "$HAS_WRANGLER" = false ] && exit 0

FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-35s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }
blocker() { printf "  \033[31mblocking\033[0m %-35s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

SRC=""
[ -d "$REPO/src" ] && SRC="$REPO/src"
[ -d "$REPO/app" ] && SRC="${SRC:+$SRC }$REPO/app"

# --- 1. export const runtime = 'edge' (not needed, Workers are already edge) ---
if [ -n "$SRC" ] && grep -rn "export const runtime" $SRC --include="*.tsx" --include="*.ts" 2>/dev/null | grep -v node_modules | head -1 | grep -q .; then
  blocker "cf-runtime-edge" "export const runtime = 'edge' — remove it, Workers are already edge"
fi

# --- 2. Old @cloudflare/next-on-pages (deprecated) ---
if [ -f "$REPO/package.json" ] && grep -q "next-on-pages" "$REPO/package.json" 2>/dev/null; then
  blocker "cf-next-on-pages" "@cloudflare/next-on-pages is deprecated — migrate to @opennextjs/cloudflare"
fi

# --- 3. wrangler.toml instead of wrangler.jsonc ---
if [ -f "$REPO/wrangler.toml" ] && [ ! -f "$REPO/wrangler.jsonc" ]; then
  finding "cf-wrangler-toml" "wrangler.toml found — consider migrating to wrangler.jsonc (better IDE support)"
fi

# --- 4. Missing open-next.config.ts ---
if grep -q "@opennextjs/cloudflare" "$REPO/package.json" 2>/dev/null && [ ! -f "$REPO/open-next.config.ts" ]; then
  finding "cf-no-opennext-config" "Missing open-next.config.ts — required for @opennextjs/cloudflare"
fi

# --- 5. Missing .dev.vars ---
if [ ! -f "$REPO/.dev.vars" ]; then
  finding "cf-no-dev-vars" "Missing .dev.vars — needed for local dev with Workers bindings"
fi

# --- 6. Global database client (should be per-request) ---
if [ -n "$SRC" ] && grep -rn "new D1Database\|global.*drizzle\|global.*prisma" $SRC --include="*.ts" --include="*.tsx" 2>/dev/null | grep -v node_modules | head -1 | grep -q .; then
  finding "cf-global-db" "Global DB client detected — use per-request via getCloudflareContext()"
fi

# --- 7. Missing nodejs_compat flag ---
if [ -f "$REPO/wrangler.jsonc" ] && ! grep -q "nodejs_compat" "$REPO/wrangler.jsonc" 2>/dev/null; then
  blocker "cf-no-nodejs-compat" "Missing nodejs_compat compatibility flag in wrangler.jsonc"
elif [ -f "$REPO/wrangler.toml" ] && ! grep -q "nodejs_compat" "$REPO/wrangler.toml" 2>/dev/null; then
  blocker "cf-no-nodejs-compat" "Missing nodejs_compat compatibility flag in wrangler.toml"
fi

# --- 8. Old pages:build script (deprecated) ---
if [ -f "$REPO/package.json" ] && grep -q "pages:build\|pages:deploy\|wrangler pages" "$REPO/package.json" 2>/dev/null; then
  finding "cf-pages-script" "pages:build/deploy scripts found — use opennextjs-cloudflare build/deploy"
fi

[ "$FINDINGS" -eq 0 ] && printf "  \033[32m✓\033[0m  Cloudflare Workers: all checks passed\n"
exit 0
