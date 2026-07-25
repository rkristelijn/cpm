#!/usr/bin/env bash
# =============================================================================
# check-centralize-patterns.sh — Detect repeated patterns that need abstraction
#
# When the same low-level call appears too many times across a codebase,
# it should be encapsulated in a dedicated module. This check detects:
#
#   Pattern            Threshold  Should become
#   ─────────────────  ─────────  ─────────────────────────
#   console.*          3          logger module
#   fetch/http.get     3          http client module
#   fs.read/write      3          storage module
#   new Date/Date.now  5          clock module (mockable)
#   process.env        5          config module
#   JSON.parse/ify     5          serialization module
#   setTimeout/Interval 3         scheduler module
#   try/catch(same)    3          error handler
#
# Usage: bash checks/check-centralize-patterns.sh [dir]
# =============================================================================

set -o pipefail

DIR="${1:-src}"
ISSUES=0

# Skip tests, node_modules, and the module itself
EXCLUDE="\.test\.\|\.spec\.\|node_modules\|/lib/"

count_pattern() {
  local pattern="$1" exclude_module="$2"
  grep -rn --include="*.js" --include="*.ts" -P "$pattern" "$DIR" 2>/dev/null \
    | grep -v "$EXCLUDE" \
    | grep -v "$exclude_module" \
    | wc -l | tr -d ' '
}

has_module() {
  local pattern_list="$1"
  local IFS='|'
  local pattern
  for pattern in $pattern_list; do
    if find "$DIR" -name "$pattern" 2>/dev/null | grep -q .; then
      echo "true"
      return
    fi
  done
  echo "false"
}

check_pattern() {
  local name="$1" pattern="$2" threshold="$3" module_glob="$4" suggestion="$5"
  local count module_exists

  count=$(count_pattern "$pattern" "$module_glob")
  module_exists=$(has_module "$module_glob")

  if [[ "$count" -gt "$threshold" ]]; then
    if [[ "$module_exists" == "false" ]]; then
      echo "  ✗ $name: $count calls (threshold: $threshold) — no dedicated module found"
      echo "    → Create $suggestion"
      ISSUES=$((ISSUES + 1))
    elif [[ "$count" -gt 0 ]]; then
      # Module exists but still direct calls
      echo "  ✗ $name: module exists but $count direct calls remain"
      ISSUES=$((ISSUES + 1))
    fi
  fi
}

echo "  Centralization audit ($DIR/)"
echo ""

check_pattern \
  "Logging" \
  "console\.(log|info|warn|error|debug)\(" \
  3 "logger*" \
  "a logger module (structured, leveled, configurable format)"

check_pattern \
  "HTTP client" \
  "(fetch|http\.get|http\.request|axios|got)\(" \
  3 "http-client*\|client*\|api*" \
  "an HTTP client module (base URL, headers, timeout, retry)"

check_pattern \
  "File I/O" \
  "(readFile|writeFile|readFileSync|writeFileSync|createReadStream)\(" \
  3 "storage*\|persist*\|store*" \
  "a storage/persistence module"

check_pattern \
  "Date/Time" \
  "(new Date|Date\.now)\(" \
  5 "clock*\|time*" \
  "a clock module (injectable, mockable for tests)"

check_pattern \
  "Environment" \
  "process\.env\." \
  5 "config*\|env*" \
  "a config module (single source of truth for env vars)"

check_pattern \
  "JSON parsing" \
  "JSON\.(parse|stringify)\(" \
  5 "serial*\|parse*\|format*" \
  "a serialization module (with error handling)"

check_pattern \
  "Timers" \
  "(setTimeout|setInterval)\(" \
  3 "scheduler*\|timer*\|worker*" \
  "a scheduler module (manageable, cancellable)"

echo ""
if [[ $ISSUES -gt 0 ]]; then
  echo "  $ISSUES pattern(s) need centralization."
  echo "  Repeated low-level calls → encapsulate in a module for:"
  echo "    • Single config point  • Testability  • Consistency"
  exit 1
else
  echo "  ✓ All patterns properly centralized"
fi
