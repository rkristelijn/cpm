#!/usr/bin/env bash
# check-hooks.sh — Verify git hooks are installed.
# @see ADR-129
source "$(dirname "$0")/../../lib/shell/check.sh"

[[ ! -d .git ]] && exit 0

hooks_dir=$(git config core.hooksPath 2>/dev/null || echo ".git/hooks")

for hook in pre-commit pre-push commit-msg; do
  if [[ ! -x "$hooks_dir/$hook" ]]; then
    findings_add "warning" "$hooks_dir/$hook" "missing-hook" \
      "Git hook '$hook' not installed" \
      "Run: cpm hook" ""
  fi
done
