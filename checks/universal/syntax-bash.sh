#!/usr/bin/env bash
# syntax-bash.sh — Check shell scripts for syntax errors.
# @see ADR-129
source "$(dirname "$0")/../../lib/shell/check.sh"

while IFS= read -r file; do
  err=$(bash -n "$file" 2>&1)
  if [[ $? -ne 0 ]]; then
    line=$(echo "$err" | grep -oE 'line [0-9]+' | head -1 | grep -oE '[0-9]+')
    findings_add "error" "$file:${line:-0}" "bash-syntax-error" \
      "Shell syntax error: $(echo "$err" | head -1)" \
      "Fix the syntax error" ""
  fi
done < <(find . -name '*.sh' -not -path './.git/*' -not -path './node_modules/*' -not -path './vendor/*' 2>/dev/null)
