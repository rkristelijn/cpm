#!/usr/bin/env bash
# checks/universal/quality/check-windows-portability.sh
# @see ADR-129
# Detects POSIX-only code that will break on Windows builds.
# Catches: unguarded sys/wait.h, fork(), pipe(), d_type, DT_DIR, etc.
source "$(dirname "$0")/../../../lib/shell/check.sh" 2>/dev/null || true
set -o nounset -o pipefail

REPO="${1:-.}"
FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

# Only check C/C++ files
FILES=$(find "$REPO" -type f \( -name "*.c" -o -name "*.cpp" -o -name "*.h" -o -name "*.hpp" \) \
  -not -path "*/.git/*" -not -path "*/node_modules/*" -not -path "*/vendor/*" 2>/dev/null)

[ -z "$FILES" ] && exit 0

# Patterns that break on Windows without #ifdef _WIN32 guards
POSIX_PATTERNS=(
  "sys/wait.h"
  "sys/time.h"
  "unistd.h"
  "fork()"
  "pipe("
  "waitpid("
  "dup2("
  "->d_type"
  "DT_DIR"
  "DT_REG"
  "WIFEXITED"
  "WEXITSTATUS"
  "sigaction"
  "kill("
)

for file in $FILES; do
  for pattern in "${POSIX_PATTERNS[@]}"; do
    # Check if pattern exists without being in a comment, #define, or #ifndef
    matches=$(grep -n "$pattern" "$file" 2>/dev/null | grep -v "^[[:space:]]*//" | grep -v "#define\|#ifndef\|#ifdef\|#if " || true)
    [ -z "$matches" ] && continue

    # Check if file has _WIN32 guards
    if grep -q "_WIN32\|WIN32\|__MINGW" "$file" 2>/dev/null; then
      # Has guards — check if each occurrence is inside a guarded block
      while IFS= read -r match; do
        linenum="${match%%:*}"
        # Look backwards for preprocessor context
        before=$(sed -n "1,${linenum}p" "$file" | grep -n "#if\|#else\|#endif" | tail -5)
        # If the nearest directive before this line is #else or #ifndef _WIN32, it's guarded
        last_directive=$(echo "$before" | tail -1)
        if echo "$last_directive" | grep -q "#else\|#ifndef.*_WIN32\|#if.*!.*_WIN32"; then
          continue  # Inside POSIX-only block, correctly guarded
        fi
        # If inside #ifdef _WIN32 block, also fine (it's the Windows alternative)
        if echo "$last_directive" | grep -q "#ifdef.*_WIN32\|#if.*defined.*_WIN32"; then
          continue
        fi
        finding "posix-unguarded" "$file:$linenum — '$pattern' without #ifdef _WIN32"
      done <<< "$matches"
    else
      # No guards at all
      linenum=$(echo "$matches" | head -1 | cut -d: -f1)
      finding "posix-no-guard" "$file:$linenum — '$pattern' (no Windows compat)"
    fi
  done
done

if [ "$FINDINGS" -gt 0 ]; then
  echo ""
  echo "  $FINDINGS portability issue(s). Fix: wrap POSIX code in #ifdef _WIN32 / #else / #endif"
  echo "  See: src/common/compat.h for a reference pattern"
  exit 1
fi
exit 0
