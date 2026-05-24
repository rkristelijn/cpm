#!/usr/bin/env bash
set -o nounset -o pipefail

# findings_add() { printf "  %-8s %-30s %s\n" "$1" "$3" "$4"; }
REPO="${1:-.}"

findings_add() {
    local severity="$1"
    local check="$2"
    local message="$3"
    printf "  %-8s %-30s %s\n" "$severity" "$check" "$message"
}

# Find test files
test_files=$(find "$REPO" -type f \( -name "*test*.py" -o -name "*test*.js" -o -name "*test*.ts" -o -name "*spec*.js" -o -name "*spec*.ts" -o -name "*test*.go" -o -name "*test*.java" \) 2>/dev/null | head -100)
[[ -z "$test_files" ]] && exit 0

# Snapshot abuse (>20 toMatchSnapshot)
for f in $test_files; do
    snapshot_count=$(grep -c "toMatchSnapshot\|toMatchInlineSnapshot" "$f" 2>/dev/null | tail -1 || echo 0)
    snapshot_count=${snapshot_count:-0}
    if [[ "$snapshot_count" =~ ^[0-9]+$ ]] && [[ $snapshot_count -gt 20 ]]; then
        findings_add "warning" "snapshot-abuse" "$f: $snapshot_count snapshot assertions (>20), consider unit tests"
    fi
done

# No assertions (test without expect/assert)
for f in $test_files; do
    has_test=false
    has_assert=false

    if grep -qE "(def\s+test|it\s*\(|test\s*\(|describe\s*\(" "$f" 2>/dev/null; then
        has_test=true
    fi

    if grep -qE "(expect|assert|should\.| chai\.| assert\.)" "$f" 2>/dev/null; then
        has_assert=true
    fi

    if $has_test && ! $has_assert; then
        findings_add "warning" "no-assertions" "$f: test without assertions"
    fi
done

# Flaky indicators
for f in $test_files; do
    # setTimeout in tests
    if grep -qE "setTimeout\s*\(\s*(function|\(\)|=>)" "$f" 2>/dev/null; then
        findings_add "warning" "flaky-timeout" "$f: setTimeout in test, potential flakiness"
    fi

    # Date.now without mock
    if grep -qE "Date\.now\(\)" "$f" 2>/dev/null; then
        if ! grep -qE "mock.*Date|jest\.spyOn.*Date" "$f" 2>/dev/null; then
            findings_add "warning" "flaky-date" "$f: Date.now() without mock, test may be time-dependent"
        fi
    fi

    # Math.random without mock
    if grep -qE "Math\.random\(\)" "$f" 2>/dev/null; then
        if ! grep -qE "mock.*Random|jest\.spyOn.*random" "$f" 2>/dev/null; then
            findings_add "warning" "flaky-random" "$f: Math.random() without mock, test is non-deterministic"
        fi
    fi
done

# Giant test files (>500 lines)
for f in $test_files; do
    lines=$(wc -l < "$f" 2>/dev/null || echo 0)
    if [[ $lines -gt 500 ]]; then
        findings_add "warning" "giant-test-file" "$f: $lines lines (>500), consider splitting"
    fi
done

# No describe/context grouping
for f in $test_files; do
    if grep -qE "(it\s*\(|test\s*\()" "$f" 2>/dev/null; then
        if ! grep -qE "(describe|context|suite)" "$f" 2>/dev/null; then
            findings_add "warning" "no-grouping" "$f: tests without describe/context grouping"
        fi
    fi
done

# Commented-out tests
for f in $test_files; do
    if grep -qE "^\s*//.*test|^\s*#.*test|^\s*<!--.*test" "$f" 2>/dev/null; then
        findings_add "info" "commented-tests" "$f: possible commented-out tests"
    fi
done

# .skip/.only left in code
for f in $test_files; do
    if grep -qE "(\.skip|\.only|skip\s*=|it\.skip|test\.skip|describe\.skip)" "$f" 2>/dev/null; then
        findings_add "error" "skip-only-left" "$f: .skip or .only left in test code"
    fi
done

# No error case tests (only happy path)
for f in $test_files; do
    has_error_test=false
    has_normal_test=false

    if grep -qE "(toThrow|throws|rejects|toThrowError|expect.*throw)" "$f" 2>/dev/null; then
        has_error_test=true
    fi

    if grep -qE "(it\s*\(|test\s*\(|describe\s*\()" "$f" 2>/dev/null; then
        has_normal_test=true
    fi

    if $has_normal_test && ! $has_error_test; then
        findings_add "info" "no-error-tests" "$f: only happy path tests, consider adding error cases"
    fi
done

# Test-to-code ratio <0.5
src_lines=0
test_lines=0

# Count source lines (non-test files)
for f in $(find "$REPO" -type f \( -name "*.py" -o -name "*.js" -o -name "*.ts" -o -name "*.go" -o -name "*.java" \) 2>/dev/null); do
    if [[ "$f" != *test* ]] && [[ "$f" != *spec* ]]; then
        lines=$(wc -l < "$f" 2>/dev/null || echo 0)
        src_lines=$((src_lines + lines))
    else
        lines=$(wc -l < "$f" 2>/dev/null || echo 0)
        test_lines=$((test_lines + lines))
    fi
done

if [[ $src_lines -gt 0 ]]; then
    ratio=$(awk "BEGIN {printf \"%.2f\", $test_lines / $src_lines}")
    is_low=$(awk "BEGIN {print ($ratio < 0.5) ? 1 : 0}")
    if [[ "$is_low" == "1" ]]; then
        findings_add "warning" "low-test-ratio" "Test-to-code ratio: $ratio (<0.5), add more tests"
    fi
fi