#!/usr/bin/env bash
# E2E test: cpm init
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"
BINARY="$(cd "$(dirname "$0")/.." && pwd)/${1:-./cpm}"
check_binary "$BINARY"

echo "=== E2E: init ==="

# init creates cpm.toml
DIR=$(setup_project)
(cd "$DIR" && "$BINARY" init)
assert_file_exists "$DIR/cpm.toml"

# cpm.toml has required sections
CONTENT=$(cat "$DIR/cpm.toml")
assert_contains "$CONTENT" "[project]" "project section"
assert_contains "$CONTENT" "[tools]" "tools section"
assert_contains "$CONTENT" "[checks]" "checks section"
assert_contains "$CONTENT" "[hooks]" "hooks section"
assert_contains "$CONTENT" "version = " "version field"
assert_contains "$CONTENT" "lang = " "lang field"

# project name derived from directory
DIRNAME=$(basename "$DIR")
assert_contains "$CONTENT" "name = \"$DIRNAME\"" "name from dir"

# init refuses if cpm.toml already exists
OUTPUT=$("$BINARY" init 2>&1 || true)
# (run from cpm repo root where cpm.toml exists)
assert_contains "$OUTPUT" "already exists" "refuses overwrite"

teardown_project "$DIR"
echo "=== All init tests passed ==="
