#!/usr/bin/env bash
# check-pii.sh — Detect PII (Personally Identifiable Information) in code.
# @see ADR-129
#
# Scans source files for patterns defined in .config/.pii (one per line).
# Suppress false positives in .config/.piiignore (format: file:pattern).
# Each developer maintains their own .pii and .piiignore files (gitignored).

# Resolve .pii file
source "$(dirname "$0")/../../../lib/shell/check.sh"
PII_FILE="${PII_FILE:-}"
if [[ -z "$PII_FILE" ]]; then
  if [[ -f ".config/.pii" ]]; then
    PII_FILE=".config/.pii"
  elif [[ -f ".pii" ]]; then
    PII_FILE=".pii"
  fi
fi

if [[ -z "$PII_FILE" || ! -f "$PII_FILE" ]]; then
  mkdir -p .config
  cat >".config/.pii" <<'EOF'
# PII patterns to detect in code (one per line)
# Examples:
# john.doe@company.com
# 192.168.1.100
# my-secret-hostname
EOF
  echo "  [pii] Created .config/.pii template"
  echo "    Add your PII patterns (one per line) and re-run"
  exit 0
fi

# Load ignore list (format: file:pattern — one per line)
IGNORE_FILE=".config/.piiignore"
IGNORES=()
if [[ -f "$IGNORE_FILE" ]]; then
  while IFS= read -r line; do
    [[ "$line" =~ ^#.*$ ]] && continue
    [[ -z "$line" ]] && continue
    IGNORES+=("$line")
  done <"$IGNORE_FILE"
fi

is_ignored() {
  local file="$1" pattern="$2"
  for entry in "${IGNORES[@]+"${IGNORES[@]}"}"; do
    if [[ "$entry" == "$file:$pattern" || "$entry" == "*:$pattern" || "$entry" == "$pattern" ]]; then
      return 0
    fi
  done
  return 1
}

# Read patterns (skip comments and empty lines)
PATTERNS=()
while IFS= read -r line; do
  [[ "$line" =~ ^#.*$ ]] && continue
  [[ -z "$line" ]] && continue
  PATTERNS+=("$line")
done <"$PII_FILE"

if [[ ${#PATTERNS[@]} -eq 0 ]]; then
  echo "  [pii] skip — no patterns defined in $PII_FILE"
  exit 0
fi

echo "  [pii] Scanning for ${#PATTERNS[@]} pattern(s)..."

FOUND=0
IGNORED=0
for pattern in "${PATTERNS[@]}"; do
  HITS=$(grep -rl \
    --include="*.cpp" --include="*.h" --include="*.hpp" \
    --include="*.sh" --include="*.md" --include="*.toml" \
    --include="*.json" --include="*.yml" --include="*.yaml" \
    --exclude="check-pii.sh" \
    "$pattern" src/ lib/ checks/ docs/ 2>/dev/null || true)
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    if is_ignored "$file" "$pattern"; then
      IGNORED=$((IGNORED + 1))
    else
      grep -n "$pattern" "$file" 2>/dev/null | while IFS=: read -r linenum _; do
        findings_add "error" "$file:$linenum" "pii-detected" \
          "PII pattern '$pattern' found" \
          "Remove data, or add to .config/.piiignore" ""
      done
      FOUND=1
    fi
  done <<<"$HITS"
done

if [[ $IGNORED -gt 0 ]]; then
  echo "  [pii] $IGNORED ignored finding(s)"
fi
