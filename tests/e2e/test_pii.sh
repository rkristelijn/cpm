#!/usr/bin/env bash
# E2E test: PII detection + .piiignore
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

echo "=== E2E: pii-detection ==="

DIR=$(setup_project)
mkdir -p "$DIR/src" "$DIR/docs" "$DIR/.config"

# Create a source file with PII
echo 'const host = "secret-server.internal";' > "$DIR/src/app.cpp"

# Create .pii with pattern
echo "secret-server.internal" > "$DIR/.config/.pii"

# PII check should fail (finds the pattern)
OUTPUT=$(cd "$DIR" && bash "$SCRIPT_DIR/../../checks/universal/security/check-pii.sh" 2>&1 || true)
assert_contains "$OUTPUT" "FOUND" "detects PII"
assert_contains "$OUTPUT" "FAIL" "reports failure"

# Add to .piiignore — should now pass
echo "src/app.cpp:secret-server.internal" > "$DIR/.config/.piiignore"
OUTPUT=$(cd "$DIR" && bash "$SCRIPT_DIR/../../checks/universal/security/check-pii.sh" 2>&1)
assert_contains "$OUTPUT" "pass" "passes with ignore"
assert_contains "$OUTPUT" "1 ignored" "reports ignored count"

# Wildcard ignore works
rm "$DIR/.config/.piiignore"
echo "*:secret-server.internal" > "$DIR/.config/.piiignore"
OUTPUT=$(cd "$DIR" && bash "$SCRIPT_DIR/../../checks/universal/security/check-pii.sh" 2>&1)
assert_contains "$OUTPUT" "pass" "wildcard ignore works"

# Empty .pii file skips gracefully
echo "# only comments" > "$DIR/.config/.pii"
OUTPUT=$(cd "$DIR" && bash "$SCRIPT_DIR/../../checks/universal/security/check-pii.sh" 2>&1)
assert_contains "$OUTPUT" "skip" "skips with no patterns"

teardown_project "$DIR"
echo "=== All pii-detection tests passed ==="
