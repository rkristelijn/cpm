#!/usr/bin/env bash
# checks/javascript/nextjs/check-client-components.sh
# @see ADR-129
# Client/Server boundary mistakes: 'use server' misuse, browser API guards
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../../lib/shell/init.sh" 2>/dev/null || true
cpm_check_enabled "nextjs-client-components" || exit 0
set -o nounset -o pipefail

REPO="${1:-.}"
[ -f "$REPO/package.json" ] && grep -q '"next"' "$REPO/package.json" || exit 0

FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

# 'use server' misused as server component marker (it creates Server Actions, not SCs)
MISUSE=$(find "$REPO/app" "$REPO/src" -name "*.tsx" -o -name "*.ts" 2>/dev/null | \
  xargs grep -l "^'use server'\|^\"use server\"" 2>/dev/null | grep -v "action" || true)
for f in $MISUSE; do
  if grep -q "return.*<\|return.*(" "$f" 2>/dev/null && grep -q "export.*function\|export.*const" "$f" 2>/dev/null; then
    grep -q "formData\|FormData\|revalidate\|redirect\|cookies\|sql\|prisma\|db\." "$f" 2>/dev/null && continue
    finding "use-server-misuse" "'use server' doesn't make a server component — it creates Server Actions"
    break
  fi
done

# localStorage/window used without SSR guard (causes hydration errors)
CLIENT=$(cpm_grep -rl "'use client'\|\"use client\"" "$REPO/app/" "$REPO/src/" 2>/dev/null || true)
if [ -n "$CLIENT" ]; then
  echo "$CLIENT" | xargs grep -l "localStorage\|sessionStorage\|window\." 2>/dev/null | \
    xargs grep -L "typeof window\|typeof localStorage\|useEffect\|mounted" 2>/dev/null | \
    head -1 | grep -q . && \
    finding "browser-api-no-guard" "localStorage/window without SSR guard — causes hydration errors"
fi

# 'use server' in utility file (should use server-only package instead)
UTILS=$(find "$REPO/app" "$REPO/src" -name "*util*" -o -name "*helper*" -o -name "*lib*" 2>/dev/null | \
  grep "\.ts$\|\.tsx$" || true)
if [ -n "$UTILS" ]; then
  echo "$UTILS" | xargs grep -l "^'use server'\|^\"use server\"" 2>/dev/null | head -1 | grep -q . && \
    finding "use-server-for-isolation" "'use server' in utility — use 'server-only' package instead"
fi

[ "$FINDINGS" -eq 0 ] && echo "  ✓ Next.js client/server boundaries OK"
exit 0
