#!/usr/bin/env bash
# phase.sh — Process enforcement. Always active. Escape requires explicit unlock.
#
# Default: ON (no file needed)
# Escape:  cpm phase unlock "reason" → creates .cpm/unlock (expires after 1 commit)
# Status:  cpm phase
#
# @see ADR-026
set -o nounset
set -o pipefail

CPM_DIR=".cpm"
UNLOCK_FILE="$CPM_DIR/unlock"
PHASE_LOG="$CPM_DIR/phase.log"

mkdir -p "$CPM_DIR"

is_unlocked() {
  [[ -f "$UNLOCK_FILE" ]]
}

log_event() {
  printf "%s | %s\n" "$(date +%Y-%m-%dT%H:%M:%S)" "$1" >> "$PHASE_LOG"
}

consume_unlock() {
  # Unlock is single-use: consumed after one commit
  if [[ -f "$UNLOCK_FILE" ]]; then
    local reason=$(cat "$UNLOCK_FILE")
    log_event "unlock consumed (was: $reason)"
    rm -f "$UNLOCK_FILE"
  fi
}

# --- Commands ---
case "${1:-}" in
  unlock)
    reason="${2:-}"
    if [[ ${#reason} -lt 5 ]]; then echo "  ✗ Provide a reason (min 5 chars): cpm phase unlock "reason""; exit 1; fi
    echo "$reason" > "$UNLOCK_FILE"
    log_event "UNLOCKED: $reason"
    echo "  ⚠ Phase unlocked for 1 commit: $reason"
    echo "    Lock re-engages after next commit."
    ;;

  lock)
    rm -f "$UNLOCK_FILE"
    log_event "manually locked"
    echo "  ✓ Phase locked (always-on mode)"
    ;;

  log)
    cat "$PHASE_LOG" 2>/dev/null || echo "  (no events yet)"
    ;;

  check)
    # Called by pre-commit hook
    if is_unlocked; then
      log_event "commit allowed (unlocked)"
      consume_unlock
      exit 0
    fi

    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
    staged=$(git diff --cached --name-only 2>/dev/null)
    code_staged=$(echo "$staged" | grep -cE '\.(cpp|ts|js|py|sh|java|go|rs|h|hpp)$' || true)

    # Block: code on main
    if [[ "$branch" == "main" || "$branch" == "master" ]] && ((code_staged > 0)); then
      echo ""
      echo "  ⛔ BLOCKED — code on main"
      echo ""
      echo "    1. cpm issue \"feat: <title>\""
      echo "    2. cpm issue branch <slug>"
      echo ""
      echo "  Stuck? cpm phase unlock \"reason\""
      echo ""
      log_event "BLOCKED: code on main ($code_staged files)"
      exit 1
    fi

    # Warn: code without tests
    if ((code_staged > 0)); then
      test_staged=$(echo "$staged" | grep -cE 'test|spec' || true)
      if ((test_staged == 0)); then
        echo "  ⛔ BLOCKED — code without tests"
        log_event "BLOCKED: code without tests"
        exit 1
      fi
    fi

    exit 0
    ;;

  *)
    # Status display
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
    unlocked=$(is_unlocked && echo "UNLOCKED ($(cat "$UNLOCK_FILE"))" || echo "LOCKED ✓")

    echo ""
    echo "  cpm phase — $unlocked"
    echo "  branch: $branch"
    echo ""

    # Exit criteria
    p1="○" p2="○"
    find docs/issues/open -name '*.md' 2>/dev/null | grep -q . && p1="●"
    [[ "$branch" != "main" && "$branch" != "master" ]] && p2="●"

    printf "  %s 1. Idee    → issue exists\n" "$p1"
    printf "  %s 2. Branch  → not on main\n" "$p2"
    printf "  ○ 3. Code    → staged code + tests\n"
    printf "  ○ 4. Check   → cpm check passes\n"
    printf "  ○ 5. Push    → PR + pipeline green\n"
    echo ""

    if [[ "$p1" == "○" ]]; then
      echo "  ▶ cpm issue \"feat: <title>\""
    elif [[ "$p2" == "○" ]]; then
      echo "  ▶ cpm issue branch <slug>"
    else
      echo "  ▶ Write code + tests, then commit"
    fi
    echo ""
    ;;
esac
