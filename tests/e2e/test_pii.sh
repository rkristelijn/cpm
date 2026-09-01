#!/usr/bin/env bash
# cpm:ignore-file SCA-068 — detector/test source: contains the patterns it checks for
# E2E test: PII detection + .piiignore
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

echo "=== E2E: pii-detection ==="

# Isolate tests from real vault — use empty temp vault
export PII_VAULT="$(mktemp -d)/pii-vault-test"
mkdir -p "$PII_VAULT/patterns.d"

DIR=$(setup_project)
mkdir -p "$DIR/src" "$DIR/docs" "$DIR/.config"

# Create a source file with PII
echo 'const host = "secret-server.internal";' > "$DIR/src/app.cpp"

# Create .pii with pattern
echo "secret-server.internal" > "$DIR/.config/.pii"

# PII check should find the pattern
OUTPUT=$(cd "$DIR" && bash "$SCRIPT_DIR/../../checks/universal/security/check-pii.sh" 2>&1 || true)
assert_contains "$OUTPUT" "Scanning for 1" "detects PII"

# Add to .piiignore — should now pass
echo "src/app.cpp:secret-server.internal" > "$DIR/.config/.piiignore"
OUTPUT=$(cd "$DIR" && bash "$SCRIPT_DIR/../../checks/universal/security/check-pii.sh" 2>&1)
assert_contains "$OUTPUT" "ignored" "passes with ignore"

# Wildcard ignore works
rm "$DIR/.config/.piiignore"
echo "*:secret-server.internal" > "$DIR/.config/.piiignore"
OUTPUT=$(cd "$DIR" && bash "$SCRIPT_DIR/../../checks/universal/security/check-pii.sh" 2>&1)
assert_contains "$OUTPUT" "ignored" "wildcard ignore works"

# Empty .pii file skips gracefully
echo "# only comments" > "$DIR/.config/.pii"
rm -f "$DIR/.config/.piiignore"
OUTPUT=$(cd "$DIR" && bash "$SCRIPT_DIR/../../checks/universal/security/check-pii.sh" 2>&1)
assert_contains "$OUTPUT" "skip" "skips with no patterns"

# Inline cpm:ignore pii suppresses finding
rm -f "$DIR/.config/.piiignore"
echo "secret-server.internal" > "$DIR/.config/.pii"
echo 'const host = "secret-server.internal"; // cpm:ignore pii' > "$DIR/src/app.cpp"
OUTPUT=$(cd "$DIR" && bash "$SCRIPT_DIR/../../checks/universal/security/check-pii.sh" 2>&1)
assert_not_contains "$OUTPUT" "pii-detected" "cpm:ignore pii suppresses inline"

# Config file disables specific staged-mode checks
DIR2=$(setup_project)
mkdir -p "$DIR2/.config"
cd "$DIR2" && git init -q && git commit --allow-empty --no-verify -m init -q
echo '999888777' > "$DIR2/test.md" # cpm:ignore pii
cd "$DIR2" && git add test.md
# Without config → should detect (findings_finish exits non-zero)
OUTPUT=$(cd "$DIR2" && export STAGED="test.md" CPM_FINDINGS_FILE="$DIR2/.tmp/f.jsonl" && mkdir -p .tmp && bash "$SCRIPT_DIR/../../checks/universal/security/check-pii.sh" --staged 2>&1 || true)
assert_contains "$OUTPUT" "suppress" "staged detects bsn without config"
# With config disable bsn → should pass
echo "disable bsn" > "$DIR2/.config/.pii-config"
OUTPUT=$(cd "$DIR2" && export STAGED="test.md" CPM_FINDINGS_FILE="$DIR2/.tmp/f2.jsonl" && mkdir -p .tmp && bash "$SCRIPT_DIR/../../checks/universal/security/check-pii.sh" --staged 2>&1)
assert_not_contains "$OUTPUT" "suppress" "config disable bsn works"
teardown_project "$DIR2"

teardown_project "$DIR"
echo "=== All pii-detection tests passed ==="
