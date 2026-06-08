#!/usr/bin/env bash
# checks/javascript/vue/check-vue-security.sh
# Vue 3 security anti-patterns: XSS, injection, unsafe bindings, secrets
# @see https://vuejs.org/guide/best-practices/security.html
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../../lib/shell/init.sh" 2>/dev/null || true
cpm_check_enabled "js-vue-security" || exit 0
set -o nounset -o pipefail

REPO="${1:-.}"
cpm_has_dep "vue" "$REPO" || exit 0

FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-36s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }
finding_err() { printf "  \033[31merror\033[0m    %-36s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

SRC=$(cpm_find_src "$REPO")
[ -z "$SRC" ] && exit 0

VUE_FILES=$(find $SRC -name "*.vue" -not -path "*/node_modules/*" 2>/dev/null || true)
TS_FILES=$(find $SRC \( -name "*.ts" -o -name "*.js" \) -not -path "*/node_modules/*" 2>/dev/null || true)
ALL_FILES="$VUE_FILES $TS_FILES"
[ -z "$VUE_FILES" ] && exit 0

# --- XSS VECTORS ---

# 1. v-html directive (renders raw HTML, XSS if user-controlled)
if echo "$VUE_FILES" | xargs grep -l "v-html" 2>/dev/null | head -1 | grep -q .; then
  finding_err "vue-sec-v-html" "v-html renders raw HTML — XSS if input is user-controlled"
fi

# 2. innerHTML assignment in script
if echo "$ALL_FILES" | xargs grep -n "\.innerHTML\s*=" 2>/dev/null | grep -v "node_modules\|\.test\.\|\.spec\." | head -1 | grep -q .; then
  finding_err "vue-sec-innerhtml" "innerHTML assignment — bypasses Vue's XSS protection"
fi

# 3. outerHTML assignment
if echo "$ALL_FILES" | xargs grep -n "\.outerHTML\s*=" 2>/dev/null | grep -v "node_modules\|\.test\.\|\.spec\." | head -1 | grep -q .; then
  finding "vue-sec-outerhtml" "outerHTML assignment — bypasses template escaping"
fi

# 4. document.write (XSS + performance)
if echo "$ALL_FILES" | xargs grep -n "document\.write" 2>/dev/null | grep -v "node_modules\|\.test\.\|\.spec\." | head -1 | grep -q .; then
  finding_err "vue-sec-document-write" "document.write — XSS risk + destroys DOM in modern apps"
fi

# 5. DOMParser without sanitization
if echo "$ALL_FILES" | xargs grep -l "DOMParser\|parseFromString" 2>/dev/null | grep -v node_modules | while read -r f; do
  grep -L "DOMPurify\|sanitize\|dompurify" "$f" 2>/dev/null
done | head -1 | grep -q .; then
  finding "vue-sec-domparser-no-sanitize" "DOMParser without DOMPurify — parsed HTML may contain XSS"
fi

# --- INJECTION ---

# 6. eval() usage
if echo "$ALL_FILES" | xargs grep -nE "\beval\s*\(" 2>/dev/null | grep -v "node_modules\|\.test\.\|\.spec\.\|// *eslint" | head -1 | grep -q .; then
  finding_err "vue-sec-eval" "eval() — arbitrary code execution, use safe alternatives"
fi

# 7. new Function() (hidden eval)
if echo "$ALL_FILES" | xargs grep -n "new Function(" 2>/dev/null | grep -v "node_modules\|\.test\.\|\.spec\." | head -1 | grep -q .; then
  finding_err "vue-sec-new-function" "new Function() — hidden eval, same risks as eval()"
fi

# 8. setTimeout/setInterval with string argument
if echo "$ALL_FILES" | xargs grep -nE "setTimeout\(['\"]|setInterval\(['\"]" 2>/dev/null | grep -v "node_modules\|\.test\.\|\.spec\." | head -1 | grep -q .; then
  finding "vue-sec-timeout-string" "setTimeout/setInterval with string — implicit eval()"
fi

# --- UNSAFE URL BINDINGS ---

# 9. :href with dynamic user input (javascript: injection)
if echo "$VUE_FILES" | xargs grep -nE ':href="[^"]*\+|:href=".*\$\{' 2>/dev/null | grep -v "node_modules" | head -1 | grep -q .; then
  finding "vue-sec-dynamic-href" "Dynamic :href binding — validate protocol (javascript: XSS)"
fi

# 10. :src with user-controlled value
if echo "$VUE_FILES" | xargs grep -nE ':src="[^"]*input|:src="[^"]*user|:src="[^"]*url' 2>/dev/null | grep -v "node_modules" | head -1 | grep -q .; then
  finding "vue-sec-dynamic-src" "Dynamic :src with user input — validate URL to prevent injection"
fi

# 11. javascript: URLs in templates
if echo "$VUE_FILES" | xargs grep -n "javascript:" 2>/dev/null | grep -v "node_modules\|\.test\.\|\.spec\." | head -1 | grep -q .; then
  finding_err "vue-sec-javascript-url" "javascript: URL in template — XSS vector"
fi

# --- SECRETS & EXPOSURE ---

# 12. Hardcoded API keys/tokens in source
if echo "$ALL_FILES" | xargs grep -nE "(api[_-]?key|apiKey|secret|token|password)\s*[:=]\s*['\"][a-zA-Z0-9_\-]{16,}['\"]" 2>/dev/null | grep -v "node_modules\|\.test\.\|\.spec\.\|\.env\|environment\|interface\|type " | head -1 | grep -q .; then
  finding_err "vue-sec-hardcoded-secret" "Hardcoded secret/API key in source — move to env vars"
fi

# 13. localStorage storing sensitive data (tokens, passwords)
if echo "$ALL_FILES" | xargs grep -nE "localStorage\.setItem\(['\"].*(token|secret|password|auth|jwt)" 2>/dev/null | grep -v "node_modules\|\.test\.\|\.spec\." | head -1 | grep -q .; then
  finding "vue-sec-localstorage-secret" "Storing auth token in localStorage — vulnerable to XSS theft"
fi

# --- CSP & HEADERS ---

# 14. Missing Content-Security-Policy
INDEX_FILES=$(find "$REPO" -name "index.html" -not -path "*/node_modules/*" -not -path "*/dist/*" 2>/dev/null || true)
if [ -n "$INDEX_FILES" ]; then
  HAS_CSP=$(echo "$INDEX_FILES" | xargs grep -l "Content-Security-Policy" 2>/dev/null | head -1 || true)
  [ -z "$HAS_CSP" ] && finding "vue-sec-no-csp" "No Content-Security-Policy meta tag — XSS protection missing"
fi

# 15. unsafe-inline or unsafe-eval in CSP
if [ -n "$INDEX_FILES" ]; then
  if echo "$INDEX_FILES" | xargs grep -n "unsafe-inline\|unsafe-eval" 2>/dev/null | head -1 | grep -q .; then
    finding "vue-sec-csp-unsafe" "CSP uses unsafe-inline/unsafe-eval — weakens XSS protection"
  fi
fi

# --- UNSAFE PATTERNS ---

# 16. Dangerously setting cookie without Secure/HttpOnly flags
if echo "$ALL_FILES" | xargs grep -n "document\.cookie\s*=" 2>/dev/null | grep -v "node_modules\|\.test\.\|\.spec\." | head -1 | grep -q .; then
  finding "vue-sec-raw-cookie" "document.cookie assignment — use cookie lib with Secure/HttpOnly flags"
fi

# 17. window.location from user input (open redirect)
if echo "$ALL_FILES" | xargs grep -nE "window\.location\s*=|location\.href\s*=" 2>/dev/null | grep -v "node_modules\|\.test\.\|\.spec\." | head -1 | grep -q .; then
  finding "vue-sec-open-redirect" "window.location assignment — validate URL to prevent open redirect"
fi

# 18. postMessage without origin check
PM_FILES=$(echo "$ALL_FILES" | xargs grep -l "addEventListener.*message" 2>/dev/null | grep -v node_modules || true)
if [ -n "$PM_FILES" ]; then
  NO_ORIGIN=$(echo "$PM_FILES" | xargs grep -L "origin\|source" 2>/dev/null | head -1 || true)
  [ -n "$NO_ORIGIN" ] && finding "vue-sec-postmessage-no-origin" "message listener without origin check — cross-origin data theft"
fi

# 19. Axios/fetch without error handling exposing internals
if echo "$ALL_FILES" | xargs grep -lE "axios\.(get|post|put)|fetch\(" 2>/dev/null | grep -v "node_modules\|\.test\.\|\.spec\." | while read -r f; do
  grep -L "catch\|\.catch\|try" "$f" 2>/dev/null
done | head -1 | grep -q .; then
  finding "vue-sec-unhandled-fetch" "HTTP request without error handling — may expose stack traces to user"
fi

# 20. Regex from user input (ReDoS)
if echo "$ALL_FILES" | xargs grep -nE "new RegExp\(" 2>/dev/null | grep -v "node_modules\|\.test\.\|\.spec\." | head -1 | grep -q .; then
  finding "vue-sec-regex-user-input" "new RegExp() — if input is user-controlled, vulnerable to ReDoS"
fi

if [ $FINDINGS -eq 0 ]; then
  echo "  ✓ Vue security checked"
else
  echo ""
  echo "  $FINDINGS Vue security finding(s)"
fi
