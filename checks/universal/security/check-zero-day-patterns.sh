#!/usr/bin/env bash
# check-zero-day-patterns.sh — Detect code patterns that lead to zero-days.
# @see ADR-129
#
# Unlike CVE scanners (which find KNOWN vulns), this finds UNKNOWN vulns
# by detecting dangerous code patterns that attackers exploit:
#
#   - Unsanitized user input flowing into dangerous sinks
#   - Deserialization of untrusted data
#   - Dynamic code execution (eval, exec, system)
#   - SQL string concatenation (not parameterized)
#   - Path traversal (user input in file paths)
#   - SSRF patterns (user input in URLs/requests)
#   - Prototype pollution sinks
#   - Unsafe regex (ReDoS)
#   - Race conditions (TOCTOU)
#   - Memory corruption patterns (C/C++)
#
# These are the ROOT CAUSES of zero-days. If you eliminate the pattern,
# you eliminate the entire class of vulnerability — known AND unknown.

source "$(dirname "$0")/../../../lib/shell/check.sh"
FOUND=0

# Detect language from cpm.toml or file extensions.
LANG=""
[ -f "cpm.toml" ] && LANG=$(grep '^lang' cpm.toml 2>/dev/null | sed 's/.*= *"//;s/".*//')

scan_pattern() {
  local severity="$1" rule="$2" desc="$3" pattern="$4" include="$5"
  local hits
  hits=$(grep -rn --include="$include" -E "$pattern" src/ lib/ app/ 2>/dev/null | grep -v "test" | grep -v "spec" | head -5)
  if [ -n "$hits" ]; then
    while IFS=: read -r file line _; do
      findings_add "$severity" "$file:$line" "$rule" "$desc" "" ""
      FOUND=$((FOUND + 1))
    done <<< "$hits"
  fi
}

echo "  [zero-day] Scanning for exploitable patterns..."

# ═══ INJECTION (any language) ═══════════════════════════════════════

# SQL concatenation (not parameterized)
scan_pattern "error" "sql-concat" \
  "SQL string concatenation — use parameterized queries" \
  '(query|execute|sql).*\+.*\$(req|request|params|body|input|user)' \
  "*.{js,ts,py,rb,php,java}"

scan_pattern "error" "sql-concat-fstring" \
  "SQL f-string/template — use parameterized queries" \
  '(query|execute|sql).*(f"|`|\$\{).*(req|request|params|input)' \
  "*.{js,ts,py,rb,php}"

# eval/exec with user input
scan_pattern "error" "code-injection" \
  "Dynamic code execution with potential user input" \
  '(eval|exec|Function)\s*\(.*\$(req|request|params|body|input|user)' \
  "*.{js,ts,py,rb,php}"

# system/shell execution
scan_pattern "error" "command-injection" \
  "Shell execution with potential user input — use safe APIs" \
  '(system|exec|popen|spawn|child_process).*\$.(req|request|params|body|input|argv)' \
  "*.{js,ts,py,rb,php,cpp,c}"

# ═══ DESERIALIZATION ════════════════════════════════════════════════

scan_pattern "error" "unsafe-deserialize" \
  "Deserialization of untrusted data — leads to RCE" \
  '(unserialize|pickle\.loads|yaml\.load|ObjectInputStream|JSON\.parse.*eval|readObject)' \
  "*.{php,py,java,js,ts}"

# Java-specific: known gadget chains
scan_pattern "error" "java-deserialize" \
  "Java deserialization sink — verify input is trusted" \
  '(ObjectInputStream|XMLDecoder|XStream\.fromXML|readObject|readResolve)' \
  "*.java"

# ═══ PATH TRAVERSAL ════════════════════════════════════════════════

scan_pattern "error" "path-traversal" \
  "User input in file path — validate and sanitize" \
  '(readFile|open|fopen|include|require).*\$(req|request|params|query|input)' \
  "*.{js,ts,py,rb,php}"

# ═══ SSRF ══════════════════════════════════════════════════════════

scan_pattern "error" "ssrf-pattern" \
  "User input in HTTP request URL — validate against allowlist" \
  '(fetch|request|axios|http\.get|urllib|curl).*\$(req|request|params|body|input)' \
  "*.{js,ts,py,rb,php}"

# ═══ PROTOTYPE POLLUTION (JS/TS) ═══════════════════════════════════

scan_pattern "warning" "prototype-pollution" \
  "Deep merge/assign with user input — prototype pollution risk" \
  '(merge|assign|extend|defaults).*\$(req|request|body|params)' \
  "*.{js,ts}"

scan_pattern "warning" "proto-access" \
  "Direct __proto__ access — prototype pollution sink" \
  '__proto__|constructor\[.prototype' \
  "*.{js,ts}"

# ═══ REGEX DoS ═════════════════════════════════════════════════════

scan_pattern "warning" "redos" \
  "Nested quantifiers in regex — ReDoS risk" \
  '\(.*[\+\*].*\)[\+\*]|\(.*\|.*\)[\+\*].*\1' \
  "*.{js,ts,py,rb,java,php}"

# ═══ C/C++ MEMORY CORRUPTION ══════════════════════════════════════

if [ "$LANG" = "c" ] || [ "$LANG" = "cpp" ]; then
  scan_pattern "error" "buffer-overflow" \
    "Unbounded copy — use bounded alternatives (strncpy, snprintf)" \
    '(strcpy|strcat|sprintf|gets)\s*\(' \
    "*.{c,cpp,h,hpp}"

  scan_pattern "error" "format-string" \
    "User-controlled format string — use fixed format" \
    '(printf|fprintf|sprintf)\s*\(\s*(buf|str|input|argv|user)' \
    "*.{c,cpp}"

  scan_pattern "warning" "use-after-free" \
    "Potential use-after-free — verify lifetime" \
    'free\s*\(.*\).*\n.*\1' \
    "*.{c,cpp}"

  scan_pattern "warning" "integer-overflow" \
    "Arithmetic before bounds check — check before operation" \
    '(malloc|alloc|new)\s*\(.*\*' \
    "*.{c,cpp}"
fi

# ═══ RACE CONDITIONS ══════════════════════════════════════════════

scan_pattern "warning" "toctou" \
  "Time-of-check-time-of-use — check and use atomically" \
  '(access|stat|exists).*\n.*(open|read|write|unlink|rename)' \
  "*.{c,cpp,py,rb}"

# ═══ AUTH BYPASS PATTERNS ═════════════════════════════════════════

scan_pattern "error" "auth-bypass" \
  "Comparison with == instead of constant-time compare" \
  '(password|token|secret|key).*[!=]=\s' \
  "*.{js,ts,py,rb,php}"

scan_pattern "warning" "jwt-none" \
  "JWT without algorithm verification — accept 'none' attack" \
  '(verify|decode).*algorithm.*none|alg.*none' \
  "*.{js,ts,py,rb,java}"

# ═══ SUMMARY ═════════════════════════════════════════════════════

if [ $FOUND -eq 0 ]; then
  echo "  ✓ No zero-day patterns detected"
else
  echo "  ✗ $FOUND exploitable pattern(s) found"
  echo "    These are ROOT CAUSES of zero-days."
  echo "    Fix the pattern → eliminate the entire vulnerability class."
  exit 1
fi
