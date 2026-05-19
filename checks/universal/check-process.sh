#!/usr/bin/env bash
# check-process.sh — Verify process artifacts exist for maturity level.
# @see ADR-129
source "$(dirname "$0")/../../lib/shell/check.sh"

[[ ! -f cpm.toml ]] && exit 0

target=$(grep -A5 '^\[process\]' cpm.toml 2>/dev/null | sed -n 's/^maturity-target *= *//p' | tr -d ' ')
target="${target:-1}"

# Level 1: conventional commits
if ((target >= 1)); then
  if ! git log -1 --format=%s 2>/dev/null | grep -qE '^(feat|fix|docs|test|refactor|chore|ci|perf|style|build)\(?'; then
    findings_add "warning" ".git" "non-conventional-commit" \
      "Last commit doesn't follow conventional commits" \
      "Use: type(scope): description" ""
  fi
fi

# Level 2: branch strategy
if ((target >= 2)); then
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  if [[ "$branch" == "main" || "$branch" == "master" ]]; then
    staged=$(git diff --cached --name-only 2>/dev/null | grep -cE '\.(ts|js|cpp|py|java|go|rs|sh)$')
    if ((staged > 0)); then
      findings_add "warning" ".git" "code-on-main" \
        "Code changes staged on main — use feature branch" \
        "git checkout -b feat/<issue>-<slug>" ""
    fi
  fi
fi

# Level 3: issue reference
if ((target >= 3)); then
  if [[ "$branch" == feat/* || "$branch" == fix/* ]] && ! git log -1 --format=%s 2>/dev/null | grep -qE '#[0-9]+|closes|refs|cpm-'; then
    findings_add "info" ".git" "no-issue-reference" \
      "Commit doesn't reference an issue" \
      "Add 'closes #N' or scope matching issue slug" ""
  fi
fi
