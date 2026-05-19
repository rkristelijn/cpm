#!/usr/bin/env bash
# check-test-architecture.sh — Enforce ADR-130 test patterns.
# Runs BEFORE tests to fail fast on structural violations.
# @see ADR-130 (standardized test architecture)
source "$(dirname "$0")/../../../lib/shell/check.sh"

violations=0

# --- Rule 1: All *_test.cpp must use TEST_SUITE ---
while IFS= read -r file; do
  if ! grep -q "TEST_SUITE" "$file"; then
    findings_add "error" "$file" "missing-test-suite" \
      "Test file must use TEST_SUITE(\"name\") for grouping" \
      "Wrap tests in TEST_SUITE(\"$(basename "$file" _test.cpp)\") { ... }" \
      "https://cpm.dev/checks/test-architecture"
    violations=$((violations + 1))
  fi
done < <(find src -name '*_test.cpp' -not -name 'toml_test.cpp')

# --- Rule 2: All *_test.cpp must use SCENARIO (BDD style) ---
while IFS= read -r file; do
  if ! grep -q "SCENARIO" "$file"; then
    findings_add "warning" "$file" "missing-bdd-style" \
      "Test file should use SCENARIO/GIVEN/WHEN/THEN (BDD style)" \
      "Replace TEST_CASE with SCENARIO/GIVEN/WHEN/THEN" \
      "https://cpm.dev/checks/test-architecture"
  fi
done < <(find src -name '*_test.cpp' -not -name 'toml_test.cpp')

# --- Rule 3: No bare CHECK on .size() without REQUIRE ---
while IFS= read -r file; do
  while IFS=: read -r _ linenum line; do
    # CHECK(x.size() == N) where N > 0 should be REQUIRE
    if echo "$line" | grep -qE 'CHECK\(.*\.size\(\)\s*==\s*[1-9]'; then
      findings_add "warning" "$file:$linenum" "require-before-index" \
        "Use REQUIRE for size checks before indexing (fatal if wrong)" \
        "Change CHECK(x.size() == N) to REQUIRE(x.size() == N)" \
        "https://cpm.dev/checks/test-architecture"
    fi
  done < <(grep -n 'CHECK(.*\.size()' "$file" 2>/dev/null || true)
done < <(find src -name '*_test.cpp')

# --- Rule 4: E2E tests must source helpers.sh ---
while IFS= read -r file; do
  if ! grep -q 'source.*helpers.sh' "$file"; then
    findings_add "error" "$file" "missing-helpers" \
      "E2E test must source helpers.sh for standard setup/teardown" \
      "Add: source \"\$(dirname \"\$0\")/helpers.sh\"" \
      "https://cpm.dev/checks/test-architecture"
  fi
done < <(find tests -name 'test_*.sh' 2>/dev/null)

# --- Rule 5: E2E tests that use BINARY must use resolve_binary ---
while IFS= read -r file; do
  if grep -q 'BINARY\|"$1"' "$file" && ! grep -q 'resolve_binary' "$file"; then
    findings_add "error" "$file" "missing-resolve-binary" \
      "E2E test uses BINARY but doesn't resolve to absolute path" \
      "Add: BINARY=\$(resolve_binary \"\${1:-./cpm}\")" \
      "https://cpm.dev/checks/test-architecture"
  fi
done < <(find tests -name 'test_*.sh' 2>/dev/null)

# --- Rule 6: Test file naming ---
for f in $(find src -name '*test*.cpp' -not -name '*_test.cpp'); do
  findings_add "error" "$f" "test-naming" \
    "Test files must be named <module>_test.cpp" \
    "Rename to $(echo "$f" | sed 's/test//' | sed 's/\.cpp/_test.cpp/')" \
    "https://cpm.dev/checks/test-architecture"
done
