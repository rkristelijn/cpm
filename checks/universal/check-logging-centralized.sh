#!/usr/bin/env bash
# =============================================================================
# check-logging-centralized.sh — Enforce centralized logging
#
# Rule: if a project has more than THRESHOLD direct console.* calls,
# it should have a logger module. Scattered console statements are:
#   - Inconsistent format
#   - Hard to switch between JSON/plain
#   - Hard to filter by level
#   - Not configurable at runtime
#
# Usage: bash checks/check-logging-centralized.sh [dir] [threshold]
# =============================================================================

set -o pipefail

DIR="${1:-src}"
THRESHOLD="${2:-3}"

# Count console.* calls in production code (exclude tests, logger itself)
COUNT=$(grep -rn --include="*.js" --include="*.ts" \
  -P "console\.(log|info|warn|error|debug)\(" "$DIR" 2>/dev/null \
  | grep -v "\.test\.\|\.spec\.\|logger\.\|// lint-ok" \
  | wc -l | tr -d ' ')

# Check if a logger module exists
HAS_LOGGER=false
if find "$DIR" -name "logger.*" -o -name "log.*" | grep -q .; then
  HAS_LOGGER=true
fi

echo "  Logging audit ($DIR/)"
echo "    console.* calls: $COUNT (threshold: $THRESHOLD)"
echo "    logger module: $HAS_LOGGER"

if [[ "$COUNT" -gt "$THRESHOLD" ]] && [[ "$HAS_LOGGER" == "false" ]]; then
  echo ""
  echo "  ✗ $COUNT console calls without a logger module."
  echo "    Create a centralized logger (src/logger.js) that handles:"
  echo "      - Structured output (JSON for prod, plain for dev)"
  echo "      - Log levels (info, warn, error)"
  echo "      - Timestamp + context"
  echo "    Then replace console.* with logger.*"
  exit 1
fi

if [[ "$COUNT" -gt 0 ]] && [[ "$HAS_LOGGER" == "true" ]]; then
  echo ""
  echo "  ✗ Logger exists but $COUNT direct console calls remain."
  echo "    Replace them with logger.info/warn/error:"
  grep -rn --include="*.js" --include="*.ts" \
    -P "console\.(log|info|warn|error|debug)\(" "$DIR" 2>/dev/null \
    | grep -v "\.test\.\|\.spec\.\|logger\.\|// lint-ok" \
    | head -10 | sed 's/^/      /'
  exit 1
fi

echo "  ✓ Logging is clean"
