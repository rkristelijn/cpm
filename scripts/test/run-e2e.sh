#!/usr/bin/env bash
# run-e2e.sh — Run all end-to-end tests with profiling.
# Usage: bash scripts/test/run-e2e.sh [binary]
# Env: TEST_WARN_MS=5000 (warn if test exceeds this, default 5s)
#      TEST_FAIL_MS=30000 (fail if test exceeds this, default 30s)

set -o errexit
set -o nounset
set -o pipefail

BINARY="${1:-./cpm}"
WARN_MS="${TEST_WARN_MS:-5000}"
FAIL_MS="${TEST_FAIL_MS:-30000}"

if [[ ! -x "$BINARY" ]]; then
  echo "ERROR: binary not found at $BINARY — run make build first"
  exit 1
fi

echo "==> running e2e tests against $BINARY..."
echo "    (warn > ${WARN_MS}ms, fail > ${FAIL_MS}ms)"
echo ""
PASS=0
FAIL=0
SLOW=0
TIMINGS=""

for t in tests/e2e/test_*.sh; do
  start_ns=$(date +%s%N 2>/dev/null || echo 0)
  if bash "$t" "$BINARY" >/dev/null 2>&1; then
    end_ns=$(date +%s%N 2>/dev/null || echo 0)
    ms=$(((end_ns - start_ns) / 1000000))
    if ((ms > FAIL_MS)); then
      printf "  \033[31m✗ %5dms\033[0m %s (TIMEOUT — exceeds %dms)\n" "$ms" "$(basename "$t")" "$FAIL_MS"
      FAIL=$((FAIL + 1))
    elif ((ms > WARN_MS)); then
      printf "  \033[33m⚠ %5dms\033[0m %s (slow — exceeds %dms)\n" "$ms" "$(basename "$t")" "$WARN_MS"
      PASS=$((PASS + 1))
      SLOW=$((SLOW + 1))
    else
      printf "  \033[32m✓ %5dms\033[0m %s\n" "$ms" "$(basename "$t")"
      PASS=$((PASS + 1))
    fi
    TIMINGS="${TIMINGS}${ms} $(basename "$t")\n"
  else
    end_ns=$(date +%s%N 2>/dev/null || echo 0)
    ms=$(((end_ns - start_ns) / 1000000))
    printf "  \033[31m✗ %5dms\033[0m %s (FAILED)\n" "$ms" "$(basename "$t")"
    bash "$t" "$BINARY" 2>&1 | tail -3 | sed 's/^/    /' || true
    FAIL=$((FAIL + 1))
    TIMINGS="${TIMINGS}${ms} $(basename "$t")\n"
  fi
done

echo ""
echo "  Results: $PASS passed, $FAIL failed, $SLOW slow (total $((PASS + FAIL)))"

if ((SLOW > 0)); then
  echo ""
  echo "  ⚠ Slow tests (>${WARN_MS}ms) — check CPM_MOCK coverage:"
  printf "$TIMINGS" | sort -rn | head -5 | while read ms name; do
    if ((ms > WARN_MS)); then echo "    ${ms}ms $name"; fi
  done
fi

[[ $FAIL -eq 0 ]] || exit 1
