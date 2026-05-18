#!/usr/bin/env bash
# commit-msg.sh — Validate conventional commit format.
# Used as .git/hooks/commit-msg when hooks are installed.
set -o errexit
set -o nounset
set -o pipefail

MSG_FILE="$1"
MSG=$(head -1 "$MSG_FILE")

# Allow merge commits
[[ "$MSG" =~ ^Merge ]] && exit 0

PATTERN="^(feat|fix|chore|refactor|docs|test|ci|style|perf|build)(\(.+\))?!?: .{1,72}$"

if ! [[ "$MSG" =~ $PATTERN ]]; then
  echo ""
  echo "  ERROR: Not a conventional commit."
  echo ""
  echo "  Expected: type(scope): description"
  echo "  Examples: feat: add streaming support"
  echo "            fix(parser): handle empty input"
  echo ""
  echo "  Types: feat fix chore refactor docs test ci style perf build"
  echo ""
  exit 1
fi
