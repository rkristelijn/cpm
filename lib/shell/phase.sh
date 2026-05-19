#!/usr/bin/env bash
# phase.sh — Process-guided development with exit criteria per phase.
#
# Phases + exit criteria:
#   1. IDEE    → exit: issue exists in docs/issues/open/
#   2. BRANCH  → exit: not on main, branch contains slug
#   3. CODE    → exit: staged code + tests
#   4. CHECK   → exit: cpm check --fast passes
#   5. PUSH    → exit: pushed + PR
#
# @see ADR-026
set -o nounset
set -o pipefail

PHASE_FILE=".cpm-phase"
PHASE_LOG=".tmp/phase.log"

is_active() { [[ -f "$PHASE_FILE" ]]; }

log_block() {
  mkdir -p .tmp
  printf "%s | phase=%s | %s\n" "$(date +%Y-%m-%dT%H:%M:%S)" "$1" "$2" >> "$PHASE_LOG"
}

# --- Exit criteria checks (return 0 = met, 1 = not met) ---
check_phase1() { # IDEE: issue exists
  find docs/issues/open -name '*.md' 2>/dev/null | grep -q . 
}

check_phase2() { # BRANCH: not on main
  local branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
  [[ "$branch" != "main" && "$branch" != "master" ]]
}

check_phase3() { # CODE: staged code + tests
  local staged=$(git diff --cached --name-only 2>/dev/null)
  local has_code=$(echo "$staged" | grep -cE '\.(cpp|ts|js|py|sh|java|go|rs|h)$' || true)
  local has_tests=$(echo "$staged" | grep -cE 'test|spec' || true)
  ((has_code > 0 && has_tests > 0))
}

check_phase4() { # CHECK: build passes
  cpm check --fast >/dev/null 2>&1
}

# --- Detect current phase (highest completed) ---
detect_phase() {
  check_phase1 || { echo 1; return; }
  check_phase2 || { echo 1; return; }
  # On feature branch with issue = phase 3
  echo 3
}

# --- Pre-commit enforcement ---
do_check() {
  is_active || exit 0

  local branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
  local staged=$(git diff --cached --name-only 2>/dev/null)
  local code_staged=$(echo "$staged" | grep -cE '\.(cpp|ts|js|py|sh|java|go|rs|h|hpp)$' || true)

  # On main with code → must be in phase 2+ first
  if [[ "$branch" == "main" || "$branch" == "master" ]] && ((code_staged > 0)); then
    echo ""
    echo "  ⛔ Phase 1 — create issue + branch first"
    echo ""
    echo "    1. cpm issue \"feat: <title>\""
    echo "    2. cpm issue branch <slug>"
    echo ""
    log_block "1" "code on main"
    exit 1
  fi

  # On feature branch, code without tests → warn
  if ((code_staged > 0)); then
    local test_staged=$(echo "$staged" | grep -cE 'test|spec' || true)
    if ((test_staged == 0)); then
      echo "  ⚠ Phase 3 — code without tests. Add tests."
      log_block "3" "code without tests"
    fi
  fi
}

# --- Show status ---
do_status() {
  local phase=$(detect_phase)
  local branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
  local active=$(is_active && echo "ON" || echo "OFF")

  echo ""
  echo "  cpm phase — enforcement: $active"
  echo ""

  # Check each exit criteria
  local p1="○" p2="○" p3="○" p4="○" p5="○"
  check_phase1 && p1="●"
  check_phase2 && p2="●"

  printf "  %s 1. Idee    → issue exists\n" "$p1"
  printf "  %s 2. Branch  → not on main\n" "$p2"
  printf "  %s 3. Code    → staged code + tests\n" "$p3"
  printf "  %s 4. Check   → cpm check passes\n" "$p4"
  printf "  %s 5. Push    → PR created\n" "$p5"
  echo ""

  # Show next action
  if [[ "$p1" == "○" ]]; then
    echo "  ▶ cpm issue \"feat: <title>\""
  elif [[ "$p2" == "○" ]]; then
    echo "  ▶ cpm issue branch <slug>"
  else
    echo "  ▶ Write code + tests, then: cpm check"
  fi
  echo ""
}

# --- Dispatch ---
case "${1:-}" in
  on)    echo "on" > "$PHASE_FILE"; echo "  ✓ Phase enforcement ON" ;;
  off)   rm -f "$PHASE_FILE"; echo "  ✓ Phase enforcement OFF" ;;
  check) do_check ;;
  *)     do_status ;;
esac
