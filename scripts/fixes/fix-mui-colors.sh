#!/usr/bin/env bash
# fixes/fix-mui-colors.sh — Replace hardcoded hex colors with MUI theme tokens
# Usage: bash fixes/fix-mui-colors.sh [path]
# Safe: uses sed with backup, only touches known MUI color values
set -o nounset -o pipefail

REPO="${1:-.}"
FIXED=0

fix() { printf "  \033[32m✓ fixed\033[0m  %s:%s %s\n" "$1" "$2" "$3"; FIXED=$((FIXED+1)); }

SRC=""
[ -d "$REPO/src" ] && SRC="$REPO/src"
[ -d "$REPO/app" ] && SRC="${SRC:+$SRC }$REPO/app"
[ -z "$SRC" ] && { echo "No src/ or app/ found"; exit 0; }

echo ""
echo "  cpm fix — MUI literal colors → theme tokens"
echo ""

# MUI default palette mapping (hex → theme token)
# Based on: https://mui.com/material-ui/customization/default-theme/
declare -A COLOR_MAP=(
  # Primary
  ["#1976d2"]="primary.main"
  ["#1565c0"]="primary.dark"
  ["#42a5f5"]="primary.light"
  # Secondary
  ["#9c27b0"]="secondary.main"
  ["#7b1fa2"]="secondary.dark"
  ["#ba68c8"]="secondary.light"
  # Error
  ["#d32f2f"]="error.main"
  ["#c62828"]="error.dark"
  ["#ef5350"]="error.light"
  # Warning
  ["#ed6c02"]="warning.main"
  ["#e65100"]="warning.dark"
  ["#ff9800"]="warning.light"
  ["#ffa726"]="warning.light"
  # Success
  ["#2e7d32"]="success.main"
  ["#1b5e20"]="success.dark"
  ["#66bb6a"]="success.light"
  ["#4caf50"]="success.main"
  # Info
  ["#0288d1"]="info.main"
  ["#01579b"]="info.dark"
  ["#03a9f4"]="info.light"
  # Grey
  ["#212121"]="text.primary"
  ["#666666"]="text.secondary"
  ["#9e9e9e"]="text.disabled"
  ["#f5f5f5"]="grey.100"
  ["#eeeeee"]="grey.200"
  ["#e0e0e0"]="grey.300"
  ["#bdbdbd"]="grey.400"
  ["#757575"]="grey.600"
  ["#616161"]="grey.700"
  ["#424242"]="grey.800"
  # Common
  ["#ffffff"]="common.white"
  ["#000000"]="common.black"
)

# Find all tsx/ts files with hex colors
FILES=$(grep -rl "#[0-9a-fA-F]\{6\}" $SRC --include="*.tsx" --include="*.ts" 2>/dev/null | grep -v node_modules || true)

for file in $FILES; do
  for hex in "${!COLOR_MAP[@]}"; do
    token="${COLOR_MAP[$hex]}"
    hex_upper=$(echo "$hex" | tr '[:lower:]' '[:upper:]')
    hex_lower=$(echo "$hex" | tr '[:upper:]' '[:lower:]')

    # Replace in sx prop context: color: "#hex" → color: "token"
    if grep -qn "$hex_lower\|$hex_upper" "$file" 2>/dev/null; then
      LINE=$(grep -n "$hex_lower\|$hex_upper" "$file" | head -1 | cut -d: -f1)
      # sx prop context: replace quoted hex with token
      sed -i "s/\"$hex_lower\"/\"$token\"/gI" "$file"
      sed -i "s/'$hex_lower'/'$token'/gI" "$file"
      # Also handle without quotes in color prop: color="#hex" → color="token"
      sed -i "s/color=\"$hex_lower\"/color=\"$token\"/gI" "$file"
      sed -i "s/color={'$hex_lower'}/color=\"$token\"/gI" "$file"
      fix "$file" "$LINE" "$hex → $token"
    fi
  done
done

if [ "$FIXED" -eq 0 ]; then
  echo "  No known MUI hex colors found to fix."
  # Show unknown hex colors that might need manual attention
  UNKNOWN=$(grep -rn "#[0-9a-fA-F]\{6\}" $SRC --include="*.tsx" --include="*.ts" 2>/dev/null | grep -v node_modules | head -5 || true)
  if [ -n "$UNKNOWN" ]; then
    echo ""
    echo "  Unknown hex colors (manual review needed):"
    echo "$UNKNOWN" | sed 's/^/    /'
  fi
fi

echo ""
echo "  $FIXED fixes applied"
