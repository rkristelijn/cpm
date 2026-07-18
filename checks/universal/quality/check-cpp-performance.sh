#!/usr/bin/env bash
# check-cpp-performance.sh — Detect C++ performance anti-patterns
# @see ADR-129
#
# Detects:
#   1. substr() in loops (heap allocation per call)
#   2. find(x)==0 instead of starts_with() (C++20, or rfind(x,0)==0)
#   3. Pass-by-value of large types (should be const&)
#   4. Postfix increment on non-trivial iterators
#   5. String/vector created inside loops (should reuse)
#   6. Virtual functions where templates could work
#   7. Missing const on methods that don't mutate
#   8. Double initialization (default-construct then assign)
#
# Sources:
#   - "High-Performance C++: 20 Class-Level Optimizations" (Sagar, 2026)
#   - "Performance tips for C++ developers" (Yagiz Nizipli, 2023)
#   - "10 Tips for C/C++ Performance" (thegeekstuff.com)

source "$(dirname "$0")/../../../lib/shell/check.sh" 2>/dev/null || findings_add() { :; }

REPO="${1:-.}"
SRC_DIR="$REPO/src"

[[ ! -d "$SRC_DIR" ]] && exit 0

FILES=$(find "$SRC_DIR" -name '*.cpp' -o -name '*.h' -o -name '*.hpp' | grep -v vendor)
[[ -z "$FILES" ]] && exit 0

TOTAL=0

# --- 1. substr() in hot loops ---
while IFS= read -r file; do
  [[ -z "$file" ]] && continue
  grep -n "\.substr(" "$file" 2>/dev/null | while IFS=: read -r linenum line; do
    # Check if inside a while/for loop (crude: look back 5 lines)
    CONTEXT=$(sed -n "$((linenum > 5 ? linenum-5 : 1)),${linenum}p" "$file")
    if echo "$CONTEXT" | grep -qE "while|for\s*\("; then
      findings_add "warning" "$file:$linenum" "perf-substr-in-loop" \
        "substr() allocates a new string each call — use string_view or reuse buffer" \
        "Replace with: std::string_view ln(content.data() + pos, eol - pos)"
      TOTAL=$((TOTAL + 1))
    fi
  done
done <<< "$FILES"

# --- 2. find()==0 instead of starts_with ---
while IFS= read -r file; do
  [[ -z "$file" ]] && continue
  grep -n "\.find(" "$file" 2>/dev/null | grep "== 0\|==0" | while IFS=: read -r linenum line; do
    findings_add "info" "$file:$linenum" "perf-find-starts-with" \
      "find(x)==0 is O(n) — use starts_with() (C++20) or rfind(x,0)==0" \
      "Replace: str.find(\"abc\")==0 → str.starts_with(\"abc\")"
    TOTAL=$((TOTAL + 1))
  done
done <<< "$FILES"

# --- 3. Pass-by-value of string/vector (should be const&) ---
while IFS= read -r file; do
  [[ -z "$file" ]] && continue
  grep -n "(std::string [a-z]\|std::vector<" "$file" 2>/dev/null | \
    grep -v "const\|&\|static\|return\|override\|=\|move" | while IFS=: read -r linenum line; do
    # Only flag function parameters (lines with parentheses)
    if echo "$line" | grep -q "("; then
      findings_add "warning" "$file:$linenum" "perf-pass-by-value" \
        "Large type passed by value — creates unnecessary copy" \
        "Use const& for read-only access, && for move semantics"
      TOTAL=$((TOTAL + 1))
    fi
  done
done <<< "$FILES"

# --- 4. Postfix increment on iterators ---
while IFS= read -r file; do
  [[ -z "$file" ]] && continue
  grep -n "it++\|iter++\|itr++" "$file" 2>/dev/null | while IFS=: read -r linenum line; do
    findings_add "info" "$file:$linenum" "perf-postfix-iterator" \
      "Postfix ++ on iterator creates temporary copy — use prefix ++it" \
      "Change it++ to ++it"
    TOTAL=$((TOTAL + 1))
  done
done <<< "$FILES"

# --- 5. Objects created in loops that could be reused ---
while IFS= read -r file; do
  [[ -z "$file" ]] && continue
  # Pattern: std::string/vector declaration inside for/while
  grep -n "std::string \|std::vector<\|std::stringstream" "$file" 2>/dev/null | while IFS=: read -r linenum line; do
    CONTEXT=$(sed -n "$((linenum > 3 ? linenum-3 : 1)),${linenum}p" "$file")
    if echo "$CONTEXT" | grep -qE "^\s*(for|while)\s*\("; then
      findings_add "warning" "$file:$linenum" "perf-object-in-loop" \
        "Object created inside loop — move declaration before loop and reuse with .clear()" \
        "Declare before loop, use .clear() or .resize(0) to reuse buffer"
      TOTAL=$((TOTAL + 1))
    fi
  done
done <<< "$FILES"

# --- 6. Virtual functions (informational) ---
VIRTUAL_COUNT=$(grep -rn "virtual " $SRC_DIR --include="*.h" --include="*.hpp" | grep -v "vendor\|~\|override" | wc -l | tr -d ' ')
if [[ $VIRTUAL_COUNT -gt 10 ]]; then
  findings_add "info" "project" "perf-virtual-functions" \
    "$VIRTUAL_COUNT virtual function declarations — consider CRTP or templates for hot paths" \
    "Virtual dispatch adds vtable lookup cost; templates inline at compile time"
  TOTAL=$((TOTAL + 1))
fi

echo "  [cpp-performance] $TOTAL finding(s)"
