#!/usr/bin/env bash
# check-process.sh — Enforce V-model process based on maturity target.
# Called by pre-commit and commit-msg hooks.
#
# Checks (by level):
#   Level 2: no commit on main, branch must exist
#   Level 3: code requires tests, commit references issue
set -o errexit
set -o nounset
set -o pipefail

# Read maturity target from cpm.toml (default: 1 = no process enforcement)
TARGET=$(grep -A5 '^\[process\]' cpm.toml 2>/dev/null | sed -n 's/^maturity-target *= *//p' | tr -d ' ')
TARGET="${TARGET:-1}"

BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
FAIL=0

# --- Level 2: Branch discipline ---
if ((TARGET >= 2)); then
  if [[ "$BRANCH" == "main" || "$BRANCH" == "master" ]]; then
    # Allow non-code commits on main (docs, config, ci, checks)
    STAGED=$(git diff --cached --name-only 2>/dev/null)
    HAS_SRC=$(echo "$STAGED" | grep -c '^src/.*\.\(cpp\|c\|h\|hpp\|ts\|js\|py\|rs\)$' || true)
    if ((HAS_SRC > 0)); then
      echo "  ✗ 2.0  No code commits on $BRANCH (maturity target ≥ 2)"
      echo "         → Create a branch: cpm issue branch <slug>"
      FAIL=1
    fi
  fi
fi

# --- Level 3: Code requires tests ---
if ((TARGET >= 3)); then
  STAGED=$(git diff --cached --name-only 2>/dev/null)
  HAS_SRC=$(echo "$STAGED" | grep -c '^src/.*\.\(cpp\|c\|ts\|js\|py\|rs\)$' || true)
  HAS_TEST=$(echo "$STAGED" | grep -c '_test\|test_\|\.test\.\|\.spec\.' || true)

  if ((HAS_SRC > 0 && HAS_TEST == 0)); then
    echo "  ✗ 3.1  Code change without tests (maturity target ≥ 3)"
    echo "         → Add tests: cpm new test <name>"
    FAIL=1
  fi
fi

if ((FAIL == 1)); then
  echo ""
  echo "  Process blocked. Override: git commit --no-verify"
  echo "  Relax: cpm set process.maturity-target $((TARGET - 1))"
  exit 1
fi
