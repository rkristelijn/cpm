#!/usr/bin/env bash
# checks/universal/quality/check-shell-help.sh
# @see ADR-129
# Check that user-facing shell scripts have --help/usage text
source "$(dirname "$0")/../../../lib/shell/check.sh"
cpm_check_enabled "shell-help" || exit 0
set -o nounset -o pipefail

REPO="${1:-.}"

# Collect user-facing scripts:
# 1. Scripts in bin/, scripts/, tools/ directories
# 2. .sh files in repo root with a shebang
CANDIDATE_SCRIPTS=""

# Scripts in tool directories
for dir in bin scripts tools; do
  if [ -d "$REPO/$dir" ]; then
    FOUND=$(find "$REPO/$dir" -name '*.sh' -type f \
      -not -path "*/node_modules/*" \
      -not -path "*/vendor/*" \
      -not -path "*/.git/*" \
      2>/dev/null) || true
    [ -n "$FOUND" ] && CANDIDATE_SCRIPTS="$CANDIDATE_SCRIPTS
$FOUND"
  fi
done

# Root-level .sh files with a shebang
for f in "$REPO"/*.sh; do
  [ -f "$f" ] || continue
  if head -1 "$f" | grep -qE '^#!.*(bash|sh)' 2>/dev/null; then
    CANDIDATE_SCRIPTS="$CANDIDATE_SCRIPTS
$f"
  fi
done

# Trim leading blank line
CANDIDATE_SCRIPTS=$(echo "$CANDIDATE_SCRIPTS" | sed '/^$/d')
[ -z "$CANDIDATE_SCRIPTS" ] && exit 0

while IFS= read -r script; do
  [ -z "$script" ] && continue
  [ ! -f "$script" ] && continue

  BASENAME=$(basename "$script")

  # Skip library/internal scripts
  case "$BASENAME" in
    # Skip check scripts, hooks, library files, init/helper scripts
    check-*|lint-*|format-*|pre-commit|pre-push|commit-msg|*.lib.sh) continue ;;
  esac

  # Skip scripts inside checks/ or lib/ or hooks/ directories
  case "$script" in
    */checks/*|*/lib/*|*/hooks/*|*/.git/*) continue ;;
  esac

  # Look for --help handling or usage text
  if ! grep -qiE '\-\-help|[Uu]sage:|[Uu]sage()' "$script" 2>/dev/null; then
    findings_add "info" "$script" "shell-no-help" \
      "User-facing script without --help or usage text" \
      "Add a --help flag or Usage: comment so users know how to run it" \
      ""
  fi

done <<< "$CANDIDATE_SCRIPTS"
