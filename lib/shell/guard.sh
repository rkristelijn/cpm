#!/usr/bin/env bash
# cpm:ignore-file SH-QUAL-014 — detector/test source: contains the patterns it checks for
# guard.sh — Enforce cpm process by blocking direct tool usage.
#
# Usage:
#   eval "$(cpm guard on)"   — activate guards
#   eval "$(cpm guard off)"  — deactivate guards
#
# When active, direct calls to grep/find/make test/git push etc.
# are intercepted with a message pointing to the cpm equivalent.
#
# @see ADR-026 (V-model process enforcement)

case "${1:-}" in
  on)
    cat << 'GUARDS'
# cpm guard mode — active
export CPM_GUARD=1

cpm_blocked() {
  echo ""
  echo "  ⚠ cpm guard: '$1' is blocked in guard mode"
  echo "  → Use: $2"
  echo ""
  return 1
}

# Search → cpm grep / cpm search
grep() { cpm_blocked "grep" "cpm search <pattern>"; }
find() { cpm_blocked "find" "cpm search / cpm scan"; }
rg() { cpm_blocked "rg" "cpm search <pattern>"; }
ag() { cpm_blocked "ag" "cpm search <pattern>"; }

# Build/test → cpm check
make() {
  case "${1:-}" in
    build) cpm_blocked "make build" "cpm build" ;;
    test*) cpm_blocked "make test" "cpm test" ;;
    *) command make "$@" ;;
  esac
}

# Git → hooks enforce process, guard blocks merge to main + checkout main
git() {
  case "${1:-}" in
    merge)
      if [[ "${*}" == *main* || "${*}" == *master* ]]; then
        cpm_blocked "git merge main" "make pr-create && make pr-merge (via PR + pipeline)"
      else
        command git "$@"
      fi ;;
    checkout)
      if [[ "${2:-}" == "main" || "${2:-}" == "master" ]] && [[ -f .cpm-phase ]]; then
        cpm_blocked "git checkout main (phase active)" "Finish current work first, then: cpm phase off && git checkout main"
      else
        command git "$@"
      fi ;;
    push)
      if [[ "${2:-}" == *main* || "${2:-}" == *master* ]]; then
        cpm_blocked "git push main" "make pr-create (use PR + pipeline)"
      else
        command git "$@"
      fi ;;
    *) command git "$@" ;;
  esac
}

# Direct lint/format → cpm check
eslint() { cpm_blocked "eslint" "cpm lint"; }
prettier() { cpm_blocked "prettier" "cpm format"; }
clang-format() { cpm_blocked "clang-format" "cpm format"; }

echo "  ✓ cpm guard mode ON — use cpm commands instead of direct tools"
GUARDS
    ;;

  off)
    cat << 'UNGUARD'
unset CPM_GUARD
unset -f cpm_blocked grep find rg ag make git eslint prettier clang-format 2>/dev/null
echo "  ✓ cpm guard mode OFF"
UNGUARD
    ;;

  status)
    if [[ "${CPM_GUARD:-}" == "1" ]]; then
      echo "  cpm guard: ON"
    else
      echo "  cpm guard: OFF"
    fi
    ;;

  *)
    echo "Usage: eval \"\$(cpm guard on)\"   — activate"
    echo "       eval \"\$(cpm guard off)\"  — deactivate"
    echo "       cpm guard status"
    ;;
esac
