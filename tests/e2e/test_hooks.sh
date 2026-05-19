#!/usr/bin/env bash
# E2E test: cpm hook and unhook
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"
BINARY=$(resolve_binary "${1:-./cpm}")
check_binary "$BINARY"

echo "=== E2E: hook/unhook ==="

DIR=$(setup_project)
(cd "$DIR" && git init -q && "$BINARY" init)

# hook installs git hooks
(cd "$DIR" && "$BINARY" hook)
assert_file_exists "$DIR/.git/hooks/pre-commit"
assert_file_exists "$DIR/.git/hooks/pre-push"

# unhook removes them
(cd "$DIR" && "$BINARY" unhook)
[[ ! -f "$DIR/.git/hooks/pre-commit" ]] || die "pre-commit not removed"

teardown_project "$DIR"
echo "=== All hook/unhook tests passed ==="
