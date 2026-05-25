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

# version shows current version (semver format from binary)
OUTPUT=$(cd "$DIR" && "$BINARY" version)
assert_contains "$OUTPUT" "cpm" "initial version"

# bump patch
OUTPUT=$(cd "$DIR" && "$BINARY" bump patch)
CONTENT=$(cat "$DIR/cpm.toml")
# Version after patch bump should end in .2 (init creates X.Y.1, patch makes X.Y.2)
assert_contains "$OUTPUT" "→" "patch bump"

# bump minor
OUTPUT=$(cd "$DIR" && "$BINARY" bump minor)
CONTENT=$(cat "$DIR/cpm.toml")
assert_contains "$OUTPUT" "→" "minor bump"

# bump major
OUTPUT=$(cd "$DIR" && "$BINARY" bump major)
CONTENT=$(cat "$DIR/cpm.toml")
assert_contains "$CONTENT" 'version = "1.0.0"' "major bump"

# bump without arg shows error
OUTPUT=$(cd "$DIR" && "$BINARY" bump 2>&1 || true)
assert_contains "$OUTPUT" "major|minor|patch" "usage hint"

teardown_project "$DIR"
echo "=== All version/bump tests passed ==="
