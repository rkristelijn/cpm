#!/usr/bin/env bash
# commit-msg.sh — Validate conventional commit format + process checks.
# @see ADR-129
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
  echo "  ✗ Not a conventional commit."
  echo ""
  echo "  Expected: type(scope): description"
  echo "  Examples: feat: add streaming support"
  echo "            fix(parser): handle empty input"
  echo ""
  echo "  Types: feat fix chore refactor docs test ci style perf build"
  echo ""
  exit 1
fi

# Level 3: feat/fix commits must reference an issue
TARGET=$(grep -A5 '^\[process\]' cpm.toml 2>/dev/null | sed -n 's/^maturity-target *= *//p' | tr -d ' ')
TARGET="${TARGET:-1}"

if ((TARGET >= 3)); then
  if [[ "$MSG" =~ ^(feat|fix) ]]; then
    # Accept: #42, closes #42, refs #42, or (slug) in scope
    if ! [[ "$MSG" =~ (#[0-9]+|closes|fixes|refs|resolves|\(.+\)) ]]; then
      echo ""
      echo "  ✗ feat/fix commit must reference an issue (maturity target ≥ 3)"
      echo "    Use scope:  feat(my-issue-slug): description"
      echo "    Or remote:  feat: description (closes #42)"
      echo ""
      exit 1
    fi
  fi
fi
