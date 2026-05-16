#!/usr/bin/env bash
# smoke-test.sh — verify cpm binary works
set -o errexit
set -o nounset
set -o pipefail

BIN="${1:-./cpm}"

echo "=== Smoke test: $BIN ==="

# Must show help
"$BIN" help | grep -q "code project maturity"

# Must show version
"$BIN" help | grep -q "0.1.0"

# Scan must work
"$BIN" scan . --depth 1 | grep -q "Findings"

# Init must work in temp dir
TMP=$(mktemp -d)
(cd "$TMP" && "$OLDPWD/$BIN" init && test -f cpm.toml)
rm -rf "$TMP"

echo "=== All smoke tests passed ==="
