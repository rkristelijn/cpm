#!/usr/bin/env bash
# checks/universal/quality/check-xml.sh
# XML anti-patterns: encoding, security (XXE), structure, common syntax issues
source "$(dirname "$0")/../../../lib/shell/check.sh"
cpm_check_enabled "xml-quality" || exit 0
set -o nounset -o pipefail

REPO="${1:-.}"

# Find XML files
XML_FILES=$(find "$REPO" -name "*.xml" -o -name "*.xsd" -o -name "*.xslt" -o -name "*.svg" -o -name "*.pom" 2>/dev/null | \
  grep -v "node_modules\|\.next\|dist\|build\|vendor\|coverage\|\.idea\|target" || true)
[ -z "$XML_FILES" ] && exit 0

FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }
error()   { printf "  \033[31merror\033[0m    %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

# --- XXE vulnerability (External Entity declarations) ---
if echo "$XML_FILES" | xargs grep -l "<!ENTITY.*SYSTEM\|<!ENTITY.*PUBLIC" 2>/dev/null | head -1 | grep -q .; then
  error "xml-xxe-risk" "External Entity (XXE) declaration found — major security risk"
fi

# --- String concatenation to build XML (in code files) ---
CODE_FILES=$(find "$REPO" -name "*.java" -o -name "*.py" -o -name "*.js" -o -name "*.ts" -o -name "*.cs" 2>/dev/null | \
  grep -v "node_modules\|dist\|build\|vendor" | head -50 || true)
if [ -n "$CODE_FILES" ]; then
  echo "$CODE_FILES" | xargs grep -n '"<[a-zA-Z].*>" *+\|"</" *+\|+ *"<[a-zA-Z]' 2>/dev/null | head -1 | grep -q . && \
    finding "xml-string-concat" "XML built via string concatenation — use an XML builder library"
fi

# --- Missing encoding declaration ---
NO_ENCODING=$(echo "$XML_FILES" | xargs grep -L 'encoding=' 2>/dev/null | \
  xargs grep -l '<?xml' 2>/dev/null | head -1 || true)
[ -n "$NO_ENCODING" ] && finding "xml-no-encoding" "XML declaration without encoding — may cause character corruption"

# --- Unescaped ampersands in content ---
if echo "$XML_FILES" | xargs grep -n " & [a-zA-Z]" 2>/dev/null | grep -v "&amp;\|&lt;\|&gt;\|&quot;\|&apos;\|CDATA" | head -1 | grep -q .; then
  finding "xml-unescaped-amp" "Unescaped & in XML content — use &amp; (parser will crash)"
fi

# --- Inconsistent naming (mixing camelCase, snake_case, kebab-case in same file) ---
SAMPLE=$(echo "$XML_FILES" | head -5)
if [ -n "$SAMPLE" ]; then
  HAS_CAMEL=$(echo "$SAMPLE" | xargs grep -l "<[a-z][a-zA-Z]*[A-Z]" 2>/dev/null | head -1 || true)
  if [ -n "$HAS_CAMEL" ]; then
    echo "$HAS_CAMEL" | xargs grep -q "<[a-z]*_[a-z]\|<[a-z]*-[a-z]" 2>/dev/null && \
      finding "xml-inconsistent-naming" "Mixed naming conventions (camelCase + snake_case) in XML"
  fi
fi

[ "$FINDINGS" -eq 0 ] && echo "  ✓ XML quality OK"
exit 0
