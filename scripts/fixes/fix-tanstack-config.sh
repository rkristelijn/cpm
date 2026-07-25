#!/usr/bin/env bash
# fixes/fix-tanstack-config.sh — Fix TanStack Query default config issues
# Usage: bash fixes/fix-tanstack-config.sh [path]
set -o nounset -o pipefail

REPO="${1:-.}"
FIXED=0

fix() {
  printf "  \033[32m✓ fixed\033[0m  %-30s %s\n" "$1" "$2"
  FIXED=$((FIXED + 1))
}
skip() { printf "  \033[90m· skip\033[0m   %-30s %s\n" "$1" "$2"; }

SRC=""
[ -d "$REPO/src" ] && SRC="$REPO/src"
[ -d "$REPO/app" ] && SRC="${SRC:+$SRC }$REPO/app"
[ -z "$SRC" ] && exit 0

echo ""
echo "  cpm fix — TanStack Query configuration"
echo ""

# --- Fix 1: Add defaultOptions with staleTime to QueryClient ---
PROVIDER=$(grep -rl "new QueryClient()" $SRC --include="*.tsx" --include="*.ts" 2>/dev/null | head -1 || true)
if [ -n "$PROVIDER" ]; then
  if ! grep -q "staleTime\|defaultOptions" "$PROVIDER" 2>/dev/null; then
    # Replace `new QueryClient()` with configured version
    sed -i 's/new QueryClient()/new QueryClient({\n      defaultOptions: {\n        queries: {\n          staleTime: 60 * 1000, \/\/ 1 minute\n          retry: 1,\n        },\n      },\n    })/' "$PROVIDER"
    fix "tanstack-staletime" "Added defaultOptions.queries.staleTime (60s) to QueryClient"
  else
    skip "tanstack-staletime" "Already configured"
  fi
fi

echo ""
echo "  $FIXED fixes applied"
