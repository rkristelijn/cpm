#!/usr/bin/env bash
# checks/universal/quality/check-shift-left.sh
# @see ADR-129
# Fast shift-left checks on changed files — catches what SonarCloud would flag.
# Only flags issues in NEW code (added lines), not existing code.
# Designed for pre-push: runs in <2s on typical changesets.
set -o nounset -o pipefail

REPO="${1:-.}"
FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-25s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }
error()   { printf "  \033[31merror\033[0m    %-25s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

# Get added lines from diff (only new code)
DIFF=$(git diff origin/main...HEAD 2>/dev/null || git diff HEAD~3 2>/dev/null || true)
[ -z "$DIFF" ] && exit 0

# --- Check added C/C++ lines ---
CPP_ADDED=$(echo "$DIFF" | grep -E '^\+' | grep -Ev '^\+\+\+' || true)

# NULL in new code
if echo "$CPP_ADDED" | grep -qw 'NULL'; then
  file=$(git diff --name-only origin/main...HEAD 2>/dev/null | grep -E '\.(cpp|h)$' | xargs grep -lw 'NULL' 2>/dev/null | head -1)
  [ -n "$file" ] && finding "use-nullptr" "$file — new code uses NULL, use nullptr"
fi

# localtime (not thread-safe) in new code
if echo "$CPP_ADDED" | grep -q 'localtime(' | grep -v '_r('; then
  finding "unsafe-localtime" "New code uses localtime() — use localtime_r()"
fi

# --- Check added JS/TS lines ---
JS_ADDED=$(echo "$DIFF" | awk '/^\+\+\+ b\/.*\.(js|ts|tsx|jsx)/{file=$2} /^\+[^+]/{if(file)print file": "$0}' || true)

# console.log in new code
if echo "$JS_ADDED" | grep -q 'console\.log('; then
  finding "console-log" "New code has console.log() — remove before push"
fi

# 'as any' in new code
if echo "$JS_ADDED" | grep -q 'as any'; then
  finding "ts-any" "New code uses 'as any' — use proper type"
fi

# TODO without ticket
if echo "$JS_ADDED" | grep -qE 'TODO|FIXME' && ! echo "$JS_ADDED" | grep -qE 'TODO.*\[.*-[0-9]|FIXME.*\[.*-[0-9]'; then
  finding "todo-no-ticket" "New TODO/FIXME without ticket reference — add [CPM-123]"
fi

# --- Check added shell scripts ---
CHANGED_SH=$(git diff --name-only origin/main...HEAD 2>/dev/null | grep '\.sh$' || true)
if [ -n "$CHANGED_SH" ] && command -v shellcheck >/dev/null 2>&1; then
  while IFS= read -r file; do
    [ -f "$file" ] || continue
    errors=$(shellcheck -S error -f gcc "$file" 2>/dev/null | wc -l | tr -d ' ')
    [ "$errors" -gt 0 ] && error "shellcheck" "$file — $errors error(s)"
  done <<< "$CHANGED_SH"
fi

# --- Summary ---
if [ "$FINDINGS" -gt 0 ]; then
  echo ""
  echo "  $FINDINGS issue(s) in new code — fix before push"
  exit 1
fi
exit 0
