#!/usr/bin/env bash
# phase.sh — Process-guided development. Enforces V-model phases.
#
# Usage:
#   cpm phase          — show current phase
#   cpm phase on       — enable enforcement (writes .cpm-phase)
#   cpm phase off      — disable enforcement (removes .cpm-phase)
#   cpm phase check    — called by hooks, blocks if phase violated
#
# @see ADR-026 (V-model process enforcement)
set -o nounset
set -o pipefail

PHASE_FILE=".cpm-phase"
PHASE_LOG=".tmp/phase.log"

# --- Phase detection ---
detect_phase() {
  local branch
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")

  if [[ "$branch" == "main" || "$branch" == "master" ]]; then
    echo 1; return
  fi

  # On feature branch = at least phase 3 (code)
  local has_tests=false
  git diff --cached --name-only 2>/dev/null | grep -qE 'test|spec' && has_tests=true

  if [[ "$has_tests" == true ]]; then
    echo 4
  else
    echo 3
  fi
}

# --- Log a block event ---
log_block() {
  mkdir -p .tmp
  printf "%s | phase=%s | blocked: %s\n" "$(date +%Y-%m-%dT%H:%M:%S)" "$1" "$2" >> "$PHASE_LOG"
}

# --- Check if enforcement is active ---
is_active() {
  [[ -f "$PHASE_FILE" ]]
}

# --- Commands ---
case "${1:-}" in
  on)
    echo "on" > "$PHASE_FILE"
    echo "  ✓ Process enforcement ON"
    echo "    Phases will be checked on every commit."
    echo "    Disable: cpm phase off"
    ;;

  off)
    rm -f "$PHASE_FILE"
    echo "  ✓ Process enforcement OFF"
    ;;

  check)
    # Called by pre-commit hook. Only enforces if active.
    if ! is_active; then
      exit 0
    fi

    phase=$(detect_phase)
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
    staged=$(git diff --cached --name-only 2>/dev/null)

    # Phase 1 (main): block code changes
    if ((phase == 1)); then
      code_staged=$(echo "$staged" | grep -cE '\.(cpp|ts|js|py|sh|java|go|rs|h|hpp)$' || true)
      if ((code_staged > 0)); then
        echo ""
        echo "  ⚠ BLOCKED: You're on '$branch' (phase 1)"
        echo ""
        echo "  Process requires:"
        echo "    1. Create issue:  cpm issue \"feat: <title>\""
        echo "    2. Create branch: cpm issue branch <slug>"
        echo "    3. Then write code"
        echo ""
        log_block "$phase" "code on main ($code_staged files)"
        exit 1
      fi
    fi

    # Phase 3 (code): warn if no tests in commit
    if ((phase == 3)); then
      code_staged=$(echo "$staged" | grep -cE '\.(cpp|ts|js|py|java|go|rs)$' || true)
      test_staged=$(echo "$staged" | grep -cE 'test|spec' || true)
      if ((code_staged > 0 && test_staged == 0)); then
        echo ""
        echo "  ⚠ WARNING: Code without tests (phase 3)"
        echo "    Consider adding tests with your code changes."
        echo ""
        log_block "$phase" "code without tests ($code_staged files)"
        # Warning only, don't block
      fi
    fi

    exit 0
    ;;

  ""|status)
    phase=$(detect_phase)
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
    active=$(is_active && echo "ON" || echo "OFF")

    echo ""
    echo "  Phase $phase/5 — branch: $branch — enforcement: $active"
    echo ""

    marks=("○" "○" "○" "○" "○")
    for ((i=0; i<phase; i++)); do marks[$i]="●"; done

    printf "  %s 1. Idee       → cpm issue \"feat: ...\"\n" "${marks[0]}"
    printf "  %s 2. Ontwerp    → cpm issue branch <slug>\n" "${marks[1]}"
    printf "  %s 3. Code       → write code + tests\n" "${marks[2]}"
    printf "  %s 4. Test       → cpm check\n" "${marks[3]}"
    printf "  %s 5. Validatie  → git push\n" "${marks[4]}"
    echo ""

    if [[ "$active" == "OFF" ]]; then
      echo "  Enable: cpm phase on"
    fi
    echo ""
    ;;
esac
