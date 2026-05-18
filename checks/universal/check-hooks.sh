#!/usr/bin/env bash
# check-hooks.sh — Verify git hooks match cpm.toml configuration.
#
# Detects:
#   - Hooks enabled in cpm.toml but missing from .git/hooks/
#   - Hooks present in .git/hooks/ but disabled in cpm.toml
#   - Hooks not executable
set -o errexit
set -o nounset
set -o pipefail

FAIL=0

check_hook() {
  local name="$1" enabled="$2"
  local hook_file=".git/hooks/$name"

  if [[ "$enabled" == "true" ]]; then
    if [[ ! -f "$hook_file" ]]; then
      echo "  [hooks] error: $name enabled in cpm.toml but missing"
      echo "    fix: cpm hook"
      FAIL=1
    elif [[ ! -x "$hook_file" ]]; then
      echo "  [hooks] error: $name exists but not executable"
      echo "    fix: chmod +x $hook_file"
      FAIL=1
    else
      echo "  [hooks] ✓ $name"
    fi
  else
    if [[ -f "$hook_file" ]]; then
      echo "  [hooks] warning: $name disabled in cpm.toml but exists in .git/hooks/"
      echo "    fix: cpm unhook  OR  cpm set hooks.$name true"
    fi
  fi
}

# Read hook config from cpm.toml
PRE_COMMIT=$(grep -A5 '^\[hooks\]' cpm.toml 2>/dev/null | sed -n 's/^pre-commit *= *//p' | tr -d ' ')
PRE_PUSH=$(grep -A5 '^\[hooks\]' cpm.toml 2>/dev/null | sed -n 's/^pre-push *= *//p' | tr -d ' ')
COMMIT_MSG=$(grep -A5 '^\[hooks\]' cpm.toml 2>/dev/null | sed -n 's/^commit-msg *= *//p' | tr -d ' ')

# Default to true if [hooks] section missing
PRE_COMMIT="${PRE_COMMIT:-true}"
PRE_PUSH="${PRE_PUSH:-true}"
COMMIT_MSG="${COMMIT_MSG:-false}"

echo "  [hooks] Checking hook consistency..."
check_hook "pre-commit" "$PRE_COMMIT"
check_hook "pre-push" "$PRE_PUSH"
check_hook "commit-msg" "$COMMIT_MSG"

if [[ $FAIL -eq 1 ]]; then
  echo ""
  echo "  [hooks] FAIL — hooks out of sync with cpm.toml"
  exit 1
fi

echo "  [hooks] pass"
