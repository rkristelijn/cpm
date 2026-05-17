#!/usr/bin/env bash
# scripts/literals.sh — Analyze string literals to reveal hidden knowledge
# Usage: bash scripts/literals.sh [path]
set -o nounset -o pipefail

REPO="${1:-.}"
EXCLUDE="node_modules|\.next|dist|build|\.git|coverage|vendor|target|__pycache__|\.test\.|\.spec\.|\.min\."

FILES=$(find "$REPO" -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \
  -o -name "*.cpp" -o -name "*.c" -o -name "*.h" -o -name "*.py" -o -name "*.go" \
  -o -name "*.java" -o -name "*.sh" -o -name "*.rb" 2>/dev/null | grep -vE "$EXCLUDE" || true)
[ -z "$FILES" ] && { echo "  No source files found"; exit 0; }

echo ""
echo "  ■ Literals Analysis: $(basename "$(cd "$REPO" && pwd)")"
echo ""

# === 1. URLs (external services, APIs) ===
echo "  External URLs & APIs:"
echo "$FILES" | xargs grep -ohE "https?://[a-zA-Z0-9._/~:@!$&'()*+,;=-]+" 2>/dev/null | \
  grep -v "example\.com\|localhost\|127\.0\.0\|placeholder\|schema\.org" | \
  sort -u | sed 's/^/    /' | head -15
echo ""

# === 2. File paths (what files does it touch?) ===
echo "  File paths:"
echo "$FILES" | xargs grep -ohE '"/[a-zA-Z0-9._/-]{3,}"' 2>/dev/null | \
  grep -vE "node_modules|\.git" | sort -u | sed 's/^/    /' | head -10
echo ""

# === 3. SQL / Database queries ===
echo "  SQL/Database:"
SQL=$(echo "$FILES" | xargs grep -ohiE "(SELECT|INSERT|UPDATE|DELETE|CREATE TABLE|ALTER TABLE|DROP)[^\"']*" 2>/dev/null | head -8)
if [ -n "$SQL" ]; then
  echo "$SQL" | sed 's/^/    /' | head -8
else
  echo "    (none detected)"
fi
echo ""

# === 4. Error messages (what can go wrong?) ===
echo "  Error messages (top failure modes):"
echo "$FILES" | xargs grep -ohE "(Error|error|ERROR|throw|FATAL|WARN)[^\"']*[\"'][^\"']{10,}[\"']" 2>/dev/null | \
  grep -oE "[\"'][^\"']{10,}[\"']" | sort | uniq -c | sort -rn | head -8 | \
  awk '{$1=$1; printf "    %s\n", $0}'
echo ""

# === 5. Environment variable names (from literals) ===
echo "  Environment variables (referenced in strings):"
echo "$FILES" | xargs grep -ohE "[A-Z][A-Z_]{2,}[A-Z]" 2>/dev/null | \
  grep -E "^(API_|DB_|AWS_|AUTH_|SECRET_|TOKEN_|PORT|HOST|URL|KEY|PASS|USER|NODE_|NEXT_|REACT_)" | \
  sort -u | sed 's/^/    /' | head -15
echo ""

# === 6. Regex patterns (what's being validated?) ===
echo "  Regex patterns (validation rules):"
echo "$FILES" | xargs grep -ohE "/[^/]{5,}/[gimsuy]*|new RegExp\([^)]+\)" 2>/dev/null | \
  grep -v "node_modules\|http" | sort -u | sed 's/^/    /' | head -8
echo ""

# === 7. Magic numbers (hardcoded config) ===
echo "  Magic numbers (possible hardcoded config):"
echo "$FILES" | xargs grep -nE "= [0-9]{4,}[^0-9]|timeout.*[0-9]{4,}|port.*[0-9]{4,}|size.*[0-9]{3,}" 2>/dev/null | \
  grep -vE "test|spec|\.min\." | sed "s|$REPO/||" | sed 's/^/    /' | head -8
echo ""

# === 8. Interesting string constants ===
echo "  Domain terms (most frequent capitalized terms):"
echo "$FILES" | xargs grep -ohE "[A-Z][a-z]+[A-Z][a-zA-Z]+" 2>/dev/null | \
  sort | uniq -c | sort -rn | head -10 | awk '{printf "    %4d  %s\n", $1, $2}'
echo ""
