#!/usr/bin/env bash
# check-unicode.sh — Check for invisible Unicode characters (security backdoors).
# @see ADR-129
source "$(dirname "$0")/../../lib/shell/check.sh"

find src/ -type f \( -name "*.cpp" -o -name "*.h" -o -name "*.ts" -o -name "*.js" \) 2>/dev/null | while read -r file; do
  if grep -nP '[\x{200B}\x{200C}\x{200D}\x{FEFF}]' "$file" 2>/dev/null | while IFS=: read -r line _; do
    findings_add "error" "$file:$line" "invisible-unicode" \
      "Invisible Unicode character (potential trojan source)" \
      "Remove zero-width characters" ""
  done; then true; fi
done
