#!/usr/bin/env bash
# checks/javascript/nextjs/check-architecture.sh
# @see ADR-129
# Server/Client component mistakes, data fetching patterns
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../../lib/shell/init.sh" 2>/dev/null || true
cpm_check_enabled "nextjs-architecture" || exit 0
set -o nounset -o pipefail

REPO="${1:-.}"
[ -f "$REPO/package.json" ] && grep -q '"next"' "$REPO/package.json" || exit 0

FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

# Page marked 'use client' (entire page becomes client)
find "$REPO/app" -name "page.tsx" -o -name "page.jsx" 2>/dev/null | \
  xargs grep -l "'use client'\|\"use client\"" 2>/dev/null | head -1 | grep -q . && \
  finding "page-use-client" "Page marked 'use client' — extract interactive parts instead"

# useEffect + fetch (should be server component)
cpm_grep -rl "useEffect" "$REPO/app/" "$REPO/src/" 2>/dev/null | \
  xargs grep -l "fetch\|axios" 2>/dev/null | grep -v ".test." | head -1 | grep -q . && \
  finding "client-side-fetch" "useEffect + fetch — use Server Components for data fetching"

# Fetching own Route Handler from Server Component
cpm_grep -rl "localhost:3000/api\|localhost:3001/api" "$REPO/app/" "$REPO/src/" 2>/dev/null | head -1 | grep -q . && \
  finding "route-handler-in-sc" "Fetching own API route from Server Component — call logic directly"

# redirect() inside try/catch
cpm_grep -rl "try" "$REPO/app/" "$REPO/src/" 2>/dev/null | \
  xargs grep -l "redirect" 2>/dev/null | head -1 | grep -q . && \
  finding "redirect-in-try-catch" "redirect() in try/catch — it throws internally, move outside"

# Server Action without revalidate after mutation
ACTIONS=$(cpm_grep -rl "'use server'\|\"use server\"" "$REPO/app/" "$REPO/src/" 2>/dev/null || true)
if [ -n "$ACTIONS" ]; then
  echo "$ACTIONS" | xargs grep -l "INSERT\|UPDATE\|DELETE\|create\|update\|delete" 2>/dev/null | \
    xargs grep -L "revalidatePath\|revalidateTag" 2>/dev/null | head -1 | grep -q . && \
    finding "no-revalidate" "Server Action mutates without revalidatePath — stale cache"
fi

# Heavy client-side logic (many filter/sort in 'use client' files)
CLIENT=$(cpm_grep -rl "'use client'" "$REPO/app/" "$REPO/src/" 2>/dev/null || true)
if [ -n "$CLIENT" ]; then
  COUNT=$(echo "$CLIENT" | xargs grep -l "\.filter\|\.sort\|\.reduce" 2>/dev/null | wc -l | tr -d ' ')
  [ "$COUNT" -gt 5 ] && finding "heavy-client-logic" "Many client components with data transforms — move to server"
fi

# --- No loading.tsx (no streaming/suspense for route segments) ---
if [ -d "$REPO/app" ]; then
  ROUTES=$(find "$REPO/app" -name "page.tsx" -o -name "page.jsx" 2>/dev/null | wc -l | tr -d ' ')
  LOADINGS=$(find "$REPO/app" -name "loading.tsx" -o -name "loading.jsx" 2>/dev/null | wc -l | tr -d ' ')
  [ "$ROUTES" -gt 3 ] && [ "$LOADINGS" -eq 0 ] && \
    finding "no-loading-tsx" "No loading.tsx in app/ — users see blank screen during navigation"
fi

# --- No error.tsx (no error boundary for route segments) ---
if [ -d "$REPO/app" ]; then
  ERRORS=$(find "$REPO/app" -name "error.tsx" -o -name "error.jsx" 2>/dev/null | wc -l | tr -d ' ')
  [ "$ROUTES" -gt 3 ] && [ "$ERRORS" -eq 0 ] && \
    finding "no-error-tsx" "No error.tsx in app/ — unhandled errors crash the entire page"
fi

# --- No metadata export in layout/pages (SEO) ---
if [ -d "$REPO/app" ]; then
  LAYOUT=$(find "$REPO/app" -maxdepth 1 -name "layout.tsx" -o -name "layout.jsx" 2>/dev/null | head -1)
  if [ -n "$LAYOUT" ] && ! grep -q "metadata\|generateMetadata" "$LAYOUT" 2>/dev/null; then
    finding "no-metadata-export" "Root layout without metadata export — missing title/description for SEO"
  fi
fi

# --- No not-found.tsx for 404 handling ---
if [ -d "$REPO/app" ]; then
  find "$REPO/app" -name "not-found.tsx" -o -name "not-found.jsx" 2>/dev/null | grep -q . || \
    finding "no-not-found" "No app/not-found.tsx — default 404 lacks branding"
fi

# --- getServerSideProps/getStaticProps in App Router (Pages Router pattern) ---
cpm_grep -rl "getServerSideProps|getStaticProps|getStaticPaths" "$REPO/app/" "$REPO/src/" 2>/dev/null | head -1 | grep -q . && \
  finding "pages-router-api" "getServerSideProps/getStaticProps found — App Router uses async components"

# --- Dynamic routes without generateStaticParams ---
DYNAMIC_ROUTES=$(find "$REPO/app" -type d -name "\[*\]" 2>/dev/null | wc -l | tr -d ' ')
if [ "$DYNAMIC_ROUTES" -gt 0 ]; then
  HAS_GENERATE_STATIC_PARAMS=$(find "$REPO/app" -name "page.tsx" -o -name "page.jsx" 2>/dev/null | \
    xargs grep -l "generateStaticParams" 2>/dev/null | wc -l | tr -d ' ')
  [ "$HAS_GENERATE_STATIC_PARAMS" -eq 0 ] && \
    finding "no-generate-static-params" "Dynamic routes without generateStaticParams — SSR at runtime"
fi

# --- cookies()/headers() in potentially static context ---
cpm_grep -rl "cookies\(\)|headers\(\)" "$REPO/app/" "$REPO/src/" 2>/dev/null | \
  xargs grep -L "dynamic\|force-dynamic" 2>/dev/null | head -1 | grep -q . && \
  finding "cookies-in-static" "cookies()/headers() without dynamic config — may cause build errors"

# --- Fetch without explicit cache strategy ---
cpm_grep -rl "fetch\(" "$REPO/app/" "$REPO/src/" 2>/dev/null | \
  xargs grep -L "cache:|revalidate:|next:" 2>/dev/null | head -1 | grep -q . && \
  finding "fetch-no-cache" "fetch() without cache options — explicit is better than implicit"

# --- Image without sizes prop ---
cpm_grep -rl "<Image\|next/image" "$REPO/app/" "$REPO/src/" 2>/dev/null | \
  xargs grep -L "sizes=" 2>/dev/null | head -1 | grep -q . && \
  finding "image-no-sizes" "next/image without sizes prop — browser downloads oversized images"

# --- Font without display swap ---
cpm_grep -rl "next/font" "$REPO/app/" "$REPO/src/" 2>/dev/null | \
  xargs grep -L "display.*swap" 2>/dev/null | head -1 | grep -q . && \
  finding "font-no-display-swap" "next/font without display: 'swap' — may cause FOIT"

# --- Static export without output: 'export' ---
NEXTCFG=$(find "$REPO" -maxdepth 1 -name "next.config.*" | head -1)
if [ -n "$NEXTCFG" ] && grep -q "output.*export" "$NEXTCFG" 2>/dev/null; then
  : # output: 'export' is set, good
else
  # Check if project might need static export
  grep -q '"next": "1[4-9]' "$REPO/package.json" 2>/dev/null && \
    finding "no-static-export" "next.config without output: 'export' — for static hosting"
fi

[ "$FINDINGS" -eq 0 ] && echo "  ✓ Next.js architecture OK"
exit 0
