#!/usr/bin/env bash
# checks/java/check-java.sh
# Java/Spring anti-patterns: deprecated APIs, security, performance
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/shell/init.sh" 2>/dev/null || true
cpm_check_enabled "java" || exit 0
set -o nounset -o pipefail

REPO="${1:-.}"
[ -f "$REPO/pom.xml" ] || [ -f "$REPO/build.gradle" ] || exit 0

FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }
error()   { printf "  \033[31merror\033[0m    %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

SRC=$(find "$REPO" -path "*/src/main/java" -maxdepth 4 2>/dev/null | head -1)
[ -z "$SRC" ] && exit 0

# --- Spring Boot EOL ---
if [ -f "$REPO/pom.xml" ]; then
  SB_VER=$(grep -A2 "spring-boot-starter-parent" "$REPO/pom.xml" 2>/dev/null | grep -oE "[0-9]+\.[0-9]+\.[0-9]+" | head -1)
  if [ -n "$SB_VER" ]; then
    MAJOR=$(echo "$SB_VER" | cut -d. -f1)
    [ "$MAJOR" -lt 3 ] && error "spring-boot-eol" "Spring Boot $SB_VER is EOL — upgrade to 3.x"
  fi
fi

# --- javax → jakarta migration needed ---
cpm_grep -rl "javax\.persistence\|javax\.servlet\|javax\.validation" "$SRC/" 2>/dev/null | head -1 | grep -q . && \
  finding "javax-not-jakarta" "javax.* imports — migrate to jakarta.* (required for Spring Boot 3)"

# --- System.out.println (use logger) ---
COUNT=$(cpm_grep -rn "System\.out\.print\|System\.err\.print" "$SRC/" 2>/dev/null | wc -l | tr -d ' ')
[ "$COUNT" -gt 5 ] && finding "sysout-abuse" "$COUNT System.out/err.print — use SLF4J logger"

# --- Catching generic Exception ---
cpm_grep -rn "catch\s*(Exception\s" "$SRC/" 2>/dev/null | head -1 | grep -q . && \
  finding "catch-generic-exception" "catch(Exception) — catch specific exceptions"

# --- @Autowired on field (use constructor injection) ---
AUTOWIRED=$(cpm_grep -rn "@Autowired" "$SRC/" 2>/dev/null | grep -v "constructor\|@Autowired.*final" | wc -l | tr -d ' ')
[ "$AUTOWIRED" -gt 5 ] && finding "field-injection" "$AUTOWIRED @Autowired field injections — use constructor injection"

# --- Hardcoded secrets ---
cpm_grep -rn "password\s*=\s*\"[^\"]\{4,\}\"\|secret\s*=\s*\"" "$SRC/" 2>/dev/null | \
  grep -v "test\|mock\|example\|dummy" | head -1 | grep -q . && \
  error "hardcoded-secret" "Hardcoded password/secret in source — use env vars or vault"

# --- No @Transactional on service methods that write ---
SERVICES=$(find "$SRC" -name "*Service*.java" -o -name "*ServiceImpl.java" 2>/dev/null | grep -v "test" || true)
if [ -n "$SERVICES" ]; then
  NO_TX=$(echo "$SERVICES" | xargs grep -l "save\|delete\|update\|persist" 2>/dev/null | \
    xargs grep -L "@Transactional" 2>/dev/null | head -1 || true)
  [ -n "$NO_TX" ] && finding "no-transactional" "Service with write ops without @Transactional"
fi

# --- Deprecated API usage ---
DEPRECATED=$(cpm_grep -rn "@SuppressWarnings.*deprecation\|@Deprecated" "$SRC/" 2>/dev/null | wc -l | tr -d ' ')
[ "$DEPRECATED" -gt 10 ] && finding "deprecated-usage" "$DEPRECATED deprecated markers — plan migration"

# --- Missing @Override ---
cpm_grep -rn "public.*void\|public.*String\|public.*List" "$SRC/" 2>/dev/null | \
  grep -v "@Override\|interface\|abstract" | head -50 | grep -c "." >/dev/null 2>&1
# (too noisy, skip)

# --- Large classes (>500 lines) ---
LARGE=$(find "$SRC" -name "*.java" -exec wc -l {} \; 2>/dev/null | awk '$1 > 500 {print}' | wc -l | tr -d ' ')
[ "$LARGE" -gt 5 ] && finding "large-classes" "$LARGE Java files >500 lines — consider splitting"

# --- Legacy collections (Vector/Hashtable instead of ArrayList/HashMap) ---
cpm_grep -rn "new Vector\|new Hashtable" "$SRC/" 2>/dev/null | grep -v "test\|Test" | head -1 | grep -q . && \
  finding "legacy-collections" "Vector/Hashtable used — use ArrayList/HashMap (unsynchronized, faster)"

# --- new Integer/Boolean/Long (use valueOf or autoboxing) ---
cpm_grep -rn "new Integer(\|new Boolean(\|new Long(\|new Double(" "$SRC/" 2>/dev/null | head -1 | grep -q . && \
  finding "boxed-constructor" "new Integer()/Boolean() — use Integer.valueOf() or autoboxing"

# --- Static SimpleDateFormat (not thread-safe) ---
cpm_grep -rn "static.*SimpleDateFormat\|static.*DateFormat" "$SRC/" 2>/dev/null | head -1 | grep -q . && \
  finding "static-dateformat" "Static SimpleDateFormat — not thread-safe, use DateTimeFormatter or ThreadLocal"

# --- Empty catch blocks ---
EMPTY_CATCH=$(cpm_grep -rn "catch.*{" "$SRC/" 2>/dev/null | while read -r line; do
  FILE=$(echo "$line" | cut -d: -f1)
  LINE=$(echo "$line" | cut -d: -f2)
  NEXT=$(sed -n "$((LINE+1))p" "$FILE" 2>/dev/null)
  echo "$NEXT" | grep -q "^\s*}" && echo "$FILE:$LINE"
done | wc -l | tr -d ' ')
[ "${EMPTY_CATCH:-0}" -gt 3 ] && finding "empty-catch-blocks" "$EMPTY_CATCH empty catch blocks — exceptions silently swallowed"

# --- God classes (>1000 lines) ---
GODS=$(find "$SRC" -name "*.java" -exec wc -l {} \; 2>/dev/null | awk '$1 > 1000 {print}' | wc -l | tr -d ' ')
[ "$GODS" -gt 0 ] && finding "god-classes" "$GODS Java files >1000 lines — God Object anti-pattern"

[ "$FINDINGS" -eq 0 ] && echo "  ✓ Java patterns OK"
exit 0
