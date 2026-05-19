#!/usr/bin/env bash
# E2E test: cpm version and bump
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"
BINARY=$(resolve_binary "${1:-./cpm}")
check_binary "$BINARY"

echo "=== E2E: version/bump ==="

DIR=$(setup_project)
(cd "$DIR" && "$BINARY" init)

# version shows current version
OUTPUT=$(cd "$DIR" && "$BINARY" version)
assert_contains "$OUTPUT" "0.1.0" "initial version"

# bump patch
OUTPUT=$(cd "$DIR" && "$BINARY" bump patch)
CONTENT=$(cat "$DIR/cpm.toml")
assert_contains "$CONTENT" 'version = "0.1.1"' "patch bump"

# bump minor
OUTPUT=$(cd "$DIR" && "$BINARY" bump minor)
CONTENT=$(cat "$DIR/cpm.toml")
assert_contains "$CONTENT" 'version = "0.2.0"' "minor bump"

# bump major
OUTPUT=$(cd "$DIR" && "$BINARY" bump major)
CONTENT=$(cat "$DIR/cpm.toml")
assert_contains "$CONTENT" 'version = "1.0.0"' "major bump"

# bump without arg shows error
OUTPUT=$(cd "$DIR" && "$BINARY" bump 2>&1 || true)
assert_contains "$OUTPUT" "major|minor|patch" "usage hint"

teardown_project "$DIR"
echo "=== All version/bump tests passed ==="
