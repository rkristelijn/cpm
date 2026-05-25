#!/usr/bin/env bash
# checks/universal/quality/check-sonar-shift-left.sh
# @see ADR-129
# Catches patterns that SonarCloud flags as CRITICAL/BLOCKER — locally, before push.
# Categories: deep nesting, null-safety, macros→constexpr, missing default case, --ignore-scripts.
source "$(dirname "$0")/../../../lib/shell/check.sh"

REPO="${1:-.}"

# --- Deep nesting (>3 levels) in C/C++ ---
check_nesting() {
  local files
  files=$(find "$REPO/src" -name '*.cpp' -o -name '*.c' -o -name '*.h' 2>/dev/null)
  [ -z "$files" ] && return

  while IFS= read -r file; do
    [ -f "$file" ] || continue
    local depth=0 max_depth=0 max_line=0 linenum=0
    while IFS= read -r line; do
      linenum=$((linenum + 1))
      # Count opening braces after if/for/while/switch
      if echo "$line" | grep -qE '^\s*(if|for|while|switch|do)\b.*\{'; then
        depth=$((depth + 1))
        if [ "$depth" -gt "$max_depth" ]; then
          max_depth=$depth
          max_line=$linenum
        fi
      elif echo "$line" | grep -qE '^\s*\}'; then
        [ "$depth" -gt 0 ] && depth=$((depth - 1))
      fi
    done < "$file"
    if [ "$max_depth" -gt 3 ]; then
      findings_add "warning" "$file:$max_line" "deep-nesting" \
        "Nesting depth $max_depth (max 3) — extract to helper function" \
        "Refactor nested logic into separate functions"
    fi
  done <<< "$files"
}

# --- Null-safety: getenv/popen without null check ---
check_null_safety() {
  local files
  files=$(find "$REPO/src" -name '*.cpp' -o -name '*.c' 2>/dev/null)
  [ -z "$files" ] && return

  while IFS= read -r file; do
    [ -f "$file" ] || continue
    # getenv used directly without null check
    grep -n 'getenv(' "$file" 2>/dev/null | while IFS=: read -r linenum line; do
      # Flag if result is used directly (not assigned to var then checked)
      if echo "$line" | grep -qE '(strcmp|strstr|printf|std::string)\(.*getenv\('; then
        findings_add "warning" "$file:$linenum" "null-deref" \
          "getenv() may return nullptr — check before use" \
          "const char* val = getenv(\"X\"); if (val) { ... }"
      fi
    done
    # popen without null check
    grep -n 'popen(' "$file" 2>/dev/null | while IFS=: read -r linenum line; do
      if ! sed -n "$((linenum+1)),$((linenum+2))p" "$file" | grep -q 'nullptr\|NULL\|!.*fp\|== 0'; then
        findings_add "info" "$file:$linenum" "null-deref" \
          "popen() may return nullptr — check before use"
      fi
    done
  done <<< "$files"
}

# --- Macros that should be constexpr ---
check_macros() {
  local files
  files=$(find "$REPO/src" -name '*.h' -o -name '*.hpp' 2>/dev/null)
  [ -z "$files" ] && return

  while IFS= read -r file; do
    [ -f "$file" ] || continue
    grep -n '^#define' "$file" 2>/dev/null | while IFS=: read -r linenum line; do
      # Skip include guards and multi-line macros
      echo "$line" | grep -qE '#define\s+[A-Z_]+_H\b|#define.*\\$|#define.*do \{' && continue
      # Flag numeric/string constant macros
      if echo "$line" | grep -qE '#define\s+[A-Z_]+\s+[0-9"]+'; then
        findings_add "info" "$file:$linenum" "macro-to-constexpr" \
          "Replace macro with constexpr — type-safe and scoped" \
          "Use: constexpr auto NAME = value;"
      fi
    done
  done <<< "$files"
}

# --- Missing default case in shell case statements ---
check_default_case() {
  local files
  files=$(find "$REPO" -name '*.sh' -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null)
  [ -z "$files" ] && return

  while IFS= read -r file; do
    [ -f "$file" ] || continue
    # Find case statements without *) default
    local in_case=false case_line=0 has_default=false
    local linenum=0
    while IFS= read -r line; do
      linenum=$((linenum + 1))
      if echo "$line" | grep -qE '^\s*case\s'; then
        in_case=true; case_line=$linenum; has_default=false
      elif [ "$in_case" = true ]; then
        echo "$line" | grep -qE '^\s*\*\)' && has_default=true
        if echo "$line" | grep -qE '^\s*esac'; then
          if [ "$has_default" = false ]; then
            findings_add "warning" "$file:$case_line" "missing-default-case" \
              "case statement without *) default — add to handle unexpected values"
          fi
          in_case=false
        fi
      fi
    done < "$file"
  done <<< "$files"
}

# --- npm install without --ignore-scripts ---
check_ignore_scripts() {
  local files
  files=$(find "$REPO" -name '*.sh' -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null)
  [ -z "$files" ] && return

  while IFS= read -r file; do
    [ -f "$file" ] || continue
    grep -n 'npm install\|npm ci\|npm i ' "$file" 2>/dev/null | while IFS=: read -r linenum line; do
      if ! echo "$line" | grep -q '\-\-ignore-scripts'; then
        findings_add "warning" "$file:$linenum" "npm-ignore-scripts" \
          "npm install without --ignore-scripts — risk of arbitrary code execution" \
          "Add --ignore-scripts flag"
      fi
    done
  done <<< "$files"
}

# --- Run all checks ---
check_nesting
check_null_safety
check_macros
check_default_case
check_ignore_scripts
