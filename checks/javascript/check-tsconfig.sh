#!/usr/bin/env bash
# checks/javascript/check-tsconfig.sh
# @see ADR-129
# tsconfig.json best practices: strict mode, interop, case sensitivity
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/shell/init.sh" 2>/dev/null || true
cpm_check_enabled "ts-config" || exit 0
set -o nounset -o pipefail

REPO="${1:-.}"
TSCONFIG="$REPO/tsconfig.json"
[ -f "$TSCONFIG" ] || exit 0

FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

grep -q '"strict".*true' "$TSCONFIG" || finding "tsconfig-no-strict" "strict mode not enabled — type bugs slip through"
grep -q '"forceConsistentCasingInFileNames".*true' "$TSCONFIG" || finding "tsconfig-no-case-check" "forceConsistentCasingInFileNames not set — breaks on Linux CI"
grep -q '"esModuleInterop".*true' "$TSCONFIG" || finding "tsconfig-no-esmoduleinterop" "esModuleInterop not enabled — import issues with CJS modules"
grep -q '"skipLibCheck".*true' "$TSCONFIG" || finding "tsconfig-no-skiplib" "skipLibCheck not set — slow builds from checking node_modules .d.ts"

[ "$FINDINGS" -eq 0 ] && echo "  ✓ tsconfig.json OK"
exit 0
