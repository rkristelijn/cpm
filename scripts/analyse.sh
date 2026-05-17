#!/usr/bin/env bash
# scripts/analyse.sh — Full codebase analysis: understand + assess + check
# Usage: bash scripts/analyse.sh [path] [--deep]
# Runs all understanding scripts, then conditionally runs checks based on detected stack
set -o nounset -o pipefail

REPO="${1:-.}"
DEEP=false
[[ "${2:-}" == "--deep" ]] && DEEP=true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK_DIR="$(cd "$SCRIPT_DIR/../checks" && pwd)"

echo ""
echo "  ╔═══════════════════════════════════════════════════════╗"
echo "  ║          cpm analyse — full codebase analysis         ║"
echo "  ╚═══════════════════════════════════════════════════════╝"
echo ""

# ============================================================
# PHASE 1: Understand
# ============================================================
echo "  ━━━ Phase 1: Understanding ━━━"
bash "$SCRIPT_DIR/discover/overview.sh" "$REPO"
bash "$SCRIPT_DIR/discover/runtime.sh" "$REPO"
bash "$SCRIPT_DIR/discover/techradar.sh" "$REPO"
bash "$SCRIPT_DIR/discover/routes.sh" "$REPO"
bash "$SCRIPT_DIR/discover/dataflow.sh" "$REPO"

# ============================================================
# PHASE 2: Assess
# ============================================================
echo "  ━━━ Phase 2: Maturity Assessment ━━━"
bash "$SCRIPT_DIR/assess/maturity.sh" "$REPO"

# ============================================================
# PHASE 3: Detect stack and run conditional checks
# ============================================================
echo "  ━━━ Phase 3: Quality Checks (based on detected stack) ━━━"
echo ""

# --- Detect package manager and enforcement ---
if [ -f "$REPO/package.json" ]; then
  echo "  ■ Package Manager"
  PM="unknown"
  [ -f "$REPO/pnpm-lock.yaml" ] && PM="pnpm"
  [ -f "$REPO/yarn.lock" ] && PM="yarn"
  [ -f "$REPO/package-lock.json" ] && PM="npm"
  [ -f "$REPO/bun.lockb" ] && PM="bun"
  printf "    Detected: %s\n" "$PM"

  # Check enforcement
  ENFORCED=false
  if [ -f "$REPO/.npmrc" ] && grep -q "package-manager\|engine-strict" "$REPO/.npmrc" 2>/dev/null; then
    ENFORCED=true
  fi
  if [ -f "$REPO/package.json" ] && grep -q '"packageManager"' "$REPO/package.json" 2>/dev/null; then
    ENFORCED=true
    PM_FIELD=$(grep -oE '"packageManager"[^,}]*' "$REPO/package.json" | sed 's/.*: *"//;s/"//')
    printf "    Enforced via: packageManager field (%s)\n" "$PM_FIELD"
  fi
  # Check for multiple lockfiles (conflict)
  LOCKS=0
  [ -f "$REPO/package-lock.json" ] && LOCKS=$((LOCKS + 1))
  [ -f "$REPO/pnpm-lock.yaml" ] && LOCKS=$((LOCKS + 1))
  [ -f "$REPO/yarn.lock" ] && LOCKS=$((LOCKS + 1))
  [ "$LOCKS" -gt 1 ] && printf "    ⚠ Multiple lockfiles detected — enforce one package manager!\n"
  [ "$ENFORCED" = false ] && printf "    ⚠ Not enforced — add \"packageManager\" field or engines.npm to package.json\n"
  echo ""
fi

# --- Universal checks ---
echo "  ■ Universal Checks"
for f in "$CHECK_DIR/universal/quality/check-css.sh" \
  "$CHECK_DIR/universal/quality/check-html.sh" \
  "$CHECK_DIR/universal/quality/check-json.sh" \
  "$CHECK_DIR/universal/quality/check-xml.sh" \
  "$CHECK_DIR/universal/docs/check-web-essentials.sh"; do
  [ -f "$f" ] && bash "$f" "$REPO" 2>/dev/null
done
echo ""

# --- JavaScript/TypeScript checks ---
if [ -f "$REPO/package.json" ]; then
  echo "  ■ JavaScript/TypeScript Checks"
  for f in "$CHECK_DIR/javascript/check-package-json.sh" \
    "$CHECK_DIR/javascript/check-runtime-pin.sh" \
    "$CHECK_DIR/javascript/check-tsconfig.sh" \
    "$CHECK_DIR/javascript/check-react.sh"; do
    [ -f "$f" ] && bash "$f" "$REPO" 2>/dev/null
  done
  echo ""

  # --- Testing checks ---
  echo "  ■ Testing Checks"
  for f in "$CHECK_DIR/javascript/testing/check-testing.sh" \
    "$CHECK_DIR/javascript/testing/check-cypress.sh" \
    "$CHECK_DIR/javascript/testing/check-playwright.sh"; do
    [ -f "$f" ] && bash "$f" "$REPO" 2>/dev/null
  done
  echo ""
fi

# --- Angular-specific ---
if [ -f "$REPO/angular.json" ]; then
  echo "  ■ Angular Checks"
  [ -f "$CHECK_DIR/javascript/angular/check-angular.sh" ] && bash "$CHECK_DIR/javascript/angular/check-angular.sh" "$REPO" 2>/dev/null
  echo ""
fi

# --- Next.js-specific ---
if [ -f "$REPO/next.config.ts" ] || [ -f "$REPO/next.config.js" ] || [ -f "$REPO/next.config.mjs" ]; then
  echo "  ■ Next.js Checks"
  for f in "$CHECK_DIR/javascript/nextjs/"*.sh; do
    [ -f "$f" ] && bash "$f" "$REPO" 2>/dev/null
  done
  echo ""
fi

# --- Nx monorepo ---
if [ -f "$REPO/nx.json" ]; then
  echo "  ■ Nx Workspace Checks"
  [ -f "$CHECK_DIR/javascript/nx/check-nx-workspace.sh" ] && bash "$CHECK_DIR/javascript/nx/check-nx-workspace.sh" "$REPO" 2>/dev/null
  echo ""
fi

# --- Node.js: npm audit + outdated ---
if [ -f "$REPO/package.json" ] && [ -d "$REPO/node_modules" ]; then
  echo "  ■ Dependency Health (live)"
  echo "    npm audit:"
  AUDIT=$(cd "$REPO" && npm audit --omit=dev --json 2>/dev/null || true)
  if [ -n "$AUDIT" ]; then
    CRIT=$(echo "$AUDIT" | grep -oE '"critical":[0-9]+' | grep -oE '[0-9]+' || echo 0)
    HIGH=$(echo "$AUDIT" | grep -oE '"high":[0-9]+' | grep -oE '[0-9]+' || echo 0)
    [ "${CRIT:-0}" -gt 0 ] && printf "      🔴 %s critical\n" "$CRIT"
    [ "${HIGH:-0}" -gt 0 ] && printf "      🟠 %s high\n" "$HIGH"
    [ "${CRIT:-0}" -eq 0 ] && [ "${HIGH:-0}" -eq 0 ] && echo "      ✓ No critical/high vulnerabilities"
  fi
  echo "    npm outdated:"
  OUTDATED=$(cd "$REPO" && npm outdated 2>/dev/null | tail -n +2 | wc -l | tr -d ' ')
  printf "      %s packages outdated\n" "${OUTDATED:-0}"
  echo ""
fi

# --- PHP checks ---
if [ -f "$REPO/composer.json" ]; then
  echo "  ■ PHP Checks"
  [ -f "$CHECK_DIR/php/check-php.sh" ] && bash "$CHECK_DIR/php/check-php.sh" "$REPO" 2>/dev/null
  echo ""
fi

# --- Java checks ---
if [ -f "$REPO/pom.xml" ] || find "$REPO" -name "pom.xml" -maxdepth 3 2>/dev/null | head -1 | grep -q .; then
  echo "  ■ Java Checks"
  [ -f "$CHECK_DIR/java/check-java.sh" ] && bash "$CHECK_DIR/java/check-java.sh" "$REPO" 2>/dev/null
  echo ""
fi

# ============================================================
# PHASE 4: Deep analysis (optional)
# ============================================================
if [ "$DEEP" = true ]; then
  echo "  ━━━ Phase 4: Deep Analysis (npx tools) ━━━"
  bash "$SCRIPT_DIR/discover/patterns-deep.sh" "$REPO"
fi

echo ""
echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Analysis complete. For deeper exploration:"
echo "    bash scripts/discover/callgraph.sh $REPO/src"
echo "    bash scripts/discover/classdiagram.sh $REPO/src"
echo "    bash scripts/discover/trace.sh <function> $REPO/src"
echo "    bash scripts/discover/exports.sh $REPO"
echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
