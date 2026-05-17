#!/usr/bin/env bash
# scripts/patterns-deep.sh — Deep pattern analysis using proven tools (optional)
# Usage: bash scripts/patterns-deep.sh [path]
# Requires: npx (Node.js), optionally: madge, knip
set -o nounset -o pipefail

REPO="${1:-.}"

echo ""
echo "  ■ Deep pattern analysis: $(basename "$(cd "$REPO" && pwd)")"
echo ""

# Check prerequisites
if ! command -v npx >/dev/null 2>&1; then
  echo "  ⚠ npx not found — install Node.js for deep analysis"
  exit 0
fi

# === 1. Circular Dependencies (madge) ===
echo "  ┌ Circular Dependencies (madge)"
if [ -f "$REPO/tsconfig.json" ] || [ -d "$REPO/src" ]; then
  CIRCULAR=$(cd "$REPO" && npx --yes madge@8 --circular --extensions ts,tsx,js,jsx src/ 2>/dev/null | grep "→" || true)
  if [ -n "$CIRCULAR" ]; then
    COUNT=$(echo "$CIRCULAR" | wc -l | tr -d ' ')
    echo "  │ ⚠ $COUNT circular dependency chain(s):"
    echo "$CIRCULAR" | head -5 | sed 's/^/  │   /'
    [ "$COUNT" -gt 5 ] && echo "  │   ... and $((COUNT - 5)) more"
  else
    echo "  │ ✓ No circular dependencies"
  fi
else
  echo "  │ · skipped (no tsconfig.json or src/)"
fi
echo "  └"
echo ""

# === 2. Dead Code / Unused Exports (knip) ===
echo "  ┌ Dead Code & Unused Exports (knip)"
if [ -f "$REPO/package.json" ]; then
  KNIP=$(cd "$REPO" && npx --yes knip@5 --no-exit-code --reporter compact 2>/dev/null | head -20 || true)
  if [ -n "$KNIP" ]; then
    echo "$KNIP" | sed 's/^/  │ /'
  else
    echo "  │ ✓ No dead code detected"
  fi
else
  echo "  │ · skipped (no package.json)"
fi
echo "  └"
echo ""

# === 3. Dependency Graph Visualization (madge) ===
echo "  ┌ Dependency Graph"
if [ -f "$REPO/tsconfig.json" ] || [ -d "$REPO/src" ]; then
  ENTRY=$(find "$REPO/src" -maxdepth 1 -name "index.ts" -o -name "main.ts" -o -name "app.ts" 2>/dev/null | head -1)
  [ -z "$ENTRY" ] && ENTRY=$(find "$REPO/src" -maxdepth 1 -name "*.ts" 2>/dev/null | head -1)
  if [ -n "$ENTRY" ]; then
    DEPS=$(cd "$REPO" && npx --yes madge@8 --extensions ts,tsx,js,jsx "$ENTRY" 2>/dev/null | head -15 || true)
    if [ -n "$DEPS" ]; then
      echo "$DEPS" | sed 's/^/  │ /'
    fi
  fi
else
  echo "  │ · skipped"
fi
echo "  └"
echo ""

# === 4. Complexity Hotspots (via grep + wc as fallback, or eslint) ===
echo "  ┌ Complexity Hotspots"
if [ -f "$REPO/tsconfig.json" ]; then
  # Find files with most functions (proxy for complexity)
  echo "  │ Files with most exported symbols:"
  find "$REPO/src" -name "*.ts" -o -name "*.tsx" 2>/dev/null | grep -v "node_modules\|\.test\.\|\.spec\." | while read -r f; do
    COUNT=$(grep -cE "^export (function|class|const|interface|type)" "$f" 2>/dev/null || echo 0)
    [ "$COUNT" -gt 5 ] && printf "  │   %3d exports  %s\n" "$COUNT" "$(echo "$f" | sed "s|$REPO/||")"
  done | sort -rn | head -8
fi
echo "  └"
echo ""

# === 5. Bundle Size (cost-of-modules) ===
echo "  ┌ Bundle Size (top dependencies)"
if [ -f "$REPO/package.json" ] && [ -d "$REPO/node_modules" ]; then
  COST=$(cd "$REPO" && npx --yes cost-of-modules@2 --no-install 2>/dev/null | head -12 || true)
  if [ -n "$COST" ]; then
    echo "$COST" | sed 's/^/  │ /'
  else
    echo "  │ · run 'npm install' first for bundle analysis"
  fi
else
  echo "  │ · skipped (no node_modules)"
fi
echo "  └"
echo ""

# === 6. Unused Dependencies (depcheck) ===
echo "  ┌ Unused Dependencies (depcheck)"
if [ -f "$REPO/package.json" ] && [ -d "$REPO/node_modules" ]; then
  UNUSED=$(cd "$REPO" && npx --yes depcheck@1 --skip-missing 2>/dev/null | grep "^\*" | head -10 || true)
  if [ -n "$UNUSED" ]; then
    echo "$UNUSED" | sed 's/^/  │ /'
  else
    echo "  │ ✓ All dependencies are used"
  fi
else
  echo "  │ · skipped (no node_modules)"
fi
echo "  └"
echo ""

# === 7. Outdated Dependencies (npm-check) ===
echo "  ┌ Outdated Dependencies"
if [ -f "$REPO/package.json" ]; then
  OUTDATED=$(cd "$REPO" && npm outdated --json 2>/dev/null | grep -oE '"[^"]+": \{' | sed 's/": {//; s/"//g; s/^/  │ /' | head -10 || true)
  if [ -n "$OUTDATED" ]; then
    echo "$OUTDATED"
  else
    echo "  │ ✓ All dependencies up to date"
  fi
fi
echo "  └"
echo ""

# === 8. License Audit (license-checker) ===
echo "  ┌ License Audit"
if [ -f "$REPO/package.json" ] && [ -d "$REPO/node_modules" ]; then
  COPYLEFT=$(cd "$REPO" && npx --yes license-checker@25 --production --csv 2>/dev/null | grep -iE "GPL|AGPL|SSPL|EUPL" | head -5 || true)
  if [ -n "$COPYLEFT" ]; then
    echo "  │ ⚠ Copyleft licenses found:"
    echo "$COPYLEFT" | sed 's/^/  │   /'
  else
    echo "  │ ✓ No copyleft licenses in production deps"
  fi
else
  echo "  │ · skipped (no node_modules)"
fi
echo "  └"
echo ""

# === 9. Security Vulnerabilities (npm audit) ===
echo "  ┌ Security Vulnerabilities"
if [ -f "$REPO/package.json" ]; then
  AUDIT=$(cd "$REPO" && npm audit --omit=dev --json 2>/dev/null || true)
  if [ -n "$AUDIT" ]; then
    CRITICAL=$(echo "$AUDIT" | grep -oE '"critical":[0-9]+' | grep -oE '[0-9]+' || echo 0)
    HIGH=$(echo "$AUDIT" | grep -oE '"high":[0-9]+' | grep -oE '[0-9]+' || echo 0)
    MODERATE=$(echo "$AUDIT" | grep -oE '"moderate":[0-9]+' | grep -oE '[0-9]+' || echo 0)
    [ "${CRITICAL:-0}" -gt 0 ] && echo "  │ 🔴 $CRITICAL critical"
    [ "${HIGH:-0}" -gt 0 ] && echo "  │ 🟠 $HIGH high"
    [ "${MODERATE:-0}" -gt 0 ] && echo "  │ 🟡 $MODERATE moderate"
    [ "${CRITICAL:-0}" -eq 0 ] && [ "${HIGH:-0}" -eq 0 ] && [ "${MODERATE:-0}" -eq 0 ] && echo "  │ ✓ No known vulnerabilities"
  fi
fi
echo "  └"
echo ""

# === 10. TypeScript Strict Compliance (tsc --noEmit) ===
echo "  ┌ TypeScript Errors"
if [ -f "$REPO/tsconfig.json" ]; then
  ERRORS=$(cd "$REPO" && npx tsc --noEmit 2>&1 | grep -c "error TS" || echo 0)
  if [ "${ERRORS:-0}" -gt 0 ]; then
    echo "  │ ⚠ $ERRORS type errors (tsc --noEmit)"
    cd "$REPO" && npx tsc --noEmit 2>&1 | grep "error TS" | head -5 | sed 's/^/  │   /'
  else
    echo "  │ ✓ No type errors"
  fi
fi
echo "  └"
echo ""

# === 11. Duplicate Code (jscpd) ===
echo "  ┌ Code Duplication (jscpd)"
if [ -d "$REPO/src" ]; then
  DUP=$(cd "$REPO" && npx --yes jscpd@4 src --min-lines 5 --min-tokens 50 --silent 2>&1 | grep -E "clones|duplicat" | head -3 || true)
  if [ -n "$DUP" ]; then
    echo "$DUP" | sed 's/^/  │ /'
  else
    echo "  │ ✓ No significant duplication"
  fi
fi
echo "  └"
echo ""
