#!/usr/bin/env bash
# check-side-effects.sh — Detect packages missing "sideEffects": false in package.json.
#
# Without this field, bundlers (webpack, rollup, esbuild) cannot tree-shake unused exports.
# All pure utility packages should declare sideEffects: false.
#
# @see https://webpack.js.org/guides/tree-shaking/#mark-the-file-as-side-effect-free
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/shell/init.sh" 2>/dev/null || true
cpm_check_enabled "side-effects" || exit 0
set -o errexit -o nounset -o pipefail

SRC="${CPM_SRC:-.}"

# Find package.json files (monorepo or single)
if [ -f "$SRC/package.json" ] && [ ! -d "$SRC/packages" ]; then
  files="$SRC/package.json"
else
  files=$(find "$SRC" -name "package.json" -not -path "*/node_modules/*" -not -path "*/.tmp/*" -maxdepth 3 2>/dev/null)
fi

[ -z "$files" ] && exit 0

missing=0
while IFS= read -r f; do
  if ! grep -q '"sideEffects"' "$f" 2>/dev/null; then
    echo "  [warn] missing sideEffects: $f"
    missing=$((missing + 1))
  fi
done <<< "$files"

if [ "$missing" -eq 0 ]; then
  echo "  [pass] all package.json files declare sideEffects"
  exit 0
fi

echo
echo "  $missing package(s) missing \"sideEffects\": false"
echo "  Tip: add '\"sideEffects\": false' for tree-shaking support"
exit 1
