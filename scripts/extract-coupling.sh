#!/usr/bin/env bash
# scripts/extract-coupling.sh — Extract how a project uses a specific dependency.
#
# Scans a codebase for all imports/requires of a package and extracts:
#   - Import style (require, import, destructured)
#   - Methods/properties accessed
#   - Call signatures (arguments passed)
#
# Usage:
#   ./scripts/extract-coupling.sh <package-name> [target-dir]
#   ./scripts/extract-coupling.sh ms ~/git/express
#   ./scripts/extract-coupling.sh debug ~/git/nestjs
#
# Output: JSON array of call sites to stdout, summary to stderr.
set -o errexit -o nounset -o pipefail

PKG="${1:?Usage: $0 <package-name> [target-dir]}"
TARGET="${2:-.}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -d "$TARGET" ]; then
  echo "Error: $TARGET is not a directory" >&2
  exit 1
fi

# Find all JS/TS files that reference this package
if command -v rg >/dev/null 2>&1; then
  FILES=$(rg -l "require\(['\"]${PKG}['\"]\)|from ['\"]${PKG}['\"]" "$TARGET" \
    -g '*.js' -g '*.ts' -g '*.mjs' -g '*.cjs' \
    -g '!**/node_modules/**' -g '!**/dist/**' -g '!**/*.min.js' \
    2>/dev/null || true)
else
  FILES=$(grep -rl "require(['\"]${PKG}['\"])\|from ['\"]${PKG}['\"]" "$TARGET" \
    --include='*.js' --include='*.ts' --include='*.mjs' --include='*.cjs' \
    --exclude-dir=node_modules --exclude-dir=dist \
    2>/dev/null || true)
fi

if [ -z "$FILES" ]; then
  echo "No usage of '$PKG' found in $TARGET" >&2
  echo "[]"
  exit 0
fi

FILE_COUNT=$(echo "$FILES" | wc -l | tr -d ' ')
echo "Found $PKG in $FILE_COUNT file(s) in $TARGET" >&2

echo "$FILES" | node "$SCRIPT_DIR/extract-coupling-parse.js" "$PKG"
