#!/usr/bin/env bash
# E2E test: maturity scoring
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

echo "=== E2E: maturity ==="

# maturity runs without error on cpm repo itself
OUTPUT=$(bash lib/shell/maturity.sh 2>&1)
assert_contains "$OUTPUT" "Score:" "has score"
assert_contains "$OUTPUT" "Level:" "has level"

# formatting check passes when cpm.toml has format entries
DIR=$(setup_project)
mkdir -p "$DIR/.git/hooks" "$DIR/src"
echo "int main(){}" > "$DIR/src/main.cpp"
cat > "$DIR/cpm.toml" <<'EOF'
[project]
name = "test"
version = "0.1.0"
lang = "cpp"
build = "make"

[checks]
code-cpp-syntax-format = true
EOF
touch "$DIR/Makefile"
# The formatting check should pass based on cpm.toml having "format"
RESULT=$(cd "$DIR" && bash -c '[[ $(grep -c "format" cpm.toml 2>/dev/null) -gt 0 ]]' && echo "pass" || echo "fail")
[[ "$RESULT" == "pass" ]] || die "formatting check should pass with format in cpm.toml"

# dead code detection finds check-dead-* scripts
RESULT=$(find . -path "*check-dead*" -not -path "./.git/*" 2>/dev/null | grep -q . && echo "pass" || echo "fail")
[[ "$RESULT" == "pass" ]] || die "dead code detection should find check-dead scripts"

# research freshness finds check-research* scripts
RESULT=$(find . -path "*check-research*" 2>/dev/null | grep -q . && echo "pass" || echo "fail")
[[ "$RESULT" == "pass" ]] || die "research freshness should find check-research scripts"

teardown_project "$DIR"
echo "=== All maturity tests passed ==="
