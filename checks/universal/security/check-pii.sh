#!/usr/bin/env bash
# check-pii.sh — Detect PII (Personally Identifiable Information) in code.
# @see ADR-129
#
# Modes:
#   (default)   Full scan of source directories for .config/.pii patterns
#   --staged    Fast scan of staged git changes only (for pre-commit hooks)
#
# Suppress inline: add 'cpm:ignore pii' to the line (any comment style).
# Suppress file:   add to .config/.piiignore (format: file:pattern).
#
# Output: clickable file:line references (VSCode/terminal hyperlinks).

source "$(dirname "$0")/../../../lib/shell/check.sh"

# --- Staged mode (pre-commit hook) ---
if [[ "${1:-}" == "--staged" ]]; then
  STAGED_FILES="${STAGED:-$(git diff --cached --name-only --diff-filter=ACMR 2>/dev/null)}"
  STAGED_FILES=$(echo "$STAGED_FILES" | grep -vE '\.(lock|min\.js|svg|png|jpg|gif)$')
  [[ -z "$STAGED_FILES" ]] && exit 0

  PATTERNS=(
      '\b[0-9]{9}\b'
      '\b[A-Z]{2}[0-9]{2}[A-Z0-9]{4}[0-9]{7}([A-Z0-9]{0,16})\b'
      '\b06[0-9]{8}\b'
      '\b\+31[0-9]{9}\b'
  )

  # Single git diff → extract added lines as "file:line:content", skip suppressed
  ADDED=$(git diff --cached -U0 -- $STAGED_FILES 2>/dev/null \
    | awk '/^diff --git/{f=substr($3,3)} /^@@/{split($3,a,"+"); ln=a[1]+0; sub(/,.*/,"",ln); ln--; next} /^\+[^+]/{ln++; if ($0 !~ /cpm:ignore pii/) print f":"ln":"substr($0,2)}')

  [[ -z "$ADDED" ]] && exit 0

  found=0
  for pattern in "${PATTERNS[@]}"; do
    while IFS= read -r hit; do
      file="${hit%%:*}"
      linenum="$(echo "$hit" | cut -d: -f2)"
      content="$(echo "$hit" | cut -d: -f3-)"
      findings_add "error" "$file:$linenum" "pii-detected" \
        "Pattern '$pattern' matched" \
        "Add 'cpm:ignore pii' to the line to suppress" ""
      found=$((found + 1))
    done < <(echo "$ADDED" | grep -E "$pattern" || true)
  done

  if [[ $found -gt 0 ]]; then
    echo "   suppress: add 'cpm:ignore pii' to the line"
  fi
  exit 0  # findings_finish in trap handles exit code
fi

# --- Full scan mode ---
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
  HITS=$(grep -rln \
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
      grep -n "$pattern" "$file" 2>/dev/null | grep -v "cpm:ignore pii" | while IFS=: read -r linenum _; do
        findings_add "error" "$file:$linenum" "pii-detected" \
          "PII pattern '$pattern' found" \
          "Add 'cpm:ignore pii' to suppress, or add to .config/.piiignore" ""
      done
      FOUND=1
    fi
  done <<<"$HITS"
done

if [[ $IGNORED -gt 0 ]]; then
  echo "  [pii] $IGNORED ignored finding(s)"
fi
