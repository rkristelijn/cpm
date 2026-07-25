#!/usr/bin/env bash
# =============================================================================
# check-shared-separation.sh — Enforce shared/ for utility modules
#
# Utility/infra modules (logger, config, clock, http-client, etc.) should
# live in a shared/ directory, not mixed with app-specific code.
#
# This keeps app code focused on business logic and shared code reusable.
#
# Rule: if src/ contains files named like common utilities, they should
# be in src/shared/ (or a configured path).
#
# Usage: bash checks/check-shared-separation.sh [src-dir]
# =============================================================================

set -o pipefail

DIR="${1:-src}"
SHARED_DIR="$DIR/shared"
ISSUES=0

# Utility module names that belong in shared/
UTILITY_PATTERNS=(
  "logger"
  "config"
  "clock"
  "time"
  "http-client"
  "api-client"
  "storage"
  "cache"
  "serializer"
  "validator"
  "constants"
  "errors"
  "types"
  "utils"
  "helpers"
)

echo "  Shared module separation ($DIR/)"

for pattern in "${UTILITY_PATTERNS[@]}"; do
  # Find files matching this utility name in src root (not in shared/)
  MISPLACED=$(find "$DIR" -maxdepth 1 -name "*${pattern}*" -type f 2>/dev/null)
  if [[ -n "$MISPLACED" ]]; then
    for file in $MISPLACED; do
      echo "  ✗ $(basename "$file") belongs in $SHARED_DIR/ (utility module)"
      ISSUES=$((ISSUES + 1))
    done
  fi
done

if [[ $ISSUES -gt 0 ]]; then
  echo ""
  echo "  $ISSUES utility module(s) in app root. Move to $SHARED_DIR/"
  echo ""
  echo "  Structure should be:"
  echo "    $SHARED_DIR/        ← Reusable utilities (logger, config, clock)"
  echo "    $DIR/              ← App-specific code (router, worker, state)"
  exit 1
else
  # Verify shared/ exists if project is non-trivial
  FILE_COUNT=$(find "$DIR" -maxdepth 1 -name "*.js" -o -name "*.ts" | wc -l | tr -d ' ')
  if [[ "$FILE_COUNT" -gt 5 ]] && [[ ! -d "$SHARED_DIR" ]]; then
    echo "  ⚠ Project has $FILE_COUNT source files but no shared/ directory"
    echo "    Consider: logger, config, constants → $SHARED_DIR/"
  else
    echo "  ✓ Utility modules properly separated in $SHARED_DIR/"
  fi
fi
