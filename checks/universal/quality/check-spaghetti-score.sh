#!/usr/bin/env bash
# checks/universal/quality/check-spaghetti-score.sh
# @see ADR-156
# Code Pasta Score — multi-dimensional anti-pattern detection.
# Measures: Spaghetti, Lasagna, Ravioli, Pizza, Lava Flow
# Usage: bash check-spaghetti-score.sh [path]
set -o nounset -o pipefail

REPO="${1:-.}"
SRC=""
[ -d "$REPO/src" ] && SRC="$REPO/src"
[ -d "$REPO/app" ] && SRC="${SRC:+$SRC }$REPO/app"
[ -d "$REPO/lib" ] && SRC="${SRC:+$SRC }$REPO/lib"
[ -z "$SRC" ] && SRC="$REPO"

# Find source files
ALL_FILES=$(find $SRC -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" -o -name "*.cpp" -o -name "*.py" 2>/dev/null | grep -v node_modules | grep -v "test\|spec\|\.d\.ts")
[ -z "$ALL_FILES" ] && { echo "  No source files found"; exit 0; }

FILE_COUNT=$(echo "$ALL_FILES" | wc -l | tr -d ' ')

# Scores per dimension (0 = clean, 100 = max anti-pattern)
SPAGHETTI=0
LASAGNA=0
RAVIOLI=0
PIZZA=0
LAVA=0

issue_s() { SPAGHETTI=$((SPAGHETTI + $1)); }
issue_l() { LASAGNA=$((LASAGNA + $1)); }
issue_r() { RAVIOLI=$((RAVIOLI + $1)); }
issue_p() { PIZZA=$((PIZZA + $1)); }
issue_v() { LAVA=$((LAVA + $1)); }

# =============================================
# SPAGHETTI: coupling, god files, deep nesting, no structure
# =============================================

# God Files (>300 lines)
GOD_FILES=$(echo "$ALL_FILES" | xargs wc -l 2>/dev/null | grep -v total | awk '$1 > 300 {n++} END {print n+0}')
[ "${GOD_FILES:-0}" -gt 0 ] && issue_s $((GOD_FILES * 8))

# Deep nesting (>5 brace levels)
DEEP_NEST=0
for f in $(echo "$ALL_FILES" | head -30); do
  MAX_D=$(awk '{d=0; for(i=1;i<=length($0);i++){c=substr($0,i,1); if(c=="{")d++; if(d>max)max=d; if(c=="}")d--}} END{print max+0}' "$f" 2>/dev/null || echo 0)
  [ "${MAX_D:-0}" -gt 5 ] && DEEP_NEST=$((DEEP_NEST + 1))
done
[ "$DEEP_NEST" -gt 0 ] && issue_s $((DEEP_NEST * 6))

# Tight coupling (>10 imports per file)
TIGHT=$(echo "$ALL_FILES" | while read -r f; do
  C=$(grep -c "^import\|require(" "$f" 2>/dev/null)
  C=${C:-0}
  [ "$C" -gt 10 ] 2>/dev/null && echo x
done | wc -l | tr -d ' ')
[ "${TIGHT:-0}" -gt 0 ] && issue_s $((TIGHT * 5))

# Circular-like: deep relative imports (../../..)
DEEP_IMP=$(echo "$ALL_FILES" | xargs grep -l "\.\./\.\./\.\." 2>/dev/null | wc -l | tr -d ' ')
[ "${DEEP_IMP:-0}" -gt 0 ] && issue_s $((DEEP_IMP * 3))

# No error handling on async
NO_CATCH=$(echo "$ALL_FILES" | xargs grep -l "async " 2>/dev/null | xargs grep -L "try\|catch\|\.catch\|onError" 2>/dev/null | wc -l | tr -d ' ')
[ "${NO_CATCH:-0}" -gt 0 ] && issue_s $((NO_CATCH * 4))

# =============================================
# LASAGNA: too many layers, over-abstraction
# =============================================

# Too many abstraction directories (exclude node_modules and Next.js route segments)
DIR_DEPTH=$(find $SRC -type d -not -path "*/node_modules/*" -not -path "*/\[*" 2>/dev/null | awk -F/ '{print NF}' | sort -rn | head -1 || echo 0)
[ "${DIR_DEPTH:-0}" -gt 7 ] && issue_l $(( (DIR_DEPTH - 7) * 10))

# Interface/abstract without implementation (empty shells)
EMPTY_IFACE=$(echo "$ALL_FILES" | xargs grep -l "interface.*{}" 2>/dev/null | wc -l | tr -d ' ')
[ "${EMPTY_IFACE:-0}" -gt 3 ] && issue_l $((EMPTY_IFACE * 5))

# Too many wrapper/adapter/proxy/facade files relative to actual logic
WRAPPER_FILES=$(find $SRC -name "*wrapper*" -o -name "*adapter*" -o -name "*proxy*" -o -name "*facade*" -o -name "*abstract*" -o -name "*base*" 2>/dev/null | grep -v node_modules | wc -l | tr -d ' ')
[ "${WRAPPER_FILES:-0}" -gt 5 ] && issue_l $((WRAPPER_FILES * 4))

# Too many type-only files vs implementation
TYPE_FILES=$(find $SRC -name "*.types.ts" -o -name "types.ts" -o -name "*.interface.ts" -o -name "interfaces.ts" 2>/dev/null | grep -v node_modules | wc -l | tr -d ' ')
[ "${TYPE_FILES:-0}" -gt 8 ] && issue_l $((TYPE_FILES * 3))

# Single function per file pattern (over-split) — only flag if also tiny
TINY_FILES=$(echo "$ALL_FILES" | xargs wc -l 2>/dev/null | grep -v total | awk '$1 < 10 && $1 > 0 {n++} END {print n+0}')
TINY_RATIO=0
[ "$FILE_COUNT" -gt 0 ] && TINY_RATIO=$((TINY_FILES * 100 / FILE_COUNT))
[ "$TINY_RATIO" -gt 50 ] && issue_l $((TINY_RATIO / 3))

# =============================================
# RAVIOLI: too many tiny disconnected pieces
# =============================================

# Too many files for the LOC
TOTAL_LOC=$(echo "$ALL_FILES" | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1+0}')
TOTAL_LOC=${TOTAL_LOC:-1}
[ "$TOTAL_LOC" -eq 0 ] && TOTAL_LOC=1
AVG_FILE_SIZE=$((TOTAL_LOC / FILE_COUNT))
[ "$AVG_FILE_SIZE" -lt 20 ] && [ "$FILE_COUNT" -gt 10 ] && issue_r 30

# Too many index/barrel files
BARREL_COUNT=$(find $SRC -name "index.ts" -o -name "index.js" 2>/dev/null | grep -v node_modules | wc -l | tr -d ' ')
[ "${BARREL_COUNT:-0}" -gt 10 ] && issue_r $((BARREL_COUNT * 3))

# Too many single-export files (exclude page/layout/route — framework convention)
SINGLE_EXPORT=$(echo "$ALL_FILES" | grep -v "page\.\|layout\.\|route\.\|loading\.\|error\.\|not-found\." | while read -r f; do
  EXPORTS=$(grep -c "^export " "$f" 2>/dev/null || echo 0)
  [ "$EXPORTS" -eq 1 ] && echo x
done | wc -l | tr -d ' ')
SINGLE_RATIO=0
[ "$FILE_COUNT" -gt 0 ] && SINGLE_RATIO=$((SINGLE_EXPORT * 100 / FILE_COUNT))
[ "$SINGLE_RATIO" -gt 80 ] && [ "$FILE_COUNT" -gt 15 ] && issue_r 25

# Too many directories relative to files
DIR_COUNT=$(find $SRC -type d -not -path "*/node_modules/*" 2>/dev/null | wc -l | tr -d ' ')
if [ "$FILE_COUNT" -gt 0 ] && [ "${DIR_COUNT:-0}" -gt 0 ]; then
  FILES_PER_DIR=$((FILE_COUNT / DIR_COUNT))
  [ "$FILES_PER_DIR" -lt 2 ] && [ "$DIR_COUNT" -gt 10 ] && issue_r 20
fi

# =============================================
# PIZZA: everything flat, no separation
# =============================================

# All files in one directory (no subdirs)
if [ "${DIR_COUNT:-0}" -le 2 ] && [ "$FILE_COUNT" -gt 15 ]; then
  issue_p 40
fi

# No lib/utils/hooks/components separation
HAS_STRUCTURE=0
[ -d "$REPO/src/components" ] || [ -d "$REPO/src/lib" ] || [ -d "$REPO/src/hooks" ] || [ -d "$REPO/src/utils" ] || [ -d "$REPO/src/services" ] && HAS_STRUCTURE=1
[ "$HAS_STRUCTURE" -eq 0 ] && [ "$FILE_COUNT" -gt 10 ] && issue_p 30

# Mixed concerns: API + UI + logic in same file
MIXED=$(echo "$ALL_FILES" | xargs grep -l "fetch(\|axios" 2>/dev/null | xargs grep -l "<.*>" 2>/dev/null | xargs grep -l "useState\|useEffect" 2>/dev/null | wc -l | tr -d ' ')
[ "${MIXED:-0}" -gt 3 ] && issue_p $((MIXED * 8))

# No separation of types from implementation
if [ "${TYPE_FILES:-0}" -eq 0 ] && [ "$FILE_COUNT" -gt 10 ]; then
  # Check if types are inline everywhere
  INLINE_TYPES=$(echo "$ALL_FILES" | xargs grep -l "^interface \|^type " 2>/dev/null | xargs grep -l "function\|const.*=>" 2>/dev/null | wc -l | tr -d ' ')
  [ "${INLINE_TYPES:-0}" -gt 5 ] && issue_p 15
fi

# =============================================
# LAVA FLOW: dead code, commented out, unreachable
# =============================================

# TODO/FIXME accumulation
TODOS=$(echo "$ALL_FILES" | xargs grep -c "TODO\|FIXME\|HACK\|XXX" 2>/dev/null | awk -F: '{s+=$2}END{print s+0}')
[ "${TODOS:-0}" -gt 10 ] && issue_v $((TODOS * 2))

# Commented-out code (4+ consecutive // lines with code chars)
COMMENT_BLOCKS=0
for f in $(echo "$ALL_FILES" | head -20); do
  BLOCK=$(grep -c "^\s*//" "$f" 2>/dev/null | head -1 || echo 0)
  BLOCK=${BLOCK:-0}
  [ "$BLOCK" -gt 8 ] 2>/dev/null && COMMENT_BLOCKS=$((COMMENT_BLOCKS + 1))
done
[ "$COMMENT_BLOCKS" -gt 0 ] && issue_v $((COMMENT_BLOCKS * 8))

# Console.log left in
CONSOLES=$(echo "$ALL_FILES" | xargs grep -l "console\.log" 2>/dev/null | wc -l | tr -d ' ')
[ "${CONSOLES:-0}" -gt 0 ] && issue_v $((CONSOLES * 3))

# any type (giving up on typing = code rot)
ANY_TYPE=$(echo "$ALL_FILES" | xargs grep -l ": any\|as any" 2>/dev/null | wc -l | tr -d ' ')
[ "${ANY_TYPE:-0}" -gt 0 ] && issue_v $((ANY_TYPE * 4))

# No tests (code decays without them)
TEST_FILES=$(find $SRC "$REPO/tests" "$REPO/__tests__" -name "*.test.*" -o -name "*.spec.*" 2>/dev/null | grep -v node_modules | wc -l | tr -d ' ')
[ "${TEST_FILES:-0}" -eq 0 ] && issue_v 25

# =============================================
# CLAMP & OUTPUT
# =============================================

# Clamp all to 0-100
[ "$SPAGHETTI" -gt 100 ] && SPAGHETTI=100
[ "$LASAGNA" -gt 100 ] && LASAGNA=100
[ "$RAVIOLI" -gt 100 ] && RAVIOLI=100
[ "$PIZZA" -gt 100 ] && PIZZA=100
[ "$LAVA" -gt 100 ] && LAVA=100

# Overall health (inverse of worst dimensions)
WORST=$SPAGHETTI
[ "$LASAGNA" -gt "$WORST" ] && WORST=$LASAGNA
[ "$RAVIOLI" -gt "$WORST" ] && WORST=$RAVIOLI
[ "$PIZZA" -gt "$WORST" ] && WORST=$PIZZA
[ "$LAVA" -gt "$WORST" ] && WORST=$LAVA
HEALTH=$((100 - (SPAGHETTI + LASAGNA + RAVIOLI + PIZZA + LAVA) / 5))
[ "$HEALTH" -lt 0 ] && HEALTH=0

# Grade
if [ "$HEALTH" -ge 90 ]; then GRADE="A"; COLOR="\033[32m"
elif [ "$HEALTH" -ge 75 ]; then GRADE="B"; COLOR="\033[32m"
elif [ "$HEALTH" -ge 50 ]; then GRADE="C"; COLOR="\033[33m"
elif [ "$HEALTH" -ge 25 ]; then GRADE="D"; COLOR="\033[31m"
else GRADE="F"; COLOR="\033[31m"; fi

# Bar helper
bar() {
  local VAL=$1 MAX=100 WIDTH=20
  local FILLED=$((VAL * WIDTH / MAX))
  local EMPTY=$((WIDTH - FILLED))
  local BAR=""
  for ((i=0; i<FILLED; i++)); do BAR="${BAR}█"; done
  for ((i=0; i<EMPTY; i++)); do BAR="${BAR}░"; done
  echo "$BAR"
}

echo ""
printf "  ${COLOR}Code Health: %d/100 (%s)${COLOR}\033[0m\n" "$HEALTH" "$GRADE"
echo "  Files: $FILE_COUNT | LOC: ${TOTAL_LOC:-0}"
echo ""
echo "  Anti-pattern breakdown (0=clean, 100=max smell):"
echo ""
printf "  🍝 Spaghetti  %3d  %s  coupling, god files, nesting\n" "$SPAGHETTI" "$(bar $SPAGHETTI)"
printf "  🍲 Lasagna    %3d  %s  over-abstraction, too many layers\n" "$LASAGNA" "$(bar $LASAGNA)"
printf "  🟠 Ravioli    %3d  %s  fragmentation, micro-files\n" "$RAVIOLI" "$(bar $RAVIOLI)"
printf "  🍕 Pizza      %3d  %s  flat, no separation of concerns\n" "$PIZZA" "$(bar $PIZZA)"
printf "  🌋 Lava Flow  %3d  %s  dead code, tech debt, rot\n" "$LAVA" "$(bar $LAVA)"
echo ""

# Verdict based on highest dimension
if [ "$HEALTH" -ge 90 ]; then
  echo "  Verdict: Clean architecture. Well done."
elif [ "$SPAGHETTI" -ge 50 ]; then
  echo "  Verdict: Spaghetti — split god files, reduce coupling, flatten nesting."
elif [ "$LASAGNA" -ge 50 ]; then
  echo "  Verdict: Lasagna — too many layers. Remove unnecessary abstractions."
elif [ "$RAVIOLI" -ge 50 ]; then
  echo "  Verdict: Ravioli — too fragmented. Consolidate related logic into modules."
elif [ "$PIZZA" -ge 50 ]; then
  echo "  Verdict: Pizza — flat chaos. Add folder structure and separate concerns."
elif [ "$LAVA" -ge 50 ]; then
  echo "  Verdict: Lava Flow — dead code accumulating. Clean up TODOs, remove commented code."
else
  echo "  Verdict: Healthy codebase with minor issues."
fi
echo ""

[ "$HEALTH" -ge 75 ] && exit 0 || exit 1
