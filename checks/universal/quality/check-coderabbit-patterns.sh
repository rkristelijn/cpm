#!/usr/bin/env bash
# check-coderabbit-patterns.sh — Detect patterns CodeRabbit frequently flags
# @see ADR-129
#
# Catches common shell script issues before they reach code review:
#   1. ((var++)) under errexit (silent abort)
#   2. \s in grep (not POSIX, fails on BSD/macOS)
#   3. Unquoted variable expansions in dangerous contexts
#   4. grep -c ... || echo 0 (double output bug)
#   5. cd without validation (TOCTOU)
#   6. Hardcoded home paths
#   7. Subshell variable loss (pipe + while)

source "$(dirname "$0")/../../../lib/shell/check.sh" 2>/dev/null || findings_add() { :; }

REPO="${1:-.}"
FILES=$(find "$REPO" -name '*.sh' -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/vendor/*')
[[ -z "$FILES" ]] && exit 0

TOTAL=0

while IFS= read -r file; do
  [[ -z "$file" || ! -f "$file" ]] && continue

  # --- 1. ((var++)) under errexit: returns 1 when var==0, aborts script ---
  grep -n '(([a-zA-Z_]*++))' "$file" 2>/dev/null | while IFS=: read -r ln _; do
    findings_add "error" "$file:$ln" "errexit-arithmetic" \
      "((var++)) returns exit 1 when var==0 under 'set -e' — script silently aborts" \
      "Use: var=\$((var + 1))"
    TOTAL=$((TOTAL + 1))
  done

  # --- 2. \s in grep (not POSIX, fails on BSD) ---
  grep -n '\\\\s' "$file" 2>/dev/null | grep -v "^#\|#.*\\\\s" | while IFS=: read -r ln _; do
    findings_add "warning" "$file:$ln" "non-posix-regex" \
      "\\s is not POSIX — fails on BSD/macOS grep" \
      "Use: [[:space:]] instead"
    TOTAL=$((TOTAL + 1))
  done

  # --- 3. grep -c ... || echo 0 (double output: prints "0\n0") ---
  grep -n 'grep -c.*|| echo 0\|grep -c.*||echo 0' "$file" 2>/dev/null | while IFS=: read -r ln _; do
    findings_add "warning" "$file:$ln" "grep-c-double-output" \
      "grep -c prints '0' AND || echo 0 fires — variable gets '0\\n0'" \
      "Use: var=\$(grep -c ... file) || var=0"
    TOTAL=$((TOTAL + 1))
  done

  # --- 4. cd without error check ---
  grep -n '^[[:space:]]*cd ' "$file" 2>/dev/null | grep -v '|| \|&& \|2>/dev/null\|pushd\|#' | while IFS=: read -r ln line; do
    # Skip if inside an if/test or has error handling on same line
    echo "$line" | grep -qE '\|\||&&|if |then|2>' && continue
    findings_add "info" "$file:$ln" "unchecked-cd" \
      "cd without error check — script continues in wrong directory if path missing" \
      "Use: cd \"path\" || { echo \"error\"; exit 1; }"
    TOTAL=$((TOTAL + 1))
  done

  # --- 5. Hardcoded /Users/ or /home/ paths ---
  grep -n '/Users/[a-z]\|/home/[a-z]' "$file" 2>/dev/null | grep -v '#\|echo\|printf\|info\|warn\|err' | while IFS=: read -r ln _; do
    findings_add "warning" "$file:$ln" "hardcoded-path" \
      "Hardcoded home path — not portable across users/systems" \
      "Use: \$HOME or \${XDG_*} variables"
    TOTAL=$((TOTAL + 1))
  done

  # --- 6. Pipe into while (variables lost in subshell) ---
  grep -n '|[[:space:]]*while ' "$file" 2>/dev/null | while IFS=: read -r ln _; do
    findings_add "info" "$file:$ln" "pipe-subshell-var-loss" \
      "Pipe into while runs in subshell — variable changes are lost" \
      "Use: while ... done < <(command) instead"
    TOTAL=$((TOTAL + 1))
  done

  # --- 7. Unquoted $VARIABLE in rm/mv/cp (dangerous) ---
  grep -n 'rm \|mv \|cp ' "$file" 2>/dev/null | grep '\$[A-Za-z]' | grep -v '"$\|#' | while IFS=: read -r ln _; do
    findings_add "warning" "$file:$ln" "unquoted-var-in-destructive" \
      "Unquoted variable in rm/mv/cp — word splitting can delete wrong files" \
      "Always quote: rm \"\$var\" not rm \$var"
    TOTAL=$((TOTAL + 1))
  done

done <<< "$FILES"

echo "  [coderabbit-patterns] $TOTAL finding(s)"
