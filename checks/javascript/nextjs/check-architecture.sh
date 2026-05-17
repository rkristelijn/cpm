#!/usr/bin/env bash
# checks/javascript/nextjs/check-architecture.sh
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

[ "$FINDINGS" -eq 0 ] && echo "  ✓ Next.js architecture OK"
exit 0
