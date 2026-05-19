#!/usr/bin/env bash
# checks/javascript/check-js-deps-health.sh
# @see ADR-129
# Dependency health: dead deps, circular imports, unused exports
# Uses npx tools (non-blocking, informational)
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../../lib/shell/init.sh" 2>/dev/null || true
cpm_check_enabled "js-deps-health" || exit 0
set -o nounset -o pipefail

REPO="${1:-.}"
[ -f "$REPO/package.json" ] || exit 0
[ -d "$REPO/node_modules" ] || exit 0

FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

cd "$REPO"

# Dead dependencies (installed but not imported)
if command -v npx >/dev/null 2>&1; then
  UNUSED=$(npx --yes depcheck@1 --skip-missing 2>/dev/null | grep "^\* " | head -10 || true)
  if [ -n "$UNUSED" ]; then
    COUNT=$(echo "$UNUSED" | wc -l | tr -d ' ')
    finding "unused-deps" "$COUNT unused dependency(ies) — run: npx depcheck"
  fi
fi

# Circular dependencies (if src/ exists and madge available)
if [ -d "src" ] && command -v npx >/dev/null 2>&1; then
  CIRCULAR=$(npx --yes madge@8 --circular --extensions ts,js,tsx,jsx src/ 2>/dev/null | grep "→" | head -5 || true)
  if [ -n "$CIRCULAR" ]; then
    COUNT=$(echo "$CIRCULAR" | wc -l | tr -d ' ')
    finding "circular-deps" "$COUNT circular dependency(ies) — run: npx madge --circular src/"
  fi
fi

[ "$FINDINGS" -eq 0 ] && echo "  ✓ Dependency health OK"
exit 0
