#!/usr/bin/env bash
# E2E test: cpm get and set
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"
BINARY="$(cd "$(dirname "$0")/.." && pwd)/${1:-./cpm}"
check_binary "$BINARY"

echo "=== E2E: get/set ==="

DIR=$(setup_project)
(cd "$DIR" && "$BINARY" init)

# get shows all config
OUTPUT=$(cd "$DIR" && "$BINARY" get)
assert_contains "$OUTPUT" "name" "shows name"

# get specific key
OUTPUT=$(cd "$DIR" && "$BINARY" get name)
assert_contains "$OUTPUT" "cpm-e2e" "get name value"

# set updates value
(cd "$DIR" && "$BINARY" set lang typescript)
OUTPUT=$(cd "$DIR" && "$BINARY" get lang)
assert_contains "$OUTPUT" "typescript" "set lang"

teardown_project "$DIR"
echo "=== All get/set tests passed ==="
