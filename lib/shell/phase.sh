#!/usr/bin/env bash
# phase.sh — Progressive process enforcement. Each phase unlocks the next.
#
# Phases:
#   1. idea    → can create issues (docs/issues/)
#   2. design  → can create ADRs, branch (docs/adrs/)
#   3. code    → can modify src/, checks/, lib/
#   4. test    → can run tests, modify tests/
#   5. validate → can push, create PR
#
# Usage:
#   cpm phase          — show current phase
#   cpm phase check    — validate you're allowed to do what you're doing
#   cpm phase advance  — try to advance to next phase
#
# @see ADR-026 (V-model process enforcement)
set -o nounset
set -o pipefail

# --- Detect current phase based on repo state ---
detect_phase() {
  local branch issue_exists has_code has_tests

  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")

  # Phase 5: all tests pass, ready to push
  # Phase 4: code + tests exist
  # Phase 3: on feature branch, issue exists
  # Phase 2: issue exists
  # Phase 1: nothing yet

  # Check issue
  issue_exists=false
  if [[ "$branch" == feat/* || "$branch" == fix/* ]]; then
    slug="${branch#*/}"
    [[ -n "$(find docs/issues/open -name '*.md' 2>/dev/null | head -1)" ]] && issue_exists=true
  fi

  # Check code changes
  has_code=false
  git diff --name-only HEAD 2>/dev/null | grep -qE '\.(cpp|ts|js|py|sh|java|go)$' && has_code=true
  git diff --cached --name-only 2>/dev/null | grep -qE '\.(cpp|ts|js|py|sh|java|go)$' && has_code=true

  # Check tests
  has_tests=false
  git diff --name-only HEAD 2>/dev/null | grep -qE 'test|spec' && has_tests=true

  # Determine phase
  if [[ "$branch" == "main" || "$branch" == "master" ]]; then
    echo 1
  elif [[ "$issue_exists" == false ]]; then
    echo 1
  elif [[ "$has_code" == false ]]; then
    echo 3
  elif [[ "$has_tests" == false ]]; then
    echo 3
  else
    echo 4
  fi
}

# --- Show current phase ---
show_phase() {
  local phase=$(detect_phase)
  local branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")

  echo ""
  echo "  Phase $phase/5 — branch: $branch"
  echo ""

  local marks=("○" "○" "○" "○" "○")
  for ((i=0; i<phase; i++)); do marks[$i]="●"; done

  printf "  %s 1. Idee       → issue aanmaken\n" "${marks[0]}"
  printf "  %s 2. Ontwerp    → ADR, branch\n" "${marks[1]}"
  printf "  %s 3. Code       → src/, checks/, lib/\n" "${marks[2]}"
  printf "  %s 4. Test       → tests draaien\n" "${marks[3]}"
  printf "  %s 5. Validatie  → push, PR\n" "${marks[4]}"
  echo ""

  case $phase in
    1) echo "  ▶ Next: cpm issue \"feat: <title>\"" ;;
    2) echo "  ▶ Next: cpm issue branch <slug>" ;;
    3) echo "  ▶ Next: Write code + tests" ;;
    4) echo "  ▶ Next: cpm check" ;;
    5) echo "  ▶ Next: git push && cpm pr" ;;
  esac
  echo ""
}

# --- Check if current action is allowed in current phase ---
check_phase() {
  local phase=$(detect_phase)
  local action="${1:-}"
  local blocked=false
  local msg=""

  case "$action" in
    src|code)
      if ((phase < 3)); then
        blocked=true
        msg="Can't modify code yet — create issue + branch first"
      fi ;;
    test)
      if ((phase < 3)); then
        blocked=true
        msg="Can't test yet — write code first"
      fi ;;
    push)
      if ((phase < 4)); then
        blocked=true
        msg="Can't push yet — tests must pass first"
      fi ;;
    adr|design)
      if ((phase < 1)); then
        blocked=true
        msg="Can't design yet — create issue first"
      fi ;;
  esac

  if [[ "$blocked" == true ]]; then
    echo ""
    echo "  ⚠ Phase $phase: $msg"
    echo ""
    show_phase
    return 1
  fi
  return 0
}

# --- Dispatch ---
case "${1:-}" in
  check) check_phase "${2:-}" ;;
  "") show_phase ;;
  *) show_phase ;;
esac
